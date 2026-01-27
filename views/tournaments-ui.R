# views/tournaments-ui.R
# Tournaments history tab UI with filters and detail modal

tournaments_ui <- tagList(
  h2("Tournament History"),

  # Filters
  div(
    class = "dashboard-filters mb-3",
    # Row 1: Search
    div(
      class = "mb-2",
      div(
        style = "max-width: 300px;",
        textInput("tournaments_search", "Search Store", placeholder = "Type a store name...")
      )
    ),
    # Row 2: Format, Event Type, Reset
    div(
      class = "d-flex align-items-end gap-3",
      div(selectInput("tournaments_format", "Format",
                      choices = list(
                        "All Formats" = "",
                        "Recent Formats" = FORMAT_CHOICES
                      ),
                      selected = "", width = "150px")),
      div(selectInput("tournaments_event_type", "Event Type",
                      choices = list(
                        "All Events" = "",
                        "Event Types" = EVENT_TYPES
                      ),
                      selected = "", width = "150px")),
      actionButton("reset_tournaments_filters", "Reset",
                   class = "btn-outline-secondary btn-sm")
    )
  ),

  card(
    card_header(
      class = "d-flex justify-content-between align-items-center",
      "All Tournaments",
      span(class = "small text-muted", "Click a row for full results")
    ),
    card_body(
      reactableOutput("tournament_history")
    )
  ),

  # Tournament detail modal (rendered dynamically)
  uiOutput("tournament_detail_modal")
)
