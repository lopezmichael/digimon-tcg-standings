# Scripts

Utility scripts for database setup, synchronization, and maintenance.

## Setup Scripts (New Users)

Run these in order for fresh setup:

```r
# 1. Initialize database schema
source("scripts/init_database.R")

# 2. Seed store data
source("scripts/seed_stores.R")

# 3. Seed deck archetypes
source("scripts/seed_archetypes.R")
```

## Sync Scripts

### Card Sync (`sync_cards.py`)

Sync card data from DigimonCard.io API. See [docs/card-sync.md](../docs/card-sync.md) for full documentation.

```bash
# Regular update (fast)
python scripts/sync_cards.py --by-set --incremental

# Full sync
python scripts/sync_cards.py --by-set

# Check for new sets
python scripts/sync_cards.py --discover
```

### Database Sync

```bash
# Push local database to MotherDuck cloud
python scripts/sync_to_motherduck.py

# Pull cloud database to local
python scripts/sync_from_motherduck.py --yes
```

## Optional Scripts

| Script | Purpose |
|--------|---------|
| `seed_mock_data.R` | Generate fake tournament data for testing |
| `delete_mock_data.py` | Remove mock data from database |
| `delete_mock_data.R` | R version of mock data cleanup |

## Migration Scripts (Legacy)

These were used for one-time database migrations and are not needed for new installs:

- `migrate_v0.5.0.py/.R` - Added wizard flow fields
- `migrate_v0.6.0.R` - Added formats table
- `migrate_cards.py` - Initial card table setup
- `migrate_drop_fk.py` - Removed FK constraints (DuckDB fix)
- `migrate_db.R` - General migration utilities

## Prerequisites

Python scripts require:
```bash
pip install duckdb python-dotenv requests
```
