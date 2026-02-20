# Stores Display & Filtering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement three features: improved online organizers display, community links for store-specific filtering, and admin table scene filtering.

**Architecture:** Schema-first approach - add `country` column, then build features layer by layer. UI changes follow existing patterns (conditionalPanel, reactive values, URL routing).

**Tech Stack:** R Shiny, DuckDB, bslib, mapgl, reactable

---

## Phase 1: Schema & Data Foundation

### Task 1.1: Create Migration for Country Column

**Files:**
- Create: `db/migrations/003_store_country.sql`

**Step 1: Create migration file**

```sql
-- =============================================================================
-- Migration 003: Store Country Column
-- Date: 2026-02-20
-- Description: Adds country column for international stores and online organizers
--
-- Changes:
--   1. Add country column to stores table (default 'USA')
--   2. Update existing online stores with correct country values
-- =============================================================================

-- 1. Add country column to stores table
-- NOTE: Will error if column already exists. Safe to ignore that error.
ALTER TABLE stores ADD COLUMN country VARCHAR DEFAULT 'USA';

-- 2. Update existing online stores with country data
-- Eagle's Nest (USA)
UPDATE stores SET country = 'USA' WHERE limitless_organizer_id = 452;
-- DMV Drakes (USA)
UPDATE stores SET country = 'USA' WHERE limitless_organizer_id = 559;
-- PHOENIX REBORN (Argentina)
UPDATE stores SET country = 'Argentina' WHERE limitless_organizer_id = 281;
-- MasterRukasu (Brazil)
UPDATE stores SET country = 'Brazil' WHERE limitless_organizer_id = 578;
```

**Step 2: Commit**

```bash
git add db/migrations/003_store_country.sql
git commit -m "schema: add country column to stores table"
```

---

### Task 1.2: Update Schema Definition

**Files:**
- Modify: `db/schema.sql:35-55` (stores table definition)

**Step 1: Add country column to stores table**

Find the stores table CREATE statement and add the country column after `is_online`:

```sql
-- In stores table definition, add after is_online line:
    country VARCHAR DEFAULT 'USA',        -- Country code for international support
```

**Step 2: Commit**

```bash
git add db/schema.sql
git commit -m "schema: add country column to stores table definition"
```

---

### Task 1.3: Run Migration on Local Database

**Step 1: Run migration**

```bash
cd /c/Users/Michael/Github/digimon-tcg-standings
python -c "
import duckdb
con = duckdb.connect('data/local.duckdb')
try:
    con.execute('ALTER TABLE stores ADD COLUMN country VARCHAR DEFAULT \\'USA\\'')
    print('Added country column')
except Exception as e:
    print(f'Column may already exist: {e}')
con.execute(\"UPDATE stores SET country = 'USA' WHERE limitless_organizer_id = 452\")
con.execute(\"UPDATE stores SET country = 'USA' WHERE limitless_organizer_id = 559\")
con.execute(\"UPDATE stores SET country = 'Argentina' WHERE limitless_organizer_id = 281\")
con.execute(\"UPDATE stores SET country = 'Brazil' WHERE limitless_organizer_id = 578\")
print('Updated online store countries')
con.close()
"
```

**Step 2: Verify**

```bash
python -c "
import duckdb
con = duckdb.connect('data/local.duckdb')
result = con.execute('SELECT name, country, is_online FROM stores WHERE is_online = TRUE').fetchall()
for row in result:
    print(row)
con.close()
"
```

Expected: Online stores show their country values.

---

## Phase 2: Admin UI - Country Field

### Task 2.1: Add Country Dropdown to Admin Stores UI

**Files:**
- Modify: `views/admin-stores-ui.R:37-41` (online store fields section)

**Step 1: Add country dropdown after store_name_online**

Find the online store conditionalPanel and add country field:

```r
          # Online store fields (shown when checkbox checked)
          conditionalPanel(
            condition = "input.store_is_online",
            textInput("store_name_online", "Store/Organizer Name"),
            selectInput("store_country", "Country",
              choices = list(
                "USA" = "USA",
                "Argentina" = "Argentina",
                "Brazil" = "Brazil",
                "Mexico" = "Mexico",
                "Canada" = "Canada",
                "Other" = "Other"
              ),
              selected = "USA",
              selectize = FALSE
            ),
            textInput("store_region", "Region/Coverage (optional)", placeholder = "e.g., DC/MD/VA, Texas, Global")
          ),
```

**Step 2: Commit**

```bash
git add views/admin-stores-ui.R
git commit -m "ui: add country dropdown to online store form"
```

---

### Task 2.2: Update Admin Stores Server - Add Store

**Files:**
- Modify: `server/admin-stores-server.R:56-219` (add_store handler)

**Step 1: Get country value in add_store handler**

After line 61 (`is_online <- isTRUE(input$store_is_online)`), add:

