# =============================================================================
# DFW Digimon TCG Tournament Tracker
# Main Shiny Application
# =============================================================================

library(shiny)
library(bslib)
library(bsicons)
library(DBI)
library(duckdb)
library(httr)
library(jsonlite)
library(reactable)
library(htmltools)
library(tidygeocoder)
library(atomtemplates)
library(sysfonts)
library(showtext)
library(mapgl)
library(sf)

# Load modules
source("R/db_connection.R")
source("R/digimoncard_api.R")

# Load environment variables
if (file.exists(".env")) {
  readRenviron(".env")
}

# Set MAPBOX_PUBLIC_TOKEN from MAPBOX_ACCESS_TOKEN if needed
# (atomtemplates uses MAPBOX_PUBLIC_TOKEN, but we have MAPBOX_ACCESS_TOKEN in .env)
if (Sys.getenv("MAPBOX_PUBLIC_TOKEN") == "" && Sys.getenv("MAPBOX_ACCESS_TOKEN") != "") {
  Sys.setenv(MAPBOX_PUBLIC_TOKEN = Sys.getenv("MAPBOX_ACCESS_TOKEN"))
}

# Setup Atom Google Fonts
setup_atom_google_fonts()

# =============================================================================
# Helper: Parse Schedule Info JSON
# =============================================================================

parse_schedule_info <- function(schedule_json) {

  if (is.null(schedule_json) || is.na(schedule_json) || schedule_json == "") {
    return(NULL)
  }

  tryCatch({
    info <- jsonlite::fromJSON(schedule_json)
    parts <- c()

    # Format days
    if (!is.null(info$digimon_days)) {
      days <- paste(info$digimon_days, collapse = ", ")
      parts <- c(parts, days)
    }

    # Add time if available
    if (!is.null(info$friday_time)) {
      parts <- c(parts, paste("Fri:", info$friday_time))
    }
    if (!is.null(info$saturday_time)) {
      parts <- c(parts, paste("Sat:", info$saturday_time))
    }
    if (!is.null(info$time)) {
      parts <- c(parts, info$time)
    }

    # Add entry fee if available
    if (!is.null(info$entry_fee)) {
      parts <- c(parts, paste("Entry:", info$entry_fee))
    }

    # Add notes if available
    if (!is.null(info$notes)) {
      parts <- c(parts, info$notes)
    }

    if (length(parts) > 0) {
      return(paste(parts, collapse = " | "))
    }
    NULL
  }, error = function(e) {
    NULL
  })
}

# =============================================================================
# Helper: Deck Color Badge Renderer
# =============================================================================

# Get badge class for a single color
get_color_class <- function(color) {
  color_lower <- tolower(trimws(color))
  switch(color_lower,
    "red" = "deck-badge deck-badge-red",
    "blue" = "deck-badge deck-badge-blue",
    "yellow" = "deck-badge deck-badge-yellow",
    "green" = "deck-badge deck-badge-green",
    "black" = "deck-badge deck-badge-black",
    "purple" = "deck-badge deck-badge-purple",
    "white" = "deck-badge deck-badge-white",
    "deck-badge"
  )
}

# Render single color badge (shows full color name)
deck_color_badge <- function(color) {
  if (is.null(color) || is.na(color) || color == "") {
    return(htmltools::span(class = "deck-badge", "-"))
  }
  # Capitalize first letter
  display_name <- paste0(toupper(substr(color, 1, 1)), tolower(substr(color, 2, nchar(color))))
  htmltools::span(class = get_color_class(color), display_name)
}

# Render dual color badge (for decks with primary + secondary color)
deck_color_badge_dual <- function(primary, secondary = NULL) {
  if (is.null(primary) || is.na(primary) || primary == "") {
    return(htmltools::span(class = "deck-badge", "-"))
  }

  if (is.null(secondary) || is.na(secondary) || secondary == "") {
    # Single color - show full name
    display_name <- paste0(toupper(substr(primary, 1, 1)), tolower(substr(primary, 2, nchar(primary))))
    return(htmltools::span(class = get_color_class(primary), display_name))
  }

  # Dual color - show as split badge with initials
  htmltools::div(
    class = "deck-badge-multi",
    htmltools::span(class = get_color_class(primary), toupper(substr(primary, 1, 1))),
    htmltools::span(class = get_color_class(secondary), toupper(substr(secondary, 1, 1)))
  )
}

