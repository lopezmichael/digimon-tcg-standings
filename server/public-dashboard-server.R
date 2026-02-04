# =============================================================================
# Public: Dashboard Tab Server Logic
# =============================================================================
# Note: This file contains all Dashboard/Overview tab functionality including:
# - Context text and value boxes
# - Most popular deck and hot deck calculations
# - Recent tournaments and top players tables
# - All dashboard charts (meta share, conversion, color distribution, trends)

# ---------------------------------------------------------------------------
# Dashboard Data
# ---------------------------------------------------------------------------

# Dashboard context text (shows current filter state)
output$dashboard_context_text <- renderUI({
  format_name <- if (!is.null(input$dashboard_format) && input$dashboard_format != "") {
    # Get format display name from database
    if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
      result <- dbGetQuery(rv$db_con, sprintf(
        "SELECT display_name FROM formats WHERE format_id = '%s'",
        input$dashboard_format
      ))
      if (nrow(result) > 0) result$display_name[1] else input$dashboard_format
    } else {
      input$dashboard_format
    }
  } else {
    "All Formats"
  }

  event_name <- if (!is.null(input$dashboard_event_type) && input$dashboard_event_type != "") {
    # Format event type nicely
    formatted <- gsub("_", " ", input$dashboard_event_type)
    formatted <- gsub("\\b([a-z])", "\\U\\1", formatted, perl = TRUE)
    formatted
  } else {
    "All Events"
  }

  HTML(paste0(format_name, " <span style='opacity: 0.6;'>·</span> ", event_name))
})

# Value box outputs (filtered by format/event type)
output$total_tournaments_val <- renderText({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return("0")
  filters <- build_dashboard_filters("t")
  query <- sprintf("
    SELECT COUNT(*) as n FROM tournaments t
    WHERE 1=1 %s %s %s
  ", filters$format, filters$event_type, filters$store)
  dbGetQuery(rv$db_con, query)$n
})

output$total_players_val <- renderText({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return("0")
  filters <- build_dashboard_filters("t")
  query <- sprintf("
    SELECT COUNT(DISTINCT r.player_id) as n
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 %s %s %s
  ", filters$format, filters$event_type, filters$store)
  dbGetQuery(rv$db_con, query)$n
})

output$total_stores_val <- renderText({
  count <- 0
  if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    count <- dbGetQuery(rv$db_con, "SELECT COUNT(*) as n FROM stores WHERE is_active = TRUE")$n
  }
  count
})

output$total_decks_val <- renderText({
  count <- 0
  if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    count <- dbGetQuery(rv$db_con, "SELECT COUNT(*) as n FROM deck_archetypes WHERE is_active = TRUE")$n
  }
  count
})

# Most popular deck (Top Deck) reactive
most_popular_deck <- reactive({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  filters <- build_dashboard_filters("t")

  # Always use filtered query for consistency
  # Exclude UNKNOWN archetype from analytics
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT da.archetype_name, da.display_card_id, COUNT(r.result_id) as entries,
           ROUND(COUNT(r.result_id) * 100.0 / NULLIF(SUM(COUNT(r.result_id)) OVER(), 0), 1) as meta_share
    FROM deck_archetypes da
    JOIN results r ON da.archetype_id = r.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' %s %s %s
    GROUP BY da.archetype_id, da.archetype_name, da.display_card_id
    ORDER BY entries DESC
    LIMIT 1
  ", filters$format, filters$event_type, filters$store))

  if (nrow(result) == 0) return(NULL)
  result[1, ]
})

output$most_popular_deck_val <- renderText({
  deck <- most_popular_deck()
  if (is.null(deck)) return("--")
  deck$archetype_name
})

# Top Deck image (for new value box layout)
output$top_deck_image <- renderUI({
  deck <- most_popular_deck()
  if (is.null(deck) || is.na(deck$display_card_id) || nchar(deck$display_card_id) == 0) {
    return(NULL)
  }
  img_url <- sprintf("https://images.digimoncard.io/images/cards/%s.jpg", deck$display_card_id)
  tags$img(
    src = img_url,
    alt = deck$archetype_name
  )
})

