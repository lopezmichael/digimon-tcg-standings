# Admin Grid Entry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the admin Enter Results one-at-a-time entry with a full-width editable grid supporting bulk entry, Points/W-L-T toggle, paste-from-spreadsheet, and inline player matching.

**Architecture:** The grid replaces Step 2's left-form + right-table layout with a single full-width card containing N blank rows (based on player count). Each row has a player name text input, record fields (Points or W/L/T based on toggle), and a deck dropdown. Server-side player matching runs on blur and shows inline badges. A paste-from-spreadsheet modal provides bulk fill. Submit inserts all rows at once.

**Tech Stack:** R Shiny, bslib (`layout_columns`), shinyjs, DuckDB, htmltools, bsicons

**Design doc:** `docs/plans/2026-02-19-admin-grid-entry-design.md`

---

### Task 1: Create Feature Branch

**Files:**
- None (git operation only)

**Step 1: Create and switch to feature branch**

Run: `git checkout -b feature/admin-grid-entry`

**Step 2: Verify branch**

Run: `git branch --show-current`
Expected: `feature/admin-grid-entry`

---

### Task 2: Add Record Format Toggle to Step 1 UI

**Files:**
- Modify: `views/admin-results-ui.R:52-59` (Row 3: Players + Rounds section)

**Context:** The Step 1 form currently has 3 rows: Store+Date, EventType+Format, Players+Rounds. We add a 4th row below Players+Rounds for the Record Format toggle. This is a `radioButtons` input that controls whether the grid shows a single Pts column or three W/L/T columns.

**Step 1: Add record format radio buttons to Step 1 UI**

In `views/admin-results-ui.R`, after the Row 3 div (Players + Rounds, lines 52-59), add a new Row 4:

```r
          # Row 4: Record Format
          div(
            class = "row g-3 mb-3",
            div(class = "col-md-6",
                radioButtons("admin_record_format", "Record Format",
                             choices = c("Points" = "points", "W-L-T" = "wlt"),
                             selected = "points", inline = TRUE))
          ),
```

This goes immediately before the `div(class = "d-flex justify-content-end mt-3",` line that contains the Create Tournament button.

**Step 2: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='views/admin-results-ui.R')"`
Expected: No errors

**Step 3: Commit**

```bash
git add views/admin-results-ui.R
git commit -m "feat(admin): add record format toggle to tournament details step"
```

---

### Task 3: Initialize Grid Data on Step 2 Entry

**Files:**
- Modify: `server/admin-results-server.R:120-138` (inside create tournament handler, after `rv$wizard_step <- 2`)
- Modify: `server/admin-results-server.R:279-298` (inside create anyway handler, after `rv$wizard_step <- 2`)

**Context:** When the admin creates a tournament and moves to Step 2, we need to initialize `rv$admin_grid_data` — a data frame with `player_count` blank rows. Each row has: `placement` (1..N), `player_name` (empty string), `points` (0), `wins` (0), `losses` (0), `ties` (0), `deck_id` (NA), `match_status` (""), `matched_player_id` (NA), `matched_member_number` (NA). We also store `rv$admin_record_format`.

**Step 1: Add reactive value initialization at top of file**

At the top of `server/admin-results-server.R` (after line 3, before the wizard step observe block), add:

```r
# Grid data for bulk entry
rv$admin_grid_data <- NULL
rv$admin_record_format <- "points"
rv$admin_player_matches <- list()
```

**Step 2: Add grid initialization helper function**

After the reactive value initialization, add a helper:

```r
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
```

**Step 3: Initialize grid in create tournament handler**

In the `observeEvent(input$create_tournament, ...)` handler, right after `rv$wizard_step <- 2` (line ~134), add:

```r
    rv$admin_record_format <- input$admin_record_format %||% "points"
    rv$admin_grid_data <- init_admin_grid(player_count)
    rv$admin_player_matches <- list()
```

**Step 4: Initialize grid in "create anyway" handler**

In the `observeEvent(input$create_anyway, ...)` handler, right after `rv$wizard_step <- 2` (line ~293), add the same three lines.