# =============================================================================
# Configuration
# =============================================================================

# Admin password (in production, use environment variable)
ADMIN_PASSWORD <- Sys.getenv("ADMIN_PASSWORD", "digimon2026")

# Event type choices
EVENT_TYPES <- c(
  "Locals" = "locals",
  "Evolution Cup" = "evo_cup",
  "Store Championship" = "store_championship",
  "Regionals" = "regionals",
  "Regulation Battle" = "regulation_battle",
  "Release Event" = "release_event",
  "Other" = "other"
)

# =============================================================================
# Source Views
# =============================================================================

source("views/dashboard-ui.R", local = TRUE)
source("views/stores-ui.R", local = TRUE)
source("views/players-ui.R", local = TRUE)
source("views/meta-ui.R", local = TRUE)
source("views/tournaments-ui.R", local = TRUE)
source("views/admin-results-ui.R", local = TRUE)
source("views/admin-decks-ui.R", local = TRUE)
source("views/admin-stores-ui.R", local = TRUE)

# =============================================================================
# UI
# =============================================================================

ui <- page_fillable(
  theme = atom_dashboard_theme(),

  # Enable busy indicators (shows spinner when app is processing)
  useBusyIndicators(),

  # Custom CSS and JavaScript
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
    # JavaScript to handle active nav state
    tags$script(HTML("
      $(document).on('click', '.nav-link-sidebar', function() {
        $('.nav-link-sidebar').removeClass('active');
        $(this).addClass('active');
      });
    "))
  ),

  # Header Bar
  div(
    class = "app-header",
    div(
      class = "header-title",
      span(bsicons::bs_icon("controller"), class = "header-icon"),
      span("Digimon TCG", class = "header-title-text")
    ),
    div(
      class = "header-actions",
      actionLink("admin_login_link",
                 tagList(bsicons::bs_icon("lock"), " Admin"),
                 class = "header-action-btn"),
      input_dark_mode(id = "dark_mode", mode = "light")
    )
  ),

  # Main Layout with Sidebar
  layout_sidebar(
    fillable = TRUE,

    sidebar = sidebar(
      id = "main_sidebar",
      title = "Navigation",
      width = 220,
      bg = "#0A3055",

      # Navigation
      tags$nav(
        class = "sidebar-nav",

        actionLink("nav_dashboard",
                   tagList(bsicons::bs_icon("graph-up"), " Overview"),
                   class = "nav-link-sidebar active"),
        actionLink("nav_stores",
                   tagList(bsicons::bs_icon("geo-alt"), " Stores"),
                   class = "nav-link-sidebar"),
        actionLink("nav_players",
                   tagList(bsicons::bs_icon("people"), " Players"),
                   class = "nav-link-sidebar"),
        actionLink("nav_meta",
                   tagList(bsicons::bs_icon("stack"), " Meta Analysis"),
                   class = "nav-link-sidebar"),
        actionLink("nav_tournaments",
                   tagList(bsicons::bs_icon("trophy"), " Tournaments"),
                   class = "nav-link-sidebar"),

        # Admin Section (conditionally shown)
        conditionalPanel(
          condition = "output.is_admin",
          tags$div(class = "nav-section-label", "Admin"),
          actionLink("nav_admin_results",
                     tagList(bsicons::bs_icon("pencil-square"), " Enter Results"),
                     class = "nav-link-sidebar"),
          actionLink("nav_admin_decks",
                     tagList(bsicons::bs_icon("collection"), " Manage Decks"),
                     class = "nav-link-sidebar"),
          actionLink("nav_admin_stores",
                     tagList(bsicons::bs_icon("shop"), " Manage Stores"),
                     class = "nav-link-sidebar")
        )
      )
    ),

    # Main Content Area
    div(
      class = "main-content",

      # Hidden navset for content switching
      navset_hidden(
        id = "main_content",

        nav_panel_hidden(value = "dashboard", dashboard_ui),
        nav_panel_hidden(value = "stores", stores_ui),
        nav_panel_hidden(value = "players", players_ui),
        nav_panel_hidden(value = "meta", meta_ui),
        nav_panel_hidden(value = "tournaments", tournaments_ui),
        nav_panel_hidden(value = "admin_results", admin_results_ui),
        nav_panel_hidden(value = "admin_decks", admin_decks_ui),
        nav_panel_hidden(value = "admin_stores", admin_stores_ui)
      )
    )
  )
)

# =============================================================================
# Server
# =============================================================================

server <- function(input, output, session) {

  # ---------------------------------------------------------------------------
  # Reactive Values
  # ---------------------------------------------------------------------------

  rv <- reactiveValues(
    is_admin = FALSE,
    db_con = NULL,
    active_tournament_id = NULL,
    current_results = data.frame(),
    current_nav = "dashboard",
    selected_store_ids = NULL  # For map-based filtering
  )

  # ---------------------------------------------------------------------------
  # Database Connection
  # ---------------------------------------------------------------------------

  observe({
    rv$db_con <- connect_db()
  })

  onStop(function() {
    isolate({
      if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
        disconnect(rv$db_con)
      }
    })
  })

  # ---------------------------------------------------------------------------
  # Navigation
  # ---------------------------------------------------------------------------

  # Navigation handlers
  observeEvent(input$nav_dashboard, {
    nav_select("main_content", "dashboard")
    rv$current_nav <- "dashboard"
  })

  observeEvent(input$nav_stores, {
    nav_select("main_content", "stores")
    rv$current_nav <- "stores"
  })

  observeEvent(input$nav_players, {
    nav_select("main_content", "players")
    rv$current_nav <- "players"
  })

  observeEvent(input$nav_meta, {
    nav_select("main_content", "meta")
    rv$current_nav <- "meta"
  })

  observeEvent(input$nav_tournaments, {
    nav_select("main_content", "tournaments")
    rv$current_nav <- "tournaments"
  })

  observeEvent(input$nav_admin_results, {
    nav_select("main_content", "admin_results")
    rv$current_nav <- "admin_results"
  })

  observeEvent(input$nav_admin_decks, {
    nav_select("main_content", "admin_decks")
    rv$current_nav <- "admin_decks"
  })

  observeEvent(input$nav_admin_stores, {
    nav_select("main_content", "admin_stores")
    rv$current_nav <- "admin_stores"
  })

  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------

  # Output for conditional panel
  output$is_admin <- reactive({ rv$is_admin })
  outputOptions(output, "is_admin", suspendWhenHidden = FALSE)

  output$has_active_tournament <- reactive({ !is.null(rv$active_tournament_id) })
  outputOptions(output, "has_active_tournament", suspendWhenHidden = FALSE)

  # Login modal
  observeEvent(input$admin_login_link, {
    if (rv$is_admin) {
      # Already logged in - offer logout
      showModal(modalDialog(
        title = "Admin Session",
        "You are currently logged in as admin.",
        footer = tagList(
          actionButton("logout_btn", "Logout", class = "btn-warning"),
          modalButton("Close")
        )
      ))
    } else {
      # Show login form
      showModal(modalDialog(
        title = "Admin Login",
        passwordInput("admin_password", "Password"),
        footer = tagList(
          actionButton("login_btn", "Login", class = "btn-primary"),
          modalButton("Cancel")
        )
      ))
    }
  })

  # Handle login
  observeEvent(input$login_btn, {
    if (input$admin_password == ADMIN_PASSWORD) {
      rv$is_admin <- TRUE
      removeModal()
      showNotification("Logged in as admin", type = "message")

      # Update dropdowns with data
      updateSelectInput(session, "tournament_store",
                        choices = get_store_choices(rv$db_con))
      updateSelectInput(session, "result_deck",
                        choices = get_archetype_choices(rv$db_con))
      updateSelectizeInput(session, "result_player",
                           choices = get_player_choices(rv$db_con),
                           server = TRUE)
    } else {
      showNotification("Invalid password", type = "error")
    }
  })

  # Handle logout
  observeEvent(input$logout_btn, {
    rv$is_admin <- FALSE
    rv$active_tournament_id <- NULL
    removeModal()
    showNotification("Logged out", type = "message")
    # Navigate back to dashboard
    nav_select("main_content", "dashboard")
    rv$current_nav <- "dashboard"
  })

  # ---------------------------------------------------------------------------
  # Helper Functions
  # ---------------------------------------------------------------------------

  get_store_choices <- function(con) {
    if (is.null(con) || !dbIsValid(con)) return(c("Loading..." = ""))
    stores <- dbGetQuery(con, "SELECT store_id, name FROM stores WHERE is_active = TRUE ORDER BY name")
    choices <- setNames(stores$store_id, stores$name)
    return(choices)
  }

  get_archetype_choices <- function(con) {
    if (is.null(con) || !dbIsValid(con)) return(c("Loading..." = ""))
    archetypes <- dbGetQuery(con, "SELECT archetype_id, archetype_name FROM deck_archetypes WHERE is_active = TRUE ORDER BY archetype_name")
    choices <- setNames(archetypes$archetype_id, archetypes$archetype_name)
    return(choices)
  }

  get_player_choices <- function(con) {
    if (is.null(con) || !dbIsValid(con)) return(character(0))
    players <- dbGetQuery(con, "SELECT player_id, display_name FROM players WHERE is_active = TRUE ORDER BY display_name")
    choices <- setNames(players$player_id, players$display_name)
    return(choices)
  }

  # ---------------------------------------------------------------------------
  # Public Dashboard Data
  # ---------------------------------------------------------------------------

  # Value box outputs (text only for bslib value_box)
  output$total_tournaments_val <- renderText({
    count <- 0
    if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
      count <- dbGetQuery(rv$db_con, "SELECT COUNT(*) as n FROM tournaments")$n
    }
    count
  })

  output$total_players_val <- renderText({
    count <- 0
    if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
      count <- dbGetQuery(rv$db_con, "SELECT COUNT(*) as n FROM players")$n
    }
    count
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

  # Recent tournaments (filters by selected stores if region drawn)
  output$recent_tournaments <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Build query with optional store filter
    store_filter <- ""
    if (!is.null(rv$selected_store_ids) && length(rv$selected_store_ids) > 0) {
      store_ids <- paste(rv$selected_store_ids, collapse = ", ")
      store_filter <- sprintf("WHERE t.store_id IN (%s)", store_ids)
    }

    query <- sprintf("
      SELECT s.name as Store, t.event_date as Date, t.event_type as Type, t.player_count as Players
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      %s
      ORDER BY t.event_date DESC
      LIMIT 10
    ", store_filter)

    data <- dbGetQuery(rv$db_con, query)
    if (nrow(data) == 0) {
      data <- data.frame(Message = "No tournaments yet")
    }
    reactable(data, compact = TRUE, striped = TRUE)
  })

  # Top players (filters by selected stores if region drawn)
  output$top_players <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # If stores are selected, calculate stats only for those tournaments
    if (!is.null(rv$selected_store_ids) && length(rv$selected_store_ids) > 0) {
      store_ids <- paste(rv$selected_store_ids, collapse = ", ")
      result <- dbGetQuery(rv$db_con, sprintf("
        SELECT p.display_name as Player,
               COUNT(DISTINCT r.tournament_id) as Events,
               SUM(r.wins) as Wins,
               SUM(r.losses) as Losses,
               ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%'
        FROM players p
        JOIN results r ON p.player_id = r.player_id
        JOIN tournaments t ON r.tournament_id = t.tournament_id
        WHERE t.store_id IN (%s)
        GROUP BY p.player_id, p.display_name
        HAVING COUNT(DISTINCT r.tournament_id) > 0
        ORDER BY \"Win %%\" DESC, Events DESC
        LIMIT 10
      ", store_ids))
    } else {
      result <- dbGetQuery(rv$db_con, "
        SELECT display_name as Player, tournaments_played as Events,
               total_wins as Wins, total_losses as Losses, win_rate as 'Win %'
        FROM player_standings
        WHERE tournaments_played > 0
        ORDER BY win_rate DESC, tournaments_played DESC
        LIMIT 10
      ")
    }

    if (nrow(result) == 0) {
      result <- data.frame(Message = "No player data yet")
    }
    reactable(result, compact = TRUE, striped = TRUE)
  })

  # Meta summary (filters by selected stores if region drawn)
  output$meta_summary <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # If stores are selected, calculate stats only for those tournaments
    if (!is.null(rv$selected_store_ids) && length(rv$selected_store_ids) > 0) {
      store_ids <- paste(rv$selected_store_ids, collapse = ", ")
      result <- dbGetQuery(rv$db_con, sprintf("
        SELECT da.archetype_name as Deck, da.primary_color as Color,
               COUNT(r.result_id) as 'Times Played',
               COUNT(CASE WHEN r.placement = 1 THEN 1 END) as Wins,
               ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%'
        FROM deck_archetypes da
        JOIN results r ON da.archetype_id = r.archetype_id
        JOIN tournaments t ON r.tournament_id = t.tournament_id
        WHERE t.store_id IN (%s)
        GROUP BY da.archetype_id, da.archetype_name, da.primary_color
        HAVING COUNT(r.result_id) > 0
        ORDER BY \"Times Played\" DESC
        LIMIT 15
      ", store_ids))
    } else {
      result <- dbGetQuery(rv$db_con, "
        SELECT archetype_name as Deck, primary_color as Color,
               times_played as 'Times Played', tournament_wins as Wins, win_rate as 'Win %'
        FROM archetype_meta
        WHERE times_played > 0
        ORDER BY times_played DESC
        LIMIT 15
      ")
    }

    if (nrow(result) == 0) {
      return(reactable(data.frame(Message = "No tournament data yet"), compact = TRUE))
    }
    reactable(result, compact = TRUE, striped = TRUE,
      columns = list(
        Color = colDef(cell = function(value) deck_color_badge(value))
      )
    )
  })

  # Store list (uses filtered stores from map selection)
  output$store_list <- renderReactable({
    stores <- filtered_stores()

    if (is.null(stores) || nrow(stores) == 0) {
      return(reactable(data.frame(Message = "No stores yet"), compact = TRUE))
    }

    # Format for display
    data <- stores[order(stores$city, stores$name), c("name", "city", "address")]
    names(data) <- c("Store", "City", "Address")

    reactable(data, compact = TRUE, striped = TRUE)
  })

  # Reactive: All stores data (for filtering)
  stores_data <- reactive({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    stores <- dbGetQuery(rv$db_con, "
      SELECT store_id, name, address, city, latitude, longitude,
             website, schedule_info
      FROM stores
      WHERE is_active = TRUE
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

    # Create popup content
    stores_sf$popup <- sapply(1:nrow(stores_sf), function(i) {
      store <- stores_with_coords[i, ]
      metrics <- c()
      if (!is.null(store$city) && !is.na(store$city)) {
        metrics <- c(metrics, "City" = store$city)
      }

      body_parts <- c()
      if (!is.null(store$address) && !is.na(store$address) && store$address != "") {
        body_parts <- c(body_parts, store$address)
      }
      schedule_text <- parse_schedule_info(store$schedule_info)
      if (!is.null(schedule_text)) {
        body_parts <- c(body_parts, paste("<br><em>", schedule_text, "</em>"))
      }
      body_text <- if (length(body_parts) > 0) paste(body_parts, collapse = "") else NULL

      atom_popup_html_metrics(
        title = store$name,
        subtitle = "Game Store",
        metrics = if (length(metrics) > 0) metrics else NULL,
        body = body_text,
        theme = "light"
      )
    })

    # Create the map with draw controls
    # Using minimal theme for basemap, light theme for popups
    map <- atom_mapgl(theme = "minimal") |>
      add_atom_popup_style(theme = "light") |>
      mapgl::add_circle_layer(
        id = "stores-layer",
        source = stores_sf,
        circle_color = "#F7941D",
        circle_radius = 10,
        circle_stroke_color = "#FFFFFF",
        circle_stroke_width = 2,
        circle_opacity = 1,
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

  # Player standings
  output$player_standings <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)
    result <- dbGetQuery(rv$db_con, "
      SELECT display_name as Player, tournaments_played as Events,
             total_wins as W, total_losses as L, total_ties as T,
             win_rate as 'Win %', first_place_finishes as '1st', top4_finishes as 'Top 4'
      FROM player_standings
      WHERE tournaments_played > 0
      ORDER BY first_place_finishes DESC, win_rate DESC
    ")
    if (nrow(result) == 0) {
      result <- data.frame(Message = "No player data yet")
    }
    reactable(result, compact = TRUE, striped = TRUE, pagination = TRUE, defaultPageSize = 20)
  })

  # Archetype stats
  output$archetype_stats <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)
    result <- dbGetQuery(rv$db_con, "
      SELECT archetype_name as Deck, primary_color as Color,
             times_played as Entries, avg_placement as 'Avg Place',
             tournament_wins as '1st Places', win_rate as 'Match Win %'
      FROM archetype_meta
      ORDER BY times_played DESC, tournament_wins DESC
    ")
    if (nrow(result) == 0) {
      return(reactable(data.frame(Message = "No tournament data yet. Add tournament results to see meta analysis."), compact = TRUE))
    }
    reactable(result, compact = TRUE, striped = TRUE,
      columns = list(
        Color = colDef(cell = function(value) deck_color_badge(value))
      )
    )
  })

  # Tournament history
  output$tournament_history <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)
    result <- dbGetQuery(rv$db_con, "
      SELECT t.event_date as Date, s.name as Store, t.event_type as Type,
             t.player_count as Players, t.rounds as Rounds
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      ORDER BY t.event_date DESC
    ")
    if (nrow(result) == 0) {
      result <- data.frame(Message = "No tournaments recorded yet")
    }
    reactable(result, compact = TRUE, striped = TRUE, pagination = TRUE, defaultPageSize = 20)
  })

  # ---------------------------------------------------------------------------
  # Admin - Tournament Entry
  # ---------------------------------------------------------------------------

  output$active_tournament_info <- renderText({
    if (is.null(rv$active_tournament_id)) {
      return("No active tournament. Create one to start entering results.")
    }

    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return("Database not connected")

    info <- dbGetQuery(rv$db_con, sprintf("
      SELECT t.tournament_id, s.name as store_name, t.event_date, t.event_type, t.player_count
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      WHERE t.tournament_id = %d
    ", rv$active_tournament_id))

    if (nrow(info) == 0) return("Tournament not found")

    sprintf("Tournament #%d\n%s\n%s (%s)\nExpected players: %d",
            info$tournament_id, info$store_name, info$event_date, info$event_type, info$player_count)
  })

  # Create tournament
  observeEvent(input$create_tournament, {
    req(rv$is_admin, rv$db_con)

    store_id <- as.integer(input$tournament_store)
    event_date <- as.character(input$tournament_date)
    event_type <- input$tournament_type
    player_count <- input$tournament_players
    rounds <- input$tournament_rounds

    tryCatch({
      # Get next ID
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(tournament_id), 0) as max_id FROM tournaments")$max_id
      new_id <- max_id + 1

      dbExecute(rv$db_con, "
        INSERT INTO tournaments (tournament_id, store_id, event_date, event_type, player_count, rounds)
        VALUES (?, ?, ?, ?, ?, ?)
      ", params = list(new_id, store_id, event_date, event_type, player_count, rounds))

      rv$active_tournament_id <- new_id
      rv$current_results <- data.frame()

      showNotification("Tournament created!", type = "message")

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Clear tournament
  observeEvent(input$clear_tournament, {
    rv$active_tournament_id <- NULL
    rv$current_results <- data.frame()
  })

  # Add result
  add_result_logic <- function() {
    req(rv$is_admin, rv$db_con, rv$active_tournament_id)

    player_input <- input$result_player
    archetype_id <- as.integer(input$result_deck)
    placement <- input$result_placement
    wins <- input$result_wins
    losses <- input$result_losses
    ties <- input$result_ties
    decklist_url <- if (nchar(input$result_decklist_url) > 0) input$result_decklist_url else NULL

    tryCatch({
      # Check if player exists or create new
      if (grepl("^\\d+$", player_input)) {
        # Existing player selected (numeric ID)
        player_id <- as.integer(player_input)
      } else {
        # New player name entered
        max_player_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(player_id), 0) as max_id FROM players")$max_id
        player_id <- max_player_id + 1

        dbExecute(rv$db_con, "
          INSERT INTO players (player_id, display_name) VALUES (?, ?)
        ", params = list(player_id, player_input))

        # Update player choices
        updateSelectizeInput(session, "result_player",
                             choices = get_player_choices(rv$db_con),
                             server = TRUE)
      }

      # Get next result ID
      max_result_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(result_id), 0) as max_id FROM results")$max_id
      result_id <- max_result_id + 1

      # Insert result
      dbExecute(rv$db_con, "
        INSERT INTO results (result_id, tournament_id, player_id, archetype_id, placement, wins, losses, ties, decklist_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", params = list(result_id, rv$active_tournament_id, player_id, archetype_id, placement, wins, losses, ties, decklist_url))

      showNotification("Result added!", type = "message")

      # Reset form for next entry
      updateNumericInput(session, "result_placement", value = placement + 1)
      updateNumericInput(session, "result_wins", value = 0)
      updateNumericInput(session, "result_losses", value = 0)
      updateNumericInput(session, "result_ties", value = 0)
      updateTextInput(session, "result_decklist_url", value = "")
      updateSelectizeInput(session, "result_player", selected = "")

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  }

  observeEvent(input$add_result, { add_result_logic() })
  observeEvent(input$add_result_another, { add_result_logic() })

  # Display current results
  output$current_results <- renderReactable({
    req(rv$db_con, rv$active_tournament_id)

    results <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.display_name as Player, da.archetype_name as Deck,
             r.placement as Place, r.wins as W, r.losses as L, r.ties as T
      FROM results r
      JOIN players p ON r.player_id = p.player_id
      LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      WHERE r.tournament_id = %d
      ORDER BY r.placement
    ", rv$active_tournament_id))

    if (nrow(results) == 0) {
      results <- data.frame(Message = "No results entered yet")
    }
    reactable(results, compact = TRUE, striped = TRUE)
  })

  # Finish tournament
  observeEvent(input$finish_tournament, {
    rv$active_tournament_id <- NULL
    rv$current_results <- data.frame()
    showNotification("Tournament complete! Results saved.", type = "message")
  })

  # ---------------------------------------------------------------------------
  # Admin - Deck Management
  # ---------------------------------------------------------------------------

  # Card search
  observeEvent(input$search_card_btn, {
    req(input$card_search)

    cards <- search_by_name(input$card_search)

    if (is.null(cards) || nrow(cards) == 0) {
      output$card_search_results <- renderUI({
        div(class = "alert alert-warning", "No cards found")
      })
      return()
    }

    # Limit to first 6 results
    cards <- head(cards, 6)

    output$card_search_results <- renderUI({
      div(
        style = "display: flex; flex-wrap: wrap; gap: 10px; margin-top: 10px;",
        lapply(1:nrow(cards), function(i) {
          card <- cards[i, ]
          div(
            style = "text-align: center; cursor: pointer; padding: 5px; border: 1px solid #ddd; border-radius: 4px;",
            onclick = sprintf("Shiny.setInputValue('select_card', '%s', {priority: 'event'})", card$cardnumber),
            img(src = get_card_image_url(card$cardnumber),
                style = "max-width: 80px; max-height: 110px;",
                onerror = "this.style.display='none'"),
            div(card$cardnumber, style = "font-size: 11px;"),
            div(substr(card$name, 1, 15), style = "font-size: 10px;")
          )
        })
      )
    })
  })

  # Handle card selection
  observeEvent(input$select_card, {
    updateTextInput(session, "selected_card_id", value = input$select_card)
  })

  # Preview selected card
  output$selected_card_preview <- renderUI({
    req(input$selected_card_id)
    if (nchar(input$selected_card_id) < 3) return(NULL)

    img_url <- get_card_image_url(input$selected_card_id)
    div(
      style = "margin-top: 10px;",
      img(src = img_url, class = "card-image", onerror = "this.style.display='none'"),
      div(paste("Card:", input$selected_card_id))
    )
  })

  # Add archetype
  observeEvent(input$add_archetype, {
    req(rv$is_admin, rv$db_con)
    req(input$deck_name)

    name <- trimws(input$deck_name)
    primary_color <- input$deck_primary_color
    secondary_color <- if (input$deck_secondary_color == "") NULL else input$deck_secondary_color
    card_id <- if (nchar(input$selected_card_id) > 0) input$selected_card_id else NULL

    tryCatch({
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(archetype_id), 0) as max_id FROM deck_archetypes")$max_id
      new_id <- max_id + 1

      dbExecute(rv$db_con, "
        INSERT INTO deck_archetypes (archetype_id, archetype_name, display_card_id, primary_color, secondary_color)
        VALUES (?, ?, ?, ?, ?)
      ", params = list(new_id, name, card_id, primary_color, secondary_color))

      showNotification(paste("Added archetype:", name), type = "message")

      # Clear form
      updateTextInput(session, "deck_name", value = "")
      updateTextInput(session, "selected_card_id", value = "")
      updateTextInput(session, "card_search", value = "")
      output$card_search_results <- renderUI({ NULL })

      # Update archetype dropdown
      updateSelectInput(session, "result_deck", choices = get_archetype_choices(rv$db_con))

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Archetype list
  output$archetype_list <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Trigger refresh when archetype added
    input$add_archetype

    data <- dbGetQuery(rv$db_con, "
      SELECT archetype_name as Deck, primary_color, secondary_color, display_card_id as 'Card ID'
      FROM deck_archetypes
      WHERE is_active = TRUE
      ORDER BY archetype_name
    ")
    if (nrow(data) == 0) {
      return(reactable(data.frame(Message = "No archetypes yet"), compact = TRUE))
    }
    reactable(data, compact = TRUE, striped = TRUE,
      columns = list(
        primary_color = colDef(
          name = "Color",
          cell = function(value, index) {
            secondary <- data$secondary_color[index]
            deck_color_badge_dual(value, secondary)
          }
        ),
        secondary_color = colDef(show = FALSE)
      )
    )
  })

  # ---------------------------------------------------------------------------
  # Admin - Store Management
  # ---------------------------------------------------------------------------

  # Add store
  observeEvent(input$add_store, {
    req(rv$is_admin, rv$db_con)
    req(input$store_name, input$store_city)

    tryCatch({
      # Build full address for geocoding
      address_parts <- c(input$store_address, input$store_city)
      if (exists("input$store_state") && nchar(input$store_state) > 0) {
        address_parts <- c(address_parts, input$store_state)
      } else {
        address_parts <- c(address_parts, "TX")
      }
      if (exists("input$store_zip") && nchar(input$store_zip) > 0) {
        address_parts <- c(address_parts, input$store_zip)
      }
      full_address <- paste(address_parts, collapse = ", ")

      # Geocode the address
      showNotification("Geocoding address...", type = "message", duration = 2)
      geo_result <- tidygeocoder::geo(full_address, method = "osm", quiet = TRUE)

      lat <- geo_result$lat
      lng <- geo_result$long

      if (is.na(lat) || is.na(lng)) {
        showNotification("Could not geocode address. Store added without coordinates.", type = "warning")
        lat <- NULL
        lng <- NULL
      }

      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(store_id), 0) as max_id FROM stores")$max_id
      new_id <- max_id + 1

      schedule_info <- if (nchar(input$store_schedule) > 0) input$store_schedule else NULL
      website <- if (nchar(input$store_website) > 0) input$store_website else NULL
      zip_code <- if (exists("input$store_zip") && nchar(input$store_zip) > 0) input$store_zip else NULL
      state <- if (exists("input$store_state")) input$store_state else "TX"

      dbExecute(rv$db_con, "
        INSERT INTO stores (store_id, name, address, city, state, zip_code, latitude, longitude, website, schedule_info)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", params = list(new_id, input$store_name, input$store_address, input$store_city,
                       state, zip_code, lat, lng, website, schedule_info))

      showNotification(paste("Added store:", input$store_name), type = "message")

      # Clear form
      updateTextInput(session, "store_name", value = "")
      updateTextInput(session, "store_address", value = "")
      updateTextInput(session, "store_city", value = "")
      updateTextInput(session, "store_zip", value = "")
      updateTextInput(session, "store_website", value = "")
      updateTextAreaInput(session, "store_schedule", value = "")

      # Update store dropdown
      updateSelectInput(session, "tournament_store", choices = get_store_choices(rv$db_con))

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Admin store list
  output$admin_store_list <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Trigger refresh
    input$add_store

    data <- dbGetQuery(rv$db_con, "
      SELECT name as Store, city as City, latitude as Lat, longitude as Lng
      FROM stores
      WHERE is_active = TRUE
      ORDER BY name
    ")
    if (nrow(data) == 0) {
      data <- data.frame(Message = "No stores yet")
    }
    reactable(data, compact = TRUE, striped = TRUE)
  })
}

# =============================================================================
# Run App
# =============================================================================

shinyApp(ui = ui, server = server)
