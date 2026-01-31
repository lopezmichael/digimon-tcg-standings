# views/tournaments-ui.R
# Tournaments history tab UI with filters and detail modal

tournaments_ui <- tagList(
  # Title strip with integrated filters
  div(
    class = "page-title-strip mb-3",
    div(
      class = "title-strip-content",
      # Left side: page title
      div(
        class = "title-strip-context",
        bsicons::bs_icon("trophy", class = "title-strip-icon"),
        tags$span(class = "title-strip-text", "Tournament History")
      ),
      # Right side: compact filters
      div(
        class = "title-strip-controls",
        div(
          class = "title-strip-search",
          textInput("tournaments_search", NULL, placeholder = "Search...", width = "120px")
        ),
        div(
          class = "title-strip-select",
          selectInput("tournaments_format", NULL,
                      choices = list("Loading..." = ""),
                      selected = "",
                      width = "120px")
        ),
        div(
          class = "title-strip-select",
          selectInput("tournaments_event_type", NULL,
                      choices = list(
                        "All Events" = "",
                        "Event Types" = EVENT_TYPES
                      ),
                      selected = "",
                      width = "100px")
        ),
        actionButton("reset_tournaments_filters", NULL,
                     icon = icon("rotate-right"),
                     class = "btn-title-strip-reset",
                     title = "Reset filters")
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