**Step 5: Clear grid in finish/delete/clear handlers**

In `observeEvent(input$finish_tournament, ...)` (line ~812), add after `rv$current_results <- data.frame()`:

```r
  rv$admin_grid_data <- NULL
  rv$admin_player_matches <- list()
```

Similarly in `observeEvent(input$delete_tournament_confirm, ...)` (line ~213), add after `rv$current_results <- data.frame()`:

```r
  rv$admin_grid_data <- NULL
  rv$admin_player_matches <- list()
```

And in `observeEvent(input$clear_results_only, ...)` (line ~183), after `rv$current_results <- data.frame()`:

```r
  # Re-initialize grid with blank rows
  player_count <- dbGetQuery(rv$db_con, "SELECT player_count FROM tournaments WHERE tournament_id = ?",
                             params = list(rv$active_tournament_id))$player_count
  rv$admin_grid_data <- init_admin_grid(player_count)
  rv$admin_player_matches <- list()
```

**Step 6: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')"`
Expected: No errors

**Step 7: Commit**

```bash
git add server/admin-results-server.R
git commit -m "feat(admin): initialize grid data on tournament creation"
```

---

### Task 4: Replace Step 2 UI with Grid Layout

**Files:**
- Modify: `views/admin-results-ui.R:69-188` (entire Step 2 section)

**Context:** Replace the current `layout_columns(col_widths = c(5, 7), ...)` containing the left entry form and right results table with a single full-width card containing: tournament summary bar, top bar (paste button + record format badge + filled count), `uiOutput("admin_grid_table")` for the grid rows, and bottom navigation.

**Step 1: Replace Step 2 content**

Replace everything inside the `shinyjs::hidden(div(id = "wizard_step2", ...))` block (lines 70-188) with:

```r
  shinyjs::hidden(
    div(
      id = "wizard_step2",
      class = "admin-panel",
      # Tournament summary bar
      uiOutput("tournament_summary_bar"),

      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          div(
            class = "d-flex align-items-center gap-2",
            span("Enter Results"),
            uiOutput("admin_record_format_badge", inline = TRUE)
          ),
          div(
            class = "d-flex align-items-center gap-2",
            uiOutput("admin_filled_count", inline = TRUE),
            actionButton("admin_paste_btn", "Paste from Spreadsheet",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("clipboard"))
          )
        ),
        card_body(
          uiOutput("admin_grid_table")
        )
      ),

      # Bottom navigation
      div(
        class = "d-flex justify-content-between mt-3",
        div(
          class = "d-flex gap-2",
          actionButton("wizard_back", "Back to Details", class = "btn-secondary",
                       icon = icon("arrow-left")),
          actionButton("clear_tournament", "Start Over", class = "btn-outline-warning",
                       icon = icon("rotate-left"))
        ),
        actionButton("admin_submit_results", "Submit Results", class = "btn-primary btn-lg",
                     icon = icon("check"))
      )
    )
  ),
```

Note: The old `finish_tournament` button is replaced by `admin_submit_results`. The old `clear_tournament` button moves to the bottom left. The wizard_back button keeps the same ID.

**Step 2: Remove the old edit result modal**

Delete the edit result modal block (lines ~218-268 in the original file). This modal was used by the old reactable's edit buttons. It's no longer needed since the grid is for initial entry only; editing after submission happens in the Edit Tournaments tab.

Keep the duplicate tournament modal and start over modal unchanged.

**Step 3: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='views/admin-results-ui.R')"`
Expected: No errors

**Step 4: Commit**

```bash
git add views/admin-results-ui.R
git commit -m "feat(admin): replace step 2 UI with grid layout card"
```

---

### Task 5: Render the Grid Table (Server)

**Files:**
- Modify: `server/admin-results-server.R` — add `output$admin_grid_table` renderUI, `output$admin_record_format_badge`, `output$admin_filled_count`

**Context:** The grid renders N rows using `layout_columns`. Each row has: delete button (X), placement badge, player name text input, record fields (Pts or W/L/T based on `rv$admin_record_format`), deck dropdown, and a match badge below the player name. This closely mirrors the upload results table pattern in `public-submit-server.R:555-693`.

