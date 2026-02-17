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

observeEvent(input$nav_submit, {
  nav_select("main_content", "submit")
  rv$current_nav <- "submit"
})

# Mobile bottom tab bar navigation
observeEvent(input$mob_dashboard, {
  nav_select("main_content", "dashboard")
  rv$current_nav <- "dashboard"
  session$sendCustomMessage("updateSidebarNav", "nav_dashboard")
})
observeEvent(input$mob_players, {
  nav_select("main_content", "players")
  rv$current_nav <- "players"
  session$sendCustomMessage("updateSidebarNav", "nav_players")
})
observeEvent(input$mob_meta, {
  nav_select("main_content", "meta")
  rv$current_nav <- "meta"
  session$sendCustomMessage("updateSidebarNav", "nav_meta")
})
observeEvent(input$mob_tournaments, {
  nav_select("main_content", "tournaments")
  rv$current_nav <- "tournaments"
  session$sendCustomMessage("updateSidebarNav", "nav_tournaments")
})
observeEvent(input$mob_stores, {
  nav_select("main_content", "stores")
  rv$current_nav <- "stores"
  session$sendCustomMessage("updateSidebarNav", "nav_stores")
})
observeEvent(input$mob_submit, {
  nav_select("main_content", "submit")
  rv$current_nav <- "submit"
  session$sendCustomMessage("updateSidebarNav", "nav_submit")
})

observeEvent(input$nav_admin_results, {
  nav_select("main_content", "admin_results")
  rv$current_nav <- "admin_results"
})

