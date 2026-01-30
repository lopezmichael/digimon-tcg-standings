# UI Polish Sprint Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Polish UI across navbar, sidebar, overview page, and data pages with filter alignment fixes, chart improvements, and table enhancements.

**Architecture:** CSS-first approach for styling, R code changes for behavior/data. Changes are isolated to specific files per task.

**Tech Stack:** R Shiny, bslib, Highcharter, reactable, Bootstrap Icons, CSS

---

## Task 1: Navbar - Change Icon and Name

**Files:**
- Modify: `app.R:245-246`

**Changes:**

1. Change controller icon to egg icon
2. Rename "Digimon TCG" to "DFW Digimon" (keeps it regional and shorter)

**Current code (app.R:245-246):**
```r
span(bsicons::bs_icon("controller"), class = "header-icon"),
span("Digimon TCG", class = "header-title-text")
```

**New code:**
```r
span(bsicons::bs_icon("egg"), class = "header-icon"),
span("Digimon Locals Meta Tracker", class = "header-title-text")
```

**Note:** Bootstrap Icons has `egg`, `egg-fill`, and `egg-fried`. Using `egg` for clean outline style.

**Verify:** Run app and check navbar shows egg icon and "Digimon Locals Meta Tracker" text.

---

## Task 2: Sidebar - Add Digimon TCG Logo

**Files:**
- Modify: `app.R:261-265` (sidebar definition)
- Modify: `www/custom.css` (add logo styles)

**Step 1: Update sidebar to include logo image**

**Current code (app.R:261-265):**
```r
sidebar = sidebar(
  id = "main_sidebar",
  title = "Menu",
  width = 220,
  bg = "#0A3055",
```

**New code:**
```r
sidebar = sidebar(
  id = "main_sidebar",
  title = NULL,  # Remove the "Menu" title
  width = 220,
  bg = "#0A3055",

  # Digimon TCG Logo (saved locally in www/)
  div(
    class = "sidebar-logo-container",
    tags$img(
      src = "digimon-logo.png",
      class = "sidebar-logo",
      alt = "Digimon TCG"
    )
  ),
```

**Step 2: Add CSS for logo styling**

Add to `www/custom.css` after the sidebar section (around line 126):

```css
/* Sidebar Logo */
.sidebar-logo-container {
  padding: 0.75rem 0.5rem 1rem 0.5rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  margin-bottom: 0.75rem;
}

.sidebar-logo {
  width: 100%;
  max-width: 180px;
  height: auto;
  display: block;
  margin: 0 auto;
}
```

**Step 3: Update the nav-section-label for Admin to match the old "Menu" style**

The Admin section label should stay as-is - it already uses `.nav-section-label` class which has small uppercase styling matching what the old "Menu" title had.

**Verify:** Run app and check sidebar shows Digimon TCG logo at top, no "Menu" text, navigation links below.

---

## Task 3: Overview Page - Fix Reset Button Alignment

**Files:**
- Modify: `views/dashboard-ui.R:54-59`

**Problem:** Reset button not vertically aligned with dropdown filters.

**Current code (dashboard-ui.R:54-59):**
```r
div(
  style = "margin-top: 1.5rem;",
  actionButton("reset_dashboard_filters", "Reset",
               class = "btn-outline-secondary",
               style = "height: 38px;")
)
```

**New code:**
```r
div(
  style = "padding-top: 1.5rem;",
  actionButton("reset_dashboard_filters", "Reset",
               class = "btn-outline-secondary",
               style = "height: 38px;")
)
```

**Note:** Using `padding-top` instead of `margin-top` to match other pages (players, meta, tournaments) which use `padding-top: 1.5rem;`.

**Verify:** Run app and check Reset button aligns with dropdown bottoms on Overview page.

---

## Task 4: Overview Page - Auto-Select Most Recent Format

**Files:**
- Modify: `server/shared-server.R:204`

**Problem:** Dashboard format defaults to "All Formats" but should default to most recent active format.

