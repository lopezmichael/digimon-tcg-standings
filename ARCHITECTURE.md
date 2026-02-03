# DigiLab Architecture

Technical reference for the DigiLab codebase. Consult this document before adding new server modules, reactive values, or modifying core patterns.

**Last Updated:** February 2026 (v0.18.1)

> **Note:** Always keep this document in sync with code changes. Update when adding new reactive values, server modules, or patterns.

---

## Table of Contents

1. [Server Module Structure](#server-module-structure)
2. [Reactive Values Reference](#reactive-values-reference)
3. [Navigation Patterns](#navigation-patterns)
4. [Modal Patterns](#modal-patterns)
5. [Database Patterns](#database-patterns)

---

## Server Module Structure

### Overview

The application uses a modular server architecture. All server logic is extracted from `app.R` into separate files in `server/`.

```
server/
├── shared-server.R            # Database, navigation, auth helpers
├── public-dashboard-server.R  # Dashboard/Overview tab (889 lines)
├── public-stores-server.R     # Stores tab with map (851 lines)
├── public-players-server.R    # Players tab (364 lines)
├── public-meta-server.R       # Meta analysis tab (305 lines)
├── public-tournaments-server.R # Tournaments tab (237 lines)
├── admin-results-server.R     # Tournament entry wizard
├── admin-tournaments-server.R # Tournament management
├── admin-decks-server.R       # Deck archetype CRUD
├── admin-stores-server.R      # Store management
├── admin-players-server.R     # Player management
└── admin-formats-server.R     # Format management
```

### Naming Convention

| Prefix | Purpose | Example |
|--------|---------|---------|
| `public-*` | Public-facing tabs (no auth required) | `public-players-server.R` |
| `admin-*` | Admin tabs (requires `rv$is_admin`) | `admin-decks-server.R` |
| `shared-*` | Shared utilities used by multiple modules | `shared-server.R` |

### Adding a New Server Module

1. Create file: `server/{prefix}-{name}-server.R`
2. Add `source()` call in `app.R` (after reactive values, before UI render)
3. Module has access to `input`, `output`, `session`, `rv` via `local = TRUE`

```r
# In app.R
source("server/public-newfeature-server.R", local = TRUE)
```

### What Goes Where

| Content | Location |
|---------|----------|
| Reactive values initialization | `app.R` |
| Database connection setup | `server/shared-server.R` |
| Navigation observers | `server/shared-server.R` |
| Auth logic | `server/shared-server.R` |
| Tab-specific outputs/observers | `server/{prefix}-{tab}-server.R` |
| Helper functions (pure) | `R/*.R` |
| UI definitions | `views/*-ui.R` |

---

## Reactive Values Reference

All reactive values are initialized in `app.R`. **Never create new reactive values ad-hoc in server files** - always add them to the initialization block.

### Core

| Name | Type | Description |
|------|------|-------------|
| `db_con` | connection | DuckDB database connection |
| `is_admin` | logical | Whether user is authenticated as admin |

### Navigation

| Name | Type | Description |
|------|------|-------------|
| `current_nav` | character | Current active tab ID |
| `navigate_to_tournament_id` | integer | Tournament ID for cross-tab navigation |

### Modal State

Pattern: `selected_{entity}_id` for single selection, `selected_{entity}_ids` for multiple.

| Name | Type | Description |
|------|------|-------------|
| `selected_store_id` | integer | Store ID for detail modal |
| `selected_online_store_id` | integer | Online store ID for detail modal |
| `selected_player_id` | integer | Player ID for profile modal |
| `selected_archetype_id` | integer | Archetype ID for deck modal |
| `selected_tournament_id` | integer | Tournament ID for detail modal |
| `selected_store_ids` | integer[] | Store IDs from map region filter |

### Form/Wizard State

| Name | Type | Description |
|------|------|-------------|
| `wizard_step` | integer | Current step in result entry wizard (1=Details, 2=Results) |
| `active_tournament_id` | integer | Tournament being edited in wizard |
| `current_results` | data.frame | Results being entered in wizard |
| `duplicate_tournament` | data.frame | Tournament info for duplicate flow |
| `modal_tournament_id` | integer | Tournament ID for results edit modal |
| `editing_store` | list | Store being edited (edit mode) |
| `editing_archetype` | list | Archetype being edited (edit mode) |
| `card_search_results` | data.frame | Card search results for deck management |
| `card_search_page` | integer | Current page in card search pagination |

### Refresh Triggers

Pattern: `{scope}_refresh` - increment to trigger reactive invalidation.

| Name | Type | Description |
|------|------|-------------|
| `data_refresh` | integer | Global refresh for all public tables |
| `results_refresh` | integer | Refresh results table in wizard |
| `format_refresh` | integer | Refresh format dropdowns |
| `tournament_refresh` | integer | Refresh tournament tables |
| `modal_results_refresh` | integer | Refresh results in edit modal |

**Usage:**
```r
# Trigger refresh
rv$data_refresh <- (rv$data_refresh %||% 0) + 1

# React to refresh
observe({
  rv$data_refresh  # Dependency
  # ... refresh logic
})
```

### Delete Permission State

Pattern: `can_delete_{entity}` (logical) + `{entity}_{related}_count` (integer).

| Name | Type | Description |
|------|------|-------------|
| `can_delete_store` | logical | Whether store can be deleted |
| `can_delete_format` | logical | Whether format can be deleted |
| `can_delete_player` | logical | Whether player can be deleted |
| `can_delete_archetype` | logical | Whether archetype can be deleted |
| `store_tournament_count` | integer | Tournaments referencing store |
| `format_tournament_count` | integer | Tournaments using format |
| `player_result_count` | integer | Results for player |
| `archetype_result_count` | integer | Results using archetype |

### Adding New Reactive Values

1. **Choose the right category** from the list above
2. **Follow naming conventions:**
   - Modal state: `selected_{entity}_id`
   - Refresh triggers: `{scope}_refresh`
   - Delete permission: `can_delete_{entity}` + `{entity}_{related}_count`
3. **Add to `app.R`** in the appropriate section with a comment
4. **Update this document** with the new value

---

## Navigation Patterns

### Tab Navigation (Correct Pattern)

Always use all three steps to ensure sidebar stays in sync:

```r
# 1. Switch the tab content
nav_select("main_content", "target_tab")

# 2. Update reactive state
rv$current_nav <- "target_tab"

# 3. Sync sidebar highlight
session$sendCustomMessage("updateSidebarNav", "nav_target_tab")
```

### Tab IDs

| Tab | Content ID | Sidebar Nav ID |
|-----|------------|----------------|
| Dashboard | `dashboard` | `nav_dashboard` |
| Stores | `stores` | `nav_stores` |
| Players | `players` | `nav_players` |
| Meta | `meta` | `nav_meta` |
| Tournaments | `tournaments` | `nav_tournaments` |
| Admin: Add Results | `admin_results` | `nav_admin_results` |
| Admin: Tournaments | `admin_tournaments` | `nav_admin_tournaments` |
| Admin: Decks | `admin_decks` | `nav_admin_decks` |
| Admin: Stores | `admin_stores` | `nav_admin_stores` |
| Admin: Formats | `admin_formats` | `nav_admin_formats` |
| Admin: Players | `admin_players` | `nav_admin_players` |

---

## Modal Patterns

### Bootstrap Modals (Defined in UI)

```r
# Show modal
shinyjs::runjs("$('#modal_id').modal('show');")

# Hide modal
shinyjs::runjs("$('#modal_id').modal('hide');")
```

### Dynamic Shiny Modals

```r
# Show modal
showModal(modalDialog(
  title = "Modal Title",
  # ... content
  footer = tagList(
    modalButton("Cancel"),
    actionButton("confirm_btn", "Confirm")
  )
))

# Hide modal
removeModal()
```

### Modal Data Flow

1. User clicks row → handler sets `rv$selected_{entity}_id`
2. Observer watches `rv$selected_{entity}_id` → fetches data → shows modal
3. Modal actions use the ID from `rv$selected_{entity}_id`
4. On close, optionally clear `rv$selected_{entity}_id`

---

## Database Patterns

### Connection Handling

Connection is established in `shared-server.R` and stored in `rv$db_con`:

```r
# Check connection before use
req(rv$db_con)
if (!dbIsValid(rv$db_con)) return(NULL)

# Use connection
data <- dbGetQuery(rv$db_con, "SELECT * FROM table")
```

### Refresh Pattern

When admin makes changes, trigger refresh so public views update:

```r
# After INSERT/UPDATE/DELETE
rv$data_refresh <- (rv$data_refresh %||% 0) + 1

# In public view reactive
reactive({
  rv$data_refresh  # React to changes
  req(rv$db_con)
  dbGetQuery(rv$db_con, "...")
})
```

### Parameterized Queries

Always use parameterized queries to prevent SQL injection:

```r
# Correct
dbGetQuery(rv$db_con, "SELECT * FROM players WHERE player_id = ?",
           params = list(player_id))

# Also correct (named)
dbGetQuery(rv$db_con, "SELECT * FROM players WHERE player_id = $1",
           params = list(player_id))

# WRONG - SQL injection risk
dbGetQuery(rv$db_con, paste0("SELECT * FROM players WHERE player_id = ", player_id))
```

---

## Quick Reference

### File Locations

| What | Where |
|------|-------|
| Main app entry | `app.R` |
| Server modules | `server/*.R` |
| UI views | `views/*.R` |
| Helper functions | `R/*.R` |
| Database schema | `db/schema.sql` |
| Custom CSS | `www/custom.css` |
| Brand config | `_brand.yml` |

### Common Patterns Cheatsheet

```r
# Navigation
nav_select("main_content", "tab_id")
rv$current_nav <- "tab_id"
session$sendCustomMessage("updateSidebarNav", "nav_tab_id")

# Trigger refresh
rv$data_refresh <- (rv$data_refresh %||% 0) + 1

# Show Bootstrap modal
shinyjs::runjs("$('#modal_id').modal('show');")

# Check admin
req(rv$is_admin)

# Check DB connection
req(rv$db_con)
if (!dbIsValid(rv$db_con)) return(NULL)
```
