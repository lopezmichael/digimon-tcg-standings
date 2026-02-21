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
          class = "tournament-details-form",
          # Row 1: Store + Date
          div(
            class = "row g-3 mb-3",
            div(class = "col-md-8",
                selectInput("tournament_store", "Store", choices = NULL)),
            div(class = "col-md-4",
                div(
                  class = "date-required",
                  dateInput("tournament_date", "Date *", value = NA),
                  div(id = "date_required_hint", class = "date-required-hint", "Required")
                ))
          ),
          # Row 2: Event Type + Format
          div(
            class = "row g-3 mb-3",
            div(class = "col-md-6",
                selectInput("tournament_type", "Event Type",
                            choices = c("Select event type..." = "", EVENT_TYPES))),
            div(class = "col-md-6",
                selectInput("tournament_format", "Format/Set", choices = list("Loading..." = "")))
          ),
          # Row 3: Players + Rounds
          div(
            class = "row g-3 mb-3",
            div(class = "col-md-6",
                numericInput("tournament_players", "Number of Players", value = 8, min = 2)),
            div(class = "col-md-6",
                numericInput("tournament_rounds", "Number of Rounds", value = 3, min = 1))
          ),
          # Row 4: Record Format
          div(
            class = "row g-3 mb-3",
            div(class = "col-md-6",
                radioButtons("admin_record_format", "Record Format",
                             choices = c("Points" = "points", "W-L-T" = "wlt"),
                             selected = "points", inline = TRUE))
          ),
          div(
            class = "d-flex justify-content-end mt-3",
            actionButton("create_tournament", "Create Tournament", class = "btn-primary btn-lg",
                         icon = icon("arrow-right"))
          )
        )
      )
  ),

  # Step 2: Enter Results Grid (hidden initially)
  shinyjs::hidden(
    div(
      id = "wizard_step2",
      class = "admin-panel",
      # Tournament summary bar
      uiOutput("tournament_summary_bar"),

      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          div(
            class = "d-flex align-items-center gap-2",
            span("Enter Results"),
            uiOutput("admin_record_format_badge", inline = TRUE)
          ),
          div(
            class = "d-flex align-items-center gap-2",
            uiOutput("admin_filled_count", inline = TRUE),
            actionButton("admin_paste_btn", "Paste from Spreadsheet",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("clipboard"))
          )
        ),
        card_body(
          uiOutput("admin_grid_table")
        )
      ),

      # Bottom navigation
      div(
        class = "d-flex justify-content-between mt-3",
        div(
          class = "d-flex gap-2",
          actionButton("wizard_back", "Back to Details", class = "btn-secondary",
                       icon = icon("arrow-left")),
          actionButton("clear_tournament", "Start Over", class = "btn-outline-warning",
                       icon = icon("rotate-left"))
        ),
        actionButton("admin_submit_results", "Submit Results", class = "btn-primary btn-lg",
                     icon = icon("check"))
      )
    )
  )
)
