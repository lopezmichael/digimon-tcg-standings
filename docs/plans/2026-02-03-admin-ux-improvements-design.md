# Admin UX Improvements Design

**Date:** 2026-02-03
**Status:** Draft
**Author:** Claude (with Michael)

## Overview

This document addresses pain points reported by admin users when editing tournament and player data. The main issues are:

1. **Editing results is not intuitive** - To fix a player's result, admins must go through the Enter Results wizard, trigger a duplicate warning, then edit. The natural place (Edit Tournaments) has no access to results.
2. **Date field defaults to today** - Admins overlook this and submit wrong dates.

## Problem Statement

### Current Flow to Edit a Player Result

1. Go to "Enter Results" tab
2. Fill in tournament details (store, date, type, format, players, rounds)
3. Click "Create Tournament"
4. Get duplicate warning modal
5. Click "View/Edit Existing"
6. Only then can you see and click individual results to edit

This is unintuitive. Admins naturally go to "Edit Tournaments" to fix data, but that page only shows tournament metadata - no access to player results.

### Date Entry Errors

The date field defaults to `Sys.Date()` (today). When entering results for past tournaments, admins often overlook this field, resulting in incorrect dates that need retroactive fixing.

---

## Design: Edit Results from Edit Tournaments

### Proposed Change

Add a **"View/Edit Results" button** to the Edit Tournaments page that opens a modal showing all results for the selected tournament.

### User Flow

1. Admin goes to Edit Tournaments
2. Clicks a tournament row → left panel shows tournament metadata (existing behavior)
3. Below the metadata form, a new **"View/Edit Results"** button appears (only when a tournament is selected)
4. Clicking it opens a modal with:
   - Tournament summary header (store, date, format, player count)
   - Results table showing all players with placement, deck, record
   - Click any row → edit form appears (same pattern as current Enter Results edit modal)
   - Ability to **add** a new result (for missed entries)
   - Ability to **delete** a result (for duplicates/mistakes)

### Modal Layout

```
+-------------------------------------------------------------+
|  Tournament Results                                    [X]  |
|  Common Ground Games - Feb 1, 2026 - BT-19 - 13 players     |
+-------------------------------------------------------------+
|                                                             |
|  [+ Add Result]                                             |
|                                                             |
|  +-----------------------------------------------------+   |
|  | #  | Player       | Deck          | Record | Actions|   |
|  +----+--------------+---------------+--------+--------+   |
|  | 1  | Lance        | Imperialdramon| 4-0-0  |  E  D  |   |
|  | 2  | Happycat     | MagnaGarurumon| 3-1-0  |  E  D  |   |
|  | 3  | Palestreem   | Mastemon      | 3-1-0  |  E  D  |   |
|  | ...| ...          | ...           | ...    |  ...   |   |
|  +-----------------------------------------------------+   |
|                                                             |
|                                            [Done]           |
+-------------------------------------------------------------+

E = Edit icon, D = Delete icon
```

### Modal Interactions

| Action | Behavior |
|--------|----------|
| **Click Edit icon** | Opens edit form (same as current Enter Results edit modal) |
| **Click Delete icon** | Confirmation prompt → removes result |
| **Click "+ Add Result"** | Opens add form (player, deck, placement, record, decklist URL) |
| **Click "Done"** | Closes modal, refreshes tournament list |

### Edit Form Fields

Same as current Enter Results edit modal:
- Player (dropdown)
- Deck (dropdown)
- Placement (number)
- Wins / Losses / Ties (three inputs)
- Decklist URL (optional)
- [Save Changes] [Cancel]

### Change to Duplicate Tournament Flow

**Current behavior:**
- "View/Edit Existing" button stays in Enter Results and loads the tournament

**New behavior:**
- "View/Edit Existing" button **navigates to Edit Tournaments** with that tournament pre-selected
- Admin can then edit metadata OR click "View/Edit Results" for player data

**Rationale:** Centralizes all editing in Edit Tournaments. Enter Results stays focused on creating new tournaments.

### Where Editing Lives (Summary)

| Page | Purpose | Edit Results? |
|------|---------|---------------|
| **Enter Results** | Creating new tournaments | Yes - inline edit/delete for quick fixes during entry |
| **Edit Tournaments** | Modifying existing tournaments | Yes - via "View/Edit Results" modal for retroactive fixes |

Both use the same edit form UI, just accessed differently.

---

## Design: Blank Date Field with Validation

### Current State

```r
dateInput("tournament_date", "Date", value = Sys.Date())
```

Defaults to today, easily overlooked.

### Proposed Change

**Enter Results page (Step 1):**
- Date field starts **blank** (`value = NA`)
- Field shows red border / warning styling until a date is selected
- "Create Tournament" button is **disabled** until date is selected

### Visual Treatment

```
Before selection:
+-----------------------------+
| Date *                      |
| +-------------------------+ |
| | Select date...          | |  <- Placeholder text
| +-------------------------+ |  <- Red/orange border
| Required                    |  <- Helper text
+-----------------------------+

After selection:
+-----------------------------+
| Date *                      |
| +-------------------------+ |
| | Feb 3, 2026             | |  <- Normal styling
| +-------------------------+ |
+-----------------------------+
```

### Form Validation

"Create Tournament" button disabled until ALL required fields are filled:
- Store selected
- **Date selected** (new requirement)
- Event type selected
- Format selected
- Players > 0
- Rounds > 0

---

## Implementation Plan

### Files to Modify