```r
  # Get country for online stores
  store_country <- if (is_online) {
    input$store_country %||% "USA"
  } else {
    "USA"  # Physical stores default to USA
  }
```

**Step 2: Update INSERT query**

Find the dbExecute INSERT statement (around line 174) and update:

```r
    dbExecute(rv$db_con, "
      INSERT INTO stores (store_id, name, address, city, state, zip_code, latitude, longitude, website, is_online, country)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ", params = list(new_id, store_name, address, store_city_db,
                     state, zip_code, lat, lng, website, is_online, store_country))
```

**Step 3: Clear country field in form reset**

In the form clearing section (around line 208), add:

```r
    updateSelectInput(session, "store_country", selected = "USA")
```

**Step 4: Commit**

```bash
git add server/admin-stores-server.R
git commit -m "feat: save country when adding online stores"
```

---

### Task 2.3: Update Admin Stores Server - Edit Store

**Files:**
- Modify: `server/admin-stores-server.R:331-383` (selection handler)
- Modify: `server/admin-stores-server.R:386-504` (update_store handler)

**Step 1: Load country in selection handler**

Update the SELECT query (around line 340):

```r
  data <- dbGetQuery(rv$db_con, "
    SELECT store_id, name, address, city, state, zip_code, website, is_online, country
    FROM stores
    WHERE is_active = TRUE
    ORDER BY name
  ")
```

**Step 2: Populate country field**

After line 360 (updateTextInput for store_region), add:

```r
    updateSelectInput(session, "store_country", selected = if (is.na(store$country)) "USA" else store$country)
```

**Step 3: Get country in update handler**

In the update_store handler (after line 391), add:

```r
  store_country <- if (is_online) {
    input$store_country %||% "USA"
  } else {
    "USA"
  }
```

**Step 4: Update UPDATE query**

Find the dbExecute UPDATE (around line 469) and add country:

```r
    dbExecute(rv$db_con, "
      UPDATE stores
      SET name = ?, address = ?, city = ?, state = ?, zip_code = ?,
          latitude = ?, longitude = ?, website = ?, is_online = ?, country = ?, updated_at = CURRENT_TIMESTAMP
      WHERE store_id = ?
    ", params = list(store_name, address, store_city_db, state, zip_code, lat, lng, website, is_online, store_country, store_id))
```

**Step 5: Clear country in form reset**

In the form clearing section (around line 487), add:

```r
    updateSelectInput(session, "store_country", selected = "USA")
```

**Step 6: Commit**

```bash
git add server/admin-stores-server.R
git commit -m "feat: load and save country when editing online stores"
```

---

## Phase 3: Online Organizers Display

### Task 3.1: Create Region Coordinates Lookup

**Files:**
- Create: `R/geo_utils.R`

**Step 1: Create geo utilities file**

```r
# =============================================================================
# Geographic Utilities
# Helper functions for coordinate lookups and map rendering
# =============================================================================

#' Get approximate coordinates for a country/region combination
#' Used for placing online organizers on world map
#'
#' @param country Country name (e.g., "USA", "Argentina")
#' @param region Optional region within country (e.g., "DC/MD/VA", "Texas")
#' @return List with lat and lng, or NULL if not found
get_region_coordinates <- function(country, region = NULL) {
  # Region-specific coordinates (more precise placement)
  region_coords <- list(
    "USA" = list(
      "DC/MD/VA" = list(lat = 38.9, lng = -77.0),
      "Texas" = list(lat = 31.0, lng = -97.0),
      "DFW" = list(lat = 32.8, lng = -96.8),
      "default" = list(lat = 39.8, lng = -98.6)  # Geographic center of USA
    ),
    "Argentina" = list(
      "default" = list(lat = -34.6, lng = -58.4)  # Buenos Aires
    ),
    "Brazil" = list(
      "default" = list(lat = -23.5, lng = -46.6)  # São Paulo
    ),
    "Mexico" = list(
      "default" = list(lat = 19.4, lng = -99.1)  # Mexico City
    ),
    "Canada" = list(
      "default" = list(lat = 45.4, lng = -75.7)  # Ottawa
    )
  )

  # Try to find region-specific coordinates
  if (!is.null(country) && country %in% names(region_coords)) {
    country_regions <- region_coords[[country]]

    # Try exact region match first
    if (!is.null(region) && region %in% names(country_regions)) {
      return(country_regions[[region]])
    }

    # Try partial region match
    if (!is.null(region)) {
      for (region_name in names(country_regions)) {
        if (region_name != "default" && grepl(region_name, region, ignore.case = TRUE)) {
          return(country_regions[[region_name]])
        }
      }
    }

    # Fall back to country default
    return(country_regions[["default"]])
  }

  # Unknown country - return NULL
  NULL
}

#' Get world map bounds for fitting all online organizers
#' @return List with sw (southwest) and ne (northeast) coordinates
get_world_map_bounds <- function() {
  list(
    sw = list(lat = -60, lng = -140),
    ne = list(lat = 70, lng = 60)
  )
}
```

