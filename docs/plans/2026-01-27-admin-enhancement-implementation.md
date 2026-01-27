# Admin Pages Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance admin pages with bug fixes, online store support, delete functionality, multi-color decks, and wizard-based results entry.

**Architecture:** Shiny reactive UI with DuckDB backend. Changes span UI files (views/), server logic (app.R), and database schema. Each phase builds on previous work.

**Tech Stack:** R Shiny, bslib, DuckDB, shinyjs, reactable

**Testing Note:** This is a Shiny app without automated tests. Each task includes manual verification steps by running the app.

---

## Phase 1: Bug Fixes

### Task 1.1: Fix Bind Parameter Error

**Files:**
- Modify: `app.R:2691`

**Step 1: Locate and understand the bug**

The error "bind parameter values need to have the same length" occurs because `NULL` is passed to DuckDB instead of `NA_character_`.

Current code at line 2691:
```r
decklist_url <- if (nchar(input$result_decklist_url) > 0) input$result_decklist_url else NULL
```

**Step 2: Apply the fix**

Change `NULL` to `NA_character_`:
```r
decklist_url <- if (nchar(input$result_decklist_url) > 0) input$result_decklist_url else NA_character_
```

**Step 3: Verify the fix**

1. Run the app: `shiny::runApp()`
2. Log in to admin
3. Create a tournament
4. Add a result WITHOUT a decklist URL
5. Expected: Result saves successfully, no error

**Step 4: Commit**

```bash
git add app.R
git commit -m "fix: Resolve bind parameter error when decklist URL is empty

Changed NULL to NA_character_ for DuckDB compatibility."
```

---

### Task 1.2: Fix Search Button Alignment

**Files:**
- Modify: `views/admin-decks-ui.R:30-36`

**Step 1: Locate the misaligned layout**

Current code at lines 30-36:
```r
div(
  class = "row g-2 align-items-end mb-2",
  div(class = "col",
      textInput("card_search", "Search Card", placeholder = "Type card name...")),
  div(class = "col-auto",
      tags$label(class = "form-label", HTML("&nbsp;")),  # Spacer for alignment
      actionButton("search_card_btn", "Search", class = "btn-info"))
)
```

**Step 2: Replace with flex layout**

Replace lines 30-36 with:
```r
div(
  class = "d-flex gap-2 align-items-end mb-3",
  div(class = "flex-grow-1",
      textInput("card_search", "Search Card", placeholder = "Type card name...")),
  actionButton("search_card_btn", "Search", class = "btn-info mb-3")
)
```

**Step 3: Verify the fix**

1. Run the app: `shiny::runApp()`
2. Navigate to Admin > Manage Decks
3. Expected: Search button aligns with the bottom of the text input

**Step 4: Commit**

```bash
git add views/admin-decks-ui.R
git commit -m "fix: Align search button with card search input

Replaced row/col layout with flexbox for proper alignment."
```

---

## Phase 2: Database Migration

### Task 2.1: Update Schema File

**Files:**
- Modify: `db/schema.sql:23` (stores table)
- Modify: `db/schema.sql:58` (deck_archetypes table)
- Modify: `db/schema.sql:206-223` (store_activity view)

**Step 1: Add is_online to stores table**

After line 23 (`is_active BOOLEAN DEFAULT TRUE,`), add:
```sql
is_online BOOLEAN DEFAULT FALSE,
```

**Step 2: Add is_multi_color to deck_archetypes table**

After line 58 (`is_active BOOLEAN DEFAULT TRUE,`), add:
```sql
is_multi_color BOOLEAN DEFAULT FALSE,
```

**Step 3: Update store_activity view**

Replace the store_activity view (lines 206-223) with:
```sql
-- Store activity summary with location and unique players
CREATE OR REPLACE VIEW store_activity AS
SELECT
    s.store_id,
    s.name AS store_name,
    s.city,
    s.latitude,
    s.longitude,
    s.address,
    s.is_online,
    COUNT(DISTINCT t.tournament_id) AS total_tournaments,
    COUNT(DISTINCT r.player_id) AS unique_players,
    SUM(t.player_count) AS total_attendance,
    ROUND(AVG(t.player_count), 1) AS avg_attendance,
    MAX(t.event_date) AS last_event_date,
    MIN(t.event_date) AS first_event_date
FROM stores s
LEFT JOIN tournaments t ON s.store_id = t.store_id
LEFT JOIN results r ON t.tournament_id = r.tournament_id
WHERE s.is_active = TRUE
GROUP BY s.store_id, s.name, s.city, s.latitude, s.longitude, s.address, s.is_online;
```

**Step 4: Commit**

```bash
git add db/schema.sql
git commit -m "schema: Add is_online and is_multi_color columns

- stores.is_online for online tournament organizers
- deck_archetypes.is_multi_color for 3+ color decks
- Updated store_activity view to include is_online"
```

---

### Task 2.2: Create Migration Script

**Files:**
- Create: `R/migrate_v0.5.0.R`

**Step 1: Create the migration file**