# Top Deck meta share percentage
output$top_deck_meta_share <- renderUI({
  deck <- most_popular_deck()
  if (is.null(deck) || is.null(deck$meta_share)) return(HTML("--"))
  HTML(paste0(deck$meta_share, "% of meta"))
})

# Hot Deck calculation - compares meta share between older and newer tournaments
hot_deck <- reactive({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  filters <- build_dashboard_filters("t")

  # Get tournament count to check if we have enough data
  tournament_count <- dbGetQuery(rv$db_con, sprintf("
    SELECT COUNT(*) as n FROM tournaments t WHERE 1=1 %s %s %s
  ", filters$format, filters$event_type, filters$store))$n

  # Need at least 10 tournaments for meaningful trend data
  if (tournament_count < 10) {
    return(list(insufficient_data = TRUE, tournament_count = tournament_count))
  }

  # Get median tournament date to split into older/newer halves
  median_date <- dbGetQuery(rv$db_con, sprintf("
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY event_date) as median_date
    FROM tournaments t WHERE 1=1 %s %s %s
  ", filters$format, filters$event_type, filters$store))$median_date

  # Calculate meta share for older tournaments
  # Exclude UNKNOWN archetype from analytics
  older_meta <- dbGetQuery(rv$db_con, sprintf("
    SELECT da.archetype_name, da.display_card_id,
           ROUND(COUNT(r.result_id) * 100.0 / NULLIF(SUM(COUNT(r.result_id)) OVER(), 0), 2) as meta_share
    FROM deck_archetypes da
    JOIN results r ON da.archetype_id = r.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE t.event_date < '%s' AND da.archetype_name != 'UNKNOWN' %s %s %s
    GROUP BY da.archetype_id, da.archetype_name, da.display_card_id
  ", median_date, filters$format, filters$event_type, filters$store))

  # Calculate meta share for newer tournaments
  # Exclude UNKNOWN archetype from analytics
  newer_meta <- dbGetQuery(rv$db_con, sprintf("
    SELECT da.archetype_name, da.display_card_id,
           ROUND(COUNT(r.result_id) * 100.0 / NULLIF(SUM(COUNT(r.result_id)) OVER(), 0), 2) as meta_share
    FROM deck_archetypes da
    JOIN results r ON da.archetype_id = r.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE t.event_date >= '%s' AND da.archetype_name != 'UNKNOWN' %s %s %s
    GROUP BY da.archetype_id, da.archetype_name, da.display_card_id
  ", median_date, filters$format, filters$event_type, filters$store))

  if (nrow(older_meta) == 0 || nrow(newer_meta) == 0) {
    return(list(insufficient_data = TRUE, tournament_count = tournament_count))
  }

  # Merge and calculate delta
  merged <- merge(newer_meta, older_meta, by = c("archetype_name", "display_card_id"),
                  suffixes = c("_new", "_old"), all.x = TRUE)
  merged$meta_share_old[is.na(merged$meta_share_old)] <- 0
  merged$delta <- merged$meta_share_new - merged$meta_share_old

  # Find deck with biggest positive increase
  hot <- merged[which.max(merged$delta), ]

  if (nrow(hot) == 0 || hot$delta <= 0) {
    return(list(insufficient_data = FALSE, no_trending = TRUE))
  }

  list(
    insufficient_data = FALSE,
    archetype_name = hot$archetype_name,
    display_card_id = hot$display_card_id,
    delta = round(hot$delta, 1)
  )
})

output$hot_deck_name <- renderUI({
  hd <- hot_deck()
  if (is.null(hd)) return(HTML("<span class='vb-tracking'>--</span>"))

  if (isTRUE(hd$insufficient_data)) {
    return(HTML("<span class='vb-tracking'>Tracking...</span>"))
  }

  if (isTRUE(hd$no_trending)) {
    return(HTML("<span style='opacity: 0.7;'>No trend</span>"))
  }

  HTML(hd$archetype_name)
})

output$hot_deck_trend <- renderUI({
  hd <- hot_deck()
  if (is.null(hd)) return(HTML(""))

  if (isTRUE(hd$insufficient_data)) {
    needed <- 10 - hd$tournament_count
    return(HTML(sprintf("<span class='vb-trend-neutral'>%d more events needed</span>", needed)))
  }

  if (isTRUE(hd$no_trending)) {
    return(HTML("<span class='vb-trend-neutral'>stable meta</span>"))
  }

  HTML(sprintf("<span class='vb-trend-up'>+%s%% share</span>", hd$delta))
})

# Hot Deck card image
output$hot_deck_image <- renderUI({
  hd <- hot_deck()
  if (is.null(hd) || isTRUE(hd$insufficient_data) || isTRUE(hd$no_trending)) {
    return(NULL)
  }
  if (is.null(hd$display_card_id) || is.na(hd$display_card_id) || nchar(hd$display_card_id) == 0) {
    return(NULL)
  }
  img_url <- sprintf("https://images.digimoncard.io/images/cards/%s.jpg", hd$display_card_id)
  tags$img(
    src = img_url,
    alt = hd$archetype_name
  )
})

# Legacy output for backward compatibility (if needed elsewhere)
output$most_popular_deck_image <- renderUI({
  deck <- most_popular_deck()
  if (is.null(deck) || is.na(deck$display_card_id) || nchar(deck$display_card_id) == 0) {
    return(bsicons::bs_icon("collection", size = "2.5rem"))
  }
  img_url <- sprintf("https://images.digimoncard.io/images/cards/%s.jpg", deck$display_card_id)
  tags$img(
    src = img_url,
    class = "top-deck-image",
    alt = deck$archetype_name
  )
})

# Helper function to build dashboard filter conditions
build_dashboard_filters <- function(table_alias = "t") {
  format_filter <- if (!is.null(input$dashboard_format) && input$dashboard_format != "") {
    sprintf("AND %s.format = '%s'", table_alias, input$dashboard_format)
  } else ""

  event_type_filter <- if (!is.null(input$dashboard_event_type) && input$dashboard_event_type != "") {
    sprintf("AND %s.event_type = '%s'", table_alias, input$dashboard_event_type)
  } else ""

  store_filter <- if (!is.null(rv$selected_store_ids) && length(rv$selected_store_ids) > 0) {
    sprintf("AND %s.store_id IN (%s)", table_alias, paste(rv$selected_store_ids, collapse = ", "))
  } else ""

  list(
    format = format_filter,
    event_type = event_type_filter,
    store = store_filter,
    date = "",  # Date filter removed
    any_active = (format_filter != "" || event_type_filter != "" || store_filter != "")
  )
}

# Recent tournaments (filters by selected stores, format, date range)
# Shows Winner column, formatted Type, and Store Rating
output$recent_tournaments <- renderReactable({
  rv$data_refresh  # Trigger refresh on admin changes
  if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) return(NULL)

  filters <- build_dashboard_filters("t")

  # Query with winner (player who got placement = 1) and store_id for rating join
  query <- sprintf("
    SELECT t.tournament_id, s.store_id, s.name as Store,
           t.event_date as Date, t.player_count as Players,
           p.display_name as Winner
    FROM tournaments t
    JOIN stores s ON t.store_id = s.store_id
    LEFT JOIN results r ON t.tournament_id = r.tournament_id AND r.placement = 1
    LEFT JOIN players p ON r.player_id = p.player_id
    WHERE 1=1 %s %s %s %s
    ORDER BY t.event_date DESC
    LIMIT 10
  ", filters$store, filters$format, filters$event_type, filters$date)

  data <- dbGetQuery(rv$db_con, query)
  if (nrow(data) == 0) {
    return(reactable(data.frame(Message = "No tournaments yet"), compact = TRUE))
  }

  # Join with store ratings
  str_ratings <- store_ratings()
  data <- merge(data, str_ratings, by = "store_id", all.x = TRUE)
  data$store_rating[is.na(data$store_rating)] <- 0

  # Re-sort by date (merge may have changed order)
  data <- data[order(as.Date(data$Date), decreasing = TRUE), ]

  # Replace NA winners with "-"
  data$Winner[is.na(data$Winner)] <- "-"

  reactable(data, compact = TRUE, striped = TRUE,
    rowStyle = list(cursor = "pointer"),
    onClick = JS("function(rowInfo, column) {
      if (rowInfo) {
        Shiny.setInputValue('overview_tournament_clicked', rowInfo.row.tournament_id, {priority: 'event'})
      }
    }"),
    columns = list(
      tournament_id = colDef(show = FALSE),
      store_id = colDef(show = FALSE),
      Store = colDef(
        minWidth = 150,
        style = list(overflow = "hidden", textOverflow = "ellipsis", whiteSpace = "nowrap")
      ),
      Date = colDef(width = 100),
      Players = colDef(width = 65, align = "center"),
      Winner = colDef(width = 110),
      store_rating = colDef(
        name = "Rating",
        width = 60,
        align = "center",
        cell = function(value) if (value == 0) "-" else value
      )
    )
  )
})

# Top players (filters by selected stores, format, date range)
# Shows: Player, Events, Event Wins, Top 3, Rating (Elo), Achievement
output$top_players <- renderReactable({
  rv$data_refresh  # Trigger refresh on admin changes
  if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) return(NULL)

  filters <- build_dashboard_filters("t")

  # Query players with basic stats
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT p.player_id,
           p.display_name as Player,
           COUNT(DISTINCT r.tournament_id) as Events,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as event_wins,
           COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3_placements
    FROM players p
    JOIN results r ON p.player_id = r.player_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 %s %s %s %s
    GROUP BY p.player_id, p.display_name
    HAVING COUNT(DISTINCT r.tournament_id) > 0
  ", filters$store, filters$format, filters$event_type, filters$date))

  if (nrow(result) == 0) {
    return(reactable(data.frame(Message = "No player data yet"), compact = TRUE))
  }

  # Join with competitive ratings
  comp_ratings <- player_competitive_ratings()
  result <- merge(result, comp_ratings, by = "player_id", all.x = TRUE)
  result$competitive_rating[is.na(result$competitive_rating)] <- 1500

  # Join with achievement scores
  ach_scores <- player_achievement_scores()
  result <- merge(result, ach_scores, by = "player_id", all.x = TRUE)
  result$achievement_score[is.na(result$achievement_score)] <- 0

  # Sort by competitive rating
  result <- result[order(-result$competitive_rating), ]
  result <- head(result, 10)

  reactable(result, compact = TRUE, striped = TRUE,
    rowStyle = list(cursor = "pointer"),
    onClick = JS("function(rowInfo, column) {
      if (rowInfo) {
        Shiny.setInputValue('overview_player_clicked', rowInfo.row.player_id, {priority: 'event'})
      }
    }"),
    columns = list(
      player_id = colDef(show = FALSE),
      Player = colDef(minWidth = 120),
      Events = colDef(minWidth = 60, align = "center"),
      event_wins = colDef(name = "Wins", minWidth = 60, align = "center"),
      top3_placements = colDef(name = "Top 3", minWidth = 60, align = "center"),
      competitive_rating = colDef(
        name = "Rating",
        minWidth = 70,
        align = "center"
      ),
      achievement_score = colDef(
        name = "Achv",
        minWidth = 60,
        align = "center"
      )
    )
  )
})

# Meta Share Timeline - curved area chart showing deck popularity over time
# Shows top 5 or all decks based on toggle

output$meta_share_timeline <- renderHighchart({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) {
    return(highchart() |> hc_add_theme(hc_theme_atom_switch("light")))
  }

  chart_mode <- if (!is.null(input$dark_mode) && input$dark_mode == "dark") "dark" else "light"
  filters <- build_dashboard_filters("t")

  # Query results by week and archetype
  # Exclude UNKNOWN archetype from analytics
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT date_trunc('week', t.event_date) as week_start,
           da.archetype_name,
           da.primary_color,
           COUNT(r.result_id) as entries
    FROM results r
    JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' %s %s %s %s
    GROUP BY date_trunc('week', t.event_date), da.archetype_id, da.archetype_name, da.primary_color
    ORDER BY week_start, entries DESC
  ", filters$store, filters$format, filters$event_type, filters$date))

  if (nrow(result) == 0) {
    return(
      highchart() |>
        hc_subtitle(text = "No tournament data to display") |>
        hc_add_theme(hc_theme_atom_switch(chart_mode))
    )
  }

  # Convert dates
  if (!inherits(result$week_start, "Date")) {
    result$week_start <- as.Date(as.character(result$week_start))
  }

  # Calculate week totals for percentage
  week_totals <- aggregate(entries ~ week_start, data = result, FUN = sum)
  names(week_totals)[2] <- "week_total"

  # Calculate overall share and sort decks by color then popularity
  overall <- aggregate(entries ~ archetype_name + primary_color, data = result, FUN = sum)
  overall$overall_share <- overall$entries / sum(overall$entries) * 100

  # Sort by color order first, then by share within each color group
  color_order <- c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White", "Multi", "Other")
  overall$color_rank <- match(overall$primary_color, color_order)
  overall$color_rank[is.na(overall$color_rank)] <- 999  # Unknown colors last
  overall <- overall[order(overall$color_rank, -overall$overall_share), ]

  # Show all decks (sorted by color for visual grouping in legend)
  selected_decks <- overall$archetype_name

  # Merge with week totals
  result <- merge(result, week_totals, by = "week_start")
  result$share <- round(result$entries / result$week_total * 100, 1)

  # Get unique weeks
  weeks <- sort(unique(result$week_start))

  # Build color map for selected decks
  deck_colors <- sapply(selected_decks, function(d) {
    color_row <- overall[overall$archetype_name == d, ]
    if (nrow(color_row) > 0 && color_row$primary_color[1] %in% names(digimon_deck_colors)) {
      digimon_deck_colors[color_row$primary_color[1]]
    } else {
      "#6B7280"
    }
  })

  # Create series list for areaspline (curved area)
  series_list <- lapply(seq_along(selected_decks), function(i) {
    deck <- selected_decks[i]
    deck_data <- result[result$archetype_name == deck, ]

    # Build data points for all weeks (fill missing with 0 for continuous area)
    data_points <- sapply(weeks, function(w) {
      row <- deck_data[deck_data$week_start == w, ]
      if (nrow(row) > 0) round(row$share[1], 1) else 0
    })

    list(
      name = deck,
      data = as.list(data_points),
      color = unname(deck_colors[i])
    )
  })

  # Custom tooltip formatter: filter 0% values and sort by value descending
  tooltip_formatter <- JS("
    function() {
      var points = this.points.filter(function(p) { return p.y > 0; });
      points.sort(function(a, b) { return b.y - a.y; });
      var html = '<b>' + this.x + '</b><br/>';
      points.forEach(function(p) {
        html += '<span style=\"color:' + p.series.color + '\">\u25CF</span> ' +
                p.series.name + ': <b>' + p.y + '%</b><br/>';
      });
      if (points.length === 0) {
        html += '<em>No data for this week</em>';
      }
      return html;
    }
  ")

  # Build the chart with areaspline for smooth curves
  highchart() |>
    hc_chart(type = "areaspline") |>
    hc_plotOptions(
      areaspline = list(
        stacking = "normal",
        lineWidth = 1.5,
        fillOpacity = 0.5,
        marker = list(
          enabled = FALSE,
          symbol = "circle",
          radius = 3,
          states = list(
            hover = list(enabled = TRUE)
          )
        )
      )
    ) |>
    hc_xAxis(
      categories = format(weeks, "%b %d"),
      title = list(text = NULL),
      labels = list(
        rotation = -45,
        style = list(fontSize = "10px")
      ),
      tickmarkPlacement = "on"
    ) |>
    hc_yAxis(
      title = list(text = "Meta Share"),
      labels = list(format = "{value}%"),
      min = 0,
      max = 100
    ) |>
    hc_tooltip(
      shared = TRUE,
      crosshairs = TRUE,
      useHTML = TRUE,
      formatter = tooltip_formatter
    ) |>
    hc_legend(
      enabled = TRUE,
      layout = "vertical",
      align = "right",
      verticalAlign = "middle",
      itemStyle = list(fontSize = "10px"),
      maxHeight = 280,
      navigation = list(
        activeColor = "#0F4C81",
        inactiveColor = "#CCC"
      )
    ) |>
    hc_add_series_list(series_list) |>
    hc_add_theme(hc_theme_atom_switch(chart_mode))
})

# Reactive: Total tournaments count for current filters
filtered_tournament_count <- reactive({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(0)

  filters <- build_dashboard_filters("t")
  dbGetQuery(rv$db_con, sprintf("
    SELECT COUNT(DISTINCT tournament_id) as total
    FROM tournaments t
    WHERE 1=1 %s %s %s %s
  ", filters$store, filters$format, filters$event_type, filters$date))$total
})

# Dynamic Top Decks header showing tournament count

output$top_decks_header <- renderUI({
  total <- filtered_tournament_count()
  if (total == 0) {
    "Top Decks"
  } else {
    sprintf("Top Decks (%d Tournaments)", total)
  }
})

# Top Decks with Card Images
# Win rate = 1st place finishes / total tournaments in filter
output$top_decks_with_images <- renderUI({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) {
    return(digital_empty_state("Connection lost", "// reconnecting...", "wifi-off"))
  }

  # Build filter conditions
  filters <- build_dashboard_filters("t")
  total_tournaments <- filtered_tournament_count()

  if (total_tournaments == 0) {
    return(digital_empty_state("No tournament data", "// awaiting results", "inbox"))
  }

  # Query top decks with 1st place finishes
  # Exclude UNKNOWN archetype from analytics
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT da.archetype_name, da.display_card_id, da.primary_color,
           COUNT(r.result_id) as times_played,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as first_places
    FROM deck_archetypes da
    JOIN results r ON da.archetype_id = r.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' %s %s %s %s
    GROUP BY da.archetype_id, da.archetype_name, da.display_card_id, da.primary_color
    HAVING COUNT(r.result_id) >= 1
    ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC, COUNT(r.result_id) DESC
    LIMIT 6
  ", filters$store, filters$format, filters$event_type, filters$date))

  if (nrow(result) == 0) {
    return(digital_empty_state("No deck data found", "// expand search filters", "search"))
  }

  # Calculate win rate = 1st places / total tournaments
  result$win_rate <- round(result$first_places / total_tournaments * 100, 1)

  # Generate HTML for each deck
  deck_items <- lapply(1:nrow(result), function(i) {
    row <- result[i, ]
    # Card image URL from DigimonCard.io
    img_url <- if (!is.na(row$display_card_id) && nchar(row$display_card_id) > 0) {
      sprintf("https://images.digimoncard.io/images/cards/%s.jpg", row$display_card_id)
    } else {
      "https://images.digimoncard.io/images/cards/BT1-001.jpg"  # Fallback
    }

    # Color for the bar
    bar_color <- digimon_deck_colors[row$primary_color]
    if (is.na(bar_color)) bar_color <- "#6B7280"

    # Bar width = actual win rate percentage (absolute 0-100 scale)
    bar_width <- min(row$win_rate, 100)  # Cap at 100%

    div(class = "deck-item",
      div(class = "deck-card-img",
        tags$img(src = img_url, alt = row$archetype_name, loading = "lazy")
      ),
      div(class = "deck-info",
        div(class = "deck-name", row$archetype_name),
        div(class = "deck-bar-container",
          div(class = "deck-bar",
            style = sprintf("width: %s%%; background-color: %s;", bar_width, bar_color)
          )
        ),
        div(class = "deck-stats",
          span(class = "deck-entries", sprintf("%d wins", row$first_places)),
          span(class = "deck-pct", sprintf("%.1f%% win rate", row$win_rate))
        )
      )
    )
  })

  div(class = "top-decks-grid", deck_items)
})

# ---------------------------------------------------------------------------
# Dashboard Charts (Highcharter)
# ---------------------------------------------------------------------------

# Digimon TCG deck colors for charts
digimon_deck_colors <- c(
  "Red" = "#E5383B",
  "Blue" = "#2D7DD2",
  "Yellow" = "#F5B700",
  "Green" = "#38A169",
  "Black" = "#2D3748",
  "Purple" = "#805AD5",
  "White" = "#A0AEC0",
  "Multi" = "#EC4899",  # Pink for multi-color decks
  "Other" = "#9CA3AF"   # Gray for Other Decks category
)

# Top 3 Conversion Rate Chart (decks that make top 3 most often)
output$conversion_rate_chart <- renderHighchart({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) {
    return(highchart() |> hc_add_theme(hc_theme_atom_switch("light")))
  }

  chart_mode <- if (!is.null(input$dark_mode) && input$dark_mode == "dark") "dark" else "light"

  # Build filter conditions
  filters <- build_dashboard_filters("t")

  # Query conversion rate (top 3 finishes / total entries) - minimum 2 entries
  # Exclude UNKNOWN archetype from analytics
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT da.archetype_name as name, da.primary_color as color,
           COUNT(r.result_id) as entries,
           COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3,
           ROUND(COUNT(CASE WHEN r.placement <= 3 THEN 1 END) * 100.0 / COUNT(r.result_id), 1) as conversion
    FROM results r
    JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' %s %s %s %s
    GROUP BY da.archetype_id, da.archetype_name, da.primary_color
    HAVING COUNT(r.result_id) >= 2
    ORDER BY conversion DESC
    LIMIT 5
  ", filters$store, filters$format, filters$event_type, filters$date))

  if (nrow(result) == 0) {
    return(
      highchart() |>
        hc_subtitle(text = "Need at least 2 entries per deck") |>
        hc_add_theme(hc_theme_atom_switch(chart_mode))
    )
  }

  # Assign colors based on deck color
  result$bar_color <- sapply(result$color, function(c) {
    col <- digimon_deck_colors[c]
    if (is.na(col)) "#6B7280" else col
  })

  highchart() |>
    hc_chart(type = "bar") |>
    hc_xAxis(categories = result$name, title = list(text = NULL)) |>
    hc_yAxis(title = list(text = NULL), max = 100, labels = list(format = "{value}%")) |>
    hc_add_series(
      name = "Conversion",
      data = lapply(1:nrow(result), function(i) {
        list(y = result$conversion[i], color = result$bar_color[i],
             top3 = result$top3[i], entries = result$entries[i])
      }),
      showInLegend = FALSE,
      dataLabels = list(
        enabled = TRUE,
        format = "{y}%"
      )
    ) |>
    hc_tooltip(
      pointFormat = "<b>{point.y}%</b> top 3 rate<br/>({point.top3}/{point.entries} entries)",
      headerFormat = "<b>{point.key}</b><br/>"
    ) |>
    hc_add_theme(hc_theme_atom_switch(chart_mode))
})

# Color Distribution Bar Chart (no title)
output$color_dist_chart <- renderHighchart({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) {
    return(highchart() |> hc_add_theme(hc_theme_atom_switch("light")))
  }

  chart_mode <- if (!is.null(input$dark_mode) && input$dark_mode == "dark") "dark" else "light"

  # Build filter conditions
  filters <- build_dashboard_filters("t")

  # Query color distribution - single colors + "Multi" for dual-color decks
  # Exclude UNKNOWN archetype from analytics
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT
      CASE WHEN da.secondary_color IS NOT NULL THEN 'Multi' ELSE da.primary_color END as color,
      COUNT(r.result_id) as count
    FROM results r
    JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' %s %s %s %s
    GROUP BY CASE WHEN da.secondary_color IS NOT NULL THEN 'Multi' ELSE da.primary_color END
    ORDER BY count DESC
  ", filters$store, filters$format, filters$event_type, filters$date))

  if (nrow(result) == 0) {
    return(
      highchart() |>
        hc_add_theme(hc_theme_atom_switch(chart_mode))
    )
  }

  # Assign deck colors
  result$bar_color <- sapply(result$color, function(c) {
    col <- digimon_deck_colors[c]
    if (is.na(col)) "#6B7280" else col
  })

  highchart() |>
    hc_chart(type = "bar") |>
    hc_xAxis(categories = result$color, title = list(text = NULL), labels = list(enabled = FALSE)) |>
    hc_yAxis(title = list(text = NULL)) |>
    hc_add_series(
      name = "Entries",
      data = lapply(1:nrow(result), function(i) {
        list(y = result$count[i], color = result$bar_color[i])
      }),
      showInLegend = FALSE
    ) |>
    hc_tooltip(pointFormat = "<b>{point.y}</b> entries") |>
    hc_add_theme(hc_theme_atom_switch(chart_mode))
})

# Tournament Activity Chart (avg players per event with rolling average, no title)
output$tournaments_trend_chart <- renderHighchart({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) {
    return(highchart() |> hc_add_theme(hc_theme_atom_switch("light")))
  }

  chart_mode <- if (!is.null(input$dark_mode) && input$dark_mode == "dark") "dark" else "light"

  # Build filter conditions (no alias for this query)
  format_filter <- if (!is.null(input$dashboard_format) && input$dashboard_format != "") {
    sprintf("AND format = '%s'", input$dashboard_format)
  } else ""

  event_type_filter <- if (!is.null(input$dashboard_event_type) && input$dashboard_event_type != "") {
    sprintf("AND event_type = '%s'", input$dashboard_event_type)
  } else ""

  store_filter <- if (!is.null(rv$selected_store_ids) && length(rv$selected_store_ids) > 0) {
    sprintf("AND store_id IN (%s)", paste(rv$selected_store_ids, collapse = ", "))
  } else ""

  # Query tournaments aggregated by day with avg players
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT event_date,
           COUNT(*) as tournaments,
           ROUND(AVG(player_count), 1) as avg_players
    FROM tournaments
    WHERE 1=1 %s %s %s
    GROUP BY event_date
    ORDER BY event_date
  ", store_filter, format_filter, event_type_filter))

  if (nrow(result) == 0) {
    return(
      highchart() |>
        hc_subtitle(text = "Tournament history will appear here") |>
        hc_add_theme(hc_theme_atom_switch(chart_mode))
    )
  }

  # Convert dates - handle both Date objects and character strings
  if (!inherits(result$event_date, "Date")) {
    result$event_date <- as.Date(as.character(result$event_date))
  }

  # Calculate 7-day (weekly) rolling average
  result$rolling_avg <- sapply(1:nrow(result), function(i) {
    current_date <- result$event_date[i]
    week_ago <- current_date - 7
    # Include all data points within the last 7 days
    in_window <- result$event_date >= week_ago & result$event_date <= current_date
    round(mean(result$avg_players[in_window], na.rm = TRUE), 1)
  })

  # Convert dates to milliseconds since epoch for Highcharts
  result$timestamp <- as.numeric(result$event_date) * 86400000  # days to milliseconds

  highchart() |>
    hc_chart(type = "spline") |>
    hc_xAxis(
      type = "datetime",
      title = list(text = NULL)
    ) |>
    hc_yAxis(title = list(text = "Players"), min = 0) |>
    hc_add_series(
      name = "Daily Avg",
      data = lapply(1:nrow(result), function(i) {
        list(x = result$timestamp[i], y = result$avg_players[i], tournaments = result$tournaments[i])
      }),
      color = "#0F4C81",
      marker = list(enabled = TRUE, radius = 4)
    ) |>
    hc_add_series(
      name = "7-Day Rolling Avg",
      data = lapply(1:nrow(result), function(i) {
        list(x = result$timestamp[i], y = result$rolling_avg[i])
      }),
      color = "#F7941D",
      dashStyle = "ShortDash",
      marker = list(enabled = FALSE)
    ) |>
    hc_tooltip(
      shared = TRUE,
      crosshairs = TRUE,
      pointFormat = "<b>{series.name}:</b> {point.y} players<br/>"
    ) |>
    hc_add_theme(hc_theme_atom_switch(chart_mode))
})
