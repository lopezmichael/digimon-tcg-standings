-- =============================================================================
-- Migration 002: Limitless TCG Integration
-- Date: 2026-02-19
-- Description: Adds schema support for Limitless TCG API integration
--
-- Changes:
--   1. Add limitless_organizer_id column to stores table
--   2. Create limitless_deck_map table
--   3. Create limitless_sync_state table
--   4. Add index on stores.limitless_organizer_id
--
-- Notes:
--   - DuckDB does not support ALTER TABLE ... ADD COLUMN IF NOT EXISTS.
--     The ALTER TABLE statement below will fail if the column already exists.
--     This is safe to ignore if re-running the migration on an already-migrated DB.
--   - CREATE TABLE IF NOT EXISTS and CREATE INDEX IF NOT EXISTS are idempotent.
-- =============================================================================

-- 1. Add limitless_organizer_id to stores table
-- NOTE: Will error if column already exists. Safe to ignore that error.
ALTER TABLE stores ADD COLUMN limitless_organizer_id INTEGER;

-- 2. Create index for Limitless organizer lookups
CREATE INDEX IF NOT EXISTS idx_stores_limitless ON stores(limitless_organizer_id);

-- 3. Create Limitless deck mapping table
CREATE TABLE IF NOT EXISTS limitless_deck_map (
    limitless_deck_id VARCHAR NOT NULL PRIMARY KEY,  -- e.g., "imperialdramon"
    limitless_deck_name VARCHAR,                     -- Human-readable name from Limitless
    archetype_id INTEGER                             -- References deck_archetypes(archetype_id)
);

-- 4. Create Limitless sync state table
CREATE TABLE IF NOT EXISTS limitless_sync_state (
    organizer_id INTEGER NOT NULL PRIMARY KEY,       -- Limitless organizer ID
    last_synced_at TIMESTAMP,                        -- When sync last ran
    last_tournament_date TIMESTAMP,                  -- Most recent tournament date synced
    tournaments_synced INTEGER DEFAULT 0             -- Total tournaments imported
);
