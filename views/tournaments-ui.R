# views/tournaments-ui.R
# Tournaments history tab UI with filters and detail modal

tournaments_ui <- tagList(
  h2("Tournament History"),

  # Filters - Using layout_columns for responsive sizing
  div(
    class = "dashboard-filters mb-3",
    layout_columns(
      col_widths = c(4, 3, 3, 2),
      textInput("tournaments_search", "Search Store", placeholder = "Type a store name..."),
      selectInput("tournaments_format", "Format",
                  choices = list("Loading..." = ""),
                  selected = ""),
      selectInput("tournaments_event_type", "Event Type",
                  choices = list(
                    "All Events" = "",
                    "Event Types" = EVENT_TYPES
                  ),
                  selected = ""),
      div(
        style = "padding-top: 1.8rem;",
        actionButton("reset_tournaments_filters", "Reset",
                     class = "btn-outline-secondary",
                     style = "height: 38px;")
      )
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
