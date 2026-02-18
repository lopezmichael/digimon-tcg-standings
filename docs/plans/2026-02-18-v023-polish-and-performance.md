# v0.23 Polish, Performance & Pre-v0.22 Improvements

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship v0.23 by closing loose ends (dynamic scene dropdown, mobile header fix, onboarding simplification), add UX improvements (pill filters, clickable cards, dashboard section split, Ko-fi/admin header changes), optimize performance (connection pooling, batched queries), and add historical format rating snapshots.

**Architecture:** Changes span UI (views, CSS, JS), server logic (query batching, reactive restructuring), and database schema (rating_snapshots table). All work happens on the `develop` branch. Performance changes reduce dashboard queries from 22+ to ~8 by batching queries that share identical JOINs and filters.

**Tech Stack:** R Shiny, bslib, DuckDB, Highcharter, pool (new dependency), custom CSS/JS

---

## Phase 1: Data & Foundation

### Task 1: Sync MotherDuck Data to Local DuckDB

**Files:**
- Run: `scripts/sync_from_motherduck.py`

**Step 1: Verify sync script handles cache tables**

Check that `sync_from_motherduck.py` includes `player_ratings_cache` and `store_ratings_cache` tables. These were added in v0.21.1.

**Step 2: Run the sync**

```bash
python scripts/sync_from_motherduck.py --yes
```

Expected: All tables synced including ratings caches and scenes data.

**Step 3: Verify data**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "
  library(duckdb); con <- dbConnect(duckdb(), 'data/local.duckdb')
  cat('Scenes:', nrow(dbGetQuery(con, 'SELECT * FROM scenes')), '\n')
  cat('Players cache:', nrow(dbGetQuery(con, 'SELECT * FROM player_ratings_cache')), '\n')
  cat('Stores cache:', nrow(dbGetQuery(con, 'SELECT * FROM store_ratings_cache')), '\n')
  cat('Formats:', nrow(dbGetQuery(con, 'SELECT * FROM formats')), '\n')
  dbDisconnect(con)
"
```

**Step 4: Commit**

```bash
git add -A && git commit -m "data: sync from MotherDuck with latest tables"
```

---

### Task 2: Dynamic Scene Dropdown (Load from DB)

**Files:**
- Modify: `app.R` (lines 462-472) — replace hardcoded choices
- Modify: `server/scene-server.R` — add startup scene population

Currently the scene selector in the header has hardcoded choices. It should load from the `scenes` table.

**Step 1: Update app.R header dropdown to start empty**

In `app.R`, replace the hardcoded `selectInput` choices with a placeholder. The server will populate it on startup.

```r
# Replace lines 464-469:
selectInput("scene_selector", NULL,
            choices = list("All Scenes" = "all"),
            selected = "all",
            width = "140px",
            selectize = FALSE)
```

**Step 2: Add server-side population in scene-server.R**

At the top of `scene-server.R`, add an observer that populates the dropdown from the database after connection is established:

```r
# Populate scene dropdown from database
observe({
  req(rv$db_con, DBI::dbIsValid(rv$db_con))

  scenes <- safe_query(rv$db_con,
    "SELECT slug, display_name FROM scenes
     WHERE scene_type = 'metro' AND is_active = TRUE
     ORDER BY display_name",
    default = data.frame(slug = character(), display_name = character()))

  # Build choices: "All Scenes" first, then metro scenes, then "Online"
  choices <- list("All Scenes" = "all")
  if (nrow(scenes) > 0) {
    scene_choices <- setNames(scenes$slug, scenes$display_name)
    choices <- c(choices, as.list(scene_choices))
  }
  choices <- c(choices, list("Online" = "online"))

  # Restore saved preference or default to "all"
  saved <- rv$scene_from_storage
  selected <- if (!is.null(saved) && saved %in% unlist(choices)) saved else "all"

  updateSelectInput(session, "scene_selector", choices = choices, selected = selected)
})
```

**Step 3: Verify R syntax**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('app.R')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/scene-server.R')"
```

**Step 4: Commit**

```bash
git add app.R server/scene-server.R
git commit -m "feat: load scene dropdown dynamically from database"
```

---

## Phase 2: Quick UI Wins

### Task 3: Pill Toggle Filter for Players Tab

**Files:**
- Modify: `views/players-ui.R` — replace `selectInput` with pill HTML
- Modify: `www/custom.css` — add pill toggle styles
- Create: `www/pill-toggle.js` — pill click handler + Shiny binding
- Modify: `app.R` — add JS include
- Modify: `server/public-players-server.R` — update min_events parsing

**Step 1: Create pill-toggle.js**

Create `www/pill-toggle.js`:

```javascript
// pill-toggle.js - Segmented pill toggle control for Shiny
(function() {
  'use strict';

  // Initialize pill toggle: set Shiny input value on click
  $(document).on('click', '.pill-toggle .pill-option', function() {
    var $el = $(this);
    var $group = $el.closest('.pill-toggle');
    var inputId = $group.data('input-id');
    var value = $el.data('value');

    // Update active state
    $group.find('.pill-option').removeClass('active');
    $el.addClass('active');

    // Send to Shiny
    Shiny.setInputValue(inputId, String(value), {priority: 'event'});
  });

  // On Shiny connect, initialize default values
  $(document).on('shiny:connected', function() {
    $('.pill-toggle').each(function() {
      var $group = $(this);
      var inputId = $group.data('input-id');
      var $active = $group.find('.pill-option.active');
      if ($active.length > 0) {
        Shiny.setInputValue(inputId, String($active.data('value')), {priority: 'event'});
      }
    });
  });
})();
```

**Step 2: Add pill CSS to custom.css**

Add to the title strip section of `www/custom.css`:

```css
/* ===== Pill Toggle Controls ===== */
.pill-toggle {
  display: inline-flex;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 6px;
  padding: 2px;
  gap: 2px;
}

.pill-option {
  padding: 0.3rem 0.65rem;
  font-size: 0.75rem;
  font-weight: 600;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.15s ease;
  background: transparent;
  color: rgba(255, 255, 255, 0.7);
  white-space: nowrap;
  line-height: 1.2;
}

.pill-option:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #FFFFFF;
}

.pill-option.active {
  background: rgba(255, 255, 255, 0.9);
  color: #0A3055;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.15);
}

/* Dark mode adjustments */
[data-bs-theme="dark"] .pill-option.active {
  background: rgba(255, 255, 255, 0.85);
  color: #0A3055;
}
```

**Step 3: Update players-ui.R**

Replace the `selectInput` for min events with pill toggle HTML:

```r
# Replace the selectInput block for players_min_events with:
div(
  class = "pill-toggle",
  `data-input-id` = "players_min_events",
  tags$button("All", class = "pill-option", `data-value` = "0"),
  tags$button("5+", class = "pill-option active", `data-value` = "5"),
  tags$button("10+", class = "pill-option", `data-value` = "10")
)
```

**Step 4: Include pill-toggle.js in app.R**

Add to the `tags$head()` section in app.R alongside other JS includes:

```r
tags$script(src = "pill-toggle.js"),
```

**Step 5: Update server/public-players-server.R**

The min_events parsing already handles numeric conversion. Just verify:

```r
min_events <- as.numeric(input$players_min_events)
if (is.na(min_events)) min_events <- 0
```

This works with both the old dropdown values ("", "2", "5") and the new pill values ("0", "5", "10").

**Step 6: Verify syntax and commit**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('views/players-ui.R')"
git add views/players-ui.R www/custom.css www/pill-toggle.js app.R server/public-players-server.R
git commit -m "feat: pill toggle filter for player minimum events (default 5+)"
```

---

### Task 4: Pill Toggle Filter for Meta Tab + Rename to "Deck Meta"

**Files:**
- Modify: `views/meta-ui.R` — replace selectInput with pills, update header text
- Modify: `app.R` — rename sidebar link from "Meta Analysis" to "Deck Meta"
- Modify: `server/public-meta-server.R` — verify min_entries parsing

**Step 1: Update meta-ui.R**

Replace the `selectInput` for `meta_min_entries` with pills and update the page title:

```r
# Change title-strip-text from "Deck Meta Analysis" to "Deck Meta"
tags$span(class = "title-strip-text", "Deck Meta")

# Replace selectInput for meta_min_entries with:
div(
  class = "pill-toggle",
  `data-input-id` = "meta_min_entries",
  tags$button("All", class = "pill-option", `data-value` = "0"),
  tags$button("5+", class = "pill-option active", `data-value` = "5"),
  tags$button("10+", class = "pill-option", `data-value` = "10")
)
```

**Step 2: Update sidebar label in app.R**

Find the nav_meta actionLink and change the label:

```r
# From:
actionLink("nav_meta",
           tagList(bsicons::bs_icon("stack"), " Meta Analysis"),
           class = "nav-link-sidebar"),
# To:
actionLink("nav_meta",
           tagList(bsicons::bs_icon("stack"), " Deck Meta"),
           class = "nav-link-sidebar"),
```

Also update the mobile bottom tab bar if it exists (search for "Meta" in the bottom nav section).

**Step 3: Update server parsing**

In `server/public-meta-server.R`, verify the min_entries parsing handles "0", "5", "10":

```r
min_entries <- as.numeric(input$meta_min_entries)
if (is.na(min_entries)) min_entries <- 0
```

**Step 4: Verify and commit**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('views/meta-ui.R')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('app.R')"
git add views/meta-ui.R app.R server/public-meta-server.R
git commit -m "feat: pill toggle for meta min entries, rename tab to Deck Meta"
```

---

### Task 5: Admin Lock Icon + Ko-fi to Header

**Files:**
- Modify: `app.R` — change admin button, add Ko-fi to header, remove from footer

**Step 1: Update header actions in app.R**

In the `header-actions` div (around line 458-475), change the admin link to icon-only and add Ko-fi:

