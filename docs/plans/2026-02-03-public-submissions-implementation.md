# Public Submissions & OCR Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable community-driven tournament data entry via screenshot uploads with OCR processing.

**Architecture:** New public "Submit Results" tab with Google Cloud Vision OCR. Screenshots are processed client-to-server, parsed into structured data, reviewed by user, then saved. Admin and public flows unified into single system with permission tiers.

**Tech Stack:** R Shiny, httr2 (API calls), base64enc (image encoding), Google Cloud Vision API, DuckDB

---

## Implementation Status

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Foundation & OCR | **COMPLETE** | Tasks 1-5 done, OCR parsing works for Bandai TCG+ screenshots |
| Phase 2: Requests & Admin | Not started | store_requests, deck_requests tables |
| Phase 3: Match History | Not started | matches table, match history OCR |
| Phase 4: Polish | Not started | Mobile optimization, error handling |

**Last Updated:** 2026-02-04

**Branch:** `feature/public-submissions` (10 commits ahead of main)

### Phase 1 Implementation Notes

- DuckDB doesn't support `ALTER TABLE ADD COLUMN ... UNIQUE` - constraint removed, uniqueness enforced in app
- OCR uses `DOCUMENT_TEXT_DETECTION` feature (better for structured documents than `TEXT_DETECTION`)
- Parsing tuned to Bandai TCG+ app format - may need adjustments for other screenshot formats
- Users can edit parsed results before submitting

---

## Phase 1: Foundation & OCR Integration

### Task 1: Add member_number to players table

**Files:**
- Modify: `db/schema.sql`
- Create: `scripts/migrate_add_member_number.R`

**Step 1: Update schema.sql**

Add member_number column to players table definition in `db/schema.sql` (around line 82):

```sql
-- In players table definition, add after tcgplus_id:
    member_number VARCHAR UNIQUE,  -- Bandai TCG+ member number (0000XXXXXX)
```

**Step 2: Create migration script**

Create `scripts/migrate_add_member_number.R`:

```r
# Migration: Add member_number column to players table
# Run once on existing database

library(DBI)
source("R/db_connection.R")

con <- connect_db()

# Check if column exists
cols <- dbGetQuery(con, "PRAGMA table_info(players)")
if (!"member_number" %in% cols$name) {
  dbExecute(con, "ALTER TABLE players ADD COLUMN member_number VARCHAR UNIQUE")
  message("Added member_number column to players table")
} else {
  message("member_number column already exists")
}

dbDisconnect(con)
```

**Step 3: Run migration locally**

```bash
"/c/Program Files/R/R-4.5.0/bin/Rscript.exe" scripts/migrate_add_member_number.R
```

**Step 4: Commit**

```bash
git add db/schema.sql scripts/migrate_add_member_number.R
git commit -m "feat(schema): add member_number column to players table"
```

---

### Task 2: Create OCR module with Google Cloud Vision

**Files:**
- Create: `R/ocr.R`

**Step 1: Create the OCR module**

Create `R/ocr.R`:

```r
# R/ocr.R
# Google Cloud Vision OCR integration for screenshot parsing

library(httr2)
library(base64enc)

#' Call Google Cloud Vision API for text detection
#'
#' @param image_path Path to local image file OR raw bytes
#' @param api_key Google Cloud Vision API key
#' @return Character string of detected text, or NULL on error
gcv_detect_text <- function(image_data, api_key = Sys.getenv("GOOGLE_CLOUD_VISION_API_KEY")) {
  if (is.null(api_key) || api_key == "") {
    warning("GOOGLE_CLOUD_VISION_API_KEY not set")
    return(NULL)
  }

  # Handle both file path and raw bytes

if (is.character(image_data) && file.exists(image_data)) {
    image_base64 <- base64encode(image_data)
  } else if (is.raw(image_data)) {
    image_base64 <- base64encode(image_data)
  } else {
    warning("Invalid image_data: must be file path or raw bytes")
    return(NULL)
  }

  # Build and execute request
  tryCatch({
    response <- request("https://vision.googleapis.com/v1/images:annotate") |>
      req_url_query(key = api_key) |>
      req_body_json(list(
        requests = list(list(
          image = list(content = image_base64),
          features = list(list(type = "TEXT_DETECTION"))
        ))
      )) |>
      req_perform() |>
      resp_body_json()

    # Extract full text annotation
    text <- response$responses[[1]]$fullTextAnnotation$text
    if (is.null(text)) {
      warning("No text detected in image")
      return("")
    }
    return(text)
  }, error = function(e) {
    warning(paste("OCR API error:", e$message))
    return(NULL)
  })
}

#' Parse tournament standings from OCR text
#'
#' Extracts player data from Bandai TCG+ tournament rankings screenshot.
#' Expected format per player:
#'   Ranking | Username | Win Points | OMW% | GW%
#'   Member Number 0000XXXXXX
#'
#' @param ocr_text Raw text from gcv_detect_text()
#' @param total_rounds Total rounds in tournament (for calculating losses)
#' @return Data frame with columns: placement, username, member_number, points, wins, losses, ties
parse_tournament_standings <- function(ocr_text, total_rounds = 4) {
  if (is.null(ocr_text) || ocr_text == "") {
    return(data.frame(
      placement = integer(),
      username = character(),
      member_number = character(),
      points = integer(),
      wins = integer(),
      losses = integer(),
      ties = integer()
    ))
  }

  lines <- strsplit(ocr_text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[lines != ""]

  results <- list()

  # Pattern for member number line
  member_pattern <- "Member\\s*Number\\s*:?\\s*(\\d{10,})"

  # Pattern for ranking row: number, username, points, percentages
  # Flexible to handle various OCR quirks
  ranking_pattern <- "^(\\d{1,2})\\s+([A-Za-z0-9_]+)\\s+(\\d{1,2})\\s+"

  current_placement <- NULL
  current_username <- NULL
  current_points <- NULL

  for (line in lines) {
    # Check for member number
    member_match <- regmatches(line, regexec(member_pattern, line, ignore.case = TRUE))[[1]]
    if (length(member_match) > 1) {
      member_number <- member_match[2]
      if (!is.null(current_username)) {
        # Calculate W-L-T from points
        # 3 points per win, 1 point per tie, 0 per loss
        wins <- current_points %/% 3
        remaining <- current_points %% 3
        ties <- remaining  # Each remaining point is a tie
        losses <- total_rounds - wins - ties

        results[[length(results) + 1]] <- data.frame(
          placement = current_placement,
          username = current_username,
          member_number = member_number,
          points = current_points,
          wins = wins,
          losses = max(0, losses),
          ties = ties,
          stringsAsFactors = FALSE
        )

        current_username <- NULL
        current_placement <- NULL
        current_points <- NULL
      }
      next
    }

    # Check for ranking row
    ranking_match <- regmatches(line, regexec(ranking_pattern, line))[[1]]
    if (length(ranking_match) > 1) {
      current_placement <- as.integer(ranking_match[2])
      current_username <- ranking_match[3]
      current_points <- as.integer(ranking_match[4])
    }
  }

  if (length(results) == 0) {
    return(data.frame(
      placement = integer(),
      username = character(),
      member_number = character(),
      points = integer(),
      wins = integer(),
      losses = integer(),
      ties = integer()
    ))
  }

  do.call(rbind, results)
}

#' Parse match history from OCR text
#'
#' Extracts round-by-round match data from Bandai TCG+ match history screenshot.
#'
#' @param ocr_text Raw text from gcv_detect_text()
#' @return Data frame with columns: round, opponent_username, opponent_member_number,
#'         games_won, games_lost, games_tied, match_points
parse_match_history <- function(ocr_text) {
  if (is.null(ocr_text) || ocr_text == "") {
    return(data.frame(
      round = integer(),
      opponent_username = character(),
      opponent_member_number = character(),
      games_won = integer(),
      games_lost = integer(),
      games_tied = integer(),
      match_points = integer()
    ))
  }

  lines <- strsplit(ocr_text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[lines != ""]

  results <- list()

  # Pattern for round row with results
  # Format: Round# | Opponent | Results (W-L-T) | Points
  round_pattern <- "^(\\d)\\s+"
  result_pattern <- "(\\d)\\s*-\\s*(\\d)\\s*-\\s*(\\d)"
  member_pattern <- "Member\\s*Number\\s*:?\\s*(\\d{10,})"

  current_round <- NULL
  current_opponent <- NULL
  current_games <- NULL
  current_points <- NULL

  for (i in seq_along(lines)) {
    line <- lines[i]

    # Check for member number (comes after opponent name)
    member_match <- regmatches(line, regexec(member_pattern, line, ignore.case = TRUE))[[1]]
    if (length(member_match) > 1 && !is.null(current_opponent)) {
      results[[length(results) + 1]] <- data.frame(
        round = current_round,
        opponent_username = current_opponent,
        opponent_member_number = member_match[2],
        games_won = current_games[1],
        games_lost = current_games[2],
        games_tied = current_games[3],
        match_points = current_points,
        stringsAsFactors = FALSE
      )
      current_opponent <- NULL
      next
    }

    # Check for round row
    round_match <- regmatches(line, regexec(round_pattern, line))[[1]]
    if (length(round_match) > 1) {
      current_round <- as.integer(round_match[2])

      # Extract results (W-L-T)
      result_match <- regmatches(line, regexec(result_pattern, line))[[1]]
      if (length(result_match) > 1) {
        current_games <- as.integer(result_match[2:4])
      }

      # Extract points (last number in line)
      points_match <- regmatches(line, regexec("(\\d)\\s*$", line))[[1]]
      if (length(points_match) > 1) {
        current_points <- as.integer(points_match[2])
      }

      # Extract opponent name (between round and results)
      # This is tricky - opponent name is in the middle
      parts <- strsplit(line, "\\s{2,}")[[1]]
      if (length(parts) >= 2) {
        current_opponent <- trimws(parts[2])
        # Remove any numbers that got captured
        current_opponent <- gsub("^\\d+\\s*", "", current_opponent)
        current_opponent <- gsub("\\s*\\d.*$", "", current_opponent)
      }
    }
  }

  if (length(results) == 0) {
    return(data.frame(
      round = integer(),
      opponent_username = character(),
      opponent_member_number = character(),
      games_won = integer(),
      games_lost = integer(),
      games_tied = integer(),
      match_points = integer()
    ))
  }

  do.call(rbind, results)
}
```

