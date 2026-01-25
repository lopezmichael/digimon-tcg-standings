-- DFW Digimon TCG Tournament Tracker
-- Database Schema for MotherDuck (Cloud DuckDB)
-- Version: 1.0.0
-- Created: January 2026

-- =============================================================================
-- STORES TABLE
-- Tracks local game stores hosting Digimon TCG events in the DFW area
-- =============================================================================
CREATE TABLE IF NOT EXISTS stores (
    store_id INTEGER PRIMARY KEY,
    name VARCHAR NOT NULL,
    address VARCHAR,
    city VARCHAR NOT NULL,
    state VARCHAR DEFAULT 'TX',
    zip_code VARCHAR,
    latitude DECIMAL(9, 6),
    longitude DECIMAL(9, 6),
    schedule_info TEXT,  -- JSON stored as text
    tcgplus_store_id VARCHAR,
    website VARCHAR,
    phone VARCHAR,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- PLAYERS TABLE
-- Tracks players participating in local tournaments
-- =============================================================================
CREATE TABLE IF NOT EXISTS players (
    player_id INTEGER PRIMARY KEY,
    display_name VARCHAR NOT NULL,
    tcgplus_id VARCHAR,
    limitless_username VARCHAR,
    home_store_id INTEGER REFERENCES stores(store_id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for player lookups
CREATE INDEX IF NOT EXISTS idx_players_display_name ON players(display_name);
CREATE INDEX IF NOT EXISTS idx_players_tcgplus_id ON players(tcgplus_id);

-- =============================================================================
-- DECK ARCHETYPES TABLE
-- Reference table mapping community deck names to associated cards
-- =============================================================================
CREATE TABLE IF NOT EXISTS deck_archetypes (
    archetype_id INTEGER PRIMARY KEY,
    archetype_name VARCHAR NOT NULL UNIQUE,
    display_card_id VARCHAR,
    primary_color VARCHAR NOT NULL,
    secondary_color VARCHAR,
    playstyle_tags TEXT,  -- JSON array stored as text
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for archetype lookups
CREATE INDEX IF NOT EXISTS idx_archetypes_name ON deck_archetypes(archetype_name);
CREATE INDEX IF NOT EXISTS idx_archetypes_color ON deck_archetypes(primary_color);

-- =============================================================================
-- ARCHETYPE CARDS TABLE (Junction Table)
-- Links archetypes to their associated cards from DigimonCard.io
-- =============================================================================
CREATE TABLE IF NOT EXISTS archetype_cards (
    archetype_id INTEGER NOT NULL REFERENCES deck_archetypes(archetype_id),
    card_id VARCHAR NOT NULL,
    card_role VARCHAR NOT NULL,
    is_core BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (archetype_id, card_id)
);

-- Create index for card lookups (find decks using a specific card)
CREATE INDEX IF NOT EXISTS idx_archetype_cards_card_id ON archetype_cards(card_id);

-- =============================================================================
-- TOURNAMENTS TABLE
-- Tracks individual tournament events
-- =============================================================================
CREATE TABLE IF NOT EXISTS tournaments (
    tournament_id INTEGER PRIMARY KEY,
    store_id INTEGER NOT NULL REFERENCES stores(store_id),
    event_date DATE NOT NULL,
    event_type VARCHAR NOT NULL,
    format VARCHAR,
    player_count INTEGER,
    rounds INTEGER,
    limitless_id VARCHAR,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for tournament queries
CREATE INDEX IF NOT EXISTS idx_tournaments_store ON tournaments(store_id);
CREATE INDEX IF NOT EXISTS idx_tournaments_date ON tournaments(event_date);
CREATE INDEX IF NOT EXISTS idx_tournaments_type ON tournaments(event_type);

-- =============================================================================
-- RESULTS TABLE
-- Tracks player results for each tournament
-- =============================================================================
CREATE TABLE IF NOT EXISTS results (
    result_id INTEGER PRIMARY KEY,
    tournament_id INTEGER NOT NULL REFERENCES tournaments(tournament_id),
    player_id INTEGER NOT NULL REFERENCES players(player_id),
    archetype_id INTEGER REFERENCES deck_archetypes(archetype_id),
    placement INTEGER,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    ties INTEGER DEFAULT 0,
    decklist_json TEXT,  -- JSON stored as text
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tournament_id, player_id)
);

-- Create indexes for result queries
CREATE INDEX IF NOT EXISTS idx_results_tournament ON results(tournament_id);
CREATE INDEX IF NOT EXISTS idx_results_player ON results(player_id);
CREATE INDEX IF NOT EXISTS idx_results_archetype ON results(archetype_id);
CREATE INDEX IF NOT EXISTS idx_results_placement ON results(placement);

-- =============================================================================
-- DATA INGESTION LOG TABLE
-- Tracks API calls and data imports for debugging
-- =============================================================================
CREATE TABLE IF NOT EXISTS ingestion_log (
    log_id INTEGER PRIMARY KEY,
    source VARCHAR NOT NULL,
    action VARCHAR NOT NULL,
    status VARCHAR NOT NULL,
    records_affected INTEGER DEFAULT 0,
    error_message TEXT,
    metadata TEXT,  -- JSON stored as text
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- VIEWS FOR COMMON QUERIES
-- =============================================================================

-- Player standings with win rate
CREATE OR REPLACE VIEW player_standings AS
SELECT
    p.player_id,
    p.display_name,
    COUNT(DISTINCT r.tournament_id) AS tournaments_played,
    SUM(r.wins) AS total_wins,
    SUM(r.losses) AS total_losses,
    SUM(r.ties) AS total_ties,
    ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) AS win_rate,
    COUNT(CASE WHEN r.placement = 1 THEN 1 END) AS first_place_finishes,
    COUNT(CASE WHEN r.placement <= 4 THEN 1 END) AS top4_finishes
FROM players p
LEFT JOIN results r ON p.player_id = r.player_id
GROUP BY p.player_id, p.display_name;

-- Archetype meta breakdown
CREATE OR REPLACE VIEW archetype_meta AS
SELECT
    da.archetype_id,
    da.archetype_name,
    da.primary_color,
    da.display_card_id,
    COUNT(r.result_id) AS times_played,
    ROUND(AVG(r.placement), 2) AS avg_placement,
    COUNT(CASE WHEN r.placement = 1 THEN 1 END) AS tournament_wins,
    SUM(r.wins) AS total_match_wins,
    SUM(r.losses) AS total_match_losses,
    ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) AS win_rate
FROM deck_archetypes da
LEFT JOIN results r ON da.archetype_id = r.archetype_id
GROUP BY da.archetype_id, da.archetype_name, da.primary_color, da.display_card_id;

-- Store activity summary
CREATE OR REPLACE VIEW store_activity AS
SELECT
    s.store_id,
    s.name AS store_name,
    s.city,
    COUNT(DISTINCT t.tournament_id) AS total_tournaments,
    SUM(t.player_count) AS total_attendance,
    ROUND(AVG(t.player_count), 1) AS avg_attendance,
    MAX(t.event_date) AS last_event_date,
    MIN(t.event_date) AS first_event_date
FROM stores s
LEFT JOIN tournaments t ON s.store_id = t.store_id
GROUP BY s.store_id, s.name, s.city;
