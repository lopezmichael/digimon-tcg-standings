# Admin UX Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve admin experience for editing tournament results and prevent date entry errors.

**Architecture:** Add a results modal to Edit Tournaments page, modify duplicate flow to navigate there, and require date selection in Enter Results.

**Tech Stack:** R Shiny, bslib, reactable, shinyjs, Bootstrap 5 modals

---

## Task 1: Add "View/Edit Results" Button to Edit Tournaments UI

**Files:**
- Modify: `views/admin-tournaments-ui.R:47-63`

**Step 1: Add the button below tournament stats**

In `views/admin-tournaments-ui.R`, after line 50 (`uiOutput("tournament_stats_info")`), add the View/Edit Results button. Replace lines 47-63:

```r
          hr(),

          # Tournament stats (read-only info)
          uiOutput("tournament_stats_info"),

          # View/Edit Results button (only shown when tournament selected)
          shinyjs::hidden(
            div(
              id = "view_results_btn_container",
              class = "mt-3",
              actionButton("view_edit_results", "View/Edit Results",
                           class = "btn-primary w-100",
                           icon = icon("list-check"))
            )
          ),

          hr(),

          # Action buttons
          div(
            class = "d-flex gap-2",
            shinyjs::hidden(
              actionButton("update_tournament", "Update Tournament", class = "btn-success")
            ),
            shinyjs::hidden(
              actionButton("delete_tournament", "Delete Tournament", class = "btn-danger")
            )
          )
```

**Step 2: Verify the change**

Run the app and go to Edit Tournaments. The button should be hidden initially.

**Step 3: Commit**

```bash
git add views/admin-tournaments-ui.R
git commit -m "feat(admin): add View/Edit Results button to Edit Tournaments"
```

---

## Task 2: Add Results Modal UI to Edit Tournaments

**Files:**
- Modify: `views/admin-tournaments-ui.R` (add modal after delete modal, around line 109)

**Step 1: Add the results modal HTML**

After the delete_tournament_modal closing div (around line 109), add:

```r
  # Results modal for viewing/editing tournament results
  tags$div(
    id = "tournament_results_modal",
    class = "modal fade",
    tabindex = "-1",
    `data-bs-backdrop` = "static",
    tags$div(
      class = "modal-dialog modal-lg",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header modal-header-digital",
          tags$h5(class = "modal-title", bsicons::bs_icon("list-check"), " Tournament Results"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          # Tournament summary
          uiOutput("results_modal_summary"),

          hr(),

          # Add result button
          div(
            class = "mb-3",
            actionButton("modal_add_result", "+ Add Result",
                         class = "btn-outline-primary btn-sm",
                         icon = icon("plus"))
          ),

          # Results table
          reactableOutput("modal_results_table"),

          # Add result form (hidden initially)
          shinyjs::hidden(
            div(
              id = "modal_add_result_form",
              class = "card mt-3 p-3 bg-light",
              h6("Add New Result"),
              div(
                class = "row g-2",
                div(class = "col-md-6",
                    selectizeInput("modal_new_player", "Player",
                                   choices = NULL,
                                   options = list(create = FALSE, placeholder = "Select player..."))),
                div(class = "col-md-6",
                    selectizeInput("modal_new_deck", "Deck",
                                   choices = NULL,
                                   options = list(create = FALSE, placeholder = "Select deck...")))
              ),
              div(
                class = "row g-2 mt-2",
                div(class = "col-md-3",
                    numericInput("modal_new_placement", "Place", value = 1, min = 1)),
                div(class = "col-md-3",
                    numericInput("modal_new_wins", "Wins", value = 0, min = 0)),
                div(class = "col-md-3",
                    numericInput("modal_new_losses", "Losses", value = 0, min = 0)),
                div(class = "col-md-3",
                    numericInput("modal_new_ties", "Ties", value = 0, min = 0))
              ),
              div(
                class = "row g-2 mt-2",
                div(class = "col-12",
                    textInput("modal_new_decklist", "Decklist URL (optional)", placeholder = "https://..."))
              ),
              div(
                class = "d-flex gap-2 mt-3",
                actionButton("modal_save_new_result", "Save", class = "btn-success btn-sm"),
                actionButton("modal_cancel_new_result", "Cancel", class = "btn-outline-secondary btn-sm")
              )
            )
          )
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Done")
        )
      )
    )
  ),

  # Edit result modal (for editing individual results from the table)
  tags$div(
    id = "modal_edit_result",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", bsicons::bs_icon("pencil-square"), " Edit Result"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          # Hidden field for result ID
          textInput("modal_editing_result_id", NULL, value = ""),
          tags$script("document.getElementById('modal_editing_result_id').parentElement.style.display = 'none';"),

          selectizeInput("modal_edit_player", "Player",
                         choices = NULL,
                         options = list(create = FALSE, placeholder = "Select player...")),
          selectizeInput("modal_edit_deck", "Deck",
                         choices = NULL,
                         options = list(create = FALSE, placeholder = "Select deck...")),
          div(
            class = "row g-2",
            div(class = "col-md-3",
                numericInput("modal_edit_placement", "Place", value = 1, min = 1)),
            div(class = "col-md-3",
                numericInput("modal_edit_wins", "Wins", value = 0, min = 0)),
            div(class = "col-md-3",
                numericInput("modal_edit_losses", "Losses", value = 0, min = 0)),
            div(class = "col-md-3",
                numericInput("modal_edit_ties", "Ties", value = 0, min = 0))
          ),
          div(
            class = "mt-2",
            textInput("modal_edit_decklist", "Decklist URL (optional)")
          )
        ),
        tags$div(
          class = "modal-footer d-flex justify-content-between",
          actionButton("modal_delete_result", "Delete", class = "btn-danger"),
          div(
            tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
            actionButton("modal_save_edit_result", "Save Changes", class = "btn-success ms-2")
          )
        )
      )
    )
  ),

  # Delete result confirmation modal
  tags$div(
    id = "modal_delete_result_confirm",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog modal-sm",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", "Delete Result?"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          p("Are you sure you want to delete this result?"),
          p(class = "text-muted small", "This action cannot be undone.")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("modal_confirm_delete_result", "Delete", class = "btn-danger")
        )
      )
    )
  )
```

