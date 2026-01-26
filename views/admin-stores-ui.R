# views/admin-stores-ui.R
# Admin - Manage stores UI

admin_stores_ui <- tagList(
  h2("Manage Stores"),
  div(
    class = "admin-panel",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Add New Store"),
        card_body(
          textInput("store_name", "Store Name"),
          textInput("store_address", "Street Address"),
          layout_columns(
            col_widths = c(6, 6),
            textInput("store_city", "City"),
            selectInput("store_state", "State", choices = c("TX" = "TX"), selected = "TX")
          ),
          textInput("store_zip", "ZIP Code (optional)"),
          textInput("store_website", "Website (optional)"),
          textAreaInput("store_schedule", "Schedule Info (optional)",
                        rows = 2,
                        placeholder = "e.g., Locals every Friday at 7pm"),
          div(
            class = "text-muted small mb-2",
            bsicons::bs_icon("geo-alt"), " Location will be automatically geocoded from address"
          ),
          actionButton("add_store", "Add Store", class = "btn-primary")
        )
      ),
      card(
        card_header("Current Stores"),
        card_body(
          reactableOutput("admin_store_list")
        )
      )
    )
  )
)
