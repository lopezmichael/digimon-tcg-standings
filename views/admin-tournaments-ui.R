# views/admin-tournaments-ui.R
# Admin - Manage tournaments UI

admin_tournaments_ui <- tagList(
  h2("Manage Tournaments"),
  div(
    class = "admin-panel",
    layout_columns(
      col_widths = c(5, 7),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          span(id = "tournament_form_title", "Edit Tournament"),
          conditionalPanel(
            condition = "input.editing_tournament_id && input.editing_tournament_id != ''",
            actionButton("cancel_edit_tournament", "Cancel", class = "btn-sm btn-outline-secondary")
          )
        ),
        card_body(
          # Hidden field for edit mode
          textInput("editing_tournament_id", NULL, value = ""),
          tags$script("document.getElementById('editing_tournament_id').parentElement.style.display = 'none';"),

          p(class = "text-muted small", "Select a tournament from the list to edit or delete."),

          # Store dropdown
          selectInput("edit_tournament_store", "Store", choices = NULL),

          # Date
          dateInput("edit_tournament_date", "Date", value = Sys.Date()),

          # Event Type + Format
          layout_columns(
            col_widths = c(6, 6),
            selectInput("edit_tournament_type", "Event Type",
                        choices = c("Select event type..." = "", EVENT_TYPES)),
            selectInput("edit_tournament_format", "Format/Set", choices = list("Loading..." = ""))
          ),

          # Players + Rounds
          layout_columns(
            col_widths = c(6, 6),
            numericInput("edit_tournament_players", "Number of Players", value = 8, min = 2),
            numericInput("edit_tournament_rounds", "Number of Rounds", value = 3, min = 1)
          ),

          hr(),

          # Tournament stats (read-only info)
          uiOutput("tournament_stats_info"),

          hr(),

          # Action buttons
          div(
            class = "d-flex gap-2",
            shinyjs::hidden(
              actionButton("update_tournament", "Update Tournament", class = "btn-success")
            ),
            shinyjs::hidden(
              actionButton("delete_tournament", "Delete Tournament", class = "btn-danger")
            )
          )
        )
      ),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          "All Tournaments",
          div(
            class = "d-flex align-items-center gap-2",
            textInput("admin_tournament_search", NULL, placeholder = "Search...",
                      width = "150px"),
            span(class = "small text-muted", "Click a row to edit")
          )
        ),
        card_body(
          reactableOutput("admin_tournament_list")
        )
      )
    )
  ),

  # Delete confirmation modal
  tags$div(
    id = "delete_tournament_modal",
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
          uiOutput("delete_tournament_message")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("confirm_delete_tournament", "Delete", class = "btn-danger")
        )
      )
    )
  )
)
