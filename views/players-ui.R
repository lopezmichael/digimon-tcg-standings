# views/players-ui.R
# Players tab UI with player profiles

players_ui <- tagList(
  # Title strip with integrated filters
  div(
    class = "page-title-strip mb-3",
    div(
      class = "title-strip-content",
      # Left side: page title
      div(
        class = "title-strip-context",
        bsicons::bs_icon("people", class = "title-strip-icon"),
        tags$span(class = "title-strip-text", "Player Standings")
      ),
      # Right side: compact filters
      div(
        class = "title-strip-controls",
        div(
          class = "title-strip-search",
          textInput("players_search", NULL, placeholder = "Search...", width = "120px")
        ),
        div(
          class = "title-strip-select",
          selectInput("players_format", NULL,
                      choices = list("Loading..." = ""),
                      selected = "",
                      width = "120px")
        ),
        div(
          class = "title-strip-select",
          selectInput("players_min_events", NULL,
                      choices = c("Any" = 0, "2+" = 2, "3+" = 3, "5+" = 5, "10+" = 10),
                      selected = 0,
                      width = "80px")
        ),
        actionButton("reset_players_filters", NULL,
                     icon = icon("rotate-right"),
                     class = "btn-title-strip-reset",
                     title = "Reset filters")
      )
    )
  ),

  card(
    card_header(
      class = "d-flex justify-content-between align-items-center",
      "Player Leaderboard",
      span(class = "small text-muted", "Click a row for player profile")
    ),
    card_body(
      reactableOutput("player_standings")
    )
  ),

  # Player detail modal (rendered dynamically)
  uiOutput("player_detail_modal")
)
