# views/admin-decks-ui.R
# Admin - Manage deck archetypes UI

admin_decks_ui <- tagList(
  h2("Manage Deck Archetypes"),
  div(
    class = "admin-panel",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Add New Archetype"),
        card_body(
          textInput("deck_name", "Archetype Name", placeholder = "e.g., Fenriloogamon"),
          layout_columns(
            col_widths = c(6, 6),
            selectInput("deck_primary_color", "Primary Color",
                        choices = c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
            selectInput("deck_secondary_color", "Secondary Color",
                        choices = c("None" = "", "Red", "Blue", "Yellow", "Green", "Purple", "Black", "White"))
          ),
          hr(),
          h5("Display Card"),
          textInput("card_search", "Search Card", placeholder = "Type card name..."),
          actionButton("search_card_btn", "Search", class = "btn-info"),
          uiOutput("card_search_results"),
          hr(),
          textInput("selected_card_id", "Selected Card ID", placeholder = "e.g., BT17-042"),
          uiOutput("selected_card_preview"),
          hr(),
          actionButton("add_archetype", "Add Archetype", class = "btn-primary")
        )
      ),
      card(
        card_header("Current Archetypes"),
        card_body(
          reactableOutput("archetype_list")
        )
      )
    )
  )
)