**Step 1: Add the ordinal helper at the top of the file**

At the top of `server/admin-results-server.R`, after the reactive value initialization, add:

```r
# Ordinal helper (1st, 2nd, 3rd, etc.)
admin_ordinal <- function(n) {
  suffix <- c("th", "st", "nd", "rd", rep("th", 6))
  if (n %% 100 >= 11 && n %% 100 <= 13) {
    return(paste0(n, "th"))
  }
  return(paste0(n, suffix[(n %% 10) + 1]))
}
```

**Step 2: Add record format badge output**

```r
output$admin_record_format_badge <- renderUI({
  format <- rv$admin_record_format %||% "points"
  label <- if (format == "points") "Points mode" else "W-L-T mode"
  span(class = "badge bg-info", label)
})
```

**Step 3: Add filled count output**

```r
output$admin_filled_count <- renderUI({
  req(rv$admin_grid_data)
  grid <- rv$admin_grid_data
  filled <- sum(nchar(trimws(grid$player_name)) > 0)
  total <- nrow(grid)
  span(class = "text-muted small", sprintf("Filled: %d/%d", filled, total))
})
```

**Step 4: Add the grid table renderUI**

This is the main rendering function. It builds deck choices (same pattern as `public-submit-server.R:563-594`), then renders a header row and data rows.

```r
output$admin_grid_table <- renderUI({
  req(rv$admin_grid_data)

  grid <- rv$admin_grid_data
  record_format <- rv$admin_record_format %||% "points"

  # Check if release event (hide deck column)
  is_release <- FALSE
  if (!is.null(rv$active_tournament_id) && !is.null(rv$db_con)) {
    t_info <- dbGetQuery(rv$db_con, "SELECT event_type FROM tournaments WHERE tournament_id = ?",
                         params = list(rv$active_tournament_id))
    if (nrow(t_info) > 0) is_release <- t_info$event_type == "release_event"
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

  # Column widths depend on record format and release event
  if (is_release) {
    if (record_format == "points") {
      col_widths <- c(1, 1, 8, 2)       # X, #, Player, Pts
    } else {
      col_widths <- c(1, 1, 6, 2, 1, 1)  # X, #, Player, W, L, T
    }
  } else {
    if (record_format == "points") {
      col_widths <- c(1, 1, 4, 2, 4)     # X, #, Player, Pts, Deck
    } else {
      col_widths <- c(1, 1, 3, 1, 1, 1, 4)  # X, #, Player, W, L, T, Deck
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
        " Release event — deck archetype auto-set to UNKNOWN.")
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

    # Placement
    placement_col <- div(
      class = "upload-result-placement",
      span(class = paste("placement-badge", place_class), admin_ordinal(row$placement)),
      match_badge
    )

    # Player name input
    player_col <- div(
      textInput(paste0("admin_player_", i), NULL, value = row$player_name)
    )

    # Build row based on format
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
      # Deck dropdown - pre-select current value if set
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
```

**Step 5: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')"`
Expected: No errors

**Step 6: Commit**

```bash
git add server/admin-results-server.R
git commit -m "feat(admin): render grid table with placement badges and deck dropdowns"
```

---

### Task 6: Add Input Sync Helper and Delete Row Handler

**Files:**
- Modify: `server/admin-results-server.R` — add `sync_admin_grid_inputs()` helper, `observeEvent(input$admin_delete_row, ...)`

**Context:** Before any operation that re-renders the grid (delete row, paste fill), we must read current input values back into `rv$admin_grid_data`. This is the same pattern as `sync_submit_inputs()` in `public-submit-server.R:481-502`. Delete row removes the row, appends a blank at the bottom, and renumbers placements — same pattern as `public-submit-server.R:504-552`.

**Step 1: Add input sync helper**

```r
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
```

**Step 2: Add delete row handler**

