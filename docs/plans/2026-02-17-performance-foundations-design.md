# v0.21.1 Performance & Foundations Design

**Date:** 2026-02-17
**Status:** Draft
**Target Version:** v0.21.1
**Depends On:** v0.21.0 (Deep Linking)
**Prepares For:** v0.22 (User Accounts), v0.23 (Multi-Region)

## Overview

Quick wins and foundational improvements before user accounts (v0.22) and multi-region (v0.23). No new user-facing features — focused on speed, security, resilience, and discoverability.

**Guiding principle:** Every change should either make the app faster, safer, or more findable. Nothing speculative.

## Goals

1. **Speed** — Eliminate wasted computation; cache what's expensive
2. **Security** — Close SQL injection vectors before adding user accounts
3. **Resilience** — Graceful failures instead of blank screens
4. **Discoverability** — Basic SEO so search engines can find us
5. **Session UX** — Keep the app alive while users are active; recover gracefully when it times out
6. **Hours-conscious** — All changes must respect Posit Connect billing hours

---

## PF1: Remove Forced 800ms Loading Delay

**Problem:** After the database connects, we wait a hard-coded 800ms + an additional 500ms CSS transition before hiding the loading screen. This adds 1.3 seconds to every cold start regardless of actual data readiness.

**Current code** (`server/shared-server.R:16`):
```r
shinyjs::delay(800, {
  session$sendCustomMessage("hideLoading", list())
})
```

And in `app.R:347`:
```js
Shiny.addCustomMessageHandler('hideLoading', function(message) {
  setTimeout(function() {
    $('.app-loading-overlay').addClass('loaded');
  }, 500);
});
```

**Fix:** Replace the arbitrary delay with a signal-based approach. The loading screen hides when the first dashboard output renders, not after a timer.

**Implementation:**
1. Add a lightweight "ready" reactive that fires once the first value box query completes
2. Send `hideLoading` immediately when that reactive triggers (no `shinyjs::delay`)
3. Reduce the CSS `setTimeout` from 500ms to 200ms (just enough for the fade animation)
4. Estimated savings: ~1 second off every cold start

**Changed files:** `server/shared-server.R`, `app.R` (JS handler)

---

## PF2: Add `bindCache()` to Dashboard Reactives

**Problem:** Every session re-runs all dashboard queries from scratch, even when viewing the same format/event type combination. With 8+ queries per dashboard load, this wastes CPU time and DB connections.

**Current state:** Zero `bindCache()` calls anywhere in the app. Every `reactive()` and `renderText()` recomputes on every session.

**Candidate reactives in `server/public-dashboard-server.R`:**

| Reactive | Line | Cache Key |
|----------|------|-----------|
| `total_tournaments_val` | 44 | format, event_type |
| `total_players_val` | 54 | format, event_type |
| `most_popular_deck` | 83 | format, event_type |
| `hot_deck` | 133 | format, event_type |
| `recent_tournaments` | 285 | format, event_type, data_refresh |
| `meta_diversity_data` | 895 | format, event_type |
| Chart outputs (conversion, color_dist, trend, meta_timeline, player_growth) | various | format, event_type |

**Implementation:**
```r
# Before
output$total_tournaments_val <- renderText({
  filters <- build_dashboard_filters("t")
  query <- sprintf("SELECT COUNT(*) ...")
  dbGetQuery(rv$db_con, query)$n
})

# After
output$total_tournaments_val <- renderText({
  filters <- build_dashboard_filters("t")
  query <- sprintf("SELECT COUNT(*) ...")
  dbGetQuery(rv$db_con, query)$n
}) |> bindCache(input$dashboard_format, input$dashboard_event_type, rv$data_refresh)
```

