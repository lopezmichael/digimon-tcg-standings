# views/dashboard-ui.R
# Dashboard tab UI

dashboard_ui <- tagList(
  # Region filter indicator (shown when stores are filtered from map)
  uiOutput("region_filter_indicator"),

  # Title strip with integrated filters
  div(
    class = "page-title-strip mb-2",
    div(
      class = "title-strip-content",
      # Left side: context display
      div(
        class = "title-strip-context",
        bsicons::bs_icon("grid-3x3-gap", class = "title-strip-icon"),
        tags$span(class = "title-strip-text", uiOutput("dashboard_context_text", inline = TRUE))
      ),
      # Right side: compact filters
      div(
        class = "title-strip-controls",
        div(
          class = "title-strip-select",
          selectInput("dashboard_format", NULL,
                      choices = list("All Formats" = ""),
                      selected = "",
                      width = "140px",
                      selectize = FALSE)
        ),
        div(
          class = "title-strip-select",
          selectInput("dashboard_event_type", NULL,
                      choices = list(
                        "All Events" = "",
                        "Event Types" = EVENT_TYPES
                      ),
                      selected = "locals",
                      width = "120px",
                      selectize = FALSE)
        ),
        actionButton("reset_dashboard_filters", NULL,
                     icon = icon("rotate-right"),
                     class = "btn-title-strip-reset",
                     title = "Reset filters")
      )
    )
  ),

  # Value boxes with digital Digimon aesthetic
  div(
    class = "overview-value-boxes mb-3",
    layout_columns(
      col_widths = c(3, 3, 3, 3),
      # Box 1: Tournaments (format-filtered)
      div(
        class = "value-box-digital vb-tournaments",
        div(class = "vb-digital-grid"),
        div(
          class = "vb-content",
          div(class = "vb-label", "TOURNAMENTS"),
          div(class = "vb-value", textOutput("total_tournaments_val", inline = TRUE)),
          div(class = "vb-subtitle", "this format")
        )
      ),
      # Box 2: Players (unique in format)
      div(
        class = "value-box-digital vb-players",
        div(class = "vb-digital-grid"),
        div(
          class = "vb-content",
          div(class = "vb-label", "PLAYERS"),
          div(class = "vb-value", textOutput("total_players_val", inline = TRUE)),
          div(class = "vb-subtitle", "unique")
        )
      ),
      # Box 3: Hot Deck (trending)
      div(
        class = "value-box-digital vb-hotdeck",
        div(class = "vb-digital-grid"),
        div(
          class = "vb-content",
          div(class = "vb-label",
              bsicons::bs_icon("fire", class = "vb-label-icon"),
              "HOT DECK"),
          div(class = "vb-value", uiOutput("hot_deck_name", inline = TRUE)),
          div(class = "vb-subtitle", uiOutput("hot_deck_trend", inline = TRUE))
        )
      ),
      # Box 4: Top Deck (most popular with card image)
      div(
        class = "value-box-digital vb-topdeck",
        div(class = "vb-digital-grid"),
        div(
          class = "vb-content-with-image",
          div(
            class = "vb-image-showcase",
            uiOutput("top_deck_image")
          ),
          div(
            class = "vb-content",
            div(class = "vb-label", "TOP DECK"),
            div(class = "vb-value vb-value-deck", textOutput("most_popular_deck_val", inline = TRUE)),
            div(class = "vb-subtitle", uiOutput("top_deck_meta_share", inline = TRUE))
          )
        )
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