Create `R/migrate_v0.5.0.R` with this content:
```r
# =============================================================================
# Database Migration v0.5.0
# Adds: is_online to stores, is_multi_color to deck_archetypes
# Run: source("R/migrate_v0.5.0.R"); migrate_v0.5.0(con)
# =============================================================================

#' Migrate database to v0.5.0
#' @param con DBI connection to DuckDB
#' @export
migrate_v0.5.0 <- function(con) {
  cat("Running migration v0.5.0...\n")

  # Add is_online to stores
tryCatch({
    dbExecute(con, "ALTER TABLE stores ADD COLUMN is_online BOOLEAN DEFAULT FALSE")
    cat("  ✓ Added is_online column to stores\n")
  }, error = function(e) {
    if (grepl("already exists|duplicate|already has", e$message, ignore.case = TRUE)) {
      cat("  - is_online column already exists\n")
    } else {
      stop(e)
    }
  })

  # Add is_multi_color to deck_archetypes
  tryCatch({
    dbExecute(con, "ALTER TABLE deck_archetypes ADD COLUMN is_multi_color BOOLEAN DEFAULT FALSE")
    cat("  ✓ Added is_multi_color column to deck_archetypes\n")
  }, error = function(e) {
    if (grepl("already exists|duplicate|already has", e$message, ignore.case = TRUE)) {
      cat("  - is_multi_color column already exists\n")
    } else {
      stop(e)
    }
  })

  # Update store_activity view
  tryCatch({
    dbExecute(con, "
      CREATE OR REPLACE VIEW store_activity AS
      SELECT
          s.store_id,
          s.name AS store_name,
          s.city,
          s.latitude,
          s.longitude,
          s.address,
          s.is_online,
          COUNT(DISTINCT t.tournament_id) AS total_tournaments,
          COUNT(DISTINCT r.player_id) AS unique_players,
          SUM(t.player_count) AS total_attendance,
          ROUND(AVG(t.player_count), 1) AS avg_attendance,
          MAX(t.event_date) AS last_event_date,
          MIN(t.event_date) AS first_event_date
      FROM stores s
      LEFT JOIN tournaments t ON s.store_id = t.store_id
      LEFT JOIN results r ON t.tournament_id = r.tournament_id
      WHERE s.is_active = TRUE
      GROUP BY s.store_id, s.name, s.city, s.latitude, s.longitude, s.address, s.is_online
    ")
    cat("  ✓ Updated store_activity view\n")
  }, error = function(e) {
    cat("  ✗ Failed to update store_activity view:", e$message, "\n")
  })

  cat("Migration v0.5.0 complete.\n")
}
```

**Step 2: Run the migration**

```r
source("R/db_connection.R")
source("R/migrate_v0.5.0.R")
con <- connect_db()
migrate_v0.5.0(con)
disconnect(con)
```

**Step 3: Verify migration**

```r
con <- connect_db()
# Check stores table has is_online
dbGetQuery(con, "SELECT column_name FROM information_schema.columns WHERE table_name = 'stores' AND column_name = 'is_online'")
# Check deck_archetypes has is_multi_color
dbGetQuery(con, "SELECT column_name FROM information_schema.columns WHERE table_name = 'deck_archetypes' AND column_name = 'is_multi_color'")
disconnect(con)
```

Expected: Both queries return one row.

**Step 4: Commit**

```bash
git add R/migrate_v0.5.0.R
git commit -m "feat: Add v0.5.0 migration script

Adds is_online and is_multi_color columns to existing databases."
```

---

## Phase 3: Manage Stores Enhancement

### Task 3.1: Add Online Store Checkbox and Conditional Fields

**Files:**
- Modify: `views/admin-stores-ui.R`

**Step 1: Add checkbox after hidden editing field**

After line 22 (`tags$script("document.getElementById('editing_store_id')...")`), add:
```r
checkboxInput("store_is_online", "Online store (no physical location)", value = FALSE),
```

**Step 2: Wrap physical address fields in conditionalPanel**

Wrap the address, city, state, zip fields (lines 23-27) in a conditionalPanel:
```r
conditionalPanel(
  condition = "!input.store_is_online",
  textInput("store_name", "Store Name"),
  textInput("store_address", "Street Address"),
  textInput("store_city", "City"),
  selectInput("store_state", "State", choices = c("TX" = "TX"), selected = "TX"),
  textInput("store_zip", "ZIP Code (optional)")
),
conditionalPanel(
  condition = "input.store_is_online",
  textInput("store_name_online", "Store/Organizer Name"),
  textInput("store_region", "Region/Coverage (optional)", placeholder = "e.g., North America, Global"),
),
```

**Step 3: Keep common fields outside conditionalPanel**

Website and schedule remain visible for both:
```r
textInput("store_website", "Website (optional)"),
textAreaInput("store_schedule", "Schedule Info (optional)",
              rows = 2,
              placeholder = "e.g., Locals every Friday at 7pm"),
```

**Step 4: Update geocode message to be conditional**

Wrap the geocode message in conditionalPanel:
```r
conditionalPanel(
  condition = "!input.store_is_online",
  div(
    class = "text-muted small mb-2",
    bsicons::bs_icon("geo-alt"), " Location will be automatically geocoded from address"
  )
),
```

**Step 5: Verify UI changes**

1. Run the app
2. Navigate to Admin > Manage Stores
3. Toggle the "Online store" checkbox
4. Expected: Address fields hide when checked, Region field appears

**Step 6: Commit**

```bash
git add views/admin-stores-ui.R
git commit -m "feat(stores): Add online store checkbox with conditional fields

Shows address fields for physical stores, region field for online stores."
```

---

### Task 3.2: Update Store Server Logic for Online Stores

**Files:**
- Modify: `app.R` (add_store observeEvent around line 3472)

**Step 1: Update add_store to handle online stores**

In the `observeEvent(input$add_store, {...})` block, add logic to handle online stores:

After getting store_name and store_city (around line 3476), add:
```r
is_online <- isTRUE(input$store_is_online)

# Get name from appropriate input
store_name <- if (is_online) {
  trimws(input$store_name_online)
} else {
  trimws(input$store_name)
}

store_city <- if (is_online) {
  trimws(input$store_region)  # Use region as "city" for online stores
} else {
  trimws(input$store_city)
}
```

