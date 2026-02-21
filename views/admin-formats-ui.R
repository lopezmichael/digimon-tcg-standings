# views/admin-formats-ui.R
# Admin - Manage formats UI

admin_formats_ui <- tagList(
  h2("Edit Formats"),
  div(class = "page-help-text",
    div(class = "info-hint-box",
      bsicons::bs_icon("info-circle", class = "info-hint-icon"),
      "Add card sets and formats. Tournaments reference these for filtering by era."
    )
  ),
  div(
    class = "admin-panel",
    layout_columns(
      col_widths = c(5, 7),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          span(id = "format_form_title", "Add New Format"),
          conditionalPanel(
            condition = "input.editing_format_id && input.editing_format_id != ''",
            actionButton("cancel_edit_format", "Cancel Edit", class = "btn-sm btn-outline-secondary")
          )
        ),
        card_body(
          # Hidden field for edit mode (stores the original format_id being edited)
          textInput("editing_format_id", NULL, value = ""),
          tags$script("document.getElementById('editing_format_id').parentElement.style.display = 'none';"),

          textInput("format_id", "Set Code", placeholder = "e.g., BT20, EX09"),
          textInput("format_set_name", "Set Name", placeholder = "e.g., Xros Encounter"),
          dateInput("format_release_date", "Release Date", value = Sys.Date()),
          checkboxInput("format_is_active", "Active", value = TRUE),
          div(class = "text-muted small mb-2", "Formats are sorted by release date (most recent first)"),

          div(
            class = "d-flex gap-2",
            actionButton("add_format", "Add Format", class = "btn-primary"),
            actionButton("update_format", "Update Format", class = "btn-success", style = "display: none;"),
            actionButton("delete_format", "Delete Format", class = "btn-danger", style = "display: none;")
          )
        )
      ),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          "Current Formats",
          span(class = "small text-muted", "Click a row to edit")
        ),
        card_body(
          reactableOutput("admin_format_list")
        )
      )
    )
  ),

  # Delete confirmation modal
  tags$div(
    id = "delete_format_modal",
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
          uiOutput("delete_format_message")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("confirm_delete_format", "Delete", class = "btn-danger")
        )
      )
    )
  )
)
