# views/dashboard-ui.R
# Dashboard tab UI

dashboard_ui <- tagList(
  layout_columns(
    col_widths = c(3, 3, 3, 3),
    value_box(
      title = "Tournaments",
      value = textOutput("total_tournaments_val", inline = TRUE),
      showcase = bsicons::bs_icon("trophy"),
      theme = value_box_theme(bg = "#0A3055", fg = "#FFFFFF")
    ),
    value_box(
      title = "Players",
      value = textOutput("total_players_val", inline = TRUE),
      showcase = bsicons::bs_icon("people"),
      theme = value_box_theme(bg = "#0F4C81", fg = "#FFFFFF")
    ),
    value_box(
      title = "Stores",
      value = textOutput("total_stores_val", inline = TRUE),
      showcase = bsicons::bs_icon("geo-alt"),
      theme = value_box_theme(bg = "#1565A8", fg = "#FFFFFF")
    ),
    value_box(
      title = "Deck Types",
      value = textOutput("total_decks_val", inline = TRUE),
      showcase = bsicons::bs_icon("stack"),
      theme = value_box_theme(bg = "#2A7AB8", fg = "#FFFFFF")
    )
  ),
  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("Recent Tournaments"),
      card_body(
        reactableOutput("recent_tournaments")
      )
    ),
    card(
      card_header("Top Players"),
      card_body(
        reactableOutput("top_players")
      )
    )
  ),
  card(
    card_header("Meta Breakdown"),
    card_body(
      reactableOutput("meta_summary")
    )
  )
)
