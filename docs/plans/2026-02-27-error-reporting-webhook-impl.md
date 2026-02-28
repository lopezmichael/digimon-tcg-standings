# Error Reporting Webhook Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace static "Report Error" buttons with webhook-powered modals that send data error reports to scene coordination threads and general bug reports to a #bug-reports Discord Forum channel.

**Architecture:** Two modal flows share a common webhook base (`discord_send`). Data error modals open from player/tournament/deck modal footers with pre-filled context; bug report modal opens from footer link and content pages. Both fire-and-forget to Discord.

**Tech Stack:** R Shiny (bslib modals, actionLinks, shinyjs), httr2 (webhook POST), Discord Forum API

**Design doc:** `docs/plans/2026-02-27-error-reporting-webhook-design.md`

---

### Task 1: Add webhook functions to `R/discord_webhook.R`

**Files:**
- Modify: `R/discord_webhook.R:105` (append after existing functions)

**Context:** This file already has `discord_send()`, `discord_post_to_scene()`, and `discord_post_scene_request()`. We add two new functions following the same pattern.

**Step 1: Add `discord_post_data_error()` function**

Append to end of `R/discord_webhook.R`:

```r
# Post a data error report to a scene's coordination thread
discord_post_data_error <- function(scene_id, item_type, item_name, description,
                                    discord_username = NA_character_, db_pool) {
  scene <- tryCatch(
    pool::dbGetQuery(db_pool,
      "SELECT discord_thread_id, display_name FROM scenes WHERE scene_id = $1",
      params = list(scene_id)),
    error = function(e) data.frame()
  )

  timestamp <- format(Sys.time(), "%m/%d/%Y %I:%M %p %Z")

  content_lines <- c(
    "**Data Error Report**",
    paste0("**Type:** ", item_type),
    paste0("**Item:** ", item_name)
  )

  if (nrow(scene) > 0) {
    content_lines <- c(content_lines, paste0("**Scene:** ", scene$display_name[1]))
  }

  content_lines <- c(content_lines, paste0("**Description:** ", description))

  if (!is.na(discord_username) && nchar(discord_username) > 0) {
    content_lines <- c(content_lines, paste0("**Discord:** ", discord_username))
  }

  content_lines <- c(content_lines,
    paste0("**Submitted:** ", timestamp),
    "*Submitted via DigiLab*"
  )

  body <- list(content = paste(content_lines, collapse = "\n"))

  # Route to scene thread if available, otherwise fall back to bug reports
  if (nrow(scene) > 0) {
    thread_id <- scene$discord_thread_id[1]
    if (!is.null(thread_id) && !is.na(thread_id) && nchar(thread_id) > 0) {
      webhook_url <- Sys.getenv("DISCORD_WEBHOOK_SCENE_COORDINATION")
      return(discord_send(webhook_url, body, thread_id = thread_id))
    }
  }

  # Fallback: post as bug report
  discord_post_bug_report(
    title = paste("Data Error:", item_type, "-", item_name),
    description = description,
    context = if (nrow(scene) > 0) paste("Scene:", scene$display_name[1]) else "",
    discord_username = discord_username
  )
}

# Post a bug report to #bug-reports Forum channel
discord_post_bug_report <- function(title, description, context = "",
                                    discord_username = NA_character_) {
  webhook_url <- Sys.getenv("DISCORD_WEBHOOK_BUG_REPORTS")
  tag_id <- Sys.getenv("DISCORD_TAG_NEW_BUG")

  timestamp <- format(Sys.time(), "%m/%d/%Y %I:%M %p %Z")

  content_lines <- c(
    paste0("**Description:** ", description)
  )

  if (nchar(context) > 0) {
    content_lines <- c(content_lines, paste0("**Context:** ", context))
  }

  if (!is.na(discord_username) && nchar(discord_username) > 0) {
    content_lines <- c(content_lines, paste0("**Discord:** ", discord_username))
  }

  content_lines <- c(content_lines,
    paste0("**Submitted:** ", timestamp),
    "*Submitted via DigiLab*"
  )

  body <- list(
    thread_name = paste0("Bug: ", substr(title, 1, 90)),
    content = paste(content_lines, collapse = "\n")
  )

  if (nchar(tag_id) > 0) {
    body$applied_tags <- list(tag_id)
  }

  discord_send(webhook_url, body)
}
```

