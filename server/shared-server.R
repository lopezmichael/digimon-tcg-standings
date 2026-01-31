# =============================================================================
# Shared Server Logic
# Contains: Database connection, navigation, authentication, helper functions
# =============================================================================

# ---------------------------------------------------------------------------
# Database Connection
# ---------------------------------------------------------------------------

observe({
  rv$db_con <- connect_db()

  # Once database is connected, hide the loading screen
  if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    # Small delay to let initial data queries complete
    shinyjs::delay(800, {
      session$sendCustomMessage("hideLoading", list())
    })
  }
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

observeEvent(input$nav_admin_players, {
  nav_select("main_content", "admin_players")
  rv$current_nav <- "admin_players"
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
  } else if (is.null(ADMIN_PASSWORD)) {
    # Admin login disabled
    showModal(modalDialog(
      title = "Admin Login Disabled",
      "Admin login is not configured. Set the ADMIN_PASSWORD environment variable to enable.",
      footer = modalButton("Close")
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
  if (!is.null(ADMIN_PASSWORD) && input$admin_password == ADMIN_PASSWORD) {
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
  if (is.null(con) || !dbIsValid(con)) {
    return(c("Database unavailable" = ""))
  }
  formats <- dbGetQuery(con, "
    SELECT format_id, display_name
    FROM formats
    WHERE is_active = TRUE
    ORDER BY release_date DESC NULLS LAST
  ")
  if (nrow(formats) == 0) {
    return(c("No formats configured" = ""))
  }
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

    # Format choices with "All Formats" option
    format_choices_with_all <- list(
      "All Formats" = "",
      "Recent Formats" = format_choices
    )

    # Update all format dropdowns
    updateSelectInput(session, "dashboard_format", choices = format_choices_with_all, selected = first_format)
    updateSelectInput(session, "players_format", choices = format_choices_with_all)
    updateSelectInput(session, "meta_format", choices = format_choices_with_all)
    updateSelectInput(session, "tournaments_format", choices = format_choices_with_all)
    updateSelectInput(session, "tournament_format", choices = format_choices)
  }
})
