# Upload Results: Row Management & Row Count Fix

**Date:** 2026-02-19
**Status:** Approved

## Problem

1. **Row count exceeds total_players**: OCR can produce more rows than the user-entered player count. The current truncation logic filters by `combined$placement <= total_players`, which fails when duplicate placements exist (e.g., 18 rows all with placements 1-17 pass the filter).

2. **Extra blank rows from OCR noise**: OCR sometimes reads non-player text (headers, store names) as usernames, creating spurious rows. The fill-missing-placements logic then adds even more blank rows.

3. **No way to delete rows**: The step 2 review table has no delete functionality. Users can't remove blank/incorrect rows and have standings auto-adjust.

## Design

### Fix: Enforce row count = total_players

Replace the current truncation logic (`combined$placement <= total_players`) with `combined[1:total_players, ]` after sorting. This guarantees exactly `total_players` rows regardless of placement values.

### Feature: Delete row with auto-renumber

- Add X button to the left of each placement badge in the review table
- On delete: sync all current input values back to `rv$submit_ocr_results`, remove the row, renumber placements 1-N, append blank row at bottom to maintain `total_players` count
- Uses `Shiny.setInputValue('submit_delete_row', i, {priority: 'event'})` pattern
- Column widths change from `c(1, 4, 2, 2, 3)` to `c(1, 1, 3, 2, 2, 3)`

### Input sync before re-render

Helper function reads all current text input values (player names, member numbers, points, deck selections) back into `rv$submit_ocr_results` before any operation that triggers a re-render.

## Files Changed

- `server/public-submit-server.R` — Fix truncation logic, add delete handler, add input sync helper
- (Table render in same file) — Add delete button column to layout

## User Decisions

- Auto-renumber placements on delete (no manual placement editing)
- Total player count stays fixed to user's entered value
- Delete button: X icon on left side of each row
