# server/public-submit-server.R
# Public Submit Results server logic

# Load OCR module
source("R/ocr.R")

# Initialize submit-related reactive values
rv$submit_ocr_results <- NULL
rv$submit_uploaded_files <- NULL

# Populate store dropdown
observe({
  req(rv$db_con)
  stores <- dbGetQuery(rv$db_con, "
    SELECT store_id, name FROM stores
    WHERE is_active = TRUE
    ORDER BY name
  ")
  choices <- setNames(stores$store_id, stores$name)
  updateSelectInput(session, "submit_store",
                    choices = c("Select store..." = "", choices))
})

# Populate format dropdown
observe({
  req(rv$db_con)
  formats <- dbGetQuery(rv$db_con, "
    SELECT format_id, display_name FROM formats
    WHERE is_active = TRUE
    ORDER BY sort_order ASC, format_id DESC
  ")
  choices <- setNames(formats$format_id, formats$display_name)
  updateSelectInput(session, "submit_format",
                    choices = c("Select format..." = "", choices))
})

# Preview uploaded screenshots
output$submit_screenshot_preview <- renderUI({
  req(input$submit_screenshots)

  files <- input$submit_screenshots

  if (is.null(files) || nrow(files) == 0) return(NULL)

  # Store file info for later
  rv$submit_uploaded_files <- files

  tagList(
    h6(class = "mt-3", paste(nrow(files), "screenshot(s) uploaded:")),
    div(
      class = "d-flex flex-wrap gap-2",
      lapply(seq_len(nrow(files)), function(i) {
        div(
          class = "border rounded p-2 d-flex align-items-center gap-2",
          bsicons::bs_icon("image"),
          span(files$name[i]),
          tags$small(class = "text-muted",
                     paste0("(", round(files$size[i] / 1024), " KB)"))
        )
      })
    )
  )
})

# Process OCR when button clicked
observeEvent(input$submit_process_ocr, {
  req(rv$submit_uploaded_files)

  files <- rv$submit_uploaded_files
  total_rounds <- input$submit_rounds

  # Show processing indicator
  showNotification("Processing screenshots with OCR...", type = "message", duration = NULL, id = "ocr_processing")

  all_results <- list()
  ocr_errors <- c()
  ocr_texts <- c()

  for (i in seq_len(nrow(files))) {
    file_path <- files$datapath[i]
    file_name <- files$name[i]

    message("[SUBMIT] Processing file ", i, ": ", file_name)
    message("[SUBMIT] File path: ", file_path)
    message("[SUBMIT] File exists: ", file.exists(file_path))

    # Call OCR
    ocr_text <- tryCatch({
      gcv_detect_text(file_path, verbose = TRUE)
    }, error = function(e) {
      ocr_errors <<- c(ocr_errors, paste(file_name, ":", e$message))
      message("[SUBMIT] OCR error for ", file_name, ": ", e$message)
      NULL
    })

    if (!is.null(ocr_text) && ocr_text != "") {
      ocr_texts <- c(ocr_texts, paste0("File ", i, ": ", nchar(ocr_text), " chars"))

      # Parse results
      parsed <- tryCatch({
        parse_tournament_standings(ocr_text, total_rounds, verbose = TRUE)
      }, error = function(e) {
        ocr_errors <<- c(ocr_errors, paste("Parse error:", e$message))
        message("[SUBMIT] Parse error: ", e$message)
        data.frame()
      })

      if (nrow(parsed) > 0) {
        all_results[[length(all_results) + 1]] <- parsed
        message("[SUBMIT] Parsed ", nrow(parsed), " results from ", file_name)
      } else {
        message("[SUBMIT] No results parsed from ", file_name)
      }
    } else {
      message("[SUBMIT] No OCR text returned for ", file_name)
      if (is.null(ocr_text)) {
        ocr_errors <- c(ocr_errors, paste(file_name, ": OCR returned NULL (check API key)"))
      } else {
        ocr_errors <- c(ocr_errors, paste(file_name, ": OCR returned empty text"))
      }
    }
  }

  removeNotification("ocr_processing")

  if (length(all_results) == 0) {
    error_detail <- if (length(ocr_errors) > 0) {
      paste("\n\nDetails:", paste(ocr_errors, collapse = "\n"))
    } else if (length(ocr_texts) > 0) {
      paste("\n\nOCR extracted text but parsing failed. Check R console for debug output.")
    } else {
      "\n\nNo text was extracted. Check that GOOGLE_CLOUD_VISION_API_KEY is set in .env"
    }
    showNotification(
      paste0("Could not extract player data from screenshots.", error_detail),
      type = "error",
      duration = 10
    )
    return()
  }

  # Combine results from all screenshots
  combined <- do.call(rbind, all_results)

  # Smart deduplication for overlapping screenshots
  # Priority: member_number (unique identifier) > username + placement
  if (nrow(combined) > 1) {
    original_count <- nrow(combined)

    # First, dedupe by member_number (most reliable - same player in multiple screenshots)
    # Keep the first occurrence (usually has correct placement from their screenshot)
    if (any(!is.na(combined$member_number) & combined$member_number != "")) {
      # For rows with member numbers, dedupe by member_number
      has_member <- !is.na(combined$member_number) & combined$member_number != ""
      with_member <- combined[has_member, ]
      without_member <- combined[!has_member, ]

      # Keep first occurrence of each member_number
      with_member <- with_member[!duplicated(with_member$member_number), ]

      # For rows without member numbers, dedupe by username (case-insensitive)
      if (nrow(without_member) > 0) {
        without_member$username_lower <- tolower(without_member$username)
        without_member <- without_member[!duplicated(without_member$username_lower), ]
        without_member$username_lower <- NULL
      }

      combined <- rbind(with_member, without_member)
    } else {
      # No member numbers - dedupe by username only
      combined$username_lower <- tolower(combined$username)
      combined <- combined[!duplicated(combined$username_lower), ]
      combined$username_lower <- NULL
    }

    deduped_count <- nrow(combined)
    if (original_count != deduped_count) {
      message("[SUBMIT] Deduplication: ", original_count, " -> ", deduped_count, " players")
    }
  }

  # Sort by placement
  combined <- combined[order(combined$placement), ]

  # Re-assign placements sequentially if there are gaps (from deduplication)
  # This handles cases where overlapping screenshots had different placement numbers
  combined$placement <- seq_len(nrow(combined))

  # Add deck column (default to UNKNOWN)
  combined$deck_id <- NA_integer_

  rv$submit_ocr_results <- combined

  showNotification(paste("Extracted", nrow(combined), "player results"), type = "message")
})

# Render results preview table
output$submit_results_preview <- renderUI({
  req(rv$submit_ocr_results)

  results <- rv$submit_ocr_results

  # Get deck choices
  decks <- if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    dbGetQuery(rv$db_con, "
      SELECT archetype_id, archetype_name FROM deck_archetypes
      WHERE is_active = TRUE
      ORDER BY archetype_name
    ")
  } else {
    data.frame(archetype_id = integer(), archetype_name = character())
  }

  deck_choices <- c("UNKNOWN" = "", setNames(decks$archetype_id, decks$archetype_name))

  card(
    class = "mt-3",
    card_header(
      class = "d-flex justify-content-between align-items-center",
      span("Review & Edit Results"),
      span(class = "badge bg-primary", paste(nrow(results), "players"))
    ),
    card_body(
      # Summary bar
      div(
        class = "tournament-summary-bar mb-3 p-2 rounded",
        style = "background: rgba(15, 76, 129, 0.1);",
        layout_columns(
          col_widths = c(3, 3, 3, 3),
          div(strong("Store: "), textOutput("submit_preview_store", inline = TRUE)),
          div(strong("Date: "), textOutput("submit_preview_date", inline = TRUE)),
          div(strong("Format: "), textOutput("submit_preview_format", inline = TRUE)),
          div(strong("Rounds: "), input$submit_rounds)
        )
      ),

      # Editable results table
      tags$table(
        class = "table table-sm table-striped",
        tags$thead(
          tags$tr(
            tags$th("#", style = "width: 50px;"),
            tags$th("Player"),
            tags$th("Member #"),
            tags$th("Points"),
            tags$th("W-L-T"),
            tags$th("Deck")
          )
        ),
        tags$tbody(
          lapply(seq_len(nrow(results)), function(i) {
            row <- results[i, ]
            tags$tr(
              tags$td(row$placement),
              tags$td(
                textInput(paste0("submit_player_", i), NULL,
                          value = row$username, width = "150px")
              ),
              tags$td(
                tags$code(
                  if (!is.null(row$member_number) && !is.na(row$member_number) && nchar(row$member_number) >= 4) {
                    substr(row$member_number, nchar(row$member_number) - 3, nchar(row$member_number))
                  } else {
                    "-"
                  }
                )
              ),
              tags$td(row$points),
              tags$td(paste0(row$wins, "-", row$losses, "-", row$ties)),
              tags$td(
                selectInput(paste0("submit_deck_", i), NULL,
                            choices = deck_choices,
                            width = "150px")
              )
            )
          })
        )
      ),

      tags$small(class = "text-muted",
                 "You can edit player names and assign decks. Member numbers are from screenshots.")
    )
  )
})

# Preview text outputs
output$submit_preview_store <- renderText({
  req(input$submit_store)
  if (input$submit_store == "") return("Not selected")
  stores <- dbGetQuery(rv$db_con, "SELECT name FROM stores WHERE store_id = ?",
                       params = list(as.integer(input$submit_store)))
  if (nrow(stores) > 0) stores$name[1] else "Unknown"
})

output$submit_preview_date <- renderText({
  req(input$submit_date)
  format(input$submit_date, "%b %d, %Y")
})

output$submit_preview_format <- renderText({
  req(input$submit_format)
  input$submit_format
})

# Final submit button
output$submit_final_button <- renderUI({
  req(rv$submit_ocr_results)

  div(
    class = "mt-3 d-flex justify-content-end gap-2",
    actionButton("submit_cancel", "Cancel", class = "btn-outline-secondary"),
    actionButton("submit_tournament", "Submit Tournament",
                 class = "btn-primary", icon = icon("check"))
  )
})

# Handle final submission
observeEvent(input$submit_tournament, {
  req(rv$submit_ocr_results)
  req(rv$db_con)

  # Validate required fields
  if (is.null(input$submit_store) || input$submit_store == "") {
    showNotification("Please select a store", type = "error")
    return()
  }
  if (is.na(input$submit_date)) {
    showNotification("Please select a date", type = "error")
    return()
  }
  if (is.null(input$submit_event_type) || input$submit_event_type == "") {
    showNotification("Please select an event type", type = "error")
    return()
  }
  if (is.null(input$submit_format) || input$submit_format == "") {
    showNotification("Please select a format", type = "error")
    return()
  }

  results <- rv$submit_ocr_results

  # Check for duplicate tournament
  existing <- dbGetQuery(rv$db_con, "
    SELECT tournament_id FROM tournaments
    WHERE store_id = ? AND event_date = ? AND event_type = ?
  ", params = list(
    as.integer(input$submit_store),
    as.character(input$submit_date),
    input$submit_event_type
  ))

  if (nrow(existing) > 0) {
    showNotification("A tournament with this store, date, and event type already exists.",
                     type = "error")
    return()
  }

  tryCatch({
    # Create tournament
    dbExecute(rv$db_con, "
      INSERT INTO tournaments (store_id, event_date, event_type, format, player_count, rounds)
      VALUES (?, ?, ?, ?, ?, ?)
    ", params = list(
      as.integer(input$submit_store),
      as.character(input$submit_date),
      input$submit_event_type,
      input$submit_format,
      nrow(results),
      input$submit_rounds
    ))

    # Get new tournament ID
    tournament_id <- dbGetQuery(rv$db_con, "SELECT MAX(tournament_id) as id FROM tournaments")$id

    # Insert each result
    for (i in seq_len(nrow(results))) {
      row <- results[i, ]

      # Get edited username
      username <- input[[paste0("submit_player_", i)]]
      if (is.null(username) || username == "") username <- row$username

      # Get selected deck
      deck_input <- input[[paste0("submit_deck_", i)]]
      deck_id <- if (!is.null(deck_input) && deck_input != "") as.integer(deck_input) else NA_integer_

      # Get member number from OCR results
      member_number <- if (!is.null(row$member_number) && !is.na(row$member_number) && row$member_number != "") {
        row$member_number
      } else {
        NA_character_
      }

      # Find or create player
      player <- dbGetQuery(rv$db_con, "
        SELECT player_id FROM players
        WHERE (member_number IS NOT NULL AND member_number = ?) OR LOWER(display_name) = LOWER(?)
        LIMIT 1
      ", params = list(member_number, username))

      if (nrow(player) == 0) {
        # Create new player
        dbExecute(rv$db_con, "
          INSERT INTO players (display_name, member_number)
          VALUES (?, ?)
        ", params = list(username, member_number))
        player_id <- dbGetQuery(rv$db_con, "SELECT MAX(player_id) as id FROM players")$id
      } else {
        player_id <- player$player_id[1]
        # Update member_number if we have it and they don't
        if (!is.na(member_number)) {
          dbExecute(rv$db_con, "
            UPDATE players SET member_number = ?
            WHERE player_id = ? AND member_number IS NULL
          ", params = list(member_number, player_id))
        }
      }

      # Insert result
      # Get UNKNOWN archetype_id if no deck selected
      if (is.na(deck_id)) {
        unknown <- dbGetQuery(rv$db_con, "SELECT archetype_id FROM deck_archetypes WHERE archetype_name = 'UNKNOWN'")
        deck_id <- if (nrow(unknown) > 0) unknown$archetype_id[1] else NA_integer_
      }

      dbExecute(rv$db_con, "
        INSERT INTO results (tournament_id, player_id, archetype_id, placement, wins, losses, ties)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ", params = list(
        tournament_id, player_id, deck_id,
        row$placement, row$wins, row$losses, row$ties
      ))
    }

    # Trigger refresh
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1
    rv$results_refresh <- (rv$results_refresh %||% 0) + 1

    # Clear form
    rv$submit_ocr_results <- NULL
    rv$submit_uploaded_files <- NULL
    updateSelectInput(session, "submit_store", selected = "")
    updateDateInput(session, "submit_date", value = NA)
    updateSelectInput(session, "submit_event_type", selected = "")
    updateSelectInput(session, "submit_format", selected = "")

    showNotification(
      paste("Tournament submitted successfully!", nrow(results), "results recorded."),
      type = "message"
    )

    # Navigate to tournaments page
    nav_select("main_content", "tournaments")
    rv$current_nav <- "tournaments"
    session$sendCustomMessage("updateSidebarNav", "nav_tournaments")

  }, error = function(e) {
    showNotification(paste("Error submitting tournament:", e$message), type = "error")
  })
})

# Handle cancel
observeEvent(input$submit_cancel, {
  rv$submit_ocr_results <- NULL
  rv$submit_uploaded_files <- NULL
  shinyjs::reset("submit_screenshots")
})

# Request new store link
observeEvent(input$submit_request_store, {
  showModal(modalDialog(
    title = "Request New Store",
    textInput("request_store_name", "Store Name *", width = "100%"),
    textInput("request_store_city", "City", width = "100%"),
    selectInput("request_store_state", "State",
                choices = c("TX", "OK", "LA", "AR", "NM"),
                selected = "TX", width = "100%"),
    footer = tagList(
      modalButton("Cancel"),
      actionButton("submit_store_request", "Submit Request", class = "btn-primary")
    )
  ))
})

observeEvent(input$submit_store_request, {
  req(input$request_store_name)
  if (trimws(input$request_store_name) == "") {
    showNotification("Store name is required", type = "error")
    return()
  }

  # For now, just show a message. Full request system in Phase 2.
  showNotification(
    "Store request noted. Please contact an admin to add the store.",
    type = "message"
  )
  removeModal()
})

# =============================================================================
# MATCH HISTORY TAB
# =============================================================================

# Initialize match history reactive values
rv$match_ocr_results <- NULL
rv$match_uploaded_file <- NULL

# Populate store dropdown for match history (includes "All stores" option)
observe({
  req(rv$db_con)
  stores <- dbGetQuery(rv$db_con, "
    SELECT store_id, name FROM stores
    WHERE is_active = TRUE
    ORDER BY name
  ")
  choices <- setNames(stores$store_id, stores$name)
  updateSelectInput(session, "match_store",
                    choices = c("All stores" = "", choices))
})

# Populate tournament dropdown based on store selection
observe({
  req(rv$db_con)

  store_filter <- if (!is.null(input$match_store) && input$match_store != "") {
    paste0(" AND t.store_id = ", as.integer(input$match_store))
  } else {
    ""
  }

  tournaments <- dbGetQuery(rv$db_con, paste0("
    SELECT t.tournament_id, t.event_date, t.event_type, s.name as store_name
    FROM tournaments t
    JOIN stores s ON t.store_id = s.store_id
    WHERE 1=1 ", store_filter, "
    ORDER BY t.event_date DESC
    LIMIT 50
  "))

  if (nrow(tournaments) > 0) {
    labels <- paste0(tournaments$store_name, " - ",
                     format(as.Date(tournaments$event_date), "%b %d, %Y"),
                     " (", tournaments$event_type, ")")
    choices <- setNames(tournaments$tournament_id, labels)
    updateSelectInput(session, "match_tournament",
                      choices = c("Select a tournament..." = "", choices))
  } else {
    updateSelectInput(session, "match_tournament",
                      choices = c("No tournaments found" = ""))
  }
})

# Show tournament info when selected
output$match_tournament_info <- renderUI({
  req(input$match_tournament)
  req(input$match_tournament != "")
  req(rv$db_con)

  tournament <- dbGetQuery(rv$db_con, "
    SELECT t.*, s.name as store_name
    FROM tournaments t
    JOIN stores s ON t.store_id = s.store_id
    WHERE t.tournament_id = ?
  ", params = list(as.integer(input$match_tournament)))

  if (nrow(tournament) == 0) return(NULL)

  t <- tournament[1, ]
  div(
    class = "mt-2 p-2 rounded",
    style = "background: rgba(15, 76, 129, 0.1);",
    tags$small(
      strong(t$store_name), " | ",
      format(as.Date(t$event_date), "%B %d, %Y"), " | ",
      t$event_type, " | ",
      t$player_count, " players | ",
      t$rounds, " rounds"
    )
  )
})

# Preview uploaded match history screenshot
output$match_screenshot_preview <- renderUI({
  req(input$match_screenshots)

  file <- input$match_screenshots
  if (is.null(file)) return(NULL)

  rv$match_uploaded_file <- file

  div(
    class = "border rounded p-2 d-flex align-items-center gap-2 mt-2",
    bsicons::bs_icon("image"),
    span(file$name),
    tags$small(class = "text-muted", paste0("(", round(file$size / 1024), " KB)"))
  )
})

# Process match history OCR
observeEvent(input$match_process_ocr, {
  req(rv$match_uploaded_file)
  req(input$match_tournament)
  req(input$match_tournament != "")

  file <- rv$match_uploaded_file

  showNotification("Processing match history with OCR...", type = "message", duration = NULL, id = "match_ocr_processing")

  message("[MATCH SUBMIT] Processing file: ", file$name)
  message("[MATCH SUBMIT] File path: ", file$datapath)

  # Call OCR
  ocr_text <- tryCatch({
    gcv_detect_text(file$datapath, verbose = TRUE)
  }, error = function(e) {
    message("[MATCH SUBMIT] OCR error: ", e$message)
    NULL
  })

  if (is.null(ocr_text) || ocr_text == "") {
    removeNotification("match_ocr_processing")
    showNotification("Could not extract text from screenshot. Check that GOOGLE_CLOUD_VISION_API_KEY is set.", type = "error")
    return()
  }

  message("[MATCH SUBMIT] OCR text length: ", nchar(ocr_text))

  # Parse match history
  parsed <- tryCatch({
    parse_match_history(ocr_text, verbose = TRUE)
  }, error = function(e) {
    message("[MATCH SUBMIT] Parse error: ", e$message)
    data.frame()
  })

  removeNotification("match_ocr_processing")

  if (nrow(parsed) == 0) {
    showNotification("Could not extract match data from screenshot. Please try a clearer image.", type = "error")
    return()
  }

  rv$match_ocr_results <- parsed
  showNotification(paste("Extracted", nrow(parsed), "matches"), type = "message")
})

# Render match history preview table
output$match_results_preview <- renderUI({
  req(rv$match_ocr_results)

  results <- rv$match_ocr_results

  card(
    class = "mt-3",
    card_header(
      class = "d-flex justify-content-between align-items-center",
      span("Review Match History"),
      span(class = "badge bg-primary", paste(nrow(results), "matches"))
    ),
    card_body(
      tags$table(
        class = "table table-sm table-striped",
        tags$thead(
          tags$tr(
            tags$th("Round"),
            tags$th("Opponent"),
            tags$th("Member #"),
            tags$th("Games (W-L-T)"),
            tags$th("Points")
          )
        ),
        tags$tbody(
          lapply(seq_len(nrow(results)), function(i) {
            row <- results[i, ]
            tags$tr(
              tags$td(row$round),
              tags$td(row$opponent_username),
              tags$td(
                tags$code(
                  if (!is.null(row$opponent_member_number) && !is.na(row$opponent_member_number) && nchar(row$opponent_member_number) >= 4) {
                    substr(row$opponent_member_number, nchar(row$opponent_member_number) - 3, nchar(row$opponent_member_number))
                  } else {
                    "-"
                  }
                )
              ),
              tags$td(paste0(row$games_won, "-", row$games_lost, "-", row$games_tied)),
              tags$td(row$match_points)
            )
          })
        )
      ),
      tags$small(class = "text-muted",
                 "Review the extracted match data. Opponents will be matched to existing players or created as new.")
    )
  )
})

# Match history submit button
output$match_final_button <- renderUI({
  req(rv$match_ocr_results)

  div(
    class = "mt-3 d-flex justify-content-end gap-2",
    actionButton("match_cancel", "Cancel", class = "btn-outline-secondary"),
    actionButton("match_submit", "Submit Match History",
                 class = "btn-primary", icon = icon("check"))
  )
})

# Handle match history submission
observeEvent(input$match_submit, {
  req(rv$match_ocr_results)
  req(rv$db_con)
  req(input$match_tournament)
  req(input$match_player_username)

  if (trimws(input$match_player_username) == "") {
    showNotification("Please enter your username", type = "error")
    return()
  }

  results <- rv$match_ocr_results
  tournament_id <- as.integer(input$match_tournament)
  submitter_username <- trimws(input$match_player_username)
  submitter_member <- if (!is.null(input$match_player_member) && trimws(input$match_player_member) != "") {
    trimws(input$match_player_member)
  } else {
    NA_character_
  }

  tryCatch({
    # Ensure matches table exists
    dbExecute(rv$db_con, "
      CREATE TABLE IF NOT EXISTS matches (
        match_id INTEGER PRIMARY KEY,
        tournament_id INTEGER NOT NULL,
        round_number INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        opponent_id INTEGER NOT NULL,
        games_won INTEGER NOT NULL DEFAULT 0,
        games_lost INTEGER NOT NULL DEFAULT 0,
        games_tied INTEGER NOT NULL DEFAULT 0,
        match_points INTEGER NOT NULL DEFAULT 0,
        submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(tournament_id, round_number, player_id)
      )
    ")

    # Find or create submitting player
    player <- dbGetQuery(rv$db_con, "
      SELECT player_id FROM players
      WHERE (member_number IS NOT NULL AND member_number = ?) OR LOWER(display_name) = LOWER(?)
      LIMIT 1
    ", params = list(submitter_member, submitter_username))

    if (nrow(player) == 0) {
      dbExecute(rv$db_con, "
        INSERT INTO players (display_name, member_number)
        VALUES (?, ?)
      ", params = list(submitter_username, submitter_member))
      player_id <- dbGetQuery(rv$db_con, "SELECT MAX(player_id) as id FROM players")$id
    } else {
      player_id <- player$player_id[1]
      if (!is.na(submitter_member)) {
        dbExecute(rv$db_con, "
          UPDATE players SET member_number = ?
          WHERE player_id = ? AND member_number IS NULL
        ", params = list(submitter_member, player_id))
      }
    }

    # Insert each match
    matches_inserted <- 0
    for (i in seq_len(nrow(results))) {
      row <- results[i, ]

      # Find or create opponent
      opponent_member <- if (!is.null(row$opponent_member_number) && !is.na(row$opponent_member_number) && row$opponent_member_number != "") {
        row$opponent_member_number
      } else {
        NA_character_
      }

      opponent <- dbGetQuery(rv$db_con, "
        SELECT player_id FROM players
        WHERE (member_number IS NOT NULL AND member_number = ?) OR LOWER(display_name) = LOWER(?)
        LIMIT 1
      ", params = list(opponent_member, row$opponent_username))

      if (nrow(opponent) == 0) {
        dbExecute(rv$db_con, "
          INSERT INTO players (display_name, member_number)
          VALUES (?, ?)
        ", params = list(row$opponent_username, opponent_member))
        opponent_id <- dbGetQuery(rv$db_con, "SELECT MAX(player_id) as id FROM players")$id
      } else {
        opponent_id <- opponent$player_id[1]
        if (!is.na(opponent_member)) {
          dbExecute(rv$db_con, "
            UPDATE players SET member_number = ?
            WHERE player_id = ? AND member_number IS NULL
          ", params = list(opponent_member, opponent_id))
        }
      }

      # Insert match (ignore if duplicate)
      tryCatch({
        dbExecute(rv$db_con, "
          INSERT INTO matches (tournament_id, round_number, player_id, opponent_id, games_won, games_lost, games_tied, match_points)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ", params = list(
          tournament_id,
          as.integer(row$round),
          player_id,
          opponent_id,
          as.integer(row$games_won),
          as.integer(row$games_lost),
          as.integer(row$games_tied),
          as.integer(row$match_points)
        ))
        matches_inserted <- matches_inserted + 1
      }, error = function(e) {
        message("[MATCH SUBMIT] Skipping duplicate match round ", row$round)
      })
    }

    # Clear form
    rv$match_ocr_results <- NULL
    rv$match_uploaded_file <- NULL
    updateSelectInput(session, "match_tournament", selected = "")
    updateTextInput(session, "match_player_username", value = "")
    updateTextInput(session, "match_player_member", value = "")

    showNotification(
      paste("Match history submitted!", matches_inserted, "matches recorded."),
      type = "message"
    )

  }, error = function(e) {
    showNotification(paste("Error submitting match history:", e$message), type = "error")
  })
})

# Handle match history cancel
observeEvent(input$match_cancel, {
  rv$match_ocr_results <- NULL
  rv$match_uploaded_file <- NULL
})
