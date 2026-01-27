# views/admin-stores-ui.R
# Admin - Manage stores UI

admin_stores_ui <- tagList(
  h2("Manage Stores"),
  div(
    class = "admin-panel",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          span(id = "store_form_title", "Add New Store"),
          conditionalPanel(
            condition = "input.editing_store_id && input.editing_store_id != ''",
            actionButton("cancel_edit_store", "Cancel Edit", class = "btn-sm btn-outline-secondary")
          )
        ),
        card_body(
          # Hidden field for edit mode
          textInput("editing_store_id", NULL, value = ""),
          tags$script("document.getElementById('editing_store_id').parentElement.style.display = 'none';"),

          checkboxInput("store_is_online", "Online store (no physical location)", value = FALSE),

          # Physical store fields (shown when checkbox unchecked)
          conditionalPanel(
            condition = "!input.store_is_online",
            textInput("store_name", "Store Name"),
            textInput("store_address", "Street Address"),
            textInput("store_city", "City"),
            selectInput("store_state", "State", choices = c("TX" = "TX"), selected = "TX"),
            textInput("store_zip", "ZIP Code (optional)")
          ),

          # Online store fields (shown when checkbox checked)
          conditionalPanel(
            condition = "input.store_is_online",
            textInput("store_name_online", "Store/Organizer Name"),
            textInput("store_region", "Region/Coverage (optional)", placeholder = "e.g., North America, Global")
          ),

          # Common fields for both
          textInput("store_website", "Website (optional)"),
          textAreaInput("store_schedule", "Schedule Info (optional)",
                        rows = 2,
                        placeholder = "e.g., Locals every Friday at 7pm"),

          # Geocode message only for physical stores
          conditionalPanel(
            condition = "!input.store_is_online",
            div(
              class = "text-muted small mb-2",
              bsicons::bs_icon("geo-alt"), " Location will be automatically geocoded from address"
            )
          ),
          div(
            class = "d-flex gap-2",
            actionButton("add_store", "Add Store", class = "btn-primary"),
            actionButton("update_store", "Update Store", class = "btn-success", style = "display: none;")
          )
        )
      ),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          "Current Stores",
          span(class = "small text-muted", "Click a row to edit")
        ),
        card_body(
          reactableOutput("admin_store_list")
        )
      )
    )
  )
)
