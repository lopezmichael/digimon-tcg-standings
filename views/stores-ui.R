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
        class = "d-flex justify-content-between align-items-center",
        span(
          bsicons::bs_icon("geo-alt-fill"),
          " Store Map"
        ),
        div(
          class = "d-flex align-items-center gap-2",
          actionButton("apply_region_filter",
                       tagList(bsicons::bs_icon("funnel"), " Apply Filter"),
                       class = "btn-sm btn-primary"),
          actionButton("clear_region",
                       tagList(bsicons::bs_icon("x-circle"), " Clear"),
                       class = "btn-sm btn-outline-secondary"),
          span(class = "small text-muted", "Draw a region, then click Apply")
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
      uiOutput("stores_filter_badge")
    ),
    card_body(
      reactableOutput("store_list")
    )
  )
)