**Current code (shared-server.R:204):**
```r
updateSelectInput(session, "dashboard_format", choices = format_choices_with_all)
```

**New code:**
```r
updateSelectInput(session, "dashboard_format", choices = format_choices_with_all, selected = first_format)
```

**Note:** `first_format` is already defined on line 195 as the first format from `get_format_choices()` which returns formats ordered by `release_date DESC`. This ensures the most recently released active format is auto-selected.

**Verify:** Run app, check Overview page defaults to most recent format (not "All Formats").

---

## Task 5: Overview Page - Remove X-Axis Label from Color Distribution Chart

**Files:**
- Modify: `app.R:987`

**Problem:** Color distribution chart shows redundant x-axis with color names that are already visible as bar labels.

**Current code (app.R:987):**
```r
hc_xAxis(categories = result$color, title = list(text = NULL)) |>
```

**New code:**
```r
hc_xAxis(categories = result$color, title = list(text = NULL), labels = list(enabled = FALSE)) |>
```

**Verify:** Run app, check Color Distribution chart no longer shows color names on x-axis.

---

## Task 6: Overview Page - Cap Meta Share Chart Y-Axis at 100%

**Files:**
- Modify: `app.R:741-744`

**Problem:** Meta share chart y-axis goes to 125% but max should be 100%.

**Current code (app.R:741-744):**
```r
hc_yAxis(
  title = list(text = "Meta Share"),
  labels = list(format = "{value}%"),
  min = 0
) |>
```

**New code:**
```r
hc_yAxis(
  title = list(text = "Meta Share"),
  labels = list(format = "{value}%"),
  min = 0,
  max = 100
) |>
```

**Verify:** Run app, check Meta Share Over Time chart y-axis goes 0-100% only.

---

## Task 7: Overview Page - Fix Most Popular Deck Text Overflow

**Files:**
- Modify: `www/custom.css:272-276`

**Problem:** Long deck names don't fit in the "Most Popular Deck" value box.

**Current code (custom.css:272-276):**
```css
/* Allow text wrapping for deck names (4th value box) */
.overview-value-boxes .bslib-value-box:nth-child(4) .value-box-value {
  white-space: normal;
  font-size: clamp(0.9rem, 2.5vw, 1.4rem) !important;
  word-wrap: break-word;
}
```

**New code:**
```css
/* Allow text wrapping for deck names (4th value box) */
.overview-value-boxes .bslib-value-box:nth-child(4) .value-box-value {
  white-space: normal;
  font-size: clamp(0.75rem, 2vw, 1.1rem) !important;
  word-wrap: break-word;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  line-height: 1.3;
}
```

**Verify:** Run app, check long deck names in Most Popular Deck box wrap to 2 lines max with ellipsis if needed.

---

## Task 8: Overview Page - Resize Value Box Elements

**Files:**
- Modify: `www/custom.css:257-288`

**Goal:** Make titles smaller, numbers/icons bigger in value boxes.

**Replace the value box CSS section (lines 257-288) with:**

```css
/* Responsive font sizes - scales smoothly across all screen widths */
.bslib-value-box .value-box-title {
  font-size: clamp(0.6rem, 1.5vw, 0.75rem) !important;
  line-height: 1.2;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  opacity: 0.85;
  margin-bottom: 0.25rem !important;
}

.bslib-value-box .value-box-value {
  font-size: clamp(1.4rem, 4vw, 2.2rem) !important;
  line-height: 1.1;
  font-weight: 700;
}

/* Allow text wrapping for deck names (4th value box) */
.overview-value-boxes .bslib-value-box:nth-child(4) .value-box-value {
  white-space: normal;
  font-size: clamp(0.75rem, 2vw, 1.1rem) !important;
  word-wrap: break-word;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  line-height: 1.3;
}

/* Keep numeric values on single line */
.overview-value-boxes .bslib-value-box:nth-child(-n+3) .value-box-value {
  white-space: nowrap;
}

/* Give more space to showcase (icons and card images) */
.bslib-value-box .value-box-showcase {
  font-size: clamp(1.5rem, 5vw, 3rem) !important;
  opacity: 1;
  flex-shrink: 0;
}

/* For value boxes with card images - give showcase more width */
.bslib-value-box .value-box-showcase img {
  max-height: 90px !important;
  width: auto !important;
  object-fit: contain;
  border-radius: 6px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

.bslib-value-box p {
  font-size: clamp(0.6rem, 1.3vw, 0.75rem) !important;
  line-height: 1.2;
  margin-bottom: 0 !important;
}
```