**Cache key structure:** `format + event_type + data_refresh`
- `data_refresh` is an existing reactive value that increments when admin submits results
- This ensures cached data invalidates when new results are entered
- Cache is shared across all sessions (Shiny's default behavior)

**Implementation notes:**
- `bindCache()` requires the reactive to be a pure function of its inputs — the filter values must be captured as cache keys, not embedded in closures
- `build_dashboard_filters()` currently uses `sprintf()` which we're replacing in PF5. The cache key is the raw filter *values*, not the constructed SQL
- Apply to ~12 outputs in `public-dashboard-server.R`
- Also apply to `public-players-server.R` and `public-meta-server.R` where format filters apply

**Changed files:** `server/public-dashboard-server.R`, `server/public-players-server.R`, `server/public-meta-server.R`

---

## PF3: Pre-compute Player Ratings into Cache Table

**Problem:** Player ratings are computed on every page load via `reactive()` in `app.R:672-699`. The Elo algorithm in `R/ratings.R` runs **5 passes** through all tournament results with O(n*m^2) per tournament (n tournaments, m players per tournament). This is the single most expensive computation in the app.

**Current code** (`app.R:672`):
```r
player_competitive_ratings <- reactive({
  rv$results_refresh
  calculate_competitive_ratings(rv$db_con)
})
```

**Fix:** Pre-compute ratings into a `player_ratings_cache` table. Recompute only when results change (admin submits), not on every page load.

**Schema:**
```sql
CREATE TABLE player_ratings_cache (
  player_id INTEGER PRIMARY KEY,
  competitive_rating INTEGER NOT NULL DEFAULT 1500,
  achievement_score INTEGER NOT NULL DEFAULT 0,
  events_played INTEGER NOT NULL DEFAULT 0,
  last_computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Recomputation trigger:** After any result submission in `server/admin-results-server.R`:
```r
# In the "save results" observer, after successful INSERT:
recalculate_ratings_cache(rv$db_con)
rv$data_refresh <- rv$data_refresh + 1
```

The `recalculate_ratings_cache()` function:
1. Calls `calculate_competitive_ratings()` and `calculate_achievement_scores()`
2. Truncates and repopulates `player_ratings_cache`
3. Runs in ~2-5 seconds (acceptable since it only happens when admin saves results)

**Reading ratings becomes a simple SELECT:**
```r
player_competitive_ratings <- reactive({
  rv$data_refresh
  dbGetQuery(rv$db_con, "SELECT player_id, competitive_rating FROM player_ratings_cache")
})
```

This drops from 5-pass Elo computation to a single table scan.

**Store ratings:** Same pattern — add `store_ratings_cache` table, recompute alongside player ratings.

**Migration:** Add both tables in a schema migration. On first deploy, manually run `recalculate_ratings_cache()` to populate.

**Changed files:** `db/schema.sql`, `R/ratings.R` (add `recalculate_ratings_cache()`), `app.R` (simplify reactive), `server/admin-results-server.R` (trigger recompute)

---

## PF4: Lazy-load Admin Server Modules

**Problem:** All 6 admin server modules are sourced unconditionally at app startup (`app.R:653-660`), creating observers and reactives for every session — even though 99% of users are viewers.

**Current code** (`app.R:653`):
```r
source("server/admin-results-server.R", local = TRUE)
source("server/admin-tournaments-server.R", local = TRUE)
source("server/admin-decks-server.R", local = TRUE)
source("server/admin-stores-server.R", local = TRUE)
source("server/admin-formats-server.R", local = TRUE)
source("server/admin-players-server.R", local = TRUE)
```

**Fix:** Wrap admin module sourcing behind `observeEvent(rv$is_admin)` so they only load when a user logs in.

**Implementation:**
```r
# Replace unconditional source() calls with:
observeEvent(rv$is_admin, {
  if (rv$is_admin && !isTRUE(rv$admin_modules_loaded)) {
    source("server/admin-results-server.R", local = TRUE)
    source("server/admin-tournaments-server.R", local = TRUE)
    source("server/admin-decks-server.R", local = TRUE)
    source("server/admin-stores-server.R", local = TRUE)
    source("server/admin-formats-server.R", local = TRUE)
    source("server/admin-players-server.R", local = TRUE)
    rv$admin_modules_loaded <- TRUE
  }
})
```

**Notes:**
- The `rv$admin_modules_loaded` flag prevents re-sourcing on logout/re-login
- Admin UI is already hidden via `conditionalPanel(condition = "output.is_admin")`, so there's no risk of UI rendering before modules load
- This saves memory and startup time for viewer sessions
- In v0.22, this pattern extends naturally — Discord OAuth confirms permissions, *then* modules load

**Changed files:** `app.R`

---

## PF5: Parameterize All SQL Queries

**Problem:** Public-facing queries use `sprintf()` to inject user input directly into SQL strings. This is a SQL injection vulnerability.

**Examples of vulnerable code:**

`server/public-dashboard-server.R:19`:
```r
dbGetQuery(rv$db_con, sprintf(
  "SELECT display_name FROM formats WHERE format_id = '%s'",
  input$dashboard_format
))
```

`server/public-dashboard-server.R:267`:
```r
sprintf("AND %s.format = '%s'", table_alias, input$dashboard_format)
```

`server/public-players-server.R:19`:
```r
sprintf("AND LOWER(p.display_name) LIKE LOWER('%%%s%%')", trimws(input$players_search))
```

**Scope:** The vulnerable pattern appears in `build_dashboard_filters()` and is used by ~20 queries across dashboard, players, meta, tournaments, and stores server files.

**Fix strategy:** Replace `build_dashboard_filters()` with a parameterized version that returns both SQL fragments and parameter lists.

**New helper:**
```r
build_dashboard_filters_param <- function(table_alias = "t") {
  sql_parts <- c()
  params <- list()

  if (!is.null(input$dashboard_format) && input$dashboard_format != "") {
    sql_parts <- c(sql_parts, sprintf("AND %s.format = ?", table_alias))
    params <- c(params, list(input$dashboard_format))
  }

  if (!is.null(input$dashboard_event_type) && input$dashboard_event_type != "") {
    sql_parts <- c(sql_parts, sprintf("AND %s.event_type = ?", table_alias))
    params <- c(params, list(input$dashboard_event_type))
  }

  list(
    sql = paste(sql_parts, collapse = " "),
    params = params,
    any_active = length(sql_parts) > 0
  )
}
```

**Usage:**
```r
# Before
filters <- build_dashboard_filters("t")
query <- sprintf("SELECT COUNT(*) FROM tournaments t WHERE 1=1 %s %s", filters$format, filters$event_type)
dbGetQuery(rv$db_con, query)$n

# After
filters <- build_dashboard_filters_param("t")
query <- paste("SELECT COUNT(*) FROM tournaments t WHERE 1=1", filters$sql)
dbGetQuery(rv$db_con, query, params = filters$params)$n
```

**Also fix:** Player search LIKE clause, format name lookup, and any other query accepting user input.

**Note:** Admin INSERT/UPDATE/DELETE queries already use parameterized queries (`params = list(...)`) — this is about fixing the SELECT queries.

**Also fix in `R/ratings.R:23`:**
```r
# Before
sprintf("AND t.format = '%s'", format_filter)

# After — use parameterized query
```

**Changed files:** `server/public-dashboard-server.R`, `server/public-players-server.R`, `server/public-meta-server.R`, `server/public-tournaments-server.R`, `server/public-stores-server.R`, `R/ratings.R`

---

## PF6: Add `safe_query()` Wrapper

**Problem:** Public-facing queries have no error handling. If a query fails (connection lost, syntax error, corrupted data), users see a blank screen or a raw R error.

**Current state:**
- Admin modules use `tryCatch` around writes (20+ instances) — good
- Public modules have zero `tryCatch` around reads — bad

**Fix:** Create a `safe_query()` wrapper that catches errors and returns sensible defaults.

**Implementation** (add to `server/shared-server.R`):
```r
safe_query <- function(db_con, query, params = NULL, default = data.frame()) {
  tryCatch({
    if (is.null(db_con) || !DBI::dbIsValid(db_con)) return(default)
    if (is.null(params)) {
      DBI::dbGetQuery(db_con, query)
    } else {
      DBI::dbGetQuery(db_con, query, params = params)
    }
  }, error = function(e) {
    message(sprintf("[safe_query] Error: %s\nQuery: %s", e$message, substr(query, 1, 200)))
    default
  })
}
```

**Usage:**
```r
# Before
dbGetQuery(rv$db_con, query)$n

# After
result <- safe_query(rv$db_con, query, params = filters$params, default = data.frame(n = 0))
result$n
```

**UI fallbacks:** Where safe_query returns the default, the rendering code should show "—" or "No data" instead of crashing. Most existing code already handles empty data frames, so this is primarily about catching connection errors.

**Changed files:** `server/shared-server.R` (define helper), all public server files (adopt helper)

---

## PF7: Add `robots.txt`

**Problem:** No `robots.txt` exists. Search engines have no guidance on what to crawl.

**Current state:** The app is served via iframe from `docs/index.html` at `digilab.cards`. The wrapper site is hosted on GitHub Pages.

**Implementation:** Add `docs/robots.txt` (served by GitHub Pages at `digilab.cards/robots.txt`):
```
User-agent: *
Allow: /
Sitemap: https://digilab.cards/sitemap.xml
```

**Note:** The Shiny app inside the iframe is not directly crawlable. This robots.txt is for the wrapper site. The real SEO value comes from the static HTML in `docs/index.html` and the planned landing pages (v1.0).

**Changed files:** `docs/robots.txt` (new)

---

## PF8: Add `sitemap.xml`

**Problem:** No sitemap exists for search engine discovery.

**Implementation:** Add `docs/sitemap.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://digilab.cards/</loc>
    <lastmod>2026-02-17</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
```

**Future:** When static landing pages are added (v1.0), expand the sitemap with About, FAQ, and Methodology pages.

**Changed files:** `docs/sitemap.xml` (new)

---

## PF9: Add `og:image` Meta Tag

**Problem:** When sharing digilab.cards on Discord or social media, there's no branded preview image. The current `og:image` points to the SVG logo, which many platforms don't render.

**Current code** (`docs/index.html:14`):
```html
<meta property="og:image" content="https://digilab.cards/digilab-logo.svg">
```

**Fix:**
1. Create a 1200x630 PNG social preview image with the DigiLab branding (dark navy background, logo, tagline)
2. Save as `docs/digilab-social-preview.png`
3. Update `og:image` in both `docs/index.html` and `app.R` to point to the PNG
4. Add `og:image:width` and `og:image:height` meta tags

**Updated meta tags:**
```html
<meta property="og:image" content="https://digilab.cards/digilab-social-preview.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
```

**Design specs for the preview image:**
- 1200x630 PNG
- Dark navy gradient background (matching `.title-strip`)
- DigiLab logo centered
- Tagline: "Digimon TCG Locals Tracker"
- Subtle grid overlay pattern (matching app aesthetic)

**Changed files:** `docs/digilab-social-preview.png` (new), `docs/index.html`, `app.R`

---

## PF10: Visibility-Aware Keepalive Script

**Problem:** Posit Connect idles inactive Shiny sessions after ~15 minutes. Users who are actively viewing the dashboard (reading data, comparing numbers) but not clicking get disconnected.

**Constraint:** Keepalive must NOT fire when the tab is in the background. Burning Posit Connect hours on hidden tabs is wasteful and expensive.

**Fix:** Add a JavaScript keepalive that pings the server every 60 seconds, but **only when the tab is visible** (using the Page Visibility API).

**Implementation** (add to `app.R` in the `tags$head()` section):
```js
// Visibility-aware keepalive — prevents timeout while tab is active
(function() {
  var keepaliveInterval = null;

  function startKeepalive() {
    if (!keepaliveInterval) {
      keepaliveInterval = setInterval(function() {
        Shiny.setInputValue('keepalive', Date.now(), {priority: 'deferred'});
      }, 60000); // Every 60 seconds
    }
  }

  function stopKeepalive() {
    if (keepaliveInterval) {
      clearInterval(keepaliveInterval);
      keepaliveInterval = null;
    }
  }

  document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
      stopKeepalive();
    } else {
      startKeepalive();
    }
  });

  // Start if tab is already visible
  if (!document.hidden) startKeepalive();
})();
```

**Server-side:** No server handler needed. `Shiny.setInputValue` is enough to reset the idle timer. Using `priority: 'deferred'` ensures it doesn't interrupt real user interactions.

**Hours impact:** Minimal. Only fires when the user is actively looking at the tab. Background tabs are not kept alive. When the user walks away, the tab is eventually hidden or the interval stops.

**Changed files:** `app.R` (JS in head)

---

## PF11: Custom Branded Disconnect Overlay

**Problem:** When a session times out, Shiny shows a generic gray "Disconnected from server" overlay. It's ugly and confusing — users don't know what happened or what to do.

**Fix:** Replace the default disconnect overlay with a branded one that:
1. Matches the DigiLab digital aesthetic
2. Explains what happened ("Session timed out")
3. Has a "Resume" button that uses deep linking (v0.21) to restore the user's exact state

**Implementation:**

CSS overlay (add to `www/custom.css`):
```css
/* Override Shiny's default disconnect overlay */
#shiny-disconnected-overlay {
  background: rgba(10, 48, 85, 0.95) !important;
  display: flex !important;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-family: inherit;
  z-index: 99999;
}
```

JavaScript (add to `app.R` in `tags$head()`):
```js
// Custom disconnect overlay with deep-link resume
$(document).on('shiny:disconnected', function() {
  var overlay = document.getElementById('shiny-disconnected-overlay');
  if (overlay) {
    // Build resume URL from current state
    var resumeUrl = window.location.href;
    overlay.innerHTML =
      '<div style="text-align:center;color:white;max-width:400px;padding:2rem">' +
        '<div style="font-size:2rem;margin-bottom:1rem">Session Timed Out</div>' +
        '<p style="opacity:0.8;margin-bottom:1.5rem">' +
          'Your session has been idle. Click below to pick up where you left off.' +
        '</p>' +
        '<a href="' + resumeUrl + '" style="' +
          'display:inline-block;padding:0.75rem 2rem;' +
          'background:#F7941D;color:white;border-radius:0.5rem;' +
          'text-decoration:none;font-weight:600;font-size:1.1rem;' +
          'transition:background 0.2s' +
        '">Resume</a>' +
      '</div>';
  }
});
```

**How it works:**
- When the session disconnects, Shiny adds `#shiny-disconnected-overlay`
- Our handler replaces the overlay content with branded HTML
- The "Resume" link uses the current URL (which includes deep link params from v0.21)
- Clicking Resume reloads the page → Shiny cold starts → deep linking restores tab + modal state

