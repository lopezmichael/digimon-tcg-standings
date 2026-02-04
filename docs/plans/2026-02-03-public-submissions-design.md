# Public Submissions & OCR Design

**Date:** 2026-02-03
**Status:** Draft
**Author:** Claude (with Michael)

## Overview

Enable community-driven data entry through screenshot uploads with OCR, reducing admin bottleneck while maintaining data quality. This design unifies public and admin submission flows into a single system.

### Goals (in priority order)

1. **Data completeness** - Let players add missing decks, results, match history
2. **Community engagement** - Players feel ownership contributing to the tracker
3. **Accuracy** - OCR reduces manual entry errors
4. **Scalability** - Support multi-region expansion where admins can't personally verify all data

## Trust Model

| Submission Type | Who Can Submit | Trust Level | Goes Live |
|-----------------|----------------|-------------|-----------|
| Tournament screenshot | Anyone | High (evidence-based) | Immediately |
| Deck assignment | Anyone | High | Immediately |
| Match history screenshot | Anyone | High (evidence-based) | Immediately |
| Manual tournament entry | Verified users only | Delegated | Immediately |
| New store request | Anyone | Queued | After admin approval |
| New deck request | Anyone | Queued | After admin approval |

Screenshots are inherently trustworthy because they're evidence. Manual entry requires elevated permissions because claims are unverifiable.

---

## Feature 1: Tournament Screenshot Submission

### User Flow

1. User navigates to **"Submit Results"** tab (new public tab)
2. User provides tournament context (not in screenshot):
   - Store: Select existing OR "Request new store"
   - Date: Date picker
   - Event type: Locals, Evo Cup, Store Championship, Regional, Online
   - Format: BT-19, etc.
   - Total rounds: Number input (needed to calculate losses)
3. User uploads 1+ screenshots (tournaments may span multiple pages)
4. System sends images to Google Cloud Vision API for OCR
5. OCR extracts per player:
   - Placement (1st, 2nd, etc.)
   - Username
   - Member number
   - Points (divide by 3 for wins, modulo 3 for ties)
6. User reviews extracted data in editable table
   - Can fix OCR errors (typos, wrong numbers)
   - Cannot add or remove player rows
   - Each row has deck dropdown (defaults to "UNKNOWN")
7. User submits
8. Data goes live immediately

### Multi-Screenshot Handling

Tournament standings may span multiple screenshots (players 1-10, 11-20, etc.):

- "Add another screenshot" button before finalizing
- System merges all extracted players into one tournament
- User reviews combined list before submitting

### Screenshots Not Stored

Images are processed by OCR then discarded. We store only the extracted text data. This:
- Reduces storage costs
- Avoids privacy concerns
- Keeps the system simple

---

## Feature 2: Deck Assignment

### During Submission

- All decks default to "UNKNOWN"
- Uploader can assign known decks from dropdown
- Submission proceeds even if decks are unknown

### After Submission (Edit Unknown Decks)

Anyone can update UNKNOWN decks to real decks:

- Available on tournament detail modals, Tournaments tab, anywhere results shown
- UI pattern: Click to edit → Select deck → Click to confirm
- Direct edit (no approval queue) for simplicity
- Admins can correct mistakes if needed

---

## Feature 3: Match History Submission

### What It Captures

The Bandai TCG+ app shows round-by-round match history:

| Data | Source |
|------|--------|
| Round number | OCR |
| Opponent username | OCR |
| Opponent member number | OCR |
| Games W-L-T | OCR (e.g., "2-1-0") |
| Match points | OCR (3=win, 1=draw, 0=loss) |

### User Flow

1. User finds existing tournament (search or from tournament detail)
2. Clicks "Add match history"
3. Uploads match history screenshot
4. OCR extracts round-by-round data
5. System matches opponents to player records:
   - Match by member number if known
   - Fallback: User confirms player match
6. User reviews and submits
7. Data linked to tournament

### Entry Points

- Dedicated section in "Submit Results" tab
- "Add my match history" button on tournament detail modals

### Prerequisite

Tournament must already exist. Match history enriches existing tournaments, doesn't create new ones.

### Player Matching

When OCR extracts opponent info:

1. Try match by `member_number` (if we have it for existing players)
2. If no match, try fuzzy match by username
3. If username match found → ask user to confirm before linking member number
4. If no match → create new player record with username + member number

This gradually enriches our player database with member numbers over time.

---

## Feature 4: Request New Store / Deck

### Store Requests

If uploader's store isn't in the dropdown:

1. Click "Request new store"
2. Enter: Store name, City, State (optional: address, coordinates)
3. Request goes to admin queue
4. Admin approves → store becomes available
5. Uploader notified (or can check back)

