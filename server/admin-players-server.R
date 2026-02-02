# =============================================================================
# Admin: Player Management Server Logic
# =============================================================================

# Player list
output$player_list <- renderReactable({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  # Refresh triggers
  input$update_player
  input$confirm_delete_player
  input$confirm_merge_players

  search_term <- input$player_search %||% ""

  query <- "
    SELECT p.player_id,
           p.display_name as 'Player Name',
           COUNT(r.result_id) as 'Results',
           SUM(CASE WHEN r.placement = 1 THEN 1 ELSE 0 END) as 'Wins',
           MAX(t.event_date) as 'Last Event'
    FROM players p
    LEFT JOIN results r ON p.player_id = r.player_id
    LEFT JOIN tournaments t ON r.tournament_id = t.tournament_id
  "

  if (nchar(search_term) > 0) {
    query <- paste0(query, " WHERE LOWER(p.display_name) LIKE LOWER('%", search_term, "%')")
  }

  query <- paste0(query, "
    GROUP BY p.player_id, p.display_name
    ORDER BY p.display_name
  ")

  data <- dbGetQuery(rv$db_con, query)

  if (nrow(data) == 0) {
    return(reactable(data.frame(Message = "No players found"), compact = TRUE))
  }

  reactable(data, compact = TRUE, striped = TRUE,
    selection = "single",
    onClick = "select",
    rowStyle = list(cursor = "pointer"),
    defaultPageSize = 20,
    showPageSizeOptions = TRUE,
    pageSizeOptions = c(10, 20, 50, 100),
    columns = list(
      player_id = colDef(show = FALSE),
      `Player Name` = colDef(minWidth = 150),
      Results = colDef(width = 80),
      Wins = colDef(width = 60),
      `Last Event` = colDef(width = 100)
    )
  )
})

# Handle player selection for editing
observeEvent(input$player_list__reactable__selected, {
  req(rv$db_con)
  selected_idx <- input$player_list__reactable__selected

  if (is.null(selected_idx) || length(selected_idx) == 0) {
    return()
  }

  # Get player data with search filter applied
  search_term <- input$player_search %||% ""
  query <- "
    SELECT p.player_id, p.display_name
    FROM players p
  "
  if (nchar(search_term) > 0) {
    query <- paste0(query, " WHERE LOWER(p.display_name) LIKE LOWER('%", search_term, "%')")
  }
  query <- paste0(query, " ORDER BY p.display_name")

  data <- dbGetQuery(rv$db_con, query)

  if (selected_idx > nrow(data)) return()

  player <- data[selected_idx, ]

  # Populate form for editing

  updateTextInput(session, "editing_player_id", value = as.character(player$player_id))
  updateTextInput(session, "player_display_name", value = player$display_name)

  # Show buttons
  shinyjs::show("update_player")
  shinyjs::show("delete_player")

  showNotification(sprintf("Editing: %s", player$display_name), type = "message", duration = 2)
})

# Player stats info
output$player_stats_info <- renderUI({
  if (is.null(input$editing_player_id) || input$editing_player_id == "") {
    return(div(class = "text-muted", "Select a player to view their stats."))
  }

  player_id <- as.integer(input$editing_player_id)

  stats <- dbGetQuery(rv$db_con, "
    SELECT
      COUNT(DISTINCT r.tournament_id) as tournaments,
      COUNT(r.result_id) as total_results,
      SUM(CASE WHEN r.placement = 1 THEN 1 ELSE 0 END) as wins,
      SUM(r.wins) as match_wins,
      SUM(r.losses) as match_losses
    FROM results r
    WHERE r.player_id = ?
  ", params = list(player_id))

  if (stats$total_results == 0) {
    return(div(
      class = "alert alert-info",
      bsicons::bs_icon("info-circle"), " This player has no tournament results.",
      div(class = "small mt-2", "Players with no results can be safely deleted.")
    ))
  }

  div(
    class = "digital-stat-box p-3",
    div(class = "d-flex justify-content-around text-center",
        div(
          div(class = "stat-value", stats$tournaments),
          div(class = "stat-label small text-muted", "Events")
        ),
        div(
          div(class = "stat-value", stats$wins),
          div(class = "stat-label small text-muted", "1st Places")
        ),
        div(
          div(class = "stat-value", paste0(stats$match_wins, "-", stats$match_losses)),
          div(class = "stat-label small text-muted", "Match Record")
        )
    )
  )
})

# Cancel edit
observeEvent(input$cancel_edit_player, {
  updateTextInput(session, "editing_player_id", value = "")
  updateTextInput(session, "player_display_name", value = "")

  shinyjs::hide("update_player")
  shinyjs::hide("delete_player")
})

# Update player
observeEvent(input$update_player, {
  req(rv$is_admin, rv$db_con, input$editing_player_id)

  player_id <- as.integer(input$editing_player_id)
  new_name <- trimws(input$player_display_name)

  if (nchar(new_name) == 0) {
    showNotification("Please enter a player name", type = "error")
    return()
  }

  if (nchar(new_name) < 2) {
    showNotification("Player name must be at least 2 characters", type = "error")
    return()
  }

  # Check for duplicate name (excluding current player)
  existing <- dbGetQuery(rv$db_con, "
    SELECT player_id FROM players
    WHERE LOWER(display_name) = LOWER(?) AND player_id != ?
  ", params = list(new_name, player_id))

  if (nrow(existing) > 0) {
    showNotification(sprintf("A player named '%s' already exists", new_name), type = "error")
    return()
  }

  tryCatch({
    dbExecute(rv$db_con, "
      UPDATE players
      SET display_name = ?, updated_at = CURRENT_TIMESTAMP
      WHERE player_id = ?
    ", params = list(new_name, player_id))

    showNotification(sprintf("Updated player: %s", new_name), type = "message")

    # Clear form and reset
    updateTextInput(session, "editing_player_id", value = "")
    updateTextInput(session, "player_display_name", value = "")

    shinyjs::hide("update_player")
    shinyjs::hide("delete_player")

    # Update player dropdown in results entry
    updateSelectizeInput(session, "result_player", choices = get_player_choices(rv$db_con))

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Check if player can be deleted (no results)
observe({
  req(input$editing_player_id, rv$db_con)
  player_id <- as.integer(input$editing_player_id)

  count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM results WHERE player_id = ?
  ", params = list(player_id))$cnt

  rv$player_result_count <- count
  rv$can_delete_player <- count == 0
})

# Delete button click - show modal
observeEvent(input$delete_player, {
  req(rv$is_admin, input$editing_player_id)

  player_id <- as.integer(input$editing_player_id)
  player <- dbGetQuery(rv$db_con, "SELECT display_name FROM players WHERE player_id = ?",
                       params = list(player_id))

  if (rv$can_delete_player) {
    output$delete_player_message <- renderUI({
      div(
        p(sprintf("Are you sure you want to delete '%s'?", player$display_name)),
        p(class = "text-danger", "This action cannot be undone.")
      )
    })
    shinyjs::runjs("$('#delete_player_modal').modal('show');")
  } else {
    showNotification(
      sprintf("Cannot delete: player has %d result(s). Use 'Merge Players' to combine with another player.",
              rv$player_result_count),
      type = "error",
      duration = 5
    )
  }
})

# Confirm delete
observeEvent(input$confirm_delete_player, {
  req(rv$is_admin, rv$db_con, input$editing_player_id)
  player_id <- as.integer(input$editing_player_id)

  # Re-check for referential integrity
  count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM results WHERE player_id = ?
  ", params = list(player_id))$cnt

  if (count > 0) {
    shinyjs::runjs("$('#delete_player_modal').modal('hide');")
    showNotification(sprintf("Cannot delete: player has %d result(s)", count), type = "error")
    return()
  }

  tryCatch({
    dbExecute(rv$db_con, "DELETE FROM players WHERE player_id = ?",
              params = list(player_id))
    showNotification("Player deleted", type = "message")

    shinyjs::runjs("$('#delete_player_modal').modal('hide');")

    # Clear form
    updateTextInput(session, "editing_player_id", value = "")
    updateTextInput(session, "player_display_name", value = "")

    shinyjs::hide("update_player")
    shinyjs::hide("delete_player")

    # Update player dropdown
    updateSelectizeInput(session, "result_player", choices = get_player_choices(rv$db_con))

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# ---------------------------------------------------------------------------
# Merge Players Feature
# ---------------------------------------------------------------------------

# Show merge modal
observeEvent(input$show_merge_modal, {
  shinyjs::runjs("$('#merge_player_modal').modal('show');")
})

# Update merge dropdowns when they're shown
observe({
  req(rv$db_con, rv$is_admin)
  choices <- get_player_choices(rv$db_con)
  updateSelectizeInput(session, "merge_source_player", choices = choices)
  updateSelectizeInput(session, "merge_target_player", choices = choices)
})

# Merge preview
output$merge_preview <- renderUI({
  source_id <- input$merge_source_player
  target_id <- input$merge_target_player

  if (is.null(source_id) || source_id == "" || is.null(target_id) || target_id == "") {
    return(NULL)
  }

  if (source_id == target_id) {
    return(div(class = "alert alert-danger", "Source and target players cannot be the same."))
  }

  source_count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM results WHERE player_id = ?
  ", params = list(as.integer(source_id)))$cnt

  div(
    class = "alert alert-warning",
    bsicons::bs_icon("exclamation-triangle"),
    sprintf(" %d result(s) will be moved to the target player.", source_count)
  )
})

# Confirm merge
observeEvent(input$confirm_merge_players, {
  req(rv$is_admin, rv$db_con)

  source_id <- as.integer(input$merge_source_player)
  target_id <- as.integer(input$merge_target_player)

  if (is.na(source_id) || is.na(target_id)) {
    showNotification("Please select both source and target players", type = "error")
    return()
  }

  if (source_id == target_id) {
    showNotification("Source and target players cannot be the same", type = "error")
    return()
  }

  tryCatch({
    # Move all results from source to target
    dbExecute(rv$db_con, "
      UPDATE results SET player_id = ? WHERE player_id = ?
    ", params = list(target_id, source_id))

    # Delete source player
    dbExecute(rv$db_con, "DELETE FROM players WHERE player_id = ?",
              params = list(source_id))

    showNotification("Players merged successfully", type = "message")

    shinyjs::runjs("$('#merge_player_modal').modal('hide');")

    # Reset dropdowns
    updateSelectizeInput(session, "merge_source_player", selected = "")
    updateSelectizeInput(session, "merge_target_player", selected = "")

    # Update player dropdown
    updateSelectizeInput(session, "result_player", choices = get_player_choices(rv$db_con))

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})
