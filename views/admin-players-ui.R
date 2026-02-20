# views/admin-players-ui.R
# Admin - Manage players UI

admin_players_ui <- tagList(
  div(
    class = "d-flex justify-content-between align-items-center mb-3",
    h2("Edit Players", class = "mb-0"),
    actionButton("show_merge_modal", "Merge Players",
                 class = "btn-outline-warning",
                 icon = icon("code-merge"))
  ),
  # Scene filter indicator and override toggle for superadmins
  conditionalPanel(
    condition = "output.is_superadmin == true",
    div(
      class = "d-flex justify-content-end mb-2",
      checkboxInput("admin_players_show_all_scenes", "Show all scenes", value = FALSE)
    )
  ),
  uiOutput("admin_players_scene_indicator"),
  div(
    class = "admin-panel",
    layout_columns(
      col_widths = c(5, 7),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          span(id = "player_form_title", "Edit Player"),
          conditionalPanel(
            condition = "input.editing_player_id && input.editing_player_id != ''",
            actionButton("cancel_edit_player", "Cancel", class = "btn-sm btn-outline-secondary")
          )
        ),
        card_body(
          # Hidden field for edit mode
          textInput("editing_player_id", NULL, value = ""),
          tags$script("document.getElementById('editing_player_id').parentElement.style.display = 'none';"),

          p(class = "text-muted small", "Select a player from the list to edit or delete."),

          textInput("player_display_name", "Display Name", placeholder = "Enter player name..."),

          hr(),

          # Player stats (read-only info)
          uiOutput("player_stats_info"),

          hr(),

          # Action buttons
          div(
            class = "d-flex gap-2",
            shinyjs::hidden(
              actionButton("update_player", "Update Player", class = "btn-success")
            ),
            shinyjs::hidden(
              actionButton("delete_player", "Delete Player", class = "btn-danger")
            )
          )
        )
      ),
      card(
        card_header(
          class = "d-flex justify-content-between align-items-center",
          "All Players",
          div(
            class = "d-flex align-items-center gap-2",
            textInput("player_search", NULL, placeholder = "Search players...",
                      width = "200px"),
            span(class = "small text-muted", "Click a row to edit")
          )
        ),
        card_body(
          reactableOutput("player_list")
        )
      )
    )
  ),

  # Delete confirmation modal
  tags$div(
    id = "delete_player_modal",
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
          uiOutput("delete_player_message")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("confirm_delete_player", "Delete", class = "btn-danger")
        )
      )
    )
  ),

  # Merge players modal
  tags$div(
    id = "merge_player_modal",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header modal-header-digital",
          tags$h5(class = "modal-title", bsicons::bs_icon("arrow-left-right"), " Merge Players"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          p("Merge two player records (e.g., fix a typo by combining duplicate entries)."),
          p(class = "text-muted small", "All results from the source player will be moved to the target player, then the source player will be deleted."),
          hr(),
          selectizeInput("merge_source_player", "Source Player (will be deleted)",
                         choices = NULL,
                         options = list(placeholder = "Select player to merge FROM...")),
          selectizeInput("merge_target_player", "Target Player (will keep)",
                         choices = NULL,
                         options = list(placeholder = "Select player to merge INTO...")),
          uiOutput("merge_preview")
        ),
        tags$div(
          class = "modal-footer",
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
          actionButton("confirm_merge_players", "Merge Players", class = "btn-warning")
        )
      )
    )
  )
)