**Step 2: Source in app.R**

Add after line 33 (source("R/ratings.R")):

```r
source("R/geo_utils.R")
```

**Step 3: Commit**

```bash
git add R/geo_utils.R app.R
git commit -m "feat: add geographic utilities for online organizer coordinates"
```

---

### Task 3.2: Update Stores Map for Online Scene

**Files:**
- Modify: `server/public-stores-server.R:869-965` (stores_map renderer)

**Step 1: Add world map rendering for online scene**

Replace the entire `output$stores_map <- renderMapboxgl({...})` block with logic that checks scene:

```r
# Stores Map
output$stores_map <- renderMapboxgl({
  scene <- rv$current_scene

  # For Online scene, show world map with online organizers
  if (!is.null(scene) && scene == "online") {
    return(render_online_organizers_map())
  }

  # For other scenes, show regional map with physical stores
  stores <- stores_data()

  # ... rest of existing map code ...
})

# Helper: Render world map for online organizers
render_online_organizers_map <- function() {
  # Query online stores with country
  online_stores <- safe_query(rv$db_con, "
    SELECT s.store_id, s.name, s.city as region, s.country, s.website,
           COUNT(t.tournament_id) as tournament_count,
           COALESCE(ROUND(AVG(t.player_count), 1), 0) as avg_players
    FROM stores s
    LEFT JOIN tournaments t ON s.store_id = t.store_id
    WHERE s.is_online = TRUE AND s.is_active = TRUE
    GROUP BY s.store_id, s.name, s.city, s.country, s.website
  ")

  if (nrow(online_stores) == 0) {
    # Empty world map
    return(
      atom_mapgl(theme = "digital") |>
        mapgl::set_view(center = c(-40, 20), zoom = 1.5)
    )
  }

  # Add coordinates based on country/region
  online_stores$lat <- NA_real_
  online_stores$lng <- NA_real_

  for (i in 1:nrow(online_stores)) {
    coords <- get_region_coordinates(
      online_stores$country[i],
      online_stores$region[i]
    )
    if (!is.null(coords)) {
      online_stores$lat[i] <- coords$lat
      online_stores$lng[i] <- coords$lng
    }
  }

  # Filter to stores with coordinates
  stores_with_coords <- online_stores[!is.na(online_stores$lat), ]

  if (nrow(stores_with_coords) == 0) {
    return(
      atom_mapgl(theme = "digital") |>
        mapgl::set_view(center = c(-40, 20), zoom = 1.5)
    )
  }

  # Convert to sf
  stores_sf <- st_as_sf(stores_with_coords, coords = c("lng", "lat"), crs = 4326)

  # Bubble size based on event count
  stores_sf$bubble_size <- sapply(stores_with_coords$tournament_count, function(cnt) {
    if (is.na(cnt) || cnt == 0) return(8)
    if (cnt < 10) return(12)
    if (cnt < 50) return(16)
    if (cnt < 100) return(20)
    return(24)
  })

  # Popup content
  stores_sf$popup <- sapply(1:nrow(stores_sf), function(i) {
    store <- stores_with_coords[i, ]
    metrics <- c()
    if (!is.na(store$country)) metrics <- c(metrics, "Country" = store$country)
    if (!is.na(store$region) && store$region != "") metrics <- c(metrics, "Region" = store$region)
    if (store$tournament_count > 0) {
      metrics <- c(metrics, "Events" = as.character(store$tournament_count))
      metrics <- c(metrics, "Avg Players" = as.character(store$avg_players))
    }

    atom_popup_html_metrics(
      title = store$name,
      subtitle = "Online Organizer",
      metrics = if (length(metrics) > 0) metrics else NULL,
      theme = "light"
    )
  })

  # Create world map
  atom_mapgl(theme = "digital") |>
    add_atom_popup_style(theme = "light") |>
    mapgl::add_circle_layer(
      id = "online-stores-layer",
      source = stores_sf,
      circle_color = "#10B981",  # Green for online
      circle_radius = list("get", "bubble_size"),
      circle_stroke_color = "#FFFFFF",
      circle_stroke_width = 2,
      circle_opacity = 0.85,
      popup = "popup"
    ) |>
    mapgl::set_view(center = c(-40, 20), zoom = 1.5)
}
```

**Step 2: Commit**

```bash
git add server/public-stores-server.R
git commit -m "feat: show world map with online organizers when Online scene selected"
```

---

### Task 3.3: Replace All Stores Table with Cards View

**Files:**
- Modify: `views/stores-ui.R:36-73` (view toggle and content area)
- Modify: `server/public-stores-server.R:214-285` (store_list renderer)