**Hours impact:** Zero. This doesn't prevent disconnection — it makes recovery seamless.

**Changed files:** `www/custom.css`, `app.R` (JS in head)

---

## PF12: "Last Updated" Timestamp

**Problem:** Users have no way to know how fresh the data is. After a tournament night, they don't know if results have been entered yet.

**Fix:** Show a "Last updated" timestamp in the dashboard title strip area.

**Data source:** Query the most recent `created_at` from the `results` table:
```sql
SELECT MAX(created_at) as last_update FROM results
```

**Implementation:**
1. Add a reactive in `server/public-dashboard-server.R`:
```r
output$last_updated <- renderText({
  rv$data_refresh
  result <- safe_query(rv$db_con,
    "SELECT CAST(MAX(created_at) AS VARCHAR) as last_update FROM results",
    default = data.frame(last_update = NA))
  if (is.na(result$last_update[1])) return("")
  ts <- as.POSIXct(result$last_update[1])
  paste("Updated", format(ts, "%b %d at %I:%M %p"))
})
```

2. Add UI element in `views/dashboard-ui.R`, inside the title strip:
```r
span(class = "text-xs opacity-60", textOutput("last_updated", inline = TRUE))
```

**Display:** Small, muted text in the title strip area (e.g., "Updated Feb 17 at 9:30 PM"). Non-intrusive but visible.

