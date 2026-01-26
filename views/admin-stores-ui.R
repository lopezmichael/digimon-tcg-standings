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
          textInput("store_address", "Address"),
          textInput("store_city", "City"),
          layout_columns(
            col_widths = c(6, 6),
            numericInput("store_lat", "Latitude", value = 32.7767, step = 0.0001),
            numericInput("store_lng", "Longitude", value = -96.7970, step = 0.0001)
          ),
          textInput("store_website", "Website (optional)"),
          textAreaInput("store_schedule", "Schedule Info (optional)", rows = 3),
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
