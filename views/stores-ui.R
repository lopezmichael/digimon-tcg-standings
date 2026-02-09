# views/stores-ui.R
# Stores tab UI with interactive map and draw-to-filter

stores_ui <- tagList(
  # Title strip with integrated controls
  div(
    class = "page-title-strip mb-3",
    div(
      class = "title-strip-content",
      # Left side: page title
      div(
        class = "title-strip-context",
        bsicons::bs_icon("geo-alt-fill", class = "title-strip-icon"),
        tags$span(class = "title-strip-text", "Store Directory")
      ),
      # Right side: map controls
      div(
        class = "title-strip-controls",
        actionButton("apply_region_filter",
                     tagList(bsicons::bs_icon("funnel"), " Apply"),
                     class = "btn-sm btn-primary"),
        actionButton("clear_region",
                     tagList(bsicons::bs_icon("x-circle"), " Clear"),
                     class = "btn-sm btn-outline-secondary"),
        span(class = "small text-muted d-none d-md-inline", "Draw a region to filter")
      )
    )
  ),

  # Filter active indicator
  uiOutput("stores_filter_active_banner"),

  # Map card with digital scanner styling
  card(
    class = "card-map mb-3",
    card_header(
      class = "d-flex justify-content-between align-items-center",
      div(
        class = "d-flex align-items-center gap-2 map-circuit-node",
        bsicons::bs_icon("map"),
        span("Location Scanner"),
        span(class = "small text-muted", "(larger nodes = more events)")
      )
    ),
    card_body(
      class = "map-container-flush",
      mapboxglOutput("stores_map", height = "400px")
    )
  ),
  card(
    card_header(
      class = "d-flex justify-content-between align-items-center",
      # View toggle buttons
      div(
        class = "btn-group btn-group-sm",
        role = "group",
        `aria-label` = "Store view toggle",
        actionButton(
          "stores_view_schedule",
          tagList(bsicons::bs_icon("calendar-week"), " Schedule"),
          class = "btn-outline-primary active"
        ),
        actionButton(
          "stores_view_all",
          tagList(bsicons::bs_icon("list-ul"), " All Stores"),
          class = "btn-outline-primary"
        )
      ),
      div(
        class = "d-flex align-items-center gap-2",
        uiOutput("stores_view_hint"),
        uiOutput("stores_filter_badge")
      )
    ),
    card_body(
      # Schedule view (default)
      conditionalPanel(
        condition = "input.stores_view_mode != 'all'",
        id = "stores_schedule_view",
        uiOutput("stores_schedule_content")
      ),
      # All Stores view
      conditionalPanel(
        condition = "input.stores_view_mode == 'all'",
        id = "stores_all_view",
        reactableOutput("store_list")
      )
    )
  ),
  # Hidden input to track view mode
  tags$input(type = "hidden", id = "stores_view_mode", value = "schedule", class = "shiny-input-text"),

  # Store detail modal (rendered dynamically)
  uiOutput("store_detail_modal"),

  # Online store detail modal (rendered dynamically)
  uiOutput("online_store_detail_modal"),

  # Online Tournament Organizers section
  uiOutput("online_stores_section")
)