**Step 1: Update UI toggle labels**

In `views/stores-ui.R`, change the toggle buttons (around line 44-53):

```r
        actionButton(
          "stores_view_schedule",
          tagList(bsicons::bs_icon("calendar-week"), " Schedule"),
          class = "btn-outline-primary active"
        ),
        actionButton(
          "stores_view_all",
          tagList(bsicons::bs_icon("grid-3x3-gap"), " Cards"),
          class = "btn-outline-primary"
        )
```

**Step 2: Update conditionalPanel for cards view**

Replace the "All Stores view" conditionalPanel (around line 66-70):

```r
      # Cards view
      conditionalPanel(
        condition = "input.stores_view_mode == 'all'",
        id = "stores_cards_view",
        uiOutput("stores_cards_content")
      )
```

**Step 3: Add cards renderer in server**

Add new output after `store_list` renderer:

```r
# Store cards view (replaces table for both physical and online)
output$stores_cards_content <- renderUI({
  rv$data_refresh
  scene <- rv$current_scene

  # For online scene, show online organizers
  if (!is.null(scene) && scene == "online") {
    online_stores <- safe_query(rv$db_con, "
      SELECT s.store_id, s.name, s.city as region, s.country, s.website,
             COUNT(t.tournament_id) as tournament_count,
             COALESCE(ROUND(AVG(t.player_count), 1), 0) as avg_players,
             MAX(t.event_date) as last_event
      FROM stores s
      LEFT JOIN tournaments t ON s.store_id = t.store_id
      WHERE s.is_online = TRUE AND s.is_active = TRUE
      GROUP BY s.store_id, s.name, s.city, s.country, s.website
      ORDER BY s.name
    ")

    if (nrow(online_stores) == 0) {
      return(digital_empty_state("No online organizers", "// check back soon", "globe"))
    }

    return(render_store_cards(online_stores, is_online = TRUE))
  }

  # For physical scenes, show physical stores
  stores <- stores_data()

  if (is.null(stores) || nrow(stores) == 0) {
    return(digital_empty_state("No stores found", "// check back soon", "shop"))
  }

  render_store_cards(stores, is_online = FALSE)
})

# Helper: Render store cards grid
render_store_cards <- function(stores, is_online = FALSE) {
  div(
    class = "row g-3",
    lapply(1:nrow(stores), function(i) {
      store <- stores[i, ]
      div(
        class = "col-md-4 col-lg-3",
        tags$button(
          type = "button",
          class = "store-card-item p-3 h-100 w-100 text-start border-0",
          onclick = if (is_online) {
            sprintf("Shiny.setInputValue('online_store_click', %d, {priority: 'event'})", store$store_id)
          } else {
            sprintf("Shiny.setInputValue('store_clicked', %d, {priority: 'event'})", store$store_id)
          },
          h6(class = "mb-1 fw-semibold", store$name),
          if (is_online) {
            tagList(
              if (!is.na(store$country)) p(class = "text-muted small mb-1", bsicons::bs_icon("globe"), " ", store$country),
              if (!is.na(store$region) && store$region != "") p(class = "text-muted small mb-1", bsicons::bs_icon("geo"), " ", store$region)
            )
          } else {
            if (!is.na(store$city)) p(class = "text-muted small mb-1", store$city)
          },
          if (store$tournament_count > 0) {
            p(class = "small mb-0 text-primary",
              bsicons::bs_icon("trophy"), " ", store$tournament_count, " events",
              span(class = "text-muted ms-2", paste0("~", store$avg_players, " avg")))
          } else {
            p(class = "small mb-0 text-muted", "No events yet")
          }
        )
      )
    })
  )
}
```

**Step 4: Add CSS for store cards**

Add to `www/custom.css`:

```css
/* Store Cards View */
.store-card-item {
  background: var(--bs-body-bg);
  border-radius: 8px;
  transition: all 0.2s ease;
  cursor: pointer;
}

.store-card-item:hover {
  background: rgba(var(--bs-primary-rgb), 0.1);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

[data-bs-theme="dark"] .store-card-item {
  background: rgba(255, 255, 255, 0.05);
}

[data-bs-theme="dark"] .store-card-item:hover {
  background: rgba(var(--bs-primary-rgb), 0.15);
}
```

**Step 5: Commit**

```bash
git add views/stores-ui.R server/public-stores-server.R www/custom.css
git commit -m "feat: replace All Stores table with Cards view"
```

---

### Task 3.4: Hide Online Organizers Section When Using Cards

**Files:**
- Modify: `server/public-stores-server.R:627-686` (online_stores_section)

**Step 1: Update condition to also hide when in Cards view for Online scene**

The online organizers section should now only show when:
- Scene is "all" (shows alongside physical stores)
- NOT when scene is "online" (cards view handles it)

Update the condition at line 631-635:

```r
  # Only show online stores section when scene is "all"
  # When scene is "online", the cards view shows online organizers instead
  scene <- rv$current_scene
  if (is.null(scene) || scene == "" || scene == "online" || (scene != "all")) {
    return(NULL)
  }
```

Wait, that logic is wrong. Let me reconsider:
- Scene = "all": Show physical stores in main area + online organizers in bottom section
- Scene = "online": Show online organizers in main area (map + cards), hide bottom section
- Scene = regional (e.g., "dfw"): Show regional stores only, hide online section

So the section should only show when scene == "all":

```r
  # Only show online stores section when scene is "all"
  # For regional scenes, we don't show online organizers
  # For "online" scene, the main content area shows online organizers
  scene <- rv$current_scene
  if (is.null(scene) || scene != "all") {
    return(NULL)
  }
```

**Step 2: Commit**

```bash
git add server/public-stores-server.R
git commit -m "fix: only show online organizers section when scene is 'all'"
```

---

## Phase 4: Community Links

### Task 4.1: Add Community Filter Reactive Value

**Files:**
- Modify: `app.R:668-710` (reactive values)

**Step 1: Add community_filter to reactive values**

In the `rv <- reactiveValues(...)` block, add after `current_scene`:

```r
    community_filter = NULL,            # Store slug for community-filtered view (e.g., "eagles-nest")
```

**Step 2: Commit**

```bash
git add app.R
git commit -m "feat: add community_filter reactive value"
```

---

### Task 4.2: Update URL Routing for Community Parameter

**Files:**
- Modify: `server/url-routing-server.R`

**Step 1: Handle community parameter in initial URL**

In `observeEvent(input$url_initial, ...)` (around line 80), add after scene handling:

```r
  # 1b. Community filter (store-specific view)
  if (!is.null(params$community)) {
    # Look up store by slug
    store <- dbGetQuery(rv$db_con,
      "SELECT store_id, scene_id FROM stores WHERE slug = ? AND is_active = TRUE",
      params = list(params$community))

    if (nrow(store) == 1) {
      rv$community_filter <- params$community
      # Also set scene to the store's scene
      scene_result <- dbGetQuery(rv$db_con,
        "SELECT slug FROM scenes WHERE scene_id = ?",
        params = list(store$scene_id))
      if (nrow(scene_result) == 1) {
        rv$current_scene <- scene_result$slug
      }
    }
  }
```

**Step 2: Add update_url_for_community helper**

Add new function after `update_url_for_tournament`:

```r
#' Update URL for community-filtered view
update_url_for_community <- function(session, store_slug) {
  params <- list(community = store_slug)
  update_browser_url(session, params, replace = FALSE)
}

#' Clear community filter from URL
clear_community_filter <- function(session) {
  params <- list()
  if (!is.null(rv$current_nav) && rv$current_nav != "dashboard") {
    params$tab <- rv$current_nav
  }
  if (!is.null(rv$current_scene)) {
    params$scene <- rv$current_scene
  }
  update_browser_url(session, params, replace = TRUE)
}
```

**Step 3: Preserve community filter in URL updates**

Update `update_url_for_player`, `update_url_for_deck`, `update_url_for_store`, `update_url_for_tournament` to preserve community filter:

```r
# Add at start of each function, after existing params setup:
  if (!is.null(rv$community_filter)) {
    params$community <- rv$community_filter
  }
```

**Step 4: Commit**

```bash
git add server/url-routing-server.R
git commit -m "feat: handle community URL parameter for store-filtered views"
```

---

### Task 4.3: Add Community Filter Banner Component

**Files:**
- Create: `views/community-banner-ui.R`
- Modify: `app.R` (source the file)

**Step 1: Create banner component**

```r
# views/community-banner-ui.R
# Banner shown when community filter is active

community_banner_ui <- function(store_name) {
  div(
    id = "community-filter-banner",
    class = "community-filter-banner mb-3",
    div(
      class = "d-flex align-items-center justify-content-between",
      div(
        class = "d-flex align-items-center gap-2",
        bsicons::bs_icon("funnel-fill", class = "text-primary"),
        span("Showing data for "),
        strong(store_name)
      ),
      actionButton(
        "clear_community_filter",
        tagList(bsicons::bs_icon("x-lg"), " View All"),
        class = "btn btn-sm btn-outline-secondary"
      )
    )
  )
}
```

**Step 2: Add CSS for banner**

Add to `www/custom.css`:

```css
/* Community Filter Banner */
.community-filter-banner {
  background: linear-gradient(135deg, rgba(var(--bs-primary-rgb), 0.1), rgba(var(--bs-primary-rgb), 0.05));
  border: 1px solid rgba(var(--bs-primary-rgb), 0.2);
  border-radius: 8px;
  padding: 12px 16px;
}

[data-bs-theme="dark"] .community-filter-banner {
  background: linear-gradient(135deg, rgba(var(--bs-primary-rgb), 0.15), rgba(var(--bs-primary-rgb), 0.08));
}
```