```r
observeEvent(input$admin_delete_row, {
  req(rv$admin_grid_data)
  row_idx <- as.integer(input$admin_delete_row)
  if (is.null(row_idx) || row_idx < 1 || row_idx > nrow(rv$admin_grid_data)) return()

  sync_admin_grid_inputs()
  grid <- rv$admin_grid_data
  total_rows <- nrow(grid)

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
```

**Step 3: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')"`
Expected: No errors

**Step 4: Commit**

```bash
git add server/admin-results-server.R
git commit -m "feat(admin): add grid input sync helper and delete row handler"
```

---

### Task 7: Add Player Matching on Blur

**Files:**
- Modify: `server/admin-results-server.R` — add JavaScript for blur detection, add `observeEvent(input$admin_player_blur, ...)`

**Context:** When the admin tabs out of a player name field, we fire a JS blur event that tells Shiny which row was blurred. The server handler does an exact case-insensitive lookup against the `players` table and updates `rv$admin_player_matches` with the result. The grid re-renders showing the match badge.

**Step 1: Add JavaScript to send blur events for player name inputs**

In the wizard step 2 observer (the `observe` block that shows/hides wizard steps), after `shinyjs::show("wizard_step2")`, add:

```r
    # Attach blur handlers to player name inputs
    shinyjs::runjs("
      $(document).off('blur.adminGrid').on('blur.adminGrid', '[id^=admin_player_]', function() {
        var id = $(this).attr('id');
        var rowNum = parseInt(id.replace('admin_player_', ''));
        if (!isNaN(rowNum)) {
          Shiny.setInputValue('admin_player_blur', {row: rowNum, name: $(this).val(), ts: Date.now()}, {priority: 'event'});
        }
      });
    ")
```

**Step 2: Add player lookup handler**

```r
observeEvent(input$admin_player_blur, {
  req(rv$db_con, rv$admin_grid_data)

  info <- input$admin_player_blur
  row_num <- info$row
  name <- trimws(info$name)

  if (is.null(row_num) || is.na(row_num)) return()

  if (nchar(name) == 0) {
    # Clear match for this row
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
```

**Step 3: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')"`
Expected: No errors

**Step 4: Commit**

```bash
git add server/admin-results-server.R
git commit -m "feat(admin): add player matching on blur with inline badges"
```

---

### Task 8: Add Paste from Spreadsheet Modal

**Files:**
- Modify: `server/admin-results-server.R` — add paste modal handler and parse logic
- Modify: `views/admin-results-ui.R` — add paste modal HTML

**Context:** The "Paste from Spreadsheet" button opens a Shiny modal with a textarea. Admin pastes tab-separated data. Parse logic auto-detects format: names only, name+points, or name+W+L+T. Parsed data fills grid rows and triggers player match lookup for all filled rows.

**Step 1: Add paste modal to UI**

In `views/admin-results-ui.R`, after the start over modal (before the closing `)` of `admin_results_ui`), add:

```r
  # Paste from spreadsheet modal
  tags$div(
    id = "paste_spreadsheet_modal",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog modal-lg",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", bsicons::bs_icon("clipboard"), " Paste from Spreadsheet"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          p(class = "text-muted", "Paste tab-separated data. Supported formats:"),
          tags$ul(class = "text-muted small",
            tags$li("Player names only (one per line)"),
            tags$li("Player name [tab] Points"),
            tags$li("Player name [tab] W [tab] L [tab] T")
          ),
          tags$textarea(id = "paste_data", class = "form-control", rows = "12",
                        placeholder = "Paste data here..."),
          uiOutput("paste_preview")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("paste_apply", "Fill Grid", class = "btn-primary", icon = icon("table"))
        )
      )
    )
  )
```

**Step 2: Add button handler to show modal (server)**

```r
observeEvent(input$admin_paste_btn, {
  shinyjs::runjs("$('#paste_spreadsheet_modal').modal('show');")
})
```

**Step 3: Add paste apply handler (server)**

