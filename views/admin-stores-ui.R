# views/admin-stores-ui.R
# Admin - Manage stores UI

admin_stores_ui <- tagList(
  h2("Edit Stores"),
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
            textInput("store_zip", "ZIP Code")
          ),

          # Online store fields (shown when checkbox checked)
          conditionalPanel(
            condition = "input.store_is_online",
            textInput("store_name_online", "Store/Organizer Name"),
            textInput("store_region", "Region/Coverage (optional)", placeholder = "e.g., North America, Global")
          ),

          # Common fields for both
          textInput("store_website", "Website (optional)"),

          # Geocode message only for physical stores
          conditionalPanel(
            condition = "!input.store_is_online",
            div(
              class = "text-muted small mb-2",
              bsicons::bs_icon("geo-alt"), " Location will be automatically geocoded from address"
            )
          ),

          # Schedule management section (for physical stores - both new and editing)
          conditionalPanel(
            condition = "!input.store_is_online",
            hr(),
            h5("Regular Schedule"),
            # Show existing schedules when editing
            conditionalPanel(
              condition = "input.editing_store_id && input.editing_store_id != ''",
              p(class = "text-muted small", "Click a schedule to delete it"),
              reactableOutput("store_schedules_table")
            ),
            # Show pending schedules when adding new store
            conditionalPanel(
              condition = "!input.editing_store_id || input.editing_store_id == ''",
              uiOutput("pending_schedules_display")
            ),
            div(
              class = "mt-3",
              layout_columns(
                col_widths = c(4, 3, 3, 2),
                selectInput(
                  "schedule_day", "Day",
                  choices = list(
                    "Sunday" = "0",
                    "Monday" = "1",
                    "Tuesday" = "2",
                    "Wednesday" = "3",
                    "Thursday" = "4",
                    "Friday" = "5",
                    "Saturday" = "6"
                  ),
                  selected = "1",
                  selectize = FALSE
                ),
                textInput(
                  "schedule_time", "Time",
                  value = "19:00",
                  placeholder = "HH:MM (e.g., 19:00)"
                ),
                selectInput(
                  "schedule_frequency", "Frequency",
                  choices = list(
                    "Weekly" = "weekly",
                    "Biweekly" = "biweekly",
                    "Monthly" = "monthly"
                  ),
                  selected = "weekly",
                  selectize = FALSE
                ),
                div(
                  style = "padding-top: 32px;",
                  actionButton("add_schedule", "Add", class = "btn-outline-primary btn-sm")
                )
              )
            )
          ),

          hr(),
          div(
            class = "d-flex gap-2",
            actionButton("add_store", "Add Store", class = "btn-primary"),
            actionButton("update_store", "Update Store", class = "btn-success", style = "display: none;"),
            actionButton("delete_store", "Delete Store", class = "btn-danger", style = "display: none;")
          )
        )
      ),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          "Current Stores",
          div(
            class = "d-flex align-items-center gap-3",
            span(class = "small text-muted", "Click to edit"),
            div(
              class = "d-flex align-items-center gap-2 small",
              span(
                style = "width: 12px; height: 12px; background: rgba(245, 183, 0, 0.3); border-left: 2px solid #F5B700; display: inline-block;",
                title = "Missing schedule or ZIP"
              ),
              span(class = "text-muted", "Incomplete")
            )
          )
        ),
        card_body(
          reactableOutput("admin_store_list")
        )
      )
    )
  ),

  # Delete confirmation modal
  tags$div(
    id = "delete_store_modal",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", "Confirm Delete"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          uiOutput("delete_store_message")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("confirm_delete_store", "Delete", class = "btn-danger")
        )
      )
    )
  )
)
