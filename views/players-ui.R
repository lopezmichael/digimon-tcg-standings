# views/players-ui.R
# Players tab UI with player profiles

players_ui <- tagList(
  h2("Player Standings"),

  # Filters
  div(
    class = "dashboard-filters mb-3",
    # Row 1: Search
    div(
      class = "mb-2",
      div(
        style = "max-width: 300px;",
        textInput("players_search", "Search Player", placeholder = "Type a name...")
      )
    ),
    # Row 2: Format, Min Events, Reset
    div(
      class = "d-flex align-items-end gap-3",
      div(selectInput("players_format", "Format",
                      choices = list("Loading..." = ""),
                      selected = "", width = "150px")),
      div(selectInput("players_min_events", "Min Events",
                      choices = c("Any" = 0, "2+" = 2, "3+" = 3, "5+" = 5, "10+" = 10),
                      selected = 0, width = "120px")),
      actionButton("reset_players_filters", "Reset",
                   class = "btn-outline-secondary",
                   style = "height: 38px;")
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