**Step 2: Skip geocoding for online stores**

Replace the geocoding block with conditional logic:
```r
if (is_online) {
  # Online stores don't need geocoding
  lat <- NA_real_
  lng <- NA_real_
  address <- NA_character_
  state <- NA_character_
  zip_code <- NA_character_
} else {
  # Build full address for geocoding
  address_parts <- c(input$store_address, store_city)
  address_parts <- c(address_parts, if (nchar(input$store_state) > 0) input$store_state else "TX")
  if (nchar(input$store_zip) > 0) {
    address_parts <- c(address_parts, input$store_zip)
  }
  full_address <- paste(address_parts, collapse = ", ")

  # Geocode the address
  showNotification("Geocoding address...", type = "message", duration = 2)
  geo_result <- tidygeocoder::geo(full_address, method = "osm", quiet = TRUE)

  lat <- geo_result$lat
  lng <- geo_result$long

  if (is.na(lat) || is.na(lng)) {
    showNotification("Could not geocode address. Store added without coordinates.", type = "warning")
    lat <- NA_real_
    lng <- NA_real_
  }

  address <- if (nchar(input$store_address) > 0) input$store_address else NA_character_
  state <- if (nchar(input$store_state) > 0) input$store_state else "TX"
  zip_code <- if (nchar(input$store_zip) > 0) input$store_zip else NA_character_
}
```

**Step 3: Update INSERT to include is_online**

Update the dbExecute INSERT statement:
```r
dbExecute(rv$db_con, "
  INSERT INTO stores (store_id, name, address, city, state, zip_code, latitude, longitude, website, schedule_info, is_online)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
", params = list(new_id, store_name, address, store_city,
                 state, zip_code, lat, lng, website, schedule_info, is_online))
```

**Step 4: Clear both name inputs on success**

Add to form clearing:
```r
updateTextInput(session, "store_name_online", value = "")
updateTextInput(session, "store_region", value = "")
updateCheckboxInput(session, "store_is_online", value = FALSE)
```

**Step 5: Verify online store creation**

1. Run the app
2. Admin > Manage Stores
3. Check "Online store"
4. Enter name and region
5. Click Add Store
6. Expected: Store added without geocoding, appears in list

**Step 6: Commit**

```bash
git add app.R
git commit -m "feat(stores): Handle online store creation in server logic

Skips geocoding, stores region in city field, sets is_online flag."
```

---

### Task 3.3: Update Store Edit/Update for Online Stores

**Files:**
- Modify: `app.R` (store selection and update_store around lines 3600-3709)

**Step 1: Update store selection to populate online fields**

In `observeEvent(input$admin_store_list__reactable__selected, {...})`, update the form population to handle online stores:

After populating existing fields, add:
```r
# Handle online store fields
is_online <- isTRUE(store$is_online)
updateCheckboxInput(session, "store_is_online", value = is_online)

if (is_online) {
  updateTextInput(session, "store_name_online", value = store$name)
  updateTextInput(session, "store_region", value = if (is.na(store$city)) "" else store$city)
} else {
  updateTextInput(session, "store_name", value = store$name)
}
```

**Step 2: Update the store list query to include is_online**

Update the query in `output$admin_store_list`:
```r
data <- dbGetQuery(rv$db_con, "
  SELECT store_id, name as Store, city as City, state as State, is_online
  FROM stores
  WHERE is_active = TRUE
  ORDER BY name
")
```

Add display for online stores in the reactable columns:
```r
columns = list(
  store_id = colDef(show = FALSE),
  is_online = colDef(
    name = "Type",
    cell = function(value) if (isTRUE(value)) "Online" else "Physical"
  )
)
```

**Step 3: Update update_store to handle online stores**

Similar to add_store, update the `observeEvent(input$update_store, {...})` block to handle is_online.

**Step 4: Verify edit/update**

1. Run the app
2. Add an online store
3. Click to edit it
4. Expected: Online checkbox checked, name/region populated
5. Update and save
6. Expected: Changes saved correctly

**Step 5: Commit**

```bash
git add app.R
git commit -m "feat(stores): Support editing online stores

Populates correct fields based on is_online flag."
```

---

### Task 3.4: Add Delete Store Functionality

**Files:**
- Modify: `views/admin-stores-ui.R`
- Modify: `app.R`

**Step 1: Add delete button to UI**

In `views/admin-stores-ui.R`, add a delete button next to update:
```r
div(
  class = "d-flex gap-2",
  actionButton("add_store", "Add Store", class = "btn-primary"),
  actionButton("update_store", "Update Store", class = "btn-success", style = "display: none;"),
  actionButton("delete_store", "Delete Store", class = "btn-danger", style = "display: none;")
)
```

**Step 2: Add delete confirmation modal to UI**

Add at the end of admin_stores_ui:
```r
# Delete confirmation modal
tags$div(
  id = "delete_store_modal",
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
        uiOutput("delete_store_message")
      ),
      tags$div(
        class = "modal-footer",
        tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
        actionButton("confirm_delete_store", "Delete", class = "btn-danger")
      )
    )
  )
)
```

**Step 3: Add server logic for delete**

