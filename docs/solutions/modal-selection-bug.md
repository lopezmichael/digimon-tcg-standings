# Modal Selection Bug - Root Cause Analysis

**Date:** 2026-02-02
**Status:** Documented, fix planned for v0.15
**Affected:** Stores tab, Players tab, Meta tab (deck archetypes)

## The Bug

Clicking on rows in the deck archetypes, stores, or players tables does not always open the correct modal. The bug occurs after sorting the table by clicking a column header.

## Root Cause

The selection handlers use the **visual row index** to look up the record ID, but they re-run the database query with a hardcoded `ORDER BY` clause. When the user sorts the table by clicking a column header, the visual order no longer matches the query order.

### Example Scenario

1. Table loads with default sort: Row 1 = "Blue Flare" (ID 5), Row 2 = "Red Hybrid" (ID 3)
2. User clicks "Win %" column header to re-sort
3. Table now shows: Row 1 = "Red Hybrid" (ID 3), Row 2 = "Blue Flare" (ID 5)
4. User clicks Row 1 (expecting Red Hybrid modal)
5. Handler code re-runs query with original `ORDER BY` clause → returns IDs in order [5, 3]
6. Code uses `result$id[selected_row]` where `selected_row = 1` → gets ID 5
7. **Wrong modal opens** (Blue Flare instead of Red Hybrid)

### Code Pattern (Current - Broken)

```r
# In app.R around line 2503
observeEvent(getReactableState("archetype_stats", "selected"), {
  selected_row <- getReactableState("archetype_stats", "selected")

  # Re-runs query with hardcoded ORDER BY
  result <- dbGetQuery(rv$db_con, sprintf("
    SELECT da.archetype_id
    FROM deck_archetypes da
    ...
    ORDER BY COUNT(r.result_id) DESC  # <-- This order may not match visual order!
  ", ...))

  # Uses row index to look up ID - WRONG if user sorted differently
  rv$selected_archetype_id <- result$archetype_id[selected_row]
})
```

## The Fix

Use JavaScript `onClick` callback to send the actual row data (including ID) directly, rather than relying on row index.

### Fixed Pattern

```r
# In the reactable() call
reactable(
  result,
  onClick = JS("function(rowInfo, column) {
    if (rowInfo) {
      Shiny.setInputValue('archetype_clicked', rowInfo.row.archetype_id, {priority: 'event'})
    }
  }"),
  # Remove: selection = "single",
  # Remove: onClick = "select",
  ...
)

# In the observer
observeEvent(input$archetype_clicked, {
  rv$selected_archetype_id <- input$archetype_clicked
})
```

This approach:
- Sends the actual ID from the clicked row's data
- Works regardless of current sort order
- Eliminates the need to re-run the query

## Affected Locations

| Table | File | Render Line | Handler Line |
|-------|------|-------------|--------------|
| `archetype_stats` | app.R | ~2446 | ~2503 |
| `player_standings` | app.R | ~2165 | ~2236 |
| `store_list` | app.R | ~1380 | ~1435 |

## Estimated Effort

~30 minutes to fix all three tables. Same pattern change for each.

## Related

- Reported in user feedback Google Sheet
- Scheduled for v0.15
