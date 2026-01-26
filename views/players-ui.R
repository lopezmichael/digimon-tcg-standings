# views/players-ui.R
# Players tab UI

players_ui <- tagList(
  h2("Player Standings"),
  card(
    card_header("Player Leaderboard"),
    card_body(
      reactableOutput("player_standings")
    )
  )
)
