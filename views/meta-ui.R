# views/meta-ui.R
# Meta analysis tab UI

meta_ui <- tagList(
  h2("Deck Meta Analysis"),
  card(
    card_header("Archetype Performance"),
    card_body(
      reactableOutput("archetype_stats")
    )
  )
)
