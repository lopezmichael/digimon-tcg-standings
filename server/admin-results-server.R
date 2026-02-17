# =============================================================================
# Admin: Tournament Entry & Results Server Logic
# =============================================================================

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

  # Date validation
  if (is.null(input$tournament_date) || is.na(input$tournament_date)) {
    showNotification("Please select a tournament date", type = "error")
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

# Clear tournament - show modal with options
observeEvent(input$clear_tournament, {
  req(rv$active_tournament_id)

  # Count current results for this tournament
  result_count <- 0
  if (!is.null(rv$db_con)) {
    result_count <- dbGetQuery(rv$db_con,
      "SELECT COUNT(*) as cnt FROM results WHERE tournament_id = ?",
      params = list(rv$active_tournament_id))$cnt
  }

  output$start_over_message <- renderUI({
    if (result_count > 0) {
      p(class = "text-muted", sprintf("This tournament has %d result(s) entered.", result_count))
    } else {
      p(class = "text-muted", "This tournament has no results entered yet.")
    }
  })

  output$delete_tournament_warning <- renderUI({
    tags$small(class = "text-danger text-center",
      if (result_count > 0) {
        sprintf("Permanently delete this tournament and all %d result(s).", result_count)
      } else {
        "Permanently delete this tournament."
      }
    )
  })

  shinyjs::runjs("$('#start_over_modal').modal('show');")
})

# Clear results only - keep tournament, remove results
observeEvent(input$clear_results_only, {
  req(rv$active_tournament_id, rv$db_con)

  tryCatch({
    dbExecute(rv$db_con,
      "DELETE FROM results WHERE tournament_id = ?",
      params = list(rv$active_tournament_id))

    rv$current_results <- data.frame()
    rv$results_refresh <- (rv$results_refresh %||% 0) + 1

    # Recalculate ratings cache
    recalculate_ratings_cache(rv$db_con)
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

    shinyjs::runjs("$('#start_over_modal').modal('hide');")
    showNotification("Results cleared. Tournament kept for re-entry.", type = "message")

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Delete tournament and all results
observeEvent(input$delete_tournament_confirm, {
  req(rv$active_tournament_id, rv$db_con)

  tryCatch({
    # Delete results first (child records)
    dbExecute(rv$db_con,
      "DELETE FROM results WHERE tournament_id = ?",
      params = list(rv$active_tournament_id))

    # Delete tournament (parent record)
    dbExecute(rv$db_con,
      "DELETE FROM tournaments WHERE tournament_id = ?",
      params = list(rv$active_tournament_id))

    # Reset state
    rv$active_tournament_id <- NULL
    rv$current_results <- data.frame()
    rv$wizard_step <- 1

    shinyjs::runjs("$('#start_over_modal').modal('hide');")
    showNotification("Tournament deleted.", type = "message")

    # Recalculate ratings cache
    recalculate_ratings_cache(rv$db_con)

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Hide date required hint when date is selected
observeEvent(input$tournament_date, {
  # Check if date is valid (not null, has length > 0, and not NA)
  date_valid <- !is.null(input$tournament_date) &&
                length(input$tournament_date) > 0 &&
                !anyNA(input$tournament_date)

  if (date_valid) {
    shinyjs::hide("date_required_hint")
    shinyjs::runjs("$('#tournament_date').closest('.date-required').removeClass('date-required');")
  } else {
    shinyjs::show("date_required_hint")
    shinyjs::runjs("$('#tournament_date').closest('.shiny-date-input').addClass('date-required');")
  }
}, ignoreNULL = FALSE)

# Wizard back button
observeEvent(input$wizard_back, {
  rv$wizard_step <- 1
})

# Handle "View/Edit Existing" button from duplicate modal
observeEvent(input$edit_existing_tournament, {
  req(rv$duplicate_tournament)
  shinyjs::runjs("$('#duplicate_tournament_modal').modal('hide');")

  # Store the tournament ID so Edit Tournaments can select it
  rv$navigate_to_tournament_id <- rv$duplicate_tournament$tournament_id

  # Navigate to Edit Tournaments tab
  nav_select("main_content", "admin_tournaments")
  rv$current_nav <- "admin_tournaments"
  session$sendCustomMessage("updateSidebarNav", "nav_admin_tournaments")
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
    class = "tournament-summary-bar",
    span(class = "summary-icon", bsicons::bs_icon("geo-alt-fill")),
    span(class = "summary-item", info$store_name),
    span(class = "summary-divider", "|"),
    span(class = "summary-item", format(as.Date(info$event_date), "%b %d, %Y")),
    span(class = "summary-divider", "|"),
    span(class = "summary-item", info$event_type),
    span(class = "summary-divider", "|"),
    span(class = "summary-item", sprintf("%d players", info$player_count))
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
  updateTextInput(session, "quick_player_member", value = "")
})

# Submit quick add player
observeEvent(input$quick_add_player_submit, {
  req(rv$db_con)
  name <- trimws(input$quick_player_name)
  member_number <- trimws(input$quick_player_member %||% "")

  if (nchar(name) == 0) {
    showNotification("Please enter a player name", type = "error")
    return()
  }

  # Convert empty string to NA for database

  member_number <- if (nchar(member_number) == 0) NA_character_ else member_number

  tryCatch({
    max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(player_id), 0) as max_id FROM players")$max_id
    player_id <- max_id + 1

    dbExecute(rv$db_con, "INSERT INTO players (player_id, display_name, member_number) VALUES (?, ?, ?)",
              params = list(player_id, name, member_number))

    showNotification(sprintf("Added player: %s", name), type = "message")

    # Update dropdown and select new player
    choices <- get_player_choices(rv$db_con)
    updateSelectizeInput(session, "result_player", choices = choices, selected = player_id)

    # Hide form and clear
    shinyjs::hide("quick_add_player_form")
    updateTextInput(session, "quick_player_name", value = "")
    updateTextInput(session, "quick_player_member", value = "")

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

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

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

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
    # Player must be selected from dropdown (create = FALSE)
    # player_input should always be a numeric ID string
    if (!grepl("^\\d+$", player_input)) {
      showNotification("Please select a player from the dropdown. Use '+ New Player' to add new players.", type = "error")
      return()
    }

    player_id <- as.integer(player_input)

    # Verify player exists
    player_exists <- dbGetQuery(rv$db_con, "
      SELECT player_id FROM players WHERE player_id = ?
    ", params = list(player_id))

    if (nrow(player_exists) == 0) {
      showNotification("Selected player not found. Please select a valid player.", type = "error")
      return()
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

    # Recalculate ratings cache
    recalculate_ratings_cache(rv$db_con)

    # Trigger table refresh (admin + public tables)
    rv$results_refresh <- rv$results_refresh + 1
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

    # Reset form for next entry
    updateNumericInput(session, "result_placement", value = placement + 1)
    updateNumericInput(session, "result_wins", value = 0)
    updateNumericInput(session, "result_losses", value = 0)
    updateNumericInput(session, "result_ties", value = 0)
    updateTextInput(session, "result_decklist_url", value = "")
    updateSelectizeInput(session, "result_player", selected = "")
    updateSelectizeInput(session, "result_deck", selected = "")

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

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

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
    SELECT r.result_id, p.display_name as Player, da.archetype_name as Deck,
           r.placement as Place, r.wins as W, r.losses as L, r.ties as T
    FROM results r
    JOIN players p ON r.player_id = p.player_id
    LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    WHERE r.tournament_id = ?
    ORDER BY r.placement
  ", params = list(rv$active_tournament_id))

  if (nrow(results) == 0) {
    results <- data.frame(Message = "No results entered yet")
    return(reactable(results, compact = TRUE, striped = TRUE))
  }

  reactable(results, compact = TRUE, striped = TRUE,
    columns = list(
      result_id = colDef(
        name = "",
        width = 70,
        cell = function(value) {
          htmltools::div(
            class = "d-flex gap-1",
            htmltools::tags$button(
              onclick = sprintf("Shiny.setInputValue('edit_result_id', %d, {priority: 'event'})", value),
              class = "btn btn-sm btn-outline-primary p-0 result-action-btn",
              title = "Edit",
              shiny::icon("pencil")
            ),
            htmltools::tags$button(
              onclick = sprintf("Shiny.setInputValue('delete_result_id', %d, {priority: 'event'})", value),
              class = "btn btn-sm btn-outline-danger p-0 result-action-btn",
              title = "Delete",
              shiny::icon("xmark")
            )
          )
        }
      )
    )
  )
})

# Delete result handler
observeEvent(input$delete_result_id, {
  req(rv$db_con, rv$active_tournament_id)
  result_id <- input$delete_result_id

  tryCatch({
    dbExecute(rv$db_con, "DELETE FROM results WHERE result_id = ? AND tournament_id = ?",
              params = list(result_id, rv$active_tournament_id))
    showNotification("Result removed", type = "message")

    # Recalculate ratings cache
    recalculate_ratings_cache(rv$db_con)

    rv$results_refresh <- rv$results_refresh + 1
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1
  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# ---------------------------------------------------------------------------
# Edit Result Handlers
# ---------------------------------------------------------------------------

# Edit result - open modal with existing data
observeEvent(input$edit_result_id, {
  req(rv$db_con, rv$active_tournament_id)
  result_id <- input$edit_result_id

  # Fetch result data
  result <- dbGetQuery(rv$db_con, "
    SELECT r.result_id, r.player_id, r.archetype_id, r.placement,
           r.wins, r.losses, r.ties, r.decklist_url
    FROM results r
    WHERE r.result_id = ? AND r.tournament_id = ?
  ", params = list(result_id, rv$active_tournament_id))

  if (nrow(result) == 0) {
    showNotification("Result not found", type = "error")
    return()
  }

  # Update edit modal dropdowns with current choices
  updateSelectizeInput(session, "edit_result_player",
                       choices = get_player_choices(rv$db_con),
                       selected = result$player_id)
  updateSelectizeInput(session, "edit_result_deck",
                       choices = get_archetype_choices(rv$db_con),
                       selected = result$archetype_id)

  # Populate form fields
  updateTextInput(session, "editing_result_id", value = as.character(result_id))
  updateNumericInput(session, "edit_result_placement", value = result$placement)
  updateNumericInput(session, "edit_result_wins", value = result$wins)
  updateNumericInput(session, "edit_result_losses", value = result$losses)
  updateNumericInput(session, "edit_result_ties", value = result$ties)
  updateTextInput(session, "edit_result_decklist_url",
                  value = if (is.na(result$decklist_url)) "" else result$decklist_url)

  # Show modal
  shinyjs::runjs("$('#edit_result_modal').modal('show');")
})

# Save edited result
observeEvent(input$save_edit_result, {
  req(rv$db_con, rv$active_tournament_id, input$editing_result_id)

  result_id <- as.integer(input$editing_result_id)
  player_id <- as.integer(input$edit_result_player)
  archetype_id <- as.integer(input$edit_result_deck)
  placement <- input$edit_result_placement
  wins <- input$edit_result_wins
  losses <- input$edit_result_losses
  ties <- input$edit_result_ties
  decklist_url <- if (!is.null(input$edit_result_decklist_url) && nchar(input$edit_result_decklist_url) > 0)
    input$edit_result_decklist_url else NA_character_

  # Validation
  if (is.na(player_id)) {
    showNotification("Please select a player", type = "error")
    return()
  }

  if (is.na(archetype_id)) {
    showNotification("Please select a deck", type = "error")
    return()
  }

  if (is.na(placement) || placement < 1) {
    showNotification("Placement must be at least 1", type = "error")
    return()
  }

  tryCatch({
    dbExecute(rv$db_con, "
      UPDATE results
      SET player_id = ?, archetype_id = ?, placement = ?,
          wins = ?, losses = ?, ties = ?, decklist_url = ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE result_id = ? AND tournament_id = ?
    ", params = list(player_id, archetype_id, placement,
                     wins %||% 0, losses %||% 0, ties %||% 0, decklist_url,
                     result_id, rv$active_tournament_id))

    showNotification("Result updated!", type = "message")

    # Recalculate ratings cache
    recalculate_ratings_cache(rv$db_con)

    # Hide modal and refresh table (admin + public tables)
    shinyjs::runjs("$('#edit_result_modal').modal('hide');")
    rv$results_refresh <- rv$results_refresh + 1
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
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
