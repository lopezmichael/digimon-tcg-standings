# DigimonCard.io Card Cache Design

**Date:** 2026-01-27
**Status:** Approved
**Problem:** DigimonCard.io API returns 403 from Posit Connect Cloud servers, blocking card search in production.

## Solution Overview

Cache card metadata from DigimonCard.io into MotherDuck. The Shiny app searches the local cache instead of calling the external API. Images continue loading from the CDN (browser requests work fine).

## Scope

- **Card types:** All (Digimon, Tamer, Option, Digi-Egg)
- **Alternate arts:** Excluded (filter by ID pattern)
- **Current sets:** Up to BT24, EX10
- **Estimated cards:** ~2,400

## Database Schema

New `cards` table in MotherDuck:

```sql
CREATE TABLE IF NOT EXISTS cards (
    card_id VARCHAR PRIMARY KEY,      -- e.g., "BT13-087"
    name VARCHAR NOT NULL,            -- e.g., "Beelzemon"
    display_name VARCHAR NOT NULL,    -- e.g., "Beelzemon (BT13-087)"
    card_type VARCHAR NOT NULL,       -- "Digimon", "Tamer", "Option", "Digi-Egg"
    color VARCHAR,                    -- Primary color
    color2 VARCHAR,                   -- Secondary color (if any)
    level INTEGER,                    -- Digimon level (NULL for others)
    dp INTEGER,                       -- Digimon DP (NULL for others)
    play_cost INTEGER,
    digi_type VARCHAR,                -- e.g., "Demon Lord"
    stage VARCHAR,                    -- e.g., "Mega"
    rarity VARCHAR,                   -- e.g., "SR"
    set_code VARCHAR,                 -- e.g., "BT13" (extracted from card_id)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_cards_name ON cards(name);
CREATE INDEX IF NOT EXISTS idx_cards_type ON cards(card_type);
CREATE INDEX IF NOT EXISTS idx_cards_color ON cards(color);
CREATE INDEX IF NOT EXISTS idx_cards_set ON cards(set_code);
```

## Sync Script

**File:** `scripts/sync_cards.py`

**Strategy:** Full sync by color (7 API requests total)

**Features:**
- Fetches all cards by color from DigimonCard.io API
- Filters out alternate arts (IDs not matching `^[A-Z]{1,3}\d{1,2}-\d{2,3}$`)
- UPSERTs into MotherDuck `cards` table
- Respects API rate limits (15 requests/10 seconds)

**Usage:**
```bash
# Full sync
python scripts/sync_cards.py

# Manual trigger for specific set (optional)
python scripts/sync_cards.py --set BT24
```

## GitHub Actions Automation

**File:** `.github/workflows/sync-cards.yml`

Runs monthly on the 1st, with manual trigger option:

```yaml
name: Sync Card Database
on:
  schedule:
    - cron: '0 0 1 * *'
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install duckdb python-dotenv requests
      - run: python scripts/sync_cards.py
        env:
          MOTHERDUCK_TOKEN: ${{ secrets.MOTHERDUCK_TOKEN }}
```

## Shiny App Changes

**File:** `R/digimoncard_api.R`

Add new function:
```r
search_cards_local <- function(con, name, card_types = c("Digimon", "Tamer"), limit = 100)
```

**File:** `app.R`

Update card search observer:
- Replace `search_by_name()` API call with `search_cards_local()` database query
- Use `display_name` field for result labels
- Image URLs unchanged: `https://images.digimoncard.io/images/cards/{card_id}.webp`

## What Stays the Same

- All image display (loads from CDN via browser)
- Search UI layout and pagination
- Card selection workflow
- `deck_archetypes.display_card_id` storage

## Implementation Steps

1. Add `cards` table to schema and run migration on MotherDuck
2. Create `scripts/sync_cards.py` and run initial sync
3. Add `search_cards_local()` function to `R/digimoncard_api.R`
4. Update `app.R` to use local search
5. Test locally and deploy
6. Add GitHub Actions workflow for monthly sync
7. Add `MOTHERDUCK_TOKEN` to GitHub repo secrets