```r
div(
  class = "header-actions",
  # Admin - lock icon only (no text)
  actionLink("admin_login_link",
             bsicons::bs_icon("lock"),
             class = "header-action-btn",
             title = "Admin Login"),
  # Ko-fi support button (moved from footer)
  tags$a(
    href = "https://ko-fi.com/atomshell",
    target = "_blank",
    class = "header-action-btn header-coffee-btn",
    title = "Support on Ko-fi",
    bsicons::bs_icon("cup-hot")
  ),
  # Scene selector
  div(
    class = "header-scene-selector",
    selectInput("scene_selector", NULL,
                choices = list("All Scenes" = "all"),
                selected = "all",
                width = "140px",
                selectize = FALSE)
  ),
  input_dark_mode(id = "dark_mode", mode = "light")
)
```

**Step 2: Remove Ko-fi from footer**

In the footer section (around line 600-614), remove the Ko-fi link and its preceding divider:

```r
# Remove these lines from footer:
# span(class = "footer-divider", "//"),
# tags$a(
#   href = "https://ko-fi.com/atomshell",
#   target = "_blank",
#   class = "footer-link footer-icon-link",
#   title = "Support on Ko-fi",
#   bsicons::bs_icon("cup-hot")
# )
```

**Step 3: Verify the admin-text CSS still hides on mobile**

The existing CSS `.admin-text { display: none; }` in mobile media query handled the old "Admin" text. Since we removed the text entirely, this is no longer needed but won't cause issues.

**Step 4: Commit**

```bash
git add app.R
git commit -m "feat: admin as lock icon only, move Ko-fi to header"
```

---

### Task 6: Collapse Onboarding to 1 Step

**Files:**
- Modify: `views/onboarding-modal-ui.R` — merge welcome heading into scene picker
- Modify: `server/scene-server.R` — remove step 1 logic, go straight to scene picker
- Modify: `www/custom.css` — remove/simplify welcome step styles

**Step 1: Rewrite onboarding-modal-ui.R**

Replace the entire file with a single-step modal that combines the welcome heading with the scene picker:

```r
# =============================================================================
# Onboarding Modal UI
# Single-step first-visit modal: Welcome + Scene Selection combined
# =============================================================================

#' Onboarding scene picker with welcome heading
#' @param scenes_data Data frame with scene_id, display_name, slug, latitude, longitude
onboarding_ui <- function(scenes_data = NULL) {
  div(
    class = "onboarding-step onboarding-scene-picker",

    # Decorative top accent
    div(class = "onboarding-accent-top"),

    # Welcome heading (merged from old step 1)
    div(
      class = "onboarding-header",
      h2("Welcome to DigiLab"),
      p(class = "onboarding-tagline", "Your Local Digimon TCG Hub")
    ),

    # Brief description
    p(class = "onboarding-description",
      "Select your local scene to see tournaments, players, and deck meta in your area."
    ),

    # Map container
    div(
      class = "onboarding-map-wrapper",
      div(
        class = "onboarding-map-container",
        mapgl::mapboxglOutput("onboarding_map", height = "280px")
      ),
      div(class = "onboarding-map-hint",
          bsicons::bs_icon("hand-index"),
          span("Click a marker to select"))
    ),

    # Find my scene button
    div(
      class = "onboarding-geolocation",
      actionButton("find_my_scene",
                   tagList(bsicons::bs_icon("crosshair"), " Find My Scene"),
                   class = "btn-primary")
    ),

    # Divider
    div(class = "onboarding-divider",
        span("or choose")),

    # Alternative options
    div(
      class = "onboarding-scene-alternatives",
      actionButton("select_scene_online",
                   tagList(bsicons::bs_icon("camera-video-fill"), " Online / Webcam"),
                   class = "btn-outline-secondary"),
      actionButton("select_scene_all",
                   tagList(bsicons::bs_icon("globe2"), " All Scenes"),
                   class = "btn-outline-secondary")
    ),

    # Decorative bottom accent
    div(class = "onboarding-accent-bottom")
  )
}
```

**Step 2: Update scene-server.R**

Find the observer that shows the onboarding modal and remove the step 1 → step 2 transition logic. The modal should now show the single-step UI directly.

Remove the `observeEvent(input$onboarding_get_started, ...)` handler (the "Get Started" button no longer exists).

Remove the `observeEvent(input$onboarding_back, ...)` handler (no "Back" button).

Update the modal creation to use the new `onboarding_ui()` function instead of `onboarding_welcome_ui()`.

**Step 3: Clean up CSS**

In `www/custom.css`, remove the `.onboarding-welcome`-specific styles (feature cards section). Keep all `.onboarding-scene-picker` styles, `.onboarding-header`, `.onboarding-tagline`, `.onboarding-description`, and `.onboarding-accent-*` styles since they're still used.

Remove:
- `.onboarding-features`
- `.onboarding-feature-card` and children
- `.onboarding-cta`

