# views/dashboard-ui.R
# Dashboard tab UI

dashboard_ui <- tagList(
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
      col_widths = breakpoints(
        sm = c(12, 12, 12, 12),
        md = c(6, 6, 6, 6),
        lg = c(3, 3, 3, 3)
      ),
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
      # Box 3: Hot Deck (trending with card image)
      div(
        class = "value-box-digital vb-hotdeck",
        div(class = "vb-digital-grid"),
        div(
          class = "vb-content-with-image",
          div(
            class = "vb-image-showcase",
            uiOutput("hot_deck_image")
          ),
          div(
            class = "vb-content",
            div(class = "vb-label",
                bsicons::bs_icon("fire", class = "vb-label-icon"),
                "HOT DECK"),
            div(class = "vb-value vb-value-deck", uiOutput("hot_deck_name", inline = TRUE)),
            div(class = "vb-subtitle", uiOutput("hot_deck_trend", inline = TRUE))
          )
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
            div(class = "vb-label",
                bsicons::bs_icon("trophy", class = "vb-label-icon"),
                "TOP DECK"),
            div(class = "vb-value vb-value-deck", textOutput("most_popular_deck_val", inline = TRUE)),
            div(class = "vb-subtitle", uiOutput("top_deck_meta_share", inline = TRUE))
          )
        )
      )
    )
  ),

  # Top Decks with card images (primary visual)
  card(
    card_header(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("collection", class = "text-primary"),
      uiOutput("top_decks_header", inline = TRUE)
    ),
    card_body(
      class = "top-decks-container",
      uiOutput("top_decks_with_images")
    )
  ),

  # Spacer
  div(class = "mb-3"),

  # Scene Health row: Meta Diversity + Conversion + Color Distribution
  layout_columns(
    col_widths = breakpoints(
      sm = c(12, 12),
      md = c(4, 8)
    ),
    # Meta Diversity gauge card
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        div(
          class = "d-flex align-items-center gap-2",
          bsicons::bs_icon("pie-chart", class = "text-info"),
          "Meta Diversity"
        ),
        uiOutput("meta_diversity_decks_count", inline = TRUE)
      ),
      card_body(
        class = "p-2 d-flex flex-column",
        div(
          class = "flex-grow-1",
          highchartOutput("meta_diversity_gauge", height = "220px")
        ),
        div(
          class = "info-hint-box text-center",
          bsicons::bs_icon("info-circle", class = "info-hint-icon"),
          "How evenly distributed tournament wins are across different decks. Higher = healthier meta."
        )
      )
    ),
    # Charts column: Conversion + Color Distribution (2-column)
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header(
          class = "d-flex align-items-center gap-2",
          bsicons::bs_icon("bullseye", class = "text-warning"),
          "Top 3 Conversion"
        ),
        card_body(
          class = "p-0",
          highchartOutput("conversion_rate_chart", height = "280px")
        )
      ),
      card(
        card_header(
          class = "d-flex align-items-center gap-2",
          bsicons::bs_icon("palette", class = "text-info"),
          "Color Distribution"
        ),
        card_body(
          class = "p-0",
          highchartOutput("color_dist_chart", height = "280px")
        )
      )
    )
  ),

  # Spacer
  div(class = "mb-3"),

  # Meta Share Over Time
  card(
    card_header(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("bar-chart-line", class = "text-info"),
      "Meta Share Over Time"
    ),
    card_body(
      class = "p-0",
      highchartOutput("meta_share_timeline", height = "350px")
    )
  ),

  # Section divider
  div(class = "dashboard-section-divider",
    div(class = "divider-line"),
    span(class = "divider-label", "Community"),
    div(class = "divider-line")
  ),

  # Rising Stars section
  card(
    card_header(
      class = "d-flex justify-content-between align-items-center",
      div(
        class = "d-flex align-items-center gap-2",
        bsicons::bs_icon("graph-up-arrow", class = "text-success"),
        "Rising Stars"
      ),
      tags$span(class = "text-muted small", "Top finishes (last 30 days)")
    ),
    card_body(
      class = "rising-stars-section",
      uiOutput("rising_stars_cards")
    )
  ),

  # Spacer
  div(class = "mb-3"),

  # Player Attendance chart (community - scene only)
  card(
    card_header(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("activity", class = "text-primary"),
      "Player Attendance"
    ),
    card_body(
      class = "p-0",
      highchartOutput("tournaments_trend_chart", height = "280px")
    )
  ),

  # Spacer
  div(class = "mb-3"),

  # Player Growth & Retention (community - scene only)
  card(
    card_header(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("people", class = "text-success"),
      "Player Growth & Retention"
    ),
    card_body(
      class = "p-2",
      highchartOutput("player_growth_chart", height = "200px")
    )
  ),

  # Spacer
  div(class = "mb-3"),

  # Tables row (community - scene only)
  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header(
        class = "d-flex align-items-center gap-2",
        bsicons::bs_icon("calendar-event", class = "text-primary"),
        "Recent Tournaments"
      ),
      card_body(
        reactableOutput("recent_tournaments")
      )
    ),
    card(
      card_header(
        class = "d-flex align-items-center gap-2",
        bsicons::bs_icon("person-badge", class = "text-success"),
        "Top Players",
        tags$span(
          class = "rating-info-icon",
          title = "Rating: Elo-style skill rating (1200-2000+) based on tournament placements and opponent strength. Achv: Achievement score based on placements, store diversity, and deck variety.",
          bsicons::bs_icon("info-circle", size = "0.9rem")
        )
      ),
      card_body(
        reactableOutput("top_players")
      )
    )
  )
)
