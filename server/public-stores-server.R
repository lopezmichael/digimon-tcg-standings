# =============================================================================
# Public: Stores Tab Server Logic
# =============================================================================
# Note: Contains modal_player_clicked handler which navigates to Players tab.
# This is kept here for now due to physical proximity; could move to shared-server.R later.
# Also contains reset_dashboard_filters which should ideally be in Dashboard server.

# Store list (uses filtered stores from map selection)
output$store_list <- renderReactable({
  rv$data_refresh  # Trigger refresh on admin changes
  stores <- filtered_stores()

  if (is.null(stores) || nrow(stores) == 0) {
    return(reactable(data.frame(Message = "No stores yet"), compact = TRUE))
  }

  # Join with store ratings
  str_ratings <- store_ratings()
  stores <- merge(stores, str_ratings, by = "store_id", all.x = TRUE)
  stores$store_rating[is.na(stores$store_rating)] <- 0

  # Format last event date
  stores$last_event_display <- sapply(stores$last_event, function(d) {
    if (is.na(d)) return("-")
    days_ago <- as.integer(Sys.Date() - as.Date(d))
    if (days_ago == 0) "Today"
    else if (days_ago == 1) "Yesterday"
    else if (days_ago <= 7) paste(days_ago, "days ago")
    else if (days_ago <= 30) paste(ceiling(days_ago / 7), "weeks ago")
    else format(as.Date(d), "%b %d")
  })

  # Format for display - include activity metrics and rating
  data <- stores[order(-stores$store_rating, -stores$tournament_count, stores$city, stores$name),
                 c("name", "city", "tournament_count", "avg_players", "store_rating", "last_event_display", "store_id")]
  names(data) <- c("Store", "City", "Events", "Avg Players", "Rating", "Last Event", "store_id")

  reactable(
    data,
    compact = TRUE,
    striped = TRUE,
    pagination = TRUE,
    defaultPageSize = 32,
    defaultSorted = list(Rating = "desc"),
    rowStyle = list(cursor = "pointer"),
    onClick = JS("function(rowInfo, column) {
      if (rowInfo) {
        Shiny.setInputValue('store_clicked', rowInfo.row.store_id, {priority: 'event'})
      }
    }"),
    columns = list(
      Store = colDef(minWidth = 180),
      City = colDef(minWidth = 100),
      Events = colDef(
        minWidth = 70,
        align = "center",
        cell = function(value) {
          if (value == 0) "-" else value
        }
      ),
      `Avg Players` = colDef(
        minWidth = 90,
        align = "center",
        cell = function(value) {
          if (value == 0) "-" else value
        }
      ),
      Rating = colDef(
        minWidth = 70,
        align = "center",
        cell = function(value) {
          if (value == 0) "-" else value
        }
      ),
      `Last Event` = colDef(minWidth = 100, align = "center"),
      store_id = colDef(show = FALSE)
    )
  )
})

# Handle store row click - open detail modal
observeEvent(input$store_clicked, {
  rv$selected_store_id <- input$store_clicked
})

# Handle cross-modal store click (from player modal, tournament modal, etc.)
observeEvent(input$modal_store_clicked, {
  removeModal()  # Close current modal
  rv$selected_store_id <- input$modal_store_clicked
  nav_select("main_content", "stores")
  rv$current_nav <- "stores"
  session$sendCustomMessage("updateSidebarNav", "nav_stores")
})

# Handle cross-modal player click (from deck modal, tournament modal, etc.)
# Note: This navigates to Players tab but is kept here due to physical proximity
observeEvent(input$modal_player_clicked, {
  removeModal()  # Close current modal
  rv$selected_player_id <- input$modal_player_clicked
  nav_select("main_content", "players")
  rv$current_nav <- "players"
  session$sendCustomMessage("updateSidebarNav", "nav_players")
})