```r
observeEvent(input$paste_apply, {
  req(rv$admin_grid_data)

  paste_text <- input$paste_data
  if (is.null(paste_text) || nchar(trimws(paste_text)) == 0) {
    showNotification("No data to paste", type = "warning")
    return()
  }

  # Parse lines
  lines <- strsplit(paste_text, "\n")[[1]]
  lines <- lines[nchar(trimws(lines)) > 0]  # Skip blank lines

  if (length(lines) == 0) {
    showNotification("No valid lines found", type = "warning")
    return()
  }

  # Sync current inputs first
  sync_admin_grid_inputs()
  grid <- rv$admin_grid_data
  record_format <- rv$admin_record_format %||% "points"

  # Check if grid has existing data
  has_data <- any(nchar(trimws(grid$player_name)) > 0)
  # If has data, overwrite from row 1 (modal already warned via confirmation)

  # Parse each line
  parsed <- lapply(lines, function(line) {
    # Split by tab, or 2+ spaces as fallback
    parts <- strsplit(line, "\t")[[1]]
    if (length(parts) == 1) {
      parts <- strsplit(trimws(line), "\\s{2,}")[[1]]
    }
    parts <- trimws(parts)

    name <- parts[1]
    pts <- 0L; w <- 0L; l <- 0L; t <- 0L

    if (length(parts) == 2) {
      # Name + points
      pts <- suppressWarnings(as.integer(parts[2]))
      if (is.na(pts)) pts <- 0L
    } else if (length(parts) >= 4) {
      # Name + W + L + T
      w <- suppressWarnings(as.integer(parts[2]))
      l <- suppressWarnings(as.integer(parts[3]))
      t <- suppressWarnings(as.integer(parts[4]))
      if (is.na(w)) w <- 0L
      if (is.na(l)) l <- 0L
      if (is.na(t)) t <- 0L
      pts <- w * 3L + t
    }

    list(name = name, points = pts, wins = w, losses = l, ties = t)
  })

  # Fill grid rows starting from row 1 (or first empty row)
  start_row <- if (has_data) 1L else 1L
  fill_count <- 0L

  for (idx in seq_along(parsed)) {
    target_row <- start_row + idx - 1L
    if (target_row > nrow(grid)) break

    p <- parsed[[idx]]
    grid$player_name[target_row] <- p$name
    grid$points[target_row] <- p$points
    grid$wins[target_row] <- p$wins
    grid$losses[target_row] <- p$losses
    grid$ties[target_row] <- p$ties
    fill_count <- fill_count + 1L
  }

  rv$admin_grid_data <- grid

  # Close modal
  shinyjs::runjs("$('#paste_spreadsheet_modal').modal('hide');")
  # Clear textarea
  shinyjs::runjs("$('#paste_data').val('');")

  showNotification(sprintf("Filled %d rows from pasted data", fill_count), type = "message")

  # Trigger player match lookup for all filled rows
  for (idx in seq_len(fill_count)) {
    row_num <- start_row + idx - 1L
    name <- trimws(grid$player_name[row_num])
    if (nchar(name) == 0) next

    player <- dbGetQuery(rv$db_con, "
      SELECT player_id, display_name, member_number
      FROM players WHERE LOWER(display_name) = LOWER(?)
      LIMIT 1
    ", params = list(name))

    if (nrow(player) > 0) {
      rv$admin_player_matches[[as.character(row_num)]] <- list(
        status = "matched", player_id = player$player_id,
        member_number = player$member_number
      )
      grid$match_status[row_num] <- "matched"
      grid$matched_player_id[row_num] <- player$player_id
      grid$matched_member_number[row_num] <- player$member_number
    } else {
      rv$admin_player_matches[[as.character(row_num)]] <- list(status = "new")
      grid$match_status[row_num] <- "new"
      grid$matched_player_id[row_num] <- NA_integer_
      grid$matched_member_number[row_num] <- NA_character_
    }
  }
  rv$admin_grid_data <- grid
})
```

**Step 4: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')" && "/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='views/admin-results-ui.R')"`
Expected: No errors

**Step 5: Commit**

```bash
git add server/admin-results-server.R views/admin-results-ui.R
git commit -m "feat(admin): add paste-from-spreadsheet modal with auto-detect format"
```

---

### Task 9: Add Deck Request Handler for Grid