In `app.R`, add delete handling:
```r
# Show/hide delete button and check if deletable
observe({
  req(input$editing_store_id)
  store_id <- as.integer(input$editing_store_id)

  # Check for related tournaments
  count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM tournaments WHERE store_id = ?
  ", params = list(store_id))$cnt

  rv$store_tournament_count <- count
  rv$can_delete_store <- count == 0
})

# Delete button click - show modal
observeEvent(input$delete_store, {
  req(input$editing_store_id)

  store_id <- as.integer(input$editing_store_id)
  store <- dbGetQuery(rv$db_con, "SELECT name FROM stores WHERE store_id = ?",
                      params = list(store_id))

  if (rv$can_delete_store) {
    output$delete_store_message <- renderUI({
      div(
        p(sprintf("Are you sure you want to delete '%s'?", store$name)),
        p(class = "text-danger", "This action cannot be undone.")
      )
    })
    # Show modal via JavaScript
    shinyjs::runjs("$('#delete_store_modal').modal('show');")
  } else {
    showNotification(
      sprintf("Cannot delete: %d tournaments reference this store", rv$store_tournament_count),
      type = "error"
    )
  }
})

# Confirm delete
observeEvent(input$confirm_delete_store, {
  req(rv$is_admin, rv$db_con, input$editing_store_id)
  store_id <- as.integer(input$editing_store_id)

  tryCatch({
    dbExecute(rv$db_con, "DELETE FROM stores WHERE store_id = ?",
              params = list(store_id))
    showNotification("Store deleted", type = "message")

    # Hide modal and reset form
    shinyjs::runjs("$('#delete_store_modal').modal('hide');")
    updateTextInput(session, "editing_store_id", value = "")
    # ... clear other fields ...
    shinyjs::show("add_store")
    shinyjs::hide("update_store")
    shinyjs::hide("delete_store")

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})
```

**Step 4: Show delete button when editing**

In the store selection observer, add:
```r
shinyjs::show("delete_store")
```

In cancel_edit_store and after successful update, add:
```r
shinyjs::hide("delete_store")
```

**Step 5: Verify delete functionality**

1. Run the app
2. Add a new test store
3. Click to edit it
4. Click Delete
5. Expected: Modal appears
6. Confirm delete
7. Expected: Store removed from list

**Step 6: Commit**

```bash
git add views/admin-stores-ui.R app.R
git commit -m "feat(stores): Add delete functionality with confirmation modal

Blocks deletion if store has tournaments, shows modal for confirmation."
```

---

## Phase 4: Stores Tab - Online Organizers Section

### Task 4.1: Add Online Tournament Organizers Section

**Files:**
- Modify: `views/stores-ui.R`

**Step 1: Add section below map**

After the store_list card (after line 51), add:
```r
# Online Tournament Organizers section
uiOutput("online_stores_section")
```

**Step 2: Add server logic to render section**

In `app.R`, add:
```r
output$online_stores_section <- renderUI({
  req(rv$db_con)

  online_stores <- dbGetQuery(rv$db_con, "
    SELECT name, city as region, website, schedule_info
    FROM stores
    WHERE is_online = TRUE AND is_active = TRUE
    ORDER BY name
  ")

  if (nrow(online_stores) == 0) {
    return(NULL)  # Don't show section if no online stores
  }

  card(
    card_header(
      class = "d-flex align-items-center gap-2",
      bsicons::bs_icon("globe"),
      span("Online Tournament Organizers")
    ),
    card_body(
      div(
        class = "row g-3",
        lapply(1:nrow(online_stores), function(i) {
          store <- online_stores[i, ]
          div(
            class = "col-md-4",
            div(
              class = "border rounded p-3 h-100",
              h6(class = "mb-1", store$name),
              if (!is.na(store$region) && nchar(store$region) > 0)
                p(class = "text-muted small mb-1", bsicons::bs_icon("geo"), store$region),
              if (!is.na(store$schedule_info) && nchar(store$schedule_info) > 0)
                p(class = "small mb-1", bsicons::bs_icon("calendar"), store$schedule_info),
              if (!is.na(store$website) && nchar(store$website) > 0)
                a(href = store$website, target = "_blank", class = "small",
                  bsicons::bs_icon("link-45deg"), "Website")
            )
          )
        })
      )
    )
  )
})
```

**Step 3: Update map query to exclude online stores**

Find the map data query and add filter:
```r
WHERE is_online = FALSE AND is_active = TRUE
```

**Step 4: Verify online stores section**

1. Run the app
2. Add an online store via admin
3. Navigate to Stores tab
4. Expected: Online store appears in "Online Tournament Organizers" section below map
5. Expected: Online store does NOT appear on map

**Step 5: Commit**

```bash
git add views/stores-ui.R app.R
git commit -m "feat(stores): Add Online Tournament Organizers section

Shows online stores in card grid below map, excludes from map markers."
```

---

## Phase 5: Manage Decks Enhancement

### Task 5.1: Reorganize Form Layout

**Files:**
- Modify: `views/admin-decks-ui.R`

**Step 1: Restructure the entire form**

Replace the card_body content with new layout:
```r
card_body(
  # Hidden field for edit mode
  textInput("editing_archetype_id", NULL, value = ""),
  tags$script("document.getElementById('editing_archetype_id').parentElement.style.display = 'none';"),

  # Identity section
  textInput("deck_name", "Archetype Name", placeholder = "e.g., Fenriloogamon"),
  selectInput("deck_primary_color", "Primary Color",
              choices = c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
  selectInput("deck_secondary_color", "Secondary Color",
              choices = c("None" = "", "Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
  checkboxInput("deck_multi_color", "Multi-color deck (3+ colors)", value = FALSE),

  hr(),

  # Display Card section
  h5("Display Card"),
  layout_columns(
    col_widths = c(4, 8),
    # Card preview on left
    div(
      class = "text-center",
      uiOutput("selected_card_preview")
    ),
    # Search on right
    div(
      div(
        class = "d-flex gap-2 align-items-end mb-3",
        div(class = "flex-grow-1",
            textInput("card_search", "Search", placeholder = "Type card name...")),
        actionButton("search_card_btn", "Search", class = "btn-info mb-3")
      ),
      uiOutput("card_search_results"),
      div(class = "mt-2",
          textInput("selected_card_id", "Selected Card ID", placeholder = "e.g., BT17-042"),
          div(class = "small text-muted", "Click a card above to auto-fill, or enter ID manually"))
    )
  ),

  hr(),

  # Action buttons
  div(
    class = "d-flex gap-2",
    actionButton("add_archetype", "Add Archetype", class = "btn-primary"),
    actionButton("update_archetype", "Update Archetype", class = "btn-success", style = "display: none;"),
    actionButton("delete_archetype", "Delete Archetype", class = "btn-danger", style = "display: none;")
  )
)
```

