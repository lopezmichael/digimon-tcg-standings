# views/stores-ui.R
# Stores tab UI

stores_ui <- tagList(
  h2("DFW Store Directory"),
  card(
    card_header("Store List"),
    card_body(
      reactableOutput("store_list")
    )
  )
)