**Step 3: Source in app.R**

Add after other view sources:

```r
source("views/community-banner-ui.R")
```

**Step 4: Commit**

```bash
git add views/community-banner-ui.R www/custom.css app.R
git commit -m "feat: add community filter banner component"
```

---

### Task 4.4: Render Banner and Handle Clear

**Files:**
- Modify: `server/shared-server.R` (add banner renderer and clear handler)

**Step 1: Add banner renderer**

```r
# Community filter banner
output$community_banner <- renderUI({
  req(rv$community_filter)

  # Look up store name
  store <- safe_query(rv$db_con,
    "SELECT name FROM stores WHERE slug = ?",
    params = list(rv$community_filter))

  if (nrow(store) == 0) return(NULL)

  community_banner_ui(store$name)
})

# Clear community filter
observeEvent(input$clear_community_filter, {
  rv$community_filter <- NULL
  clear_community_filter(session)
  showNotification("Community filter cleared", type = "message", duration = 2)
})
```

**Step 2: Add banner placeholder to main UI**

In `app.R`, add banner output before main content (around line 400, after sidebar):

```r
        # Community filter banner (shown when filtering by store)
        uiOutput("community_banner"),
```

**Step 3: Commit**

```bash
git add server/shared-server.R app.R
git commit -m "feat: render community filter banner and handle clear"
```

---

### Task 4.5: Add Share Community View Button to Store Modal

**Files:**
- Modify: `server/public-stores-server.R:414-436` (store modal footer)

**Step 1: Update modal footer with two buttons**

Find the footer section in store_detail_modal and update:

```r
    footer = tagList(
      tags$button(
        type = "button",
        class = "btn btn-outline-secondary",
        onclick = "copyCurrentUrl()",
        bsicons::bs_icon("link-45deg"), " Copy Link"
      ),
      tags$button(
        type = "button",
        class = "btn btn-outline-primary ms-2",
        onclick = sprintf("copyCommunityUrl('%s')", store_slug),
        bsicons::bs_icon("share"), " Share Community View"
      ),
      modalButton("Close")
    ),
```

**Step 2: Add JavaScript helper for copying community URL**

Add to `www/url-routing.js`:

```javascript
// Copy community-filtered URL to clipboard
function copyCommunityUrl(storeSlug) {
  const baseUrl = window.location.origin + window.location.pathname;
  const communityUrl = baseUrl + '?community=' + encodeURIComponent(storeSlug);

  navigator.clipboard.writeText(communityUrl).then(function() {
    Shiny.setInputValue('link_copied', Math.random());
  }).catch(function(err) {
    console.error('Failed to copy:', err);
  });
}
```

**Step 3: Commit**

```bash
git add server/public-stores-server.R www/url-routing.js
git commit -m "feat: add Share Community View button to store modal"
```

---

### Task 4.6: Apply Community Filter to Dashboard Queries

**Files:**
- Modify: `server/public-dashboard-server.R`

**Step 1: Update build_dashboard_filters to support community filter**

Find `build_dashboard_filters` function and add community parameter:

```r
build_dashboard_filters <- function(format = NULL, event_type = NULL, scene = NULL, community = NULL, ...) {
  # ... existing code ...

  # Community filter (overrides scene filter for tournaments)
  if (!is.null(community) && community != "") {
    sql_parts <- c(sql_parts, "AND s.slug = ?")
    params <- c(params, list(community))
  }

  # ... rest of function ...
}
```

**Step 2: Pass community filter to all dashboard queries**

In each dashboard query that uses filters, add `community = rv$community_filter`:

```r
# Example for deck_analytics reactive:
deck_analytics <- reactive({
  filters <- build_dashboard_filters(
    format = input$dashboard_format,
    event_type = input$dashboard_event_type,
    scene = rv$current_scene,
    community = rv$community_filter  # ADD THIS
  )
  # ... rest of query ...
})
```

**Step 3: Commit**

```bash
git add server/public-dashboard-server.R
git commit -m "feat: apply community filter to dashboard queries"
```

---

### Task 4.7: Apply Community Filter to Other Public Tabs

**Files:**
- Modify: `server/public-players-server.R`
- Modify: `server/public-meta-server.R`
- Modify: `server/public-tournaments-server.R`

**Step 1: Update each server file's queries**

For each file, find the main data queries and add community filter support. The pattern is the same - add a JOIN to stores and filter by slug when community filter is active.

**Step 2: Commit**

```bash
git add server/public-players-server.R server/public-meta-server.R server/public-tournaments-server.R
git commit -m "feat: apply community filter to players, meta, and tournaments tabs"
```

---

## Phase 5: Admin Scene Filtering