**Step 2: Verify syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('R/discord_webhook.R')"`
Expected: No errors

**Step 3: Commit**

```bash
git add R/discord_webhook.R
git commit -m "feat: add discord_post_data_error and discord_post_bug_report webhook functions"
```

---

### Task 2: Add environment variables to `.env.example`

**Files:**
- Modify: `.env.example:33` (append after existing Discord vars)

**Step 1: Add new env vars**

After the existing `DISCORD_TAG_NEW_REQUEST=` line, append:

```
DISCORD_WEBHOOK_BUG_REPORTS=
# Tag ID for "New" in #bug-reports Forum (right-click tag → Copy ID with Developer Mode on)
DISCORD_TAG_NEW_BUG=
```

**Step 2: Commit**

```bash
git add .env.example
git commit -m "chore: add DISCORD_WEBHOOK_BUG_REPORTS and DISCORD_TAG_NEW_BUG env vars"
```

---

### Task 3: Replace "Report Error" buttons in player, tournament, and deck meta modals

**Files:**
- Modify: `server/public-players-server.R:395-408` (player modal footer)
- Modify: `server/public-tournaments-server.R:176-189` (tournament modal footer)
- Modify: `server/public-meta-server.R:241-254` (deck meta modal footer)

**Context:** Each of these three modals has the same footer pattern:

```r
footer = tagList(
  tags$button(type = "button", class = "btn btn-outline-secondary me-auto",
    onclick = "copyCurrentUrl()",
    bsicons::bs_icon("link-45deg"), " Copy Link"),
  tags$a(href = LINKS$discord, target = "_blank",
    class = "btn btn-outline-secondary",
    bsicons::bs_icon("flag"), " Report Error"),
  modalButton("Close")
),
```

Replace the `tags$a(href = LINKS$discord ...)` Report Error link with an `actionButton` that triggers a data error report modal. Each modal needs a unique button ID to avoid conflicts.

**Step 1: Update player modal footer** (`server/public-players-server.R`)

Replace lines 402-406:
```r
      tags$a(
        href = LINKS$discord, target = "_blank",
        class = "btn btn-outline-secondary",
        bsicons::bs_icon("flag"), " Report Error"
      ),
```

With:
```r
      actionButton("report_error_player", tagList(bsicons::bs_icon("flag"), " Report Error"),
                   class = "btn btn-outline-secondary btn-sm"),
```

**Step 2: Update tournament modal footer** (`server/public-tournaments-server.R`)

Replace lines 183-187:
```r
      tags$a(
        href = LINKS$discord, target = "_blank",
        class = "btn btn-outline-secondary",
        bsicons::bs_icon("flag"), " Report Error"
      ),
```

With:
```r
      actionButton("report_error_tournament", tagList(bsicons::bs_icon("flag"), " Report Error"),
                   class = "btn btn-outline-secondary btn-sm"),
```

**Step 3: Update deck meta modal footer** (`server/public-meta-server.R`)

Replace lines 248-252:
```r
      tags$a(
        href = LINKS$discord, target = "_blank",
        class = "btn btn-outline-secondary",
        bsicons::bs_icon("flag"), " Report Error"
      ),
```

With:
```r
      actionButton("report_error_deck", tagList(bsicons::bs_icon("flag"), " Report Error"),
                   class = "btn btn-outline-secondary btn-sm"),
```

**Step 4: Verify syntax for all three files**

Run:
```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/public-players-server.R')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/public-tournaments-server.R')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/public-meta-server.R')"
```
Expected: No errors

**Step 5: Commit**

```bash
git add server/public-players-server.R server/public-tournaments-server.R server/public-meta-server.R
git commit -m "refactor: replace static Report Error links with actionButton triggers"
```

---

### Task 4: Add data error report modal and handlers

**Files:**
- Modify: `server/shared-server.R` (append data error modal + handlers at end of navigation section, before any admin sections)

**Context:** The data error modal is shared — triggered from player, tournament, or deck modals. It pre-fills item type and name, collects a description and optional Discord username, and sends to the scene's coordination thread.

