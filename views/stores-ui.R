# views/stores-ui.R
# Stores tab UI with interactive map and draw-to-filter

stores_ui <- tagList(
  h2("DFW Store Directory"),

  # Filter active indicator
  uiOutput("stores_filter_active_banner"),

  layout_columns(
    col_widths = c(12),
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center flex-wrap gap-2",
        div(
          class = "d-flex align-items-center gap-2",
          bsicons::bs_icon("geo-alt-fill"),
          span("Store Map"),
          span(class = "small text-muted", "(larger bubbles = more events)")
        ),
        div(
          class = "d-flex align-items-center gap-2",
          actionButton("apply_region_filter",
                       tagList(bsicons::bs_icon("funnel"), " Apply Filter"),
                       class = "btn-sm btn-primary"),
          actionButton("clear_region",
                       tagList(bsicons::bs_icon("x-circle"), " Clear"),
                       class = "btn-sm btn-outline-secondary"),
          span(class = "small text-muted d-none d-md-inline", "Draw a region, then click Apply")
        )
      ),
      card_body(
        style = "padding: 0;",
        mapboxglOutput("stores_map", height = "400px")
      )
    )
  ),
  card(
    card_header(
      class = "d-flex justify-content-between align-items-center",
      span("Store List"),
      div(
        class = "d-flex align-items-center gap-2",
        span(class = "small text-muted", "Click a row for details"),
        uiOutput("stores_filter_badge")
      )
    ),
    card_body(
      reactableOutput("store_list")
    )
  ),

  # Store detail modal (rendered dynamically)
  uiOutput("store_detail_modal")
)
