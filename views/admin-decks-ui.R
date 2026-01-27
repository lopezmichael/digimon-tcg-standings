# views/admin-decks-ui.R
# Admin - Manage deck archetypes UI

admin_decks_ui <- tagList(
  h2("Manage Deck Archetypes"),
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
          textInput("deck_name", "Archetype Name", placeholder = "e.g., Fenriloogamon"),
          selectInput("deck_primary_color", "Primary Color",
                      choices = c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
          selectInput("deck_secondary_color", "Secondary Color",
                      choices = c("None" = "", "Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
          hr(),
          h5("Display Card"),
          div(
            class = "d-flex gap-2 align-items-end mb-3",
            div(class = "flex-grow-1",
                textInput("card_search", "Search Card", placeholder = "Type card name...")),
            actionButton("search_card_btn", "Search", class = "btn-info mb-3")
          ),
          uiOutput("card_search_results"),
          textInput("selected_card_id", "Selected Card ID", placeholder = "e.g., BT17-042"),
          div(class = "small text-muted mb-2", "Click a card above to auto-fill, or enter ID manually"),
          uiOutput("selected_card_preview"),
          hr(),
          div(
            class = "d-flex gap-2",
            actionButton("add_archetype", "Add Archetype", class = "btn-primary"),
            actionButton("update_archetype", "Update Archetype", class = "btn-success", style = "display: none;")
          )
        )
      ),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          "Current Archetypes",
          span(class = "small text-muted", "Click a row to edit")
        ),
        card_body(
          reactableOutput("archetype_list")
        )
      )
    )
  )
)
