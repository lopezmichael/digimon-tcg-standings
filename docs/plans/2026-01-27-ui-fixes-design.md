# UI Fixes and Improvements Design

**Date:** 2026-01-27
**Status:** Approved

## Overview

Collection of bug fixes and UI improvements across the application.

## Changes

### 1. Event Types & Format Dropdown

**Add Online Tournament event type:**
```r
EVENT_TYPES <- c(
  "Locals" = "locals",
  "Online Tournament" = "online",  # NEW
  "Evolution Cup" = "evo_cup",
  "Store Championship" = "store_championship",
  "Regionals" = "regionals",
  "Regulation Battle" = "regulation_battle",
  "Release Event" = "release_event",
  "Other" = "other"
)
```

**Remove hardcoded FORMAT_CHOICES:**
- Delete the hardcoded constant (lines 163-173)
- Always load from database via `get_format_choices()`
- Return empty with error if DB unavailable

### 2. Reset Buttons Standardization

All reset buttons across tabs:
- Label: "Reset" (not "Reset Filters")
- Height: 38px (matches inputs)
- Alignment: margin-top: 1.5rem
- Class: btn-outline-secondary (no btn-sm)

**Files:**
- views/dashboard-ui.R
- views/players-ui.R
- views/meta-ui.R
- views/tournaments-ui.R

### 3. Results Entry Improvements

**Wins/Losses/Ties inputs:**
- Smaller column widths: c(3, 3, 3)
- Max-width: 100px per input
- Shorter labels: W, L, T

**Delete player from pending results:**
- Small X button next to each row
- Only visible before "Mark Complete"
- Removes result from database

### 4. Card Search & Manage Formats

**Card search button:**
- Replace "Search" text with magnifying glass icon
- bsicons::bs_icon("search")

**Manage Formats simplification:**
- Remove display_name input (auto-generate as "{format_id} ({set_name})")
- Remove sort_order input (auto-calculate from release_date)
- Keep active toggle
- Order dropdowns by release_date DESC

## Files to Modify

| File | Changes |
|------|---------|
| app.R | EVENT_TYPES, remove FORMAT_CHOICES, format queries, delete result handler |
| views/dashboard-ui.R | Reset button styling |
| views/players-ui.R | Reset button styling |
| views/meta-ui.R | Reset button styling |
| views/tournaments-ui.R | Reset button styling |
| views/admin-results-ui.R | W/L/T layout, delete buttons |
| views/admin-decks-ui.R | Search button icon |
| views/admin-formats-ui.R | Remove display_name, sort_order fields |

## Implementation Order

1. EVENT_TYPES update (simple constant change)
2. Remove FORMAT_CHOICES, update format loading
3. Reset buttons standardization (4 files)
4. W/L/T input layout
5. Delete result button + handler
6. Card search icon
7. Manage Formats simplification
