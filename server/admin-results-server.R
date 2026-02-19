# =============================================================================
# Admin: Tournament Entry & Results Server Logic
# =============================================================================

# Grid data for bulk entry
rv$admin_grid_data <- NULL
rv$admin_record_format <- "points"
rv$admin_player_matches <- list()
rv$admin_deck_request_row <- NULL

# Initialize blank grid data frame
init_admin_grid <- function(player_count) {
  data.frame(
    placement = seq_len(player_count),
    player_name = rep("", player_count),
    points = rep(0L, player_count),
    wins = rep(0L, player_count),
    losses = rep(0L, player_count),
    ties = rep(0L, player_count),
    deck_id = rep(NA_integer_, player_count),
    match_status = rep("", player_count),
    matched_player_id = rep(NA_integer_, player_count),
    matched_member_number = rep(NA_character_, player_count),
    stringsAsFactors = FALSE
  )
}

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

    # Hide deck selector for release events (sealed packs, no archetype)
    is_release <- !is.null(input$tournament_type) && input$tournament_type == "release_event"
    if (is_release) {
      shinyjs::hide("deck_selection_section")
      shinyjs::show("release_event_deck_notice")
    } else {
      shinyjs::show("deck_selection_section")
      shinyjs::hide("release_event_deck_notice")
    }
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
    rv$admin_record_format <- input$admin_record_format %||% "points"
    rv$admin_grid_data <- init_admin_grid(player_count)
    rv$admin_player_matches <- list()

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
    # Re-initialize grid with blank rows
    player_count <- dbGetQuery(rv$db_con, "SELECT player_count FROM tournaments WHERE tournament_id = ?",
                               params = list(rv$active_tournament_id))$player_count
    rv$admin_grid_data <- init_admin_grid(player_count)
    rv$admin_player_matches <- list()
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
    rv$admin_grid_data <- NULL
    rv$admin_player_matches <- list()
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
    rv$admin_record_format <- input$admin_record_format %||% "points"
    rv$admin_grid_data <- init_admin_grid(player_count)
    rv$admin_player_matches <- list()

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

# =============================================================================
# Admin Grid: Helper Functions
# =============================================================================

# Ordinal helper (1st, 2nd, 3rd, etc.)
admin_ordinal <- function(n) {
  suffix <- c("th", "st", "nd", "rd", rep("th", 6))
  if (n %% 100 >= 11 && n %% 100 <= 13) {
    return(paste0(n, "th"))
  }
  return(paste0(n, suffix[(n %% 10) + 1]))
}

output$admin_record_format_badge <- renderUI({
  format <- rv$admin_record_format %||% "points"
  label <- if (format == "points") "Points mode" else "W-L-T mode"
  span(class = "badge bg-info", label)
})

output$admin_filled_count <- renderUI({
  req(rv$admin_grid_data)
  grid <- rv$admin_grid_data
  filled <- sum(nchar(trimws(grid$player_name)) > 0)
  total <- nrow(grid)
  span(class = "text-muted small", sprintf("Filled: %d/%d", filled, total))
})

# =============================================================================
# Admin Grid: Table Rendering
# =============================================================================

