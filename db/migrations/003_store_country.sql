-- =============================================================================
-- Migration 003: Store Country Column
-- Date: 2026-02-20
-- Description: Adds country column for international stores and online organizers
--
-- Changes:
--   1. Add country column to stores table (default 'USA')
--   2. Update existing online stores with correct country values
-- =============================================================================

-- 1. Add country column to stores table
-- NOTE: Will error if column already exists. Safe to ignore that error.
ALTER TABLE stores ADD COLUMN country VARCHAR DEFAULT 'USA';

-- 2. Update existing online stores with country data
-- Eagle's Nest (USA)
UPDATE stores SET country = 'USA' WHERE limitless_organizer_id = 452;
-- DMV Drakes (USA)
UPDATE stores SET country = 'USA' WHERE limitless_organizer_id = 559;
-- PHOENIX REBORN (Argentina)
UPDATE stores SET country = 'Argentina' WHERE limitless_organizer_id = 281;
-- MasterRukasu (Brazil)
UPDATE stores SET country = 'Brazil' WHERE limitless_organizer_id = 578;