We need reactive state to track which item opened the error modal. We also need the scene_id for routing. The `rv$current_scene` holds the scene slug (e.g., "dfw"), not the ID. We'll look up the scene_id from the slug.

**Step 1: Add data error report modal + handlers to `server/shared-server.R`**

Find the end of the Navigation section (around line 100-120, after the last `observeEvent` for nav). Add a new section:

```r
# ---------------------------------------------------------------------------
# Data Error Report Modal (shared across player/tournament/deck modals)
# ---------------------------------------------------------------------------

# Reactive to store context for the data error report
data_error_context <- reactiveValues(
  item_type = NULL,
  item_name = NULL
)

# Player modal → data error report
observeEvent(input$report_error_player, {
  player <- tryCatch(
    safe_query(db_pool,
      "SELECT display_name FROM players WHERE player_id = $1",
      params = list(rv$selected_player_id),
      default = data.frame()),
    error = function(e) data.frame()
  )
  data_error_context$item_type <- "Player"
  data_error_context$item_name <- if (nrow(player) > 0) player$display_name[1] else "Unknown"
  show_data_error_modal(data_error_context$item_type, data_error_context$item_name)
})

# Tournament modal → data error report
observeEvent(input$report_error_tournament, {
  tourn <- tryCatch(
    safe_query(db_pool,
      "SELECT t.event_date, s.store_name
       FROM tournaments t JOIN stores s ON t.store_id = s.store_id
       WHERE t.tournament_id = $1",
      params = list(rv$selected_tournament_id),
      default = data.frame()),
    error = function(e) data.frame()
  )
  data_error_context$item_type <- "Tournament"
  data_error_context$item_name <- if (nrow(tourn) > 0) {
    paste0(tourn$store_name[1], " - ", tourn$event_date[1])
  } else "Unknown"
  show_data_error_modal(data_error_context$item_type, data_error_context$item_name)
})

# Deck modal → data error report
observeEvent(input$report_error_deck, {
  deck <- tryCatch(
    safe_query(db_pool,
      "SELECT archetype_name FROM deck_archetypes WHERE archetype_id = $1",
      params = list(rv$selected_archetype_id),
      default = data.frame()),
    error = function(e) data.frame()
  )
  data_error_context$item_type <- "Deck"
  data_error_context$item_name <- if (nrow(deck) > 0) deck$archetype_name[1] else "Unknown"
  show_data_error_modal(data_error_context$item_type, data_error_context$item_name)
})

# Helper to show the data error modal
show_data_error_modal <- function(item_type, item_name) {
  showModal(modalDialog(
    title = tagList(bsicons::bs_icon("flag"), " Report Data Error"),
    div(
      div(class = "mb-3 p-2 rounded", style = "background: rgba(255,255,255,0.05);",
        tags$small(class = "text-muted", "Reporting error for:"),
        tags$div(class = "fw-bold", paste(item_type, "-", item_name))
      ),
      textAreaInput("data_error_description", "What's wrong?",
                    placeholder = "Describe the error (e.g., 'Deck should be Blue Flare, not Jesmon')",
                    rows = 3),
      textInput("data_error_discord", "Your Discord Username (optional)",
                placeholder = "So we can follow up")
    ),
    footer = tagList(
      modalButton("Cancel"),
      actionButton("submit_data_error", "Submit Report", class = "btn-primary")
    ),
    size = "m",
    easyClose = TRUE
  ))
}

# Handle data error submission
observeEvent(input$submit_data_error, {
  description <- trimws(input$data_error_description)

  if (nchar(description) == 0) {
    notify("Please describe the error", type = "warning")
    return()
  }

  tryCatch({
    # Look up scene_id from current scene slug
    scene_id <- NULL
    if (!is.null(rv$current_scene) && rv$current_scene != "all") {
      scene_row <- safe_query(db_pool,
        "SELECT scene_id FROM scenes WHERE slug = $1",
        params = list(rv$current_scene),
        default = data.frame())
      if (nrow(scene_row) > 0) scene_id <- scene_row$scene_id[1]
    }

    discord_username <- trimws(input$data_error_discord)

    if (!is.null(scene_id)) {
      discord_post_data_error(
        scene_id = scene_id,
        item_type = data_error_context$item_type,
        item_name = data_error_context$item_name,
        description = description,
        discord_username = discord_username,
        db_pool = db_pool
      )
    } else {
      # No scene context — fall back to bug report
      discord_post_bug_report(
        title = paste("Data Error:", data_error_context$item_type, "-", data_error_context$item_name),
        description = description,
        context = paste("Tab:", rv$current_nav),
        discord_username = discord_username
      )
    }

    removeModal()
    notify("Error report submitted! Thank you for helping improve DigiLab.", type = "message", duration = 5)
  }, error = function(e) {
    warning(paste("Data error report failed:", e$message))
    removeModal()
    notify("Report received but couldn't send to Discord. We'll follow up manually.", type = "warning", duration = 5)
  })
})
```

