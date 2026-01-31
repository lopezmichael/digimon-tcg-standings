# =============================================================================
# Admin: Deck Management Server Logic
# =============================================================================

# Card search
observeEvent(input$search_card_btn, {
  req(input$card_search)

  # Reset pagination
  rv$card_search_page <- 1

  # Show searching indicator
  output$card_search_results <- renderUI({
    div(class = "text-muted", bsicons::bs_icon("hourglass-split"), " Searching...")
  })

  cards <- tryCatch({
    search_cards_local(rv$db_con, input$card_search)
  }, error = function(e) {
    message("Card search error: ", e$message)
    NULL
  })

  if (is.null(cards) || nrow(cards) == 0) {
    output$card_search_results <- renderUI({
      div(class = "alert alert-warning", "No cards found for '", input$card_search, "'")
    })
    rv$card_search_results <- NULL
    return()
  }

  # Deduplicate by card ID (removes duplicate listings of same card)
  # Keep all different cards even if they share the same name (alternate arts)
  cards <- cards[!duplicated(cards$id), ]

  # Store ALL cards in reactive for pagination
  rv$card_search_results <- cards

  # Render first page
  render_card_search_page()
})

# Pagination handlers
observeEvent(input$card_search_prev, {
  if (rv$card_search_page > 1) {
    rv$card_search_page <- rv$card_search_page - 1
    render_card_search_page()
  }
})

observeEvent(input$card_search_next, {
  req(rv$card_search_results)
  total_pages <- ceiling(nrow(rv$card_search_results) / 8)
  if (rv$card_search_page < total_pages) {
    rv$card_search_page <- rv$card_search_page + 1
    render_card_search_page()
  }
})

# Helper function to render card search page
render_card_search_page <- function() {
  req(rv$card_search_results)
  cards <- rv$card_search_results
  page <- rv$card_search_page
  per_page <- 8

  total_cards <- nrow(cards)
  total_pages <- ceiling(total_cards / per_page)
  start_idx <- (page - 1) * per_page + 1
  end_idx <- min(page * per_page, total_cards)

  # Get cards for current page
  page_cards <- cards[start_idx:end_idx, ]

  output$card_search_results <- renderUI({
    div(
      # Header with count and pagination
      div(
        class = "d-flex justify-content-between align-items-center mb-2",
        p(class = "text-muted small mb-0", sprintf("Found %d cards (showing %d-%d):", total_cards, start_idx, end_idx)),
        if (total_pages > 1) {
          div(
            class = "d-flex align-items-center gap-1",
            actionButton("card_search_prev", bsicons::bs_icon("chevron-left"),
                         class = paste("btn-sm btn-outline-secondary", if (page == 1) "disabled" else ""),
                         style = "padding: 2px 6px;"),
            span(class = "small mx-1", sprintf("%d/%d", page, total_pages)),
            actionButton("card_search_next", bsicons::bs_icon("chevron-right"),
                         class = paste("btn-sm btn-outline-secondary", if (page == total_pages) "disabled" else ""),
                         style = "padding: 2px 6px;")
          )
        }
      ),
      # Card grid
      div(
        style = "display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; margin-top: 10px;",
        lapply(1:nrow(page_cards), function(i) {
          card_data <- page_cards[i, ]
          # Calculate absolute index for button ID
          abs_idx <- start_idx + i - 1
          # API returns card number in 'id' field, not 'cardnumber'
          card_num <- if ("id" %in% names(card_data)) card_data$id else card_data$cardnumber
          card_name <- if ("name" %in% names(card_data)) card_data$name else "Unknown"
          card_color <- if ("color" %in% names(card_data) && !is.na(card_data$color)) card_data$color else ""

          # Use .webp format - server returns WebP regardless of extension
          img_url <- paste0("https://images.digimoncard.io/images/cards/", card_num, ".webp")

          actionButton(
            inputId = paste0("card_select_", abs_idx),
            label = tagList(
              tags$img(src = img_url,
                       style = "width: 100%; max-width: 80px; height: auto; border-radius: 4px; display: block; margin: 0 auto;",
                       onerror = "this.style.display='none'; this.nextElementSibling.style.display='block';"),
              tags$div(style = "display: none; height: 60px; background: #eee; border-radius: 4px; line-height: 60px; text-align: center; font-size: 10px;", "No image"),
              tags$div(style = "font-weight: bold; font-size: 11px; margin-top: 4px; color: #0F4C81;", card_num),
              tags$div(style = "font-size: 9px; color: #666; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;",
                       title = card_name, substr(card_name, 1, 15)),
              if (nchar(card_color) > 0) tags$div(style = "font-size: 8px; color: #999;", card_color)
            ),
            class = "card-search-btn p-2",
            style = "background: #f8f9fa; border: 2px solid #ddd; border-radius: 6px; width: 100%; text-align: center;"
          )
        })
      )
    )
  })
}