**Cache consideration:** This should also use `bindCache()` keyed on `rv$data_refresh` so it only re-queries when results change.

**Changed files:** `server/public-dashboard-server.R`, `views/dashboard-ui.R`

---

## Implementation Order

Recommended order based on dependencies and risk:

| Phase | Items | Rationale |
|-------|-------|-----------|
| 1 | PF5 (parameterize SQL) | Security fix — must happen before any new features. Also needed before PF2 since cache keys should use clean param values |
| 2 | PF6 (safe_query) | Foundation for everything else — wrap queries before caching them |
| 3 | PF2 (bindCache) | Biggest performance win for the least effort |
| 4 | PF3 (ratings cache) | Second biggest performance win; requires schema change |
| 5 | PF1 (remove delay) | Quick win, easy to test |
| 6 | PF4 (lazy admin modules) | Quick win, prepares for v0.22 auth |
| 7 | PF10 + PF11 (keepalive + disconnect) | Session UX improvements, JS-only |
| 8 | PF12 (last updated) | Small UI addition |
| 9 | PF7 + PF8 + PF9 (SEO) | Static files, no app changes needed for robots/sitemap |

**Phases 1-2** are prerequisites for everything else.
**Phases 3-6** can be done in parallel after phases 1-2.
**Phases 7-9** are independent and can be done in any order.

