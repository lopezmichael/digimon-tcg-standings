# Changelog

All notable changes to the DFW Digimon TCG Tournament Tracker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure with R, data, logs, db, and tests directories
- MIT License
- Database schema for MotherDuck (cloud DuckDB) with tables:
  - `stores` - Local game store information
  - `players` - Player profiles and identifiers
  - `deck_archetypes` - Community deck name reference
  - `archetype_cards` - Card-to-archetype mappings
  - `tournaments` - Tournament event records
  - `results` - Player tournament results
  - `ingestion_log` - Data import tracking
- Database views for common queries:
  - `player_standings` - Aggregated player statistics
  - `archetype_meta` - Deck archetype performance metrics
  - `store_activity` - Store tournament activity summary
- R database connection module (`R/db_connection.R`) with:
  - MotherDuck cloud connection support
  - Local DuckDB fallback for development
  - Schema initialization and validation
  - Ingestion logging utility
- Development logging framework:
  - `CHANGELOG.md` - Version history
  - `logs/dev_log.md` - Development decisions and notes
  - `data/archetype_changelog.md` - Archetype maintenance log

## [0.1.0] - 2026-01-25

### Added
- Project initialization
- PROJECT_PLAN.md technical specification