**Step 2: Verify the change**

Ensure the file is syntactically correct by running the app briefly.

**Step 3: Commit**

```bash
git add views/admin-tournaments-ui.R
git commit -m "feat(admin): add results modal UI to Edit Tournaments"
```

---

## Task 3: Add Server Handlers for Results Modal

**Files:**
- Modify: `server/admin-tournaments-server.R` (add at end of file)

**Step 1: Add show/hide button handler and modal open handler**

At the end of `server/admin-tournaments-server.R`, add:

```r
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

# Also need to update reset_tournament_form to hide button
# This will be done by modifying the existing function

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
```

**Step 2: Verify syntax**

Run: `Rscript -e "source('server/admin-tournaments-server.R')"`

**Step 3: Commit**

```bash
git add server/admin-tournaments-server.R
git commit -m "feat(admin): add results modal open and display handlers"
```

---

## Task 4: Add Edit/Delete Result Handlers in Modal

**Files:**
- Modify: `server/admin-tournaments-server.R` (continue adding handlers)

**Step 1: Add click-to-edit handler**

Continue in `server/admin-tournaments-server.R`:

```r
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
```

**Step 2: Commit**

```bash
git add server/admin-tournaments-server.R
git commit -m "feat(admin): add edit/delete result handlers in modal"
```

---

## Task 5: Add New Result Handler in Modal

**Files:**
- Modify: `server/admin-tournaments-server.R` (continue adding handlers)

**Step 1: Add show/hide add form and save new result handlers**

```r
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
```

**Step 2: Commit**

```bash
git add server/admin-tournaments-server.R
git commit -m "feat(admin): add new result handler in modal"
```

---

## Task 6: Update reset_tournament_form to Hide Button

**Files:**
- Modify: `server/admin-tournaments-server.R:234-244`

**Step 1: Add hide call to reset function**

Update the `reset_tournament_form` function to also hide the View/Edit Results button:

```r
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
```

**Step 2: Commit**

```bash
git add server/admin-tournaments-server.R
git commit -m "fix(admin): hide results button when form is reset"
```

---

## Task 7: Initialize modal_results_refresh in rv

**Files:**
- Modify: `app.R` (find rv initialization, around line 484-490)

**Step 1: Add modal_results_refresh to reactive values**

Find the `rv <- reactiveValues(...)` initialization and add:

```r
    modal_results_refresh = 0,  # Trigger to refresh results modal table
    modal_tournament_id = NULL,  # Tournament ID for results modal
```

**Step 2: Commit**

```bash
git add app.R
git commit -m "feat(admin): add reactive values for results modal"
```

---

## Task 8: Update Duplicate Tournament Flow

**Files:**
- Modify: `server/results-server.R:220-226`

**Step 1: Change edit_existing_tournament handler to navigate to Edit Tournaments**

Replace the current handler:

```r
# Handle "View/Edit Existing" button from duplicate modal
observeEvent(input$edit_existing_tournament, {
  req(rv$duplicate_tournament)
  shinyjs::runjs("$('#duplicate_tournament_modal').modal('hide');")

  # Store the tournament ID so Edit Tournaments can select it
  rv$navigate_to_tournament_id <- rv$duplicate_tournament$tournament_id

  # Navigate to Edit Tournaments tab
  nav_select("main_tabs", "admin_tournaments")

  # Update sidebar highlight
  shinyjs::runjs("
    $('.nav-link').removeClass('active');
    $('#nav_admin_tournaments').addClass('active');
  ")
})
```