# Handle card selection buttons (1-100 to support pagination)
lapply(1:100, function(i) {
  observeEvent(input[[paste0("card_select_", i)]], {
    req(rv$card_search_results)
    if (i <= nrow(rv$card_search_results)) {
      # API returns card number in 'id' field
      card_num <- if ("id" %in% names(rv$card_search_results)) {
        rv$card_search_results$id[i]
      } else {
        rv$card_search_results$cardnumber[i]
      }
      updateTextInput(session, "selected_card_id", value = card_num)
      showNotification(paste("Selected:", card_num), type = "message", duration = 2)
    }
  }, ignoreInit = TRUE)
})

# Preview selected card
output$selected_card_preview <- renderUI({
  card_id <- trimws(input$selected_card_id %||% "")

  # Show placeholder if no card selected
  if (nchar(card_id) < 3) {
    return(div(
      class = "text-muted",
      style = "font-size: 0.85rem;",
      bsicons::bs_icon("image", size = "2rem"),
      div(class = "mt-2", "No card selected")
    ))
  }

  # Construct image URL directly using the card ID (.webp format)
  img_url <- paste0("https://images.digimoncard.io/images/cards/", card_id, ".webp")

  div(
    class = "text-center",
    tags$img(src = img_url, style = "max-width: 120px; border-radius: 6px;",
             onerror = "this.onerror=null; this.src=''; this.alt='Image not found'; this.style.height='60px'; this.style.background='#ddd';"),
    div(class = "mt-1 small text-muted", paste("Selected:", card_id))
  )
})