**Step 2: Commit**

```bash
git add R/ocr.R
git commit -m "feat(ocr): add Google Cloud Vision integration for screenshot parsing"
```

---

### Task 3: Create Submit Results UI

**Files:**
- Create: `views/submit-ui.R`
- Modify: `app.R` (add nav item and source)

**Step 1: Create the Submit Results UI**

Create `views/submit-ui.R`:

```r
# views/submit-ui.R
# Public Submit Results tab UI

submit_ui <- tagList(
  # Title strip
  div(
    class = "page-title-strip mb-3",
    div(
      class = "title-strip-content",
      div(
        class = "title-strip-context",
        bsicons::bs_icon("cloud-upload", class = "title-strip-icon"),
        tags$span(class = "title-strip-text", "Submit Results")
      ),
      div(
        class = "title-strip-controls",
        span(class = "small text-muted", "Help grow the tournament database")
      )
    )
  ),

  # Main content with tabs
  navset_card_tab(
    id = "submit_tabs",

    # Tournament Results Tab
    nav_panel(
      title = tagList(bsicons::bs_icon("trophy"), " Tournament Results"),
      value = "tournament",

      div(
        class = "p-3",

        # Tournament Details Card
        card(
          card_header("Tournament Details"),
          card_body(
            layout_columns(
              col_widths = c(6, 6),
              # Left column
              div(
                selectInput("submit_store", "Store *",
                            choices = c("Loading..." = ""),
                            width = "100%"),
                actionLink("submit_request_store", "Store not listed? Request new store",
                           class = "small text-muted")
              ),
              # Right column
              div(
                dateInput("submit_date", "Date *", value = NA, width = "100%"),
                tags$small(class = "text-muted", "Required")
              )
            ),
            layout_columns(
              col_widths = c(4, 4, 4),
              selectInput("submit_event_type", "Event Type *",
                          choices = c("Select..." = "",
                                      "Locals" = "locals",
                                      "Evo Cup" = "evo_cup",
                                      "Store Championship" = "store_championship",
                                      "Regional" = "regional",
                                      "Online" = "online"),
                          width = "100%"),
              selectInput("submit_format", "Format *",
                          choices = c("Loading..." = ""),
                          width = "100%"),
              numericInput("submit_rounds", "Total Rounds *", value = 4, min = 1, max = 15, width = "100%")
            )
          )
        ),

        # Screenshot Upload Card
        card(
          card_header(
            class = "d-flex justify-content-between align-items-center",
            span("Tournament Screenshots"),
            actionButton("submit_add_screenshot", "Add Another",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("plus"))
          ),
          card_body(
            fileInput("submit_screenshots", "Upload Screenshot(s)",
                      multiple = TRUE,
                      accept = c("image/png", "image/jpeg", "image/jpg"),
                      width = "100%"),
            tags$small(class = "text-muted d-block mb-2",
                       "Upload screenshots from Bandai TCG+ app showing tournament rankings"),
            uiOutput("submit_screenshot_preview"),
            div(
              class = "mt-3",
              actionButton("submit_process_ocr", "Process Screenshots",
                           class = "btn-primary",
                           icon = icon("magic"))
            )
          )
        ),

        # Results Preview (shown after OCR)
        uiOutput("submit_results_preview"),

        # Submit Button (shown after OCR)
        uiOutput("submit_final_button")
      )
    ),

    # Match History Tab
    nav_panel(
      title = tagList(bsicons::bs_icon("list-ol"), " Match History"),
      value = "match_history",

      div(
        class = "p-3",

        # Info card
        card(
          card_body(
            class = "text-center py-4",
            bsicons::bs_icon("info-circle", size = "2rem", class = "text-muted mb-2"),
            h5("Coming Soon"),
            p(class = "text-muted mb-0",
              "Match history submission will be available in a future update. ",
              "For now, you can submit tournament standings above.")
          )
        )
      )
    )
  )
)
```

