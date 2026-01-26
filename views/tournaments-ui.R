# views/tournaments-ui.R
# Tournaments history tab UI

tournaments_ui <- tagList(
  h2("Tournament History"),
  card(
    card_header("All Tournaments"),
    card_body(
      reactableOutput("tournament_history")
    )
  )
)
