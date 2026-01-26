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
      layout_columns(
        col_widths = c(6, 6),
        card(
          card_header("Step 2: Add Player Result"),
          card_body(
            selectizeInput("result_player", "Player Name",
                           choices = NULL,
                           options = list(create = TRUE, placeholder = "Type to search or add new...")),
            selectInput("result_deck", "Deck Archetype", choices = NULL),
            textInput("result_decklist_url", "Decklist URL (optional)",
                      placeholder = "e.g., digimonmeta.com/deck/..."),
            numericInput("result_placement", "Placement", value = 1, min = 1),
            layout_columns(
              col_widths = c(4, 4, 4),
              numericInput("result_wins", "Wins", value = 0, min = 0),
              numericInput("result_losses", "Losses", value = 0, min = 0),
              numericInput("result_ties", "Ties", value = 0, min = 0)
            ),
            actionButton("add_result", "Add Result", class = "btn-success"),
            actionButton("add_result_another", "Add & Continue", class = "btn-info")
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
    )
  )
)