**Step 2: Add to app.R navigation**

In `app.R`, add the source and nav item. Find the `nav_panel` definitions and add after "Stores":

```r
# Add source at top with other sources
source("views/submit-ui.R")

# Add nav_panel in sidebar (after stores, before admin)
nav_panel(
  title = "Submit",
  value = "submit",
  icon = bsicons::bs_icon("cloud-upload"),
  submit_ui
),
```

**Step 3: Commit**

```bash
git add views/submit-ui.R app.R
git commit -m "feat(ui): add Submit Results tab with tournament upload form"
```

---

### Task 4: Create Submit Results Server Logic

**Files:**
- Create: `server/public-submit-server.R`
- Modify: `app.R` (add source)

**Step 1: Create server module**

Create `server/public-submit-server.R`:

```r
# server/public-submit-server.R
# Public Submit Results server logic

# Load OCR module
source("R/ocr.R")

# Reactive value to store OCR results
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

  for (i in seq_len(nrow(files))) {
    file_path <- files$datapath[i]

    # Call OCR
    ocr_text <- gcv_detect_text(file_path)

    if (!is.null(ocr_text) && ocr_text != "") {
      # Parse results
      parsed <- parse_tournament_standings(ocr_text, total_rounds)
      if (nrow(parsed) > 0) {
        all_results[[length(all_results) + 1]] <- parsed
      }
    }
  }

  removeNotification("ocr_processing")

  if (length(all_results) == 0) {
    showNotification("Could not extract data from screenshots. Please try clearer images.",
                     type = "error")
    return()
  }

  # Combine results from all screenshots
  combined <- do.call(rbind, all_results)

  # Remove duplicates (same placement)
  combined <- combined[!duplicated(combined$placement), ]

  # Sort by placement
  combined <- combined[order(combined$placement), ]

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
                tags$code(substr(row$member_number, nchar(row$member_number) - 3, nchar(row$member_number)))
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

      # Find or create player
      player <- dbGetQuery(rv$db_con, "
        SELECT player_id FROM players
        WHERE member_number = ? OR LOWER(display_name) = LOWER(?)
        LIMIT 1
      ", params = list(row$member_number, username))

      if (nrow(player) == 0) {
        # Create new player
        dbExecute(rv$db_con, "
          INSERT INTO players (display_name, member_number)
          VALUES (?, ?)
        ", params = list(username, row$member_number))
        player_id <- dbGetQuery(rv$db_con, "SELECT MAX(player_id) as id FROM players")$id
      } else {
        player_id <- player$player_id[1]
        # Update member_number if we have it and they don't
        dbExecute(rv$db_con, "
          UPDATE players SET member_number = ?
          WHERE player_id = ? AND member_number IS NULL
        ", params = list(row$member_number, player_id))
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

  }, error = function(e) {
    showNotification(paste("Error submitting tournament:", e$message), type = "error")
  })
})

# Handle cancel
observeEvent(input$submit_cancel, {
  rv$submit_ocr_results <- NULL
  rv$submit_uploaded_files <- NULL
  reset("submit_screenshots")
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
```

**Step 2: Add to app.R**

Add source call in app.R with other server sources:

```r
source("server/public-submit-server.R")
```

Also add reactive values initialization:

```r
# In rv initialization, add:
submit_ocr_results = NULL,
submit_uploaded_files = NULL,
```

**Step 3: Commit**

```bash
git add server/public-submit-server.R app.R
git commit -m "feat(server): add Submit Results server logic with OCR processing"
```

---

### Task 5: Test OCR Integration End-to-End

**Files:**
- None (manual testing)

**Step 1: Run the app locally**

```bash
# User runs shiny::runApp() in R console
```

**Step 2: Test the Submit Results flow**