output$admin_grid_table <- renderUI({
  req(rv$admin_grid_data)

  grid <- rv$admin_grid_data
  record_format <- rv$admin_record_format %||% "points"

  # Check if release event (hide deck column)
  is_release <- FALSE
  if (!is.null(rv$active_tournament_id) && !is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    t_info <- dbGetQuery(rv$db_con, "SELECT event_type FROM tournaments WHERE tournament_id = ?",
                         params = list(rv$active_tournament_id))
    if (nrow(t_info) > 0) is_release <- t_info$event_type[1] == "release_event"
  }

  # Build deck choices
  decks <- dbGetQuery(rv$db_con, "
    SELECT archetype_id, archetype_name FROM deck_archetypes
    WHERE is_active = TRUE ORDER BY archetype_name
  ")

  pending_requests <- dbGetQuery(rv$db_con, "
    SELECT request_id, deck_name FROM deck_requests
    WHERE status = 'pending' ORDER BY deck_name
  ")

  deck_choices <- c("Unknown" = "")
  deck_choices <- c(deck_choices, "\U2795 Request new deck..." = "__REQUEST_NEW__")
  if (nrow(pending_requests) > 0) {
    pending_choices <- setNames(
      paste0("pending_", pending_requests$request_id),
      paste0("Pending: ", pending_requests$deck_name)
    )
    deck_choices <- c(deck_choices, pending_choices)
  }
  deck_choices <- c(deck_choices, setNames(decks$archetype_id, decks$archetype_name))

  # Column widths depend on format and release event
  if (is_release) {
    if (record_format == "points") {
      col_widths <- c(1, 1, 8, 2)
    } else {
      col_widths <- c(1, 1, 6, 2, 1, 1)
    }
  } else {
    if (record_format == "points") {
      col_widths <- c(1, 1, 4, 2, 4)
    } else {
      col_widths <- c(1, 1, 3, 1, 1, 1, 4)
    }
  }

  # Header row
  if (is_release) {
    if (record_format == "points") {
      header <- layout_columns(col_widths = col_widths, class = "results-header-row",
                               div(""), div("#"), div("Player"), div("Pts"))
    } else {
      header <- layout_columns(col_widths = col_widths, class = "results-header-row",
                               div(""), div("#"), div("Player"), div("W"), div("L"), div("T"))
    }
  } else {
    if (record_format == "points") {
      header <- layout_columns(col_widths = col_widths, class = "results-header-row",
                               div(""), div("#"), div("Player"), div("Pts"), div("Deck"))
    } else {
      header <- layout_columns(col_widths = col_widths, class = "results-header-row",
                               div(""), div("#"), div("Player"), div("W"), div("L"), div("T"), div("Deck"))
    }
  }

  # Release event info notice
  release_notice <- if (is_release) {
    div(class = "alert alert-info py-2 px-3 mb-3",
        bsicons::bs_icon("info-circle"),
        " Release event \u2014 deck archetype auto-set to UNKNOWN.")
  } else NULL

  # Data rows
  rows <- lapply(seq_len(nrow(grid)), function(i) {
    row <- grid[i, ]
    place_class <- if (i == 1) "place-1st" else if (i == 2) "place-2nd" else if (i == 3) "place-3rd" else ""

    # Player match badge
    match_badge <- if (!is.null(rv$admin_player_matches[[as.character(i)]])) {
      m <- rv$admin_player_matches[[as.character(i)]]
      if (m$status == "matched") {
        member_text <- if (!is.na(m$member_number) && nchar(m$member_number) > 0) {
          paste0("#", m$member_number)
        } else {
          "(no member #)"
        }
        div(class = "player-match-indicator matched",
            bsicons::bs_icon("check-circle-fill"),
            span(class = "match-label", paste0("Matched ", member_text)))
      } else if (m$status == "new") {
        div(class = "player-match-indicator new",
            bsicons::bs_icon("person-plus-fill"),
            span(class = "match-label", "New player"))
      } else NULL
    } else NULL

    # Delete button
    delete_btn <- div(
      class = "upload-result-delete",
      htmltools::tags$button(
        onclick = sprintf("Shiny.setInputValue('admin_delete_row', %d, {priority: 'event'})", i),
        class = "btn btn-sm btn-outline-danger p-0 result-action-btn",
        title = "Remove row",
        shiny::icon("xmark")
      )
    )

    # Placement column
    placement_col <- div(
      class = "upload-result-placement",
      span(class = paste("placement-badge", place_class), admin_ordinal(row$placement)),
      match_badge
    )

    # Player name input
    player_col <- div(
      textInput(paste0("admin_player_", i), NULL, value = row$player_name)
    )

    # Build row based on format and release event
    if (is_release) {
      if (record_format == "points") {
        pts_col <- div(numericInput(paste0("admin_pts_", i), NULL, value = row$points, min = 0, max = 99))
        layout_columns(col_widths = col_widths, class = "upload-result-row",
                       delete_btn, placement_col, player_col, pts_col)
      } else {
        w_col <- div(numericInput(paste0("admin_w_", i), NULL, value = row$wins, min = 0))
        l_col <- div(numericInput(paste0("admin_l_", i), NULL, value = row$losses, min = 0))
        t_col <- div(numericInput(paste0("admin_t_", i), NULL, value = row$ties, min = 0))
        layout_columns(col_widths = col_widths, class = "upload-result-row",
                       delete_btn, placement_col, player_col, w_col, l_col, t_col)
      }
    } else {
      current_deck <- if (!is.na(row$deck_id)) as.character(row$deck_id) else ""
      deck_col <- div(
        selectInput(paste0("admin_deck_", i), NULL,
                    choices = deck_choices, selected = current_deck,
                    selectize = FALSE)
      )

      if (record_format == "points") {
        pts_col <- div(numericInput(paste0("admin_pts_", i), NULL, value = row$points, min = 0, max = 99))
        layout_columns(col_widths = col_widths, class = "upload-result-row",
                       delete_btn, placement_col, player_col, pts_col, deck_col)
      } else {
        w_col <- div(numericInput(paste0("admin_w_", i), NULL, value = row$wins, min = 0))
        l_col <- div(numericInput(paste0("admin_l_", i), NULL, value = row$losses, min = 0))
        t_col <- div(numericInput(paste0("admin_t_", i), NULL, value = row$ties, min = 0))
        layout_columns(col_widths = col_widths, class = "upload-result-row",
                       delete_btn, placement_col, player_col, w_col, l_col, t_col, deck_col)
      }
    }
  })

  tagList(release_notice, header, rows)
})

# =============================================================================
# Admin Grid: Input Sync & Row Management
# =============================================================================

# Sync current grid input values back to reactive data frame
sync_admin_grid_inputs <- function() {
  grid <- rv$admin_grid_data
  if (is.null(grid) || nrow(grid) == 0) return()
  record_format <- rv$admin_record_format %||% "points"

  for (i in seq_len(nrow(grid))) {
    player_val <- input[[paste0("admin_player_", i)]]
    if (!is.null(player_val)) grid$player_name[i] <- player_val

    if (record_format == "points") {
      pts_val <- input[[paste0("admin_pts_", i)]]
      if (!is.null(pts_val) && !is.na(pts_val)) grid$points[i] <- as.integer(pts_val)
    } else {
      w_val <- input[[paste0("admin_w_", i)]]
      if (!is.null(w_val) && !is.na(w_val)) grid$wins[i] <- as.integer(w_val)
      l_val <- input[[paste0("admin_l_", i)]]
      if (!is.null(l_val) && !is.na(l_val)) grid$losses[i] <- as.integer(l_val)
      t_val <- input[[paste0("admin_t_", i)]]
      if (!is.null(t_val) && !is.na(t_val)) grid$ties[i] <- as.integer(t_val)
    }

    deck_val <- input[[paste0("admin_deck_", i)]]
    if (!is.null(deck_val) && nchar(deck_val) > 0 && deck_val != "__REQUEST_NEW__" && !grepl("^pending_", deck_val)) {
      grid$deck_id[i] <- as.integer(deck_val)
    }
  }
  rv$admin_grid_data <- grid
}

observeEvent(input$admin_delete_row, {
  req(rv$admin_grid_data)
  row_idx <- as.integer(input$admin_delete_row)
  if (is.null(row_idx) || row_idx < 1 || row_idx > nrow(rv$admin_grid_data)) return()

  sync_admin_grid_inputs()
  grid <- rv$admin_grid_data

  # Remove the row
  grid <- grid[-row_idx, ]

  # Append blank row to maintain count
  blank_row <- data.frame(
    placement = nrow(grid) + 1,
    player_name = "",
    points = 0L, wins = 0L, losses = 0L, ties = 0L,
    deck_id = NA_integer_,
    match_status = "",
    matched_player_id = NA_integer_,
    matched_member_number = NA_character_,
    stringsAsFactors = FALSE
  )
  grid <- rbind(grid, blank_row)

  # Renumber placements
  grid$placement <- seq_len(nrow(grid))

  # Update match list (shift indices)
  new_matches <- list()
  for (j in seq_len(nrow(grid))) {
    old_idx <- if (j < row_idx) j else j + 1
    if (!is.null(rv$admin_player_matches[[as.character(old_idx)]])) {
      new_matches[[as.character(j)]] <- rv$admin_player_matches[[as.character(old_idx)]]
    }
  }
  rv$admin_player_matches <- new_matches
  rv$admin_grid_data <- grid
  showNotification(paste0("Row removed. Players renumbered 1-", nrow(grid), "."), type = "message", duration = 3)
})

# =============================================================================
# Admin Grid: Player Matching
# =============================================================================

# Attach blur handlers via delegated event (runs when wizard step 2 shows)
observe({
  req(rv$wizard_step == 2)
  shinyjs::runjs("
    $(document).off('blur.adminGrid').on('blur.adminGrid', 'input[id^=\"admin_player_\"]', function() {
      var id = $(this).attr('id');
      var rowNum = parseInt(id.replace('admin_player_', ''));
      if (!isNaN(rowNum)) {
        Shiny.setInputValue('admin_player_blur', {row: rowNum, name: $(this).val(), ts: Date.now()}, {priority: 'event'});
      }
    });
  ")
})

observeEvent(input$admin_player_blur, {
  req(rv$db_con, rv$admin_grid_data)

  info <- input$admin_player_blur
  row_num <- info$row
  name <- trimws(info$name)

  if (is.null(row_num) || is.na(row_num)) return()
  if (row_num < 1 || row_num > nrow(rv$admin_grid_data)) return()

  # Sync all inputs before modifying reactive (re-render preserves all typed values)
  sync_admin_grid_inputs()

  if (nchar(name) == 0) {
    rv$admin_player_matches[[as.character(row_num)]] <- NULL
    rv$admin_grid_data$match_status[row_num] <- ""
    rv$admin_grid_data$matched_player_id[row_num] <- NA_integer_
    rv$admin_grid_data$matched_member_number[row_num] <- NA_character_
    return()
  }

  # Exact match (case-insensitive)
  player <- dbGetQuery(rv$db_con, "
    SELECT player_id, display_name, member_number
    FROM players WHERE LOWER(display_name) = LOWER(?)
    LIMIT 1
  ", params = list(name))

  if (nrow(player) > 0) {
    rv$admin_player_matches[[as.character(row_num)]] <- list(
      status = "matched",
      player_id = player$player_id,
      member_number = player$member_number
    )
    rv$admin_grid_data$match_status[row_num] <- "matched"
    rv$admin_grid_data$matched_player_id[row_num] <- player$player_id
    rv$admin_grid_data$matched_member_number[row_num] <- player$member_number
  } else {
    rv$admin_player_matches[[as.character(row_num)]] <- list(status = "new")
    rv$admin_grid_data$match_status[row_num] <- "new"
    rv$admin_grid_data$matched_player_id[row_num] <- NA_integer_
    rv$admin_grid_data$matched_member_number[row_num] <- NA_character_
  }
})

# =============================================================================
# Admin Grid: Paste from Spreadsheet
# =============================================================================

observeEvent(input$admin_paste_btn, {
  shinyjs::runjs("$('#paste_spreadsheet_modal').modal('show');")
})

observeEvent(input$paste_apply, {
  req(rv$admin_grid_data)

  paste_text <- input$paste_data
  if (is.null(paste_text) || nchar(trimws(paste_text)) == 0) {
    showNotification("No data to paste", type = "warning")
    return()
  }

  lines <- strsplit(paste_text, "\n")[[1]]
  lines <- lines[nchar(trimws(lines)) > 0]

  if (length(lines) == 0) {
    showNotification("No valid lines found", type = "warning")
    return()
  }

  sync_admin_grid_inputs()
  grid <- rv$admin_grid_data

  # Look up all deck archetypes for name matching
  all_decks <- dbGetQuery(rv$db_con, "
    SELECT archetype_id, archetype_name FROM deck_archetypes
    WHERE is_active = TRUE
  ")

  # Parse each line
  parsed <- lapply(lines, function(line) {
    parts <- strsplit(line, "\t")[[1]]
    if (length(parts) == 1) {
      parts <- strsplit(trimws(line), "\\s{2,}")[[1]]
    }
    parts <- trimws(parts)

    name <- parts[1]
    pts <- 0L; w <- 0L; l <- 0L; t_val <- 0L; deck_name <- ""

    if (length(parts) == 2) {
      # Name + Points
      pts <- suppressWarnings(as.integer(parts[2]))
      if (is.na(pts)) pts <- 0L
    } else if (length(parts) == 3) {
      # Name + Points + Deck
      pts <- suppressWarnings(as.integer(parts[2]))
      if (is.na(pts)) pts <- 0L
      deck_name <- parts[3]
    } else if (length(parts) == 4) {
      # Name + W + L + T
      w <- suppressWarnings(as.integer(parts[2]))
      l <- suppressWarnings(as.integer(parts[3]))
      t_val <- suppressWarnings(as.integer(parts[4]))
      if (is.na(w)) w <- 0L
      if (is.na(l)) l <- 0L
      if (is.na(t_val)) t_val <- 0L
      pts <- w * 3L + t_val
    } else if (length(parts) >= 5) {
      # Name + W + L + T + Deck
      w <- suppressWarnings(as.integer(parts[2]))
      l <- suppressWarnings(as.integer(parts[3]))
      t_val <- suppressWarnings(as.integer(parts[4]))
      if (is.na(w)) w <- 0L
      if (is.na(l)) l <- 0L
      if (is.na(t_val)) t_val <- 0L
      pts <- w * 3L + t_val
      deck_name <- parts[5]
    }

    # Match deck name to archetype
    deck_id <- NA_integer_
    if (nchar(deck_name) > 0) {
      match_idx <- which(tolower(all_decks$archetype_name) == tolower(deck_name))
      if (length(match_idx) > 0) {
        deck_id <- all_decks$archetype_id[match_idx[1]]
      }
    }

    list(name = name, points = pts, wins = w, losses = l, ties = t_val, deck_id = deck_id)
  })

  fill_count <- 0L
  for (idx in seq_along(parsed)) {
    if (idx > nrow(grid)) break
    p <- parsed[[idx]]
    grid$player_name[idx] <- p$name
    grid$points[idx] <- p$points
    grid$wins[idx] <- p$wins
    grid$losses[idx] <- p$losses
    grid$ties[idx] <- p$ties
    if (!is.na(p$deck_id)) grid$deck_id[idx] <- p$deck_id
    fill_count <- fill_count + 1L
  }

  # Close modal and clear textarea
  shinyjs::runjs("$('#paste_spreadsheet_modal').modal('hide');")
  shinyjs::runjs("$('#paste_data').val('');")
  showNotification(sprintf("Filled %d rows from pasted data", fill_count), type = "message")

  # Trigger player match lookup for all filled rows
  for (idx in seq_len(fill_count)) {
    name <- trimws(grid$player_name[idx])
    if (nchar(name) == 0) next

    player <- dbGetQuery(rv$db_con, "
      SELECT player_id, display_name, member_number
      FROM players WHERE LOWER(display_name) = LOWER(?)
      LIMIT 1
    ", params = list(name))

    if (nrow(player) > 0) {
      rv$admin_player_matches[[as.character(idx)]] <- list(
        status = "matched", player_id = player$player_id,
        member_number = player$member_number
      )
      grid$match_status[idx] <- "matched"
      grid$matched_player_id[idx] <- player$player_id
      grid$matched_member_number[idx] <- player$member_number
    } else {
      rv$admin_player_matches[[as.character(idx)]] <- list(status = "new")
      grid$match_status[idx] <- "new"
      grid$matched_player_id[idx] <- NA_integer_
      grid$matched_member_number[idx] <- NA_character_
    }
  }
  rv$admin_grid_data <- grid
})

# =============================================================================
# Admin Grid: Deck Request
# =============================================================================

observe({
  req(rv$admin_grid_data)
  grid <- rv$admin_grid_data

  lapply(seq_len(nrow(grid)), function(i) {
    observeEvent(input[[paste0("admin_deck_", i)]], {
      if (!is.null(input[[paste0("admin_deck_", i)]]) &&
          input[[paste0("admin_deck_", i)]] == "__REQUEST_NEW__") {
        rv$admin_deck_request_row <- i
        showModal(modalDialog(
          title = tagList(bsicons::bs_icon("collection-fill"), " Request New Deck"),
          textInput("admin_deck_request_name", "Deck Name", placeholder = "e.g., Blue Flare"),
          layout_columns(
            col_widths = c(6, 6),
            selectInput("admin_deck_request_color", "Primary Color",
                        choices = c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
            selectInput("admin_deck_request_color2", "Secondary Color (optional)",
                        choices = c("None" = "", "Red", "Blue", "Yellow", "Green", "Purple", "Black", "White"))
          ),
          textInput("admin_deck_request_card_id", "Card ID (optional)",
                    placeholder = "e.g., BT1-001"),
          footer = tagList(
            modalButton("Cancel"),
            actionButton("admin_deck_request_submit", "Submit Request", class = "btn-primary")
          )
        ))
      }
    }, ignoreInit = TRUE)
  })
})

observeEvent(input$admin_deck_request_submit, {
  req(rv$db_con)

  deck_name <- trimws(input$admin_deck_request_name)
  if (nchar(deck_name) == 0) {
    showNotification("Please enter a deck name", type = "error")
    return()
  }

  primary_color <- input$admin_deck_request_color
  secondary_color <- if (!is.null(input$admin_deck_request_color2) && input$admin_deck_request_color2 != "") {
    input$admin_deck_request_color2
  } else NA_character_

  card_id <- if (!is.null(input$admin_deck_request_card_id) && trimws(input$admin_deck_request_card_id) != "") {
    trimws(input$admin_deck_request_card_id)
  } else NA_character_

  # Check for existing pending request
  existing <- dbGetQuery(rv$db_con, "
    SELECT request_id FROM deck_requests
    WHERE LOWER(deck_name) = LOWER(?) AND status = 'pending'
  ", params = list(deck_name))

  if (nrow(existing) > 0) {
    showNotification(sprintf("A pending request for '%s' already exists", deck_name), type = "warning")
  } else {
    max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(request_id), 0) as max_id FROM deck_requests")$max_id
    new_id <- max_id + 1

    dbExecute(rv$db_con, "
      INSERT INTO deck_requests (request_id, deck_name, primary_color, secondary_color, display_card_id, status)
      VALUES (?, ?, ?, ?, ?, 'pending')
    ", params = list(new_id, deck_name, primary_color, secondary_color, card_id))

    showNotification(sprintf("Deck request submitted: %s", deck_name), type = "message")
  }

  removeModal()

  # Force grid re-render to update deck dropdowns
  sync_admin_grid_inputs()
  rv$admin_grid_data <- rv$admin_grid_data
})

# =============================================================================
# Admin Grid: Submit Results
# =============================================================================

observeEvent(input$admin_submit_results, {
  req(rv$is_admin, rv$db_con, rv$active_tournament_id)

  sync_admin_grid_inputs()
  grid <- rv$admin_grid_data
  record_format <- rv$admin_record_format %||% "points"

  # Get tournament info
  tournament <- dbGetQuery(rv$db_con, "
    SELECT tournament_id, event_type, rounds FROM tournaments WHERE tournament_id = ?
  ", params = list(rv$active_tournament_id))

  if (nrow(tournament) == 0) {
    showNotification("Tournament not found", type = "error")
    return()
  }

  rounds <- tournament$rounds
  is_release <- tournament$event_type == "release_event"

  # Filter to rows with player names
  filled_rows <- grid[nchar(trimws(grid$player_name)) > 0, ]

  if (nrow(filled_rows) == 0) {
    showNotification("No results to submit. Enter at least one player name.", type = "warning")
    return()
  }

  # Get UNKNOWN archetype ID for release events or fallback
  unknown_row <- dbGetQuery(rv$db_con, "SELECT archetype_id FROM deck_archetypes WHERE archetype_name = 'UNKNOWN' LIMIT 1")
  unknown_id <- if (nrow(unknown_row) > 0) unknown_row$archetype_id[1] else NA_integer_

  if (is_release && is.na(unknown_id)) {
    showNotification("UNKNOWN archetype not found in database", type = "error")
    return()
  }

  tryCatch({
    result_count <- 0L
    max_result_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(result_id), 0) as max_id FROM results")$max_id

    for (idx in seq_len(nrow(filled_rows))) {
      row <- filled_rows[idx, ]
      name <- trimws(row$player_name)

      # 1. Resolve player
      player <- dbGetQuery(rv$db_con, "
        SELECT player_id FROM players WHERE LOWER(display_name) = LOWER(?) LIMIT 1
      ", params = list(name))

      if (nrow(player) > 0) {
        player_id <- player$player_id
      } else {
        max_pid <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(player_id), 0) as max_id FROM players")$max_id
        player_id <- max_pid + 1
        dbExecute(rv$db_con, "INSERT INTO players (player_id, display_name) VALUES (?, ?)",
                  params = list(player_id, name))
      }

      # 2. Convert record
      if (record_format == "points") {
        pts <- row$points
        wins <- pts %/% 3L
        ties <- pts %% 3L
        losses <- max(0L, rounds - wins - ties)
      } else {
        wins <- row$wins
        losses <- row$losses
        ties <- row$ties
      }

      # 3. Resolve deck
      pending_deck_request_id <- NA_integer_
      if (is_release) {
        archetype_id <- unknown_id
      } else {
        deck_input <- input[[paste0("admin_deck_", row$placement)]]

        if (is.null(deck_input) || nchar(deck_input) == 0 || deck_input == "__REQUEST_NEW__") {
          archetype_id <- unknown_id
        } else if (grepl("^pending_", deck_input)) {
          pending_deck_request_id <- as.integer(sub("^pending_", "", deck_input))
          archetype_id <- unknown_id
        } else {
          archetype_id <- as.integer(deck_input)
        }
      }

      # 4. Insert result
      max_result_id <- max_result_id + 1
      dbExecute(rv$db_con, "
        INSERT INTO results (result_id, tournament_id, player_id, archetype_id, pending_deck_request_id,
                             placement, wins, losses, ties)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", params = list(max_result_id, rv$active_tournament_id, player_id, archetype_id,
                       pending_deck_request_id, row$placement, wins, losses, ties))

      result_count <- result_count + 1L
    }

    # Recalculate ratings
    recalculate_ratings_cache(rv$db_con)
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

    showNotification(sprintf("Tournament submitted! %d results recorded.", result_count),
                     type = "message", duration = 5)

    # Reset to Step 1
    rv$active_tournament_id <- NULL
    rv$wizard_step <- 1
    rv$current_results <- data.frame()
    rv$admin_grid_data <- NULL
    rv$admin_player_matches <- list()

  }, error = function(e) {
    showNotification(paste("Error submitting results:", e$message), type = "error")
  })
})