**Step 2: Verify syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/shared-server.R')"`
Expected: No errors

**Step 3: Commit**

```bash
git add server/shared-server.R
git commit -m "feat: add data error report modal and webhook handlers"
```

---

### Task 5: Add bug report modal and footer trigger

**Files:**
- Modify: `app.R:862-874` (footer nav — add "Report a Bug" link)
- Modify: `server/shared-server.R` (append bug report modal + handler after data error section)

**Step 1: Add "Report a Bug" link to footer** in `app.R`

In the footer `tags$nav`, add a new link before the GitHub icon. Replace lines 866-874:

```r
      actionLink("nav_for_tos", "For Organizers", class = "footer-link"),
      span(class = "footer-divider", "//"),
      tags$a(
        href = LINKS$github,
        target = "_blank",
        class = "footer-link footer-icon-link",
        title = "View on GitHub",
        bsicons::bs_icon("github")
      )
```

With:

```r
      actionLink("nav_for_tos", "For Organizers", class = "footer-link"),
      span(class = "footer-divider", "//"),
      actionLink("open_bug_report", tagList(bsicons::bs_icon("bug"), " Report a Bug"),
                 class = "footer-link"),
      span(class = "footer-divider", "//"),
      tags$a(
        href = LINKS$github,
        target = "_blank",
        class = "footer-link footer-icon-link",
        title = "View on GitHub",
        bsicons::bs_icon("github")
      )
```

**Step 2: Add bug report modal + handler to `server/shared-server.R`**

Append after the data error report section:

```r
# ---------------------------------------------------------------------------
# Bug Report Modal (general bugs — footer + content pages)
# ---------------------------------------------------------------------------

observeEvent(input$open_bug_report, {
  show_bug_report_modal()
})

# For Organizers page triggers
observeEvent(input$tos_open_bug_report, {
  show_bug_report_modal()
})

# FAQ page trigger
observeEvent(input$faq_open_bug_report, {
  show_bug_report_modal()
})

show_bug_report_modal <- function() {
  showModal(modalDialog(
    title = tagList(bsicons::bs_icon("bug"), " Report a Bug"),
    div(
      textInput("bug_report_title", "Title",
                placeholder = "Brief summary of the issue"),
      textAreaInput("bug_report_description", "What happened?",
                    placeholder = "What were you trying to do? What went wrong?",
                    rows = 4),
      textInput("bug_report_discord", "Your Discord Username (optional)",
                placeholder = "So we can follow up")
    ),
    footer = tagList(
      modalButton("Cancel"),
      actionButton("submit_bug_report", "Submit Report", class = "btn-primary")
    ),
    size = "m",
    easyClose = TRUE
  ))
}

# Handle bug report submission
observeEvent(input$submit_bug_report, {
  title <- trimws(input$bug_report_title)
  description <- trimws(input$bug_report_description)

  if (nchar(title) == 0) {
    notify("Please provide a title", type = "warning")
    return()
  }
  if (nchar(description) == 0) {
    notify("Please describe the issue", type = "warning")
    return()
  }

  tryCatch({
    context_parts <- c()
    if (!is.null(rv$current_nav)) context_parts <- c(context_parts, paste("Tab:", rv$current_nav))
    if (!is.null(rv$current_scene) && rv$current_scene != "all") {
      context_parts <- c(context_parts, paste("Scene:", rv$current_scene))
    }
    context <- paste(context_parts, collapse = ", ")

    discord_username <- trimws(input$bug_report_discord)

    discord_post_bug_report(
      title = title,
      description = description,
      context = context,
      discord_username = discord_username
    )

    removeModal()
    notify("Bug report submitted! Thank you for helping improve DigiLab.", type = "message", duration = 5)
  }, error = function(e) {
    warning(paste("Bug report failed:", e$message))
    removeModal()
    notify("Report received but couldn't send to Discord. We'll follow up manually.", type = "warning", duration = 5)
  })
})
```

