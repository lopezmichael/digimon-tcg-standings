# views/admin-results-ui.R
# Admin - Enter tournament results UI

admin_results_ui <- tagList(
  h2("Enter Tournament Results"),
  div(
    class = "admin-panel",
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Step 1: Tournament Details"),
        card_body(
          selectInput("tournament_store", "Store", choices = NULL),
          dateInput("tournament_date", "Date", value = Sys.Date()),
          selectInput("tournament_type", "Event Type", choices = EVENT_TYPES),
          selectInput("tournament_format", "Format/Set", choices = FORMAT_CHOICES),
          numericInput("tournament_players", "Number of Players", value = 8, min = 2),
          numericInput("tournament_rounds", "Number of Rounds", value = 3, min = 1),
          actionButton("create_tournament", "Create Tournament", class = "btn-primary")
        )
      ),
      card(
        card_header("Active Tournament"),
        card_body(
          verbatimTextOutput("active_tournament_info"),
          hr(),
          conditionalPanel(
            condition = "output.has_active_tournament == true",
            actionButton("clear_tournament", "Clear / Start New", class = "btn-warning")
          )
        )
      )
    ),

    # Step 2: Add Results (shown after tournament created)
    conditionalPanel(
      condition = "output.has_active_tournament == true",
      hr(),
      # Entry mode toggle
      div(
        class = "mb-3",
        radioButtons("result_entry_mode", "Entry Mode",
                     choices = c("Single Entry" = "single", "Bulk Paste" = "bulk"),
                     selected = "single", inline = TRUE)
      ),

      # Single entry mode
      conditionalPanel(
        condition = "input.result_entry_mode == 'single'",
        layout_columns(
          col_widths = c(6, 6),
          card(
            card_header("Step 2: Add Player Result"),
            card_body(
              selectizeInput("result_player", "Player Name",
                             choices = NULL,
                             options = list(create = TRUE, placeholder = "Type to search or add new...")),
              # Deck selection with quick-add option
              div(
                class = "mb-3",
                selectizeInput("result_deck", "Deck Archetype",
                               choices = NULL,
                               options = list(placeholder = "Type to search decks...")),
                # Quick add deck section
                tags$details(
                  tags$summary(class = "small text-muted", style = "cursor: pointer;",
                               bsicons::bs_icon("plus-circle"), " Quick add new deck..."),
                  div(
                    class = "mt-2 p-2 bg-light rounded",
                    textInput("quick_deck_name", "Deck Name", placeholder = "e.g., New Archetype"),
                    selectInput("quick_deck_color", "Primary Color",
                                choices = c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
                    div(
                      class = "d-flex gap-2 align-items-center",
                      actionButton("quick_add_deck", "Add Deck", class = "btn-sm btn-warning"),
                      span(class = "small text-muted", "(Can complete details later in Manage Decks)")
                    )
                  )
                )
              ),
              textInput("result_decklist_url", "Decklist URL (optional)",
                        placeholder = "e.g., digimonmeta.com/deck/..."),
              numericInput("result_placement", "Placement", value = 1, min = 1),
              numericInput("result_wins", "Wins", value = 0, min = 0),
              numericInput("result_losses", "Losses", value = 0, min = 0),
              numericInput("result_ties", "Ties", value = 0, min = 0),
              div(
                class = "d-flex gap-2",
                actionButton("add_result", "Add Result", class = "btn-success"),
                actionButton("add_result_another", "Add & Continue", class = "btn-info")
              )
            )
          ),
          card(
            card_header("Results Entered"),
            card_body(
              reactableOutput("current_results"),
              hr(),
              actionButton("finish_tournament", "Mark Tournament Complete", class = "btn-primary")
            )
          )
        )
      ),

      # Bulk entry mode
      conditionalPanel(
        condition = "input.result_entry_mode == 'bulk'",
        layout_columns(
          col_widths = c(6, 6),
          card(
            card_header("Step 2: Paste Tournament Results"),
            card_body(
              div(
                class = "alert alert-info small",
                tags$strong("Format:"), " One result per line",
                tags$br(),
                tags$code("Place, Player Name, Deck, W-L-T, [Decklist URL]"),
                tags$br(),
                tags$em("Examples:"),
                tags$br(),
                tags$code("1, John Smith, Fenriloogamon, 4-0-0"),
                tags$br(),
                tags$code("2, Jane Doe, Blue Flare, 3-1-0, https://digimonmeta.com/deck/123")
              ),
              textAreaInput("bulk_results", "Paste Results",
                            rows = 12,
                            placeholder = "1, Player Name, Deck Name, 4-0-0\n2, Player Name, Deck Name, 3-1-0\n..."),
              div(
                class = "d-flex gap-2",
                actionButton("parse_bulk", "Preview Results", class = "btn-info"),
                actionButton("submit_bulk", "Submit All Results", class = "btn-success")
              )
            )
          ),
          card(
            card_header("Bulk Results Preview"),
            card_body(
              uiOutput("bulk_preview_errors"),
              reactableOutput("bulk_preview_table"),
              hr(),
              reactableOutput("current_results_bulk"),
              hr(),
              actionButton("finish_tournament_bulk", "Mark Tournament Complete", class = "btn-primary")
            )
          )
        )
      )
    )
  )
)