**Files:**
- Modify: `server/admin-results-server.R` — add deck dropdown change observer, deck request modal trigger

**Context:** When an admin selects "+ Request new deck..." from any row's deck dropdown, we open the deck request modal (same pattern as `public-submit-server.R:710-860`). After the request is submitted, all deck dropdowns get updated with the new pending entry and the triggering row gets auto-selected.

**Step 1: Add reactive value for tracking which row triggered deck request**

At the top of the file with other reactive values:

```r
rv$admin_deck_request_row <- NULL
```

**Step 2: Add deck dropdown observer**

```r
# Detect "Request new deck" selection in any grid row
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
```

**Step 3: Add deck request submit handler**

```r
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

  # Check for existing request
  existing <- dbGetQuery(rv$db_con, "
    SELECT request_id FROM deck_requests
    WHERE LOWER(deck_name) = LOWER(?) AND status = 'pending'
  ", params = list(deck_name))

  if (nrow(existing) > 0) {
    showNotification(sprintf("A pending request for '%s' already exists", deck_name), type = "warning")
    # Still select it for the row
    req_value <- paste0("pending_", existing$request_id[1])
  } else {
    max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(request_id), 0) as max_id FROM deck_requests")$max_id
    new_id <- max_id + 1

    dbExecute(rv$db_con, "
      INSERT INTO deck_requests (request_id, deck_name, primary_color, secondary_color, display_card_id, status)
      VALUES (?, ?, ?, ?, ?, 'pending')
    ", params = list(new_id, deck_name, primary_color, secondary_color, card_id))

    showNotification(sprintf("Deck request submitted: %s", deck_name), type = "message")
    req_value <- paste0("pending_", new_id)
  }

  removeModal()

  # Set the deck value for the requesting row in the grid data
  if (!is.null(rv$admin_deck_request_row)) {
    # Store the pending request value - the grid re-render will pick it up
    # For now, update deck_id to a special marker; re-render handles dropdown selection
    rv$admin_grid_data$deck_id[rv$admin_deck_request_row] <- NA_integer_
  }

  # Force grid re-render to update all deck dropdowns with new pending entry
  rv$admin_grid_data <- rv$admin_grid_data
})
```

**Step 4: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')"`
Expected: No errors

**Step 5: Commit**

```bash
git add server/admin-results-server.R
git commit -m "feat(admin): add deck request modal for grid rows"
```

---

### Task 10: Add Submit Results Handler

**Files:**
- Modify: `server/admin-results-server.R` — add `observeEvent(input$admin_submit_results, ...)`

**Context:** The submit handler reads all grid inputs, validates at least 1 row has a player name, then for each filled row: (1) exact-match player or create new, (2) convert points to W-L-T if in points mode, (3) resolve deck choice, (4) insert result row. Finally recalculate ratings, refresh data, show success notification, and reset to Step 1.

**Step 1: Add submit handler**

```r
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

  # Get UNKNOWN archetype ID for release events
  unknown_id <- NULL
  if (is_release) {
    unknown_row <- dbGetQuery(rv$db_con, "SELECT archetype_id FROM deck_archetypes WHERE archetype_name = 'UNKNOWN' LIMIT 1")
    if (nrow(unknown_row) == 0) {
      showNotification("UNKNOWN archetype not found in database", type = "error")
      return()
    }
    unknown_id <- unknown_row$archetype_id[1]
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
        # Create new player
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
        # Read deck selection from input (not grid$deck_id which may be stale)
        original_row_num <- row$placement  # placement = original row index before filtering
        deck_input <- input[[paste0("admin_deck_", original_row_num)]]

        if (is.null(deck_input) || nchar(deck_input) == 0) {
          # Default to UNKNOWN
          unknown_fallback <- dbGetQuery(rv$db_con, "SELECT archetype_id FROM deck_archetypes WHERE archetype_name = 'UNKNOWN' LIMIT 1")
          archetype_id <- if (nrow(unknown_fallback) > 0) unknown_fallback$archetype_id[1] else NA_integer_
        } else if (grepl("^pending_", deck_input)) {
          pending_deck_request_id <- as.integer(sub("^pending_", "", deck_input))
          unknown_fallback <- dbGetQuery(rv$db_con, "SELECT archetype_id FROM deck_archetypes WHERE archetype_name = 'UNKNOWN' LIMIT 1")
          archetype_id <- if (nrow(unknown_fallback) > 0) unknown_fallback$archetype_id[1] else NA_integer_
        } else if (deck_input == "__REQUEST_NEW__") {
          unknown_fallback <- dbGetQuery(rv$db_con, "SELECT archetype_id FROM deck_archetypes WHERE archetype_name = 'UNKNOWN' LIMIT 1")
          archetype_id <- if (nrow(unknown_fallback) > 0) unknown_fallback$archetype_id[1] else NA_integer_
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
```

