# views/submit-ui.R
# Public Upload Results tab UI

submit_ui <- tagList(
  # Title strip
  div(
    class = "page-title-strip mb-3",
    div(
      class = "title-strip-content",
      div(
        class = "title-strip-context",
        bsicons::bs_icon("cloud-upload", class = "title-strip-icon"),
        tags$span(class = "title-strip-text", "Upload Results")
      ),
      div(
        class = "title-strip-controls",
        span(class = "small text-muted", "Upload Bandai TCG+ screenshots to add tournament data")
      )
    )
  ),

  # Main content with tabs
  navset_card_tab(
    id = "submit_tabs",

    # Tournament Results Tab
    nav_panel(
      title = tagList(bsicons::bs_icon("trophy"), " Tournament Results"),
      value = "tournament",

      div(
        class = "p-3",

        # Wizard step indicator
        div(
          class = "wizard-steps d-flex gap-3 mb-4",
          div(
            id = "submit_step1_indicator",
            class = "wizard-step active",
            span(class = "step-number", "1"),
            span(class = "step-label", "Upload Screenshots")
          ),
          div(
            id = "submit_step2_indicator",
            class = "wizard-step",
            span(class = "step-number", "2"),
            span(class = "step-label", "Review & Submit")
          )
        ),

        # Step 1: Tournament Details + Screenshot Upload
        div(
          id = "submit_wizard_step1",

          # Tournament Details Card
          card(
            card_header("Tournament Details"),
            card_body(
              layout_columns(
                col_widths = c(6, 6),
                # Left column - Store
                div(
                  selectInput("submit_store", "Store",
                              choices = c("Loading..." = ""),
                              selectize = FALSE),
                  actionLink("submit_request_store", "Store not listed? Request it",
                             class = "small text-primary")
                ),
                # Right column - Date
                dateInput("submit_date", "Date", value = NA)
              ),
              layout_columns(
                col_widths = c(4, 4, 4),
                selectInput("submit_event_type", "Event Type",
                            choices = c("Select..." = "",
                                        "Locals" = "locals",
                                        "Evo Cup" = "evo_cup",
                                        "Store Championship" = "store_championship",
                                        "Regional" = "regional",
                                        "Online" = "online"),
                            selectize = FALSE),
                selectInput("submit_format", "Format",
                            choices = c("Loading..." = ""),
                            selectize = FALSE),
                numericInput("submit_rounds", "Total Rounds", value = 4, min = 1, max = 15)
              )
            )
          ),

          # Screenshot Upload Card
          card(
            class = "mt-3",
            card_header("Upload Screenshots"),
            card_body(
              # Info callout
              div(
                class = "alert alert-info d-flex mb-3",
                bsicons::bs_icon("info-circle", class = "me-2 flex-shrink-0", size = "1.2em"),
                div(
                  tags$strong("Bandai TCG+ App Screenshots Only"),
                  tags$br(),
                  tags$small("You can upload multiple screenshots if the standings span multiple screens.")
                )
              ),

              # Simple file upload
              div(
                class = "upload-file-input",
                fileInput("submit_screenshots", "Select Files",
                          multiple = TRUE,
                          accept = c("image/png", "image/jpeg", "image/jpg", "image/webp", ".png", ".jpg", ".jpeg", ".webp"))
              ),

              # Screenshot preview
              uiOutput("submit_screenshot_preview"),

              # Process button
              div(
                class = "mt-3",
                actionButton("submit_process_ocr", "Process Screenshots",
                             class = "btn-primary btn-lg",
                             icon = icon("arrow-right"))
              )
            )
          )
        ),

        # Step 2: Review & Edit Results (hidden initially)
        shinyjs::hidden(
          div(
            id = "submit_wizard_step2",

            # Summary banner
            uiOutput("submit_summary_banner"),

            # Instructions callout - prominent at top
            div(
              class = "alert alert-primary d-flex mb-3",
              bsicons::bs_icon("pencil-square", class = "me-2 flex-shrink-0", size = "1.2em"),
              div(
                tags$strong("Review and edit the extracted data"),
                tags$br(),
                tags$small("Check that player names and points are correct. ",
                           "Select a deck archetype for each player if known (optional). ",
                           "Click ", bsicons::bs_icon("x-circle"), " to reject a matched player and create them as new.")
              )
            ),

            # Match summary badges - prominent
            uiOutput("submit_match_summary"),

            # Results card
            card(
              class = "mt-3",
              card_header("Player Results"),
              card_body(
                uiOutput("submit_results_table")
              )
            ),

            # Navigation buttons
            div(
              class = "d-flex justify-content-between mt-3",
              actionButton("submit_back", "Back", class = "btn-secondary",
                           icon = icon("arrow-left")),
              actionButton("submit_tournament", "Submit Tournament",
                           class = "btn-primary btn-lg", icon = icon("check"))
            )
          )
        )
      )
    ),

    # Match History Tab
    nav_panel(
      title = tagList(bsicons::bs_icon("list-ol"), " Match History"),
      value = "match_history",

      div(
        class = "p-3",

        # Info box - updated with Bandai TCG+ mention
        div(
          class = "alert alert-info d-flex align-items-start mb-3",
          bsicons::bs_icon("info-circle", class = "me-2 flex-shrink-0", size = "1.2em"),
          div(
            tags$strong("Add your round-by-round match data"),
            tags$br(),
            tags$small("Upload a screenshot of your match history from the ",
                       tags$strong("Bandai TCG+ app"),
                       " for a tournament that already exists in the system.")
          )
        ),

        # Tournament Selection Card
        card(
          card_header("Select Tournament"),
          card_body(
            layout_columns(
              col_widths = c(6, 6),
              selectInput("match_store", "Store",
                          choices = c("All stores" = ""),
                          selectize = FALSE),
              selectInput("match_tournament", "Tournament",
                          choices = c("Select a tournament..." = ""),
                          selectize = FALSE)
            ),
            uiOutput("match_tournament_info")
          )
        ),

        # Your Player Info Card
        card(
          class = "mt-3",
          card_header("Your Player Info"),
          card_body(
            p(class = "text-muted small mb-2",
              "Enter your info so we can link this match history to your player record."),
            layout_columns(
              col_widths = c(6, 6),
              div(
                textInput("match_player_username", "Your Username",
                          placeholder = "e.g., HappyCat"),
                div(id = "match_username_hint", class = "form-text text-danger d-none", "Required")
              ),
              div(
                textInput("match_player_member", "Your Member Number",
                          placeholder = "e.g., 0000123456"),
                div(id = "match_member_hint", class = "form-text text-danger d-none", "Required")
              )
            )
          )
        ),

        # Screenshot Upload Card
        card(
          class = "mt-3",
          card_header("Match History Screenshot"),
          card_body(
            # Simple file upload
            div(
              class = "upload-file-input",
              fileInput("match_screenshots", "Select File",
                        multiple = FALSE,
                        accept = c("image/png", "image/jpeg", "image/jpg", "image/webp", ".png", ".jpg", ".jpeg", ".webp"))
            ),

            uiOutput("match_screenshot_preview"),
            div(
              class = "mt-3",
              actionButton("match_process_ocr", "Process Screenshot",
                           class = "btn-primary",
                           icon = icon("magic"))
            )
          )
        ),

        # Match History Preview (shown after OCR)
        uiOutput("match_results_preview"),

        # Submit Button (shown after OCR)
        uiOutput("match_final_button")
      )
    )
  )
)
