# Admin Pages Enhancement Design

**Date:** January 27, 2026
**Status:** Approved
**Version:** 1.0

## Overview

Enhance the three admin pages (Enter Results, Manage Decks, Manage Stores) to fix known bugs, add missing functionality, and improve user experience.

### Goals
- Fix existing bugs (bind parameter error, button alignment)
- Add delete functionality for correcting mistakes
- Support online stores/tournament organizers
- Improve form layouts and workflow
- Add duplicate tournament detection

### Out of Scope
- Multi-user authentication (noted for future)
- Soft delete / archiving functionality
- Bulk paste mode for results (may revisit later)

---

## Section 1: Bug Fixes

### 1.1 Bind Parameter Error in Enter Results

**Problem:** When adding a result with no decklist URL, the error "bind parameter values need to have the same length" appears.

**Root Cause:** Line 2691 in `app.R` sets `decklist_url` to `NULL` instead of `NA_character_`. DuckDB's parameterized queries don't handle R's `NULL` properly.

**Fix:**
```r
# Before (line 2691)
decklist_url <- if (nchar(input$result_decklist_url) > 0) input$result_decklist_url else NULL

# After
decklist_url <- if (nchar(input$result_decklist_url) > 0) input$result_decklist_url else NA_character_
```

**Files affected:** `app.R` (single line change)

---

### 1.2 Search Button Alignment in Manage Decks

**Problem:** The "Search" button doesn't align vertically with the card search text input.

**Root Cause:** The button's parent div uses `col-auto` but lacks proper flex alignment.

**Fix:** Restructure the search row layout in `views/admin-decks-ui.R`:
```r
div(
  class = "d-flex gap-2 align-items-end mb-3",
  div(class = "flex-grow-1",
      textInput("card_search", "Search Card", placeholder = "Type card name...")),
  actionButton("search_card_btn", "Search", class = "btn-info mb-3")
)
```

**Files affected:** `views/admin-decks-ui.R`

---

## Section 2: Manage Stores Enhancement

### 2.1 Online Store Support

**Feature:** Add ability to create stores without physical addresses for online tournament organizers.

**UI Changes:**

Add checkbox at top of form: `☐ Online store (no physical location)`

When checked:
- Hide: address, city, state, zip fields
- Show: optional "Region/Coverage" text field (e.g., "North America", "Global")
- Skip geocoding entirely
- Store will not appear on map

When unchecked (default):
- Show all physical address fields (current behavior)

**Form layout:**

```
☐ Online store (no physical location)

[If unchecked - physical store]     [If checked - online store]
────────────────────────────────    ────────────────────────────
Store Name: [___________]           Store Name: [___________]
Address:    [___________]           Region:     [___________]
City:       [___________]           Website:    [___________]
State:      [TX ▼]                  Schedule:   [___________]
ZIP:        [___________]
Website:    [___________]
Schedule:   [___________]

[Add Store] [Delete]                [Add Store] [Delete]
```

**Database change:** Add `is_online BOOLEAN DEFAULT FALSE` column to `stores` table.

**Server logic changes:**
- Skip geocoding when `is_online = TRUE`
- Set `latitude = NULL`, `longitude = NULL` for online stores
- Store region info in `city` field for online stores

---

### 2.2 Stores Tab Update

**Feature:** Show online tournament organizers in a separate section below the map.

**Layout:**
```
┌─────────────────────────────────────────┐
│            [Interactive Map]            │
│      (physical stores only, filtered    │
│         by is_online = FALSE)           │
└─────────────────────────────────────────┘

Online Tournament Organizers
┌──────────────────┬──────────────────────┐
│ Discord Digimon  │ Region: North America│
│ TCG League       │ Schedule: Saturdays  │
└──────────────────┴──────────────────────┘
```

**Query changes:**
- Map query: `WHERE is_online = FALSE AND is_active = TRUE`
- Online section query: `WHERE is_online = TRUE AND is_active = TRUE`

---

### 2.3 Delete Store Functionality

**Feature:** Allow deletion of stores with no associated tournaments.

**UI Changes:**
- Add delete button (trash icon) that appears when editing a store
- Delete button disabled if store has tournaments

**Behavior:**
1. User clicks row to edit store → form populates, delete button appears
2. Check: `SELECT COUNT(*) FROM tournaments WHERE store_id = ?`
3. If count > 0: Button disabled with tooltip "Cannot delete: X tournaments reference this store"
4. If count = 0: Button enabled
5. On click: Modal confirmation "Delete [Store Name]? This cannot be undone."
6. On confirm: `DELETE FROM stores WHERE store_id = ?`

---

## Section 3: Manage Decks Enhancement

### 3.1 Form Layout Reorganization

**Current issues:**
- Display card section feels disconnected from name/colors
- Card preview appears at bottom when editing
- Flow is unintuitive

**New layout:**

