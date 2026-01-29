# views/meta-ui.R
# Meta analysis tab UI with deck profiles

meta_ui <- tagList(
  h2("Deck Meta Analysis"),

  # Filters - Using layout_columns for responsive sizing
  div(
    class = "dashboard-filters mb-3",
    layout_columns(
      col_widths = c(4, 3, 3, 2),
      textInput("meta_search", "Search Deck", placeholder = "Type a deck name..."),
      selectInput("meta_format", "Format",
                  choices = list("Loading..." = ""),
                  selected = ""),
      selectInput("meta_min_entries", "Min Entries",
                  choices = c("Any" = 0, "2+" = 2, "5+" = 5, "10+" = 10, "20+" = 20),
                  selected = 2),
      div(
        style = "padding-top: 1.5rem;",
        actionButton("reset_meta_filters", "Reset",
                     class = "btn-outline-secondary",
                     style = "height: 38px;")
      )
    )
  ),

  card(
    card_header(
      class = "d-flex justify-content-between align-items-center",
      "Archetype Performance",
      span(class = "small text-muted", "Click a row for deck profile")
    ),
    card_body(
      reactableOutput("archetype_stats")
    )
  ),

  # Deck detail modal (rendered dynamically)
  uiOutput("deck_detail_modal")
)