observeEvent(input$nav_admin_tournaments, {
  nav_select("main_content", "admin_tournaments")
  rv$current_nav <- "admin_tournaments"
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

# Admin modal navigation (for mobile access)
observeEvent(input$modal_admin_results, {
  removeModal()
  nav_select("main_content", "admin_results")
  rv$current_nav <- "admin_results"
})
observeEvent(input$modal_admin_tournaments, {
  removeModal()
  nav_select("main_content", "admin_tournaments")
  rv$current_nav <- "admin_tournaments"
})
observeEvent(input$modal_admin_players, {
  removeModal()
  nav_select("main_content", "admin_players")
  rv$current_nav <- "admin_players"
})
observeEvent(input$modal_admin_decks, {
  removeModal()
  nav_select("main_content", "admin_decks")
  rv$current_nav <- "admin_decks"
})
observeEvent(input$modal_admin_stores, {
  removeModal()
  nav_select("main_content", "admin_stores")
  rv$current_nav <- "admin_stores"
})
observeEvent(input$modal_admin_formats, {
  removeModal()
  nav_select("main_content", "admin_formats")
  rv$current_nav <- "admin_formats"
})

# Content pages (footer navigation)
observeEvent(input$nav_about, {
  nav_select("main_content", "about")
  rv$current_nav <- "about"
})

observeEvent(input$nav_faq, {
  nav_select("main_content", "faq")
  rv$current_nav <- "faq"
})

observeEvent(input$nav_for_tos, {
  nav_select("main_content", "for_tos")
  rv$current_nav <- "for_tos"
})

# Cross-page navigation links (from content pages)
observeEvent(input$about_to_for_tos, {
  nav_select("main_content", "for_tos")
  rv$current_nav <- "for_tos"
})

observeEvent(input$faq_to_for_tos, {
  nav_select("main_content", "for_tos")
  rv$current_nav <- "for_tos"
})

observeEvent(input$faq_to_about, {
  nav_select("main_content", "about")
  rv$current_nav <- "about"
})

# FAQ → Upload Results
observeEvent(input$faq_to_upload, {
  nav_select("main_content", "submit")
  rv$current_nav <- "submit"
})
observeEvent(input$faq_to_upload2, {
  nav_select("main_content", "submit")
  rv$current_nav <- "submit"
})

# For Organizers → Upload Results (multiple links on the page)
observeEvent(input$tos_to_upload, {
  nav_select("main_content", "submit")
  rv$current_nav <- "submit"
})
observeEvent(input$tos_to_upload_btn, {
  nav_select("main_content", "submit")
  rv$current_nav <- "submit"
})
observeEvent(input$tos_to_upload2, {
  nav_select("main_content", "submit")
  rv$current_nav <- "submit"
})
observeEvent(input$tos_to_upload3, {
  nav_select("main_content", "submit")
  rv$current_nav <- "submit"
})

# ---------------------------------------------------------------------------
# About Page Stats
# ---------------------------------------------------------------------------

output$about_store_count <- renderText({
  req(rv$db_con)
  count <- dbGetQuery(rv$db_con, "SELECT COUNT(*) FROM stores WHERE is_active = TRUE")[[1]]
  as.character(count)
})

output$about_player_count <- renderText({
  req(rv$db_con)
  count <- dbGetQuery(rv$db_con, "SELECT COUNT(*) FROM players WHERE is_active = TRUE")[[1]]
  as.character(count)
})

output$about_tournament_count <- renderText({
  req(rv$db_con)
  count <- dbGetQuery(rv$db_con, "SELECT COUNT(*) FROM tournaments")[[1]]
  as.character(count)
})

output$about_result_count <- renderText({
  req(rv$db_con)
  count <- dbGetQuery(rv$db_con, "SELECT COUNT(*) FROM results")[[1]]
  as.character(count)
})

# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------

# Output for conditional panels
output$is_admin <- reactive({ rv$is_admin })
outputOptions(output, "is_admin", suspendWhenHidden = FALSE)

output$is_superadmin <- reactive({ rv$is_superadmin })
outputOptions(output, "is_superadmin", suspendWhenHidden = FALSE)

output$has_active_tournament <- reactive({ !is.null(rv$active_tournament_id) })
outputOptions(output, "has_active_tournament", suspendWhenHidden = FALSE)

# Login modal
observeEvent(input$admin_login_link, {
  if (rv$is_admin) {
    # Already logged in - show admin nav + logout
    role_label <- if (rv$is_superadmin) "super admin" else "admin"

    # Build admin nav links
    admin_links <- tagList(
      actionLink("modal_admin_results",
                 tagList(bsicons::bs_icon("pencil-square"), " Enter Results"),
                 class = "admin-modal-link"),
      actionLink("modal_admin_tournaments",
                 tagList(bsicons::bs_icon("trophy"), " Edit Tournaments"),
                 class = "admin-modal-link"),
      actionLink("modal_admin_players",
                 tagList(bsicons::bs_icon("people"), " Edit Players"),
                 class = "admin-modal-link"),
      actionLink("modal_admin_decks",
                 tagList(bsicons::bs_icon("collection"), " Edit Decks"),
                 class = "admin-modal-link")
    )

    # Add super admin links if applicable
    superadmin_links <- NULL
    if (rv$is_superadmin) {
      superadmin_links <- tagList(
        tags$hr(class = "my-2"),
        tags$div(class = "admin-modal-section", "Super Admin"),
        actionLink("modal_admin_stores",
                   tagList(bsicons::bs_icon("shop"), " Edit Stores"),
                   class = "admin-modal-link"),
        actionLink("modal_admin_formats",
                   tagList(bsicons::bs_icon("calendar3"), " Edit Formats"),
                   class = "admin-modal-link")
      )
    }

    showModal(modalDialog(
      title = paste0("Admin (", role_label, ")"),
      div(
        class = "admin-modal-nav",
        admin_links,
        superadmin_links
      ),
      footer = tagList(
        actionButton("logout_btn", "Logout", class = "btn-warning"),
        modalButton("Close")
      )
    ))
  } else if (is.null(ADMIN_PASSWORD) && is.null(SUPERADMIN_PASSWORD)) {
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
  pw <- input$admin_password

  if (!is.null(SUPERADMIN_PASSWORD) && pw == SUPERADMIN_PASSWORD) {
    rv$is_admin <- TRUE
    rv$is_superadmin <- TRUE
    removeModal()
    showNotification("Logged in as super admin", type = "message")
  } else if (!is.null(ADMIN_PASSWORD) && pw == ADMIN_PASSWORD) {
    rv$is_admin <- TRUE
    rv$is_superadmin <- FALSE
    removeModal()
    showNotification("Logged in as admin", type = "message")
  } else {
    showNotification("Invalid password", type = "error")
    return()
  }

  # Update dropdowns with data
  updateSelectInput(session, "tournament_store",
                    choices = get_store_choices(rv$db_con, include_none = TRUE))
  updateSelectizeInput(session, "result_deck",
                    choices = get_archetype_choices(rv$db_con))
  updateSelectizeInput(session, "result_player",
                       choices = get_player_choices(rv$db_con),
                       server = TRUE)
})

# Handle logout
observeEvent(input$logout_btn, {
  rv$is_admin <- FALSE
  rv$is_superadmin <- FALSE
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

get_store_choices <- function(con, include_none = FALSE) {
  if (is.null(con) || !dbIsValid(con)) return(c("Loading..." = ""))
  stores <- dbGetQuery(con, "SELECT store_id, name FROM stores WHERE is_active = TRUE ORDER BY name")
  choices <- setNames(stores$store_id, stores$name)
  if (include_none) {
    choices <- c("Select a store..." = "", choices)
  }
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

    # Format choices with "All Formats" option
    format_choices_with_all <- list(
      "All Formats" = "",
      "Recent Formats" = format_choices
    )

    # Update all format dropdowns (default to All Formats to avoid empty results when new format has no data)
    updateSelectInput(session, "dashboard_format", choices = format_choices_with_all, selected = "")
    updateSelectInput(session, "players_format", choices = format_choices_with_all)
    updateSelectInput(session, "meta_format", choices = format_choices_with_all)
    updateSelectInput(session, "tournaments_format", choices = format_choices_with_all)
    updateSelectInput(session, "tournament_format", choices = format_choices)
  }
})

#' Build Parameterized SQL Filters
#'
#' Creates SQL WHERE clause fragments with parameterized placeholders to prevent
#' SQL injection. Returns both the SQL fragment and corresponding parameter values.
#'
#' @param table_alias Character. Table alias to use in SQL (e.g., "t" for "t.format")
#' @param format Character or NULL. Format value for exact match filter
#' @param event_type Character or NULL. Event type value for exact match filter
#' @param search Character or NULL. Search term for LIKE filter (will be wrapped with %)
#' @param search_column Character. Column name for search filter (default: "display_name")
#' @param id Integer or NULL. ID value for exact match filter
#' @param id_column Character. Column name for ID filter (default: "id")
#'
#' @return List with:
#'   - sql: SQL fragment with ? placeholders (e.g., "AND t.format = ?")
#'   - params: List of parameter values in order
#'   - any_active: Boolean indicating if any filters are active
#'
#' @examples
#' filters <- build_filters_param(
#'   table_alias = "t",
#'   format = "BT-19",
#'   event_type = "locals"
#' )
#' # filters$sql: "AND t.format = ? AND t.event_type = ?"
#' # filters$params: list("BT-19", "locals")
#'
#' query <- paste("SELECT * FROM tournaments t WHERE 1=1", filters$sql)
#' dbGetQuery(con, query, params = filters$params)
build_filters_param <- function(table_alias = "t",
                                 format = NULL,
                                 event_type = NULL,
                                 search = NULL,
                                 search_column = "display_name",
                                 id = NULL,
                                 id_column = "id") {
  sql_parts <- character(0)
  params <- list()

  # Format filter (exact match)
  if (!is.null(format) && format != "") {
    sql_parts <- c(sql_parts, sprintf("AND %s.format = ?", table_alias))
    params <- c(params, list(format))
  }

  # Event type filter (exact match)
  if (!is.null(event_type) && event_type != "") {
    sql_parts <- c(sql_parts, sprintf("AND %s.event_type = ?", table_alias))
    params <- c(params, list(event_type))
  }

  # Search filter (LIKE match, case-insensitive)
  if (!is.null(search) && trimws(search) != "") {
    search_term <- trimws(search)
    # Use table alias if search_column doesn't contain a dot (allowing "p.display_name" override)
    col_ref <- if (grepl("\\.", search_column)) {
      search_column
    } else {
      sprintf("%s.%s", table_alias, search_column)
    }
    sql_parts <- c(sql_parts, sprintf("AND LOWER(%s) LIKE LOWER(?)", col_ref))
    params <- c(params, list(paste0("%", search_term, "%")))
  }

  # ID filter (exact match)
  if (!is.null(id) && !is.na(id)) {
    # Use table alias if id_column doesn't contain a dot
    col_ref <- if (grepl("\\.", id_column)) {
      id_column
    } else {
      sprintf("%s.%s", table_alias, id_column)
    }
    sql_parts <- c(sql_parts, sprintf("AND %s = ?", col_ref))
    params <- c(params, list(as.integer(id)))
  }

  list(
    sql = paste(sql_parts, collapse = " "),
    params = params,
    any_active = length(params) > 0
  )
}