**Step 4: Verify and commit**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('views/onboarding-modal-ui.R')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/scene-server.R')"
git add views/onboarding-modal-ui.R server/scene-server.R www/custom.css
git commit -m "feat: collapse onboarding to single step (welcome + scene picker)"
```

---

## Phase 3: Dashboard Improvements

### Task 7: Dashboard Section Split (Format-Specific vs Community Health)

**Files:**
- Modify: `views/dashboard-ui.R` — add section divider, reorder sections
- Modify: `server/public-dashboard-server.R` — remove format/event filters from community health queries
- Modify: `www/custom.css` — add section divider styling

**Step 1: Design the section layout**

The dashboard should be split into two sections:

**Top: "Current Meta" (format-filtered):**
- Value boxes (Tournaments, Players, Hot Deck, Top Deck)
- Top Decks section
- Meta Diversity gauge + charts row (Conversion, Color Distribution)
- Meta Share Over Time

**Divider: subtle visual break**

**Bottom: "Community Health" (always all-time / trailing 12 months):**
- Player Growth & Retention
- Player Attendance chart
- Rising Stars (last 30 days — already time-based)
- Recent Tournaments table
- Top Players table

**Step 2: Update dashboard-ui.R**

Reorganize the sections and add a divider between them:

```r
# After Meta Share Over Time chart, add:
div(class = "dashboard-section-divider",
    div(class = "divider-line"),
    span(class = "divider-label", "Community"),
    div(class = "divider-line")
),
```

Move Player Growth, Player Attendance, Rising Stars, Recent Tournaments, and Top Players below the divider.

Keep Meta Diversity in the format-specific section (per user's request).

**Step 3: Add divider CSS**

```css
/* ===== Dashboard Section Divider ===== */
.dashboard-section-divider {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin: 1.5rem 0;
  padding: 0 0.5rem;
}

.dashboard-section-divider .divider-line {
  flex: 1;
  height: 1px;
  background: linear-gradient(90deg, transparent, rgba(15, 76, 129, 0.2), transparent);
}

[data-bs-theme="dark"] .dashboard-section-divider .divider-line {
  background: linear-gradient(90deg, transparent, rgba(0, 200, 255, 0.2), transparent);
}

.dashboard-section-divider .divider-label {
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: rgba(15, 76, 129, 0.4);
  white-space: nowrap;
}

[data-bs-theme="dark"] .dashboard-section-divider .divider-label {
  color: rgba(255, 255, 255, 0.3);
}
```

**Step 4: Update community health queries to ignore format/event filters**

In `server/public-dashboard-server.R`, the community health outputs should use scene-only filtering (no format, no event_type). Create a helper:

```r
build_community_filters <- function(table_alias = "t", store_alias = NULL) {
  sql_parts <- character(0)
  params <- list()

  # Scene filter only (no format, no event type)
  scene <- rv$current_scene
  if (!is.null(scene) && scene != "" && scene != "all" && !is.null(store_alias)) {
    if (scene == "online") {
      sql_parts <- c(sql_parts, sprintf("AND %s.is_online = TRUE", store_alias))
    } else {
      sql_parts <- c(sql_parts, sprintf(
        "AND %s.scene_id = (SELECT scene_id FROM scenes WHERE slug = ?)",
        store_alias
      ))
      params <- c(params, list(scene))
    }
  }

  list(
    sql = paste(sql_parts, collapse = " "),
    params = params,
    any_active = length(params) > 0
  )
}
```

Update these outputs to use `build_community_filters()` instead of `build_dashboard_filters()`:
- `output$player_growth_chart`
- `output$tournaments_trend_chart` (Player Attendance)
- `output$rising_stars_cards`
- `output$recent_tournaments`
- `output$top_players`

Update their `bindCache()` keys to exclude `input$dashboard_format` and `input$dashboard_event_type` (only use `rv$current_scene` and `rv$data_refresh`).

**Step 5: Verify and commit**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('views/dashboard-ui.R')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/public-dashboard-server.R')"
git add views/dashboard-ui.R server/public-dashboard-server.R www/custom.css
git commit -m "feat: split dashboard into format-specific and community sections"
```

---

### Task 8: Make Top Decks and Rising Stars Clickable

**Files:**
- Modify: `server/public-dashboard-server.R` — add click handlers to rendered HTML

**Step 1: Make Top Decks clickable**

In the `output$top_decks_with_images` renderUI (around line 628-702), each deck item is a `div`. Wrap each in an `onclick` that triggers the deck modal:

```r
# In the lapply that builds deck items, add onclick to the outer div:
div(
  class = "top-deck-item clickable-row",
  onclick = sprintf("Shiny.setInputValue('overview_deck_clicked', %d, {priority: 'event'})",
                    deck_data$archetype_id),
  style = "cursor: pointer;",
  # ... existing card image, name, progress bar content ...
)
```

Add an observer for the click:

```r
observeEvent(input$overview_deck_clicked, {
  req(input$overview_deck_clicked)
  # Switch to Meta tab and open deck modal
  nav_select("main_tabs", "meta")
  session$sendCustomMessage("updateSidebarNav", "nav_meta")
  rv$selected_archetype_id(input$overview_deck_clicked)
})
```

**Step 2: Make Rising Stars clickable**

In the `output$rising_stars_cards` renderUI (around line 1209-1293), each player card should trigger the player modal:

```r
# In the lapply that builds rising star cards, add onclick:
div(
  class = "rising-star-card clickable-row",
  onclick = sprintf("Shiny.setInputValue('overview_rising_star_clicked', %d, {priority: 'event'})",
                    player_data$player_id),
  style = "cursor: pointer;",
  # ... existing rank, name, badges, rating content ...
)
```