**Step 2: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')"`
Expected: No errors

**Step 3: Commit**

```bash
git add server/admin-results-server.R
git commit -m "feat(admin): add submit results handler with player create and points conversion"
```

---

### Task 11: Remove Old One-at-a-Time Entry Code

**Files:**
- Modify: `server/admin-results-server.R` — remove quick-add player handlers, quick-add deck handlers, `add_result_logic()`, old reactable display, old delete/edit result handlers
- Modify: `views/admin-results-ui.R` — confirm edit result modal already removed in Task 4

**Context:** With the grid in place, the following server code is no longer needed:
- Lines 341-396: Quick Add Player handlers (`show_quick_add_player`, `quick_add_player_cancel`, `quick_add_player_submit`)
- Lines 398-449: Quick Add Deck handlers (`show_quick_add_deck`, `quick_add_deck_cancel`, `quick_add_deck_submit`)
- Lines 451-585: `add_result_logic()` function
- Lines 587-639: Quick-add deck from results entry (`quick_add_deck`)
- Lines 641-642: `observeEvent` bindings for `add_result` and `add_result_another`
- Lines 644-690: `output$current_results` renderReactable
- Lines 692-710: `observeEvent(input$delete_result_id, ...)`
- Lines 712-809: Edit result modal handlers (`edit_result_id`, `save_edit_result`)
- Lines 811-830: `observeEvent(input$finish_tournament, ...)` — replaced by `admin_submit_results`

Also remove `output$results_count_header` (lines 327-339) since it's replaced by `admin_filled_count`.

**Step 1: Remove the old code blocks**

Delete the following sections from `server/admin-results-server.R`:
1. Quick Add Player Handlers section (from `# ---------------------------------------------------------------------------` comment through `quick_add_player_submit` handler)
2. Quick Add Deck Handlers section
3. `add_result_logic()` function
4. Quick-add deck from results entry
5. `observeEvent(input$add_result, ...)` and `observeEvent(input$add_result_another, ...)`
6. `output$current_results` renderReactable
7. `observeEvent(input$delete_result_id, ...)`
8. Edit Result Handlers section
9. `observeEvent(input$finish_tournament, ...)`
10. `output$results_count_header` renderUI

**Step 2: Verify R syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')"`
Expected: No errors

**Step 3: Commit**

```bash
git add server/admin-results-server.R
git commit -m "refactor(admin): remove old one-at-a-time entry code"
```

---

### Task 12: Add CSS for Admin Grid

**Files:**
- Modify: `www/custom.css` — add admin grid styles

**Context:** The admin grid reuses the `.upload-result-row`, `.upload-result-delete`, `.upload-result-placement`, and `.placement-badge` classes already in `custom.css`. We only need minimal additions for the admin-specific header and any adjustments.

**Step 1: Add admin grid CSS**

Find the `/* Upload result delete button */` section in `www/custom.css` and add after the existing upload result styles (after the `.upload-result-row select` block):

