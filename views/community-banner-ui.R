# views/community-banner-ui.R
# Banner shown when community filter is active

community_banner_ui <- function(store_name) {
  div(
    id = "community-filter-banner",
    class = "community-filter-banner mb-3",
    div(
      class = "d-flex align-items-center justify-content-between",
      div(
        class = "d-flex align-items-center gap-2",
        bsicons::bs_icon("funnel-fill", class = "text-primary"),
        span("Showing data for "),
        strong(store_name)
      ),
      actionButton(
        "clear_community_filter",
        tagList(bsicons::bs_icon("x-lg"), " View All"),
        class = "btn btn-sm btn-outline-secondary"
      )
    )
  )
}
