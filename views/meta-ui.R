# views/meta-ui.R
# Meta analysis tab UI with deck profiles

meta_ui <- tagList(
  h2("Deck Meta Analysis"),

  # Filters
  div(
    class = "dashboard-filters mb-3",
    # Row 1: Search
    div(
      class = "mb-2",
      div(
        style = "max-width: 300px;",
        textInput("meta_search", "Search Deck", placeholder = "Type a deck name...")
      )
    ),
    # Row 2: Format, Min Entries, Reset
    div(
      class = "d-flex align-items-end gap-3",
      div(selectInput("meta_format", "Format",
                      choices = list(
                        "All Formats" = "",
                        "Recent Formats" = FORMAT_CHOICES
                      ),
                      selected = "", width = "150px")),
      div(selectInput("meta_min_entries", "Min Entries",
                      choices = c("Any" = 0, "2+" = 2, "5+" = 5, "10+" = 10, "20+" = 20),
                      selected = 2, width = "120px")),
      actionButton("reset_meta_filters", "Reset",
                   class = "btn-outline-secondary btn-sm")
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
