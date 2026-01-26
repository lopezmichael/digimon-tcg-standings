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
library(atomtemplates)
library(sysfonts)
library(showtext)

# Load modules
source("R/db_connection.R")
source("R/digimoncard_api.R")

# Load environment variables
if (file.exists(".env")) {
  readRenviron(".env")
}

# Setup Atom Google Fonts
setup_atom_google_fonts()

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
    current_nav = "dashboard"
  )

  # ---------------------------------------------------------------------------
  # Database Connection
  # ---------------------------------------------------------------------------

  observe({
    rv$db_con <- connect_db()
  })

  onStop(function() {
    if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
      disconnect(rv$db_con)
    }
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

  # Recent tournaments
  output$recent_tournaments <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)
    data <- dbGetQuery(rv$db_con, "
      SELECT s.name as Store, t.event_date as Date, t.event_type as Type, t.player_count as Players
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      ORDER BY t.event_date DESC
      LIMIT 10
    ")
    if (nrow(data) == 0) {
      data <- data.frame(Message = "No tournaments yet")
    }
    reactable(data, compact = TRUE, striped = TRUE)
  })

  # Top players
  output$top_players <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)
    result <- dbGetQuery(rv$db_con, "
      SELECT display_name as Player, tournaments_played as Events,
             total_wins as Wins, total_losses as Losses, win_rate as 'Win %'
      FROM player_standings
      WHERE tournaments_played > 0
      ORDER BY win_rate DESC, tournaments_played DESC
      LIMIT 10
    ")
    if (nrow(result) == 0) {
      result <- data.frame(Message = "No player data yet")
    }
    reactable(result, compact = TRUE, striped = TRUE)
  })

  # Meta summary
  output$meta_summary <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)
    result <- dbGetQuery(rv$db_con, "
      SELECT archetype_name as Deck, primary_color as Color,
             times_played as 'Times Played', tournament_wins as Wins, win_rate as 'Win %'
      FROM archetype_meta
      WHERE times_played > 0
      ORDER BY times_played DESC
      LIMIT 15
    ")
    if (nrow(result) == 0) {
      result <- data.frame(Message = "No tournament data yet")
    }
    reactable(result, compact = TRUE, striped = TRUE)
  })

  # Store list
  output$store_list <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)
    data <- dbGetQuery(rv$db_con, "
      SELECT name as Store, city as City, address as Address
      FROM stores
      WHERE is_active = TRUE
      ORDER BY city, name
    ")
    if (nrow(data) == 0) {
      data <- data.frame(Message = "No stores yet")
    }
    reactable(data, compact = TRUE, striped = TRUE)
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
      result <- data.frame(Message = "No tournament data yet. Add tournament results to see meta analysis.")
    }
    reactable(result, compact = TRUE, striped = TRUE)
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
        INSERT INTO results (result_id, tournament_id, player_id, archetype_id, placement, wins, losses, ties)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ", params = list(result_id, rv$active_tournament_id, player_id, archetype_id, placement, wins, losses, ties))

      showNotification("Result added!", type = "message")

      # Reset form for next entry
      updateNumericInput(session, "result_placement", value = placement + 1)
      updateNumericInput(session, "result_wins", value = 0)
      updateNumericInput(session, "result_losses", value = 0)
      updateNumericInput(session, "result_ties", value = 0)
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
      SELECT archetype_name as Deck, primary_color as Color, display_card_id as 'Card ID'
      FROM deck_archetypes
      WHERE is_active = TRUE
      ORDER BY archetype_name
    ")
    if (nrow(data) == 0) {
      data <- data.frame(Message = "No archetypes yet")
    }
    reactable(data, compact = TRUE, striped = TRUE)
  })

  # ---------------------------------------------------------------------------
  # Admin - Store Management
  # ---------------------------------------------------------------------------

  # Add store
  observeEvent(input$add_store, {
    req(rv$is_admin, rv$db_con)
    req(input$store_name, input$store_city)

    tryCatch({
      max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(store_id), 0) as max_id FROM stores")$max_id
      new_id <- max_id + 1

      schedule_json <- if (nchar(input$store_schedule) > 0) input$store_schedule else NULL
      website <- if (nchar(input$store_website) > 0) input$store_website else NULL

      dbExecute(rv$db_con, "
        INSERT INTO stores (store_id, name, address, city, latitude, longitude, website, schedule_info)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ", params = list(new_id, input$store_name, input$store_address, input$store_city,
                       input$store_lat, input$store_lng, website, schedule_json))

      showNotification(paste("Added store:", input$store_name), type = "message")

      # Clear form
      updateTextInput(session, "store_name", value = "")
      updateTextInput(session, "store_address", value = "")
      updateTextInput(session, "store_city", value = "")
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