**Step 2: Verify layout**

1. Run the app
2. Navigate to Admin > Manage Decks
3. Expected: Name/colors at top, then card preview on left with search on right

**Step 3: Commit**

```bash
git add views/admin-decks-ui.R
git commit -m "refactor(decks): Reorganize form layout

Identity fields first, display card section with side-by-side preview and search."
```

---

### Task 5.2: Add Multi-Color Support

**Files:**
- Modify: `app.R` (add_archetype and update_archetype)

**Step 1: Update add_archetype to include is_multi_color**

In the INSERT statement for add_archetype:
```r
dbExecute(rv$db_con, "
  INSERT INTO deck_archetypes (archetype_id, archetype_name, display_card_id, primary_color, secondary_color, is_multi_color)
  VALUES (?, ?, ?, ?, ?, ?)
", params = list(new_id, name, card_id, primary_color, secondary_color, input$deck_multi_color))
```

**Step 2: Update update_archetype to include is_multi_color**

```r
dbExecute(rv$db_con, "
  UPDATE deck_archetypes
  SET archetype_name = ?, primary_color = ?, secondary_color = ?, display_card_id = ?, is_multi_color = ?, updated_at = CURRENT_TIMESTAMP
  WHERE archetype_id = ?
", params = list(name, primary_color, secondary_color, card_id, input$deck_multi_color, archetype_id))
```

**Step 3: Update archetype selection to populate checkbox**

In the archetype selection observer:
```r
updateCheckboxInput(session, "deck_multi_color",
                    value = isTRUE(arch$is_multi_color))
```

**Step 4: Clear checkbox on form reset**

```r
updateCheckboxInput(session, "deck_multi_color", value = FALSE)
```

**Step 5: Update archetype list to show multi-color badge**

Update the archetype_list reactable to show multi-color:
```r
# Include is_multi_color in query
data <- dbGetQuery(rv$db_con, "
  SELECT archetype_id, archetype_name as Deck, primary_color, secondary_color, is_multi_color, display_card_id as 'Card ID'
  FROM deck_archetypes
  WHERE is_active = TRUE
  ORDER BY archetype_name
")

# Update color column to show Multi badge
columns = list(
  ...
  primary_color = colDef(
    name = "Color",
    cell = function(value, index) {
      if (isTRUE(data$is_multi_color[index])) {
        span(class = "badge", style = "background-color: #E91E8C; color: white;", "Multi")
      } else {
        secondary <- data$secondary_color[index]
        deck_color_badge_dual(value, secondary)
      }
    }
  ),
  is_multi_color = colDef(show = FALSE),
  ...
)
```

**Step 6: Verify multi-color**

1. Run the app
2. Add a new archetype with "Multi-color deck" checked
3. Expected: Saves with is_multi_color = TRUE
4. Expected: Shows pink "Multi" badge in list

**Step 7: Commit**

```bash
git add app.R
git commit -m "feat(decks): Add multi-color deck support

Checkbox for 3+ color decks, pink 'Multi' badge in list display."
```

---

### Task 5.3: Add Delete Archetype Functionality

**Files:**
- Modify: `views/admin-decks-ui.R`
- Modify: `app.R`

**Step 1: Add delete confirmation modal to UI**

Similar to stores, add modal at end of admin_decks_ui:
```r
tags$div(
  id = "delete_archetype_modal",
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
        uiOutput("delete_archetype_message")
      ),
      tags$div(
        class = "modal-footer",
        tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel"),
        actionButton("confirm_delete_archetype", "Delete", class = "btn-danger")
      )
    )
  )
)
```

**Step 2: Add server logic for delete**

```r
# Check if archetype can be deleted
observe({
  req(input$editing_archetype_id)
  archetype_id <- as.integer(input$editing_archetype_id)

  count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM results WHERE archetype_id = ?
  ", params = list(archetype_id))$cnt

  rv$archetype_result_count <- count
  rv$can_delete_archetype <- count == 0
})

# Delete button click
observeEvent(input$delete_archetype, {
  req(input$editing_archetype_id)

  archetype_id <- as.integer(input$editing_archetype_id)
  arch <- dbGetQuery(rv$db_con, "SELECT archetype_name FROM deck_archetypes WHERE archetype_id = ?",
                     params = list(archetype_id))

  if (rv$can_delete_archetype) {
    output$delete_archetype_message <- renderUI({
      div(
        p(sprintf("Are you sure you want to delete '%s'?", arch$archetype_name)),
        p(class = "text-danger", "This action cannot be undone.")
      )
    })
    shinyjs::runjs("$('#delete_archetype_modal').modal('show');")
  } else {
    showNotification(
      sprintf("Cannot delete: used in %d results", rv$archetype_result_count),
      type = "error"
    )
  }
})

# Confirm delete
observeEvent(input$confirm_delete_archetype, {
  req(rv$is_admin, rv$db_con, input$editing_archetype_id)
  archetype_id <- as.integer(input$editing_archetype_id)

  tryCatch({
    dbExecute(rv$db_con, "DELETE FROM deck_archetypes WHERE archetype_id = ?",
              params = list(archetype_id))
    showNotification("Archetype deleted", type = "message")

    shinyjs::runjs("$('#delete_archetype_modal').modal('hide');")
    # Reset form...
    updateTextInput(session, "editing_archetype_id", value = "")
    updateTextInput(session, "deck_name", value = "")
    updateCheckboxInput(session, "deck_multi_color", value = FALSE)
    # ... clear other fields ...

    shinyjs::show("add_archetype")
    shinyjs::hide("update_archetype")
    shinyjs::hide("delete_archetype")

    updateSelectizeInput(session, "result_deck", choices = get_archetype_choices(rv$db_con))

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})
```

