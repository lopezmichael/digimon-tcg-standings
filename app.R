# =============================================================================
# DFW Digimon TCG Tournament Tracker
# Main Shiny Application
# =============================================================================

library(shiny)
library(shinyjs)
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
library(highcharter)
library(brand.yml)

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
    "multi" = "deck-badge deck-badge-multi-color",
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

# Format/Set choices (most recent first)
# Update this list when new sets release
FORMAT_CHOICES <- c(
  "BT19 (Xros Encounter)" = "BT19",
  "EX08 (New Awakening)" = "EX08",
  "BT18 (Dimensional Phase)" = "BT18",
  "EX07 (Digimon Liberator)" = "EX07",
  "BT17 (Secret Crisis)" = "BT17",
  "ST19/ST20 (Fable Waltz)" = "ST19",
  "BT16 (Beginning Observer)" = "BT16",
  "EX06 (Infernal Ascension)" = "EX06",
  "BT15 (Exceed Apocalypse)" = "BT15",
  "Older Format" = "older"
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
source("views/admin-formats-ui.R", local = TRUE)

# =============================================================================
# UI
# =============================================================================

ui <- page_fillable(
  theme = atom_dashboard_theme(),

  # Enable busy indicators (shows spinner when app is processing)
  useBusyIndicators(),

  # Enable shinyjs for show/hide functionality
  useShinyjs(),

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
                     class = "nav-link-sidebar"),
          actionLink("nav_admin_formats",
                     tagList(bsicons::bs_icon("calendar3"), " Manage Formats"),
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
        nav_panel_hidden(value = "admin_stores", admin_stores_ui),
        nav_panel_hidden(value = "admin_formats", admin_formats_ui)
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
    selected_store_ids = NULL,  # For map-based filtering
    selected_store_detail = NULL,  # For store detail modal
    selected_player_id = NULL,  # For player profile modal
    selected_archetype_id = NULL,  # For deck profile modal
    selected_tournament_id = NULL,  # For tournament detail modal
    card_search_results = NULL,  # For card search in deck management
    editing_store = NULL,  # For edit mode
    editing_archetype = NULL,  # For edit mode
    wizard_step = 1,  # Wizard navigation: 1 = Details, 2 = Results
    duplicate_tournament = NULL,  # Store duplicate tournament info for modal
    results_refresh = 0,  # Trigger to refresh results table
    card_search_page = 1  # Current page for card search pagination
  )

  # Helper function for ordinal numbers (1st, 2nd, 3rd, etc.)
  ordinal <- function(n) {
    if (is.na(n)) return("-")
    suffix <- c("th", "st", "nd", "rd", rep("th", 6))
    if (n %% 100 >= 11 && n %% 100 <= 13) {
      paste0(n, "th")
    } else {
      paste0(n, suffix[(n %% 10) + 1])
    }
  }

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

  observeEvent(input$nav_admin_formats, {
    nav_select("main_content", "admin_formats")
    rv$current_nav <- "admin_formats"
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
      updateSelectizeInput(session, "result_deck",
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

  get_format_choices <- function(con) {
    if (is.null(con) || !dbIsValid(con)) return(FORMAT_CHOICES)
    formats <- dbGetQuery(con, "
      SELECT format_id, display_name
      FROM formats
      WHERE is_active = TRUE
      ORDER BY sort_order
    ")
    if (nrow(formats) == 0) return(FORMAT_CHOICES)
    choices <- setNames(formats$format_id, formats$display_name)
    return(choices)
  }

  # Update format dropdowns when database connects or formats change
  observe({
    # Trigger on db connection and format refresh
    rv$db_con
    rv$format_refresh

    if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
      format_choices <- get_format_choices(rv$db_con)
      first_format <- if (length(format_choices) > 0) format_choices[1] else ""

      # Update dashboard format dropdown
      updateSelectInput(session, "dashboard_format",
                        choices = list(
                          "All Formats" = "",
                          "Recent Formats" = format_choices
                        ))

      # Update tournament format dropdown
      updateSelectInput(session, "tournament_format",
                        choices = format_choices)
    }
  })

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

  # Most popular deck value box
  most_popular_deck <- reactive({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    filters <- build_dashboard_filters("t")

    if (filters$any_active) {
      result <- dbGetQuery(rv$db_con, sprintf("
        SELECT da.archetype_name, da.display_card_id, COUNT(r.result_id) as entries
        FROM deck_archetypes da
        JOIN results r ON da.archetype_id = r.archetype_id
        JOIN tournaments t ON r.tournament_id = t.tournament_id
        WHERE 1=1 %s %s %s %s
        GROUP BY da.archetype_id, da.archetype_name, da.display_card_id
        ORDER BY entries DESC
        LIMIT 1
      ", filters$store, filters$format, filters$event_type, filters$date))
    } else {
      result <- dbGetQuery(rv$db_con, "
        SELECT archetype_name, display_card_id, times_played as entries
        FROM archetype_meta
        WHERE times_played > 0
        ORDER BY times_played DESC
        LIMIT 1
      ")
    }

    if (nrow(result) == 0) return(NULL)
    result[1, ]
  })

  output$most_popular_deck_val <- renderText({
    deck <- most_popular_deck()
    if (is.null(deck)) return("--")
    deck$archetype_name
  })

  output$most_popular_deck_image <- renderUI({
    deck <- most_popular_deck()
    if (is.null(deck) || is.na(deck$display_card_id) || nchar(deck$display_card_id) == 0) {
      return(bsicons::bs_icon("collection", size = "2.5rem"))
    }
    img_url <- sprintf("https://images.digimoncard.io/images/cards/%s.jpg", deck$display_card_id)
    tags$img(
      src = img_url,
      style = "height: 85px; width: auto; border-radius: 6px; object-fit: contain; box-shadow: 0 2px 8px rgba(0,0,0,0.2);",
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
  # Shows Winner column and formatted Type (no Format column)
  output$recent_tournaments <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    filters <- build_dashboard_filters("t")

    # Query with winner (player who got placement = 1)
    query <- sprintf("
      SELECT s.name as Store, t.event_date as Date, t.event_type as Type,
             t.player_count as Players, p.display_name as Winner
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

    # Format event type nicely
    event_type_labels <- c(
      "locals" = "Locals",
      "evo_cup" = "Evo Cup",
      "store_championship" = "Store Champ",
      "regionals" = "Regionals",
      "regulation_battle" = "Reg Battle",
      "release_event" = "Release",
      "other" = "Other"
    )
    data$Type <- sapply(data$Type, function(t) {
      if (t %in% names(event_type_labels)) event_type_labels[t] else t
    })

    # Replace NA winners with "-"
    data$Winner[is.na(data$Winner)] <- "-"

    reactable(data, compact = TRUE, striped = TRUE,
      columns = list(
        Store = colDef(minWidth = 120),
        Date = colDef(minWidth = 90),
        Type = colDef(minWidth = 80),
        Players = colDef(minWidth = 60, align = "center"),
        Winner = colDef(minWidth = 100)
      )
    )
  })

  # Top players (filters by selected stores, format, date range)
  # Shows: Player, Events, Event Wins, Top 3 Placements, Rating (with tooltip)
  output$top_players <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    filters <- build_dashboard_filters("t")

    # Query players with stats needed for weighted rating
    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.display_name as Player,
             COUNT(DISTINCT r.tournament_id) as Events,
             SUM(r.wins) as total_wins,
             SUM(r.losses) as total_losses,
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as event_wins,
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3_placements,
             ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as win_pct
      FROM players p
      JOIN results r ON p.player_id = r.player_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s %s %s
      GROUP BY p.player_id, p.display_name
      HAVING COUNT(DISTINCT r.tournament_id) > 0
      ORDER BY COUNT(DISTINCT r.tournament_id) DESC
      LIMIT 20
    ", filters$store, filters$format, filters$event_type, filters$date))

    if (nrow(result) == 0) {
      return(reactable(data.frame(Message = "No player data yet"), compact = TRUE))
    }

    # Handle NA win percentages
    result$win_pct[is.na(result$win_pct)] <- 0

    # Calculate weighted rating: (win% * 0.5) + (top3_rate * 30) + (events_bonus)
    # This rewards consistent performance, top finishes, and attendance
    result$top3_rate <- result$top3_placements / result$Events
    result$events_bonus <- pmin(result$Events * 2, 20)  # Cap at 20 points
    result$weighted_rating <- round(
      (result$win_pct * 0.5) +           # 50% weight on win rate
      (result$top3_rate * 30) +          # 30 points max for top 3 rate
      result$events_bonus,               # Up to 20 points for attendance
      1
    )

    # Sort by weighted rating
    result <- result[order(-result$weighted_rating), ]
    result <- head(result, 10)

    reactable(result, compact = TRUE, striped = TRUE,
      columns = list(
        Player = colDef(minWidth = 120),
        Events = colDef(minWidth = 60, align = "center"),
        total_wins = colDef(show = FALSE),
        total_losses = colDef(show = FALSE),
        event_wins = colDef(name = "Event Wins", minWidth = 80, align = "center"),
        top3_placements = colDef(name = "Top 3", minWidth = 60, align = "center"),
        win_pct = colDef(show = FALSE),
        top3_rate = colDef(show = FALSE),
        events_bonus = colDef(show = FALSE),
        weighted_rating = colDef(
          name = "Rating",
          minWidth = 70,
          align = "center",
          cell = function(value) sprintf("%.1f", value)
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
    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT date_trunc('week', t.event_date) as week_start,
             da.archetype_name,
             da.primary_color,
             COUNT(r.result_id) as entries
      FROM results r
      JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s %s %s
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

    # Calculate overall share and sort decks by popularity
    overall <- aggregate(entries ~ archetype_name + primary_color, data = result, FUN = sum)
    overall$overall_share <- overall$entries / sum(overall$entries) * 100
    overall <- overall[order(-overall$overall_share), ]

    # Show all decks (sorted by overall popularity for legend order)
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
        min = 0
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
      return(div(class = "text-muted", "No data available"))
    }

    # Build filter conditions
    filters <- build_dashboard_filters("t")
    total_tournaments <- filtered_tournament_count()

    if (total_tournaments == 0) {
      return(div(class = "text-muted text-center p-4", "No tournament data yet"))
    }

    # Query top decks with 1st place finishes
    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT da.archetype_name, da.display_card_id, da.primary_color,
             COUNT(r.result_id) as times_played,
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as first_places
      FROM deck_archetypes da
      JOIN results r ON da.archetype_id = r.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s %s %s
      GROUP BY da.archetype_id, da.archetype_name, da.display_card_id, da.primary_color
      HAVING COUNT(r.result_id) >= 1
      ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC, COUNT(r.result_id) DESC
      LIMIT 8
    ", filters$store, filters$format, filters$event_type, filters$date))

    if (nrow(result) == 0) {
      return(div(class = "text-muted text-center p-4", "No tournament data yet"))
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
    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT da.archetype_name as name, da.primary_color as color,
             COUNT(r.result_id) as entries,
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3,
             ROUND(COUNT(CASE WHEN r.placement <= 3 THEN 1 END) * 100.0 / COUNT(r.result_id), 1) as conversion
      FROM results r
      JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s %s %s
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
    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT
        CASE WHEN da.secondary_color IS NOT NULL THEN 'Multi' ELSE da.primary_color END as color,
        COUNT(r.result_id) as count
      FROM results r
      JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s %s %s
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
      hc_xAxis(categories = result$color, title = list(text = NULL)) |>
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

    # Query tournaments aggregated by week with avg players
    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT date_trunc('week', event_date) as week_start,
             COUNT(*) as tournaments,
             ROUND(AVG(player_count), 1) as avg_players
      FROM tournaments
      WHERE 1=1 %s %s %s
      GROUP BY date_trunc('week', event_date)
      ORDER BY week_start
    ", store_filter, format_filter, event_type_filter))

    if (nrow(result) == 0) {
      return(
        highchart() |>
          hc_subtitle(text = "Tournament history will appear here") |>
          hc_add_theme(hc_theme_atom_switch(chart_mode))
      )
    }

    # Convert dates - handle both Date objects and character strings
    if (!inherits(result$week_start, "Date")) {
      result$week_start <- as.Date(as.character(result$week_start))
    }

    # Calculate 4-week rolling average
    result$rolling_avg <- sapply(1:nrow(result), function(i) {
      start_idx <- max(1, i - 3)  # Look back 3 weeks (4 week window)
      round(mean(result$avg_players[start_idx:i], na.rm = TRUE), 1)
    })

    # Convert dates to milliseconds since epoch for Highcharts
    result$timestamp <- as.numeric(result$week_start) * 86400000  # days to milliseconds

    highchart() |>
      hc_chart(type = "spline") |>
      hc_xAxis(
        type = "datetime",
        title = list(text = NULL)
      ) |>
      hc_yAxis(title = list(text = "Players"), min = 0) |>
      hc_add_series(
        name = "Avg Players",
        data = lapply(1:nrow(result), function(i) {
          list(x = result$timestamp[i], y = result$avg_players[i], tournaments = result$tournaments[i])
        }),
        color = "#0F4C81",
        marker = list(enabled = TRUE, radius = 4)
      ) |>
      hc_add_series(
        name = "4-Week Rolling Avg",
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

  # Store list (uses filtered stores from map selection)
  output$store_list <- renderReactable({
    stores <- filtered_stores()

    if (is.null(stores) || nrow(stores) == 0) {
      return(reactable(data.frame(Message = "No stores yet"), compact = TRUE))
    }

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

    # Format for display - include activity metrics
    data <- stores[order(-stores$tournament_count, stores$city, stores$name),
                   c("name", "city", "tournament_count", "avg_players", "last_event_display")]
    names(data) <- c("Store", "City", "Events", "Avg Players", "Last Event")

    # Store the store_id for row click handling
    data$store_id <- stores[order(-stores$tournament_count, stores$city, stores$name), "store_id"]

    reactable(
      data,
      compact = TRUE,
      striped = TRUE,
      selection = "single",
      onClick = "select",
      defaultSorted = list(Events = "desc"),
      rowStyle = list(cursor = "pointer"),
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
        `Last Event` = colDef(minWidth = 100, align = "center"),
        store_id = colDef(show = FALSE)  # Hidden column for ID
      )
    )
  })

  # Handle store row selection - open detail modal
  observeEvent(getReactableState("store_list", "selected"), {
    selected_row <- getReactableState("store_list", "selected")
    if (is.null(selected_row) || length(selected_row) == 0) return()

    # Get store data
    stores <- filtered_stores()
    if (is.null(stores)) return()

    # Sort the same way as the table to get correct row
    sorted_stores <- stores[order(-stores$tournament_count, stores$city, stores$name), ]
    selected_store <- sorted_stores[selected_row, ]

    rv$selected_store_detail <- selected_store$store_id
  })

  # Render store detail modal
  output$store_detail_modal <- renderUI({
    req(rv$selected_store_detail)

    store_id <- rv$selected_store_detail
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

      # Activity stats
      div(
        class = "d-flex justify-content-evenly mb-3 p-3 bg-light rounded",
        div(
          class = "text-center px-3",
          div(class = "h4 mb-0 text-primary", store$tournament_count),
          div(class = "small text-muted", "Events")
        ),
        div(
          class = "text-center px-3",
          div(class = "h4 mb-0 text-primary", if (store$avg_players > 0) store$avg_players else "-"),
          div(class = "small text-muted", "Avg Players")
        ),
        div(
          class = "text-center px-3",
          div(class = "h4 mb-0 text-primary",
              if (!is.na(store$last_event)) format(as.Date(store$last_event), "%b %d") else "-"),
          div(class = "small text-muted", "Last Event")
        )
      ),

      # Recent tournaments
      if (!is.null(recent_tournaments) && nrow(recent_tournaments) > 0) {
        tagList(
          h6(class = "border-bottom pb-2", "Recent Tournaments"),
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
        p(class = "text-muted", "No tournaments recorded yet")
      },

      # Top players
      if (!is.null(top_players) && nrow(top_players) > 0) {
        tagList(
          h6(class = "border-bottom pb-2 mt-3", "Top Players at This Store"),
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
      SELECT name, city as region, website, schedule_info
      FROM stores
      WHERE is_online = TRUE AND is_active = TRUE
      ORDER BY name
    ")

    if (nrow(online_stores) == 0) {
      return(NULL)  # Don't show section if no online stores
    }

    card(
      card_header(
        class = "d-flex align-items-center gap-2",
        bsicons::bs_icon("globe"),
        span("Online Tournament Organizers")
      ),
      card_body(
        div(
          class = "row g-3",
          lapply(1:nrow(online_stores), function(i) {
            store <- online_stores[i, ]
            div(
              class = "col-md-4",
              div(
                class = "border rounded p-3 h-100",
                h6(class = "mb-1", store$name),
                if (!is.na(store$region) && nchar(store$region) > 0)
                  p(class = "text-muted small mb-1", bsicons::bs_icon("geo"), " ", store$region),
                if (!is.na(store$schedule_info) && nchar(store$schedule_info) > 0)
                  p(class = "small mb-1", bsicons::bs_icon("calendar"), " ", store$schedule_info),
                if (!is.na(store$website) && nchar(store$website) > 0)
                  a(href = store$website, target = "_blank", class = "small",
                    bsicons::bs_icon("link-45deg"), " Website")
              )
            )
          })
        )
      )
    )
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

  # Player standings
  # Reset players filters

  observeEvent(input$reset_players_filters, {
    updateTextInput(session, "players_search", value = "")
    updateSelectInput(session, "players_format", selected = "")
    updateSelectInput(session, "players_min_events", selected = 0)
  })

  output$player_standings <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Build filters
    search_filter <- if (!is.null(input$players_search) && nchar(trimws(input$players_search)) > 0) {
      sprintf("AND LOWER(p.display_name) LIKE LOWER('%%%s%%')", trimws(input$players_search))
    } else ""

    format_filter <- if (!is.null(input$players_format) && input$players_format != "") {
      sprintf("AND t.format = '%s'", input$players_format)
    } else ""

    min_events <- as.numeric(input$players_min_events)
    if (is.na(min_events)) min_events <- 0

    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.player_id, p.display_name as Player,
             COUNT(DISTINCT r.tournament_id) as Events,
             SUM(r.wins) as W, SUM(r.losses) as L, SUM(r.ties) as T,
             ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%',
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as '1st',
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as 'Top 3'
      FROM players p
      JOIN results r ON p.player_id = r.player_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s
      GROUP BY p.player_id, p.display_name
      HAVING COUNT(DISTINCT r.tournament_id) >= %d
      ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC,
               ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) DESC
    ", search_filter, format_filter, min_events))

    if (nrow(result) == 0) {
      return(reactable(data.frame(Message = "No player data matches filters"), compact = TRUE))
    }

    reactable(
      result,
      compact = TRUE,
      striped = TRUE,
      pagination = TRUE,
      defaultPageSize = 20,
      selection = "single",
      onClick = "select",
      rowStyle = list(cursor = "pointer"),
      columns = list(
        player_id = colDef(show = FALSE),
        Player = colDef(minWidth = 150),
        Events = colDef(minWidth = 70, align = "center"),
        W = colDef(minWidth = 50, align = "center"),
        L = colDef(minWidth = 50, align = "center"),
        T = colDef(minWidth = 50, align = "center"),
        `Win %` = colDef(minWidth = 70, align = "center"),
        `1st` = colDef(minWidth = 50, align = "center"),
        `Top 3` = colDef(minWidth = 60, align = "center")
      )
    )
  })

  # Handle player row selection - open detail modal
  observeEvent(getReactableState("player_standings", "selected"), {
    selected_row <- getReactableState("player_standings", "selected")
    if (is.null(selected_row) || length(selected_row) == 0) return()

    # Get the player_id from the data
    # We need to re-run the query to get the data in the same order
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return()

    search_filter <- if (!is.null(input$players_search) && nchar(trimws(input$players_search)) > 0) {
      sprintf("AND LOWER(p.display_name) LIKE LOWER('%%%s%%')", trimws(input$players_search))
    } else ""

    format_filter <- if (!is.null(input$players_format) && input$players_format != "") {
      sprintf("AND t.format = '%s'", input$players_format)
    } else ""

    min_events <- as.numeric(input$players_min_events)
    if (is.na(min_events)) min_events <- 0

    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.player_id
      FROM players p
      JOIN results r ON p.player_id = r.player_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s
      GROUP BY p.player_id, p.display_name
      HAVING COUNT(DISTINCT r.tournament_id) >= %d
      ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC,
               ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) DESC
    ", search_filter, format_filter, min_events))

    if (selected_row > nrow(result)) return()

    rv$selected_player_id <- result$player_id[selected_row]
  })

  # Render player detail modal
  output$player_detail_modal <- renderUI({
    req(rv$selected_player_id)

    player_id <- rv$selected_player_id
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Get player info
    player <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.display_name, s.name as home_store
      FROM players p
      LEFT JOIN stores s ON p.home_store_id = s.store_id
      WHERE p.player_id = %d
    ", player_id))

    if (nrow(player) == 0) return(NULL)

    # Get overall stats
    stats <- dbGetQuery(rv$db_con, sprintf("
      SELECT COUNT(DISTINCT r.tournament_id) as events,
             SUM(r.wins) as wins, SUM(r.losses) as losses,
             ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as win_pct,
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as first_places,
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3
      FROM results r
      WHERE r.player_id = %d
    ", player_id))

    # Get favorite decks (most played)
    favorite_decks <- dbGetQuery(rv$db_con, sprintf("
      SELECT da.archetype_name as Deck, da.primary_color as color,
             COUNT(*) as Times,
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as Wins
      FROM results r
      JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      WHERE r.player_id = %d
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

    # Build modal
    showModal(modalDialog(
      title = div(
        class = "d-flex align-items-center gap-2",
        bsicons::bs_icon("person-circle"),
        player$display_name
      ),
      size = "l",
      easyClose = TRUE,
      footer = modalButton("Close"),

      # Player info
      if (!is.na(player$home_store)) {
        p(class = "text-muted", bsicons::bs_icon("shop"), " Home store: ", player$home_store)
      },

      # Stats summary
      div(
        class = "d-flex justify-content-evenly mb-3 p-3 bg-light rounded flex-wrap",
        div(
          class = "text-center px-2",
          div(class = "h4 mb-0 text-primary", stats$events),
          div(class = "small text-muted", "Events")
        ),
        div(
          class = "text-center px-2",
          div(class = "h4 mb-0 text-primary", sprintf("%d-%d", stats$wins, stats$losses)),
          div(class = "small text-muted", "Record")
        ),
        div(
          class = "text-center px-2",
          div(class = "h4 mb-0 text-primary", if (!is.na(stats$win_pct)) paste0(stats$win_pct, "%") else "-"),
          div(class = "small text-muted", "Win Rate")
        ),
        div(
          class = "text-center px-2",
          div(class = "h4 mb-0 text-success", stats$first_places),
          div(class = "small text-muted", "1st Places")
        ),
        div(
          class = "text-center px-2",
          div(class = "h4 mb-0 text-info", stats$top3),
          div(class = "small text-muted", "Top 3s")
        )
      ),

      # Favorite decks
      if (nrow(favorite_decks) > 0) {
        tagList(
          h6(class = "border-bottom pb-2", "Favorite Decks"),
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
          h6(class = "border-bottom pb-2", "Recent Results"),
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
                    class = if (row$Place == 1) "fw-bold text-success" else if (row$Place <= 3) "text-info" else "",
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
        p(class = "text-muted", "No tournament results recorded")
      }
    ))
  })

  # Reset meta filters
  observeEvent(input$reset_meta_filters, {
    updateTextInput(session, "meta_search", value = "")
    updateSelectInput(session, "meta_format", selected = "")
    updateSelectInput(session, "meta_min_entries", selected = 2)
  })

  # Archetype stats
  output$archetype_stats <- renderReactable({
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

    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT da.archetype_id, da.archetype_name as Deck, da.primary_color as Color,
             COUNT(r.result_id) as Entries,
             ROUND(AVG(r.placement), 1) as 'Avg Place',
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as '1st Places',
             ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%',
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as 'Top 3s'
      FROM deck_archetypes da
      JOIN results r ON da.archetype_id = r.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s
      GROUP BY da.archetype_id, da.archetype_name, da.primary_color
      HAVING COUNT(r.result_id) >= %d
      ORDER BY COUNT(r.result_id) DESC, COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC
    ", search_filter, format_filter, min_entries))

    if (nrow(result) == 0) {
      return(reactable(data.frame(Message = "No decks match the current filters"), compact = TRUE))
    }

    reactable(
      result,
      compact = TRUE,
      striped = TRUE,
      selection = "single",
      onClick = "select",
      rowStyle = list(cursor = "pointer"),
      columns = list(
        archetype_id = colDef(show = FALSE),
        Deck = colDef(minWidth = 150),
        Color = colDef(minWidth = 80, cell = function(value) deck_color_badge(value)),
        Entries = colDef(minWidth = 70, align = "center"),
        `Avg Place` = colDef(minWidth = 80, align = "center"),
        `1st Places` = colDef(minWidth = 80, align = "center"),
        `Win %` = colDef(minWidth = 70, align = "center"),
        `Top 3s` = colDef(minWidth = 70, align = "center")
      )
    )
  })

  # Handle archetype row selection - open detail modal
  observeEvent(getReactableState("archetype_stats", "selected"), {
    selected_row <- getReactableState("archetype_stats", "selected")
    if (is.null(selected_row) || length(selected_row) == 0) return()

    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return()

    search_filter <- if (!is.null(input$meta_search) && nchar(trimws(input$meta_search)) > 0) {
      sprintf("AND LOWER(da.archetype_name) LIKE LOWER('%%%s%%')", trimws(input$meta_search))
    } else ""

    format_filter <- if (!is.null(input$meta_format) && input$meta_format != "") {
      sprintf("AND t.format = '%s'", input$meta_format)
    } else ""

    min_entries <- as.numeric(input$meta_min_entries)
    if (is.na(min_entries)) min_entries <- 0

    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT da.archetype_id
      FROM deck_archetypes da
      JOIN results r ON da.archetype_id = r.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s
      GROUP BY da.archetype_id, da.archetype_name, da.primary_color
      HAVING COUNT(r.result_id) >= %d
      ORDER BY COUNT(r.result_id) DESC, COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC
    ", search_filter, format_filter, min_entries))

    if (selected_row > nrow(result)) return()

    rv$selected_archetype_id <- result$archetype_id[selected_row]
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

    # Get overall stats
    stats <- dbGetQuery(rv$db_con, sprintf("
      SELECT COUNT(r.result_id) as entries,
             COUNT(DISTINCT r.tournament_id) as tournaments,
             COUNT(DISTINCT r.player_id) as pilots,
             ROUND(AVG(r.placement), 1) as avg_place,
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as first_places,
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3,
             ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as win_pct
      FROM results r
      WHERE r.archetype_id = %d
    ", archetype_id))

    # Get top pilots
    top_pilots <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.display_name as Player,
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
            class = "d-flex justify-content-evenly flex-wrap p-3 bg-light rounded h-100 align-items-center",
            div(
              class = "text-center px-2",
              div(class = "h5 mb-0 text-primary", stats$entries),
              div(class = "small text-muted", "Entries")
            ),
            div(
              class = "text-center px-2",
              div(class = "h5 mb-0 text-primary", stats$pilots),
              div(class = "small text-muted", "Pilots")
            ),
            div(
              class = "text-center px-2",
              div(class = "h5 mb-0 text-success", stats$first_places),
              div(class = "small text-muted", "1st Places")
            ),
            div(
              class = "text-center px-2",
              div(class = "h5 mb-0 text-info", stats$top3),
              div(class = "small text-muted", "Top 3s")
            ),
            div(
              class = "text-center px-2",
              div(class = "h5 mb-0", if (!is.na(stats$win_pct)) paste0(stats$win_pct, "%") else "-"),
              div(class = "small text-muted", "Win Rate")
            ),
            div(
              class = "text-center px-2",
              div(class = "h5 mb-0", if (!is.na(stats$avg_place)) stats$avg_place else "-"),
              div(class = "small text-muted", "Avg Place")
            )
          )
        )
      ),

      # Top pilots
      if (nrow(top_pilots) > 0) {
        tagList(
          h6(class = "border-bottom pb-2", "Top Pilots"),
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
                  tags$td(row$Player),
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
          h6(class = "border-bottom pb-2 mt-3", "Recent Results"),
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
                    class = if (row$Place == 1) "fw-bold text-success" else if (row$Place <= 3) "text-info" else "",
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
        p(class = "text-muted", "No tournament results recorded")
      }
    ))
  })

  # Tournament history
  # Reset tournaments filters
  observeEvent(input$reset_tournaments_filters, {
    updateTextInput(session, "tournaments_search", value = "")
    updateSelectInput(session, "tournaments_format", selected = "")
    updateSelectInput(session, "tournaments_event_type", selected = "")
  })

  output$tournament_history <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Build filters
    search_filter <- if (!is.null(input$tournaments_search) && nchar(trimws(input$tournaments_search)) > 0) {
      sprintf("AND LOWER(s.name) LIKE LOWER('%%%s%%')", trimws(input$tournaments_search))
    } else ""

    format_filter <- if (!is.null(input$tournaments_format) && input$tournaments_format != "") {
      sprintf("AND t.format = '%s'", input$tournaments_format)
    } else ""

    event_type_filter <- if (!is.null(input$tournaments_event_type) && input$tournaments_event_type != "") {
      sprintf("AND t.event_type = '%s'", input$tournaments_event_type)
    } else ""

    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT t.tournament_id, t.event_date as Date, s.name as Store, t.event_type as Type,
             t.format as Format, t.player_count as Players, t.rounds as Rounds,
             p.display_name as Winner, da.archetype_name as 'Winning Deck'
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      LEFT JOIN results r ON t.tournament_id = r.tournament_id AND r.placement = 1
      LEFT JOIN players p ON r.player_id = p.player_id
      LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      WHERE 1=1 %s %s %s
      ORDER BY t.event_date DESC
    ", search_filter, format_filter, event_type_filter))

    if (nrow(result) == 0) {
      return(reactable(data.frame(Message = "No tournaments match filters"), compact = TRUE))
    }

    # Format event type nicely
    result$Type <- sapply(result$Type, function(et) {
      if (is.na(et)) return("Unknown")
      switch(et,
             "locals" = "Locals",
             "evo_cup" = "Evo Cup",
             "store_championship" = "Store Champ",
             "regional" = "Regional",
             "online" = "Online",
             et)
    })

    reactable(
      result,
      compact = TRUE,
      striped = TRUE,
      pagination = TRUE,
      defaultPageSize = 20,
      selection = "single",
      onClick = "select",
      rowStyle = list(cursor = "pointer"),
      columns = list(
        tournament_id = colDef(show = FALSE),
        Date = colDef(minWidth = 90),
        Store = colDef(minWidth = 150),
        Type = colDef(minWidth = 90),
        Format = colDef(minWidth = 70),
        Players = colDef(minWidth = 70, align = "center"),
        Rounds = colDef(minWidth = 60, align = "center"),
        Winner = colDef(minWidth = 120),
        `Winning Deck` = colDef(minWidth = 120)
      )
    )
  })

  # Handle tournament row selection - open detail modal
  observeEvent(getReactableState("tournament_history", "selected"), {
    selected_row <- getReactableState("tournament_history", "selected")
    if (is.null(selected_row) || length(selected_row) == 0) return()

    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return()

    # Build same filters to get correct tournament_id
    search_filter <- if (!is.null(input$tournaments_search) && nchar(trimws(input$tournaments_search)) > 0) {
      sprintf("AND LOWER(s.name) LIKE LOWER('%%%s%%')", trimws(input$tournaments_search))
    } else ""

    format_filter <- if (!is.null(input$tournaments_format) && input$tournaments_format != "") {
      sprintf("AND t.format = '%s'", input$tournaments_format)
    } else ""

    event_type_filter <- if (!is.null(input$tournaments_event_type) && input$tournaments_event_type != "") {
      sprintf("AND t.event_type = '%s'", input$tournaments_event_type)
    } else ""

    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT t.tournament_id
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      WHERE 1=1 %s %s %s
      ORDER BY t.event_date DESC
    ", search_filter, format_filter, event_type_filter))

    if (selected_row > nrow(result)) return()

    rv$selected_tournament_id <- result$tournament_id[selected_row]
  })

  # Render tournament detail modal
  output$tournament_detail_modal <- renderUI({
    req(rv$selected_tournament_id)

    tournament_id <- rv$selected_tournament_id
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Get tournament info
    tournament <- dbGetQuery(rv$db_con, "
      SELECT t.event_date, t.event_type, t.format, t.player_count, t.rounds, s.name as store_name
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      WHERE t.tournament_id = ?
    ", params = list(tournament_id))

    if (nrow(tournament) == 0) return(NULL)

    # Get all results for this tournament
    results <- dbGetQuery(rv$db_con, "
      SELECT r.placement as Place, p.display_name as Player, da.archetype_name as Deck,
             da.primary_color as color, r.wins as W, r.losses as L, r.ties as T, r.decklist_url
      FROM results r
      JOIN players p ON r.player_id = p.player_id
      JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      WHERE r.tournament_id = ?
      ORDER BY r.placement ASC
    ", params = list(tournament_id))

    # Format event type
    event_type_display <- switch(tournament$event_type,
                                  "locals" = "Locals",
                                  "evo_cup" = "Evo Cup",
                                  "store_championship" = "Store Championship",
                                  "regional" = "Regional",
                                  "online" = "Online",
                                  tournament$event_type)

    # Build modal
    showModal(modalDialog(
      title = div(
        class = "d-flex align-items-center gap-2",
        bsicons::bs_icon("trophy"),
        sprintf("%s - %s", tournament$store_name, format(as.Date(tournament$event_date), "%B %d, %Y"))
      ),
      size = "l",
      easyClose = TRUE,
      footer = modalButton("Close"),

      # Tournament info
      div(
        class = "d-flex justify-content-evenly mb-3 p-3 bg-light rounded flex-wrap",
        div(
          class = "text-center px-3",
          div(class = "h5 mb-0 text-primary", event_type_display),
          div(class = "small text-muted", "Event Type")
        ),
        div(
          class = "text-center px-3",
          div(class = "h5 mb-0 text-primary", if (!is.na(tournament$format)) tournament$format else "-"),
          div(class = "small text-muted", "Format")
        ),
        div(
          class = "text-center px-3",
          div(class = "h5 mb-0 text-primary", tournament$player_count),
          div(class = "small text-muted", "Players")
        ),
        div(
          class = "text-center px-3",
          div(class = "h5 mb-0 text-primary", if (!is.na(tournament$rounds)) tournament$rounds else "-"),
          div(class = "small text-muted", "Rounds")
        )
      ),

      # Full standings
      if (nrow(results) > 0) {
        tagList(
          h6(class = "border-bottom pb-2", "Final Standings"),
          tags$table(
            class = "table table-sm table-striped",
            tags$thead(
              tags$tr(
                tags$th("Place"), tags$th("Player"), tags$th("Deck"),
                tags$th("Record"), tags$th("")
              )
            ),
            tags$tbody(
              lapply(1:nrow(results), function(i) {
                row <- results[i, ]
                tags$tr(
                  tags$td(
                    class = if (row$Place == 1) "fw-bold text-success" else if (row$Place <= 3) "fw-bold text-info" else "",
                    ordinal(row$Place)
                  ),
                  tags$td(row$Player),
                  tags$td(
                    span(class = paste("deck-badge", paste0("deck-badge-", tolower(row$color))), row$Deck)
                  ),
                  tags$td(sprintf("%d-%d%s", row$W, row$L, if (row$T > 0) sprintf("-%d", row$T) else "")),
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
        p(class = "text-muted", "No results recorded for this tournament")
      }
    ))
  })

  # ---------------------------------------------------------------------------
  # Admin - Tournament Entry
  # ---------------------------------------------------------------------------

  # Wizard step management
  observe({
    if (rv$wizard_step == 1) {
      shinyjs::show("wizard_step1")
      shinyjs::hide("wizard_step2")
      shinyjs::runjs("$('#step1_indicator').addClass('active').removeClass('completed'); $('#step2_indicator').removeClass('active');")
    } else {
      shinyjs::hide("wizard_step1")
      shinyjs::show("wizard_step2")
      shinyjs::runjs("$('#step2_indicator').addClass('active'); $('#step1_indicator').removeClass('active').addClass('completed');")
    }
  })

  output$active_tournament_info <- renderText({
    if (is.null(rv$active_tournament_id)) {
      return("No active tournament. Create one to start entering results.")
    }

    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return("Database not connected")

    info <- dbGetQuery(rv$db_con, "
      SELECT t.tournament_id, s.name as store_name, t.event_date, t.event_type, t.format, t.player_count
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      WHERE t.tournament_id = ?
    ", params = list(rv$active_tournament_id))

    if (nrow(info) == 0) return("Tournament not found")

    format_display <- if (!is.null(info$format) && !is.na(info$format)) paste0(" [", info$format, "]") else ""
    sprintf("Tournament #%d\n%s\n%s (%s)%s\nExpected players: %d",
            info$tournament_id, info$store_name, info$event_date, info$event_type, format_display, info$player_count)
  })

  # Create tournament
  observeEvent(input$create_tournament, {
    req(rv$is_admin, rv$db_con)

    store_id <- input$tournament_store
    event_date <- as.character(input$tournament_date)
    event_type <- input$tournament_type
    format <- input$tournament_format
    player_count <- input$tournament_players
    rounds <- input$tournament_rounds

    # Validation
    if (is.null(store_id) || nchar(trimws(store_id)) == 0) {
      showNotification("Please select a store", type = "error")
      return()
    }

    store_id <- as.integer(store_id)
    if (is.na(store_id)) {
      showNotification("Invalid store selection", type = "error")
      return()
    }

    if (is.null(event_date) || nchar(event_date) == 0) {
      showNotification("Please select a date", type = "error")
      return()
    }

    if (is.null(player_count) || is.na(player_count) || player_count < 2) {
      showNotification("Player count must be at least 2", type = "error")
      return()
    }

    if (is.null(rounds) || is.na(rounds) || rounds < 1) {
      showNotification("Rounds must be at least 1", type = "error")
      return()
    }

    # Check for duplicate tournament (same store and date)
    existing <- dbGetQuery(rv$db_con, "
      SELECT t.tournament_id, t.player_count, t.event_type,
             (SELECT COUNT(*) FROM results WHERE tournament_id = t.tournament_id) as result_count,
             s.name as store_name
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      WHERE t.store_id = ? AND t.event_date = ?
    ", params = list(store_id, event_date))

    if (nrow(existing) > 0) {
      # Store for modal handlers
      rv$duplicate_tournament <- existing[1, ]

      output$duplicate_tournament_message <- renderUI({
        div(
          p(sprintf("A tournament at %s on %s already exists:",
                    existing$store_name[1], format(as.Date(event_date), "%B %d, %Y"))),
          tags$ul(
            tags$li(sprintf("%d players expected", existing$player_count[1])),
            tags$li(sprintf("%d results entered", existing$result_count[1])),
            tags$li(sprintf("Event type: %s", existing$event_type[1]))
          ),
          p("What would you like to do?")
        )
      })

      # Show modal and return (don't create)
      shinyjs::runjs("$('#duplicate_tournament_modal').modal('show');")
      return()
    }

    tryCatch({
      # Get next ID
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(tournament_id), 0) as max_id FROM tournaments")$max_id
      new_id <- max_id + 1

      dbExecute(rv$db_con, "
        INSERT INTO tournaments (tournament_id, store_id, event_date, event_type, format, player_count, rounds)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ", params = list(new_id, store_id, event_date, event_type, format, player_count, rounds))

      rv$active_tournament_id <- new_id
      rv$current_results <- data.frame()

      showNotification("Tournament created!", type = "message")
      rv$wizard_step <- 2

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Clear tournament
  observeEvent(input$clear_tournament, {
    rv$active_tournament_id <- NULL
    rv$current_results <- data.frame()
    rv$wizard_step <- 1
  })

  # Wizard back button
  observeEvent(input$wizard_back, {
    rv$wizard_step <- 1
  })

  # Handle "View/Edit Existing" button from duplicate modal
  observeEvent(input$edit_existing_tournament, {
    req(rv$duplicate_tournament)
    shinyjs::runjs("$('#duplicate_tournament_modal').modal('hide');")

    rv$active_tournament_id <- rv$duplicate_tournament$tournament_id
    rv$wizard_step <- 2
  })

  # Handle "Create Anyway" button from duplicate modal
  observeEvent(input$create_anyway, {
    shinyjs::runjs("$('#duplicate_tournament_modal').modal('hide');")

    # Get form values again
    store_id <- as.integer(input$tournament_store)
    event_date <- as.character(input$tournament_date)
    event_type <- input$tournament_type
    format <- input$tournament_format
    player_count <- input$tournament_players
    rounds <- input$tournament_rounds

    tryCatch({
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(tournament_id), 0) as max_id FROM tournaments")$max_id
      new_id <- max_id + 1

      dbExecute(rv$db_con, "
        INSERT INTO tournaments (tournament_id, store_id, event_date, event_type, format, player_count, rounds)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ", params = list(new_id, store_id, event_date, event_type, format, player_count, rounds))

      rv$active_tournament_id <- new_id
      rv$current_results <- data.frame()
      rv$duplicate_tournament <- NULL

      showNotification("Tournament created!", type = "message")
      rv$wizard_step <- 2

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Tournament summary bar for wizard step 2
  output$tournament_summary_bar <- renderUI({
    req(rv$active_tournament_id, rv$db_con)

    info <- dbGetQuery(rv$db_con, "
      SELECT s.name as store_name, t.event_date, t.event_type, t.player_count
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      WHERE t.tournament_id = ?
    ", params = list(rv$active_tournament_id))

    if (nrow(info) == 0) return(NULL)

    div(
      class = "alert alert-info d-flex align-items-center gap-3 mb-3",
      bsicons::bs_icon("geo-alt-fill"),
      span(info$store_name),
      span("|"),
      span(format(as.Date(info$event_date), "%b %d, %Y")),
      span("|"),
      span(info$event_type),
      span("|"),
      span(sprintf("%d players", info$player_count))
    )
  })

  # Results count header
  output$results_count_header <- renderUI({
    req(rv$active_tournament_id, rv$db_con)

    result_count <- dbGetQuery(rv$db_con, "
      SELECT COUNT(*) as cnt FROM results WHERE tournament_id = ?
    ", params = list(rv$active_tournament_id))$cnt

    player_count <- dbGetQuery(rv$db_con, "
      SELECT player_count FROM tournaments WHERE tournament_id = ?
    ", params = list(rv$active_tournament_id))$player_count

    sprintf("Results Entered (%d/%d)", result_count, player_count)
  })

  # ---------------------------------------------------------------------------
  # Quick Add Player Handlers
  # ---------------------------------------------------------------------------

  # Show quick add player form
  observeEvent(input$show_quick_add_player, {
    shinyjs::show("quick_add_player_form")
  })

  # Cancel quick add player
  observeEvent(input$quick_add_player_cancel, {
    shinyjs::hide("quick_add_player_form")
    updateTextInput(session, "quick_player_name", value = "")
  })

  # Submit quick add player
  observeEvent(input$quick_add_player_submit, {
    req(rv$db_con)
    name <- trimws(input$quick_player_name)

    if (nchar(name) == 0) {
      showNotification("Please enter a player name", type = "error")
      return()
    }

    tryCatch({
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(player_id), 0) as max_id FROM players")$max_id
      player_id <- max_id + 1

      dbExecute(rv$db_con, "INSERT INTO players (player_id, display_name) VALUES (?, ?)",
                params = list(player_id, name))

      showNotification(sprintf("Added player: %s", name), type = "message")

      # Update dropdown and select new player
      choices <- get_player_choices(rv$db_con)
      updateSelectizeInput(session, "result_player", choices = choices, selected = player_id)

      # Hide form and clear
      shinyjs::hide("quick_add_player_form")
      updateTextInput(session, "quick_player_name", value = "")

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # ---------------------------------------------------------------------------
  # Quick Add Deck Handlers
  # ---------------------------------------------------------------------------

  # Show quick add deck form
  observeEvent(input$show_quick_add_deck, {
    shinyjs::show("quick_add_deck_form")
  })

  # Cancel quick add deck
  observeEvent(input$quick_add_deck_cancel, {
    shinyjs::hide("quick_add_deck_form")
    updateTextInput(session, "quick_deck_name", value = "")
  })

  # Submit quick add deck
  observeEvent(input$quick_add_deck_submit, {
    req(rv$db_con)
    name <- trimws(input$quick_deck_name)
    color <- input$quick_deck_color

    if (nchar(name) == 0) {
      showNotification("Please enter a deck name", type = "error")
      return()
    }

    tryCatch({
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(archetype_id), 0) as max_id FROM deck_archetypes")$max_id
      archetype_id <- max_id + 1

      dbExecute(rv$db_con, "
        INSERT INTO deck_archetypes (archetype_id, archetype_name, primary_color)
        VALUES (?, ?, ?)
      ", params = list(archetype_id, name, color))

      showNotification(sprintf("Added deck: %s", name), type = "message")

      # Update dropdown and select new deck
      choices <- get_archetype_choices(rv$db_con)
      updateSelectizeInput(session, "result_deck", choices = choices, selected = archetype_id)

      # Hide form and clear
      shinyjs::hide("quick_add_deck_form")
      updateTextInput(session, "quick_deck_name", value = "")

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Add result
  add_result_logic <- function() {
    req(rv$is_admin, rv$db_con, rv$active_tournament_id)

    player_input <- input$result_player
    archetype_id <- input$result_deck
    placement <- input$result_placement
    wins <- input$result_wins
    losses <- input$result_losses
    ties <- input$result_ties
    decklist_url <- if (!is.null(input$result_decklist_url) && nchar(input$result_decklist_url) > 0) input$result_decklist_url else NA_character_

    # Validation
    if (is.null(player_input) || nchar(trimws(player_input)) == 0) {
      showNotification("Please enter a player name", type = "error")
      return()
    }

    if (is.null(archetype_id) || nchar(trimws(archetype_id)) == 0) {
      showNotification("Please select a deck archetype", type = "error")
      return()
    }

    archetype_id <- as.integer(archetype_id)
    if (is.na(archetype_id)) {
      showNotification("Invalid deck selection", type = "error")
      return()
    }

    if (is.na(placement) || placement < 1) {
      showNotification("Placement must be at least 1", type = "error")
      return()
    }

    if (is.na(wins) || wins < 0) wins <- 0
    if (is.na(losses) || losses < 0) losses <- 0
    if (is.na(ties) || ties < 0) ties <- 0

    # Validate decklist URL format if provided
    if (!is.null(decklist_url) && !is.na(decklist_url) && nchar(decklist_url) > 0) {
      if (!grepl("^https?://", decklist_url)) {
        showNotification("Decklist URL should start with http:// or https://", type = "warning")
      }
    }

    # Check for duplicate placement in this tournament
    existing_placement <- dbGetQuery(rv$db_con, "
      SELECT COUNT(*) as cnt FROM results
      WHERE tournament_id = ? AND placement = ?
    ", params = list(rv$active_tournament_id, placement))

    if (existing_placement$cnt > 0) {
      showNotification(
        sprintf("Warning: Placement %d already exists in this tournament", placement),
        type = "warning"
      )
    }

    tryCatch({
      # Check if player exists or create new
      if (grepl("^\\d+$", player_input)) {
        # Existing player selected (numeric ID)
        player_id <- as.integer(player_input)
      } else {
        # New player name entered - check for existing player with same name first
        existing_player <- dbGetQuery(rv$db_con, "
          SELECT player_id FROM players WHERE LOWER(display_name) = LOWER(?)
        ", params = list(trimws(player_input)))

        if (nrow(existing_player) > 0) {
          player_id <- existing_player$player_id[1]
          showNotification(sprintf("Using existing player: %s", player_input), type = "message")
        } else {
          # Create new player
          max_player_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(player_id), 0) as max_id FROM players")$max_id
          player_id <- max_player_id + 1

          dbExecute(rv$db_con, "
            INSERT INTO players (player_id, display_name) VALUES (?, ?)
          ", params = list(player_id, trimws(player_input)))

          showNotification(sprintf("Created new player: %s", player_input), type = "message")
        }

        # Update player choices
        updateSelectizeInput(session, "result_player",
                             choices = get_player_choices(rv$db_con),
                             server = TRUE)
      }

      # Check if this player already has a result in this tournament
      existing_result <- dbGetQuery(rv$db_con, "
        SELECT result_id FROM results
        WHERE tournament_id = ? AND player_id = ?
      ", params = list(rv$active_tournament_id, player_id))

      if (nrow(existing_result) > 0) {
        showNotification(
          "Warning: This player already has a result in this tournament!",
          type = "warning",
          duration = 5
        )
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

      # Trigger table refresh
      rv$results_refresh <- rv$results_refresh + 1

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

  # Quick-add deck from results entry
  observeEvent(input$quick_add_deck, {
    req(rv$is_admin, rv$db_con)

    deck_name <- trimws(input$quick_deck_name)
    deck_color <- input$quick_deck_color

    if (nchar(deck_name) == 0) {
      showNotification("Please enter a deck name", type = "error")
      return()
    }

    # Check for duplicate
    existing <- dbGetQuery(rv$db_con, "
      SELECT archetype_id FROM deck_archetypes
      WHERE LOWER(archetype_name) = LOWER(?)
    ", params = list(deck_name))

    if (nrow(existing) > 0) {
      showNotification(sprintf("Deck '%s' already exists", deck_name), type = "warning")
      # Select the existing deck
      updateSelectizeInput(session, "result_deck", selected = existing$archetype_id[1])
      return()
    }

    tryCatch({
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(archetype_id), 0) as max_id FROM deck_archetypes")$max_id
      new_id <- max_id + 1

      # Add with minimal info - can be completed later in Manage Decks
      dbExecute(rv$db_con, "
        INSERT INTO deck_archetypes (archetype_id, archetype_name, primary_color, secondary_color, display_card_id)
        VALUES (?, ?, ?, NULL, NULL)
      ", params = list(new_id, deck_name, deck_color))

      showNotification(sprintf("Quick-added deck: %s (complete details in Manage Decks)", deck_name),
                       type = "message", duration = 4)

      # Update deck dropdown and select the new deck
      updateSelectizeInput(session, "result_deck",
                           choices = get_archetype_choices(rv$db_con),
                           selected = new_id)

      # Clear quick-add form
      updateTextInput(session, "quick_deck_name", value = "")

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  observeEvent(input$add_result, { add_result_logic() })
  observeEvent(input$add_result_another, { add_result_logic() })

  # Display current results
  output$current_results <- renderReactable({
    req(rv$db_con, rv$active_tournament_id)
    # Refresh trigger - re-run query when results are added
    rv$results_refresh

    results <- dbGetQuery(rv$db_con, "
      SELECT p.display_name as Player, da.archetype_name as Deck,
             r.placement as Place, r.wins as W, r.losses as L, r.ties as T
      FROM results r
      JOIN players p ON r.player_id = p.player_id
      LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
      WHERE r.tournament_id = ?
      ORDER BY r.placement
    ", params = list(rv$active_tournament_id))

    if (nrow(results) == 0) {
      results <- data.frame(Message = "No results entered yet")
    }
    reactable(results, compact = TRUE, striped = TRUE)
  })

  # Finish tournament
  observeEvent(input$finish_tournament, {
    req(rv$active_tournament_id)

    showNotification("Tournament completed!", type = "message")

    # Reset wizard
    rv$active_tournament_id <- NULL
    rv$wizard_step <- 1
    rv$current_results <- data.frame()

    # Clear result entry forms
    updateSelectizeInput(session, "result_player", selected = "")
    updateSelectizeInput(session, "result_deck", selected = "")
    updateNumericInput(session, "result_placement", value = 1)
    updateNumericInput(session, "result_wins", value = 0)
    updateNumericInput(session, "result_losses", value = 0)
    updateNumericInput(session, "result_ties", value = 0)
    updateTextInput(session, "result_decklist_url", value = "")
  })

  # ---------------------------------------------------------------------------
  # Admin - Deck Management
  # ---------------------------------------------------------------------------

  # Card search
  observeEvent(input$search_card_btn, {
    req(input$card_search)

    # Reset pagination
    rv$card_search_page <- 1

    # Show searching indicator
    output$card_search_results <- renderUI({
      div(class = "text-muted", bsicons::bs_icon("hourglass-split"), " Searching...")
    })

    cards <- tryCatch({
      search_cards_local(rv$db_con, input$card_search)
    }, error = function(e) {
      message("Card search error: ", e$message)
      NULL
    })

    if (is.null(cards) || nrow(cards) == 0) {
      output$card_search_results <- renderUI({
        div(class = "alert alert-warning", "No cards found for '", input$card_search, "'")
      })
      rv$card_search_results <- NULL
      return()
    }

    # Deduplicate by card ID (removes duplicate listings of same card)
    # Keep all different cards even if they share the same name (alternate arts)
    cards <- cards[!duplicated(cards$id), ]

    # Store ALL cards in reactive for pagination
    rv$card_search_results <- cards

    # Render first page
    render_card_search_page()
  })

  # Pagination handlers
  observeEvent(input$card_search_prev, {
    if (rv$card_search_page > 1) {
      rv$card_search_page <- rv$card_search_page - 1
      render_card_search_page()
    }
  })

  observeEvent(input$card_search_next, {
    req(rv$card_search_results)
    total_pages <- ceiling(nrow(rv$card_search_results) / 8)
    if (rv$card_search_page < total_pages) {
      rv$card_search_page <- rv$card_search_page + 1
      render_card_search_page()
    }
  })

  # Helper function to render card search page
  render_card_search_page <- function() {
    req(rv$card_search_results)
    cards <- rv$card_search_results
    page <- rv$card_search_page
    per_page <- 8

    total_cards <- nrow(cards)
    total_pages <- ceiling(total_cards / per_page)
    start_idx <- (page - 1) * per_page + 1
    end_idx <- min(page * per_page, total_cards)

    # Get cards for current page
    page_cards <- cards[start_idx:end_idx, ]

    output$card_search_results <- renderUI({
      div(
        # Header with count and pagination
        div(
          class = "d-flex justify-content-between align-items-center mb-2",
          p(class = "text-muted small mb-0", sprintf("Found %d cards (showing %d-%d):", total_cards, start_idx, end_idx)),
          if (total_pages > 1) {
            div(
              class = "d-flex align-items-center gap-1",
              actionButton("card_search_prev", bsicons::bs_icon("chevron-left"),
                           class = paste("btn-sm btn-outline-secondary", if (page == 1) "disabled" else ""),
                           style = "padding: 2px 6px;"),
              span(class = "small mx-1", sprintf("%d/%d", page, total_pages)),
              actionButton("card_search_next", bsicons::bs_icon("chevron-right"),
                           class = paste("btn-sm btn-outline-secondary", if (page == total_pages) "disabled" else ""),
                           style = "padding: 2px 6px;")
            )
          }
        ),
        # Card grid
        div(
          style = "display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; margin-top: 10px;",
          lapply(1:nrow(page_cards), function(i) {
            card_data <- page_cards[i, ]
            # Calculate absolute index for button ID
            abs_idx <- start_idx + i - 1
            # API returns card number in 'id' field, not 'cardnumber'
            card_num <- if ("id" %in% names(card_data)) card_data$id else card_data$cardnumber
            card_name <- if ("name" %in% names(card_data)) card_data$name else "Unknown"
            card_color <- if ("color" %in% names(card_data) && !is.na(card_data$color)) card_data$color else ""

            # Use .webp format - server returns WebP regardless of extension
            img_url <- paste0("https://images.digimoncard.io/images/cards/", card_num, ".webp")

            actionButton(
              inputId = paste0("card_select_", abs_idx),
              label = tagList(
                tags$img(src = img_url,
                         style = "width: 100%; max-width: 80px; height: auto; border-radius: 4px; display: block; margin: 0 auto;",
                         onerror = "this.style.display='none'; this.nextElementSibling.style.display='block';"),
                tags$div(style = "display: none; height: 60px; background: #eee; border-radius: 4px; line-height: 60px; text-align: center; font-size: 10px;", "No image"),
                tags$div(style = "font-weight: bold; font-size: 11px; margin-top: 4px; color: #0F4C81;", card_num),
                tags$div(style = "font-size: 9px; color: #666; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;",
                         title = card_name, substr(card_name, 1, 15)),
                if (nchar(card_color) > 0) tags$div(style = "font-size: 8px; color: #999;", card_color)
              ),
              class = "card-search-btn p-2",
              style = "background: #f8f9fa; border: 2px solid #ddd; border-radius: 6px; width: 100%; text-align: center;"
            )
          })
        )
      )
    })
  }

  # Handle card selection buttons (1-100 to support pagination)
  lapply(1:100, function(i) {
    observeEvent(input[[paste0("card_select_", i)]], {
      req(rv$card_search_results)
      if (i <= nrow(rv$card_search_results)) {
        # API returns card number in 'id' field
        card_num <- if ("id" %in% names(rv$card_search_results)) {
          rv$card_search_results$id[i]
        } else {
          rv$card_search_results$cardnumber[i]
        }
        updateTextInput(session, "selected_card_id", value = card_num)
        showNotification(paste("Selected:", card_num), type = "message", duration = 2)
      }
    }, ignoreInit = TRUE)
  })

  # Preview selected card
  output$selected_card_preview <- renderUI({
    req(input$selected_card_id)
    card_id <- trimws(input$selected_card_id)
    if (nchar(card_id) < 3) return(NULL)

    # Construct image URL directly using the card ID (.webp format)
    img_url <- paste0("https://images.digimoncard.io/images/cards/", card_id, ".webp")

    div(
      class = "mt-2 p-2 bg-light rounded text-center",
      tags$img(src = img_url, style = "max-width: 120px; border-radius: 6px;",
               onerror = "this.onerror=null; this.src=''; this.alt='Image not found'; this.style.height='60px'; this.style.background='#ddd';"),
      div(class = "mt-1 small text-muted", paste("Selected:", card_id))
    )
  })

  # Add archetype
  observeEvent(input$add_archetype, {
    req(rv$is_admin, rv$db_con)

    name <- trimws(input$deck_name)
    primary_color <- input$deck_primary_color
    secondary_color <- if (input$deck_secondary_color == "") NA_character_ else input$deck_secondary_color
    card_id <- if (!is.null(input$selected_card_id) && nchar(input$selected_card_id) > 0) input$selected_card_id else NA_character_

    # Validation
    if (is.null(name) || nchar(name) == 0) {
      showNotification("Please enter an archetype name", type = "error")
      return()
    }

    if (nchar(name) < 2) {
      showNotification("Archetype name must be at least 2 characters", type = "error")
      return()
    }

    # Check for duplicate archetype name
    existing <- dbGetQuery(rv$db_con, "
      SELECT archetype_id FROM deck_archetypes
      WHERE LOWER(archetype_name) = LOWER(?)
    ", params = list(name))

    if (nrow(existing) > 0) {
      showNotification(
        sprintf("Archetype '%s' already exists", name),
        type = "error"
      )
      return()
    }

    # Validate card ID format if provided
    if (!is.null(card_id) && nchar(card_id) > 0) {
      if (!grepl("^[A-Z0-9]+-[0-9]+$", card_id)) {
        showNotification(
          "Card ID format should be like BT17-042 or EX6-001",
          type = "warning"
        )
      }
    }

    tryCatch({
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(archetype_id), 0) as max_id FROM deck_archetypes")$max_id
      new_id <- max_id + 1

      dbExecute(rv$db_con, "
        INSERT INTO deck_archetypes (archetype_id, archetype_name, display_card_id, primary_color, secondary_color, is_multi_color)
        VALUES (?, ?, ?, ?, ?, ?)
      ", params = list(new_id, name, card_id, primary_color, secondary_color, isTRUE(input$deck_multi_color)))

      showNotification(paste("Added archetype:", name), type = "message")

      # Clear form
      updateTextInput(session, "deck_name", value = "")
      updateSelectInput(session, "deck_primary_color", selected = "Red")
      updateSelectInput(session, "deck_secondary_color", selected = "")
      updateTextInput(session, "selected_card_id", value = "")
      updateTextInput(session, "card_search", value = "")
      updateCheckboxInput(session, "deck_multi_color", value = FALSE)
      output$card_search_results <- renderUI({ NULL })

      # Update archetype dropdown
      updateSelectizeInput(session, "result_deck", choices = get_archetype_choices(rv$db_con))

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Archetype list
  output$archetype_list <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Trigger refresh when archetype added/updated/deleted
    input$add_archetype
    input$update_archetype
    input$confirm_delete_archetype

    data <- dbGetQuery(rv$db_con, "
      SELECT archetype_id, archetype_name as Deck, primary_color, secondary_color, is_multi_color, display_card_id as 'Card ID'
      FROM deck_archetypes
      WHERE is_active = TRUE
      ORDER BY archetype_name
    ")
    if (nrow(data) == 0) {
      return(reactable(data.frame(Message = "No archetypes yet"), compact = TRUE))
    }
    reactable(data, compact = TRUE, striped = TRUE,
      selection = "single",
      onClick = "select",
      rowStyle = list(cursor = "pointer"),
      defaultPageSize = 20,
      showPageSizeOptions = TRUE,
      pageSizeOptions = c(10, 20, 50, 100),
      columns = list(
        archetype_id = colDef(show = FALSE),
        primary_color = colDef(
          name = "Color",
          cell = function(value, index) {
            if (isTRUE(data$is_multi_color[index])) {
              span(class = "badge", style = "background-color: #E91E8C; color: white;", "Multi")
            } else {
              secondary <- data$secondary_color[index]
              deck_color_badge_dual(value, secondary)
            }
          }
        ),
        secondary_color = colDef(show = FALSE),
        is_multi_color = colDef(show = FALSE)
      )
    )
  })

  # Handle archetype selection for editing
  observeEvent(input$archetype_list__reactable__selected, {
    req(rv$db_con)
    selected_idx <- input$archetype_list__reactable__selected

    if (is.null(selected_idx) || length(selected_idx) == 0) {
      return()
    }

    # Get archetype data
    data <- dbGetQuery(rv$db_con, "
      SELECT archetype_id, archetype_name, primary_color, secondary_color, display_card_id, is_multi_color
      FROM deck_archetypes
      WHERE is_active = TRUE
      ORDER BY archetype_name
    ")

    if (selected_idx > nrow(data)) return()

    arch <- data[selected_idx, ]

    # Populate form for editing
    updateTextInput(session, "editing_archetype_id", value = as.character(arch$archetype_id))
    updateTextInput(session, "deck_name", value = arch$archetype_name)
    updateSelectInput(session, "deck_primary_color", selected = arch$primary_color)
    updateSelectInput(session, "deck_secondary_color",
                      selected = if (is.na(arch$secondary_color)) "" else arch$secondary_color)
    updateTextInput(session, "selected_card_id",
                    value = if (is.na(arch$display_card_id)) "" else arch$display_card_id)
    updateCheckboxInput(session, "deck_multi_color", value = isTRUE(arch$is_multi_color))

    # Show/hide buttons
    shinyjs::hide("add_archetype")
    shinyjs::show("update_archetype")
    shinyjs::show("delete_archetype")

    showNotification(sprintf("Editing: %s", arch$archetype_name), type = "message", duration = 2)
  })

  # Update archetype
  observeEvent(input$update_archetype, {
    req(rv$is_admin, rv$db_con)
    req(input$editing_archetype_id)

    archetype_id <- as.integer(input$editing_archetype_id)
    name <- trimws(input$deck_name)
    primary_color <- input$deck_primary_color
    secondary_color <- if (input$deck_secondary_color == "") NA_character_ else input$deck_secondary_color
    card_id <- if (!is.null(input$selected_card_id) && nchar(input$selected_card_id) > 0) input$selected_card_id else NA_character_

    if (is.null(name) || nchar(name) == 0) {
      showNotification("Please enter an archetype name", type = "error")
      return()
    }

    tryCatch({
      dbExecute(rv$db_con, "
        UPDATE deck_archetypes
        SET archetype_name = ?, primary_color = ?, secondary_color = ?, display_card_id = ?, is_multi_color = ?, updated_at = CURRENT_TIMESTAMP
        WHERE archetype_id = ?
      ", params = list(name, primary_color, secondary_color, card_id, isTRUE(input$deck_multi_color), archetype_id))

      showNotification(sprintf("Updated archetype: %s", name), type = "message")

      # Clear form and reset to add mode
      updateTextInput(session, "editing_archetype_id", value = "")
      updateTextInput(session, "deck_name", value = "")
      updateSelectInput(session, "deck_primary_color", selected = "Red")
      updateSelectInput(session, "deck_secondary_color", selected = "")
      updateTextInput(session, "selected_card_id", value = "")
      updateTextInput(session, "card_search", value = "")
      updateCheckboxInput(session, "deck_multi_color", value = FALSE)
      output$card_search_results <- renderUI({ NULL })

      shinyjs::show("add_archetype")
      shinyjs::hide("update_archetype")
      shinyjs::hide("delete_archetype")

      # Update dropdown
      updateSelectizeInput(session, "result_deck", choices = get_archetype_choices(rv$db_con))

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Cancel edit archetype
  observeEvent(input$cancel_edit_archetype, {
    updateTextInput(session, "editing_archetype_id", value = "")
    updateTextInput(session, "deck_name", value = "")
    updateSelectInput(session, "deck_primary_color", selected = "Red")
    updateSelectInput(session, "deck_secondary_color", selected = "")
    updateTextInput(session, "selected_card_id", value = "")
    updateTextInput(session, "card_search", value = "")
    updateCheckboxInput(session, "deck_multi_color", value = FALSE)
    output$card_search_results <- renderUI({ NULL })

    shinyjs::show("add_archetype")
    shinyjs::hide("update_archetype")
    shinyjs::hide("delete_archetype")
  })

  # Check if archetype can be deleted (no related results)
  observe({
    req(input$editing_archetype_id, rv$db_con)
    archetype_id <- as.integer(input$editing_archetype_id)

    count <- dbGetQuery(rv$db_con, "
      SELECT COUNT(*) as cnt FROM results WHERE archetype_id = ?
    ", params = list(archetype_id))$cnt

    rv$archetype_result_count <- count
    rv$can_delete_archetype <- count == 0
  })

  # Delete button click - show modal
  observeEvent(input$delete_archetype, {
    req(rv$is_admin, input$editing_archetype_id)

    archetype_id <- as.integer(input$editing_archetype_id)
    arch <- dbGetQuery(rv$db_con, "SELECT archetype_name FROM deck_archetypes WHERE archetype_id = ?",
                       params = list(archetype_id))

    if (rv$can_delete_archetype) {
      output$delete_archetype_message <- renderUI({
        div(
          p(sprintf("Are you sure you want to delete '%s'?", arch$archetype_name)),
          p(class = "text-danger", "This action cannot be undone.")
        )
      })
      shinyjs::runjs("$('#delete_archetype_modal').modal('show');")
    } else {
      showNotification(
        sprintf("Cannot delete: used in %d result(s)", rv$archetype_result_count),
        type = "error"
      )
    }
  })

  # Confirm delete
  observeEvent(input$confirm_delete_archetype, {
    req(rv$is_admin, rv$db_con, input$editing_archetype_id)
    archetype_id <- as.integer(input$editing_archetype_id)

    tryCatch({
      dbExecute(rv$db_con, "DELETE FROM deck_archetypes WHERE archetype_id = ?",
                params = list(archetype_id))
      showNotification("Archetype deleted", type = "message")

      # Hide modal and reset form
      shinyjs::runjs("$('#delete_archetype_modal').modal('hide');")

      # Clear form
      updateTextInput(session, "editing_archetype_id", value = "")
      updateTextInput(session, "deck_name", value = "")
      updateSelectInput(session, "deck_primary_color", selected = "Red")
      updateSelectInput(session, "deck_secondary_color", selected = "")
      updateTextInput(session, "selected_card_id", value = "")
      updateTextInput(session, "card_search", value = "")
      updateCheckboxInput(session, "deck_multi_color", value = FALSE)
      output$card_search_results <- renderUI({ NULL })

      shinyjs::show("add_archetype")
      shinyjs::hide("update_archetype")
      shinyjs::hide("delete_archetype")

      # Update archetype dropdown
      updateSelectizeInput(session, "result_deck", choices = get_archetype_choices(rv$db_con))

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # ---------------------------------------------------------------------------
  # Admin - Store Management
  # ---------------------------------------------------------------------------

  # Add store
  observeEvent(input$add_store, {
    req(rv$is_admin, rv$db_con)

    # Check if this is an online store
    is_online <- isTRUE(input$store_is_online)

    # Get name from appropriate input based on is_online
    store_name <- if (is_online) {
      trimws(input$store_name_online)
    } else {
      trimws(input$store_name)
    }

    # Use region as "city" for online stores
    store_city <- if (is_online) {
      trimws(input$store_region)
    } else {
      trimws(input$store_city)
    }

    # Validation
    if (nchar(store_name) == 0) {
      showNotification("Please enter a store name", type = "error")
      return()
    }

    # City is required for physical stores, optional for online stores
    if (!is_online && nchar(store_city) == 0) {
      showNotification("Please enter a city", type = "error")
      return()
    }

    # Check for duplicate store name in same city/region
    # For online stores with no region, check for duplicate name among online stores
    if (is_online && nchar(store_city) == 0) {
      existing <- dbGetQuery(rv$db_con, "
        SELECT store_id FROM stores
        WHERE LOWER(name) = LOWER(?) AND is_online = TRUE AND (city IS NULL OR city = '')
      ", params = list(store_name))
    } else {
      existing <- dbGetQuery(rv$db_con, "
        SELECT store_id FROM stores
        WHERE LOWER(name) = LOWER(?) AND LOWER(city) = LOWER(?)
      ", params = list(store_name, store_city))
    }

    if (nrow(existing) > 0) {
      if (is_online && nchar(store_city) == 0) {
        showNotification(
          sprintf("Online store '%s' already exists", store_name),
          type = "error"
        )
      } else {
        showNotification(
          sprintf("Store '%s' in %s already exists", store_name, store_city),
          type = "error"
        )
      }
      return()
    }

    # Validate website URL format if provided
    if (nchar(input$store_website) > 0 && !grepl("^https?://", input$store_website)) {
      showNotification("Website should start with http:// or https://", type = "warning")
    }

    tryCatch({
      # Online stores don't need geocoding
      if (is_online) {
        lat <- NA_real_
        lng <- NA_real_
        address <- NA_character_
        state <- NA_character_
        zip_code <- NA_character_
      } else {
        # Build full address for geocoding (physical stores only)
        address_parts <- c(input$store_address, store_city)
        address_parts <- c(address_parts, if (nchar(input$store_state) > 0) input$store_state else "TX")
        if (nchar(input$store_zip) > 0) {
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
          lat <- NA_real_
          lng <- NA_real_
        }

        # Use NA instead of NULL for DuckDB parameterized queries
        zip_code <- if (nchar(input$store_zip) > 0) input$store_zip else NA_character_
        address <- if (nchar(input$store_address) > 0) input$store_address else NA_character_
        state <- if (nchar(input$store_state) > 0) input$store_state else "TX"
      }

      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(store_id), 0) as max_id FROM stores")$max_id
      new_id <- max_id + 1

      # Common fields for both online and physical stores
      schedule_info <- if (nchar(input$store_schedule) > 0) input$store_schedule else NA_character_
      website <- if (nchar(input$store_website) > 0) input$store_website else NA_character_

      # Use NA for empty city/region
      store_city_db <- if (nchar(store_city) > 0) store_city else NA_character_

      dbExecute(rv$db_con, "
        INSERT INTO stores (store_id, name, address, city, state, zip_code, latitude, longitude, website, schedule_info, is_online)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", params = list(new_id, store_name, address, store_city_db,
                       state, zip_code, lat, lng, website, schedule_info, is_online))

      showNotification(paste("Added store:", store_name), type = "message")

      # Clear form - both physical and online store fields
      updateTextInput(session, "store_name", value = "")
      updateTextInput(session, "store_name_online", value = "")
      updateTextInput(session, "store_region", value = "")
      updateTextInput(session, "store_address", value = "")
      updateTextInput(session, "store_city", value = "")
      updateSelectInput(session, "store_state", selected = "TX")
      updateTextInput(session, "store_zip", value = "")
      updateTextInput(session, "store_website", value = "")
      updateTextAreaInput(session, "store_schedule", value = "")
      updateCheckboxInput(session, "store_is_online", value = FALSE)

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
    input$update_store
    input$confirm_delete_store

    data <- dbGetQuery(rv$db_con, "
      SELECT store_id, name as Store, city as City, state as State, is_online
      FROM stores
      WHERE is_active = TRUE
      ORDER BY name
    ")
    if (nrow(data) == 0) {
      data <- data.frame(Message = "No stores yet")
      return(reactable(data, compact = TRUE))
    }
    reactable(data, compact = TRUE, striped = TRUE,
      selection = "single",
      onClick = "select",
      rowStyle = list(cursor = "pointer"),
      defaultPageSize = 20,
      showPageSizeOptions = TRUE,
      pageSizeOptions = c(10, 20, 50, 100),
      columns = list(
        store_id = colDef(show = FALSE),
        is_online = colDef(
          name = "Type",
          cell = function(value) if (isTRUE(value)) "Online" else "Physical"
        )
      )
    )
  })

  # Handle store selection for editing
  observeEvent(input$admin_store_list__reactable__selected, {
    req(rv$db_con)
    selected_idx <- input$admin_store_list__reactable__selected

    if (is.null(selected_idx) || length(selected_idx) == 0) {
      return()
    }

    # Get store data
    data <- dbGetQuery(rv$db_con, "
      SELECT store_id, name, address, city, state, zip_code, website, schedule_info, is_online
      FROM stores
      WHERE is_active = TRUE
      ORDER BY name
    ")

    if (selected_idx > nrow(data)) return()

    store <- data[selected_idx, ]

    # Populate form for editing
    updateTextInput(session, "editing_store_id", value = as.character(store$store_id))

    # Handle online store fields
    is_online <- isTRUE(store$is_online)
    updateCheckboxInput(session, "store_is_online", value = is_online)

    if (is_online) {
      updateTextInput(session, "store_name_online", value = store$name)
      updateTextInput(session, "store_region", value = if (is.na(store$city)) "" else store$city)
      updateTextInput(session, "store_name", value = "")  # Clear physical store name
    } else {
      updateTextInput(session, "store_name", value = store$name)
      updateTextInput(session, "store_name_online", value = "")  # Clear online store name
      updateTextInput(session, "store_region", value = "")
    }

    updateTextInput(session, "store_address", value = if (is.na(store$address)) "" else store$address)
    updateTextInput(session, "store_city", value = if (is.na(store$city)) "" else store$city)
    updateSelectInput(session, "store_state", selected = if (is.na(store$state)) "TX" else store$state)
    updateTextInput(session, "store_zip", value = if (is.na(store$zip_code)) "" else store$zip_code)
    updateTextInput(session, "store_website", value = if (is.na(store$website)) "" else store$website)
    updateTextAreaInput(session, "store_schedule", value = if (is.na(store$schedule_info)) "" else store$schedule_info)

    # Show/hide buttons
    shinyjs::hide("add_store")
    shinyjs::show("update_store")
    shinyjs::show("delete_store")

    showNotification(sprintf("Editing: %s", store$name), type = "message", duration = 2)
  })

  # Update store
  observeEvent(input$update_store, {
    req(rv$is_admin, rv$db_con)
    req(input$editing_store_id)

    store_id <- as.integer(input$editing_store_id)
    is_online <- isTRUE(input$store_is_online)

    store_name <- if (is_online) {
      trimws(input$store_name_online)
    } else {
      trimws(input$store_name)
    }

    store_city <- if (is_online) {
      trimws(input$store_region)
    } else {
      trimws(input$store_city)
    }

    if (nchar(store_name) == 0) {
      showNotification("Store name is required", type = "error")
      return()
    }

    # City only required for physical stores
    if (!is_online && nchar(store_city) == 0) {
      showNotification("Please enter a city", type = "error")
      return()
    }

    # Validate website URL format if provided
    if (nchar(input$store_website) > 0 && !grepl("^https?://", input$store_website)) {
      showNotification("Website should start with http:// or https://", type = "warning")
    }

    tryCatch({
      # Online stores don't need geocoding
      if (is_online) {
        lat <- NA_real_
        lng <- NA_real_
        address <- NA_character_
        state <- NA_character_
        zip_code <- NA_character_
        store_city_db <- if (nchar(store_city) > 0) store_city else NA_character_
      } else {
        # Build full address for geocoding
        address_parts <- c(input$store_address, store_city)
        address_parts <- c(address_parts, if (nchar(input$store_state) > 0) input$store_state else "TX")
        if (nchar(input$store_zip) > 0) {
          address_parts <- c(address_parts, input$store_zip)
        }
        full_address <- paste(address_parts, collapse = ", ")

        # Geocode the address
        showNotification("Geocoding address...", type = "message", duration = 2)
        geo_result <- tidygeocoder::geo(full_address, method = "osm", quiet = TRUE)

        lat <- geo_result$lat
        lng <- geo_result$long

        if (is.na(lat) || is.na(lng)) {
          showNotification("Could not geocode address. Keeping existing coordinates.", type = "warning")
          # Keep existing coordinates
          existing <- dbGetQuery(rv$db_con, "SELECT latitude, longitude FROM stores WHERE store_id = ?",
                                 params = list(store_id))
          lat <- existing$latitude
          lng <- existing$longitude
        }

        zip_code <- if (nchar(input$store_zip) > 0) input$store_zip else NA_character_
        address <- if (nchar(input$store_address) > 0) input$store_address else NA_character_
        state <- if (nchar(input$store_state) > 0) input$store_state else "TX"
        store_city_db <- store_city
      }

      schedule_info <- if (nchar(input$store_schedule) > 0) input$store_schedule else NA_character_
      website <- if (nchar(input$store_website) > 0) input$store_website else NA_character_

      dbExecute(rv$db_con, "
        UPDATE stores
        SET name = ?, address = ?, city = ?, state = ?, zip_code = ?,
            latitude = ?, longitude = ?, website = ?, schedule_info = ?, is_online = ?, updated_at = CURRENT_TIMESTAMP
        WHERE store_id = ?
      ", params = list(store_name, address, store_city_db, state, zip_code, lat, lng, website, schedule_info, is_online, store_id))

      showNotification(sprintf("Updated store: %s", store_name), type = "message")

      # Clear form and reset to add mode
      updateTextInput(session, "editing_store_id", value = "")
      updateTextInput(session, "store_name", value = "")
      updateTextInput(session, "store_name_online", value = "")
      updateTextInput(session, "store_region", value = "")
      updateTextInput(session, "store_address", value = "")
      updateTextInput(session, "store_city", value = "")
      updateTextInput(session, "store_zip", value = "")
      updateTextInput(session, "store_website", value = "")
      updateTextAreaInput(session, "store_schedule", value = "")
      updateCheckboxInput(session, "store_is_online", value = FALSE)
      updateSelectInput(session, "store_state", selected = "TX")

      shinyjs::show("add_store")
      shinyjs::hide("update_store")
      shinyjs::hide("delete_store")

      # Update dropdown
      updateSelectInput(session, "tournament_store", choices = get_store_choices(rv$db_con))

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Cancel edit store
  observeEvent(input$cancel_edit_store, {
    updateTextInput(session, "editing_store_id", value = "")
    updateTextInput(session, "store_name", value = "")
    updateTextInput(session, "store_name_online", value = "")
    updateTextInput(session, "store_region", value = "")
    updateTextInput(session, "store_address", value = "")
    updateTextInput(session, "store_city", value = "")
    updateTextInput(session, "store_zip", value = "")
    updateTextInput(session, "store_website", value = "")
    updateTextAreaInput(session, "store_schedule", value = "")
    updateCheckboxInput(session, "store_is_online", value = FALSE)
    updateSelectInput(session, "store_state", selected = "TX")

    shinyjs::show("add_store")
    shinyjs::hide("update_store")
    shinyjs::hide("delete_store")
  })

  # Check if store can be deleted (no related tournaments)
  observe({
    req(input$editing_store_id)
    store_id <- as.integer(input$editing_store_id)

    count <- dbGetQuery(rv$db_con, "
      SELECT COUNT(*) as cnt FROM tournaments WHERE store_id = ?
    ", params = list(store_id))$cnt

    rv$store_tournament_count <- count
    rv$can_delete_store <- count == 0
  })

  # Delete button click - show modal
  observeEvent(input$delete_store, {
    req(rv$is_admin, input$editing_store_id)

    store_id <- as.integer(input$editing_store_id)
    store <- dbGetQuery(rv$db_con, "SELECT name FROM stores WHERE store_id = ?",
                        params = list(store_id))

    if (rv$can_delete_store) {
      output$delete_store_message <- renderUI({
        div(
          p(sprintf("Are you sure you want to delete '%s'?", store$name)),
          p(class = "text-danger", "This action cannot be undone.")
        )
      })
      shinyjs::runjs("$('#delete_store_modal').modal('show');")
    } else {
      showNotification(
        sprintf("Cannot delete: %d tournament(s) reference this store", rv$store_tournament_count),
        type = "error"
      )
    }
  })

  # Confirm delete
  observeEvent(input$confirm_delete_store, {
    req(rv$is_admin, rv$db_con, input$editing_store_id)
    store_id <- as.integer(input$editing_store_id)

    tryCatch({
      dbExecute(rv$db_con, "DELETE FROM stores WHERE store_id = ?",
                params = list(store_id))
      showNotification("Store deleted", type = "message")

      # Hide modal and reset form
      shinyjs::runjs("$('#delete_store_modal').modal('hide');")

      # Clear form
      updateTextInput(session, "editing_store_id", value = "")
      updateTextInput(session, "store_name", value = "")
      updateTextInput(session, "store_name_online", value = "")
      updateTextInput(session, "store_region", value = "")
      updateTextInput(session, "store_address", value = "")
      updateTextInput(session, "store_city", value = "")
      updateSelectInput(session, "store_state", selected = "TX")
      updateTextInput(session, "store_zip", value = "")
      updateTextInput(session, "store_website", value = "")
      updateTextAreaInput(session, "store_schedule", value = "")
      updateCheckboxInput(session, "store_is_online", value = FALSE)

      shinyjs::show("add_store")
      shinyjs::hide("update_store")
      shinyjs::hide("delete_store")

      # Update dropdown
      updateSelectInput(session, "tournament_store", choices = get_store_choices(rv$db_con))

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # ---------------------------------------------------------------------------
  # Admin: Manage Formats
  # ---------------------------------------------------------------------------

  # Format list table
  output$admin_format_list <- renderReactable({
    req(rv$db_con)

    # Trigger refresh
    input$add_format
    input$update_format
    input$confirm_delete_format

    data <- dbGetQuery(rv$db_con, "
      SELECT format_id as 'Set Code',
             set_name as 'Set Name',
             release_date as 'Release Date',
             sort_order as 'Sort',
             is_active as 'Active'
      FROM formats
      ORDER BY sort_order
    ")

    if (nrow(data) == 0) {
      return(reactable(data.frame(Message = "No formats added yet")))
    }

    # Format date for display
    data$`Release Date` <- as.character(data$`Release Date`)

    reactable(
      data,
      selection = "single",
      onClick = "select",
      highlight = TRUE,
      compact = TRUE,
      pagination = TRUE,
      defaultPageSize = 20,
      columns = list(
        `Set Code` = colDef(width = 80),
        `Set Name` = colDef(minWidth = 150),
        `Release Date` = colDef(width = 110),
        Sort = colDef(width = 60),
        Active = colDef(width = 70, cell = function(value) if (value) "Yes" else "No")
      )
    )
  })

  # Click row to edit
  observeEvent(input$admin_format_list__reactable__selected, {
    req(rv$db_con)
    selected_idx <- input$admin_format_list__reactable__selected

    if (is.null(selected_idx)) return()

    # Get the format_id from the selected row
    data <- dbGetQuery(rv$db_con, "
      SELECT format_id, set_name, display_name, release_date, sort_order, is_active
      FROM formats
      ORDER BY sort_order
    ")

    if (selected_idx > nrow(data)) return()

    format <- data[selected_idx, ]

    # Fill form
    updateTextInput(session, "editing_format_id", value = format$format_id)
    updateTextInput(session, "format_id", value = format$format_id)
    updateTextInput(session, "format_set_name", value = format$set_name)
    updateTextInput(session, "format_display_name", value = format$display_name)
    updateDateInput(session, "format_release_date", value = format$release_date)
    updateNumericInput(session, "format_sort_order", value = format$sort_order)
    updateCheckboxInput(session, "format_is_active", value = format$is_active)

    # Show/hide buttons
    shinyjs::hide("add_format")
    shinyjs::show("update_format")
    shinyjs::show("delete_format")

    showNotification(sprintf("Editing: %s", format$set_name), type = "message", duration = 2)
  })

  # Add format
  observeEvent(input$add_format, {
    req(rv$is_admin, rv$db_con)

    format_id <- trimws(input$format_id)
    set_name <- trimws(input$format_set_name)
    display_name <- trimws(input$format_display_name)
    release_date <- input$format_release_date
    sort_order <- input$format_sort_order
    is_active <- input$format_is_active

    if (format_id == "" || set_name == "") {
      showNotification("Set Code and Set Name are required", type = "error")
      return()
    }

    # Auto-generate display_name if blank
    if (display_name == "") {
      display_name <- sprintf("%s (%s)", format_id, set_name)
    }

    tryCatch({
      dbExecute(rv$db_con, "
        INSERT INTO formats (format_id, set_name, display_name, release_date, sort_order, is_active)
        VALUES ($1, $2, $3, $4, $5, $6)
      ", params = list(format_id, set_name, display_name, release_date, sort_order, is_active))

      showNotification(sprintf("Added format: %s", display_name), type = "message")

      # Clear form
      updateTextInput(session, "format_id", value = "")
      updateTextInput(session, "format_set_name", value = "")
      updateTextInput(session, "format_display_name", value = "")
      updateDateInput(session, "format_release_date", value = Sys.Date())
      updateNumericInput(session, "format_sort_order", value = 1)
      updateCheckboxInput(session, "format_is_active", value = TRUE)

      # Refresh format choices
      rv$format_refresh <- (rv$format_refresh %||% 0) + 1

    }, error = function(e) {
      if (grepl("unique|duplicate|primary key", e$message, ignore.case = TRUE)) {
        showNotification("A format with this Set Code already exists", type = "error")
      } else {
        showNotification(paste("Error:", e$message), type = "error")
      }
    })
  })

  # Update format
  observeEvent(input$update_format, {
    req(rv$is_admin, rv$db_con, input$editing_format_id)

    original_id <- input$editing_format_id
    format_id <- trimws(input$format_id)
    set_name <- trimws(input$format_set_name)
    display_name <- trimws(input$format_display_name)
    release_date <- input$format_release_date
    sort_order <- input$format_sort_order
    is_active <- input$format_is_active

    if (format_id == "" || set_name == "") {
      showNotification("Set Code and Set Name are required", type = "error")
      return()
    }

    # Auto-generate display_name if blank
    if (display_name == "") {
      display_name <- sprintf("%s (%s)", format_id, set_name)
    }

    tryCatch({
      # If format_id changed, we need to update related tournaments
      if (format_id != original_id) {
        # Update tournaments that reference this format
        dbExecute(rv$db_con, "
          UPDATE tournaments SET format = $1 WHERE format = $2
        ", params = list(format_id, original_id))

        # Delete old and insert new (since format_id is primary key)
        dbExecute(rv$db_con, "DELETE FROM formats WHERE format_id = $1", params = list(original_id))
        dbExecute(rv$db_con, "
          INSERT INTO formats (format_id, set_name, display_name, release_date, sort_order, is_active)
          VALUES ($1, $2, $3, $4, $5, $6)
        ", params = list(format_id, set_name, display_name, release_date, sort_order, is_active))
      } else {
        dbExecute(rv$db_con, "
          UPDATE formats
          SET set_name = $1, display_name = $2, release_date = $3, sort_order = $4, is_active = $5, updated_at = CURRENT_TIMESTAMP
          WHERE format_id = $6
        ", params = list(set_name, display_name, release_date, sort_order, is_active, format_id))
      }

      showNotification(sprintf("Updated format: %s", display_name), type = "message")

      # Reset form
      updateTextInput(session, "editing_format_id", value = "")
      updateTextInput(session, "format_id", value = "")
      updateTextInput(session, "format_set_name", value = "")
      updateTextInput(session, "format_display_name", value = "")
      updateDateInput(session, "format_release_date", value = Sys.Date())
      updateNumericInput(session, "format_sort_order", value = 1)
      updateCheckboxInput(session, "format_is_active", value = TRUE)

      shinyjs::show("add_format")
      shinyjs::hide("update_format")
      shinyjs::hide("delete_format")

      # Refresh format choices
      rv$format_refresh <- (rv$format_refresh %||% 0) + 1

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  # Cancel edit format
  observeEvent(input$cancel_edit_format, {
    updateTextInput(session, "editing_format_id", value = "")
    updateTextInput(session, "format_id", value = "")
    updateTextInput(session, "format_set_name", value = "")
    updateTextInput(session, "format_display_name", value = "")
    updateDateInput(session, "format_release_date", value = Sys.Date())
    updateNumericInput(session, "format_sort_order", value = 1)
    updateCheckboxInput(session, "format_is_active", value = TRUE)

    shinyjs::show("add_format")
    shinyjs::hide("update_format")
    shinyjs::hide("delete_format")
  })

  # Check if format can be deleted (no related tournaments)
  observe({
    req(input$editing_format_id)

    count <- dbGetQuery(rv$db_con, "
      SELECT COUNT(*) as cnt FROM tournaments WHERE format = ?
    ", params = list(input$editing_format_id))$cnt

    rv$format_tournament_count <- count
    rv$can_delete_format <- count == 0
  })

  # Delete button click - show modal
  observeEvent(input$delete_format, {
    req(rv$is_admin, input$editing_format_id)

    format <- dbGetQuery(rv$db_con, "SELECT set_name, display_name FROM formats WHERE format_id = ?",
                         params = list(input$editing_format_id))

    if (rv$can_delete_format) {
      output$delete_format_message <- renderUI({
        div(
          p(sprintf("Are you sure you want to delete '%s'?", format$display_name)),
          p(class = "text-danger", "This action cannot be undone.")
        )
      })
      shinyjs::runjs("$('#delete_format_modal').modal('show');")
    } else {
      showNotification(
        sprintf("Cannot delete: %d tournament(s) use this format", rv$format_tournament_count),
        type = "error"
      )
    }
  })

  # Confirm delete format
  observeEvent(input$confirm_delete_format, {
    req(rv$is_admin, rv$db_con, input$editing_format_id)

    tryCatch({
      dbExecute(rv$db_con, "DELETE FROM formats WHERE format_id = ?",
                params = list(input$editing_format_id))
      showNotification("Format deleted", type = "message")

      # Hide modal and reset form
      shinyjs::runjs("$('#delete_format_modal').modal('hide');")

      updateTextInput(session, "editing_format_id", value = "")
      updateTextInput(session, "format_id", value = "")
      updateTextInput(session, "format_set_name", value = "")
      updateTextInput(session, "format_display_name", value = "")
      updateDateInput(session, "format_release_date", value = Sys.Date())
      updateNumericInput(session, "format_sort_order", value = 1)
      updateCheckboxInput(session, "format_is_active", value = TRUE)

      shinyjs::show("add_format")
      shinyjs::hide("update_format")
      shinyjs::hide("delete_format")

      # Refresh format choices
      rv$format_refresh <- (rv$format_refresh %||% 0) + 1

    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })
}

# =============================================================================
# Run App
# =============================================================================

shinyApp(ui = ui, server = server)
