# Tournament Deletion Design

## Overview

Add the ability to delete accidentally created tournaments from the "Enter Tournament Results" admin page by enhancing the existing "Start Over" button.

## Use Case

User is partway through entering results and realizes they created the tournament with wrong details (wrong store, date, etc.). They want to delete the entire tournament and start fresh, not just clear the results.

## User Flow

1. User clicks "Start Over" button on Step 2 (Add Results)
2. Modal appears with two options:
   - **Clear Results**: Remove entered results but keep tournament for re-entry (stays on Step 2)
   - **Delete Tournament**: Permanently delete tournament and all results (returns to Step 1)
3. User selects an option or cancels

## Modal Design

```
┌─────────────────────────────────────┐
│ Start Over?                      X  │
├─────────────────────────────────────┤
│                                     │
│ What would you like to do?          │
│                                     │
│ [Clear Results]                     │
│  Remove entered results but keep    │
│  the tournament for re-entry.       │
│                                     │
│ [Delete Tournament]                 │
│  Permanently delete this tournament │
│  and all N results.                 │
│                                     │
│                          [Cancel]   │
└─────────────────────────────────────┘
```

- "Delete Tournament" styled as `btn-danger` (red)
- "Clear Results" styled as `btn-warning` (yellow/orange)
- Delete button shows dynamic result count for clarity
- Modal itself serves as confirmation (no second confirmation)

## Implementation

### UI Changes (`views/admin-results-ui.R`)

Add `start_over_modal` with:
- Dynamic message showing result count via `uiOutput`
- Three buttons: `clear_results_only`, `delete_tournament_confirm`, Cancel

### Handler Changes (`app.R`)

1. **Modify `clear_tournament` click**: Show modal instead of clearing directly

2. **Add `clear_results_only` handler**:
   - Delete results from DB: `DELETE FROM results WHERE tournament_id = ?`
   - Clear `rv$current_results`
   - Stay on Step 2
   - Show notification

3. **Add `delete_tournament_confirm` handler**:
   - Delete results: `DELETE FROM results WHERE tournament_id = ?`
   - Delete tournament: `DELETE FROM tournaments WHERE tournament_id = ?`
   - Clear `rv$active_tournament_id` and `rv$current_results`
   - Reset wizard to Step 1 with fresh form
   - Show notification

### Database

No schema changes. Delete in correct order (results first, then tournament).