**Step 3: Verify syntax**

Run:
```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('app.R')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/shared-server.R')"
```
Expected: No errors

**Step 4: Commit**

```bash
git add app.R server/shared-server.R
git commit -m "feat: add bug report modal with footer trigger and webhook handler"
```

---

### Task 6: Update For Organizers page to trigger bug report modal

**Files:**
- Modify: `views/for-tos-ui.R:386-427` (Report an Error section)

**Step 1: Replace the Discord link with an actionLink that opens the bug report modal**

Replace the current "Report an Error" accordion (lines 386-427):

```r
  h2(class = "faq-category", bsicons::bs_icon("exclamation-triangle"), "Report an Error"),
  accordion(
    id = "tos_errors",
    open = FALSE,
    accordion_panel(
      title = "How to report data errors",
      value = "report-error",
      icon = bsicons::bs_icon("flag"),
      p("Spotted something wrong? We want to fix it! Common errors include:"),
      tags$ul(
        tags$li("Incorrect tournament results or placements"),
        tags$li("Wrong deck archetype assignments"),
        tags$li("Duplicate player entries"),
        tags$li("Incorrect store information")
      ),
      p("To report an error:"),
      tags$ol(
        class = "steps-list",
        tags$li(
          strong("Identify the issue"),
          p("Note which tournament, player, or store has the error.")
        ),
        tags$li(
          strong("Provide correct information"),
          p("If you know what it should be, include that in your report.")
        ),
        tags$li(
          strong("Submit your report"),
          p("Reach out on Discord with the details.")
        )
      ),
      div(
        class = "contact-links",
        tags$a(
          class = "contact-link",
          href = LINKS$discord,
          target = "_blank",
          bsicons::bs_icon("discord"), "Report on Discord"
        )
      )
    )
  ),
```

With:

```r
  h2(class = "faq-category", bsicons::bs_icon("exclamation-triangle"), "Report an Error"),
  accordion(
    id = "tos_errors",
    open = FALSE,
    accordion_panel(
      title = "How to report data errors",
      value = "report-data-error",
      icon = bsicons::bs_icon("flag"),
      p("Spotted something wrong with a tournament result, player record, or deck assignment? ",
        "You can report errors directly from the item itself:"),
      tags$ul(
        tags$li("Open the player, tournament, or deck modal"),
        tags$li("Click the ", tags$strong("Report Error"), " button in the modal footer"),
        tags$li("Describe what's wrong and submit — it goes straight to the scene admin")
      ),
      p(class = "info-note",
        bsicons::bs_icon("info-circle"),
        " Reports are routed to your scene's coordination channel on Discord for fast resolution.")
    ),
    accordion_panel(
      title = "How to report a bug",
      value = "report-bug",
      icon = bsicons::bs_icon("bug"),
      p("Found a bug or something not working right? Let us know:"),
      tags$ul(
        tags$li("What you were trying to do"),
        tags$li("What you expected to happen"),
        tags$li("What actually happened"),
        tags$li("Screenshots if possible")
      ),
      div(
        class = "contact-links",
        actionLink("tos_open_bug_report",
          tagList(bsicons::bs_icon("bug"), " Report a Bug"),
          class = "contact-link"
        )
      )
    )
  ),
```

**Step 2: Verify syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('views/for-tos-ui.R')"`
Expected: No errors

**Step 3: Commit**

```bash
git add views/for-tos-ui.R
git commit -m "feat: update For Organizers error section with data error + bug report guidance"
```

---

### Task 7: Update FAQ page to trigger bug report modal

**Files:**
- Modify: `views/faq-ui.R:381-401` (bug report accordion panel)