### Task 5.1: Add Admin Scene Override Toggle

**Files:**
- Modify: `views/admin-players-ui.R`
- Modify: `views/admin-tournaments-ui.R` (create if needed)
- Modify: `views/admin-stores-ui.R`

**Step 1: Add toggle to each admin UI**

Add near the table header in each admin UI file:

```r
# Only show for superadmins
conditionalPanel(
  condition = "output.is_superadmin == true",
  div(
    class = "d-flex justify-content-end mb-2",
    checkboxInput("admin_show_all_scenes", "Show all scenes", value = FALSE)
  )
)
```

**Step 2: Commit**

```bash
git add views/admin-players-ui.R views/admin-stores-ui.R
git commit -m "ui: add 'Show all scenes' toggle for superadmins"
```

---

### Task 5.2: Apply Scene Filter to Admin Players

**Files:**
- Modify: `server/admin-players-server.R:6-57` (player_list query)

**Step 1: Update query to filter by scene**

```r
output$player_list <- renderReactable({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  # Refresh triggers
  input$update_player
  input$confirm_delete_player
  input$confirm_merge_players

  search_term <- input$player_search %||% ""
  scene <- rv$current_scene
  show_all <- isTRUE(input$admin_show_all_scenes) && isTRUE(rv$is_superadmin)

  # Base query - players with results in scene
  if (!show_all && !is.null(scene) && scene != "" && scene != "all") {
    query <- "
      SELECT DISTINCT p.player_id,
             p.display_name as 'Player Name',
             COUNT(r.result_id) as 'Results',
             SUM(CASE WHEN r.placement = 1 THEN 1 ELSE 0 END) as 'Wins',
             MAX(t.event_date) as 'Last Event'
      FROM players p
      LEFT JOIN results r ON p.player_id = r.player_id
      LEFT JOIN tournaments t ON r.tournament_id = t.tournament_id
      LEFT JOIN stores s ON t.store_id = s.store_id
      WHERE EXISTS (
        SELECT 1 FROM results r2
        JOIN tournaments t2 ON r2.tournament_id = t2.tournament_id
        JOIN stores s2 ON t2.store_id = s2.store_id
        WHERE r2.player_id = p.player_id
    "

    if (scene == "online") {
      query <- paste0(query, " AND s2.is_online = TRUE")
    } else {
      query <- paste0(query, " AND s2.scene_id = (SELECT scene_id FROM scenes WHERE slug = '", scene, "')")
    }

    query <- paste0(query, ")")

    if (nchar(search_term) > 0) {
      query <- paste0(query, " AND LOWER(p.display_name) LIKE LOWER('%", search_term, "%')")
    }

    query <- paste0(query, "
      GROUP BY p.player_id, p.display_name
      ORDER BY p.display_name
    ")
  } else {
    # Original unfiltered query
    query <- "
      SELECT p.player_id,
             p.display_name as 'Player Name',
             COUNT(r.result_id) as 'Results',
             SUM(CASE WHEN r.placement = 1 THEN 1 ELSE 0 END) as 'Wins',
             MAX(t.event_date) as 'Last Event'
      FROM players p
      LEFT JOIN results r ON p.player_id = r.player_id
      LEFT JOIN tournaments t ON r.tournament_id = t.tournament_id
    "

    if (nchar(search_term) > 0) {
      query <- paste0(query, " WHERE LOWER(p.display_name) LIKE LOWER('%", search_term, "%')")
    }

    query <- paste0(query, "
      GROUP BY p.player_id, p.display_name
      ORDER BY p.display_name
    ")
  }

  data <- dbGetQuery(rv$db_con, query)
  # ... rest of function ...
})
```

**Step 2: Add scene indicator**

Add output showing current filter:

```r
output$admin_players_scene_indicator <- renderUI({
  scene <- rv$current_scene
  show_all <- isTRUE(input$admin_show_all_scenes) && isTRUE(rv$is_superadmin)

  if (show_all || is.null(scene) || scene == "" || scene == "all") {
    return(NULL)
  }

  div(
    class = "badge bg-info mb-2",
    paste("Filtered to:", toupper(scene))
  )
})
```

**Step 3: Commit**

```bash
git add server/admin-players-server.R
git commit -m "feat: apply scene filter to admin players table"
```

---

### Task 5.3: Apply Scene Filter to Admin Tournaments

**Files:**
- Modify: `server/admin-tournaments-server.R:56-150` (tournament list query)

**Step 1: Update query to filter by scene**

Similar pattern to players - add JOIN to stores and scene filter condition.

**Step 2: Commit**

```bash
git add server/admin-tournaments-server.R
git commit -m "feat: apply scene filter to admin tournaments table"
```

---

### Task 5.4: Apply Scene Filter to Admin Stores

**Files:**
- Modify: `server/admin-stores-server.R:221-328` (admin_store_list query)

