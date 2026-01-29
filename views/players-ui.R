# views/players-ui.R
# Players tab UI with player profiles

players_ui <- tagList(
  h2("Player Standings"),

  # Filters - Using layout_columns for responsive sizing
  div(
    class = "dashboard-filters mb-3",
    layout_columns(
      col_widths = c(4, 3, 3, 2),
      textInput("players_search", "Search Player", placeholder = "Type a name..."),
      selectInput("players_format", "Format",
                  choices = list("Loading..." = ""),
                  selected = ""),
      selectInput("players_min_events", "Min Events",
                  choices = c("Any" = 0, "2+" = 2, "3+" = 3, "5+" = 5, "10+" = 10),
                  selected = 0),
      div(
        style = "padding-top: 1.5rem;",
        actionButton("reset_players_filters", "Reset",
                     class = "btn-outline-secondary",
                     style = "height: 38px;")
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
