# UI Refactor and Polish Design

**Date:** 2026-01-28
**Branch:** `ui-refactor-and-polish`
**Status:** Approved

## Overview

This document outlines the plan to refactor `app.R` into domain-based server files and improve the UI for both desktop and mobile platforms.

## Execution Order

1. Bug fixes (benefits both platforms)
2. Desktop UI improvements
3. Mobile UI improvements

---

## 1. Code Refactor: app.R Split

### Goal
Split the monolithic `app.R` (~2000+ lines) into domain-based sourced files for easier maintenance and debugging.

### File Structure

```
server/
├── dashboard-server.R      # Overview page reactives & observers
├── stores-server.R         # Store map, store management
├── players-server.R        # Player standings, player profiles
├── meta-server.R           # Deck meta analysis, deck profiles
├── tournaments-server.R    # Tournament history, tournament details
├── results-server.R        # Enter results wizard (both steps)
├── admin-decks-server.R    # Manage deck archetypes
├── admin-stores-server.R   # Manage stores
├── admin-formats-server.R  # Manage formats
└── shared-server.R         # Shared reactives (filtered data, notifications)
```

### How It Works
- Each file defines its observers, reactives, and render functions
- Files are `source()`'d at the top of the `server` function in app.R
- Shared state (like `filtered_results()`, notification helpers) lives in `shared-server.R`
- app.R becomes a thin wrapper: UI definition + sourcing server files

### Migration Approach
- Move code function-by-function, testing after each move
- Keep app.R working at every step (no big-bang rewrite)

---

## 2. Bug Fixes

### Bug 1: `&times;` Delete Button

**Problem:** Delete button in Results Entered table shows raw HTML entity text instead of × symbol.

**Fix:** Find the delete button code and ensure proper HTML rendering:
- Add `html = TRUE` to reactable column, OR
- Use `shiny::icon("times")` instead of raw text

### Bug 2: Notification Styling

**Problem:** Plain toast notifications in bottom-right corner.

**Improvements:**
- Add subtle background color based on type (green for success, red for error)
- Add an icon (checkmark for success, warning for errors)
- Position: bottom-right for desktop, bottom-center for mobile
- Slightly larger text, rounded corners, subtle shadow

---

## 3. Desktop UI Improvements

### 3a. Overview Page Value Boxes

**Problem:** Plain boxes, "Most Popular Deck" text truncated.

**Solution:**
- Add representative card image as subtle background (low opacity, right-aligned)
- Ensure text never truncates - smaller font or allow wrapping for long deck names
- Match visual richness of Top Decks section below

### 3b. Filter Section Layouts (Players, Meta, Tournaments)

**Problem:** Two rows, Reset button awkwardly placed.

**Solution:** Single-row layout:
```
[Search input (wider)] [Format dropdown] [Min Events dropdown] [Reset button]
```
- All controls on one line
- Reset button right-aligned
- Consistent pattern across all three pages

### 3c. Enter Tournament Details Page

**Problem:** Full-width inputs feel wasteful.

**Solution:**
- Constrain form to ~600px max-width, left-aligned
- Group related fields (Store + Date on one row, Event Type + Format on another)

### 3d. Add Results Page (Step 2)

**Problem:** Left form takes vertical space; W/L/T stacked; Results table small.

**Solution:**
- Two-column layout: Left (40%) form, Right (60%) results table
- W/L/T inputs inline (three small inputs in a row)
- Placement field: smaller width
- Form becomes compact, table gets prominence

### 3e. Duplicate Tournament Modal

**Problem:** Buttons on two rows, misaligned.

**Solution:**
- All buttons on one row: `[View/Edit Existing] [Create Anyway] [Cancel]`
- Or stack vertically, all same width and aligned
- Primary action gets filled style, secondary actions get outline style

### 3f. Manage Decks - Display Card Section

**Problem:** Horizontal scroll, Card ID input too wide.

**Solution:**
- Card ID input: max-width ~120px
- Display Card preview: constrain within container, add max-height
- Remove horizontal scroll

### 3g. Sidebar Navigation Header

**Problem:** "Navigation" text takes up unnecessary space.

**Solution:**
- Replace with small "Menu" text or subtle icon
- Position closer to collapse arrow
- Saves vertical space

---

## 4. Mobile UI Improvements

### 4a. Navigation Menu

**Problem:** Extends full screen height for 5 items.

**Solution:**
- Menu only as tall as its content
- Subtle separation between nav sections
- Auto-collapse on item tap

### 4b. Overview Page Value Boxes

**Problem:** Stacked vertically, no card images, clunky.

**Solution:**
- 2x2 grid layout instead of 4 stacked
- Keep card backgrounds at lower opacity
- Smaller text, prioritize numbers
- Truncate long names with ellipsis

### 4c. Filter Sections (Players, Meta, Tournaments)

**Problem:** Horizontal layout causes scroll.

**Solution:**
- Stack all filters vertically at mobile breakpoints
- Full-width inputs
- Reset button full-width at bottom or small icon
- Search first, then dropdowns

### 4d. Data Tables

**Problem:** Columns cut off.

**Solution:**
- Prioritize important columns, hide others on mobile
- Player Standings: Player, Events, W, Win% (hide L, T, 1st, Top 3)
- Add horizontal scroll hint (subtle fade) or collapsible rows

### 4e. Sidebar Header (Mobile)

Same as desktop - minimal "Menu" text, positioned near collapse arrow.

---

## 5. Mobile Admin Pages (Priority)

Entering results at events is a key mobile use case.

### 5a. Enter Tournament Details

- Center the "Create Tournament" button
- Slightly smaller vertical spacing to reduce scrolling

### 5b. Add Results Page

- Tournament info card: Single line format "Store · Date · Type · Players"
- W/L/T inputs inline (three in a row)
- Results table: Player and Deck columns only, Place as badge
- "Add Result" button sticky at bottom

### 5c. Manage Pages (Decks, Stores, Formats)

- Decks: Show Deck, Color (hide Card ID)
- Stores: Show Store, City (hide State)
- Formats: Already looks fine

---

## Future Considerations

- Add Digimon TCG logo to main navbar header (replacing current controller icon)
- This is separate from current work but noted for future enhancement

---

## Implementation Checklist

- [ ] Refactor app.R into server/ files
- [ ] Fix &times; delete button bug
- [ ] Improve notification styling
- [ ] Desktop: Overview value boxes with card backgrounds
- [ ] Desktop: Filter section single-row layouts
- [ ] Desktop: Enter Tournament Details constrained width
- [ ] Desktop: Add Results page two-column + inline W/L/T
- [ ] Desktop: Duplicate Tournament modal buttons
- [ ] Desktop: Manage Decks Card ID input width
- [ ] Desktop/Mobile: Sidebar "Menu" header
- [ ] Mobile: Navigation menu height
- [ ] Mobile: Overview 2x2 value box grid
- [ ] Mobile: Filter sections vertical stacking
- [ ] Mobile: Table column prioritization
- [ ] Mobile: Enter Tournament center button
- [ ] Mobile: Add Results compact layout
- [ ] Mobile: Manage pages table columns