# Add archetype
observeEvent(input$add_archetype, {
  req(rv$is_admin, rv$db_con)

  name <- trimws(input$deck_name)
  primary_color <- input$deck_primary_color
  secondary_color <- if (input$deck_secondary_color == "") NA_character_ else input$deck_secondary_color
  card_id <- if (!is.null(input$selected_card_id) && nchar(input$selected_card_id) > 0) input$selected_card_id else NA_character_

  # Validation
  if (is.null(name) || nchar(name) == 0) {
    showNotification("Please enter an archetype name", type = "error")
    return()
  }

  if (nchar(name) < 2) {
    showNotification("Archetype name must be at least 2 characters", type = "error")
    return()
  }

  # Check for duplicate archetype name
  existing <- dbGetQuery(rv$db_con, "
    SELECT archetype_id FROM deck_archetypes
    WHERE LOWER(archetype_name) = LOWER(?)
  ", params = list(name))

  if (nrow(existing) > 0) {
    showNotification(
      sprintf("Archetype '%s' already exists", name),
      type = "error"
    )
    return()
  }

  # Validate card ID format if provided
  if (!is.null(card_id) && nchar(card_id) > 0) {
    if (!grepl("^[A-Z0-9]+-[0-9]+$", card_id)) {
      showNotification(
        "Card ID format should be like BT17-042 or EX6-001",
        type = "warning"
      )
    }
  }

  tryCatch({
    max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(archetype_id), 0) as max_id FROM deck_archetypes")$max_id
    new_id <- max_id + 1

    dbExecute(rv$db_con, "
      INSERT INTO deck_archetypes (archetype_id, archetype_name, display_card_id, primary_color, secondary_color, is_multi_color)
      VALUES (?, ?, ?, ?, ?, ?)
    ", params = list(new_id, name, card_id, primary_color, secondary_color, isTRUE(input$deck_multi_color)))

    showNotification(paste("Added archetype:", name), type = "message")

    # Clear form
    updateTextInput(session, "deck_name", value = "")
    updateSelectInput(session, "deck_primary_color", selected = "Red")
    updateSelectInput(session, "deck_secondary_color", selected = "")
    updateTextInput(session, "selected_card_id", value = "")
    updateTextInput(session, "card_search", value = "")
    updateCheckboxInput(session, "deck_multi_color", value = FALSE)
    output$card_search_results <- renderUI({ NULL })

    # Update archetype dropdown
    updateSelectizeInput(session, "result_deck", choices = get_archetype_choices(rv$db_con))

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Archetype list
output$archetype_list <- renderReactable({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  # Trigger refresh when archetype added/updated/deleted
  input$add_archetype
  input$update_archetype
  input$confirm_delete_archetype

  # Sort by Card ID with NULLs first (decks needing review), then alphabetically
  data <- dbGetQuery(rv$db_con, "
    SELECT archetype_id, archetype_name as Deck, primary_color, secondary_color, is_multi_color, display_card_id as 'Card ID'
    FROM deck_archetypes
    WHERE is_active = TRUE
    ORDER BY
      CASE WHEN display_card_id IS NULL OR display_card_id = '' THEN 0 ELSE 1 END,
      display_card_id,
      archetype_name
  ")
  if (nrow(data) == 0) {
    return(reactable(data.frame(Message = "No archetypes yet"), compact = TRUE))
  }
  reactable(data, compact = TRUE, striped = TRUE,
    selection = "single",
    onClick = "select",
    rowStyle = function(index) {
      # Highlight rows without Card ID
      if (is.na(data$`Card ID`[index]) || data$`Card ID`[index] == "") {
        list(cursor = "pointer", backgroundColor = "rgba(247, 148, 29, 0.1)")
      } else {
        list(cursor = "pointer")
      }
    },
    defaultPageSize = 20,
    showPageSizeOptions = TRUE,
    pageSizeOptions = c(10, 20, 50, 100),
    columns = list(
      archetype_id = colDef(show = FALSE),
      Deck = colDef(minWidth = 120),
      primary_color = colDef(
        name = "Color",
        cell = function(value, index) {
          if (isTRUE(data$is_multi_color[index])) {
            span(class = "badge", style = "background-color: #E91E8C; color: white;", "Multi")
          } else {
            secondary <- data$secondary_color[index]
            deck_color_badge_dual(value, secondary)
          }
        }
      ),
      secondary_color = colDef(show = FALSE),
      is_multi_color = colDef(show = FALSE),
      `Card ID` = colDef(
        cell = function(value) {
          if (is.na(value) || value == "") {
            span(class = "badge bg-warning text-dark", "Needs Card")
          } else {
            span(value)
          }
        }
      )
    )
  )
})

# Handle archetype selection for editing
observeEvent(input$archetype_list__reactable__selected, {
  req(rv$db_con)
  selected_idx <- input$archetype_list__reactable__selected

  if (is.null(selected_idx) || length(selected_idx) == 0) {
    return()
  }

  # Get archetype data (must use same order as archetype_list render)
  data <- dbGetQuery(rv$db_con, "
    SELECT archetype_id, archetype_name, primary_color, secondary_color, display_card_id, is_multi_color
    FROM deck_archetypes
    WHERE is_active = TRUE
    ORDER BY
      CASE WHEN display_card_id IS NULL OR display_card_id = '' THEN 0 ELSE 1 END,
      display_card_id,
      archetype_name
  ")

  if (selected_idx > nrow(data)) return()

  arch <- data[selected_idx, ]

  # Populate form for editing
  updateTextInput(session, "editing_archetype_id", value = as.character(arch$archetype_id))
  updateTextInput(session, "deck_name", value = arch$archetype_name)
  updateSelectInput(session, "deck_primary_color", selected = arch$primary_color)
  updateSelectInput(session, "deck_secondary_color",
                    selected = if (is.na(arch$secondary_color)) "" else arch$secondary_color)
  updateTextInput(session, "selected_card_id",
                  value = if (is.na(arch$display_card_id)) "" else arch$display_card_id)
  updateCheckboxInput(session, "deck_multi_color", value = isTRUE(arch$is_multi_color))

  # Show/hide buttons
  shinyjs::hide("add_archetype")
  shinyjs::show("update_archetype")
  shinyjs::show("delete_archetype")

  showNotification(sprintf("Editing: %s", arch$archetype_name), type = "message", duration = 2)
})

# Update archetype
observeEvent(input$update_archetype, {
  req(rv$is_admin, rv$db_con)
  req(input$editing_archetype_id)

  archetype_id <- as.integer(input$editing_archetype_id)
  name <- trimws(input$deck_name)
  primary_color <- input$deck_primary_color
  secondary_color <- if (input$deck_secondary_color == "") NA_character_ else input$deck_secondary_color
  card_id <- if (!is.null(input$selected_card_id) && nchar(input$selected_card_id) > 0) input$selected_card_id else NA_character_

  if (is.null(name) || nchar(name) == 0) {
    showNotification("Please enter an archetype name", type = "error")
    return()
  }

  # Debug logging
  message(sprintf("UPDATE archetype: id=%d, name=%s, color=%s", archetype_id, name, primary_color))

  tryCatch({
    dbExecute(rv$db_con, "
      UPDATE deck_archetypes
      SET archetype_name = ?, primary_color = ?, secondary_color = ?, display_card_id = ?, is_multi_color = ?, updated_at = CURRENT_TIMESTAMP
      WHERE archetype_id = ?
    ", params = list(name, primary_color, secondary_color, card_id, isTRUE(input$deck_multi_color), archetype_id))

    showNotification(sprintf("Updated archetype: %s", name), type = "message")

    # Clear form and reset to add mode
    updateTextInput(session, "editing_archetype_id", value = "")
    updateTextInput(session, "deck_name", value = "")
    updateSelectInput(session, "deck_primary_color", selected = "Red")
    updateSelectInput(session, "deck_secondary_color", selected = "")
    updateTextInput(session, "selected_card_id", value = "")
    updateTextInput(session, "card_search", value = "")
    updateCheckboxInput(session, "deck_multi_color", value = FALSE)
    output$card_search_results <- renderUI({ NULL })

    shinyjs::show("add_archetype")
    shinyjs::hide("update_archetype")
    shinyjs::hide("delete_archetype")

    # Update dropdown
    updateSelectizeInput(session, "result_deck", choices = get_archetype_choices(rv$db_con))

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Cancel edit archetype
observeEvent(input$cancel_edit_archetype, {
  updateTextInput(session, "editing_archetype_id", value = "")
  updateTextInput(session, "deck_name", value = "")
  updateSelectInput(session, "deck_primary_color", selected = "Red")
  updateSelectInput(session, "deck_secondary_color", selected = "")
  updateTextInput(session, "selected_card_id", value = "")
  updateTextInput(session, "card_search", value = "")
  updateCheckboxInput(session, "deck_multi_color", value = FALSE)
  output$card_search_results <- renderUI({ NULL })

  shinyjs::show("add_archetype")
  shinyjs::hide("update_archetype")
  shinyjs::hide("delete_archetype")
})

# Check if archetype can be deleted (no related results)
observe({
  req(input$editing_archetype_id, rv$db_con)
  archetype_id <- as.integer(input$editing_archetype_id)

  count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM results WHERE archetype_id = ?
  ", params = list(archetype_id))$cnt

  rv$archetype_result_count <- count
  rv$can_delete_archetype <- count == 0
})

# Delete button click - show modal
observeEvent(input$delete_archetype, {
  req(rv$is_admin, input$editing_archetype_id)

  archetype_id <- as.integer(input$editing_archetype_id)
  arch <- dbGetQuery(rv$db_con, "SELECT archetype_name FROM deck_archetypes WHERE archetype_id = ?",
                     params = list(archetype_id))

  if (rv$can_delete_archetype) {
    output$delete_archetype_message <- renderUI({
      div(
        p(sprintf("Are you sure you want to delete '%s'?", arch$archetype_name)),
        p(class = "text-danger", "This action cannot be undone.")
      )
    })
    shinyjs::runjs("$('#delete_archetype_modal').modal('show');")
  } else {
    showNotification(
      sprintf("Cannot delete: used in %d result(s)", rv$archetype_result_count),
      type = "error"
    )
  }
})

# Confirm delete
observeEvent(input$confirm_delete_archetype, {
  req(rv$is_admin, rv$db_con, input$editing_archetype_id)
  archetype_id <- as.integer(input$editing_archetype_id)

  # Debug logging
  message(sprintf("DELETE archetype triggered: id=%d", archetype_id))

  # Re-check for referential integrity before delete
  count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM results WHERE archetype_id = ?
  ", params = list(archetype_id))$cnt

  if (count > 0) {
    shinyjs::runjs("$('#delete_archetype_modal').modal('hide');")
    showNotification(sprintf("Cannot delete: used in %d result(s)", count), type = "error")
    return()
  }

  tryCatch({
    message(sprintf("Executing DELETE for archetype_id=%d", archetype_id))
    dbExecute(rv$db_con, "DELETE FROM deck_archetypes WHERE archetype_id = ?",
              params = list(archetype_id))
    showNotification("Archetype deleted", type = "message")

    # Hide modal and reset form
    shinyjs::runjs("$('#delete_archetype_modal').modal('hide');")

    # Clear form
    updateTextInput(session, "editing_archetype_id", value = "")
    updateTextInput(session, "deck_name", value = "")
    updateSelectInput(session, "deck_primary_color", selected = "Red")
    updateSelectInput(session, "deck_secondary_color", selected = "")
    updateTextInput(session, "selected_card_id", value = "")
    updateTextInput(session, "card_search", value = "")
    updateCheckboxInput(session, "deck_multi_color", value = FALSE)
    output$card_search_results <- renderUI({ NULL })

    shinyjs::show("add_archetype")
    shinyjs::hide("update_archetype")
    shinyjs::hide("delete_archetype")

    # Update archetype dropdown
    updateSelectizeInput(session, "result_deck", choices = get_archetype_choices(rv$db_con))

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})