```
┌─────────────────────────────────────────────────────┐
│ Add New Archetype                    [Cancel Edit]  │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Archetype Name:   [_________________________]       │
│                                                     │
│ Primary Color:    [Dropdown______________▼]         │
│ Secondary Color:  [Dropdown______________▼]         │
│ ☐ Multi-color deck (3+ colors)                      │
│                                                     │
│ ───────────────────────────────────────────────     │
│ Display Card                                        │
│                                                     │
│ ┌────────────┐   Search: [___________] [Search]     │
│ │            │                                      │
│ │  [Card     │   ┌──────┬──────┬──────┬──────┐     │
│ │  Preview]  │   │ card │ card │ card │ card │     │
│ │            │   └──────┴──────┴──────┴──────┘     │
│ └────────────┘   Selected: BT17-042                 │
│                                                     │
│ [Add Archetype]                          [Delete]   │
└─────────────────────────────────────────────────────┘
```

**Key changes:**
- Identity first (name, colors), then visual (card)
- Card preview prominently displayed on left
- Search and results grid to the right of preview
- Immediate visual feedback when selecting a card
- Delete button only appears in edit mode

---

### 3.2 Multi-Color Deck Support

**Feature:** Checkbox for decks that use 3+ colors.

**UI:**
```r
checkboxInput("deck_multi_color", "Multi-color deck (3+ colors)", value = FALSE)
```

**Database:** Add `is_multi_color BOOLEAN DEFAULT FALSE` to `deck_archetypes` table.