| File | Changes |
|------|---------|
| `views/admin-tournaments-ui.R` | Add "View/Edit Results" button, results modal UI |
| `app.R` | Add modal handlers (open, edit, add, delete results), update duplicate flow to navigate to Edit Tournaments |
| `views/admin-results-ui.R` | Change date default to NA, add required validation styling |
| `www/custom.css` | Required field styling for blank date input |

### No Changes To

- Enter Results wizard flow (kept as-is)
- Enter Results inline edit/delete during entry (kept as-is)
- Public-facing pages

### Effort Estimate

| Change | Effort |
|--------|--------|
| Edit Results modal in Edit Tournaments | Medium (new modal, CRUD handlers) |
| Update duplicate flow navigation | Low (change button handler) |
| Blank date field with validation | Low (change default, add CSS) |

---

## Future Considerations

### Screenshot OCR (Bandai TCG+ App)

**Context:** Admins currently enter all data manually. Bandai TCG+ app shows tournament rankings that could be parsed via OCR.

**What OCR could extract:**
- Placement (1st, 2nd, etc.)
- Username
- Member Number (useful for player deduplication)
- Win Points (can derive approximate W-L-T)

**What still requires manual entry:**
- Deck archetype (not in screenshot)
- Decklist URL
- Tournament metadata (store, date, format)

**Assessment:** OCR would automate ~2/3 of error-prone data entry. Deck assignment errors would persist regardless.

**Status:** Deferred. Ship the quick UX wins (this design) first, prototype OCR separately.

**Reference:** Screenshots uploaded to `screenshots/mobile/` showing Bandai TCG+ ranking format.

### Public Submission with Approval Workflow

**Idea:** Allow non-admin users to submit tournament results (possibly via OCR) for admin approval.

| Approach | Pros | Cons |
|----------|------|------|
| Admin-only entry (current) | Simple, controlled, trusted data | Bottleneck on admins |
| Public submit + admin approval | Scales data entry, community involvement | Approval queue overhead, spam risk |
| Hybrid: OCR + admin review | Faster entry, still controlled | Medium complexity |

**Recommendation:** Start with hybrid (OCR speeds up admin entry). Only add public submissions if admin bandwidth becomes a bottleneck.

### Error Flagging (Lightweight)

**Idea:** Let users report errors without a full approval workflow.

- "Report Error" link in player/tournament modals
- Simple form: "What's wrong?" (text field)
- Creates record in `error_reports` table
- Admin sees badge/list of pending reports

**Status:** Could be added as a quick win alongside or after this design.

---

## Platform & Scaling Considerations

### Current Hosting: Posit Connect Cloud (Free Tier)

| Resource | Free | Basic ($19/mo) | Enhanced ($59/mo) |
|----------|------|----------------|-------------------|
| Memory | 4GB | 8GB | 16GB |
| CPU | 1 | 2 | 4 |
| Active Hours | 20/month | 100/month | 500/month |
| Applications | 5 | 25 | Unlimited |

**"Active hours"** = time the app is actively serving requests (not idle time).

### Scaling Assessment

For a tournament tracker app:
- Usage is sporadic (check results after tournaments, admins enter data)
- Not constant concurrent usage like social media
- International users (e.g., Japan) spread load across time zones

**Estimate:** Enhanced tier ($59/month) with 500 active hours (~16.7 hrs/day average) should handle US-wide + international community traffic comfortably.

### If You Outgrow Posit Connect

**Option 1: Self-hosted Shiny Server**
- Host on DigitalOcean/AWS VPS (~$20-50/month)
- No active hour limits
- You manage server (updates, security, backups)

**Option 2: Rewrite in Another Stack**

| Stack | Pros | Cons |
|-------|------|------|
| Next.js + PostgreSQL | Modern, scalable, huge ecosystem | JS/React learning curve |
| Python (FastAPI) + React | Closer to data science tooling | Two languages |
| SvelteKit | Lightweight, fast | Smaller ecosystem |

**Rewrite effort:**
- 2-4 weeks full-time (experienced developer)
- 2-3 months part-time
- $5k-$15k if hiring

**What you'd lose:**
- R's data manipulation (dplyr, etc.)
- Highcharter/reactable/mapgl (need JS equivalents)
- Rating calculations (rewrite in JS/Python)

### Recommendation

```
Now          -> Stay on Shiny (Free tier)
Growing      -> Upgrade to Enhanced ($59/mo) when hitting limits
Scaling big  -> Self-host Shiny Server OR evaluate rewrite
```

Don't rewrite until you actually hit scaling problems. $59/month is cheap compared to a $10k+ rewrite.

---

## Summary

### In Scope (This Release)

| Change | Description | Effort |
|--------|-------------|--------|
| Edit Results modal | Access player results from Edit Tournaments page | Medium |
| Update duplicate flow | "View/Edit Existing" navigates to Edit Tournaments | Low |
| Blank date field | Required validation, prevents accidental wrong dates | Low |

### Deferred

| Item | Notes |
|------|-------|
| Screenshot OCR | Separate initiative, prototype needed |
| Public submission workflow | Wait until admin bandwidth is bottleneck |
| Error flagging | Quick win, could add later |
| Platform rewrite | Only if scaling demands it |

---

## Open Questions

None at this time. Design is ready for implementation.

---

## Next Steps

1. [x] Get user approval on this design
2. [ ] Create implementation plan with detailed tasks
3. [ ] Implement Edit Results modal
4. [ ] Implement blank date validation
5. [ ] Update duplicate tournament flow
6. [ ] Test with admin users
7. [ ] Deploy
