# views/submit-ui.R
# Public Submit Results tab UI

submit_ui <- tagList(
  # Title strip
  div(
    class = "page-title-strip mb-3",
    div(
      class = "title-strip-content",
      div(
        class = "title-strip-context",
        bsicons::bs_icon("cloud-upload", class = "title-strip-icon"),
        tags$span(class = "title-strip-text", "Submit Results")
      ),
      div(
        class = "title-strip-controls",
        span(class = "small text-muted", "Help grow the tournament database")
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

        # Tournament Details Card
        card(
          card_header("Tournament Details"),
          card_body(
            layout_columns(
              col_widths = c(6, 6),
              # Left column
              div(
                selectInput("submit_store", "Store *",
                            choices = c("Loading..." = ""),
                            width = "100%"),
                actionLink("submit_request_store", "Store not listed? Request new store",
                           class = "small text-muted")
              ),
              # Right column
              div(
                dateInput("submit_date", "Date *", value = NA, width = "100%"),
                tags$small(class = "text-muted", "Required")
              )
            ),
            layout_columns(
              col_widths = c(4, 4, 4),
              selectInput("submit_event_type", "Event Type *",
                          choices = c("Select..." = "",
                                      "Locals" = "locals",
                                      "Evo Cup" = "evo_cup",
                                      "Store Championship" = "store_championship",
                                      "Regional" = "regional",
                                      "Online" = "online"),
                          width = "100%"),
              selectInput("submit_format", "Format *",
                          choices = c("Loading..." = ""),
                          width = "100%"),
              numericInput("submit_rounds", "Total Rounds *", value = 4, min = 1, max = 15, width = "100%")
            )
          )
        ),

        # Screenshot Upload Card
        card(
          card_header(
            class = "d-flex justify-content-between align-items-center",
            span("Tournament Screenshots"),
            actionButton("submit_add_screenshot", "Add Another",
                         class = "btn-sm btn-outline-primary",
                         icon = icon("plus"))
          ),
          card_body(
            fileInput("submit_screenshots", "Upload Screenshot(s)",
                      multiple = TRUE,
                      accept = c("image/png", "image/jpeg", "image/jpg"),
                      width = "100%"),
            tags$small(class = "text-muted d-block mb-2",
                       "Upload screenshots from Bandai TCG+ app showing tournament rankings"),
            uiOutput("submit_screenshot_preview"),
            div(
              class = "mt-3",
              actionButton("submit_process_ocr", "Process Screenshots",
                           class = "btn-primary",
                           icon = icon("magic"))
            )
          )
        ),

        # Results Preview (shown after OCR)
        uiOutput("submit_results_preview"),

        # Submit Button (shown after OCR)
        uiOutput("submit_final_button")
      )
    ),

    # Match History Tab
    nav_panel(
      title = tagList(bsicons::bs_icon("list-ol"), " Match History"),
      value = "match_history",

      div(
        class = "p-3",

        # Info card
        card(
          card_body(
            class = "text-center py-4",
            bsicons::bs_icon("info-circle", size = "2rem", class = "text-muted mb-2"),
            h5("Coming Soon"),
            p(class = "text-muted mb-0",
              "Match history submission will be available in a future update. ",
              "For now, you can submit tournament standings above.")
          )
        )
      )
    )
  )
)
