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
source("R/ratings.R")

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
  # Use "U" for Blue to distinguish from Black ("B")
  get_color_initial <- function(color) {
    color_lower <- tolower(trimws(color))
    if (color_lower == "blue") return("U")
    toupper(substr(color, 1, 1))
  }

  htmltools::div(
    class = "deck-badge-multi",
    htmltools::span(class = get_color_class(primary), get_color_initial(primary)),
    htmltools::span(class = get_color_class(secondary), get_color_initial(secondary))
  )
}

# =============================================================================
# Helper: Custom Notification
# =============================================================================

notify <- function(message, type = "message", duration = 5) {
  # Map type to icon and class
  icon_name <- switch(type,
    "message" = "check-circle",
    "warning" = "triangle-exclamation",
    "error" = "circle-xmark",
    "check-circle"
  )

  type_class <- switch(type,
    "message" = "notify-success",
    "warning" = "notify-warning",
    "error" = "notify-error",
    "notify-success"
  )

  # Build notification UI with icon
  ui <- tags$div(
    class = paste("custom-notification", type_class),
    tags$span(class = "notify-icon", icon(icon_name)),
    tags$span(class = "notify-message", message)
  )

  showNotification(
    ui = ui,
    duration = duration,
    closeButton = TRUE,
    type = type
  )
}

# =============================================================================
# Helper: Digital Empty State
# =============================================================================

digital_empty_state <- function(title = "No signal detected",
                                 subtitle = "// awaiting data",
                                 icon = "reception-0") {
  div(
    class = "empty-state-digital",
    div(class = "empty-state-corners"),
    div(class = "empty-state-icon", bsicons::bs_icon(icon)),
    div(class = "empty-state-title", title),
    div(class = "empty-state-subtitle", subtitle)
  )
}

# =============================================================================
# Configuration
# =============================================================================

# Admin password - MUST be set via environment variable
ADMIN_PASSWORD <- Sys.getenv("ADMIN_PASSWORD")
if (ADMIN_PASSWORD == "") {
  warning("ADMIN_PASSWORD environment variable not set - admin login disabled")
  ADMIN_PASSWORD <- NULL
}