1. Navigate to Submit Results tab
2. Select a store, date, event type, format, rounds
3. Upload a screenshot from `screenshots/mobile/IMG_3780.PNG`
4. Click "Process Screenshots"
5. Verify OCR extracts player data
6. Assign some decks
7. Submit tournament
8. Verify tournament appears in Tournaments tab

**Step 3: Fix any parsing issues**

The OCR regex patterns may need adjustment based on actual output. Common issues:
- Extra whitespace
- OCR misreading characters
- Different line ordering

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix(ocr): adjust parsing regex for actual OCR output"
```

---

## Phase 2: Request System & Admin Unification

### Task 6: Create request tables

**Files:**
- Modify: `db/schema.sql`
- Create: `scripts/migrate_add_request_tables.R`

**Step 1: Add tables to schema.sql**

Add after the results table:

```sql
-- =============================================================================
-- STORE REQUESTS TABLE
-- Community-submitted store requests pending admin approval
-- =============================================================================
CREATE TABLE IF NOT EXISTS store_requests (
    request_id INTEGER PRIMARY KEY,
    store_name VARCHAR NOT NULL,
    city VARCHAR,
    state VARCHAR DEFAULT 'TX',
    address VARCHAR,
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6),
    status VARCHAR DEFAULT 'pending',  -- pending, approved, rejected
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP,
    reviewed_by VARCHAR
);

-- =============================================================================
-- DECK REQUESTS TABLE
-- Community-submitted deck archetype requests pending admin approval
-- =============================================================================
CREATE TABLE IF NOT EXISTS deck_requests (
    request_id INTEGER PRIMARY KEY,
    deck_name VARCHAR NOT NULL,
    primary_color VARCHAR NOT NULL,
    secondary_color VARCHAR,
    display_card_id VARCHAR,
    status VARCHAR DEFAULT 'pending',  -- pending, approved, rejected
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP,
    reviewed_by VARCHAR
);
```

**Step 2: Create migration script**

Create `scripts/migrate_add_request_tables.R`:

```r
# Migration: Add store_requests and deck_requests tables
library(DBI)
source("R/db_connection.R")

con <- connect_db()

# Create store_requests if not exists
dbExecute(con, "
  CREATE TABLE IF NOT EXISTS store_requests (
    request_id INTEGER PRIMARY KEY,
    store_name VARCHAR NOT NULL,
    city VARCHAR,
    state VARCHAR DEFAULT 'TX',
    address VARCHAR,
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6),
    status VARCHAR DEFAULT 'pending',
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP,
    reviewed_by VARCHAR
  )
")
message("Created store_requests table")

# Create deck_requests if not exists
dbExecute(con, "
  CREATE TABLE IF NOT EXISTS deck_requests (
    request_id INTEGER PRIMARY KEY,
    deck_name VARCHAR NOT NULL,
    primary_color VARCHAR NOT NULL,
    secondary_color VARCHAR,
    display_card_id VARCHAR,
    status VARCHAR DEFAULT 'pending',
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP,
    reviewed_by VARCHAR
  )
")
message("Created deck_requests table")

dbDisconnect(con)
```

**Step 3: Run migration and commit**

```bash
"/c/Program Files/R/R-4.5.0/bin/Rscript.exe" scripts/migrate_add_request_tables.R
git add db/schema.sql scripts/migrate_add_request_tables.R
git commit -m "feat(schema): add store_requests and deck_requests tables"
```

---

### Task 7: Implement store/deck request submission

(Continue with full request workflow...)

---

## Phase 3: Match History (Deferred)

Tasks 12-15 for match history OCR and submission - implement after Phase 1 & 2 are stable.

---

## Phase 4: Polish (Deferred)

Tasks 16-19 for edit-anywhere deck feature, error handling, mobile optimization.

---

## Testing Checklist

After each phase, verify:

- [ ] App starts without errors
- [ ] Submit Results tab is visible
- [ ] Store/format dropdowns populate
- [ ] Screenshot upload works
- [ ] OCR processing returns results
- [ ] Results can be edited
- [ ] Submission creates tournament and results
- [ ] New players are created with member numbers
- [ ] Existing players get member numbers backfilled
- [ ] Duplicate tournament detection works
- [ ] Data appears in Tournaments and Players tabs

---

## Rollback Plan

If issues arise:
1. Revert commits: `git revert HEAD~N`
2. Drop new columns: `ALTER TABLE players DROP COLUMN member_number`
3. Drop new tables: `DROP TABLE IF EXISTS store_requests, deck_requests`