---

## Testing Plan

| Item | How to Verify |
|------|---------------|
| PF1 | Time cold start before/after. Target: <2s from click to dashboard visible |
| PF2 | Open two browser tabs with same filters. Second tab should load instantly (cache hit). Change filter → cache miss → new data loads |
| PF3 | Submit new results via admin. Verify ratings table updates. Verify player standings show correct values. Compare ratings before/after to ensure algorithm parity |
| PF4 | Open app as viewer → check R console for no admin module sourcing. Login as admin → verify admin tabs work |
| PF5 | Attempt SQL injection via format selector (e.g., `'; DROP TABLE--`). Verify query fails safely, not destructively |
| PF6 | Temporarily disconnect DB mid-session. Verify app shows fallback UI, not raw errors |
| PF7-8 | Visit `digilab.cards/robots.txt` and `digilab.cards/sitemap.xml` in browser |
| PF9 | Paste `digilab.cards` in Discord. Verify branded preview image appears |
| PF10 | Open app, leave tab visible for 20 minutes without clicking. Verify no disconnect. Switch to background tab → verify keepalive stops (check Network tab) |
| PF11 | Wait for session timeout (or kill R process). Verify branded overlay appears. Click Resume → verify deep link restores state |
| PF12 | Submit results via admin. Verify "Updated" timestamp changes on dashboard |