# Event type choices
EVENT_TYPES <- c(
  "Locals" = "locals",
  "Online Tournament" = "online",
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
source("views/admin-formats-ui.R", local = TRUE)
source("views/admin-players-ui.R", local = TRUE)

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
    # JavaScript to handle active nav state and loading screen
    tags$script(HTML("
      $(document).on('click', '.nav-link-sidebar', function() {
        $('.nav-link-sidebar').removeClass('active');
        $(this).addClass('active');
      });

      // Loading screen message cycling
      var loadingMessages = [
        { main: 'Opening Digital Gate...', sub: 'Establishing connection' },
        { main: 'Scanning Local Meta...', sub: 'Loading tournament data' },
        { main: 'Synchronizing...', sub: 'Preparing tool' }
      ];
      var currentMessage = 0;

      function cycleLoadingMessage() {
        if (currentMessage < loadingMessages.length) {
          var msg = loadingMessages[currentMessage];
          $('.loading-message').text(msg.main);
          $('.loading-submessage').text(msg.sub);
          currentMessage++;
        }
      }

      // Function to hide loading screen (called from Shiny server)
      Shiny.addCustomMessageHandler('hideLoading', function(message) {
        setTimeout(function() {
          $('.app-loading-overlay').addClass('loaded');
        }, 500);
      });

      // Inject loading overlay into body on document ready (avoids prependContent warning)
      $(document).ready(function() {
        var loadingHTML = '<div class=\"app-loading-overlay\">' +
          '<div class=\"loading-scanline\"></div>' +
          '<div class=\"loading-gate\"><div class=\"loading-gate-center\"></div></div>' +
          '<div class=\"loading-message\">Opening Digital Gate...</div>' +
          '<div class=\"loading-submessage\">Establishing connection</div>' +
        '</div>';
        $('body').prepend(loadingHTML);
        setInterval(cycleLoadingMessage, 1200);
      });
    "))
  ),

  # Header Bar
  div(
    class = "app-header",
    div(
      class = "header-title",
      # Cards icon (placeholder until digivice icon is found)
      span(
        class = "header-icon",
        HTML('<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 14 14" height="20" width="20">
          <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" d="M6.54619 0.85725c0.06787 -0.253169 0.3281 -0.403409 0.58128 -0.335603L13.1479 2.13401c0.2533 0.06783 0.4036 0.32817 0.3357 0.58143l-2.3101 8.61726c-0.0679 0.2532 -0.3281 0.4034 -0.5813 0.3356l-6.02048 -1.6124c-0.25327 -0.06779 -0.40358 -0.32813 -0.33569 -0.58139L6.54619 0.85725Z" stroke-width="1"></path>
          <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" d="M6.10793 2.53467 0.851879 3.94374c-0.253168 0.06787 -0.403409 0.32809 -0.335603 0.58128L2.82425 13.1429c0.06783 0.2532 0.32817 0.4035 0.58143 0.3356l3.01003 -0.8069" stroke-width="1"></path>
        </svg>')
      ),
      span("Digimon TCG Tracker", class = "header-title-text"),
      span(class = "header-badge", "BETA"),
      span(class = "header-circuit-line")
    ),
    div(
      class = "header-actions",
      tags$a(
        href = "https://github.com/lopezmichael/digimon-tcg-standings",
        target = "_blank",
        class = "header-action-btn",
        title = "View on GitHub",
        bsicons::bs_icon("github")
      ),
      tags$a(
        href = "https://ko-fi.com/atomshell",
        target = "_blank",
        class = "header-action-btn header-coffee-btn",
        title = "Support on Ko-fi",
        bsicons::bs_icon("cup-hot")
      ),
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
      title = NULL,  # Remove the "Menu" title
      width = 220,
      bg = "#0A3055",
      open = "desktop",  # Closed on mobile by default

      # Digimon TCG Logo (saved locally in www/)
      div(
        class = "sidebar-logo-container",
        tags$img(
          src = "digimon-logo.png",
          class = "sidebar-logo",
          alt = "Digimon TCG"
        )
      ),

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
                     class = "nav-link-sidebar"),
          actionLink("nav_admin_players",
                     tagList(bsicons::bs_icon("people"), " Manage Players"),
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
        nav_panel_hidden(value = "admin_formats", admin_formats_ui),
        nav_panel_hidden(value = "admin_players", admin_players_ui)
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
    selected_online_store_detail = NULL,  # For online store detail modal
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
  # Source Server Modules
  # ---------------------------------------------------------------------------

  source("server/shared-server.R", local = TRUE)
  source("server/results-server.R", local = TRUE)
  source("server/admin-decks-server.R", local = TRUE)
  source("server/admin-stores-server.R", local = TRUE)
  source("server/admin-formats-server.R", local = TRUE)
  source("server/admin-players-server.R", local = TRUE)

  # ---------------------------------------------------------------------------
  # Rating Calculations (reactive)
  # ---------------------------------------------------------------------------

  # Reactive: Calculate competitive ratings for all players
  player_competitive_ratings <- reactive({
    if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) {
      return(data.frame(player_id = integer(), competitive_rating = numeric()))
    }
    # Invalidate when results change
    rv$results_refresh
    calculate_competitive_ratings(rv$db_con)
  })

  # Reactive: Calculate achievement scores for all players
  player_achievement_scores <- reactive({
    if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) {
      return(data.frame(player_id = integer(), achievement_score = numeric()))
    }
    rv$results_refresh
    calculate_achievement_scores(rv$db_con)
  })

  # Reactive: Calculate store ratings
  store_ratings <- reactive({
    if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) {
      return(data.frame(store_id = integer(), store_rating = numeric()))
    }
    rv$results_refresh
    player_rtgs <- player_competitive_ratings()
    calculate_store_ratings(rv$db_con, player_rtgs)
  })

  # ---------------------------------------------------------------------------
  # Public Dashboard Data
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

  # Legacy output for backward compatibility (if needed elsewhere)
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
  # Shows Winner column, formatted Type, and Store Rating
  output$recent_tournaments <- renderReactable({
    if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) return(NULL)

    filters <- build_dashboard_filters("t")

    # Query with winner (player who got placement = 1) and store_id for rating join
    query <- sprintf("
      SELECT t.tournament_id, s.store_id, s.name as Store,
             t.event_date as Date, t.event_type as Type,
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

    # Join with store ratings
    str_ratings <- store_ratings()
    data <- merge(data, str_ratings, by = "store_id", all.x = TRUE)
    data$store_rating[is.na(data$store_rating)] <- 0

    # Re-sort by date (merge may have changed order)
    data <- data[order(as.Date(data$Date), decreasing = TRUE), ]

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
        tournament_id = colDef(show = FALSE),
        store_id = colDef(show = FALSE),
        Store = colDef(minWidth = 120),
        Date = colDef(minWidth = 90),
        Type = colDef(minWidth = 80),
        Players = colDef(minWidth = 60, align = "center"),
        Winner = colDef(minWidth = 100),
        store_rating = colDef(
          name = "Store",
          minWidth = 60,
          align = "center",
          cell = function(value) if (value == 0) "-" else value
        )
      )
    )
  })

  # Top players (filters by selected stores, format, date range)
  # Shows: Player, Events, Event Wins, Top 3, Rating (Elo), Achievement
  output$top_players <- renderReactable({
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

  # Store list (uses filtered stores from map selection)
  output$store_list <- renderReactable({
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
    rv$selected_store_detail <- input$store_clicked
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
    rv$selected_online_store_detail <- input$online_store_click
  })

  # Online store detail modal
  output$online_store_detail_modal <- renderUI({
    req(rv$selected_online_store_detail)

    store_id <- rv$selected_online_store_detail

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
    updateSelectInput(session, "players_min_events", selected = "")
  })

  output$player_standings <- renderReactable({
    if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) return(NULL)

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
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as '1sts',
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as 'Top 3s'
      FROM players p
      JOIN results r ON p.player_id = r.player_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s
      GROUP BY p.player_id, p.display_name
      HAVING COUNT(DISTINCT r.tournament_id) >= %d
    ", search_filter, format_filter, min_events))

    # Get most played deck for each player (Main Deck)
    main_decks <- dbGetQuery(rv$db_con, sprintf("
      WITH player_deck_counts AS (
        SELECT r.player_id, da.archetype_name, da.primary_color,
               COUNT(*) as times_played,
               ROW_NUMBER() OVER (PARTITION BY r.player_id ORDER BY COUNT(*) DESC) as rn
        FROM results r
        JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
        JOIN tournaments t ON r.tournament_id = t.tournament_id
        WHERE da.archetype_name != 'UNKNOWN' %s %s
        GROUP BY r.player_id, da.archetype_name, da.primary_color
      )
      SELECT player_id, archetype_name as main_deck, primary_color as main_deck_color
      FROM player_deck_counts
      WHERE rn = 1
    ", search_filter, format_filter))

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
        class = "modal-stats-box d-flex justify-content-evenly mb-3 p-3 flex-wrap",
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value", stats$events),
          div(class = "modal-stat-label", "Events")
        ),
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value", sprintf("%d-%d", stats$wins, stats$losses)),
          div(class = "modal-stat-label", "Record")
        ),
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value", if (!is.na(stats$win_pct)) paste0(stats$win_pct, "%") else "-"),
          div(class = "modal-stat-label", "Win Rate")
        ),
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value stat-highlight place-1st", stats$first_places),
          div(class = "modal-stat-label", "1st Places")
        ),
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value", stats$top3),
          div(class = "modal-stat-label", "Top 3s")
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

  # Reset meta filters
  observeEvent(input$reset_meta_filters, {
    updateTextInput(session, "meta_search", value = "")
    updateSelectInput(session, "meta_format", selected = "")
    updateSelectInput(session, "meta_min_entries", selected = "")
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
            class = "modal-stats-box d-flex justify-content-evenly flex-wrap p-3 h-100 align-items-center",
            div(
              class = "modal-stat-item",
              div(class = "modal-stat-value", stats$entries),
              div(class = "modal-stat-label", "Entries")
            ),
            div(
              class = "modal-stat-item",
              div(class = "modal-stat-value", stats$pilots),
              div(class = "modal-stat-label", "Pilots")
            ),
            div(
              class = "modal-stat-item",
              div(class = "modal-stat-value stat-highlight place-1st", stats$first_places),
              div(class = "modal-stat-label", "1st Places")
            ),
            div(
              class = "modal-stat-item",
              div(class = "modal-stat-value", stats$top3),
              div(class = "modal-stat-label", "Top 3s")
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

      # Top pilots
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
      defaultPageSize = 32,
      defaultSorted = list(Date = "desc"),
      rowStyle = list(cursor = "pointer"),
      onClick = JS("function(rowInfo, column) {
        if (rowInfo) {
          Shiny.setInputValue('tournament_clicked', rowInfo.row.tournament_id, {priority: 'event'})
        }
      }"),
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

  # Handle tournament row click - open detail modal
  observeEvent(input$tournament_clicked, {
    rv$selected_tournament_id <- input$tournament_clicked
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
        class = "modal-stats-box d-flex justify-content-evenly mb-3 p-3 flex-wrap",
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value", event_type_display),
          div(class = "modal-stat-label", "Event Type")
        ),
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value", if (!is.na(tournament$format)) tournament$format else "-"),
          div(class = "modal-stat-label", "Format")
        ),
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value stat-highlight", tournament$player_count),
          div(class = "modal-stat-label", "Players")
        ),
        div(
          class = "modal-stat-item",
          div(class = "modal-stat-value", if (!is.na(tournament$rounds)) tournament$rounds else "-"),
          div(class = "modal-stat-label", "Rounds")
        )
      ),

      # Full standings
      if (nrow(results) > 0) {
        tagList(
          h6(class = "modal-section-header", "Final Standings"),
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
                    class = if (row$Place == 1) "place-1st" else if (row$Place == 2) "place-2nd" else if (row$Place == 3) "place-3rd" else "",
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
        digital_empty_state("No results recorded", "// tournament data pending", "list-ul")
      }
    ))
  })

}

# =============================================================================
# Run App
# =============================================================================

shinyApp(ui = ui, server = server)
