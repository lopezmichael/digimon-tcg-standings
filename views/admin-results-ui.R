# views/admin-results-ui.R
# Admin - Enter tournament results with wizard flow

admin_results_ui <- tagList(
  h2("Enter Tournament Results"),

  # Wizard step indicator
  div(
    class = "wizard-steps d-flex gap-3 mb-4",
    div(
      id = "step1_indicator",
      class = "wizard-step active",
      span(class = "step-number", "1"),
      span(class = "step-label", "Tournament Details")
    ),
    div(
      id = "step2_indicator",
      class = "wizard-step",
      span(class = "step-number", "2"),
      span(class = "step-label", "Add Results")
    )
  ),

  # Step 1: Tournament Details
  div(
    id = "wizard_step1",
    card(
        card_header("Tournament Details"),
        card_body(
          # Row 1: Store + Date
          layout_columns(
            col_widths = c(8, 4),
            selectInput("tournament_store", "Store", choices = NULL),
            dateInput("tournament_date", "Date", value = Sys.Date())
          ),
          # Row 2: Event Type + Format
          layout_columns(
            col_widths = c(6, 6),
            selectInput("tournament_type", "Event Type", choices = EVENT_TYPES),
            selectInput("tournament_format", "Format/Set", choices = list("Loading..." = ""))
          ),
          # Row 3: Players + Rounds
          layout_columns(
            col_widths = c(6, 6),
            numericInput("tournament_players", "Number of Players", value = 8, min = 2),
            numericInput("tournament_rounds", "Number of Rounds", value = 3, min = 1)
          ),
          div(
            class = "d-flex justify-content-end mt-3",
            actionButton("create_tournament", "Create Tournament", class = "btn-primary btn-lg",
                         icon = icon("arrow-right"))
          )
        )
      )
  ),

  # Step 2: Add Results (hidden initially)
  shinyjs::hidden(
    div(
      id = "wizard_step2",
      class = "admin-panel",
      # Tournament summary bar
      uiOutput("tournament_summary_bar"),

      layout_columns(
        col_widths = c(5, 7),
        # Left: Add result form
        card(
          card_header("Add Player Result"),
          card_body(
            # Player selection with quick add
            selectizeInput("result_player", "Player Name",
                           choices = NULL,
                           options = list(create = TRUE, placeholder = "Type to search or add new...")),
            shinyjs::hidden(
              div(
                id = "quick_add_player_form",
                class = "border rounded p-2 mb-3 bg-light",
                textInput("quick_player_name", "New Player Name"),
                div(
                  class = "d-flex gap-2",
                  actionButton("quick_add_player_submit", "Add", class = "btn-sm btn-success"),
                  actionButton("quick_add_player_cancel", "Cancel", class = "btn-sm btn-secondary")
                )
              )
            ),
            actionLink("show_quick_add_player", "+ New Player", class = "small"),

            hr(),

            # Deck selection with quick add
            selectizeInput("result_deck", "Deck Archetype",
                           choices = NULL,
                           options = list(placeholder = "Type to search decks...")),
            shinyjs::hidden(
              div(
                id = "quick_add_deck_form",
                class = "border rounded p-2 mb-3 bg-light",
                textInput("quick_deck_name", "Deck Name", placeholder = "e.g., New Archetype"),
                selectInput("quick_deck_color", "Primary Color",
                            choices = c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
                div(class = "small text-muted mb-2", "(Full details can be added later in Manage Decks)"),
                div(
                  class = "d-flex gap-2",
                  actionButton("quick_add_deck_submit", "Add", class = "btn-sm btn-success"),
                  actionButton("quick_add_deck_cancel", "Cancel", class = "btn-sm btn-secondary")
                )
              )
            ),
            actionLink("show_quick_add_deck", "+ New Deck", class = "small"),

            hr(),

            # Placement + Decklist URL row
            layout_columns(
              col_widths = c(4, 8),
              numericInput("result_placement", "Placement", value = 1, min = 1),
              textInput("result_decklist_url", "Decklist URL (optional)",
                        placeholder = "e.g., digimonmeta.com/deck/...")
            ),

            # W/L/T with individual labels
            layout_columns(
              col_widths = c(4, 4, 4),
              numericInput("result_wins", "Wins", value = 0, min = 0),
              numericInput("result_losses", "Losses", value = 0, min = 0),
              numericInput("result_ties", "Ties", value = 0, min = 0)
            ),
            actionButton("add_result", "Add Result", class = "btn-add-result w-100 mt-3")
          )
        ),
        # Right: Results table
        card(
          card_header(
            class = "d-flex justify-content-between align-items-center",
            uiOutput("results_count_header"),
            actionButton("clear_tournament", "Start Over", class = "btn-sm btn-outline-warning")
          ),
          card_body(
            reactableOutput("current_results")
          )
        )
      ),

      # Bottom navigation
      div(
        class = "d-flex justify-content-between mt-3",
        actionButton("wizard_back", "Back to Details", class = "btn-secondary",
                     icon = icon("arrow-left")),
        actionButton("finish_tournament", "Mark Complete", class = "btn-primary btn-lg",
                     icon = icon("check"))
      )
    )
  ),

  # Duplicate tournament modal
  tags$div(
    id = "duplicate_tournament_modal",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", "Possible Duplicate Tournament"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          uiOutput("duplicate_tournament_message")
        ),
        tags$div(
          class = "modal-footer d-flex gap-2 justify-content-end",
          actionButton("edit_existing_tournament", "View/Edit Existing", class = "btn-outline-primary"),
          actionButton("create_anyway", "Create Anyway", class = "btn-warning"),
          tags$button(type = "button", class = "btn btn-outline-secondary", `data-bs-dismiss` = "modal", "Cancel")
        )
      )
    )
  ),

  # Start over modal (clear results vs delete tournament)
  tags$div(
    id = "start_over_modal",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", "Start Over?"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          p("What would you like to do?"),
          uiOutput("start_over_message")
        ),
        tags$div(
          class = "modal-footer d-flex flex-column gap-2 align-items-stretch",
          actionButton("clear_results_only", "Clear Results",
                       class = "btn-warning",
                       icon = icon("eraser")),
          tags$small(class = "text-muted text-center", "Remove entered results but keep the tournament for re-entry."),
          actionButton("delete_tournament_confirm", "Delete Tournament",
                       class = "btn-danger",
                       icon = icon("trash")),
          uiOutput("delete_tournament_warning"),
          tags$button(type = "button", class = "btn btn-secondary mt-2", `data-bs-dismiss` = "modal", "Cancel")
        )
      )
    )
  )
)