**Step 1: Replace Discord link with actionLink**

Replace the existing "I found a bug" panel content (lines 381-401):

```r
    accordion_panel(
      title = "I found a bug! How do I report it?",
      value = "bugs",
      icon = bsicons::bs_icon("bug"),
      p("Thank you for helping improve DigiLab! We appreciate bug reports."),
      p(strong("What to include:")),
      tags$ul(
        tags$li("What you were trying to do"),
        tags$li("What you expected to happen"),
        tags$li("What actually happened"),
        tags$li("Screenshots if possible")
      ),
      div(
        class = "contact-links",
        tags$a(
          class = "contact-link",
          href = LINKS$discord,
          target = "_blank",
          bsicons::bs_icon("discord"), "Report on Discord"
        )
      )
    ),
```

With:

```r
    accordion_panel(
      title = "I found a bug! How do I report it?",
      value = "bugs",
      icon = bsicons::bs_icon("bug"),
      p("Thank you for helping improve DigiLab! We appreciate bug reports."),
      p(strong("What to include:")),
      tags$ul(
        tags$li("What you were trying to do"),
        tags$li("What you expected to happen"),
        tags$li("What actually happened"),
        tags$li("Screenshots if possible")
      ),
      div(
        class = "contact-links",
        actionLink("faq_open_bug_report",
          tagList(bsicons::bs_icon("bug"), " Report a Bug"),
          class = "contact-link"
        )
      )
    ),
```

**Step 2: Verify syntax**

Run: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('views/faq-ui.R')"`
Expected: No errors

**Step 3: Commit**

```bash
git add views/faq-ui.R
git commit -m "feat: update FAQ bug report section to open bug report modal"
```

---

### Task 8: Manual testing

**No files modified. Testing only.**

**Step 1: Set environment variables**

In your `.env` file, add:
```
DISCORD_WEBHOOK_BUG_REPORTS=<your #bug-reports Forum webhook URL>
DISCORD_TAG_NEW_BUG=<your "New" tag ID from #bug-reports>
```

The existing `DISCORD_WEBHOOK_SCENE_COORDINATION` should already be set from the store request webhook.

**Step 2: Test data error report from player modal**

1. Open the app: `shiny::runApp()`
2. Go to Players tab, click a player to open their modal
3. Verify "Report Error" button is smaller (`btn-sm`) and styled as `btn-outline-secondary`
4. Click "Report Error" — modal should open with "Report Data Error" title
5. Verify pre-filled context shows "Player - [PlayerName]"
6. Type a description, optionally add Discord username
7. Submit — verify success notification
8. Check Discord scene coordination thread for the message (or #bug-reports if no scene selected)

**Step 3: Test data error report from tournament modal**

1. Go to Tournaments tab, click a tournament
2. Verify "Report Error" button is present and styled
3. Click → verify pre-filled context shows "Tournament - [StoreName] - [Date]"
4. Submit → check Discord

**Step 4: Test data error report from deck meta modal**

1. Go to Meta tab, click a deck archetype
2. Verify "Report Error" button is present and styled
3. Click → verify pre-filled context shows "Deck - [ArchetypeName]"
4. Submit → check Discord

**Step 5: Test bug report from footer**

1. Look at footer — verify "Report a Bug" link with bug icon appears between "For Organizers" and GitHub icon
2. Click "Report a Bug" — modal should open with bug icon + "Report a Bug" title
3. Fill in title and description
4. Submit → check Discord #bug-reports Forum for a new post titled "Bug: [title]"

**Step 6: Test bug report from For Organizers page**

1. Go to For Organizers page (footer link)
2. Open "Report an Error" section
3. Verify two sub-panels: "How to report data errors" and "How to report a bug"
4. Click "Report a Bug" button → verify bug report modal opens

**Step 7: Test bug report from FAQ page**

1. Go to FAQ page
2. Open "I found a bug! How do I report it?"
3. Click "Report a Bug" → verify bug report modal opens

**Step 8: Test validation**

1. Open bug report modal, try to submit with empty title → verify warning
2. Try to submit with empty description → verify warning
3. Open data error modal, try to submit with empty description → verify warning
