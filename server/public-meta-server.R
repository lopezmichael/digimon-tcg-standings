# =============================================================================
# Public: Meta Analysis Server Logic
# =============================================================================

# Reset meta filters
observeEvent(input$reset_meta_filters, {
  updateTextInput(session, "meta_search", value = "")
  updateSelectInput(session, "meta_format", selected = "")
  updateSelectInput(session, "meta_min_entries", selected = "")
})

# Archetype stats
output$archetype_stats <- renderReactable({
  rv$data_refresh  # Trigger refresh on admin changes
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  # Build filters
  search_filter <- if (!is.null(input$meta_search) && nchar(trimws(input$meta_search)) > 0) {
    sprintf("AND LOWER(da.archetype_name) LIKE LOWER('%%%s%%')", trimws(input$meta_search))
  } else ""

  format_filter <- if (!is.null(input$meta_format) && input$meta_format != "") {
    sprintf("AND t.format = '%s'", input$meta_format)
  } else ""

  min_entries <- as.numeric(input$meta_min_entries)
  if (is.na(min_entries)) min_entries <- 0

  # Exclude UNKNOWN archetype from analytics
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT da.archetype_id, da.archetype_name as Deck, da.primary_color as Color,
           COUNT(r.result_id) as Entries,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as '1sts',
           COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as 'Top 3s',
           ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%'
    FROM deck_archetypes da
    JOIN results r ON da.archetype_id = r.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' %s %s
    GROUP BY da.archetype_id, da.archetype_name, da.primary_color
    HAVING COUNT(r.result_id) >= %d
    ORDER BY COUNT(r.result_id) DESC, COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC
  ", search_filter, format_filter, min_entries))

  if (nrow(result) == 0) {
    return(reactable(data.frame(Message = "No decks match the current filters"), compact = TRUE))
  }

  # Calculate Meta % (share of total entries)
  total_entries <- sum(result$Entries)
  result$`Meta %` <- round(result$Entries * 100 / total_entries, 1)

  # Calculate Conv % (conversion rate: Top 3s / Entries)
  result$`Conv %` <- round(result$`Top 3s` * 100 / result$Entries, 1)

  reactable(
    result,
    compact = TRUE,
    striped = TRUE,
    pagination = TRUE,
    defaultPageSize = 32,
    rowStyle = list(cursor = "pointer"),
    onClick = JS("function(rowInfo, column) {
      if (rowInfo) {
        Shiny.setInputValue('archetype_clicked', rowInfo.row.archetype_id, {priority: 'event'})
      }
    }"),
    columns = list(
      archetype_id = colDef(show = FALSE),
      Deck = colDef(minWidth = 150),
      Color = colDef(minWidth = 80, cell = function(value) deck_color_badge(value)),
      Entries = colDef(minWidth = 70, align = "center"),
      `Meta %` = colDef(minWidth = 70, align = "center"),
      `1sts` = colDef(minWidth = 50, align = "center"),
      `Top 3s` = colDef(minWidth = 60, align = "center"),
      `Conv %` = colDef(minWidth = 70, align = "center"),
      `Win %` = colDef(minWidth = 60, align = "center")
    )
  )
})

# Handle archetype row click - open detail modal
observeEvent(input$archetype_clicked, {
  rv$selected_archetype_id <- input$archetype_clicked
})

