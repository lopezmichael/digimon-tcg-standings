# views/dashboard-ui.R
# Dashboard tab UI

dashboard_ui <- tagList(
  # Region filter indicator (shown when stores are filtered from map)
  uiOutput("region_filter_indicator"),

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
      title = "Deck Types",
      value = textOutput("total_decks_val", inline = TRUE),
      showcase = bsicons::bs_icon("stack"),
      theme = value_box_theme(bg = "#1565A8", fg = "#FFFFFF")
    ),
    value_box(
      title = "Most Popular Deck",
      value = textOutput("most_popular_deck_val", inline = TRUE),
      showcase = uiOutput("most_popular_deck_image"),
      showcase_layout = showcase_left_center(width = 0.4, max_height = "100px"),
      theme = value_box_theme(bg = "#2A7AB8", fg = "#FFFFFF")
    )
  ),

  # Dashboard filters
  div(
    class = "dashboard-filters mb-3",
    layout_columns(
      col_widths = c(4, 4, 4),
      selectInput("dashboard_format", "Format",
                  choices = list("Loading..." = ""),
                  selected = ""),  # Will be populated from database
      selectInput("dashboard_event_type", "Event Type",
                  choices = list(
                    "All Events" = "",
                    "Event Types" = EVENT_TYPES
                  ),
                  selected = "locals"),  # Default to Locals
      div(
        style = "margin-top: 1.5rem;",
        actionButton("reset_dashboard_filters", "Reset",
                     class = "btn-outline-secondary",
                     style = "height: 38px;")
      )
    )
  ),

  # Top Decks with card images (primary visual)
  card(
    card_header(uiOutput("top_decks_header", inline = TRUE)),
    card_body(
      class = "top-decks-container",
      uiOutput("top_decks_with_images")
    )
  ),

  # Charts row (secondary analytics)
  layout_columns(
    col_widths = c(4, 4, 4),
    card(
      card_header("Top 3 Conversion Rate"),
      card_body(
        class = "p-0",
        highchartOutput("conversion_rate_chart", height = "280px")
      )
    ),
    card(
      card_header("Color Distribution of Decks Played"),
      card_body(
        class = "p-0",
        highchartOutput("color_dist_chart", height = "280px")
      )
    ),
    card(
      card_header("Tournament Player Counts Over Time"),
      card_body(
        class = "p-0",
        highchartOutput("tournaments_trend_chart", height = "280px")
      )
    )
  ),

  # Tables row
  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("Recent Tournaments"),
      card_body(
        reactableOutput("recent_tournaments")
      )
    ),
    card(
      card_header(
        class = "d-flex align-items-center gap-2",
        "Top Players",
        tags$span(
          class = "rating-info-icon",
          title = "Rating combines three factors: how often you win matches (50%), how often you finish in the top 3 (30%), and how many events you attend (20%). Higher rating = stronger overall performance.",
          bsicons::bs_icon("info-circle", size = "0.9rem")
        )
      ),
      card_body(
        reactableOutput("top_players")
      )
    )
  ),
  card(
    card_header("Meta Share Over Time"),
    card_body(
      class = "p-0",
      highchartOutput("meta_share_timeline", height = "350px")
    )
  )
)
