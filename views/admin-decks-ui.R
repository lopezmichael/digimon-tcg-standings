# views/admin-decks-ui.R
# Admin - Manage deck archetypes UI

admin_decks_ui <- tagList(
  h2("Edit Deck Archetypes"),
  div(
    class = "admin-panel",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          span(id = "deck_form_title", "Add New Archetype"),
          conditionalPanel(
            condition = "input.editing_archetype_id && input.editing_archetype_id != ''",
            actionButton("cancel_edit_archetype", "Cancel Edit", class = "btn-sm btn-outline-secondary")
          )
        ),
        card_body(
          # Hidden field for edit mode
          textInput("editing_archetype_id", NULL, value = ""),
          tags$script("document.getElementById('editing_archetype_id').parentElement.style.display = 'none';"),

          # Identity section
          textInput("deck_name", "Archetype Name", placeholder = "e.g., Fenriloogamon"),
          selectInput("deck_primary_color", "Primary Color",
                      choices = c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
          selectInput("deck_secondary_color", "Secondary Color",
                      choices = c("None" = "", "Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
          checkboxInput("deck_multi_color", "Multi-color deck (3+ colors)", value = FALSE),

          hr(),

          # Display Card section
          h5("Display Card"),
          layout_columns(
            col_widths = c(4, 8),
            # Card preview on left
            div(
              class = "text-center",
              div(
                id = "card_preview_container",
                class = "rounded p-2",
                style = "min-height: 150px; max-height: 200px; display: flex; align-items: center; justify-content: center; overflow: hidden;",
                uiOutput("selected_card_preview")
              )
            ),
            # Search controls on right
            div(
              # Row 1: Search input + button (aligned with flexbox)
              div(
                class = "search-row-aligned",
                div(class = "search-input-wrapper", textInput("card_search", "Search", placeholder = "Type card name...")),
                div(class = "search-btn-wrapper",
                    actionButton("search_card_btn", bsicons::bs_icon("search"),
                                 class = "btn-card-search"))
              ),
              # Row 2: Card ID with inline info icon in label
              div(
                tags$label(
                  `for` = "selected_card_id",
                  class = "form-label d-flex align-items-center gap-1",
                  "Selected Card ID",
                  tags$span(
                    class = "text-muted",
                    title = "Click a card from search results to auto-fill, or enter a card ID manually",
                    style = "cursor: help;",
                    bsicons::bs_icon("info-circle", size = "0.9rem")
                  )
                ),
                textInput("selected_card_id", NULL, placeholder = "e.g., BT17-042")
              )
            )
          ),
          # Search results in dedicated box below - digital scanner container
          div(
            class = "card-search-results-container p-2 mt-2",
            style = "min-height: 60px;",
            tags$label(class = "form-label small text-muted", "Search Results"),
            uiOutput("card_search_results")
          ),

          hr(),

          # Action buttons
          div(
            class = "d-flex gap-2",
            actionButton("add_archetype", "Add Archetype", class = "btn-primary"),
            actionButton("update_archetype", "Update Archetype", class = "btn-success", style = "display: none;"),
            actionButton("delete_archetype", "Delete Archetype", class = "btn-danger", style = "display: none;")
          )
        )
      ),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          div(
            "Current Archetypes",
            div(class = "small text-muted", "Decks without cards shown first")
          ),
          span(class = "small text-muted", "Click a row to edit")
        ),
        card_body(
          reactableOutput("archetype_list")
        )
      )
    )
  ),

  # Delete confirmation modal
  tags$div(
    id = "delete_archetype_modal",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", "Confirm Delete"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          uiOutput("delete_archetype_message")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("confirm_delete_archetype", "Delete", class = "btn-danger")
        )
      )
    )
  )
)