**Verify:** Run app, check value boxes have smaller titles, larger numbers and icons.

---

## Task 9: Players Page - Fix Reset Button & Search Box Height

**Files:**
- Modify: `views/players-ui.R:10-26`

**Problem:** Reset button not aligned, search box shorter than dropdowns.

**Current code (players-ui.R:10-26):**
```r
div(
  class = "dashboard-filters mb-3",
  layout_columns(
    col_widths = c(4, 3, 3, 2),
    textInput("players_search", "Search Player", placeholder = "Type a name..."),
    selectInput("players_format", "Format",
                choices = list("Loading..." = ""),
                selected = ""),
    selectInput("players_min_events", "Min Events",
                choices = c("Any" = 0, "2+" = 2, "3+" = 3, "5+" = 5, "10+" = 10),
                selected = 0),
    div(
      style = "padding-top: 1.5rem;",
      actionButton("reset_players_filters", "Reset",
                   class = "btn-outline-secondary",
                   style = "height: 38px;")
    )
  )
),
```

**New code:**
```r
div(
  class = "dashboard-filters mb-3",
  layout_columns(
    col_widths = c(4, 3, 3, 2),
    selectizeInput("players_search", "Search Player",
                   choices = NULL,
                   options = list(placeholder = "Type a name...", create = FALSE)),
    selectInput("players_format", "Format",
                choices = list("Loading..." = ""),
                selected = ""),
    selectInput("players_min_events", "Min Events",
                choices = c("Any" = 0, "2+" = 2, "3+" = 3, "5+" = 5, "10+" = 10),
                selected = 0),
    div(
      style = "padding-top: 1.5rem;",
      actionButton("reset_players_filters", "Reset",
                   class = "btn-outline-secondary",
                   style = "height: 38px;")
    )
  )
),
```

**Note:** Changed `textInput` to `selectizeInput` for consistent height with other dropdowns. The selectize input can still accept free text input.

**Also update reset handler in app.R:1722-1725:**

**Current:**
```r
observeEvent(input$reset_players_filters, {
  updateTextInput(session, "players_search", value = "")
```

**New:**
```r
observeEvent(input$reset_players_filters, {
  updateSelectizeInput(session, "players_search", selected = "")
```

**Verify:** Run app, check Players page search box matches dropdown heights, Reset button aligned.

---

## Task 10: Players Page - Add Rating Column

**Files:**
- Modify: `app.R:1743-1784`

**Goal:** Add weighted rating calculation and column to player standings table and modal.

**Step 1: Update the query (app.R:1743-1758)**

**Current query:**
```r
result <- dbGetQuery(rv$db_con, sprintf("
  SELECT p.player_id, p.display_name as Player,
         COUNT(DISTINCT r.tournament_id) as Events,
         SUM(r.wins) as W, SUM(r.losses) as L, SUM(r.ties) as T,
         ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%',
         COUNT(CASE WHEN r.placement = 1 THEN 1 END) as '1st',
         COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as 'Top 3'
  FROM players p
  JOIN results r ON p.player_id = r.player_id
  JOIN tournaments t ON r.tournament_id = t.tournament_id
  WHERE 1=1 %s %s
  GROUP BY p.player_id, p.display_name
  HAVING COUNT(DISTINCT r.tournament_id) >= %d
  ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC,
           ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) DESC
", search_filter, format_filter, min_events))
```

