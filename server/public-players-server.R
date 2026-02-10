# =============================================================================
# Public: Players Tab Server Logic
# =============================================================================
# Note: Contains overview_player_clicked handler which is triggered from
# the Dashboard tab to open player details from "Top Players" table.

# Reset players filters
observeEvent(input$reset_players_filters, {
  updateTextInput(session, "players_search", value = "")
  updateSelectInput(session, "players_format", selected = "")
  updateSelectInput(session, "players_min_events", selected = "")
})

output$player_standings <- renderReactable({
  rv$data_refresh  # Trigger refresh on admin changes
  if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) return(NULL)

  # Build filters
  search_filter <- if (!is.null(input$players_search) && nchar(trimws(input$players_search)) > 0) {
    sprintf("AND LOWER(p.display_name) LIKE LOWER('%%%s%%')", trimws(input$players_search))
  } else ""

  format_filter <- if (!is.null(input$players_format) && input$players_format != "") {
    sprintf("AND t.format = '%s'", input$players_format)
  } else ""

  scene_filter <- build_scene_filter(rv$current_scene, "s")

  min_events <- as.numeric(input$players_min_events)
  if (is.na(min_events)) min_events <- 0

  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT p.player_id, p.display_name as Player,
           COUNT(DISTINCT r.tournament_id) as Events,
           SUM(r.wins) as W, SUM(r.losses) as L, SUM(r.ties) as T,
           ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%',
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as '1sts',
           COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as 'Top 3s'
    FROM players p
    JOIN results r ON p.player_id = r.player_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    JOIN stores s ON t.store_id = s.store_id
    WHERE 1=1 %s %s %s
    GROUP BY p.player_id, p.display_name
    HAVING COUNT(DISTINCT r.tournament_id) >= %d
  ", search_filter, format_filter, scene_filter, min_events))

  # Get most played deck for each player (Main Deck)
  main_decks <- dbGetQuery(rv$db_con, sprintf("
    WITH player_deck_counts AS (
      SELECT r.player_id, da.archetype_name, da.primary_color,
             COUNT(*) as times_played,
             ROW_NUMBER() OVER (PARTITION BY r.player_id ORDER BY COUNT(*) DESC) as rn
      FROM results r
      JOIN players p ON r.player_id = p.player_id
      JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      JOIN stores s ON t.store_id = s.store_id
      WHERE da.archetype_name != 'UNKNOWN' %s %s %s
      GROUP BY r.player_id, da.archetype_name, da.primary_color
    )
    SELECT player_id, archetype_name as main_deck, primary_color as main_deck_color
    FROM player_deck_counts
    WHERE rn = 1
  ", search_filter, format_filter, scene_filter))

  if (nrow(result) == 0) {
    return(reactable(data.frame(Message = "No player data matches filters"), compact = TRUE))
  }

  # Join with competitive ratings
  comp_ratings <- player_competitive_ratings()
  result <- merge(result, comp_ratings, by = "player_id", all.x = TRUE)
  result$competitive_rating[is.na(result$competitive_rating)] <- 1500

  # Join with achievement scores
  ach_scores <- player_achievement_scores()
  result <- merge(result, ach_scores, by = "player_id", all.x = TRUE)
  result$achievement_score[is.na(result$achievement_score)] <- 0

  # Join with main decks
  result <- merge(result, main_decks, by = "player_id", all.x = TRUE)
  result$main_deck[is.na(result$main_deck)] <- "-"
  result$main_deck_color[is.na(result$main_deck_color)] <- ""

  # Create Record column as HTML (W-L-T with colors)
  result$Record <- sapply(1:nrow(result), function(i) {
    w <- result$W[i]
    l <- result$L[i]
    t <- result$T[i]
    sprintf(
      "<span style='color: #22c55e;'>%d</span>-<span style='color: #ef4444;'>%d</span>%s",
      w, l,
      if (t > 0) sprintf("-<span style='color: #f97316;'>%d</span>", t) else ""
    )
  })

  # Create Main Deck column as HTML (with color badge)
  result$main_deck_html <- sapply(1:nrow(result), function(i) {
    deck <- result$main_deck[i]
    if (is.na(deck) || deck == "-") return("-")
    color <- result$main_deck_color[i]
    color_class <- if (!is.na(color) && color != "") {
      paste0("deck-badge deck-badge-", tolower(color))
    } else {
      "deck-badge"
    }
    sprintf("<span class='%s'>%s</span>", color_class, deck)
  })

  # Sort by competitive rating
  result <- result[order(-result$competitive_rating), ]

  reactable(
    result,
    compact = TRUE,
    striped = TRUE,
    pagination = TRUE,
    defaultPageSize = 32,
    rowStyle = list(cursor = "pointer"),
    onClick = JS("function(rowInfo, column) {
      if (rowInfo) {
        Shiny.setInputValue('player_clicked', rowInfo.row.player_id, {priority: 'event'})
      }
    }"),
    columns = list(
      player_id = colDef(show = FALSE),
      Player = colDef(minWidth = 140),
      Events = colDef(minWidth = 60, align = "center"),
      competitive_rating = colDef(
        name = "Rating",
        minWidth = 65,
        align = "center"
      ),
      achievement_score = colDef(
        name = "Score",
        minWidth = 55,
        align = "center"
      ),
      `1sts` = colDef(minWidth = 45, align = "center"),
      `Top 3s` = colDef(minWidth = 55, align = "center"),
      W = colDef(show = FALSE),
      L = colDef(show = FALSE),
      T = colDef(show = FALSE),
      Record = colDef(
        name = "Record",
        minWidth = 80,
        align = "center",
        html = TRUE
      ),
      `Win %` = colDef(minWidth = 60, align = "center"),
      main_deck = colDef(show = FALSE),
      main_deck_color = colDef(show = FALSE),
      main_deck_html = colDef(
        name = "Main Deck",
        minWidth = 120,
        html = TRUE
      )
    )
  )
})

# Handle player row click - open detail modal
observeEvent(input$player_clicked, {
  rv$selected_player_id <- input$player_clicked
})

# Handle Overview player click - switch to Players tab and open modal
observeEvent(input$overview_player_clicked, {
  rv$selected_player_id <- input$overview_player_clicked
  nav_select("main_content", "players")
  rv$current_nav <- "players"
  session$sendCustomMessage("updateSidebarNav", "nav_players")
})

# Render player detail modal
output$player_detail_modal <- renderUI({
  req(rv$selected_player_id)

  player_id <- rv$selected_player_id
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  # Get player info
  player <- dbGetQuery(rv$db_con, sprintf("
    SELECT p.player_id, p.display_name, p.home_store_id, s.name as home_store
    FROM players p
    LEFT JOIN stores s ON p.home_store_id = s.store_id
    WHERE p.player_id = %d
  ", player_id))

  if (nrow(player) == 0) return(NULL)

  # Get overall stats including ties and avg placement
  stats <- dbGetQuery(rv$db_con, sprintf("
    SELECT COUNT(DISTINCT r.tournament_id) as events,
           SUM(r.wins) as wins, SUM(r.losses) as losses, SUM(r.ties) as ties,
           ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as win_pct,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as first_places,
           COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3,
           ROUND(AVG(r.placement), 1) as avg_placement
    FROM results r
    WHERE r.player_id = %d
  ", player_id))

  # Get rating and achievement score
  p_ratings <- player_competitive_ratings()
  p_achievements <- player_achievement_scores()
  player_rating <- p_ratings$competitive_rating[p_ratings$player_id == player_id]
  player_score <- p_achievements$achievement_score[p_achievements$player_id == player_id]
  if (length(player_rating) == 0) player_rating <- 1500
  if (length(player_score) == 0) player_score <- 0

  # Get favorite decks (most played)
  # Exclude UNKNOWN archetype from player profiles
  favorite_decks <- dbGetQuery(rv$db_con, sprintf("
    SELECT da.archetype_name as Deck, da.primary_color as color,
           COUNT(*) as Times,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as Wins
    FROM results r
    JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    WHERE r.player_id = %d AND da.archetype_name != 'UNKNOWN'
    GROUP BY da.archetype_id, da.archetype_name, da.primary_color
    ORDER BY COUNT(*) DESC
    LIMIT 5
  ", player_id))

  # Get recent tournament results
  recent_results <- dbGetQuery(rv$db_con, sprintf("
    SELECT t.event_date as Date, s.name as Store, da.archetype_name as Deck,
           r.placement as Place, r.wins as W, r.losses as L, r.decklist_url
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    JOIN stores s ON t.store_id = s.store_id
    JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    WHERE r.player_id = %d
    ORDER BY t.event_date DESC
    LIMIT 10
  ", player_id))

  # Update URL for deep linking
  update_url_for_player(session, player_id, player$display_name)

  # Build modal
  showModal(modalDialog(
    title = div(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("person-circle"),
      player$display_name
    ),
    size = "l",
    easyClose = TRUE,
    footer = tagList(
      tags$button(
        type = "button",
        class = "btn btn-outline-secondary me-auto",
        onclick = "copyCurrentUrl()",
        bsicons::bs_icon("link-45deg"), " Copy Link"
      ),
      modalButton("Close")
    ),

    # Player info with clickable home store
    if (!is.na(player$home_store) && !is.na(player$home_store_id)) {
      p(class = "text-muted",
        bsicons::bs_icon("shop"), " Home store: ",
        actionLink(
          inputId = paste0("player_modal_store_", player$home_store_id),
          label = player$home_store,
          class = "text-primary",
          onclick = sprintf("Shiny.setInputValue('modal_store_clicked', %d, {priority: 'event'}); return false;", player$home_store_id)
        )
      )
    } else if (!is.na(player$home_store)) {
      p(class = "text-muted", bsicons::bs_icon("shop"), " Home store: ", player$home_store)
    },

    # Stats summary with Rating, Score, W-L-T colors
    div(
      class = "modal-stats-box d-flex justify-content-evenly mb-3 p-3 flex-wrap",
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", stats$events),
        div(class = "modal-stat-label", "Events")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value",
          span(class = "text-success", stats$wins %||% 0), "-",
          span(class = "text-danger", stats$losses %||% 0), "-",
          span(class = "text-warning", stats$ties %||% 0)
        ),
        div(class = "modal-stat-label", "Record")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", round(player_rating)),
        div(class = "modal-stat-label", "Rating")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", player_score),
        div(class = "modal-stat-label", "Score")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value stat-highlight place-1st", stats$first_places),
        div(class = "modal-stat-label", "1sts")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", if (!is.na(stats$avg_placement)) stats$avg_placement else "-"),
        div(class = "modal-stat-label", "Avg Place")
      )
    ),

    # Favorite decks
    if (nrow(favorite_decks) > 0) {
      tagList(
        h6(class = "modal-section-header", "Favorite Decks"),
        div(
          class = "d-flex flex-wrap gap-2 mb-3",
          lapply(1:nrow(favorite_decks), function(i) {
            deck <- favorite_decks[i, ]
            color_class <- paste0("deck-badge-", tolower(deck$color))
            div(
              class = "d-flex align-items-center gap-1",
              span(class = paste("deck-badge", color_class), deck$Deck),
              span(class = "small text-muted", sprintf("(%dx, %d wins)", deck$Times, deck$Wins))
            )
          })
        )
      )
    },

    # Recent results
    if (nrow(recent_results) > 0) {
      tagList(
        h6(class = "modal-section-header", "Recent Results"),
        tags$table(
          class = "table table-sm table-striped",
          tags$thead(
            tags$tr(
              tags$th("Date"), tags$th("Store"), tags$th("Deck"),
              tags$th("Place"), tags$th("Record"), tags$th("")
            )
          ),
          tags$tbody(
            lapply(1:nrow(recent_results), function(i) {
              row <- recent_results[i, ]
              tags$tr(
                tags$td(format(as.Date(row$Date), "%b %d")),
                tags$td(row$Store),
                tags$td(row$Deck),
                tags$td(
                  class = if (row$Place == 1) "place-1st" else if (row$Place == 2) "place-2nd" else if (row$Place == 3) "place-3rd" else "",
                  ordinal(row$Place)
                ),
                tags$td(sprintf("%d-%d", row$W, row$L)),
                tags$td(
                  if (!is.na(row$decklist_url) && nchar(row$decklist_url) > 0) {
                    tags$a(
                      href = row$decklist_url,
                      target = "_blank",
                      title = "View decklist",
                      class = "text-primary",
                      bsicons::bs_icon("list-ul")
                    )
                  }
                )
              )
            })
          )
        )
      )
    } else {
      digital_empty_state("No results recorded", "// deck data pending", "clipboard-x")
    }
  ))
})