**Step 2: Add observer to auto-select tournament when navigating**

In `server/admin-tournaments-server.R`, add at the top:

```r
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
```

**Step 3: Add navigate_to_tournament_id to rv in app.R**

Add to rv initialization:

```r
    navigate_to_tournament_id = NULL,  # For duplicate flow navigation
```

**Step 4: Commit**

```bash
git add server/results-server.R server/admin-tournaments-server.R app.R
git commit -m "feat(admin): update duplicate flow to navigate to Edit Tournaments"
```

---

## Task 9: Blank Date Field with Required Validation

**Files:**
- Modify: `views/admin-results-ui.R:37`
- Modify: `server/results-server.R` (validation in create_tournament)

**Step 1: Change date default to NA**

In `views/admin-results-ui.R`, change line 37 from:

```r
                dateInput("tournament_date", "Date", value = Sys.Date()))
```

To:

```r
                dateInput("tournament_date", "Date *", value = NA))
```

**Step 2: Add CSS for required field styling**

In `www/custom.css`, add:

```css
/* Required date field styling */
.shiny-date-input.date-required input[type="text"]:placeholder-shown {
  border-color: #dc3545;
  background-color: rgba(220, 53, 69, 0.05);
}

.shiny-date-input.date-required input[type="text"]:placeholder-shown::placeholder {
  color: #dc3545;
}

.date-required-hint {
  color: #dc3545;
  font-size: 0.75rem;
  margin-top: 0.25rem;
}
```

**Step 3: Add required hint below date input**

In `views/admin-results-ui.R`, update the date input section:

```r
            div(class = "col-md-4",
                div(
                  class = "date-required",
                  dateInput("tournament_date", "Date *", value = NA),
                  div(id = "date_required_hint", class = "date-required-hint", "Required")
                ))
```

**Step 4: Add validation in create_tournament handler**

In `server/results-server.R`, find the `create_tournament` observeEvent and add date validation. After getting form values, add:

```r
  # Date validation
  if (is.null(input$tournament_date) || is.na(input$tournament_date)) {
    showNotification("Please select a tournament date", type = "error")
    return()
  }
```

**Step 5: Hide hint when date is selected**

Add observer in `server/results-server.R`:

```r
# Hide date required hint when date is selected
observeEvent(input$tournament_date, {
  if (!is.null(input$tournament_date) && !is.na(input$tournament_date)) {
    shinyjs::hide("date_required_hint")
    shinyjs::runjs("$('#tournament_date').closest('.date-required').removeClass('date-required');")
  } else {
    shinyjs::show("date_required_hint")
    shinyjs::runjs("$('#tournament_date').closest('.shiny-date-input').addClass('date-required');")
  }
}, ignoreNULL = FALSE)
```

**Step 6: Commit**

```bash
git add views/admin-results-ui.R server/results-server.R www/custom.css
git commit -m "feat(admin): require date selection in Enter Results"
```

---

## Task 10: Test Complete Flow

**Step 1: Test Edit Results modal**

1. Go to Edit Tournaments
2. Click a tournament with results
3. Verify "View/Edit Results" button appears
4. Click it - modal should open with results table
5. Click a result row - edit form should appear
6. Make a change and save - should update
7. Click "+ Add Result" - form should appear
8. Add a new result and save

**Step 2: Test duplicate flow**

1. Go to Enter Results
2. Enter details for an existing tournament (same store + date)
3. Click Create Tournament
4. Duplicate modal appears
5. Click "View/Edit Existing"
6. Should navigate to Edit Tournaments with tournament selected

**Step 3: Test date validation**

1. Go to Enter Results
2. Date field should be blank with red styling
3. Try to create tournament without date - should show error
4. Select a date - red styling should disappear
5. Should be able to create tournament

**Step 4: Commit final verification**

```bash
git add -A
git commit -m "test: verify admin UX improvements complete"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add View/Edit Results button | `views/admin-tournaments-ui.R` |
| 2 | Add results modal UI | `views/admin-tournaments-ui.R` |
| 3 | Add modal open/display handlers | `server/admin-tournaments-server.R` |
| 4 | Add edit/delete result handlers | `server/admin-tournaments-server.R` |
| 5 | Add new result handler | `server/admin-tournaments-server.R` |
| 6 | Update reset function | `server/admin-tournaments-server.R` |
| 7 | Add reactive values | `app.R` |
| 8 | Update duplicate flow | `server/results-server.R`, `server/admin-tournaments-server.R`, `app.R` |
| 9 | Blank date with validation | `views/admin-results-ui.R`, `server/results-server.R`, `www/custom.css` |
| 10 | Test complete flow | Manual testing |