**New query:**
```r
result <- dbGetQuery(rv$db_con, sprintf("
  SELECT p.player_id, p.display_name as Player,
         COUNT(DISTINCT r.tournament_id) as Events,
         SUM(r.wins) as W, SUM(r.losses) as L, SUM(r.ties) as T,
         ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%',
         COUNT(CASE WHEN r.placement = 1 THEN 1 END) as '1st',
         COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as 'Top 3',
         COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3_count
  FROM players p
  JOIN results r ON p.player_id = r.player_id
  JOIN tournaments t ON r.tournament_id = t.tournament_id
  WHERE 1=1 %s %s
  GROUP BY p.player_id, p.display_name
  HAVING COUNT(DISTINCT r.tournament_id) >= %d
", search_filter, format_filter, min_events))
```

**Step 2: Add rating calculation after the query (after line 1758):**

```r
if (nrow(result) == 0) {
  return(reactable(data.frame(Message = "No player data matches filters"), compact = TRUE))
}

# Calculate weighted rating
result$win_pct <- result$`Win %`
result$win_pct[is.na(result$win_pct)] <- 0
result$top3_rate <- result$top3_count / result$Events
result$events_bonus <- pmin(result$Events * 2, 20)
result$Rating <- round(
  (result$win_pct * 0.5) +
  (result$top3_rate * 30) +
  result$events_bonus,
  1
)

# Sort by rating
result <- result[order(-result$Rating), ]
```

**Step 3: Update reactable columns (app.R:1773-1783):**

```r
columns = list(
  player_id = colDef(show = FALSE),
  Player = colDef(minWidth = 150),
  Events = colDef(minWidth = 70, align = "center"),
  W = colDef(minWidth = 50, align = "center"),
  L = colDef(minWidth = 50, align = "center"),
  T = colDef(minWidth = 50, align = "center"),
  `Win %` = colDef(minWidth = 70, align = "center"),
  `1st` = colDef(minWidth = 50, align = "center"),
  `Top 3` = colDef(minWidth = 60, align = "center"),
  top3_count = colDef(show = FALSE),
  win_pct = colDef(show = FALSE),
  top3_rate = colDef(show = FALSE),
  events_bonus = colDef(show = FALSE),
  Rating = colDef(minWidth = 70, align = "center")
)
```

**Verify:** Run app, check Players page shows Rating column, sorted by rating descending.

---

## Task 11: Meta Analysis Page - Fix Reset Button & Search Box Height

**Files:**
- Modify: `views/meta-ui.R:10-26`
- Modify: `app.R:1991-1993`

**Apply same pattern as Task 9:**

**New code (meta-ui.R:10-26):**
```r
div(
  class = "dashboard-filters mb-3",
  layout_columns(
    col_widths = c(4, 3, 3, 2),
    selectizeInput("meta_search", "Search Deck",
                   choices = NULL,
                   options = list(placeholder = "Type a deck name...", create = FALSE)),
    selectInput("meta_format", "Format",
                choices = list("Loading..." = ""),
                selected = ""),
    selectInput("meta_min_entries", "Min Entries",
                choices = c("Any" = 0, "2+" = 2, "5+" = 5, "10+" = 10, "20+" = 20),
                selected = 2),
    div(
      style = "padding-top: 1.5rem;",
      actionButton("reset_meta_filters", "Reset",
                   class = "btn-outline-secondary",
                   style = "height: 38px;")
    )
  )
),
```

**Update reset handler (app.R:1991-1993):**
```r
observeEvent(input$reset_meta_filters, {
  updateSelectizeInput(session, "meta_search", selected = "")
  updateSelectInput(session, "meta_format", selected = "")
  updateSelectInput(session, "meta_min_entries", selected = 2)
})
```

**Verify:** Run app, check Meta Analysis page search box matches dropdown heights, Reset button aligned.

---

## Task 12: Meta Analysis Page - Debug Empty Archetype Performance

**Files:**
- Investigate: `app.R:2012-2026`

**Debug steps:**

