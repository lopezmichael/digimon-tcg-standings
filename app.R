# =============================================================================
# DigiLab - Digimon TCG Tournament Tracker
# Main Shiny Application
# https://digilab.cards/
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

# App version (update with each release)
APP_VERSION <- "0.20.0"

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

# Super admin password - optional, grants access to Edit Stores and Edit Formats
SUPERADMIN_PASSWORD <- Sys.getenv("SUPERADMIN_PASSWORD")
if (SUPERADMIN_PASSWORD == "") {
  SUPERADMIN_PASSWORD <- NULL
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
source("views/submit-ui.R", local = TRUE)
source("views/admin-results-ui.R", local = TRUE)
source("views/admin-tournaments-ui.R", local = TRUE)
source("views/admin-decks-ui.R", local = TRUE)
source("views/admin-stores-ui.R", local = TRUE)
source("views/admin-formats-ui.R", local = TRUE)
source("views/admin-players-ui.R", local = TRUE)
source("views/about-ui.R", local = TRUE)
source("views/faq-ui.R", local = TRUE)
source("views/for-tos-ui.R", local = TRUE)
source("views/onboarding-modal-ui.R", local = TRUE)

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
    # Open Graph meta tags for link previews (Discord, Twitter, etc.)
    tags$meta(property = "og:title", content = "DigiLab - Digimon TCG Locals Tracker"),
    tags$meta(property = "og:description", content = "Track your local Digimon TCG tournament results, player standings, deck meta, and store events."),
    tags$meta(property = "og:type", content = "website"),
    tags$meta(property = "og:url", content = "https://digilab.cards/"),
    tags$meta(property = "og:site_name", content = "DigiLab"),
    # Twitter Card tags
    tags$meta(name = "twitter:card", content = "summary"),
    tags$meta(name = "twitter:title", content = "DigiLab - Digimon TCG Locals Tracker"),
    tags$meta(name = "twitter:description", content = "Track your local Digimon TCG tournament results, player standings, deck meta, and store events."),
    # Standard meta description
    tags$meta(name = "description", content = "Track your local Digimon TCG tournament results, player standings, deck meta, and store events."),
    # Google Analytics
    tags$script(async = NA, src = "https://www.googletagmanager.com/gtag/js?id=G-NJ3SMG8HGG"),
    tags$script(HTML("
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', 'G-NJ3SMG8HGG');
    ")),
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
    # Deep linking URL routing
    tags$script(src = "url-routing.js"),
    # Scene selection and localStorage
    tags$script(src = "scene-selector.js"),
    # JavaScript to handle active nav state and loading screen
    tags$script(HTML("
      $(document).on('click', '.nav-link-sidebar', function() {
        $('.nav-link-sidebar').removeClass('active');
        $(this).addClass('active');
      });

      // Bottom tab bar - click handler
      $(document).on('click', '.tab-bar-item', function() {
        $('.tab-bar-item').removeClass('active');
        $(this).addClass('active');
      });

      // Map sidebar nav IDs to bottom bar IDs
      var navToTab = {
        'nav_dashboard': 'mob_dashboard',
        'nav_players': 'mob_players',
        'nav_meta': 'mob_meta',
        'nav_tournaments': 'mob_tournaments',
        'nav_stores': 'mob_stores'
      };

      // Custom handler to update sidebar and bottom bar when programmatically navigating
      Shiny.addCustomMessageHandler('updateSidebarNav', function(navId) {
        // Update sidebar
        $('.nav-link-sidebar').removeClass('active');
        $('#' + navId).addClass('active');

        // Update bottom tab bar
        $('.tab-bar-item').removeClass('active');
        var tabId = navToTab[navId];
        if (tabId) {
          $('#' + tabId + ' .tab-bar-item').addClass('active');
        }
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
        // Set initial active tab on mobile bar
        $('#mob_dashboard .tab-bar-item').addClass('active');

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
      span("DigiLab", class = "header-title-text"),
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
      div(
        class = "header-scene-selector",
        selectInput("scene_selector", NULL,
                    choices = list(
                      "All Scenes" = "all",
                      "Dallas-Fort Worth" = "dfw",
                      "Online" = "online"
                    ),
                    selected = "all",
                    width = "140px",
                    selectize = FALSE)
      ),
      input_dark_mode(id = "dark_mode", mode = "light")
    )
  ),

  # Main Layout with Sidebar
  layout_sidebar(
    fillable = TRUE,

    sidebar = sidebar(
      id = "main_sidebar",
      title = NULL,  # Remove the "Menu" title
      width = 230,
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

        # Public tabs (ordered by engagement: overview, rankings, meta, history, reference)
        actionLink("nav_dashboard",
                   tagList(bsicons::bs_icon("graph-up"), " Overview"),
                   class = "nav-link-sidebar active"),
        actionLink("nav_players",
                   tagList(bsicons::bs_icon("people"), " Players"),
                   class = "nav-link-sidebar"),
        actionLink("nav_meta",
                   tagList(bsicons::bs_icon("stack"), " Meta Analysis"),
                   class = "nav-link-sidebar"),
        actionLink("nav_tournaments",
                   tagList(bsicons::bs_icon("trophy"), " Tournaments"),
                   class = "nav-link-sidebar"),
        actionLink("nav_stores",
                   tagList(bsicons::bs_icon("geo-alt"), " Stores"),
                   class = "nav-link-sidebar"),
        actionLink("nav_submit",
                   tagList(bsicons::bs_icon("cloud-upload"), " Upload Results"),
                   class = "nav-link-sidebar"),

        # Admin Section (conditionally shown, ordered by frequency of use)
        conditionalPanel(
          condition = "output.is_admin",
          tags$div(class = "nav-section-label", "Admin"),
          actionLink("nav_admin_results",
                     tagList(bsicons::bs_icon("pencil-square"), " Enter Results"),
                     class = "nav-link-sidebar"),
          actionLink("nav_admin_tournaments",
                     tagList(bsicons::bs_icon("trophy"), " Edit Tournaments"),
                     class = "nav-link-sidebar"),
          actionLink("nav_admin_players",
                     tagList(bsicons::bs_icon("people"), " Edit Players"),
                     class = "nav-link-sidebar"),
          actionLink("nav_admin_decks",
                     tagList(bsicons::bs_icon("collection"), " Edit Decks"),
                     class = "nav-link-sidebar")
        ),

        # Super Admin Section (superadmin only)
        conditionalPanel(
          condition = "output.is_superadmin",
          tags$div(class = "nav-section-label", "Super Admin"),
          actionLink("nav_admin_stores",
                     tagList(bsicons::bs_icon("shop"), " Edit Stores"),
                     class = "nav-link-sidebar"),
          actionLink("nav_admin_formats",
                     tagList(bsicons::bs_icon("calendar3"), " Edit Formats"),
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
        nav_panel_hidden(value = "submit", submit_ui),
        nav_panel_hidden(value = "admin_results", admin_results_ui),
        nav_panel_hidden(value = "admin_tournaments", admin_tournaments_ui),
        nav_panel_hidden(value = "admin_decks", admin_decks_ui),
        nav_panel_hidden(value = "admin_stores", admin_stores_ui),
        nav_panel_hidden(value = "admin_formats", admin_formats_ui),
        nav_panel_hidden(value = "admin_players", admin_players_ui),

        # Content pages (accessed via footer)
        nav_panel_hidden(value = "about", about_ui),
        nav_panel_hidden(value = "faq", faq_ui),
        nav_panel_hidden(value = "for_tos", for_tos_ui)
      )
    )
  ),

  # Footer (outside layout_sidebar to span full width like header)
  tags$footer(
    class = "app-footer",
    tags$nav(
      class = "footer-nav",
      actionLink("nav_about", "About", class = "footer-link"),
      span(class = "footer-divider", "//"),
      actionLink("nav_faq", "FAQ", class = "footer-link"),
      span(class = "footer-divider", "//"),
      actionLink("nav_for_tos", "For Organizers", class = "footer-link")
    ),
    tags$div(
      class = "footer-meta",
      paste0("v", APP_VERSION, " | \u00A9 2026 DigiLab")
    )
  ),

  # Mobile bottom tab bar (hidden on desktop via CSS)
  div(
    id = "mobile_tab_bar",
    class = "mobile-tab-bar",

    actionLink("mob_dashboard", div(
      class = "tab-bar-item",
      bsicons::bs_icon("graph-up"),
      span(class = "tab-bar-label", "Overview")
    )),
    actionLink("mob_players", div(
      class = "tab-bar-item",
      bsicons::bs_icon("people"),
      span(class = "tab-bar-label", "Players")
    )),
    actionLink("mob_meta", div(
      class = "tab-bar-item",
      bsicons::bs_icon("stack"),
      span(class = "tab-bar-label", "Meta")
    )),
    actionLink("mob_tournaments", div(
      class = "tab-bar-item",
      bsicons::bs_icon("trophy"),
      span(class = "tab-bar-label", "Tournaments")
    )),
    actionLink("mob_stores", div(
      class = "tab-bar-item",
      bsicons::bs_icon("geo-alt"),
      span(class = "tab-bar-label", "Stores")
    )),
    actionLink("mob_submit", div(
      class = "tab-bar-item",
      bsicons::bs_icon("cloud-upload"),
      span(class = "tab-bar-label", "Upload")
    ))
  )
)

# =============================================================================
# Server
# =============================================================================

server <- function(input, output, session) {

  # ---------------------------------------------------------------------------
  # Reactive Values
  # See ARCHITECTURE.md for full documentation of each value
  # ---------------------------------------------------------------------------

  rv <- reactiveValues(
    # === CORE ===
    db_con = NULL,
    is_admin = FALSE,
    is_superadmin = FALSE,

    # === NAVIGATION ===
    current_nav = "dashboard",
    current_scene = NULL,              # Scene filter for deep linking (e.g., "dfw")
    navigate_to_tournament_id = NULL,

    # === MODAL STATE ===
    # Pattern: selected_{entity}_id (singular)
    selected_store_id = NULL,
    selected_online_store_id = NULL,
    selected_player_id = NULL,
    selected_archetype_id = NULL,
    selected_tournament_id = NULL,

    # === FORM/WIZARD STATE ===
    wizard_step = 1,
    active_tournament_id = NULL,
    current_results = data.frame(),
    duplicate_tournament = NULL,
    modal_tournament_id = NULL,
    editing_store = NULL,
    editing_archetype = NULL,
    card_search_results = NULL,
    card_search_page = 1,

    # === REFRESH TRIGGERS ===
    # Pattern: {scope}_refresh - increment to trigger reactive invalidation
    data_refresh = 0,
    results_refresh = 0,
    format_refresh = 0,
    tournament_refresh = 0,
    modal_results_refresh = 0,
    schedules_refresh = 0,

    # === STORE FORM STATE ===
    pending_schedules = list(),  # Schedules to add when creating new store

    # === DELETE PERMISSION STATE ===
    # Pattern: can_delete_{entity} + {entity}_{related}_count
    can_delete_store = FALSE,
    can_delete_format = FALSE,
    can_delete_player = FALSE,
    can_delete_archetype = FALSE,
    store_tournament_count = 0,
    format_tournament_count = 0,
    player_result_count = 0,
    archetype_result_count = 0
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
  source("server/url-routing-server.R", local = TRUE)
  source("server/scene-server.R", local = TRUE)
  source("server/admin-results-server.R", local = TRUE)
  source("server/admin-tournaments-server.R", local = TRUE)
  source("server/admin-decks-server.R", local = TRUE)
  source("server/admin-stores-server.R", local = TRUE)
  source("server/admin-formats-server.R", local = TRUE)
  source("server/admin-players-server.R", local = TRUE)

  # Public page server modules
  source("server/public-meta-server.R", local = TRUE)
  source("server/public-stores-server.R", local = TRUE)
  source("server/public-tournaments-server.R", local = TRUE)
  source("server/public-players-server.R", local = TRUE)
  source("server/public-dashboard-server.R", local = TRUE)
  source("server/public-submit-server.R", local = TRUE)

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

  # Reactive: Calculate average player rating per store (weighted by participation)
  store_avg_ratings <- reactive({
    if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) {
      return(data.frame(store_id = integer(), avg_player_rating = numeric()))
    }
    rv$results_refresh
    player_rtgs <- player_competitive_ratings()
    calculate_store_avg_player_rating(rv$db_con, player_rtgs)
  })


}

# =============================================================================
# Run App
# =============================================================================

shinyApp(ui = ui, server = server)
