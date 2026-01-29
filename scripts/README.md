# Scripts

Utility scripts for database setup, synchronization, and maintenance.

## Prerequisites

### R Scripts
- R 4.3+ with packages from `renv.lock`
- Run `renv::restore()` to install dependencies

### Python Scripts
```bash
pip install duckdb python-dotenv requests
```

### Environment Variables
Create a `.env` file in the project root (see `.env.example`):
```
MOTHERDUCK_TOKEN=your_token_here
MOTHERDUCK_DATABASE=digimon_tcg_dfw
MAPBOX_ACCESS_TOKEN=your_mapbox_token
```

---

## Setup Scripts (New Users)

Run these in order for a fresh local database setup:

### 1. Initialize Database Schema (`init_database.R`)

Creates all tables, indexes, and views in the local DuckDB database.

```r
source("scripts/init_database.R")
# Creates: data/local.duckdb with empty tables
```

**Tables created:** stores, players, deck_archetypes, archetype_cards, tournaments, results, formats, cards, ingestion_log

### 2. Seed Store Data (`seed_stores.R`)

Populates the stores table with DFW-area game stores.

```r
source("scripts/seed_stores.R")
# Adds 13 local game stores with addresses and coordinates
```

### 3. Seed Deck Archetypes (`seed_archetypes.R`)

Populates deck archetypes with current meta decks.

```r
source("scripts/seed_archetypes.R")
# Adds 25+ deck archetypes with colors and display cards
```

### 4. Seed Formats (`seed_formats.R`)

Populates the formats table with Digimon TCG set information.

```r
source("scripts/seed_formats.R")
# Adds BT01-BT19, EX01-EX08 format entries
```

### 5. Sync Card Database (Optional but Recommended)

Pull the full card database from DigimonCard.io API.

```bash
python scripts/sync_cards.py --by-set --local
# Syncs 4,200+ cards to local database
# Takes ~3-5 minutes due to API rate limiting
```

---

## Sync Scripts

### Card Sync (`sync_cards.py`)

Syncs card data from [DigimonCard.io](https://digimoncard.io) API to the database.

**Full documentation:** [docs/card-sync.md](../docs/card-sync.md)

#### Common Usage

```bash
# Regular update - fast, only adds new cards
python scripts/sync_cards.py --by-set --incremental

# Full re-sync - slower, updates all cards
python scripts/sync_cards.py --by-set

# Sync specific set (e.g., when new set releases)
python scripts/sync_cards.py --set BT-25 --by-set

# Check for new set prefixes
python scripts/sync_cards.py --discover

# Sync to local database instead of MotherDuck
python scripts/sync_cards.py --by-set --local
```

#### Flags

| Flag | Description |
|------|-------------|
| `--by-set` | Fetch by set/pack instead of color. **Recommended** - more comprehensive. |
| `--incremental` | Skip cards already in database. Much faster for updates. |
| `--discover` | Scan API for new/unknown set prefixes. |
| `--set X` | Sync only a specific set (e.g., `BT-25`, `EX-12`). |
| `--local` | Sync to local DuckDB instead of MotherDuck cloud. |

#### Sets Covered

- **Booster Sets:** BT-01 through BT-24
- **Extra Boosters:** EX-01 through EX-11
- **Starter Decks:** ST-1 through ST-22
- **Limited Packs:** LM-01 through LM-08
- **Resurgence:** RB-01
- **Promo Packs:** 49 different promo/box promotion packs

---

### Push to Cloud (`sync_to_motherduck.py`)

Pushes your local DuckDB database to MotherDuck cloud. Use this to deploy local changes.

```bash
python scripts/sync_to_motherduck.py
```

**What it does:**
1. Connects to MotherDuck using `MOTHERDUCK_TOKEN`
2. Creates database if it doesn't exist
3. Copies all tables from local to cloud (overwrites cloud data)

**When to use:**
- After making local data changes you want to deploy
- Initial setup of cloud database from local

---

### Pull from Cloud (`sync_from_motherduck.py`)

Pulls MotherDuck cloud database to your local DuckDB. Use for fresh dev setup or restoring from cloud.

```bash
# Interactive (prompts for confirmation)
python scripts/sync_from_motherduck.py

# Skip confirmation prompt
python scripts/sync_from_motherduck.py --yes
```

**What it does:**
1. Connects to MotherDuck
2. Shows table counts (preview)
3. Overwrites local database with cloud data

**When to use:**
- Fresh clone of repo - get production data locally
- Restore local database from cloud backup
- Sync after someone else made cloud changes

---

## Optional Scripts

### Generate Mock Data (`seed_mock_data.R`)

Creates fake tournament data for testing and development.

```r
source("scripts/seed_mock_data.R")
# Generates: fake players, tournaments, and results
# Useful for testing UI without real data
```

### Delete Mock Data (`delete_mock_data.py` / `delete_mock_data.R`)

Removes mock/test data from database. Use before going to production.

```bash
# Python version
python scripts/delete_mock_data.py

# Or R version
source("scripts/delete_mock_data.R")
```

---

## Troubleshooting

### "MOTHERDUCK_TOKEN not set"
Create a `.env` file with your token. Get a token from [MotherDuck](https://motherduck.com).

### "Database is locked"
Close any other applications using the database (e.g., the Shiny app, DBeaver).

### Cards missing from a set
Use `--by-set` flag. Color-based fetching misses some multi-color cards.

### API rate limiting
The script includes a 0.7s delay between requests. If you hit limits, wait a few minutes.

### Python not found
On Windows, use `py` instead of `python`:
```bash
py scripts/sync_cards.py --by-set
```
