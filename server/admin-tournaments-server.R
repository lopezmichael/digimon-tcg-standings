# =============================================================================
# Admin: Edit Tournaments Server Logic
# =============================================================================

# Update edit form dropdowns when data changes
observe({
  req(rv$db_con)
  rv$format_refresh

  # Update store dropdown for edit form
  updateSelectInput(session, "edit_tournament_store",
                    choices = get_store_choices(rv$db_con, include_none = TRUE))

  # Update format dropdown for edit form
  format_choices <- get_format_choices(rv$db_con)
  updateSelectInput(session, "edit_tournament_format", choices = format_choices)
})

# Auto-select tournament when navigated from duplicate modal
observe({
  req(rv$navigate_to_tournament_id)

  # Trigger the same logic as clicking a row
  tournament_id <- rv$navigate_to_tournament_id
  rv$navigate_to_tournament_id <- NULL  # Clear to prevent re-triggering

  # Get tournament details
  tournament <- dbGetQuery(rv$db_con, "
    SELECT t.*, s.name as store_name
    FROM tournaments t
    LEFT JOIN stores s ON t.store_id = s.store_id
    WHERE t.tournament_id = ?
  ", params = list(tournament_id))

  if (nrow(tournament) == 0) return()

  # Fill form (same as click handler)
  updateTextInput(session, "editing_tournament_id", value = as.character(tournament$tournament_id))
  updateSelectInput(session, "edit_tournament_store", selected = tournament$store_id)
  updateDateInput(session, "edit_tournament_date", value = tournament$event_date)
  updateSelectInput(session, "edit_tournament_type", selected = tournament$event_type)
  updateSelectInput(session, "edit_tournament_format", selected = tournament$format)
  updateNumericInput(session, "edit_tournament_players", value = tournament$player_count)
  updateNumericInput(session, "edit_tournament_rounds", value = tournament$rounds)

  # Show buttons
  shinyjs::show("update_tournament")
  shinyjs::show("delete_tournament")
  shinyjs::show("view_results_btn_container")

  showNotification(sprintf("Editing: %s - %s", tournament$store_name, tournament$event_date),
                   type = "message", duration = 3)
})

# Tournament list table
output$admin_tournament_list <- renderReactable({
  req(rv$db_con)

  # Trigger refresh
  input$update_tournament
  input$confirm_delete_tournament

  # Search filter
  search <- input$admin_tournament_search %||% ""

  # Build query
  query <- "
    SELECT t.tournament_id,
           s.name as store_name,
           t.event_date,
           t.event_type,
           t.format,
           t.player_count,
           t.rounds,
           COUNT(r.result_id) as results_entered
    FROM tournaments t
    LEFT JOIN stores s ON t.store_id = s.store_id
    LEFT JOIN results r ON t.tournament_id = r.tournament_id
    WHERE 1=1
  "

  if (nchar(search) > 0) {
    query <- paste0(query, " AND LOWER(s.name) LIKE LOWER('%", search, "%')")
  }

  query <- paste0(query, " GROUP BY t.tournament_id, s.name, t.event_date, t.event_type, t.format, t.player_count, t.rounds
                          ORDER BY t.event_date DESC")

  data <- dbGetQuery(rv$db_con, query)

  if (nrow(data) == 0) {
    return(reactable(data.frame(Message = "No tournaments found")))
  }

  # Format event type
  format_event_type <- function(type) {
    type_labels <- c(
      "locals" = "Locals",
      "online" = "Online",
      "evo_cup" = "Evo Cup",
      "store_championship" = "Store Champ",
      "regionals" = "Regionals",
      "regulation_battle" = "Reg Battle",
      "release_event" = "Release",
      "other" = "Other"
    )
    type_labels[type] %||% type
  }

  # Prepare display data
  display_data <- data.frame(
    ID = data$tournament_id,
    Store = data$store_name,
    Date = as.character(data$event_date),
    Type = sapply(data$event_type, format_event_type),
    Format = data$format,
    Players = data$player_count,
    Rounds = data$rounds,
    Results = data$results_entered,
    stringsAsFactors = FALSE
  )

  # Store tournament_id in a way we can retrieve on click
  reactable(
    display_data,
    selection = "single",
    onClick = JS("function(rowInfo, column) {
      if (rowInfo) {
        Shiny.setInputValue('admin_tournament_list_clicked', {
          tournament_id: rowInfo.row.ID,
          nonce: Math.random()
        }, {priority: 'event'});
      }
    }"),
    highlight = TRUE,
    compact = TRUE,
    pagination = TRUE,
    defaultPageSize = 32,
    columns = list(
      ID = colDef(show = FALSE),
      Store = colDef(minWidth = 150),
      Date = colDef(width = 100),
      Type = colDef(width = 90),
      Format = colDef(width = 70),
      Players = colDef(width = 70, align = "center"),
      Rounds = colDef(width = 65, align = "center"),
      Results = colDef(width = 70, align = "center")
    )
  )
})

# Click row to edit
observeEvent(input$admin_tournament_list_clicked, {
  req(rv$db_con)
  tournament_id <- input$admin_tournament_list_clicked$tournament_id

  if (is.null(tournament_id)) return()

  # Get tournament details
  tournament <- dbGetQuery(rv$db_con, "
    SELECT t.*, s.name as store_name
    FROM tournaments t
    LEFT JOIN stores s ON t.store_id = s.store_id
    WHERE t.tournament_id = ?
  ", params = list(tournament_id))

  if (nrow(tournament) == 0) return()

  # Fill form
  updateTextInput(session, "editing_tournament_id", value = as.character(tournament$tournament_id))
  updateSelectInput(session, "edit_tournament_store", selected = tournament$store_id)
  updateDateInput(session, "edit_tournament_date", value = tournament$event_date)
  updateSelectInput(session, "edit_tournament_type", selected = tournament$event_type)
  updateSelectInput(session, "edit_tournament_format", selected = tournament$format)
  updateNumericInput(session, "edit_tournament_players", value = tournament$player_count)
  updateNumericInput(session, "edit_tournament_rounds", value = tournament$rounds)

  # Show buttons
  shinyjs::show("update_tournament")
  shinyjs::show("delete_tournament")

  showNotification(sprintf("Editing: %s - %s", tournament$store_name, tournament$event_date),
                   type = "message", duration = 2)
})

# Tournament stats info
output$tournament_stats_info <- renderUI({
  req(rv$db_con, input$editing_tournament_id)

  tid <- as.integer(input$editing_tournament_id)

  # Get results count
  results_count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM results WHERE tournament_id = ?
  ", params = list(tid))$cnt

  # Get winner info
  winner <- dbGetQuery(rv$db_con, "
    SELECT p.display_name, da.archetype_name
    FROM results r
    JOIN players p ON r.player_id = p.player_id
    LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    WHERE r.tournament_id = ? AND r.placement = 1
  ", params = list(tid))

  tagList(
    div(
      class = "d-flex gap-4 text-muted small",
      div(bsicons::bs_icon("people-fill"), sprintf(" %d results entered", results_count)),
      if (nrow(winner) > 0) {
        div(bsicons::bs_icon("trophy-fill"),
            sprintf(" Winner: %s (%s)", winner$display_name, winner$archetype_name %||% "Unknown deck"))
      }
    )
  )
})

# Update tournament
observeEvent(input$update_tournament, {
  req(rv$is_admin, rv$db_con, input$editing_tournament_id)

  tournament_id <- as.integer(input$editing_tournament_id)
  store_id <- input$edit_tournament_store
  event_date <- input$edit_tournament_date
  event_type <- input$edit_tournament_type
  format <- input$edit_tournament_format
  player_count <- input$edit_tournament_players
  rounds <- input$edit_tournament_rounds

  # Validation
  if (is.null(store_id) || store_id == "") {
    showNotification("Please select a store", type = "error")
    return()
  }

  if (is.null(event_type) || event_type == "") {
    showNotification("Please select an event type", type = "error")
    return()
  }

  tryCatch({
    dbExecute(rv$db_con, "
      UPDATE tournaments
      SET store_id = $1, event_date = $2, event_type = $3, format = $4,
          player_count = $5, rounds = $6, updated_at = CURRENT_TIMESTAMP
      WHERE tournament_id = $7
    ", params = list(as.integer(store_id), event_date, event_type, format,
                     player_count, rounds, tournament_id))

    showNotification("Tournament updated", type = "message")

    # Reset form
    reset_tournament_form()

    # Trigger table refresh (admin + public tables)
    rv$tournament_refresh <- (rv$tournament_refresh %||% 0) + 1
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Cancel edit tournament
observeEvent(input$cancel_edit_tournament, {
  reset_tournament_form()
})

# Helper function to reset form
reset_tournament_form <- function() {
  updateTextInput(session, "editing_tournament_id", value = "")
  updateSelectInput(session, "edit_tournament_store", selected = "")
  updateDateInput(session, "edit_tournament_date", value = Sys.Date())
  updateSelectInput(session, "edit_tournament_type", selected = "")
  updateNumericInput(session, "edit_tournament_players", value = 8)
  updateNumericInput(session, "edit_tournament_rounds", value = 3)

  shinyjs::hide("update_tournament")
  shinyjs::hide("delete_tournament")
  shinyjs::hide("view_results_btn_container")
}

# Delete button click - show modal
observeEvent(input$delete_tournament, {
  req(rv$is_admin, input$editing_tournament_id)

  tournament_id <- as.integer(input$editing_tournament_id)

  # Get tournament info and results count
  tournament <- dbGetQuery(rv$db_con, "
    SELECT t.*, s.name as store_name,
           (SELECT COUNT(*) FROM results WHERE tournament_id = t.tournament_id) as results_count
    FROM tournaments t
    LEFT JOIN stores s ON t.store_id = s.store_id
    WHERE t.tournament_id = ?
  ", params = list(tournament_id))

  output$delete_tournament_message <- renderUI({
    div(
      p(sprintf("Are you sure you want to delete this tournament?")),
      p(tags$strong(sprintf("%s - %s", tournament$store_name, tournament$event_date))),
      if (tournament$results_count > 0) {
        p(class = "text-danger",
          bsicons::bs_icon("exclamation-triangle-fill"),
          sprintf(" This will also delete %d result(s)!", tournament$results_count))
      },
      p(class = "text-muted small", "This action cannot be undone.")
    )
  })

  shinyjs::runjs("$('#delete_tournament_modal').modal('show');")
})

# Confirm delete tournament
observeEvent(input$confirm_delete_tournament, {
  req(rv$is_admin, rv$db_con, input$editing_tournament_id)

  tournament_id <- as.integer(input$editing_tournament_id)

  tryCatch({
    # Delete results first (cascade)
    dbExecute(rv$db_con, "DELETE FROM results WHERE tournament_id = ?",
              params = list(tournament_id))

    # Delete tournament
    dbExecute(rv$db_con, "DELETE FROM tournaments WHERE tournament_id = ?",
              params = list(tournament_id))

    showNotification("Tournament and results deleted", type = "message")

    # Hide modal and reset form
    shinyjs::runjs("$('#delete_tournament_modal').modal('hide');")
    reset_tournament_form()

    # Trigger table refresh (admin + public tables)
    rv$tournament_refresh <- (rv$tournament_refresh %||% 0) + 1
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# =============================================================================
# Results Modal Handlers
# =============================================================================

# Show View/Edit Results button when tournament is selected
observeEvent(input$admin_tournament_list_clicked, {
  # Button is shown in the existing click handler, add this line there
  shinyjs::show("view_results_btn_container")
}, priority = -1)  # Run after main handler

# Hide button when form is cancelled/reset
observeEvent(input$cancel_edit_tournament, {
  shinyjs::hide("view_results_btn_container")
}, priority = -1)

# Open results modal
observeEvent(input$view_edit_results, {
  req(rv$db_con, input$editing_tournament_id)

  # Store the tournament ID for modal operations
  rv$modal_tournament_id <- as.integer(input$editing_tournament_id)

  # Update dropdowns for add/edit forms
  updateSelectizeInput(session, "modal_new_player",
                       choices = get_player_choices(rv$db_con))
  updateSelectizeInput(session, "modal_new_deck",
                       choices = get_archetype_choices(rv$db_con))
  updateSelectizeInput(session, "modal_edit_player",
                       choices = get_player_choices(rv$db_con))
  updateSelectizeInput(session, "modal_edit_deck",
                       choices = get_archetype_choices(rv$db_con))

  # Reset add form
  shinyjs::hide("modal_add_result_form")

  # Show modal
  shinyjs::runjs("$('#tournament_results_modal').modal('show');")
})

# Results modal summary
output$results_modal_summary <- renderUI({
  req(rv$db_con, rv$modal_tournament_id)

  tournament <- dbGetQuery(rv$db_con, "
    SELECT t.*, s.name as store_name
    FROM tournaments t
    LEFT JOIN stores s ON t.store_id = s.store_id
    WHERE t.tournament_id = ?
  ", params = list(rv$modal_tournament_id))

  if (nrow(tournament) == 0) return(NULL)

  div(
    class = "d-flex flex-wrap gap-3 align-items-center text-muted",
    span(tags$strong(tournament$store_name)),
    span(bsicons::bs_icon("calendar"), " ", as.character(tournament$event_date)),
    span(bsicons::bs_icon("tag"), " ", tournament$format),
    span(bsicons::bs_icon("people"), " ", tournament$player_count, " players")
  )
})

# Results table in modal
output$modal_results_table <- renderReactable({
  req(rv$db_con, rv$modal_tournament_id)

  # Trigger refresh
  rv$modal_results_refresh

  results <- dbGetQuery(rv$db_con, "
    SELECT r.result_id, r.placement, p.display_name as player,
           da.archetype_name as deck, da.primary_color,
           r.wins, r.losses, r.ties, r.decklist_url
    FROM results r
    JOIN players p ON r.player_id = p.player_id
    LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    WHERE r.tournament_id = ?
    ORDER BY r.placement
  ", params = list(rv$modal_tournament_id))

  if (nrow(results) == 0) {
    return(reactable(data.frame(Message = "No results entered yet")))
  }

  # Format record
  results$Record <- paste0(results$wins, "-", results$losses, "-", results$ties)

  display_data <- data.frame(
    result_id = results$result_id,
    `#` = results$placement,
    Player = results$player,
    Deck = results$deck,
    Record = results$Record,
    stringsAsFactors = FALSE
  )

  reactable(
    display_data,
    selection = "single",
    onClick = JS("function(rowInfo, column) {
      if (rowInfo) {
        Shiny.setInputValue('modal_result_clicked', {
          result_id: rowInfo.row.result_id,
          nonce: Math.random()
        }, {priority: 'event'});
      }
    }"),
    highlight = TRUE,
    compact = TRUE,
    pagination = FALSE,
    columns = list(
      result_id = colDef(show = FALSE),
      `#` = colDef(width = 50, align = "center"),
      Player = colDef(minWidth = 120),
      Deck = colDef(minWidth = 120),
      Record = colDef(width = 80, align = "center")
    )
  )
})

# =============================================================================
# Edit/Delete Result Handlers
# =============================================================================

# Click result row to edit
observeEvent(input$modal_result_clicked, {
  req(rv$db_con, rv$modal_tournament_id)

  result_id <- input$modal_result_clicked$result_id

  result <- dbGetQuery(rv$db_con, "
    SELECT r.*
    FROM results r
    WHERE r.result_id = ? AND r.tournament_id = ?
  ", params = list(result_id, rv$modal_tournament_id))

  if (nrow(result) == 0) {
    showNotification("Result not found", type = "error")
    return()
  }

  # Populate edit form
  updateTextInput(session, "modal_editing_result_id", value = as.character(result_id))
  updateSelectizeInput(session, "modal_edit_player", selected = result$player_id)
  updateSelectizeInput(session, "modal_edit_deck", selected = result$archetype_id)
  updateNumericInput(session, "modal_edit_placement", value = result$placement)
  updateNumericInput(session, "modal_edit_wins", value = result$wins)
  updateNumericInput(session, "modal_edit_losses", value = result$losses)
  updateNumericInput(session, "modal_edit_ties", value = result$ties)
  updateTextInput(session, "modal_edit_decklist",
                  value = if (is.na(result$decklist_url)) "" else result$decklist_url)

  # Show edit modal
  shinyjs::runjs("$('#modal_edit_result').modal('show');")
})

# Save edited result
observeEvent(input$modal_save_edit_result, {
  req(rv$db_con, rv$modal_tournament_id, input$modal_editing_result_id)

  result_id <- as.integer(input$modal_editing_result_id)
  player_id <- as.integer(input$modal_edit_player)
  archetype_id <- as.integer(input$modal_edit_deck)
  placement <- input$modal_edit_placement
  wins <- input$modal_edit_wins %||% 0
  losses <- input$modal_edit_losses %||% 0
  ties <- input$modal_edit_ties %||% 0
  decklist_url <- if (!is.null(input$modal_edit_decklist) && nchar(input$modal_edit_decklist) > 0)
    input$modal_edit_decklist else NA_character_

  # Validation
  if (is.na(player_id)) {
    showNotification("Please select a player", type = "error")
    return()
  }
  if (is.na(archetype_id)) {
    showNotification("Please select a deck", type = "error")
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
                     wins, losses, ties, decklist_url,
                     result_id, rv$modal_tournament_id))

    showNotification("Result updated!", type = "message")

    shinyjs::runjs("$('#modal_edit_result').modal('hide');")
    rv$modal_results_refresh <- (rv$modal_results_refresh %||% 0) + 1
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Delete result button (shows confirmation)
observeEvent(input$modal_delete_result, {
  req(input$modal_editing_result_id)
  shinyjs::runjs("$('#modal_delete_result_confirm').modal('show');")
})

# Confirm delete result
observeEvent(input$modal_confirm_delete_result, {
  req(rv$db_con, rv$modal_tournament_id, input$modal_editing_result_id)

  result_id <- as.integer(input$modal_editing_result_id)

  tryCatch({
    dbExecute(rv$db_con, "DELETE FROM results WHERE result_id = ? AND tournament_id = ?",
              params = list(result_id, rv$modal_tournament_id))

    showNotification("Result deleted", type = "message")

    shinyjs::runjs("$('#modal_delete_result_confirm').modal('hide');")
    shinyjs::runjs("$('#modal_edit_result').modal('hide');")
    rv$modal_results_refresh <- (rv$modal_results_refresh %||% 0) + 1
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# =============================================================================
# Add New Result Handlers
# =============================================================================

# Show add result form
observeEvent(input$modal_add_result, {
  # Reset form
  updateSelectizeInput(session, "modal_new_player", selected = "")
  updateSelectizeInput(session, "modal_new_deck", selected = "")
  updateNumericInput(session, "modal_new_placement", value = 1)
  updateNumericInput(session, "modal_new_wins", value = 0)
  updateNumericInput(session, "modal_new_losses", value = 0)
  updateNumericInput(session, "modal_new_ties", value = 0)
  updateTextInput(session, "modal_new_decklist", value = "")

  shinyjs::show("modal_add_result_form")
})

# Cancel add result
observeEvent(input$modal_cancel_new_result, {
  shinyjs::hide("modal_add_result_form")
})

# Save new result
observeEvent(input$modal_save_new_result, {
  req(rv$db_con, rv$modal_tournament_id)

  player_id <- as.integer(input$modal_new_player)
  archetype_id <- as.integer(input$modal_new_deck)
  placement <- input$modal_new_placement
  wins <- input$modal_new_wins %||% 0
  losses <- input$modal_new_losses %||% 0
  ties <- input$modal_new_ties %||% 0
  decklist_url <- if (!is.null(input$modal_new_decklist) && nchar(input$modal_new_decklist) > 0)
    input$modal_new_decklist else NA_character_

  # Validation
  if (is.na(player_id)) {
    showNotification("Please select a player", type = "error")
    return()
  }
  if (is.na(archetype_id)) {
    showNotification("Please select a deck", type = "error")
    return()
  }

  tryCatch({
    dbExecute(rv$db_con, "
      INSERT INTO results (tournament_id, player_id, archetype_id, placement,
                           wins, losses, ties, decklist_url)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ", params = list(rv$modal_tournament_id, player_id, archetype_id, placement,
                     wins, losses, ties, decklist_url))

    showNotification("Result added!", type = "message")

    shinyjs::hide("modal_add_result_form")
    rv$modal_results_refresh <- (rv$modal_results_refresh %||% 0) + 1
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})
