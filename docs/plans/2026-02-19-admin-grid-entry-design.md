# Admin Grid Entry for Enter Results

**Date:** 2026-02-19
**Status:** Approved

## Problem

The current admin Enter Results tab requires adding players one at a time: select player from dropdown, select deck, enter W-L-T, click "Add Result", repeat. For a 16+ player tournament this takes 16+ cycles and is the biggest admin pain point. Additionally, non-Bandai sources sometimes provide total points instead of W-L-T records, requiring mental conversion.

## Solution

Replace the one-at-a-time entry form with a full-width editable grid. N blank rows (based on player count) appear after tournament creation. Admins type directly into the grid, see inline player match feedback, and submit all results at once. A paste-from-spreadsheet option fills the grid from tab-separated data.

## Design

### Step 1: Tournament Details (minimal changes)

Same form as today with one addition: **Record Format** toggle (Points or W-L-T) below the player count / rounds fields.

- **Record Format: Points** (default) — grid shows a single Pts column. W-L-T auto-calculated on submit: `wins = pts / 3`, `ties = pts % 3`, `losses = rounds - wins - ties`.
- **Record Format: W-L-T** — grid shows three W/L/T columns. Points not shown.

The toggle is stored in a reactive value and passed to Step 2.

### Step 2: Results Grid

Full-width card replacing the current left-form + right-table layout.

**Top bar:**
- Tournament summary bar (same component as today)
- "Paste from Spreadsheet" button (top-right)
- Record format badge (e.g., "Points mode")

#### Grid Layout (Points mode)

```
col_widths = c(1, 1, 4, 2, 4)

[X] | #   | Player Name          | Pts | Deck
[x] | 1st | [________________]   | [0] | [dropdown]
      [✔ Matched #0001234]
[x] | 2nd | [________________]   | [0] | [dropdown]
      [+ New player]
```

#### Grid Layout (W-L-T mode)

```
col_widths = c(1, 1, 3, 1, 1, 1, 4)

[X] | #   | Player Name          | W   | L   | T   | Deck
[x] | 1st | [________________]   | [0] | [0] | [0] | [dropdown]
      [✔ Matched #0001234]
```

#### Row Behaviors

- **Placement**: Read-only, auto-assigned ordinal (1st, 2nd, ...). Uses same `ordinal()` helper and placement badge styling as Upload Results.
- **Player Name**: Plain `textInput`. On blur (tab out), triggers server-side player lookup. Shows inline match badge below the input:
  - Green `✔ Matched #0001234` — exact name match with member number
  - Green `✔ Matched (no member #)` — exact name match without member number
  - Blue `? Possible: "DisplayName"` — case-insensitive match with different casing
  - Gray `+ New player` — no match found, will be created on submit
- **Points/W-L-T**: Numeric inputs. In points mode, single column. In W-L-T mode, three columns.
- **Deck**: `selectInput` (native, not selectize) with choices: Unknown (default), "+ Request new deck...", pending requests, existing decks. Hidden column for release events with info notice.
- **Delete (X)**: Same pattern as Upload Results review table — removes row, appends blank at bottom, renumbers placements.
- **Tab order**: Player Name → Pts (or W → L → T) → Deck → next row's Player Name.

#### Bottom Bar

- "Back to Details" button (left)
- "Submit Results" button (right)
- Filled count indicator: "Filled: 12/17" (counts rows with non-empty player name)

### Paste from Spreadsheet

Button opens a Shiny modal with a large textarea.

**Supported formats (auto-detected):**
1. Player names only (one per line)
2. Player name `[tab]` Points
3. Player name `[tab]` W `[tab]` L `[tab]` T

**Parse logic:**
- Split input by newlines
- For each line, split by tab (or 2+ spaces as fallback)
- First column = player name (required)
- If 1 additional column → treat as points
- If 3 additional columns → treat as W, L, T
- Skip blank lines

**Fill behavior:**
- Fills grid rows in order starting from first empty row
- If grid already has data, shows confirmation: "Replace existing data?"
- After fill, triggers player match lookup for all filled rows
- Notification: "Filled 12 rows from pasted data"

### Player Matching

**On blur (tab out of player name field):**

```r
observeEvent(input$admin_player_N, {
  name <- trimws(input$admin_player_N)
  if (nchar(name) == 0) { clear badge; return() }

  # Exact match (case-insensitive)
  player <- dbGetQuery(con, "
    SELECT player_id, display_name, member_number
    FROM players WHERE LOWER(display_name) = LOWER(?)
    LIMIT 1
  ", params = list(name))

  if (nrow(player) > 0) {
    # Show green badge with member number status
    badge = "matched", member_number = player$member_number
  } else {
    # Show gray "New player" badge
    badge = "new"
  }
})
```

No fuzzy matching for simplicity. Admin types the exact name to link to an existing player, or any name to create a new one.

**On submit:** Only exact matches (case-insensitive) link to existing players. All others auto-create.

### Submit Flow

1. Validate: at least 1 row has a non-empty player name
2. For each row with a player name:
   a. Exact match `LOWER(display_name) = LOWER(name)` → use existing player_id
   b. No match → create new player (auto-generate ID)
   c. Convert record: if points mode, calculate W-L-T from points. If W-L-T mode, use directly.
   d. Get deck: regular ID, pending request ID → UNKNOWN + pending_deck_request_id, or blank → UNKNOWN
   e. Insert result row
3. Recalculate ratings cache
4. Trigger data refresh
5. Show success notification: "Tournament submitted! 17 results recorded."
6. Reset to Step 1

### Deck Request Modal

Same modal as Upload Results tab — triggered when admin selects "+ Request new deck..." from any row's deck dropdown. Asks for deck name, primary color, secondary color (optional), card ID (optional). Inserts to `deck_requests` table. Updates all deck dropdowns with new pending entry.

### Release Events

Same behavior as today: when event type is "release_event", hide the deck column and show info notice. UNKNOWN archetype auto-assigned on submit.

### Existing Results (Edit/Delete)

Out of scope for this design. Admins use the existing "Edit Tournaments" tab to modify or delete results after submission. The grid is purely for initial entry.

## Reactive Values

New or modified reactive values:
- `rv$admin_grid_data` — data frame of grid rows (replaces `rv$current_results` for entry)
- `rv$admin_record_format` — "points" or "wlt"
- `rv$admin_player_matches` — list of match results per row (badge display)

## Files Changed

- `server/admin-results-server.R` — Major rewrite of Step 2 logic
- `views/admin-results-ui.R` — Replace left-form + right-table with grid layout
- `www/custom.css` — Add grid-specific styles (reuse `.upload-result-row` patterns where possible)

## What's NOT Included

- No changes to Upload Results (public) tab
- No mobile-specific overhaul (grid uses same responsive patterns as Upload Results)
- No edit/delete of already-submitted results in the grid
- No member number input column (comes from player matching)
- No fuzzy matching (exact name match only for simplicity)

## User Decisions

- Grid replaces one-at-a-time entry entirely (no toggle to old flow)
- Record format toggle at tournament level (Points or W-L-T)
- Inline badge after typing for player matching (not autocomplete dropdown)
- Auto-create new players on submit (no pre-confirmation)
- Paste from spreadsheet as supplementary input method
