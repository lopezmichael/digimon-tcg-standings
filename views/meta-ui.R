# views/meta-ui.R
# Meta analysis tab UI with deck profiles

meta_ui <- tagList(
  # Title strip with integrated filters
  div(
    class = "page-title-strip mb-3",
    div(
      class = "title-strip-content",
      # Left side: page title
      div(
        class = "title-strip-context",
        bsicons::bs_icon("stack", class = "title-strip-icon"),
        tags$span(class = "title-strip-text", "Deck Meta Analysis")
      ),
      # Right side: compact filters
      div(
        class = "title-strip-controls",
        div(
          class = "title-strip-search",
          textInput("meta_search", NULL, placeholder = "Search...", width = "120px")
        ),
        div(
          class = "title-strip-select",
          selectInput("meta_format", NULL,
                      choices = list("Loading..." = ""),
                      selected = "",
                      width = "120px")
        ),
        div(
          class = "title-strip-select",
          selectInput("meta_min_entries", NULL,
                      choices = c("Any" = 0, "2+" = 2, "5+" = 5, "10+" = 10, "20+" = 20),
                      selected = 0,
                      width = "80px")
        ),
        actionButton("reset_meta_filters", NULL,
                     icon = icon("rotate-right"),
                     class = "btn-title-strip-reset",
                     title = "Reset filters")
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