**Display:** Multi-color decks show a pink "Multi" badge in meta views and archetype lists (using existing pink color from the app's color palette).

---

### 3.3 Delete Archetype Functionality

**Feature:** Allow deletion of archetypes with no associated results.

**Behavior:** Same pattern as stores:
1. Check: `SELECT COUNT(*) FROM results WHERE archetype_id = ?`
2. If count > 0: Button disabled with tooltip "Cannot delete: used in X results"
3. If count = 0: Button enabled
4. On click: Modal confirmation "Delete [Archetype Name]? This cannot be undone."
5. On confirm: `DELETE FROM deck_archetypes WHERE archetype_id = ?`

---

## Section 4: Enter Results Enhancement

### 4.1 Wizard/Stepper Flow

**Replace current layout** with a two-step wizard. No scrolling between sections.

**Step 1: Tournament Details**

```
┌─────────────────────────────────────────────────────────────────┐
│ Enter Tournament Results                                        │
│                                                                 │
│   ● Step 1: Tournament Details    ○ Step 2: Add Results        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Store:            [Common Ground Games        ▼]              │
│   Date:             [January 25, 2026           📅]             │
│   Event Type:       [Locals                     ▼]              │
│   Format/Set:       [BT18                       ▼]              │
│   Number of Players: [8    ]                                    │
│   Number of Rounds:  [3    ]                                    │
│                                                                 │
│                                        [Create Tournament →]    │
└─────────────────────────────────────────────────────────────────┘
```

**Step 2: Add Results**

```
┌─────────────────────────────────────────────────────────────────┐
│ Enter Tournament Results                                        │
│                                                                 │
│   ○ Step 1: Tournament Details    ● Step 2: Add Results        │
├─────────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 📍 Common Ground Games | Jan 25, 2026 | Locals | 8 players  │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌───────────────────────────┐  ┌────────────────────────────┐  │
│ │                           │  │ Results Entered (3/8)      │  │
│ │ Player: [___________▼]    │  │                            │  │
│ │         [+ New Player]    │  │ ┌────┬────────┬──────┬───┐ │  │
│ │                           │  │ │ #  │ Player │ Deck │W-L│ │  │
│ │ Deck:   [___________▼]    │  │ ├────┼────────┼──────┼───┤ │  │
│ │         [+ New Deck]      │  │ │ 1  │ John   │Fenri │3-0│ │  │
│ │                           │  │ │ 2  │ Jane   │BlueFl│2-1│ │  │
│ │ Placement: [1  ]          │  │ │ 3  │ Bob    │Jesmon│2-1│ │  │
│ │ Record: [__]-[__]-[__]    │  │ └────┴────────┴──────┴───┘ │  │
│ │ Decklist URL: [________]  │  │                            │  │
│ │                           │  │                            │  │
│ │ [Add Result]              │  │                            │  │
│ └───────────────────────────┘  └────────────────────────────┘  │
│                                                                 │
│   [← Back to Details]                    [Mark Complete ✓]     │
└─────────────────────────────────────────────────────────────────┘
```

**Key features:**
- Progress indicator shows current step
- Tournament summary bar in Step 2
- Results count shows progress (3/8 players entered)
- Back button allows editing tournament details
- Bulk paste mode removed (may revisit later)

---

### 4.2 Quick Add Buttons

**[+ New Player]** and **[+ New Deck]** buttons use inline expandable forms:

```
┌───────────────────────────┐
│ Player: [___________▼]    │
│         [+ New Player]    │
│  ┌────────────────────┐   │
│  │ Name: [__________] │   │  ← Inline form expands
│  │ [Add] [Cancel]     │   │
│  └────────────────────┘   │
│                           │
│ Deck:   [___________▼]    │
│         [+ New Deck]      │
│  ┌────────────────────┐   │
│  │ Name:  [_________] │   │  ← Inline form expands
│  │ Color: [Purple  ▼] │   │
│  │ [Add] [Cancel]     │   │
│  │ (Details later in  │   │
│  │  Manage Decks)     │   │
│  └────────────────────┘   │
└───────────────────────────┘
```

After adding, the form collapses and the new item is auto-selected in the dropdown.

---

### 4.3 Duplicate Tournament Detection

**Trigger:** When user clicks "Create Tournament →", before creating.

**Check:**
```sql
SELECT tournament_id, player_count,
       (SELECT COUNT(*) FROM results WHERE tournament_id = t.tournament_id) as result_count
FROM tournaments t
WHERE store_id = ? AND event_date = ?
```

**If duplicate found, show modal:**

```
┌─────────────────────────────────────────────────────────────────┐
│ ⚠️  Possible Duplicate Tournament                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   A tournament at Common Ground Games on January 25, 2026       │
│   already exists:                                               │
│                                                                 │
│     • 8 players registered                                      │
│     • 6 results entered                                         │
│     • Event type: Locals                                        │
│                                                                 │
│   What would you like to do?                                    │
│                                                                 │
│   [View/Edit Existing]   [Create Anyway]   [Cancel]            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Options:**
- **View/Edit Existing** → Load existing tournament into Step 2
- **Create Anyway** → For multiple events same day (morning + evening)
- **Cancel** → Return to Step 1

---

## Section 5: Database Migrations

### 5.1 Schema Changes

**`db/schema.sql` updates:**

```sql
-- stores table: add after is_active line
is_online BOOLEAN DEFAULT FALSE,

-- deck_archetypes table: add after is_active line
is_multi_color BOOLEAN DEFAULT FALSE,
```

**`store_activity` view update:**

```sql
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

### 5.2 Migration Script

**Create `R/migrate_v0.5.0.R`:**

```r
#' Migrate database to v0.5.0
#' Adds: is_online to stores, is_multi_color to deck_archetypes
migrate_v0.5.0 <- function(con) {
  cat("Running migration v0.5.0...\n")

  # Add is_online to stores
  tryCatch({
    dbExecute(con, "ALTER TABLE stores ADD COLUMN is_online BOOLEAN DEFAULT FALSE")
    cat("  ✓ Added is_online column to stores\n")
  }, error = function(e) {
    if (grepl("already exists|duplicate", e$message, ignore.case = TRUE)) {
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
    if (grepl("already exists|duplicate", e$message, ignore.case = TRUE)) {
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

### 5.3 Seed Script Updates

**`R/seed_stores.R`:** Add `is_online = FALSE` to INSERT statements.

**`R/seed_archetypes.R`:** Add `is_multi_color = FALSE` to INSERT statements.

---

## Section 6: Implementation Summary

### 6.1 Files to Modify

| File | Changes |
|------|---------|
| `app.R` | Bug fixes, all server logic for new features |
| `views/admin-results-ui.R` | Wizard layout, quick-add buttons, remove bulk mode |
| `views/admin-decks-ui.R` | Form reorganization, multi-color checkbox, delete button |
| `views/admin-stores-ui.R` | Online store checkbox, conditional fields, delete button |
| `views/stores-ui.R` | Add "Online Tournament Organizers" section below map |
| `db/schema.sql` | Add new columns, update view |
| `R/migrate_v0.5.0.R` | New file - migration script |
| `R/seed_stores.R` | Add `is_online` column |
| `R/seed_archetypes.R` | Add `is_multi_color` column |
| `www/custom.css` | Wizard step styling (optional) |

### 6.2 Implementation Order

| Phase | Tasks | Risk | Estimate |
|-------|-------|------|----------|
| 1 | Bug fixes (bind parameter, button alignment) | Low | Quick |
| 2 | Database migration script + schema updates | Low | Quick |
| 3 | Manage Stores (online support, delete, modal) | Medium | Medium |
| 4 | Stores tab (online organizers section) | Low | Quick |
| 5 | Manage Decks (layout, multi-color, delete) | Medium | Medium |
| 6 | Enter Results (wizard refactor, duplicate detection, quick-add) | High | Longer |

### 6.3 Design Decisions Summary

| Decision | Choice |
|----------|--------|
| Online stores | Flag-based (`is_online`), separate section on Stores tab |
| Delete behavior | Hard delete, blocked if related records exist |
| Delete confirmation | Modal dialog |
| Multi-color display | Pink "Multi" badge |
| Quick add (deck/player) | Inline expandable form |
| Results entry | Wizard/stepper flow, 2 steps |
| Bulk paste mode | Removed for now (may revisit) |
| Duplicate detection | Modal with View/Edit, Create Anyway, Cancel options |

---

*Document Version: 1.0*
*Status: Approved*
*Author: Claude (AI Assistant)*