# Render store detail modal
output$store_detail_modal <- renderUI({
  req(rv$selected_store_id)

  store_id <- rv$selected_store_id
  stores <- stores_data()
  store <- stores[stores$store_id == store_id, ]

  if (nrow(store) == 0) return(NULL)

  # Get recent tournaments at this store
  recent_tournaments <- NULL
  if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    recent_tournaments <- dbGetQuery(rv$db_con, sprintf("
      SELECT t.event_date as Date, t.event_type as Type, t.format as Format,
             t.player_count as Players, p.display_name as Winner,
             da.archetype_name as Deck, r.decklist_url
      FROM tournaments t
      LEFT JOIN results r ON t.tournament_id = r.tournament_id AND r.placement = 1
      LEFT JOIN players p ON r.player_id = p.player_id
      LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      WHERE t.store_id = %d
      ORDER BY t.event_date DESC
      LIMIT 5
    ", store_id))
  }

  # Get top players at this store
  top_players <- NULL
  if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    top_players <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.display_name as Player,
             COUNT(DISTINCT r.tournament_id) as Events,
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as Wins
      FROM players p
      JOIN results r ON p.player_id = r.player_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE t.store_id = %d
      GROUP BY p.player_id, p.display_name
      ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC, COUNT(DISTINCT r.tournament_id) DESC
      LIMIT 5
    ", store_id))
  }

  # Get store rating
  str_ratings <- store_ratings()
  store_rating <- str_ratings$store_rating[str_ratings$store_id == store_id]
  if (length(store_rating) == 0) store_rating <- 0

  # Get total unique players
  unique_players <- 0
  if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    unique_players <- dbGetQuery(rv$db_con, sprintf("
      SELECT COUNT(DISTINCT r.player_id) as cnt
      FROM results r
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE t.store_id = %d
    ", store_id))$cnt
  }

  # Get most popular deck at this store
  popular_deck <- NULL
  if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    popular_deck <- dbGetQuery(rv$db_con, sprintf("
      SELECT da.archetype_name, da.primary_color, COUNT(*) as cnt
      FROM results r
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      WHERE t.store_id = %d AND da.archetype_name != 'UNKNOWN'
      GROUP BY da.archetype_id, da.archetype_name, da.primary_color
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ", store_id))
  }

  # Format event type
  format_event_type <- function(et) {
    if (is.na(et)) return("Unknown")
    switch(et,
           "locals" = "Locals",
           "evo_cup" = "Evo Cup",
           "store_championship" = "Store Championship",
           "regional" = "Regional",
           "online" = "Online",
           et)
  }

  # Build modal content
  showModal(modalDialog(
    title = div(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("shop"),
      store$name
    ),
    size = "l",
    easyClose = TRUE,
    footer = modalButton("Close"),

    # Store info
    div(
      class = "mb-3",
      if (!is.na(store$city) && store$city != "") p(bsicons::bs_icon("geo-alt"), " ", store$city),
      if (!is.na(store$address) && store$address != "") p(class = "text-muted small", store$address),
      if (!is.na(store$website) && store$website != "") p(
        tags$a(href = store$website, target = "_blank",
               bsicons::bs_icon("globe"), " Website")
      )
    ),

    # Activity stats with Store Rating, unique players
    div(
      class = "modal-stats-box d-flex justify-content-evenly mb-3 p-3 flex-wrap",
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", if (store_rating > 0) store_rating else "-"),
        div(class = "modal-stat-label", "Store Rating")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", store$tournament_count),
        div(class = "modal-stat-label", "Events")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", unique_players),
        div(class = "modal-stat-label", "Players")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", if (store$avg_players > 0) store$avg_players else "-"),
        div(class = "modal-stat-label", "Avg Size")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value",
            if (!is.na(store$last_event)) format(as.Date(store$last_event), "%b %d") else "-"),
        div(class = "modal-stat-label", "Last Event")
      )
    ),

    # Most popular deck
    if (!is.null(popular_deck) && nrow(popular_deck) > 0) {
      div(
        class = "mb-3",
        span(class = "text-muted small", "Most played deck: "),
        span(class = paste("deck-badge deck-badge-", tolower(popular_deck$primary_color), sep = ""),
             popular_deck$archetype_name)
      )
    },

    # Recent tournaments
    if (!is.null(recent_tournaments) && nrow(recent_tournaments) > 0) {
      tagList(
        h6(class = "modal-section-header", "Recent Tournaments"),
        tags$table(
          class = "table table-sm table-striped",
          tags$thead(
            tags$tr(
              tags$th("Date"), tags$th("Type"), tags$th("Players"), tags$th("Winner"), tags$th("Deck"), tags$th("")
            )
          ),
          tags$tbody(
            lapply(1:nrow(recent_tournaments), function(i) {
              row <- recent_tournaments[i, ]
              tags$tr(
                tags$td(format(as.Date(row$Date), "%b %d")),
                tags$td(format_event_type(row$Type)),
                tags$td(row$Players),
                tags$td(if (!is.na(row$Winner)) row$Winner else "-"),
                tags$td(if (!is.na(row$Deck)) row$Deck else "-"),
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
      digital_empty_state("No tournaments recorded", "// check back soon", "calendar-x")
    },

    # Top players
    if (!is.null(top_players) && nrow(top_players) > 0) {
      tagList(
        h6(class = "modal-section-header mt-3", "Top Players at This Store"),
        tags$table(
          class = "table table-sm table-striped",
          tags$thead(
            tags$tr(
              tags$th("Player"), tags$th("Events"), tags$th("Wins")
            )
          ),
          tags$tbody(
            lapply(1:nrow(top_players), function(i) {
              row <- top_players[i, ]
              tags$tr(
                tags$td(row$Player),
                tags$td(row$Events),
                tags$td(row$Wins)
              )
            })
          )
        )
      )
    }
  ))
})

# Online Tournament Organizers section
output$online_stores_section <- renderUI({
  req(rv$db_con)

  online_stores <- dbGetQuery(rv$db_con, "
    SELECT s.store_id, s.name, s.city as region, s.website, s.schedule_info,
           COUNT(t.tournament_id) as tournament_count,
           COALESCE(ROUND(AVG(t.player_count), 1), 0) as avg_players,
           MAX(t.event_date) as last_event
    FROM stores s
    LEFT JOIN tournaments t ON s.store_id = t.store_id
    WHERE s.is_online = TRUE AND s.is_active = TRUE
    GROUP BY s.store_id, s.name, s.city, s.website, s.schedule_info
    ORDER BY s.name
  ")

  if (nrow(online_stores) == 0) {
    return(NULL)  # Don't show section if no online stores
  }

  card(
    class = "card-online mt-3",
    card_header(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("globe"),
      span("Online Tournament Organizers"),
      span(class = "small text-muted ms-auto", "Click for details")
    ),
    card_body(
      div(
        class = "row g-3",
        lapply(1:nrow(online_stores), function(i) {
          store <- online_stores[i, ]
          div(
            class = "col-md-4",
            tags$button(
              type = "button",
              class = "online-store-item p-3 h-100 w-100 text-start border-0",
              onclick = sprintf("Shiny.setInputValue('online_store_click', %d, {priority: 'event'})", store$store_id),
              h6(class = "mb-1", store$name),
              if (!is.na(store$region) && nchar(store$region) > 0)
                p(class = "text-muted small mb-1", bsicons::bs_icon("geo"), " ", store$region),
              if (!is.na(store$schedule_info) && nchar(store$schedule_info) > 0)
                p(class = "small mb-1", bsicons::bs_icon("calendar"), " ", store$schedule_info),
              if (store$tournament_count > 0)
                p(class = "small mb-0 text-primary",
                  bsicons::bs_icon("trophy"), " ", store$tournament_count, " events")
            )
          )
        })
      )
    )
  )
})

# Online store click handler
observeEvent(input$online_store_click, {
  rv$selected_online_store_id <- input$online_store_click
})

# Online store detail modal
output$online_store_detail_modal <- renderUI({
  req(rv$selected_online_store_id)

  store_id <- rv$selected_online_store_id

  store <- dbGetQuery(rv$db_con, sprintf("
    SELECT s.store_id, s.name, s.city as region, s.website, s.schedule_info,
           COUNT(t.tournament_id) as tournament_count,
           COALESCE(ROUND(AVG(t.player_count), 1), 0) as avg_players,
           MAX(t.event_date) as last_event
    FROM stores s
    LEFT JOIN tournaments t ON s.store_id = t.store_id
    WHERE s.store_id = %d
    GROUP BY s.store_id, s.name, s.city, s.website, s.schedule_info
  ", store_id))

  if (nrow(store) == 0) return(NULL)

  # Get recent tournaments
  recent_tournaments <- dbGetQuery(rv$db_con, sprintf("
    SELECT t.event_date as Date, t.event_type as Type, t.format as Format,
           t.player_count as Players, p.display_name as Winner,
           da.archetype_name as Deck
    FROM tournaments t
    LEFT JOIN results r ON t.tournament_id = r.tournament_id AND r.placement = 1
    LEFT JOIN players p ON r.player_id = p.player_id
    LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    WHERE t.store_id = %d
    ORDER BY t.event_date DESC
    LIMIT 5
  ", store_id))

  # Get top players
  top_players <- dbGetQuery(rv$db_con, sprintf("
    SELECT p.display_name as Player,
           COUNT(DISTINCT r.tournament_id) as Events,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as Wins
    FROM players p
    JOIN results r ON p.player_id = r.player_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE t.store_id = %d
    GROUP BY p.player_id, p.display_name
    ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC
    LIMIT 5
  ", store_id))

  showModal(modalDialog(
    title = div(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("globe"),
      store$name
    ),
    size = "l",
    easyClose = TRUE,
    footer = modalButton("Close"),

    # Store info
    div(
      class = "mb-3",
      if (!is.na(store$region) && store$region != "")
        p(bsicons::bs_icon("geo-alt"), " ", store$region),
      if (!is.na(store$schedule_info) && store$schedule_info != "")
        p(class = "small", bsicons::bs_icon("calendar"), " ", store$schedule_info),
      if (!is.na(store$website) && store$website != "")
        p(tags$a(href = store$website, target = "_blank",
                 bsicons::bs_icon("link-45deg"), " Website"))
    ),

    # Activity stats
    div(
      class = "modal-stats-box d-flex justify-content-evenly mb-3 p-3 flex-wrap",
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", store$tournament_count),
        div(class = "modal-stat-label", "Events")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value", if (store$avg_players > 0) store$avg_players else "-"),
        div(class = "modal-stat-label", "Avg Players")
      ),
      div(
        class = "modal-stat-item",
        div(class = "modal-stat-value",
            if (!is.na(store$last_event)) format(as.Date(store$last_event), "%b %d") else "-"),
        div(class = "modal-stat-label", "Last Event")
      )
    ),

    # Recent tournaments
    if (!is.null(recent_tournaments) && nrow(recent_tournaments) > 0) {
      tagList(
        h6(class = "modal-section-header", "Recent Tournaments"),
        reactable(recent_tournaments, compact = TRUE, striped = TRUE,
                  columns = list(
                    Date = colDef(width = 90),
                    Type = colDef(width = 80),
                    Format = colDef(width = 60),
                    Players = colDef(width = 60),
                    Winner = colDef(minWidth = 100),
                    Deck = colDef(minWidth = 100)
                  ))
      )
    } else {
      p(class = "text-muted", "No tournaments recorded yet.")
    },

    # Top players
    if (!is.null(top_players) && nrow(top_players) > 0) {
      tagList(
        h6(class = "modal-section-header mt-3", "Top Players"),
        reactable(top_players, compact = TRUE, striped = TRUE,
                  columns = list(
                    Player = colDef(minWidth = 120),
                    Events = colDef(width = 70),
                    Wins = colDef(width = 60)
                  ))
      )
    }
  ))
})

# Reactive: All stores data with activity metrics (for filtering and map)
stores_data <- reactive({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  stores <- dbGetQuery(rv$db_con, "
    SELECT s.store_id, s.name, s.address, s.city, s.latitude, s.longitude,
           s.website, s.schedule_info,
           COUNT(t.tournament_id) as tournament_count,
           COALESCE(ROUND(AVG(t.player_count), 1), 0) as avg_players,
           MAX(t.event_date) as last_event
    FROM stores s
    LEFT JOIN tournaments t ON s.store_id = t.store_id
    WHERE s.is_active = TRUE AND (s.is_online = FALSE OR s.is_online IS NULL)
    GROUP BY s.store_id, s.name, s.address, s.city, s.latitude, s.longitude,
             s.website, s.schedule_info
  ")
  stores
})

# Reactive: Filtered stores based on drawn region
filtered_stores <- reactive({
  stores <- stores_data()
  if (is.null(stores) || nrow(stores) == 0) {
    return(stores)
  }

  # If no stores are selected, return all
  if (is.null(rv$selected_store_ids) || length(rv$selected_store_ids) == 0) {
    return(stores)
  }

  # Return only selected stores
  stores[stores$store_id %in% rv$selected_store_ids, ]
})

# Apply region filter button handler
observeEvent(input$apply_region_filter, {
  stores <- stores_data()
  if (is.null(stores) || nrow(stores) == 0) {
    showNotification("No stores to filter", type = "warning")
    return()
  }

  # Filter stores with valid coordinates
  stores_with_coords <- stores[!is.na(stores$latitude) & !is.na(stores$longitude), ]
  if (nrow(stores_with_coords) == 0) {
    showNotification("No stores have coordinates", type = "warning")
    return()
  }

  # Convert stores to sf
  stores_sf <- st_as_sf(stores_with_coords, coords = c("longitude", "latitude"), crs = 4326)

  # Get drawn features as sf
  tryCatch({
    proxy <- mapboxgl_proxy("stores_map")
    drawn_sf <- get_drawn_features(proxy)
    if (is.null(drawn_sf) || nrow(drawn_sf) == 0) {
      showNotification("Draw a region on the map first", type = "warning")
      return()
    }

    # Filter to polygons only
    drawn_polygons <- drawn_sf[st_geometry_type(drawn_sf) %in% c("POLYGON", "MULTIPOLYGON"), ]
    if (nrow(drawn_polygons) == 0) {
      showNotification("Draw a polygon region on the map", type = "warning")
      return()
    }

    # Union all polygons
    region <- st_union(drawn_polygons)
    # Filter stores within the region
    within_region <- st_filter(stores_sf, region)

    if (nrow(within_region) == 0) {
      showNotification("No stores found in drawn region", type = "warning")
      return()
    }

    # Update selected store IDs
    rv$selected_store_ids <- within_region$store_id

    # Update map to highlight selected stores
    # Use a match expression to color selected stores differently
    selected_ids <- within_region$store_id
    mapboxgl_proxy("stores_map") |>
      set_paint_property(
        layer_id = "stores-layer",
        name = "circle-color",
        value = list(
          "case",
          list("in", list("get", "store_id"), list("literal", selected_ids)),
          "#16A34A",  # Green for selected
          "#999999"   # Gray for non-selected
        )
      ) |>
      set_paint_property(
        layer_id = "stores-layer",
        name = "circle-opacity",
        value = list(
          "case",
          list("in", list("get", "store_id"), list("literal", selected_ids)),
          1.0,  # Full opacity for selected
          0.4   # Faded for non-selected
        )
      )

    showNotification(sprintf("Filtered to %d stores", nrow(within_region)), type = "message")

  }, error = function(e) {
    showNotification(paste("Error applying filter:", e$message), type = "error")
  })
})

# Clear region button handler
observeEvent(input$clear_region, {
  mapboxgl_proxy("stores_map") |>
    clear_drawn_features() |>
    set_paint_property(
      layer_id = "stores-layer",
      name = "circle-color",
      value = "#F7941D"  # Reset to orange
    ) |>
    set_paint_property(
      layer_id = "stores-layer",
      name = "circle-opacity",
      value = 1  # Reset to original opacity
    )
  rv$selected_store_ids <- NULL
  showNotification("Region filter cleared", type = "message")
})

# Filter active banner for Stores tab
output$stores_filter_active_banner <- renderUI({
  if (is.null(rv$selected_store_ids) || length(rv$selected_store_ids) == 0) {
    return(NULL)
  }

  n_stores <- length(rv$selected_store_ids)

  div(
    class = "alert alert-success d-flex align-items-center mb-3",
    style = "background-color: rgba(22, 163, 74, 0.1); border-color: #16A34A; color: #166534;",
    bsicons::bs_icon("check-circle-fill"),
    span(
      class = "ms-2",
      sprintf(" Region filter active: %d store%s selected. ",
              n_stores, if (n_stores == 1) "" else "s"),
      tags$strong("Dashboard, Players, and Meta tabs are now filtered to these stores.")
    )
  )
})

# Filter badge showing how many stores are filtered
output$stores_filter_badge <- renderUI({
  all_stores <- stores_data()
  filtered <- filtered_stores()

  if (is.null(all_stores) || is.null(filtered)) return(NULL)

  total <- nrow(all_stores)
  showing <- nrow(filtered)

  if (showing < total) {
    span(
      class = "badge bg-warning text-dark",
      sprintf("Showing %d of %d stores", showing, total)
    )
  } else {
    span(class = "badge bg-secondary", sprintf("%d stores", total))
  }
})

# Region filter indicator for dashboard
output$region_filter_indicator <- renderUI({
  if (is.null(rv$selected_store_ids) || length(rv$selected_store_ids) == 0) {
    return(NULL)
  }

  # Get names of selected stores
  stores <- stores_data()
  if (is.null(stores)) return(NULL)

  selected_names <- stores$name[stores$store_id %in% rv$selected_store_ids]
  store_list <- if (length(selected_names) <= 3) {
    paste(selected_names, collapse = ", ")
  } else {
    paste(c(selected_names[1:3], sprintf("and %d more", length(selected_names) - 3)), collapse = ", ")
  }

  div(
    class = "alert alert-info d-flex justify-content-between align-items-center mb-3",
    style = "background-color: rgba(15, 76, 129, 0.1); border-color: #0F4C81; color: #0F4C81;",
    div(
      bsicons::bs_icon("funnel-fill"),
      sprintf(" Filtered by region: %s", store_list)
    ),
    actionButton("clear_region_from_dashboard", "Clear Filter",
                 class = "btn btn-sm btn-outline-primary")
  )
})

# Clear region from dashboard button
observeEvent(input$clear_region_from_dashboard, {
  mapboxgl_proxy("stores_map") |>
    clear_drawn_features() |>
    set_paint_property(
      layer_id = "stores-layer",
      name = "circle-color",
      value = "#F7941D"  # Reset to orange
    ) |>
    set_paint_property(
      layer_id = "stores-layer",
      name = "circle-opacity",
      value = 1  # Reset to original opacity
    )
  rv$selected_store_ids <- NULL
  showNotification("Region filter cleared", type = "message")
})

# Reset dashboard filters (reset to defaults: first format + locals)
# Note: This should ideally be in Dashboard server, kept here due to physical proximity
observeEvent(input$reset_dashboard_filters, {
  format_choices <- get_format_choices(rv$db_con)
  first_format <- if (length(format_choices) > 0) format_choices[1] else ""
  updateSelectInput(session, "dashboard_format", selected = first_format)
  updateSelectInput(session, "dashboard_event_type", selected = "locals")
  showNotification("Filters reset to defaults", type = "message")
})

# Stores Map
output$stores_map <- renderMapboxgl({
  stores <- stores_data()

  # Use minimal theme for map (works in both light/dark app modes)
  # Popup always uses light theme for readability

  # Default DFW center if no stores or no valid coordinates
  if (is.null(stores) || nrow(stores) == 0) {
    return(
      atom_mapgl(theme = "minimal") |>
        mapgl::set_view(center = c(-96.8, 32.8), zoom = 9) |>
        add_atom_popup_style(theme = "light") |>
        mapgl::add_draw_control(
          position = "top-left",
          freehand = TRUE,
          point = FALSE,
          line_string = FALSE,
          polygon = TRUE,
          trash = TRUE
        )
    )
  }

  # Filter to stores with coordinates
  stores_with_coords <- stores[!is.na(stores$latitude) & !is.na(stores$longitude), ]

  if (nrow(stores_with_coords) == 0) {
    return(
      atom_mapgl(theme = "minimal") |>
        mapgl::set_view(center = c(-96.8, 32.8), zoom = 9) |>
        add_atom_popup_style(theme = "light") |>
        mapgl::add_draw_control(
          position = "top-left",
          freehand = TRUE,
          point = FALSE,
          line_string = FALSE,
          polygon = TRUE,
          trash = TRUE
        )
    )
  }

  # Convert to sf object
  stores_sf <- st_as_sf(stores_with_coords, coords = c("longitude", "latitude"), crs = 4326)

  # Calculate bubble size based on tournament activity (min 8, max 20)
  max_tournaments <- max(stores_with_coords$tournament_count, na.rm = TRUE)
  if (is.na(max_tournaments) || max_tournaments == 0) max_tournaments <- 1

  stores_sf$bubble_size <- 8 + (stores_with_coords$tournament_count / max_tournaments) * 12

  # Create popup content with activity metrics
  stores_sf$popup <- sapply(1:nrow(stores_sf), function(i) {
    store <- stores_with_coords[i, ]

    # Build metrics list
    metrics <- c()
    if (!is.null(store$city) && !is.na(store$city)) {
      metrics <- c(metrics, "City" = store$city)
    }
    if (!is.na(store$tournament_count) && store$tournament_count > 0) {
      metrics <- c(metrics, "Events" = as.character(store$tournament_count))
      metrics <- c(metrics, "Avg Players" = as.character(store$avg_players))
    }

    body_parts <- c()
    if (!is.null(store$address) && !is.na(store$address) && store$address != "") {
      body_parts <- c(body_parts, store$address)
    }
    schedule_text <- parse_schedule_info(store$schedule_info)
    if (!is.null(schedule_text)) {
      body_parts <- c(body_parts, paste("<br><em>", schedule_text, "</em>"))
    }
    if (!is.na(store$last_event)) {
      days_ago <- as.integer(Sys.Date() - as.Date(store$last_event))
      last_event_text <- if (days_ago == 0) "Today" else if (days_ago == 1) "Yesterday" else paste(days_ago, "days ago")
      body_parts <- c(body_parts, paste("<br><small>Last event:", last_event_text, "</small>"))
    }
    body_text <- if (length(body_parts) > 0) paste(body_parts, collapse = "") else NULL

    atom_popup_html_metrics(
      title = store$name,
      subtitle = if (store$tournament_count > 0) "Active Game Store" else "Game Store",
      metrics = if (length(metrics) > 0) metrics else NULL,
      body = body_text,
      theme = "light"
    )
  })

  # Create the map with draw controls
  # Using minimal theme for basemap, light theme for popups
  # Bubble size based on tournament activity
  map <- atom_mapgl(theme = "minimal") |>
    add_atom_popup_style(theme = "light") |>
    mapgl::add_circle_layer(
      id = "stores-layer",
      source = stores_sf,
      circle_color = "#F7941D",
      circle_radius = list("get", "bubble_size"),
      circle_stroke_color = "#FFFFFF",
      circle_stroke_width = 2,
      circle_opacity = 0.85,
      popup = "popup"
    ) |>
    mapgl::add_draw_control(
      position = "top-left",
      freehand = TRUE,
      point = FALSE,
      line_string = FALSE,
      polygon = TRUE,
      trash = TRUE
    ) |>
    mapgl::fit_bounds(stores_sf, padding = 50)

  map
})