1. The query joins `deck_archetypes` with `results` and `tournaments`
2. Check if tournaments have been entered with results that link to archetypes
3. The `HAVING COUNT(r.result_id) >= %d` filter defaults to `min_entries = 2`

**Likely issue:** Results may not have `archetype_id` set, or the min entries filter is too high.

**Fix: Change default min entries from 2 to 0**

In `views/meta-ui.R`, change:
```r
selected = 2
```
to:
```r
selected = 0
```

Or add debug logging temporarily to see what data exists.

**Verify:** Run app with min entries set to "Any", check if decks appear. If still empty, check database for results with archetype_id.

---

## Task 13: Tournament History Page - Fix Reset Button & Search Box Height

**Files:**
- Modify: `views/tournaments-ui.R:10-29`
- Modify: `app.R:2290-2293`

**Apply same pattern as Tasks 9 and 11:**

**New code (tournaments-ui.R:10-29):**
```r
div(
  class = "dashboard-filters mb-3",
  layout_columns(
    col_widths = c(4, 3, 3, 2),
    selectizeInput("tournaments_search", "Search Store",
                   choices = NULL,
                   options = list(placeholder = "Type a store name...", create = FALSE)),
    selectInput("tournaments_format", "Format",
                choices = list("Loading..." = ""),
                selected = ""),
    selectInput("tournaments_event_type", "Event Type",
                choices = list(
                  "All Events" = "",
                  "Event Types" = EVENT_TYPES
                ),
                selected = ""),
    div(
      style = "padding-top: 1.5rem;",
      actionButton("reset_tournaments_filters", "Reset",
                   class = "btn-outline-secondary",
                   style = "height: 38px;")
    )
  )
),
```

**Update reset handler (app.R:2290-2293):**
```r
observeEvent(input$reset_tournaments_filters, {
  updateSelectizeInput(session, "tournaments_search", selected = "")
  updateSelectInput(session, "tournaments_format", selected = "")
  updateSelectInput(session, "tournaments_event_type", selected = "")
})
```

**Verify:** Run app, check Tournaments page search box matches dropdown heights, Reset button aligned.

---

## Task 14: Tournament History Page - Auto-Sort by Date

**Files:**
- Modify: `app.R:2341-2361`

**Goal:** Sort tournaments table by date descending by default.

**Current code (app.R:2341-2361):**
```r
reactable(
  result,
  compact = TRUE,
  striped = TRUE,
  pagination = TRUE,
  defaultPageSize = 20,
  selection = "single",
  onClick = "select",
  rowStyle = list(cursor = "pointer"),
  columns = list(
    ...
  )
)
```

**New code:**
```r
reactable(
  result,
  compact = TRUE,
  striped = TRUE,
  pagination = TRUE,
  defaultPageSize = 20,
  defaultSorted = list(Date = "desc"),
  selection = "single",
  onClick = "select",
  rowStyle = list(cursor = "pointer"),
  columns = list(
    ...
  )
)
```

**Verify:** Run app, check Tournament History table is sorted by Date descending by default.

---

## Summary of Changes

| File | Tasks |
|------|-------|
| `app.R` | 1, 4, 5, 6, 9, 10, 11, 13, 14 |
| `views/dashboard-ui.R` | 3 |
| `views/players-ui.R` | 9 |
| `views/meta-ui.R` | 11, 12 |
| `views/tournaments-ui.R` | 13 |
| `www/custom.css` | 2, 7, 8 |
| `server/shared-server.R` | 4 |

---

## Commit Strategy

Commit after completing related groups:
1. **Navbar & Sidebar** (Tasks 1-2): `fix: Update navbar icon/name and add sidebar logo`
2. **Overview Page** (Tasks 3-8): `fix: Polish overview page filters, charts, and value boxes`
3. **Players Page** (Tasks 9-10): `feat: Add rating column and fix filter alignment on Players page`
4. **Meta & Tournaments** (Tasks 11-14): `fix: Fix filter alignment and sorting on Meta/Tournaments pages`