# Render deck detail modal
output$deck_detail_modal <- renderUI({
  req(rv$selected_archetype_id)

  archetype_id <- rv$selected_archetype_id
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  # Get archetype info
  archetype <- dbGetQuery(rv$db_con, sprintf("
    SELECT archetype_name, primary_color, secondary_color, display_card_id
    FROM deck_archetypes
    WHERE archetype_id = %d
  ", archetype_id))

  if (nrow(archetype) == 0) return(NULL)

  # Get overall stats with meta share and conversion rate
  stats <- dbGetQuery(rv$db_con, sprintf("
    WITH deck_stats AS (
      SELECT COUNT(r.result_id) as entries,
             COUNT(DISTINCT r.tournament_id) as tournaments,
             COUNT(DISTINCT r.player_id) as pilots,
             ROUND(AVG(r.placement), 1) as avg_place,
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as first_places,
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3,
             ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as win_pct
      FROM results r
      WHERE r.archetype_id = %d
    ),
    total_entries AS (
      SELECT COUNT(*) as total FROM results
    )
    SELECT ds.*,
           ROUND(ds.entries * 100.0 / NULLIF(te.total, 0), 1) as meta_pct,
           ROUND(ds.top3 * 100.0 / NULLIF(ds.entries, 0), 1) as conv_pct
    FROM deck_stats ds, total_entries te
  ", archetype_id))

  # Get top pilots (include player_id for clickable links)
  top_pilots <- dbGetQuery(rv$db_con, sprintf("
    SELECT p.player_id,
           p.display_name as Player,
           COUNT(*) as Times,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as Wins,
           ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%'
    FROM results r
    JOIN players p ON r.player_id = p.player_id
    WHERE r.archetype_id = %d
    GROUP BY p.player_id, p.display_name
    ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC, COUNT(*) DESC
    LIMIT 5
  ", archetype_id))

  # Get recent results with this deck
  recent_results <- dbGetQuery(rv$db_con, sprintf("
    SELECT t.event_date as Date, s.name as Store, p.display_name as Player,
           r.placement as Place, r.wins as W, r.losses as L, r.decklist_url
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    JOIN stores s ON t.store_id = s.store_id
    JOIN players p ON r.player_id = p.player_id
    WHERE r.archetype_id = %d
    ORDER BY t.event_date DESC, r.placement ASC
    LIMIT 10
  ", archetype_id))

  # Card image URL
  card_img_url <- if (!is.na(archetype$display_card_id) && archetype$display_card_id != "") {
    sprintf("https://images.digimoncard.io/images/cards/%s.jpg", archetype$display_card_id)
  } else NULL

  # Color badge
  color_class <- paste0("deck-badge-", tolower(archetype$primary_color))

  # Build modal
  showModal(modalDialog(
    title = div(
      class = "d-flex align-items-center gap-2",
      span(class = paste("deck-badge", color_class), archetype$archetype_name)
    ),
    size = "l",
    easyClose = TRUE,
    footer = modalButton("Close"),

    # Card image and stats side by side
    div(
      class = "d-flex gap-3 mb-3",

      # Card image
      if (!is.null(card_img_url)) {
        div(
          class = "flex-shrink-0",
          tags$img(
            src = card_img_url,
            class = "rounded shadow",
            style = "width: 120px; height: auto;",
            alt = archetype$archetype_name
          )
        )
      },

      # Stats
      div(
        class = "flex-grow-1",
        div(
          class = "modal-stats-box d-flex justify-content-evenly flex-wrap p-3 h-100 align-items-center",
          div(
            class = "modal-stat-item",
            div(class = "modal-stat-value", if (!is.na(stats$meta_pct)) paste0(stats$meta_pct, "%") else "-"),
            div(class = "modal-stat-label", "Meta %")
          ),
          div(
            class = "modal-stat-item",
            div(class = "modal-stat-value", stats$pilots),
            div(class = "modal-stat-label", "Pilots")
          ),
          div(
            class = "modal-stat-item",
            div(class = "modal-stat-value stat-highlight place-1st", stats$first_places),
            div(class = "modal-stat-label", "1sts")
          ),
          div(
            class = "modal-stat-item",
            div(class = "modal-stat-value", if (!is.na(stats$conv_pct)) paste0(stats$conv_pct, "%") else "-"),
            div(class = "modal-stat-label", "Conv %")
          ),
          div(
            class = "modal-stat-item",
            div(class = "modal-stat-value", if (!is.na(stats$win_pct)) paste0(stats$win_pct, "%") else "-"),
            div(class = "modal-stat-label", "Win Rate")
          ),
          div(
            class = "modal-stat-item",
            div(class = "modal-stat-value", if (!is.na(stats$avg_place)) stats$avg_place else "-"),
            div(class = "modal-stat-label", "Avg Place")
          )
        )
      )
    ),

    # Top pilots (clickable to open player modal)
    if (nrow(top_pilots) > 0) {
      tagList(
        h6(class = "modal-section-header", "Top Pilots"),
        tags$table(
          class = "table table-sm table-striped",
          tags$thead(
            tags$tr(
              tags$th("Player"), tags$th("Times Played"), tags$th("Wins"), tags$th("Win %")
            )
          ),
          tags$tbody(
            lapply(1:nrow(top_pilots), function(i) {
              row <- top_pilots[i, ]
              tags$tr(
                tags$td(
                  tags$a(
                    href = "#",
                    class = "text-primary text-decoration-none",
                    style = "cursor: pointer;",
                    onclick = sprintf("Shiny.setInputValue('modal_player_clicked', %d, {priority: 'event'}); return false;", row$player_id),
                    row$Player
                  )
                ),
                tags$td(class = "text-center", row$Times),
                tags$td(class = "text-center", row$Wins),
                tags$td(class = "text-center", if (!is.na(row$`Win %`)) paste0(row$`Win %`, "%") else "-")
              )
            })
          )
        )
      )
    },

    # Recent results
    if (nrow(recent_results) > 0) {
      tagList(
        h6(class = "modal-section-header mt-3", "Recent Results"),
        tags$table(
          class = "table table-sm table-striped",
          tags$thead(
            tags$tr(
              tags$th("Date"), tags$th("Store"), tags$th("Player"),
              tags$th("Place"), tags$th("Record"), tags$th("")
            )
          ),
          tags$tbody(
            lapply(1:nrow(recent_results), function(i) {
              row <- recent_results[i, ]
              tags$tr(
                tags$td(format(as.Date(row$Date), "%b %d")),
                tags$td(row$Store),
                tags$td(row$Player),
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
      digital_empty_state("No tournament history", "// player data pending", "person-x")
    }
  ))
})