Add observer:

```r
observeEvent(input$overview_rising_star_clicked, {
  req(input$overview_rising_star_clicked)
  nav_select("main_tabs", "players")
  session$sendCustomMessage("updateSidebarNav", "nav_players")
  rv$selected_player_id(input$overview_rising_star_clicked)
})
```

**Step 3: Verify and commit**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/public-dashboard-server.R')"
git add server/public-dashboard-server.R
git commit -m "feat: make Top Decks and Rising Stars clickable (open modals)"
```

---

### Task 9: Fix Mobile Header Alignment

**Files:**
- Modify: `www/custom.css` — fix mobile header layout

**Step 1: Investigate and fix**

The known issue is dark mode toggle and right alignment on mobile. Update the mobile media query for `.app-header`:

```css
@media (max-width: 768px) {
  .app-header {
    padding: 0.4rem 0.75rem;
    overflow: visible;
  }

  .header-title {
    min-width: 0;
    flex-shrink: 1;
  }

  .header-title-text {
    font-size: 1.1rem;
  }

  .header-badge {
    display: none;  /* Hide BETA badge on mobile */
  }

  .header-circuit-line {
    display: none;  /* Hide decorative line on mobile */
  }

  .header-actions {
    margin-left: auto;
    flex-shrink: 0;
    gap: 0.5rem;
  }

  .header-scene-selector select {
    width: 120px !important;
    font-size: 0.8rem;
    padding: 0.3rem 0.4rem;
    padding-right: 1.3rem;
  }

  .header-action-btn {
    padding: 0.3rem 0.5rem;
    font-size: 0.8rem;
  }

  .app-header .bslib-dark-mode {
    font-size: 0.9rem;
  }
}
```

**Step 2: Test visually, then commit**

```bash
git add www/custom.css
git commit -m "fix: mobile header alignment and dark mode toggle visibility"
```

---

## Phase 4: Performance Optimizations

### Task 10: Connection Pooling with `pool` Package

**Files:**
- Modify: `R/db_connection.R` — add pool-based connection option
- Modify: `server/shared-server.R` — use pool connection
- Modify: `app.R` — add pool to library imports
- Run: `renv::install("pool")` and `renv::snapshot()`

**Step 1: Install pool package**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "renv::install('pool')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "renv::snapshot()"
```

**Step 2: Add pool connection functions to db_connection.R**

```r
#' Create a pooled database connection
#' Pool handles reconnection, multiple sessions, and connection lifecycle
connect_pool <- function() {
  use_motherduck <- can_use_motherduck()

  if (use_motherduck) {
    pool <- pool::dbPool(
      drv = duckdb::duckdb(),
      dbdir = ":memory:",
      minSize = 1,
      maxSize = 5,
      onCreate = function(con) {
        token <- Sys.getenv("MOTHERDUCK_TOKEN")
        db_name <- Sys.getenv("MOTHERDUCK_DATABASE", "digimon_tcg_dfw")
        DBI::dbExecute(con, "INSTALL motherduck;")
        DBI::dbExecute(con, "LOAD motherduck;")
        DBI::dbExecute(con, sprintf("SET motherduck_token = '%s';", token))
        DBI::dbExecute(con, sprintf("ATTACH 'md:%s';", db_name))
        DBI::dbExecute(con, sprintf("USE %s;", db_name))
      }
    )
    message("Connected to MotherDuck via pool")
    return(pool)
  } else {
    pool <- pool::dbPool(
      drv = duckdb::duckdb(),
      dbdir = "data/local.duckdb",
      minSize = 1,
      maxSize = 3
    )
    message("Connected to local database via pool")
    return(pool)
  }
}
```

**Step 3: Update shared-server.R to use pool**

Replace `rv$db_con <- connect_db()` with `rv$db_pool <- connect_pool()`. The `pool` package implements `dbGetQuery`, `dbExecute`, etc. on pool objects, so existing `safe_query()` calls should work transparently.

Update `safe_query()` to accept both pool and connection objects (it should already work since pool objects implement the DBI interface).

Add `onStop()` handler to close pool on app shutdown:

```r
onStop(function() {
  if (!is.null(rv$db_pool)) {
    pool::poolClose(rv$db_pool)
  }
})
```

**Important:** The transition from `rv$db_con` to `rv$db_pool` requires updating all references across server files. Consider keeping the variable name `rv$db_con` but storing the pool object in it, since pool objects are DBI-compatible. This minimizes changes.