```css
/* Admin grid entry styles */
.admin-panel .upload-result-row input[type="number"] {
  text-align: center;
}

.admin-panel .results-header-row {
  font-weight: 600;
  font-size: 0.8rem;
  text-transform: uppercase;
  color: rgba(0, 0, 0, 0.5);
  padding: 0.25rem 0;
  border-bottom: 2px solid rgba(0, 0, 0, 0.15);
  margin-bottom: 0.25rem;
}

[data-bs-theme="dark"] .admin-panel .results-header-row {
  color: rgba(255, 255, 255, 0.5);
  border-bottom-color: rgba(255, 255, 255, 0.15);
}
```

**Step 2: Verify the CSS file is syntactically valid**

Review the added CSS visually — no build step needed for CSS.

**Step 3: Commit**

```bash
git add www/custom.css
git commit -m "style(admin): add CSS for admin grid entry"
```

---

### Task 13: Update Documentation

**Files:**
- Modify: `CHANGELOG.md` — add entry under [Unreleased]
- Modify: `logs/dev_log.md` — add entry for admin grid entry

**Step 1: Update CHANGELOG.md**

Add under the `[Unreleased]` section:

```markdown
### Added
- Admin Enter Results: grid-based bulk entry replacing one-at-a-time flow
- Record Format toggle (Points or W-L-T) on tournament creation
- Paste from Spreadsheet modal for bulk data fill
- Inline player matching badges (matched with member #, new player)
- Auto-create new players on grid submit

### Changed
- Admin Enter Results Step 2: full-width grid replaces left-form + right-table layout
- Submit Results button replaces per-row Add Result + Mark Complete flow

### Removed
- Quick-add player/deck inline forms in admin results entry
- Per-row edit/delete in admin results step 2 (use Edit Tournaments tab instead)
```

**Step 2: Update dev_log.md**

Add a dated entry:

```markdown
### 2026-02-19: Admin Grid Entry

Replaced the admin Enter Results one-at-a-time flow with a full-width editable grid.

**Problem:** Adding 16+ players required 16+ cycles of select-player → select-deck → enter-WLT → click-Add. Non-Bandai sources sometimes provide total points instead of W-L-T.

**Solution:** Grid with N blank rows (based on player count), Record Format toggle (Points auto-converts to W-L-T on submit), paste-from-spreadsheet, and inline player matching badges. Submit inserts all results at once.

**Key decisions:**
- Grid replaces old flow entirely (no toggle back)
- Points mode: `wins = pts / 3`, `ties = pts % 3`, `losses = rounds - wins - ties`
- Player matching: exact case-insensitive name match, auto-create on submit
- Deck request modal reused from Upload Results pattern
- Edit/delete after submission stays in Edit Tournaments tab
```

**Step 3: Commit**

```bash
git add CHANGELOG.md logs/dev_log.md
git commit -m "docs: add changelog and dev log entries for admin grid entry"
```

---

### Task 14: Verify and Test

**Files:**
- None (verification only)

**Step 1: Run full R syntax check**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='views/admin-results-ui.R')" && "/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='server/admin-results-server.R')" && "/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='www/custom.css')" && "/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse(file='app.R')"`
Expected: No parse errors

**Step 2: Ask user to manually test**

Ask the user to:
1. Run `shiny::runApp()` and navigate to Enter Results
2. Create a tournament with Points mode → verify grid appears with N blank rows
3. Type a known player name, tab out → verify green "Matched" badge appears
4. Type an unknown name, tab out → verify gray "New player" badge
5. Delete a row → verify renumber
6. Test paste from spreadsheet with tab-separated data
7. Create a tournament with W-L-T mode → verify 3 columns instead of 1
8. Submit results → verify results appear in Edit Tournaments tab
9. Test release event → verify deck column hidden

---

## Summary of All Changes

| File | Action | Description |
|------|--------|-------------|
| `views/admin-results-ui.R` | Major rewrite | Record format toggle in Step 1; full-width grid card in Step 2; paste modal; remove edit result modal |
| `server/admin-results-server.R` | Major rewrite | Grid init, grid render, input sync, delete row, player match on blur, paste handler, deck request, submit handler; remove old one-at-a-time code |
| `www/custom.css` | Minor add | Admin grid number alignment and header styles |
| `CHANGELOG.md` | Update | New feature entries |
| `logs/dev_log.md` | Update | Technical decision entry |