**Step 3: Show/hide delete button appropriately**

Update archetype selection and cancel handlers.

**Step 4: Verify delete**

1. Run the app
2. Add a test archetype
3. Click to edit, click Delete
4. Expected: Modal appears, delete succeeds
5. Try to delete an archetype with results
6. Expected: Error notification, deletion blocked

**Step 5: Commit**

```bash
git add views/admin-decks-ui.R app.R
git commit -m "feat(decks): Add delete functionality with modal confirmation

Blocks deletion if archetype has results, shows confirmation modal."
```

---

## Phase 6: Enter Results Wizard

### Task 6.1: Create Wizard UI Structure

**Files:**
- Modify: `views/admin-results-ui.R`

**Step 1: Replace entire file with wizard layout**

```r
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
        selectInput("tournament_store", "Store", choices = NULL),
        dateInput("tournament_date", "Date", value = Sys.Date()),
        selectInput("tournament_type", "Event Type", choices = EVENT_TYPES),
        selectInput("tournament_format", "Format/Set", choices = FORMAT_CHOICES),
        numericInput("tournament_players", "Number of Players", value = 8, min = 2),
        numericInput("tournament_rounds", "Number of Rounds", value = 3, min = 1),
        div(
          class = "d-flex justify-content-end mt-3",
          actionButton("create_tournament", "Create Tournament →", class = "btn-primary btn-lg")
        )
      )
    )
  ),

  # Step 2: Add Results
  shinyjs::hidden(
    div(
      id = "wizard_step2",
      # Tournament summary bar
      uiOutput("tournament_summary_bar"),

      layout_columns(
        col_widths = c(5, 7),
        # Left: Add result form
        card(
          card_header("Add Player Result"),
          card_body(
            # Player selection with quick add
            selectizeInput("result_player", "Player Name",
                           choices = NULL,
                           options = list(create = TRUE, placeholder = "Type to search or add new...")),
            shinyjs::hidden(
              div(
                id = "quick_add_player_form",
                class = "border rounded p-2 mb-3 bg-light",
                textInput("quick_player_name", "New Player Name"),
                div(
                  class = "d-flex gap-2",
                  actionButton("quick_add_player_submit", "Add", class = "btn-sm btn-success"),
                  actionButton("quick_add_player_cancel", "Cancel", class = "btn-sm btn-secondary")
                )
              )
            ),
            actionLink("show_quick_add_player", "+ New Player", class = "small"),

            hr(),

            # Deck selection with quick add
            selectizeInput("result_deck", "Deck Archetype",
                           choices = NULL,
                           options = list(placeholder = "Type to search decks...")),
            shinyjs::hidden(
              div(
                id = "quick_add_deck_form",
                class = "border rounded p-2 mb-3 bg-light",
                textInput("quick_deck_name", "Deck Name", placeholder = "e.g., New Archetype"),
                selectInput("quick_deck_color", "Primary Color",
                            choices = c("Red", "Blue", "Yellow", "Green", "Purple", "Black", "White")),
                div(class = "small text-muted mb-2", "(Full details can be added later in Manage Decks)"),
                div(
                  class = "d-flex gap-2",
                  actionButton("quick_add_deck_submit", "Add", class = "btn-sm btn-success"),
                  actionButton("quick_add_deck_cancel", "Cancel", class = "btn-sm btn-secondary")
                )
              )
            ),
            actionLink("show_quick_add_deck", "+ New Deck", class = "small"),

            hr(),

            numericInput("result_placement", "Placement", value = 1, min = 1),
            layout_columns(
              col_widths = c(4, 4, 4),
              numericInput("result_wins", "Wins", value = 0, min = 0),
              numericInput("result_losses", "Losses", value = 0, min = 0),
              numericInput("result_ties", "Ties", value = 0, min = 0)
            ),
            textInput("result_decklist_url", "Decklist URL (optional)",
                      placeholder = "e.g., digimonmeta.com/deck/..."),
            actionButton("add_result", "Add Result", class = "btn-success btn-block mt-3")
          )
        ),
        # Right: Results table
        card(
          card_header(
            class = "d-flex justify-content-between align-items-center",
            uiOutput("results_count_header"),
            actionButton("clear_tournament", "Start Over", class = "btn-sm btn-outline-warning")
          ),
          card_body(
            reactableOutput("current_results")
          )
        )
      ),

      # Bottom navigation
      div(
        class = "d-flex justify-content-between mt-3",
        actionButton("wizard_back", "← Back to Details", class = "btn-secondary"),
        actionButton("finish_tournament", "Mark Complete ✓", class = "btn-primary btn-lg")
      )
    )
  ),

  # Duplicate tournament modal
  tags$div(
    id = "duplicate_tournament_modal",
    class = "modal fade",
    tabindex = "-1",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          tags$h5(class = "modal-title", "Possible Duplicate Tournament"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(
          class = "modal-body",
          uiOutput("duplicate_tournament_message")
        ),
        tags$div(
          class = "modal-footer",
          actionButton("edit_existing_tournament", "View/Edit Existing", class = "btn-info"),
          actionButton("create_anyway", "Create Anyway", class = "btn-warning"),
          tags$button(type = "button", class = "btn btn-secondary", `data-bs-dismiss` = "modal", "Cancel")
        )
      )
    )
  )
)
```

