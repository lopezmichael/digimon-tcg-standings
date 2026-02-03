# views/admin-tournaments-ui.R
# Admin - Manage tournaments UI

admin_tournaments_ui <- tagList(
  h2("Edit Tournaments"),
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

          # View/Edit Results button (only shown when tournament selected)
          shinyjs::hidden(
            div(
              id = "view_results_btn_container",
              class = "mt-3",
              actionButton("view_edit_results", "View/Edit Results",
                           class = "btn-primary w-100",
                           icon = icon("list-check"))
            )
          ),

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
  ),

  # Results modal for viewing/editing tournament results
  tags$div(
    id = "tournament_results_modal",
    class = "modal fade",
    tabindex = "-1",
    `data-bs-backdrop` = "static",
    tags$div(
      class = "modal-dialog modal-lg",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header modal-header-digital",
          tags$h5(class = "modal-title", bsicons::bs_icon("list-check"), " Tournament Results"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          # Tournament summary
          uiOutput("results_modal_summary"),

          hr(),

          # Add result button
          div(
            class = "mb-3",
            actionButton("modal_add_result", "+ Add Result",
                         class = "btn-outline-primary btn-sm",
                         icon = icon("plus"))
          ),

          # Results table
          reactableOutput("modal_results_table"),

          # Add result form (hidden initially)
          shinyjs::hidden(
            div(
              id = "modal_add_result_form",
              class = "card mt-3 p-3 bg-light",
              h6("Add New Result"),
              div(
                class = "row g-2",
                div(class = "col-md-6",
                    selectizeInput("modal_new_player", "Player",
                                   choices = NULL,
                                   options = list(create = FALSE, placeholder = "Select player..."))),
                div(class = "col-md-6",
                    selectizeInput("modal_new_deck", "Deck",
                                   choices = NULL,
                                   options = list(create = FALSE, placeholder = "Select deck...")))
              ),
              div(
                class = "row g-2 mt-2",
                div(class = "col-md-3",
                    numericInput("modal_new_placement", "Place", value = 1, min = 1)),
                div(class = "col-md-3",
                    numericInput("modal_new_wins", "Wins", value = 0, min = 0)),
                div(class = "col-md-3",
                    numericInput("modal_new_losses", "Losses", value = 0, min = 0)),
                div(class = "col-md-3",
                    numericInput("modal_new_ties", "Ties", value = 0, min = 0))
              ),
              div(
                class = "row g-2 mt-2",
                div(class = "col-12",
                    textInput("modal_new_decklist", "Decklist URL (optional)", placeholder = "https://..."))
              ),
              div(
                class = "d-flex gap-2 mt-3",
                actionButton("modal_save_new_result", "Save", class = "btn-success btn-sm"),
                actionButton("modal_cancel_new_result", "Cancel", class = "btn-outline-secondary btn-sm")
              )
            )
          )
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Done")
        )
      )
    )
  ),

  # Edit result modal (for editing individual results from the table)
  tags$div(
    id = "modal_edit_result",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", bsicons::bs_icon("pencil-square"), " Edit Result"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          # Hidden field for result ID
          textInput("modal_editing_result_id", NULL, value = ""),
          tags$script("document.getElementById('modal_editing_result_id').parentElement.style.display = 'none';"),

          selectizeInput("modal_edit_player", "Player",
                         choices = NULL,
                         options = list(create = FALSE, placeholder = "Select player...")),
          selectizeInput("modal_edit_deck", "Deck",
                         choices = NULL,
                         options = list(create = FALSE, placeholder = "Select deck...")),
          div(
            class = "modal-numeric-inputs",
            layout_columns(
              col_widths = c(3, 3, 3, 3),
              numericInput("modal_edit_placement", "Place", value = 1, min = 1),
              numericInput("modal_edit_wins", "Wins", value = 0, min = 0),
              numericInput("modal_edit_losses", "Losses", value = 0, min = 0),
              numericInput("modal_edit_ties", "Ties", value = 0, min = 0)
            )
          ),
          div(
            class = "mt-2",
            textInput("modal_edit_decklist", "Decklist URL (optional)")
          )
        ),
        tags$div(
          class = "modal-footer d-flex justify-content-between",
          actionButton("modal_delete_result", "Delete", class = "btn-danger"),
          div(
            tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
            actionButton("modal_save_edit_result", "Save Changes", class = "btn-success ms-2")
          )
        )
      )
    )
  ),

  # Delete result confirmation modal
  tags$div(
    id = "modal_delete_result_confirm",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog modal-sm",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", "Delete Result?"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          p("Are you sure you want to delete this result?"),
          p(class = "text-muted small", "This action cannot be undone.")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("modal_confirm_delete_result", "Delete", class = "btn-danger")
        )
      )
    )
  )
)
