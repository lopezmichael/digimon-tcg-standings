# server/public-submit-server.R
# Public Upload Results server logic

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

# Populate format dropdown - sorted by release_date DESC (most recent first)
observe({
  req(rv$db_con)
  formats <- dbGetQuery(rv$db_con, "
    SELECT format_id, display_name FROM formats
    WHERE is_active = TRUE
    ORDER BY release_date DESC, sort_order ASC
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
    div(
      class = "uploaded-files-list mt-3",
      h6(class = "text-muted mb-2", paste(nrow(files), "file(s) selected:")),
      lapply(seq_len(nrow(files)), function(i) {
        div(
          class = "uploaded-file-item d-flex align-items-center gap-2 p-2 border rounded mb-2",
          bsicons::bs_icon("file-image", class = "text-primary"),
          span(files$name[i]),
          tags$small(class = "text-muted ms-auto",
                     paste0(round(files$size[i] / 1024), " KB"))
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

  # Validate required fields first
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

  # Show processing modal with blue theme
  showModal(modalDialog(
    div(
      class = "text-center py-4",
      div(class = "processing-spinner mb-3"),
      h5(class = "text-primary", "Processing Screenshots"),
      p(class = "text-muted mb-0", id = "ocr_status_text", "Extracting player data..."),
      tags$small(class = "text-muted", paste(nrow(files), "file(s) to process"))
    ),
    title = NULL,
    footer = NULL,
    easyClose = FALSE,
    size = "s"
  ))

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

  removeModal()

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
  if (nrow(combined) > 1) {
    original_count <- nrow(combined)

    if (any(!is.na(combined$member_number) & combined$member_number != "")) {
      has_member <- !is.na(combined$member_number) & combined$member_number != ""
      with_member <- combined[has_member, ]
      without_member <- combined[!has_member, ]

      with_member <- with_member[!duplicated(with_member$member_number), ]

      if (nrow(without_member) > 0) {
        without_member$username_lower <- tolower(without_member$username)
        without_member <- without_member[!duplicated(without_member$username_lower), ]
        without_member$username_lower <- NULL
      }

      combined <- rbind(with_member, without_member)
    } else {
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

  # Re-assign placements sequentially
  combined$placement <- seq_len(nrow(combined))

  # Add deck column
  combined$deck_id <- NA_integer_

  # Pre-match players against database
  combined$matched_player_id <- NA_integer_
  combined$match_status <- "new"  # "matched", "possible", "new"
  combined$matched_player_name <- NA_character_

  if (!is.null(rv$db_con) && dbIsValid(rv$db_con)) {
    for (i in seq_len(nrow(combined))) {
      member_num <- combined$member_number[i]
      username <- combined$username[i]

      # First try to match by member number
      if (!is.null(member_num) && !is.na(member_num) && nchar(member_num) > 0) {
        player_by_member <- dbGetQuery(rv$db_con, "
          SELECT player_id, display_name FROM players
          WHERE member_number = ?
          LIMIT 1
        ", params = list(member_num))

        if (nrow(player_by_member) > 0) {
          combined$matched_player_id[i] <- player_by_member$player_id[1]
          combined$matched_player_name[i] <- player_by_member$display_name[1]
          combined$match_status[i] <- "matched"
          next
        }
      }

      # Try to match by username
      if (!is.null(username) && !is.na(username) && nchar(username) > 0) {
        player_by_name <- dbGetQuery(rv$db_con, "
          SELECT player_id, display_name, member_number FROM players
          WHERE LOWER(display_name) = LOWER(?)
          LIMIT 1
        ", params = list(username))

        if (nrow(player_by_name) > 0) {
          combined$matched_player_id[i] <- player_by_name$player_id[1]
          combined$matched_player_name[i] <- player_by_name$display_name[1]
          combined$match_status[i] <- "possible"
        }
      }
    }
  }

  rv$submit_ocr_results <- combined

  # Switch to step 2
  shinyjs::hide("submit_wizard_step1")
  shinyjs::show("submit_wizard_step2")
  shinyjs::removeClass("submit_step1_indicator", "active")
  shinyjs::addClass("submit_step2_indicator", "active")

  showNotification(paste("Extracted", nrow(combined), "player results"), type = "message")
})

# Back button - return to step 1
observeEvent(input$submit_back, {
  shinyjs::hide("submit_wizard_step2")
  shinyjs::show("submit_wizard_step1")
  shinyjs::removeClass("submit_step2_indicator", "active")
  shinyjs::addClass("submit_step1_indicator", "active")
})

# Render summary banner
output$submit_summary_banner <- renderUI({
  req(rv$submit_ocr_results)

  # Get store name
  store_name <- "Not selected"
  if (!is.null(input$submit_store) && input$submit_store != "") {
    store <- dbGetQuery(rv$db_con, "SELECT name FROM stores WHERE store_id = ?",
                        params = list(as.integer(input$submit_store)))
    if (nrow(store) > 0) store_name <- store$name[1]
  }

  div(
    class = "tournament-summary-bar mb-3",
    div(
      class = "summary-bar-content",
      div(class = "summary-item",
          bsicons::bs_icon("shop"),
          span(store_name)),
      div(class = "summary-item",
          bsicons::bs_icon("calendar"),
          span(format(input$submit_date, "%b %d, %Y"))),
      div(class = "summary-item",
          bsicons::bs_icon("tag"),
          span(input$submit_format)),
      div(class = "summary-item",
          bsicons::bs_icon("flag"),
          span(input$submit_rounds, " rounds"))
    )
  )
})

# Render match summary badges
output$submit_match_summary <- renderUI({
  req(rv$submit_ocr_results)

  results <- rv$submit_ocr_results

  matched_count <- sum(results$match_status == "matched", na.rm = TRUE)
  possible_count <- sum(results$match_status == "possible", na.rm = TRUE)
  new_count <- sum(results$match_status == "new", na.rm = TRUE)

  div(
    class = "match-summary-badges d-flex gap-2 mb-3",
    div(
      class = "match-badge match-badge--matched",
      bsicons::bs_icon("check-circle-fill"),
      span(class = "badge-count", matched_count),
      span(class = "badge-label", "Matched")
    ),
    div(
      class = "match-badge match-badge--possible",
      bsicons::bs_icon("question-circle-fill"),
      span(class = "badge-count", possible_count),
      span(class = "badge-label", "Possible")
    ),
    div(
      class = "match-badge match-badge--new",
      bsicons::bs_icon("person-plus-fill"),
      span(class = "badge-count", new_count),
      span(class = "badge-label", "New")
    )
  )
})

# Helper function for ordinal placement (1st, 2nd, 3rd, etc.)
ordinal <- function(n) {
  suffix <- c("th", "st", "nd", "rd", rep("th", 6))
  if (n %% 100 >= 11 && n %% 100 <= 13) {
    return(paste0(n, "th"))
  }
  return(paste0(n, suffix[(n %% 10) + 1]))
}

# Render results table using layout_columns
output$submit_results_table <- renderUI({
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

  deck_choices <- c("Unknown" = "", setNames(decks$archetype_id, decks$archetype_name))

  tagList(
    # Header row
    layout_columns(
      col_widths = c(1, 4, 2, 2, 3),
      class = "results-header-row",
      div("#"),
      div("Player"),
      div("Member #"),
      div("Pts"),
      div("Deck")
    ),

    # Data rows
    lapply(seq_len(nrow(results)), function(i) {
      row <- results[i, ]

      # Placement class for coloring
      place_class <- if (row$placement == 1) "place-1st"
                     else if (row$placement == 2) "place-2nd"
                     else if (row$placement == 3) "place-3rd"
                     else ""

      # Match indicator
      match_indicator <- switch(row$match_status,
        "matched" = div(
          class = "player-match-indicator matched",
          bsicons::bs_icon("check-circle-fill"),
          span(class = "match-label", "Linked to:"),
          span(class = "match-name", row$matched_player_name),
          actionLink(paste0("reject_match_", i),
                     bsicons::bs_icon("x-circle"),
                     class = "reject-btn",
                     title = "Reject match")
        ),
        "possible" = div(
          class = "player-match-indicator possible",
          bsicons::bs_icon("question-circle-fill"),
          span(class = "match-label", "Possible:"),
          span(class = "match-name", row$matched_player_name),
          actionLink(paste0("reject_match_", i),
                     bsicons::bs_icon("x-circle"),
                     class = "reject-btn",
                     title = "Reject match")
        ),
        div(
          class = "player-match-indicator new",
          bsicons::bs_icon("person-plus-fill"),
          span(class = "match-label", "New player")
        )
      )

      layout_columns(
        col_widths = c(1, 4, 2, 2, 3),
        class = "upload-result-row",
        # Placement
        div(
          span(class = paste("placement-badge", place_class), ordinal(row$placement))
        ),
        # Player + match indicator
        div(
          textInput(paste0("submit_player_", i), NULL,
                    value = row$username),
          match_indicator
        ),
        # Member number
        div(
          textInput(paste0("submit_member_", i), NULL,
                    value = if (!is.na(row$member_number)) row$member_number else "",
                    placeholder = "0000...")
        ),
        # Points
        div(
          numericInput(paste0("submit_points_", i), NULL,
                       value = if (!is.na(row$points)) row$points else 0,
                       min = 0, max = 99)
        ),
        # Deck
        div(
          selectInput(paste0("submit_deck_", i), NULL,
                      choices = deck_choices,
                      selectize = FALSE)
        )
      )
    })
  )
})

# Handle reject match buttons
observe({
  req(rv$submit_ocr_results)
  results <- rv$submit_ocr_results

  lapply(seq_len(nrow(results)), function(i) {
    observeEvent(input[[paste0("reject_match_", i)]], {
      rv$submit_ocr_results$match_status[i] <- "new"
      rv$submit_ocr_results$matched_player_id[i] <- NA_integer_
      rv$submit_ocr_results$matched_player_name[i] <- NA_character_
      showNotification(paste("Match rejected - will create as new player"), type = "message")
    }, ignoreInit = TRUE, once = TRUE)
  })
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

    tournament_id <- dbGetQuery(rv$db_con, "SELECT MAX(tournament_id) as id FROM tournaments")$id
    total_rounds <- input$submit_rounds

    # Insert each result
    for (i in seq_len(nrow(results))) {
      row <- results[i, ]

      # Get edited values
      username <- input[[paste0("submit_player_", i)]]
      if (is.null(username) || username == "") username <- row$username

      member_input <- input[[paste0("submit_member_", i)]]
      member_number <- if (!is.null(member_input) && trimws(member_input) != "") {
        trimws(member_input)
      } else {
        NA_character_
      }

      points_input <- input[[paste0("submit_points_", i)]]
      points <- if (!is.null(points_input) && !is.na(points_input)) as.integer(points_input) else 0
      wins <- points %/% 3
      ties <- points %% 3
      losses <- max(0, total_rounds - wins - ties)

      deck_input <- input[[paste0("submit_deck_", i)]]
      deck_id <- if (!is.null(deck_input) && deck_input != "") as.integer(deck_input) else NA_integer_

      # Determine player_id
      player_id <- NULL

      if (!is.na(row$matched_player_id) && row$match_status %in% c("matched", "possible")) {
        player_id <- row$matched_player_id
        if (!is.na(member_number)) {
          dbExecute(rv$db_con, "
            UPDATE players SET member_number = ?
            WHERE player_id = ? AND member_number IS NULL
          ", params = list(member_number, player_id))
        }
      } else {
        player <- dbGetQuery(rv$db_con, "
          SELECT player_id FROM players
          WHERE (member_number IS NOT NULL AND member_number = ?) OR LOWER(display_name) = LOWER(?)
          LIMIT 1
        ", params = list(member_number, username))

        if (nrow(player) == 0) {
          dbExecute(rv$db_con, "
            INSERT INTO players (display_name, member_number)
            VALUES (?, ?)
          ", params = list(username, member_number))
          player_id <- dbGetQuery(rv$db_con, "SELECT MAX(player_id) as id FROM players")$id
        } else {
          player_id <- player$player_id[1]
          if (!is.na(member_number)) {
            dbExecute(rv$db_con, "
              UPDATE players SET member_number = ?
              WHERE player_id = ? AND member_number IS NULL
            ", params = list(member_number, player_id))
          }
        }
      }

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
        row$placement, wins, losses, ties
      ))
    }

    # Trigger refresh
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1
    rv$results_refresh <- (rv$results_refresh %||% 0) + 1

    # Reset form
    rv$submit_ocr_results <- NULL
    rv$submit_uploaded_files <- NULL

    # Switch back to step 1
    shinyjs::hide("submit_wizard_step2")
    shinyjs::show("submit_wizard_step1")
    shinyjs::removeClass("submit_step2_indicator", "active")
    shinyjs::addClass("submit_step1_indicator", "active")

    # Clear inputs
    updateSelectInput(session, "submit_store", selected = "")
    updateDateInput(session, "submit_date", value = NA)
    updateSelectInput(session, "submit_event_type", selected = "")
    updateSelectInput(session, "submit_format", selected = "")
    shinyjs::reset("submit_screenshots")

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

# Request new store link
observeEvent(input$submit_request_store, {
  # Open Google Form for store requests (placeholder URL)
  showModal(modalDialog(
    title = "Request New Store",
    div(
      class = "text-center py-3",
      bsicons::bs_icon("shop", size = "3em", class = "text-primary mb-3"),
      p("To request a new store be added to the system, please fill out our store request form."),
      tags$a(
        href = "https://forms.gle/placeholder", # TODO: Real form URL
        target = "_blank",
        class = "btn btn-primary",
        bsicons::bs_icon("box-arrow-up-right", class = "me-2"),
        "Open Store Request Form"
      ),
      p(class = "text-muted small mt-3",
        "You can also contact an admin directly via Discord.")
    ),
    footer = modalButton("Close"),
    easyClose = TRUE
  ))
})

# =============================================================================
# MATCH HISTORY TAB
# =============================================================================

# Initialize match history reactive values
rv$match_ocr_results <- NULL
rv$match_uploaded_file <- NULL

# Populate store dropdown for match history
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
    class = "uploaded-file-item d-flex align-items-center gap-2 p-2 border rounded mt-3",
    bsicons::bs_icon("file-image", class = "text-primary"),
    span(file$name),
    tags$small(class = "text-muted ms-auto", paste0(round(file$size / 1024), " KB"))
  )
})

# Process match history OCR
observeEvent(input$match_process_ocr, {
  req(rv$match_uploaded_file)

  # Validate required fields
  if (is.null(input$match_tournament) || input$match_tournament == "") {
    showNotification("Please select a tournament", type = "error")
    return()
  }

  if (is.null(input$match_player_username) || trimws(input$match_player_username) == "") {
    showNotification("Please enter your username", type = "error")
    shinyjs::removeClass("match_username_hint", "d-none")
    return()
  } else {
    shinyjs::addClass("match_username_hint", "d-none")
  }

  if (is.null(input$match_player_member) || trimws(input$match_player_member) == "") {
    showNotification("Please enter your member number", type = "error")
    shinyjs::removeClass("match_member_hint", "d-none")
    return()
  } else {
    shinyjs::addClass("match_member_hint", "d-none")
  }

  file <- rv$match_uploaded_file

  # Show processing modal
  showModal(modalDialog(
    div(
      class = "text-center py-4",
      div(class = "processing-spinner mb-3"),
      h5(class = "text-primary", "Processing Screenshot"),
      p(class = "text-muted mb-0", "Extracting match data...")
    ),
    title = NULL,
    footer = NULL,
    easyClose = FALSE,
    size = "s"
  ))

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
    removeModal()
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

  removeModal()

  if (nrow(parsed) == 0) {
    showNotification("Could not extract match data from screenshot. Please try a clearer image.", type = "error")
    return()
  }

  rv$match_ocr_results <- parsed
  showNotification(paste("Extracted", nrow(parsed), "matches"), type = "message")
})

# Render match history preview table with editable fields
output$match_results_preview <- renderUI({
  req(rv$match_ocr_results)

  results <- rv$match_ocr_results

  card(
    class = "mt-3",
    card_header(
      class = "d-flex justify-content-between align-items-center",
      span("Review & Edit Match History"),
      span(class = "badge bg-primary", paste(nrow(results), "matches"))
    ),
    card_body(
      # Instructions
      div(
        class = "alert alert-info d-flex mb-3",
        bsicons::bs_icon("pencil-square", class = "me-2 flex-shrink-0"),
        tags$small("Review and edit the extracted data. Correct any OCR errors before submitting.")
      ),

      # Header row
      layout_columns(
        col_widths = c(1, 4, 3, 2, 2),
        class = "results-header-row",
        div("Rd"),
        div("Opponent"),
        div("Member #"),
        div("W-L-T"),
        div("Pts")
      ),

      # Editable rows
      lapply(seq_len(nrow(results)), function(i) {
        row <- results[i, ]

        layout_columns(
          col_widths = c(1, 4, 3, 2, 2),
          class = "upload-result-row",
          # Round number (read-only display)
          div(
            span(class = "placement-badge", row$round)
          ),
          # Opponent username (editable)
          div(
            textInput(paste0("match_opponent_", i), NULL,
                      value = row$opponent_username)
          ),
          # Opponent member number (editable)
          div(
            textInput(paste0("match_member_", i), NULL,
                      value = if (!is.na(row$opponent_member_number)) row$opponent_member_number else "",
                      placeholder = "0000...")
          ),
          # Games W-L-T (editable as text to allow "2-0-0" format)
          div(
            textInput(paste0("match_games_", i), NULL,
                      value = paste0(row$games_won, "-", row$games_lost, "-", row$games_tied),
                      placeholder = "W-L-T")
          ),
          # Match points (editable)
          div(
            numericInput(paste0("match_points_", i), NULL,
                         value = as.integer(row$match_points),
                         min = 0, max = 9)
          )
        )
      })
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

  if (is.null(input$match_player_username) || trimws(input$match_player_username) == "") {
    showNotification("Please enter your username", type = "error")
    return()
  }

  if (is.null(input$match_player_member) || trimws(input$match_player_member) == "") {
    showNotification("Please enter your member number", type = "error")
    return()
  }

  results <- rv$match_ocr_results
  tournament_id <- as.integer(input$match_tournament)
  submitter_username <- trimws(input$match_player_username)
  submitter_member <- trimws(input$match_player_member)

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
      dbExecute(rv$db_con, "
        UPDATE players SET member_number = ?
        WHERE player_id = ? AND member_number IS NULL
      ", params = list(submitter_member, player_id))
    }

    # Insert each match - read from editable inputs
    matches_inserted <- 0
    for (i in seq_len(nrow(results))) {
      row <- results[i, ]

      # Get edited values from inputs
      opponent_username <- input[[paste0("match_opponent_", i)]]
      if (is.null(opponent_username) || opponent_username == "") opponent_username <- row$opponent_username

      opponent_member_input <- input[[paste0("match_member_", i)]]
      opponent_member <- if (!is.null(opponent_member_input) && trimws(opponent_member_input) != "") {
        trimws(opponent_member_input)
      } else {
        NA_character_
      }

      # Parse games W-L-T from input
      games_input <- input[[paste0("match_games_", i)]]
      games_won <- row$games_won
      games_lost <- row$games_lost
      games_tied <- row$games_tied
      if (!is.null(games_input) && grepl("^\\d+-\\d+-\\d+$", games_input)) {
        parts <- strsplit(games_input, "-")[[1]]
        games_won <- as.integer(parts[1])
        games_lost <- as.integer(parts[2])
        games_tied <- as.integer(parts[3])
      }

      # Get match points from input
      match_points_input <- input[[paste0("match_points_", i)]]
      match_points <- if (!is.null(match_points_input) && !is.na(match_points_input)) {
        as.integer(match_points_input)
      } else {
        as.integer(row$match_points)
      }

      opponent <- dbGetQuery(rv$db_con, "
        SELECT player_id FROM players
        WHERE (member_number IS NOT NULL AND member_number = ?) OR LOWER(display_name) = LOWER(?)
        LIMIT 1
      ", params = list(opponent_member, opponent_username))

      if (nrow(opponent) == 0) {
        dbExecute(rv$db_con, "
          INSERT INTO players (display_name, member_number)
          VALUES (?, ?)
        ", params = list(opponent_username, opponent_member))
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

      tryCatch({
        dbExecute(rv$db_con, "
          INSERT INTO matches (tournament_id, round_number, player_id, opponent_id, games_won, games_lost, games_tied, match_points)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ", params = list(
          tournament_id,
          as.integer(row$round),
          player_id,
          opponent_id,
          games_won,
          games_lost,
          games_tied,
          match_points
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
    shinyjs::reset("match_screenshots")

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
  shinyjs::reset("match_screenshots")
})
