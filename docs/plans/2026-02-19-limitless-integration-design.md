# Limitless TCG Integration Design

**Date:** 2026-02-19
**Status:** Draft
**Target Version:** v0.24+

## Overview

Integrate the [LimitlessTCG API](https://docs.limitlesstcg.com/developer/) to automatically sync online Digimon Card Game tournament data into DigiLab. This eliminates manual data entry for online organizers, populates the "Online" scene, and gives DigiLab rich meta analysis data from organizers who collect decklists.

## Goals (Priority Order)

1. **Automated data ingestion** - No manual entry needed for Limitless tournaments
2. **Online scene visibility** - Players competing online get ratings, standings, and meta tracking
3. **Rich meta data** - Deck archetype classification from organizers who collect it
4. **Organizer partnerships** - "Want your community on DigiLab? Use Limitless and require decklists"
5. **Player network effects** - Online players discover DigiLab; local players see their online results

## Research Findings

### API Overview

**Base URL:** `https://play.limitlesstcg.com/api`
**Auth:** No API key required for basic access. Key available for higher rate limits and `/games/{id}/decks` endpoint. Key requested 2026-02-19 (pending approval).
**Game ID:** `DCG` (Digimon Card Game)

| Endpoint | Data | Quality for DCG |
|----------|------|-----------------|
| `GET /tournaments?game=DCG&organizerId={id}` | Tournament list with date, players, format | Good |
| `GET /tournaments/{id}/details` | Organizer, phases, online flag, decklists flag | Good |
| `GET /tournaments/{id}/standings` | Placements, W/L/T, deck archetype, full decklists | Organizer-dependent |
| `GET /tournaments/{id}/pairings` | Round-by-round match results with winners | Good |

### Key Findings

- **Deck data is organizer-dependent.** Organizers who set `decklists: true` provide full card-by-card decklists AND auto-classified deck archetypes. Organizers with `decklists: false` provide only placements and W/L/T records.
- **`format` is always null** for DCG tournaments. Format can be inferred from tournament name or tournament date + release schedule.
- **No geographic data** on tournaments. Online organizers are identified by `organizerId` only.
- **Player identity** is Limitless username only - no Bandai TCG+ member numbers.
- **~2,500+ DCG tournaments** exist on Limitless dating back to mid-2022.
- **Pagination:** `limit` + `page` params, 50 results default/max per page.

### Organizer Data Quality Audit

**Tier 1 - Full data, high volume, active (LAUNCH TARGETS):**

| Org ID | Name | Events | Players/Event | Decklists | Full Deck Data | Region |
|--------|------|--------|--------------|-----------|----------------|--------|
| 452 | Eagle's Nest | 111 | 13-29 | Yes | Yes | USA |
| 281 | PHOENIX REBORN | 146+ | 5-18 | Yes | Yes | Argentina |
| 559 | DMV Drakes | 50+ | 4-28 | Yes | Yes | USA (DC/MD/VA) |
| 578 | MasterRukasu | 44 | 4-17 | Yes | Yes | Brazil |

**Tier 2 - Full data, moderate volume:**

| Org ID | Name | Events | Players/Event | Decklists | Full Deck Data | Region |
|--------|------|--------|--------------|-----------|----------------|--------|
| 999 | DigiGuard United | 51 | 4-16 | Yes | Yes | USA (inactive since Nov 2025) |

**Tier 3 - Full data, low volume:**

| Org ID | Name | Events | Players/Event | Decklists | Full Deck Data | Region |
|--------|------|--------|--------------|-----------|----------------|--------|
| 2453 | Decks y Mazos | 5 | 6-10 | Yes | Yes | Mexico |
| 1023 | Rancho del Profesor | 1 | 48 | Yes | Yes | Latin America (special events) |
| 1407 | Nani Entertainment LLC | 3 | 4-6 | Yes | Yes | USA (sporadic) |

**Not recommended (no deck data):**
451 (Team Nordic Gap), 537 (Homelands), 1009 (DigiGalaxy), 1093 (Card Station), 1237 (Howayte), 1283 (Questionable Plays), 1758 (HaoQi cup), 1882 (DCGO Wednesdays), 2025 (Frikioteca), 2536 (Expanse Italia)

### Example Data (Eagle's Nest, 39-player tournament)

**Standings entry:**
```json
{
  "name": "Vpassion",
  "country": "US",
  "placing": 1,
  "player": "vpassion",
  "record": { "wins": 5, "losses": 0, "ties": 0 },
  "deck": { "id": "Royal-Knights", "name": "Royal Knights" },
  "decklist": { "digimon": [...], "tamer": [...], "option": [...], "egg": [...] },
  "drop": null
}
```

**Pairings entry:**
```json
{
  "round": 1, "phase": 1, "table": 1,
  "winner": "awesdmon",
  "player1": "awesdmon", "player2": "m149307"
}
```

## Existing Infrastructure

Schema fields already exist (unused):
- `tournaments.limitless_id VARCHAR` — Store Limitless tournament ID
- `players.limitless_username VARCHAR` — Store Limitless player username

Event type exists:
- `"Online Tournament" = "online"` in EVENT_TYPES (app.R:227)

Online store support exists:
- `stores.is_online BOOLEAN` — Flags virtual stores
- `scenes` table has "Online" as a top-level scene type
- Rating system treats online tournaments equally (no special handling in `R/ratings.R`)

Existing deck request queue:
- `deck_requests` table with status workflow (pending → approved/rejected)
- Admin UI for reviewing and approving deck requests
- Results can reference `pending_deck_request_id` until deck is approved

## Core Design Decisions

### Organizer = Virtual Store

Each Limitless organizer maps to a DigiLab store with `is_online = TRUE`:

| Limitless | DigiLab |
|-----------|---------|
| `organizerId: 452` | `stores.limitless_organizer_id = 452` |
| `organizer.name: "The Eagle's Nest"` | `stores.name = "The Eagle's Nest"` |
| `isOnline: true` | `stores.is_online = TRUE` |
| N/A | `stores.scene_id` → Online scene |

**New schema field:** `stores.limitless_organizer_id INTEGER`

### Event Type

All Limitless-synced tournaments use `event_type = "online"` (the existing "Online Tournament" type).

### Player Matching Strategy

Limitless provides `player` (permanent username) and `name` (display name, changeable).

**During sync:**
1. Check `players.limitless_username` for exact match → use that existing player
2. No match → auto-create new player with `display_name` from Limitless `name` field and `limitless_username` set

**Player merging** (Phase 2 — when an online player turns out to be a known local):
- General-purpose "Merge Players" admin tool (useful beyond just Limitless)
- Admin selects primary player (local, has Bandai ID) and secondary player (Limitless duplicate)
- Merge operation transfers all results + matches from secondary → primary
- Copies `limitless_username` to primary player
- Deletes secondary player record
- Recalculates ratings
- See [Player Merge Design](#player-merge-design) section below

**Pre-link shortcut:** Admin can set `limitless_username` on a known local player before running sync. The sync will then match correctly without needing a merge.

### Deck Archetype Mapping

Limitless deck IDs (e.g., `Hudies`, `jes`, `Royal-Knights`) don't match our `archetype_id` values.

**Solution:** New mapping table + existing deck request queue.

```sql
CREATE TABLE limitless_deck_map (
  limitless_deck_id VARCHAR NOT NULL,
  limitless_deck_name VARCHAR,
  archetype_id INTEGER,
  PRIMARY KEY (limitless_deck_id)
);
```

**Mapping workflow:**
1. Sync encounters Limitless deck ID → check `limitless_deck_map`
2. **Mapped (archetype_id set)?** → Use the linked archetype
3. **Not mapped?** → Create a `deck_requests` entry with `deck_name` = Limitless deck display name, `status = 'pending'`. Result gets `pending_deck_request_id`.
4. Admin reviews in existing deck management UI:
   - If deck matches an existing archetype → approve, set mapping in `limitless_deck_map`
   - If truly new deck → create archetype, then set mapping
5. Limitless `"other"` deck → map to our `UNKNOWN` archetype

This reuses the existing deck request queue workflow. Unmapped decks show up alongside manually-requested decks for admin review.

### Format Inference

Limitless `format` field is always null for DCG. We infer format using two strategies:

**Strategy 1 — Parse from tournament name (preferred):**
Regex for `BT-?\d+` or `EX-?\d+` patterns in tournament name.
- Eagle's Nest: ~95% match rate (e.g., "S8W5.0 **BT24** Win-A-Box")
- DMV Drakes: ~40% match rate (e.g., "[**BT24** Win a Box]")
- PHOENIX REBORN: ~2% match rate (rarely includes format in name)

**Strategy 2 — Date-based fallback:**
Find the most recent format in the `formats` table where `release_date <= tournament_date`.
Works for all organizers regardless of naming convention.

**Implementation:** Try name parsing first. If no match, fall back to date-based. Admin can manually correct any misassignments.

**Note:** Newer formats (BT20+, EX09+) must be in the `formats` table with correct release dates for the date fallback to work. Verify these exist before initial sync.

### What We Sync vs. Skip

| Data | Sync? | Notes |
|------|-------|-------|
| Tournament metadata | Yes | Name, date, player count, rounds, event_type="online" |
| Standings (placement, W/L/T) | Yes | Core results data |
| Deck archetype | Yes | Via mapping table, unmapped → deck request queue |
| Full decklists | **No** | Not storing card-by-card decklist data for now |
| Match pairings | Yes | Round-by-round into `matches` table |
| Player country | Yes | Store in player record (new field or notes) |
| Player drop round | Yes | Store in `results.notes` |
| Tournament format | Yes | Inferred from name or date |

### Decklist Storage

**Not storing decklists for now.** The Limitless API provides full card-by-card decklists, but we don't have a UI or feature plan for decklist data yet. This can be revisited as a separate feature if needed.

### Sync Source of Truth

Limitless sync is the **sole source** for tracked organizers' tournament data. No need for deduplication against manually-entered tournaments. If an organizer is tracked for Limitless sync, their data comes exclusively from the sync.

### Historical Sync Depth

Sync back to the **BT23 era** for each organizer:
- **Eagle's Nest (452):** BT23 starts ~Oct 20, 2025
- **PHOENIX REBORN (281):** All data (they only go back to Dec 27, 2025)
- **DMV Drakes (559):** BT23 starts ~Nov 2025

This aligns with DigiLab's current data starting at BT24. Going back one format gives historical context.

### Match Pairings

Limitless pairings provide: `round`, `phase`, `table`, `player1`, `player2`, `winner`.

They do NOT provide game-level scores (games_won/games_lost/games_tied within a match).

**Mapping to `matches` table:**
- `round_number` ← `round`
- `player_id` ← resolve `player1` username to player_id
- `opponent_id` ← resolve `player2` username to player_id
- Derive `match_points` from `winner` field: 3 (win), 1 (tie, `winner = "0"`), 0 (loss or double loss `winner = "-1"`)
- `games_won` / `games_lost` / `games_tied` = NULL (Limitless only reports match winner, not game-level scores within a BO3)

**Note:** Each Limitless pairing is one row (both players). Our `matches` table stores one row per player perspective. The sync creates two rows per pairing (one for each player).

## Schema Changes

```sql
-- Link stores to Limitless organizers
ALTER TABLE stores ADD COLUMN limitless_organizer_id INTEGER;
CREATE INDEX idx_stores_limitless ON stores(limitless_organizer_id);

-- Map Limitless deck IDs to our archetypes
CREATE TABLE limitless_deck_map (
  limitless_deck_id VARCHAR NOT NULL,
  limitless_deck_name VARCHAR,
  archetype_id INTEGER,
  PRIMARY KEY (limitless_deck_id)
);

-- Track sync state per organizer
CREATE TABLE limitless_sync_state (
  organizer_id INTEGER NOT NULL,
  last_synced_at TIMESTAMP,
  last_tournament_date TIMESTAMP,
  tournaments_synced INTEGER DEFAULT 0,
  PRIMARY KEY (organizer_id)
);
```

Existing fields to populate:
- `tournaments.limitless_id` — set to Limitless tournament ID string on sync
- `players.limitless_username` — set on player creation or manual pre-link
- `tournaments.event_type` — set to `"online"` for all Limitless tournaments

## Player Merge Design

**Existing tool:** A merge players tool already exists in the admin panel (`server/admin-players-server.R:282`, `views/admin-players-ui.R:98`). It has source/target player selection, preview, and executes the merge.

### Current Merge Implementation

The existing tool:
- Selects source player (deleted) and target player (kept)
- Transfers all `results` from source → target
- Deletes source player
- Triggers data refresh

### Enhancements Needed for Limitless

The existing merge needs two additions:

```sql
-- EXISTING: Transfer results
UPDATE results SET player_id = :target WHERE player_id = :source;

-- NEW: Transfer matches (as player)
UPDATE matches SET player_id = :target WHERE player_id = :source;

-- NEW: Transfer matches (as opponent)
UPDATE matches SET opponent_id = :target WHERE opponent_id = :source;

-- NEW: Copy Limitless username to target (if not already set)
UPDATE players SET limitless_username = (
  SELECT limitless_username FROM players WHERE player_id = :source
) WHERE player_id = :target AND limitless_username IS NULL;

-- EXISTING: Delete source player
DELETE FROM players WHERE player_id = :source;
```

Also add: recalculate ratings cache after merge.

### Unique Constraint Handling

The `results` table has `UNIQUE(tournament_id, player_id)`. If both players have a result in the same tournament (unlikely but possible), the merge should warn and skip that result rather than failing.

## Implementation Plan

### Phase 1: Foundation (MVP)

**1.1 Schema updates**
- Add `limitless_organizer_id` to stores table
- Create `limitless_deck_map` table
- Create `limitless_sync_state` table
- Verify formats table has BT23+ and EX10+ with correct release dates (needed for date-based format fallback)

**1.2 Sync script (`scripts/sync_limitless.py`)**
- CLI tool: `python scripts/sync_limitless.py --organizer 452 --since 2025-10-01`
- Fetches tournament list → details → standings → pairings
- Creates/updates: stores (as online), players, tournaments, results, matches
- Player matching: `limitless_username` exact match or create new
- Deck mapping: check `limitless_deck_map`, unmapped → `deck_requests` queue
- Format inference: regex parse name → date-based fallback
- Event type: always `"online"`
- Idempotent: skips tournaments already synced (by `limitless_id`)
- Respects rate limits (check response headers, add delay between calls)
- Logs to `ingestion_log` table
- Dry-run mode for testing: `--dry-run` shows what would be synced without writing

**1.3 Seed Tier 1 organizers**
- Create online store records for Eagle's Nest (452), PHOENIX REBORN (281), DMV Drakes (559), MasterRukasu (578)
- Link to Online scene
- Seed `limitless_deck_map` with obvious mappings (Limitless deck names → existing archetypes)

**1.4 Initial historical sync**
- Eagle's Nest: `--since 2025-10-01` (BT23 era start)
- PHOENIX REBORN: `--since 2025-12-01` (all their data)
- DMV Drakes: `--since 2025-10-01` (BT23 era start)
- MasterRukasu: `--since 2025-10-01` (BT23 era start)
- Review unmapped decks in admin deck request queue
- Verify ratings recalculation works with new volume
- Verify online tournaments appear correctly with Online scene filter

### Phase 2: GitHub Actions + Player Merge

**2.1 GitHub Actions workflow (`.github/workflows/sync-limitless.yml`)**
- Daily cron schedule (e.g., `0 6 * * *` — 6am UTC daily)
- Also supports `workflow_dispatch` for manual trigger with optional inputs (organizer ID, since date)
- Runs `scripts/sync_limitless.py` against MotherDuck (cloud DB)
- Mirrors existing `sync-cards.yml` pattern
- Tracked organizer list stored in script config or workflow inputs

**2.2 Enhance existing player merge tool**
- Add `matches` table transfer (player_id + opponent_id) to existing merge handler
- Add `limitless_username` copy from source → target
- Add ratings cache recalculation after merge
- Small changes to `server/admin-players-server.R:339-347`

**2.3 Deck mapping review**
- Unmapped Limitless decks flow through existing deck request queue
- Admin approves → creates/links archetype + updates `limitless_deck_map`
- No new UI needed beyond existing deck request workflow

### Phase 3: Ongoing Operations

**3.1 New organizer onboarding**
- Organizer contacts DigiLab (Discord or form)
- Must use Limitless with `decklists: true`
- Admin creates online store record + adds organizer ID to sync config
- Run manual `workflow_dispatch` for initial historical sync, then daily cron handles ongoing

## Data Volume Estimates

For Tier 1 organizers, BT23+ only:

| Metric | Estimate |
|--------|----------|
| Tournaments | ~150 (historical) + ~10/week (ongoing) |
| Results rows | ~3,000 (historical) + ~200/week |
| Unique players | ~300-600 |
| Match pairings | ~8,000 (historical) |
| API calls for initial sync | ~600 (150 tournaments × 4 endpoints) |

With rate limiting and delays, initial sync is a ~10-20 minute one-time job.

## Resolved Questions

1. **Event type:** Use existing `event_type = "online"` for all Limitless tournaments
2. **Rating pool:** Online tournaments feed the same Elo pool as locals (no separation needed)
3. **Historical depth:** Sync back to BT23 era (~Oct 2025) to align with DigiLab's existing data range
4. **Format inference:** Regex parse from tournament name first, date-based fallback second
5. **Decklists:** Not storing card-by-card decklist data for now
6. **Unmapped decks:** Route through existing deck request queue for admin review
7. **Sync source:** Limitless sync is sole source for tracked organizers, no dedup needed
8. **Player creation:** Use Limitless display name, set limitless_username
9. **Player merge:** Existing merge tool in admin panel; enhance with matches transfer + limitless_username copy in Phase 2
10. **Match pairings:** Sync to matches table; match_points derived from winner field, game-level scores (games_won/lost/tied) NULL since Limitless only reports match winner not BO3 game scores
11. **Player count minimum:** Keep existing `>= 4` threshold for ratings. Same rules for online and offline. Filters out very few Limitless events.
12. **Ongoing sync:** Phase 1 = CLI script (local), Phase 2 = GitHub Actions daily cron + manual `workflow_dispatch` (mirrors existing `sync-cards.yml` pattern). No in-app sync button needed.
13. **Organizer onboarding:** Admin-only for now. Outbound outreach to identified organizers, or inbound via Discord. No self-service form until demand justifies it.
14. **Player country:** Defer. Limitless provides ISO codes but no current feature needs it. Add later if player profiles or geographic analytics warrant it.

## Future Consideration: Stores Page for Online Organizers

The current stores page is designed for physical locations (map, address, schedule). Online organizers won't have geographic data. A future iteration should adapt the stores page to handle online organizers appropriately (e.g., show Discord/YouTube links instead of address, skip map pin). This is post-implementation scope.