### Deck Requests

If a new archetype isn't in the dropdown:

1. Click "Request new deck"
2. Enter: Deck name, Primary color, (optional: secondary color, representative card ID)
3. Request goes to admin queue
4. Admin approves → deck becomes available

---

## Feature 5: Unified Admin System

### Current State

- Admins use "Enter Results" wizard for manual entry
- Public has no submission capability

### New State

One unified submission system with permission tiers:

| Capability | Public | Admin |
|------------|--------|-------|
| Upload tournament screenshot | Yes | Yes |
| Upload match history screenshot | Yes | Yes |
| Assign/edit decks | Yes | Yes |
| Manual tournament entry (no screenshot) | No | Yes |
| Edit any tournament metadata | No | Yes |
| Delete tournaments | No | Yes |
| Delete match history | No | Yes |
| Approve store/deck requests | No | Yes |
| Add stores directly | No | Yes |
| Add decks directly | No | Yes |

Admins benefit from OCR too - faster entry for everyone.

---

## Schema Changes

### Players Table

Add `member_number` column:

```sql
ALTER TABLE players ADD COLUMN member_number TEXT UNIQUE;
```

- Nullable (existing players won't have it)
- Unique when present (Bandai member numbers are unique)
- Populated via screenshot OCR over time

### New: Matches Table

Store round-by-round matchup data:

```sql
CREATE TABLE matches (
  match_id INTEGER PRIMARY KEY AUTOINCREMENT,
  tournament_id INTEGER NOT NULL REFERENCES tournaments(tournament_id),
  round_number INTEGER NOT NULL,
  player_id INTEGER NOT NULL REFERENCES players(player_id),
  opponent_id INTEGER NOT NULL REFERENCES players(player_id),
  games_won INTEGER NOT NULL,
  games_lost INTEGER NOT NULL,
  games_tied INTEGER NOT NULL DEFAULT 0,
  match_points INTEGER NOT NULL, -- 3=win, 1=draw, 0=loss
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE(tournament_id, round_number, player_id)
);
```

**Note:** If both players submit match history, we'll have two rows for the same match (from each perspective). This is intentional - simpler than deduplication, and serves as cross-validation.

### New: Store Requests Table

```sql
CREATE TABLE store_requests (
  request_id INTEGER PRIMARY KEY AUTOINCREMENT,
  store_name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  address TEXT,
  latitude REAL,
  longitude REAL,
  status TEXT DEFAULT 'pending', -- pending, approved, rejected
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TIMESTAMP,
  reviewed_by TEXT
);
```

### New: Deck Requests Table

```sql
CREATE TABLE deck_requests (
  request_id INTEGER PRIMARY KEY AUTOINCREMENT,
  deck_name TEXT NOT NULL,
  primary_color TEXT NOT NULL,
  secondary_color TEXT,
  display_card_id TEXT,
  status TEXT DEFAULT 'pending', -- pending, approved, rejected
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  reviewed_at TIMESTAMP,
  reviewed_by TEXT
);
```

---

## OCR Implementation

### Technology Choice

**Direct REST calls to Google Cloud Vision API using httr2**

Rejected alternatives:
- `tesseract` R package: Requires system libraries not available on Posit Connect Cloud
- `googleCloudVisionR` package: Last updated 2020, unmaintained
- Client-side Tesseract.js: Viable fallback if API costs become concern

### Why Google Cloud Vision

- High accuracy on structured app screenshots
- Simple REST API
- Free tier: 1,000 images/month
- No system dependencies (just HTTPS calls)

### Implementation Sketch

```r
library(httr2)
library(jsonlite)

gcv_ocr <- function(image_path, api_key) {
  # Read and base64 encode image
  image_data <- base64enc::base64encode(image_path)

  # Build request
  response <- request("https://vision.googleapis.com/v1/images:annotate") |>
    req_url_query(key = api_key) |>
    req_body_json(list(
      requests = list(list(
        image = list(content = image_data),
        features = list(list(type = "TEXT_DETECTION"))
      ))
    )) |>
    req_perform() |>
    resp_body_json()

  # Extract text
  response$responses[[1]]$fullTextAnnotation$text
}
```

### Parsing OCR Output

The raw OCR text needs parsing to extract structured data. Tournament standings have predictable format:

```
1  PlayerName1  9
2  PlayerName2  7
3  PlayerName3  6
...
```

We'll need regex patterns to extract:
- Placement (leading number)
- Username (middle text)
- Points (trailing number)
- Member number (if visible, format: 0000XXXXXX)

### API Key Management

- Store API key as environment variable on Posit Connect Cloud
- Never commit to git
- Add `GOOGLE_CLOUD_VISION_API_KEY` to `.env.example`

---

## UI Design

### New "Submit Results" Tab

Public-facing tab in main navigation:

```
[Dashboard] [Players] [Meta] [Tournaments] [Stores] [Submit Results]
```

### Submit Results Page Layout

```
+----------------------------------------------------------+
|  Submit Results                                           |
|  Help grow the tournament database                        |
+----------------------------------------------------------+
|                                                           |
|  [Tournament Results]  [Match History]    <- Tab toggle   |
|                                                           |
|  +-----------------------------------------------------+  |
|  | Tournament Details                                   |  |
|  | Store: [Dropdown] or [Request New Store]            |  |
|  | Date: [Date Picker]                                 |  |
|  | Event Type: [Dropdown]                              |  |
|  | Format: [Dropdown]                                  |  |
|  | Rounds: [Number]                                    |  |
|  +-----------------------------------------------------+  |
|                                                           |
|  +-----------------------------------------------------+  |
|  | Screenshots                                          |  |
|  | [Upload Screenshot]  [+ Add Another]                |  |
|  |                                                      |  |
|  | screenshot1.png  [x]                                |  |
|  | screenshot2.png  [x]                                |  |
|  +-----------------------------------------------------+  |
|                                                           |
|  [Process Screenshots]                                    |
|                                                           |
+----------------------------------------------------------+
```

### Review & Edit Screen (after OCR)

```
+----------------------------------------------------------+
|  Review Results                           [Back] [Submit] |
+----------------------------------------------------------+
|  Store: Common Ground Games                               |
|  Date: Feb 3, 2026 | Format: BT-19 | Rounds: 4           |
+----------------------------------------------------------+
|  #  | Player          | Points | W-L-T  | Deck           |
+-----+-----------------+--------+--------+----------------+
|  1  | [HappyCat    ]  | [9  ]  | 3-0-0  | [Imperialdramon v] |
|  2  | [Palestreem  ]  | [7  ]  | 2-0-1  | [UNKNOWN       v] |
|  3  | [AzureMage   ]  | [6  ]  | 2-1-0  | [UNKNOWN       v] |
| ... | ...             | ...    | ...    | ...            |
+----------------------------------------------------------+
|  [x] I confirm this data is accurate                      |
|                                              [Submit]     |
+----------------------------------------------------------+
```

---

## Error Handling

### OCR Failures

- If API call fails: Show error, allow retry
- If image unreadable: "Could not extract text. Please try a clearer screenshot."
- If parsing fails: Show raw OCR text, allow manual correction

### Duplicate Tournament Detection

Before creating tournament, check for existing tournament with same:
- Store + Date + Event Type

If found: "A tournament matching this already exists. View existing?"

### Invalid Data

- Missing required fields: Disable submit, highlight missing
- Invalid point values: Warning but allow override
- Unmatched players: Create new player records

---

## Future Considerations

### Manual Round-by-Round Entry

Deferred. If match history screenshots prove valuable, we can add manual entry for edge cases (non-TCG+ events).

### Submission History / Audit Trail

Could track who submitted what, when. Useful for:
- Recognizing top contributors
- Investigating bad data
- Building trust scores over time

### Rate Limiting

If spam becomes an issue:
- Limit submissions per IP/session
- Require solving captcha for high volume

### Regional Moderators

As we expand to other regions, designated moderators could:
- Approve store/deck requests for their region
- Have manual entry permission
- Review flagged submissions

---

## Implementation Plan

### Phase 1: Core Screenshot Submission
1. Add `member_number` column to players table
2. Create Google Cloud Vision API integration (httr2)
3. Build OCR parsing logic for tournament standings
4. Create "Submit Results" UI (tournament flow only)
5. Implement review/edit screen with deck assignment
6. Add duplicate tournament detection

### Phase 2: Requests & Admin Unification
7. Create store_requests and deck_requests tables
8. Build request submission UI
9. Build admin approval queue UI
10. Migrate admin "Enter Results" to unified system
11. Add manual entry option (admin-only)

### Phase 3: Match History
12. Create matches table
13. Add match history OCR parsing
14. Build match history submission UI
15. Implement player matching with confirmation flow

### Phase 4: Polish
16. Edit unknown decks feature (click-to-edit anywhere)
17. Error handling improvements
18. Mobile optimization
19. Documentation / help text

---

## Open Questions

None at this time. Design is ready for implementation.

---

## References

- [Google Cloud Vision API Docs](https://cloud.google.com/vision/docs/ocr)
- [httr2 Package](https://httr2.r-lib.org/)
- Bandai TCG+ screenshot examples: `screenshots/mobile/`
- Previous admin UX design: `docs/plans/2026-02-03-admin-ux-improvements-design.md`