**Step 2: Add wizard CSS**

In `www/custom.css`, add:
```css
/* Wizard steps */
.wizard-steps {
  border-bottom: 2px solid #dee2e6;
  padding-bottom: 1rem;
}

.wizard-step {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #6c757d;
}

.wizard-step.active {
  color: #0F4C81;
  font-weight: bold;
}

.wizard-step .step-number {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: #dee2e6;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.875rem;
}

.wizard-step.active .step-number {
  background: #0F4C81;
  color: white;
}

.wizard-step.completed .step-number {
  background: #198754;
  color: white;
}
```

**Step 3: Commit**

```bash
git add views/admin-results-ui.R www/custom.css
git commit -m "feat(results): Create wizard UI structure

Two-step wizard with step indicators, quick-add forms, duplicate modal."
```

---

### Task 6.2: Implement Wizard Navigation Logic

**Files:**
- Modify: `app.R`

**Step 1: Add reactive for wizard step**

```r
rv$wizard_step <- 1
```

**Step 2: Update step indicators**

```r
observe({
  if (rv$wizard_step == 1) {
    shinyjs::show("wizard_step1")
    shinyjs::hide("wizard_step2")
    shinyjs::runjs("$('#step1_indicator').addClass('active'); $('#step2_indicator').removeClass('active');")
  } else {
    shinyjs::hide("wizard_step1")
    shinyjs::show("wizard_step2")
    shinyjs::runjs("$('#step2_indicator').addClass('active'); $('#step1_indicator').removeClass('active').addClass('completed');")
  }
})
```

**Step 3: Handle wizard_back button**

```r
observeEvent(input$wizard_back, {
  rv$wizard_step <- 1
})
```

**Step 4: Update create_tournament to advance wizard**

At end of successful tournament creation:
```r
rv$wizard_step <- 2
```

**Step 5: Verify navigation**

1. Run the app
2. Create tournament → advances to Step 2
3. Click "Back to Details" → returns to Step 1
4. Step indicators update correctly

**Step 6: Commit**

```bash
git add app.R
git commit -m "feat(results): Implement wizard navigation

Step transitions, back button, step indicator updates."
```

---

### Task 6.3: Implement Duplicate Tournament Detection

**Files:**
- Modify: `app.R`

**Step 1: Check for duplicates before creating**

Modify the `create_tournament` observeEvent:
```r
observeEvent(input$create_tournament, {
  req(rv$is_admin, rv$db_con)

  store_id <- as.integer(input$tournament_store)
  event_date <- input$tournament_date

  # Check for existing tournament
  existing <- dbGetQuery(rv$db_con, "
    SELECT t.tournament_id, t.player_count, t.event_type,
           (SELECT COUNT(*) FROM results WHERE tournament_id = t.tournament_id) as result_count,
           s.name as store_name
    FROM tournaments t
    JOIN stores s ON t.store_id = s.store_id
    WHERE t.store_id = ? AND t.event_date = ?
  ", params = list(store_id, event_date))

  if (nrow(existing) > 0) {
    # Store for later use
    rv$duplicate_tournament <- existing[1, ]

    output$duplicate_tournament_message <- renderUI({
      div(
        p(sprintf("A tournament at %s on %s already exists:",
                  existing$store_name[1], format(event_date, "%B %d, %Y"))),
        tags$ul(
          tags$li(sprintf("%d players registered", existing$player_count[1])),
          tags$li(sprintf("%d results entered", existing$result_count[1])),
          tags$li(sprintf("Event type: %s", existing$event_type[1]))
        ),
        p("What would you like to do?")
      )
    })

    shinyjs::runjs("$('#duplicate_tournament_modal').modal('show');")
    return()
  }

  # No duplicate, proceed with creation
  create_new_tournament()
})
```

**Step 2: Handle modal buttons**

```r
# Edit existing tournament
observeEvent(input$edit_existing_tournament, {
  req(rv$duplicate_tournament)
  shinyjs::runjs("$('#duplicate_tournament_modal').modal('hide');")

  rv$active_tournament_id <- rv$duplicate_tournament$tournament_id
  rv$wizard_step <- 2
})

# Create anyway
observeEvent(input$create_anyway, {
  shinyjs::runjs("$('#duplicate_tournament_modal').modal('hide');")
  create_new_tournament()
})

# Helper function
create_new_tournament <- function() {
  # ... existing tournament creation logic ...
  rv$wizard_step <- 2
}
```

**Step 3: Verify duplicate detection**

1. Create a tournament
2. Try to create another for same store + date
3. Expected: Modal appears with existing tournament info
4. Click "View/Edit Existing" → loads existing tournament
5. Click "Create Anyway" → creates new tournament

**Step 4: Commit**

```bash
git add app.R
git commit -m "feat(results): Add duplicate tournament detection

Modal shows existing tournament info with options to edit or create anyway."
```

---

### Task 6.4: Implement Quick Add Forms

**Files:**
- Modify: `app.R`

**Step 1: Show/hide quick add player form**