**Step 4: Verify and commit**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('R/db_connection.R')"
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/shared-server.R')"
git add R/db_connection.R server/shared-server.R app.R renv.lock
git commit -m "perf: add connection pooling via pool package"
```

**Note:** If DuckDB + pool has compatibility issues (DuckDB is embedded, not client-server), fall back to keeping the direct connection but wrapping it with automatic reconnection logic in `safe_query()`.

---

### Task 11: Batch Dashboard Queries

**Files:**
- Modify: `server/public-dashboard-server.R` — consolidate queries into batch reactives

**Step 1: Create batch reactive for deck analytics**

Queries 5, 11, 12, 13, 15 all JOIN `deck_archetypes → results → tournaments → stores` with identical filters. Combine into one reactive:

```r
# Batch reactive: all deck analytics in one query
deck_analytics <- reactive({
  if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) return(NULL)

  filters <- build_dashboard_filters("t", "s")

  result <- safe_query(rv$db_con, paste("
    SELECT da.archetype_id, da.archetype_name, da.display_card_id,
           da.primary_color,
           COUNT(r.result_id) as entries,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as first_places,
           COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3,
           ROUND(COUNT(r.result_id) * 100.0 / NULLIF(SUM(COUNT(r.result_id)) OVER(), 0), 1) as meta_share
    FROM deck_archetypes da
    JOIN results r ON da.archetype_id = r.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    JOIN stores s ON t.store_id = s.store_id
    WHERE da.archetype_name != 'UNKNOWN'", filters$sql, "
    GROUP BY da.archetype_id, da.archetype_name, da.display_card_id, da.primary_color
    ORDER BY entries DESC
  "), params = filters$params, default = data.frame())

  result
}) |> bindCache(input$dashboard_format, input$dashboard_event_type, rv$current_scene, rv$data_refresh)
```

Then update downstream outputs to read from `deck_analytics()`:
- `most_popular_deck()` → `deck_analytics()[1, ]`
- `top_decks_with_images` → `head(deck_analytics() sorted by first_places, 6)`
- `conversion_rate_chart` → `deck_analytics()` filtered and sorted by conversion
- `color_dist_chart` → `deck_analytics()` aggregated by primary_color
- `meta_diversity_gauge` → `deck_analytics()` wins column for HHI calc

**Step 2: Create batch reactive for core metrics**

```r
core_metrics <- reactive({
  if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) return(list(tournaments = 0, players = 0))

  filters <- build_dashboard_filters("t", "s")

  result <- safe_query(rv$db_con, paste("
    SELECT COUNT(DISTINCT t.tournament_id) as tournaments,
           COUNT(DISTINCT r.player_id) as players
    FROM tournaments t
    JOIN stores s ON t.store_id = s.store_id
    LEFT JOIN results r ON t.tournament_id = r.tournament_id
    WHERE 1=1", filters$sql
  ), params = filters$params, default = data.frame(tournaments = 0, players = 0))

  as.list(result[1, ])
}) |> bindCache(input$dashboard_format, input$dashboard_event_type, rv$current_scene, rv$data_refresh)
```

Then `total_tournaments_val` and `total_players_val` read from this single reactive.

**Step 3: Keep remaining queries as-is**

Some queries have unique structures that don't batch well:
- Hot Deck (requires median date split — 4 sub-queries, keep as-is but could optimize later)
- Meta Share Timeline (grouped by week — different GROUP BY)
- Player Growth (complex CTEs)
- Tournament Trend (grouped by date)

These are already individually cached and don't fire on every render.

**Expected impact:** Reduces initial dashboard load from ~18 format-filtered queries to ~10 (core metrics batch + deck analytics batch + 8 unique queries).

**Step 4: Verify and commit**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/public-dashboard-server.R')"
git add server/public-dashboard-server.R
git commit -m "perf: batch dashboard queries (deck analytics + core metrics)"
```

---

## Phase 5: Historical Format Rating Snapshots

### Task 12: Rating Snapshots Schema

**Files:**
- Modify: `db/schema.sql` — add rating_snapshots table
- Create: `scripts/migrate_v0.23.R` — migration script

**Step 1: Add schema**

Add to `db/schema.sql`:

```sql
-- Rating snapshots: historical ratings frozen at the end of each format era
CREATE TABLE IF NOT EXISTS rating_snapshots (
    player_id INTEGER NOT NULL,
    format_id VARCHAR NOT NULL,
    competitive_rating INTEGER NOT NULL DEFAULT 1500,
    achievement_score INTEGER NOT NULL DEFAULT 0,
    events_played INTEGER NOT NULL DEFAULT 0,
    player_rank INTEGER,
    snapshot_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_id, format_id)
);

CREATE INDEX IF NOT EXISTS idx_rating_snapshots_format ON rating_snapshots(format_id);
```

**Step 2: Create migration script**

Create `scripts/migrate_v0.23.R`:

```r
# Migration script for v0.23
# Adds rating_snapshots table

migrate_v0.23 <- function(con) {
  message("Running v0.23 migration...")

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS rating_snapshots (
      player_id INTEGER NOT NULL,
      format_id VARCHAR NOT NULL,
      competitive_rating INTEGER NOT NULL DEFAULT 1500,
      achievement_score INTEGER NOT NULL DEFAULT 0,
      events_played INTEGER NOT NULL DEFAULT 0,
      player_rank INTEGER,
      snapshot_date DATE NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (player_id, format_id)
    )
  ")

  DBI::dbExecute(con, "
    CREATE INDEX IF NOT EXISTS idx_rating_snapshots_format ON rating_snapshots(format_id)
  ")

  message("v0.23 migration complete: rating_snapshots table created")
}
```