**Step 1: Update query to filter by scene**

```r
output$admin_store_list <- renderReactable({
  # ... existing triggers ...

  scene <- rv$current_scene
  show_all <- isTRUE(input$admin_show_all_scenes) && isTRUE(rv$is_superadmin)

  # Build scene filter
  scene_filter <- ""
  if (!show_all && !is.null(scene) && scene != "" && scene != "all") {
    if (scene == "online") {
      scene_filter <- "AND s.is_online = TRUE"
    } else {
      scene_filter <- sprintf("AND s.scene_id = (SELECT scene_id FROM scenes WHERE slug = '%s')", scene)
    }
  }

  query <- sprintf("
    SELECT s.store_id, s.name as Store, s.city as City, s.state as State,
           s.is_online, s.zip_code,
           COUNT(ss.schedule_id) as schedule_count
    FROM stores s
    LEFT JOIN store_schedules ss ON s.store_id = ss.store_id AND ss.is_active = TRUE
    WHERE s.is_active = TRUE
      %s
    GROUP BY s.store_id, s.name, s.city, s.state, s.is_online, s.zip_code
    ORDER BY s.name
  ", scene_filter)

  # ... rest of function ...
})
```

**Step 2: Commit**

```bash
git add server/admin-stores-server.R
git commit -m "feat: apply scene filter to admin stores table"
```

---

## Phase 6: Testing & Documentation

### Task 6.1: Manual Testing Checklist

**Test each feature:**

1. **Schema & Admin UI**
   - [ ] Create new online store with country selection
   - [ ] Edit existing online store, verify country loads and saves
   - [ ] Verify physical stores still work (country defaults to USA)

2. **Online Organizers Display**
   - [ ] Select "Online" scene, verify world map appears
   - [ ] Verify markers at correct country/region locations
   - [ ] Click marker, verify popup shows
   - [ ] Switch to Cards view, verify online organizers display
   - [ ] Switch to Schedule view, verify it works (may be empty if no schedules)

3. **Community Links**
   - [ ] Open store modal, click "Share Community View"
   - [ ] Paste URL in new tab, verify filtered view loads
   - [ ] Verify banner appears with store name
   - [ ] Click "View All" on banner, verify filter clears
   - [ ] Navigate between tabs, verify filter persists
   - [ ] Verify dashboard stats are filtered
   - [ ] Verify players tab shows only players from that store
   - [ ] Verify tournaments tab shows only that store's tournaments

4. **Admin Scene Filtering**
   - [ ] Select a scene (e.g., "dfw"), go to Edit Players
   - [ ] Verify only players who competed in DFW appear
   - [ ] As superadmin, check "Show all scenes", verify all players appear
   - [ ] Repeat for Edit Tournaments and Edit Stores

### Task 6.2: Update Documentation

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `ROADMAP.md`

**Step 1: Add changelog entry**

```markdown
## [0.25.0] - 2026-XX-XX - Stores & Filtering Enhancements

### Added
- **Online Organizers World Map**: When "Online" scene selected, Stores tab shows world map with organizer markers placed by country/region
- **Cards View**: New card-based view toggle on Stores tab (replaces "All Stores" table), consistent across all scenes
- **Community Links**: Store-specific filtering via `?community=store-slug` URL parameter
  - Filters Dashboard, Players, Meta, and Tournaments to single store's data
  - Banner shows active filter with "View All" to clear
  - "Share Community View" button in store modals
- **Admin Scene Filtering**: Edit Players, Tournaments, and Stores tables respect scene selection
  - Super admins have "Show all scenes" toggle to override
- **Country Field**: Online stores can specify their country for map placement

### Changed
- Stores tab view toggle renamed from "All Stores" to "Cards"
- Online organizers section only shows when scene is "all" (not when viewing specific regions)

### Schema
- Added `country` column to stores table (default: 'USA')
```

**Step 2: Update roadmap**

Mark completed items in v0.25 section.

**Step 3: Commit**

```bash
git add CHANGELOG.md ROADMAP.md
git commit -m "docs: update changelog and roadmap for v0.25 features"
```

---

## Summary

**Total Tasks:** 18 tasks across 6 phases

**Phase 1 - Schema:** 3 tasks (migration, schema update, run migration)
**Phase 2 - Admin UI:** 3 tasks (country dropdown, add handler, edit handler)
**Phase 3 - Online Display:** 4 tasks (geo utils, world map, cards view, hide section)
**Phase 4 - Community Links:** 7 tasks (reactive, URL routing, banner, clear, modal button, dashboard filter, other tabs filter)
**Phase 5 - Admin Filtering:** 4 tasks (toggle UI, players, tournaments, stores)
**Phase 6 - Testing:** 2 tasks (manual testing, documentation)

**Estimated Commits:** ~20 small, focused commits