```r
observeEvent(input$show_quick_add_player, {
  shinyjs::show("quick_add_player_form")
})

observeEvent(input$quick_add_player_cancel, {
  shinyjs::hide("quick_add_player_form")
  updateTextInput(session, "quick_player_name", value = "")
})

observeEvent(input$quick_add_player_submit, {
  name <- trimws(input$quick_player_name)
  req(nchar(name) > 0)

  # Create player
  max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(player_id), 0) as max_id FROM players")$max_id
  player_id <- max_id + 1

  dbExecute(rv$db_con, "INSERT INTO players (player_id, display_name) VALUES (?, ?)",
            params = list(player_id, name))

  showNotification(sprintf("Added player: %s", name), type = "message")

  # Update dropdown and select new player
  choices <- get_player_choices(rv$db_con)
  updateSelectizeInput(session, "result_player", choices = choices, selected = player_id)

  # Hide form
  shinyjs::hide("quick_add_player_form")
  updateTextInput(session, "quick_player_name", value = "")
})
```

**Step 2: Show/hide quick add deck form**

```r
observeEvent(input$show_quick_add_deck, {
  shinyjs::show("quick_add_deck_form")
})

observeEvent(input$quick_add_deck_cancel, {
  shinyjs::hide("quick_add_deck_form")
  updateTextInput(session, "quick_deck_name", value = "")
})

observeEvent(input$quick_add_deck_submit, {
  name <- trimws(input$quick_deck_name)
  color <- input$quick_deck_color
  req(nchar(name) > 0)

  # Create archetype
  max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(archetype_id), 0) as max_id FROM deck_archetypes")$max_id
  archetype_id <- max_id + 1

  dbExecute(rv$db_con, "
    INSERT INTO deck_archetypes (archetype_id, archetype_name, primary_color)
    VALUES (?, ?, ?)
  ", params = list(archetype_id, name, color))

  showNotification(sprintf("Added deck: %s", name), type = "message")

  # Update dropdown and select new deck
  choices <- get_archetype_choices(rv$db_con)
  updateSelectizeInput(session, "result_deck", choices = choices, selected = archetype_id)

  # Hide form
  shinyjs::hide("quick_add_deck_form")
  updateTextInput(session, "quick_deck_name", value = "")
})
```

**Step 3: Add tournament summary bar**

```r
output$tournament_summary_bar <- renderUI({
  req(rv$active_tournament_id)

  info <- dbGetQuery(rv$db_con, "
    SELECT s.name as store_name, t.event_date, t.event_type, t.player_count
    FROM tournaments t
    JOIN stores s ON t.store_id = s.store_id
    WHERE t.tournament_id = ?
  ", params = list(rv$active_tournament_id))

  div(
    class = "alert alert-info d-flex align-items-center gap-3 mb-3",
    bsicons::bs_icon("geo-alt-fill"),
    span(info$store_name),
    span("|"),
    span(format(info$event_date, "%b %d, %Y")),
    span("|"),
    span(info$event_type),
    span("|"),
    span(sprintf("%d players", info$player_count))
  )
})

output$results_count_header <- renderUI({
  req(rv$active_tournament_id)

  result_count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM results WHERE tournament_id = ?
  ", params = list(rv$active_tournament_id))$cnt

  player_count <- dbGetQuery(rv$db_con, "
    SELECT player_count FROM tournaments WHERE tournament_id = ?
  ", params = list(rv$active_tournament_id))$player_count

  sprintf("Results Entered (%d/%d)", result_count, player_count)
})
```

**Step 4: Verify quick add forms**

1. Run the app, go to Step 2
2. Click "+ New Player" → inline form appears
3. Add player → dropdown updates, new player selected
4. Same for deck

**Step 5: Commit**

```bash
git add app.R
git commit -m "feat(results): Implement quick add forms and summary bar

Inline forms for adding players/decks, tournament summary header."
```

---

### Task 6.5: Clean Up and Final Polish

**Files:**
- Modify: `app.R`

**Step 1: Remove bulk paste mode**

Delete all code related to:
- `input$result_entry_mode`
- `input$bulk_results`
- `parse_bulk`
- `submit_bulk`
- `bulk_preview_*`

**Step 2: Reset wizard on completion**

In `finish_tournament`:
```r
observeEvent(input$finish_tournament, {
  req(rv$active_tournament_id)

  showNotification("Tournament completed!", type = "message")

  # Reset wizard
  rv$active_tournament_id <- NULL
  rv$wizard_step <- 1
  rv$current_results <- data.frame()

  # Clear forms
  updateNumericInput(session, "result_placement", value = 1)
  updateNumericInput(session, "result_wins", value = 0)
  updateNumericInput(session, "result_losses", value = 0)
  updateNumericInput(session, "result_ties", value = 0)
  updateTextInput(session, "result_decklist_url", value = "")
})
```

**Step 3: Reset wizard on clear/start over**

Update `clear_tournament`:
```r
observeEvent(input$clear_tournament, {
  rv$active_tournament_id <- NULL
  rv$wizard_step <- 1
  rv$current_results <- data.frame()
})
```

**Step 4: Full end-to-end test**

1. Run the app
2. Complete full flow:
   - Create tournament
   - Add 3 results with mix of existing/new players and decks
   - Mark complete
   - Verify wizard resets
3. Test duplicate detection
4. Test all admin pages

**Step 5: Commit**

```bash
git add app.R views/admin-results-ui.R
git commit -m "feat(results): Complete wizard implementation

Remove bulk mode, add reset on completion, final polish."
```

---

## Final Commit

After all phases complete:

```bash
git add -A
git commit -m "v0.5.0: Admin pages enhancement

- Bug fixes: bind parameter error, button alignment
- Manage Stores: online store support, delete functionality
- Stores tab: online tournament organizers section
- Manage Decks: layout reorg, multi-color support, delete functionality
- Enter Results: wizard flow, duplicate detection, quick add forms

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

*Plan Version: 1.0*
*Created: January 27, 2026*