**Step 3: Run migration**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "
  library(duckdb); con <- dbConnect(duckdb(), 'data/local.duckdb')
  source('scripts/migrate_v0.23.R')
  migrate_v0.23(con)
  dbDisconnect(con)
"
```

**Step 4: Commit**

```bash
git add db/schema.sql scripts/migrate_v0.23.R
git commit -m "schema: add rating_snapshots table for historical format ratings"
```

---

### Task 13: Backfill Historical Snapshots + Date-Cutoff Rating Calculation

**Files:**
- Modify: `R/ratings.R` — add `date_cutoff` parameter and snapshot functions

**Step 1: Add date_cutoff to calculate_competitive_ratings()**

Add a `date_cutoff` parameter that limits which tournaments are included:

```r
calculate_competitive_ratings <- function(db_con, format_filter = NULL, date_cutoff = NULL) {
  # Build conditions
  conditions <- character(0)
  if (!is.null(format_filter) && format_filter != "") {
    conditions <- c(conditions, sprintf("AND t.format = '%s'", format_filter))
  }
  if (!is.null(date_cutoff)) {
    conditions <- c(conditions, sprintf("AND t.event_date <= '%s'", date_cutoff))
  }
  format_condition <- paste(conditions, collapse = " ")

  # ... rest of function unchanged ...
}
```

**Step 2: Add snapshot generation function**

```r
#' Generate rating snapshot for a specific format era
#' Computes ratings using all tournaments up to the format's end date
#'
#' @param db_con DuckDB connection
#' @param format_id Format identifier (e.g., "BT18")
#' @param end_date Date cutoff (last day of this format era)
#' @return Number of player snapshots created
generate_format_snapshot <- function(db_con, format_id, end_date) {
  # Calculate ratings up to this date
  ratings <- calculate_competitive_ratings(db_con, date_cutoff = end_date)
  scores <- calculate_achievement_scores(db_con)  # Achievement is cumulative

  if (nrow(ratings) == 0) return(0)

  # Merge ratings with achievement scores
  snapshot <- merge(ratings, scores, by = "player_id", all.x = TRUE)
  snapshot$achievement_score[is.na(snapshot$achievement_score)] <- 0

  # Count events per player up to cutoff
  events <- DBI::dbGetQuery(db_con, sprintf("
    SELECT r.player_id, COUNT(DISTINCT r.tournament_id) as events_played
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE t.event_date <= '%s'
    GROUP BY r.player_id
  ", end_date))

  snapshot <- merge(snapshot, events, by = "player_id", all.x = TRUE)
  snapshot$events_played[is.na(snapshot$events_played)] <- 0

  # Add rank
  snapshot <- snapshot[order(-snapshot$competitive_rating), ]
  snapshot$player_rank <- seq_len(nrow(snapshot))

  # Delete existing snapshot for this format (idempotent)
  DBI::dbExecute(db_con, "DELETE FROM rating_snapshots WHERE format_id = ?",
                 params = list(format_id))

  # Insert snapshot
  if (nrow(snapshot) > 0) {
    DBI::dbExecute(db_con, sprintf("
      INSERT INTO rating_snapshots (player_id, format_id, competitive_rating,
                                     achievement_score, events_played, player_rank, snapshot_date)
      VALUES %s
    ", paste(sprintf("(%d, '%s', %d, %d, %d, %d, '%s')",
             snapshot$player_id, format_id,
             snapshot$competitive_rating, snapshot$achievement_score,
             snapshot$events_played, snapshot$player_rank,
             end_date), collapse = ", ")))
  }

  message(sprintf("[snapshots] Generated %d player snapshots for %s (cutoff: %s)",
                  nrow(snapshot), format_id, end_date))
  nrow(snapshot)
}
```

**Step 3: Add backfill function**

```r
#' Backfill rating snapshots for all historical formats
#' Uses format release dates to determine era boundaries
#'
#' @param db_con DuckDB connection
backfill_rating_snapshots <- function(db_con) {
  # Get formats ordered by release date
  formats <- DBI::dbGetQuery(db_con, "
    SELECT format_id, set_name, release_date
    FROM formats
    WHERE release_date IS NOT NULL
    ORDER BY release_date ASC
  ")

  if (nrow(formats) < 2) {
    message("[snapshots] Need at least 2 formats to compute snapshots")
    return(invisible(NULL))
  }

  # Each format's "end date" is the day before the next format's release
  for (i in 1:(nrow(formats) - 1)) {
    format_id <- formats$format_id[i]
    end_date <- as.Date(formats$release_date[i + 1]) - 1

    message(sprintf("[snapshots] Processing %s (end date: %s)...", format_id, end_date))
    generate_format_snapshot(db_con, format_id, as.character(end_date))
  }

  message("[snapshots] Backfill complete")
}
```

**Step 4: Run backfill**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "
  library(duckdb); con <- dbConnect(duckdb(), 'data/local.duckdb')
  source('R/ratings.R')
  backfill_rating_snapshots(con)
  cat('Snapshots:', nrow(dbGetQuery(con, 'SELECT DISTINCT format_id FROM rating_snapshots')), 'formats\n')
  dbDisconnect(con)
"
```

**Step 5: Commit**

```bash
git add R/ratings.R
git commit -m "feat: add historical rating snapshots with backfill support"
```

---

### Task 14: Players Tab Shows Historical Ratings When Format Selected

**Files:**
- Modify: `server/public-players-server.R` — check format filter, use snapshots for past formats
- Modify: `app.R` — add reactive for current format detection

**Step 1: Add helper to detect if selected format is historical**

In `server/shared-server.R` or `app.R`:

```r
# Reactive: is the currently selected format historical (not the latest)?
get_latest_format_id <- reactive({
  if (is.null(rv$db_con) || !DBI::dbIsValid(rv$db_con)) return(NULL)
  result <- safe_query(rv$db_con,
    "SELECT format_id FROM formats WHERE is_active = TRUE ORDER BY sort_order ASC LIMIT 1",
    default = data.frame(format_id = character()))
  if (nrow(result) > 0) result$format_id[1] else NULL
})
```

**Step 2: Update players server to use snapshots for historical formats**

In `server/public-players-server.R`, after the main query, check if we should use historical ratings:

```r
# After getting the base player results...
# Determine rating source: live cache or historical snapshot
selected_format <- input$players_format
latest_format <- get_latest_format_id()

if (!is.null(selected_format) && selected_format != "" &&
    !is.null(latest_format) && selected_format != latest_format) {
  # Historical format: use snapshot ratings
  ratings <- safe_query(rv$db_con,
    "SELECT player_id, competitive_rating, achievement_score, player_rank
     FROM rating_snapshots WHERE format_id = ?",
    params = list(selected_format),
    default = data.frame(player_id = integer(), competitive_rating = integer(),
                         achievement_score = integer(), player_rank = integer()))
} else {
  # Current format: use live ratings from cache
  ratings <- player_competitive_ratings()
  scores <- player_achievement_scores()
  ratings <- merge(ratings, scores, by = "player_id", all = TRUE)
}

# Merge ratings into results (existing pattern)
```

**Step 3: Add visual indicator for historical ratings**

When showing historical ratings, update the Players tab header to indicate:

```r
# In the reactable header or above the table:
if (using_historical) {
  div(class = "historical-rating-badge",
      bsicons::bs_icon("clock-history"),
      sprintf("Ratings as of end of %s era", selected_format))
}
```

**Step 4: Verify and commit**

```bash
"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('server/public-players-server.R')"
git add server/public-players-server.R server/shared-server.R app.R www/custom.css
git commit -m "feat: show historical format ratings in player leaderboard"
```

---

## Phase 6: Documentation & Release

### Task 15: Update Documentation

**Files:**
- Modify: `CHANGELOG.md` — add v0.23 release notes
- Modify: `ROADMAP.md` — mark completed items, update status
- Modify: `logs/dev_log.md` — add entry for this work
- Modify: `ARCHITECTURE.md` — document new patterns (pill toggles, batch reactives, rating snapshots)

**Step 1: Update CHANGELOG.md**

Add under `[Unreleased]` → `[0.23.0]`:
- Scene selector loads dynamically from database
- Onboarding collapsed to single step
- Dashboard split: format-specific meta section + community health section
- Pill toggle filters on Players (5+/10+ events) and Deck Meta (5+/10+ entries)
- Admin button simplified to lock icon, Ko-fi moved to header
- Top Decks and Rising Stars now clickable (open modals)
- Tab renamed: "Meta Analysis" → "Deck Meta"
- Performance: connection pooling, batched dashboard queries
- Historical format rating snapshots (time capsule feature)
- Mobile header alignment fixes
- Fix: onboarding feature cards no longer show non-clickable hover state

**Step 2: Update ROADMAP.md**

Mark completed items in v0.23 section. Move deferred items (MR8-MR12) to appropriate future versions.

**Step 3: Commit**

```bash
git add CHANGELOG.md ROADMAP.md logs/dev_log.md ARCHITECTURE.md
git commit -m "docs: update documentation for v0.23 release"
```

---

## Implementation Notes

### Task Dependencies
- Task 1 (sync) → should run first
- Tasks 2-6 are independent of each other
- Task 7 depends on Tasks 3-4 being done (pill toggles should exist before reorganizing dashboard)
- Task 8 depends on Task 7 (clickable items in the right dashboard section)
- Tasks 10-11 (performance) can run in parallel but should come after UI changes are stable
- Tasks 12-14 (ratings) are sequential
- Task 15 (docs) runs last

### Testing Strategy
- After each task, run R syntax check: `"/c/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "parse('filename.R')"`
- After Phase 2 complete: manual app test (user runs `shiny::runApp()`)
- After Phase 3 complete: manual app test
- After Phase 4 complete: compare dashboard load time before/after
- After Phase 5 complete: test format selector shows different ratings for past vs current format

### Rollback Plan
- Each task has its own commit, so any individual change can be reverted
- Pool package (Task 10) is the riskiest — may have DuckDB compatibility issues. If so, revert to direct connection with reconnection wrapper in `safe_query()`