---

## Files Changed Summary

| File | Changes |
|------|---------|
| `db/schema.sql` | Add `player_ratings_cache` and `store_ratings_cache` tables |
| `R/ratings.R` | Add `recalculate_ratings_cache()` function |
| `app.R` | Lazy admin modules, JS keepalive, JS disconnect overlay, simplified rating reactive |
| `server/shared-server.R` | Remove 800ms delay, add `safe_query()` helper |
| `server/public-dashboard-server.R` | Parameterized queries, `bindCache()`, last updated timestamp |
| `server/public-players-server.R` | Parameterized queries, `bindCache()` |
| `server/public-meta-server.R` | Parameterized queries, `bindCache()` |
| `server/public-tournaments-server.R` | Parameterized queries |
| `server/public-stores-server.R` | Parameterized queries |
| `server/admin-results-server.R` | Trigger ratings cache recompute after result submission |
| `views/dashboard-ui.R` | "Last updated" text output |
| `www/custom.css` | Disconnect overlay styles |
| `docs/robots.txt` | New file |
| `docs/sitemap.xml` | New file |
| `docs/digilab-social-preview.png` | New file (design asset) |
| `docs/index.html` | Update og:image to PNG |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `bindCache()` returns stale data | Cache key includes `rv$data_refresh` which increments on every admin action |
| Ratings cache gets out of sync | Recompute is triggered in the same observer as result submission; wrap in transaction |
| `safe_query()` silently swallows real bugs | Log all caught errors with `message()`. In v1.0, upgrade to Sentry (ERR1) |
| Parameterization breaks existing queries | Test every query manually. DuckDB's `?` placeholder syntax is standard SQL |
| Keepalive burns hours | Visibility API ensures it only fires when tab is visible. 1 ping/min is negligible overhead |
| Social preview image looks bad on different platforms | Test on Discord, Twitter, and Facebook using their respective preview tools |
