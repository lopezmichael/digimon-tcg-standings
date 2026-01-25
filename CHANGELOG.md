# Changelog

All notable changes to the DFW Digimon TCG Tournament Tracker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

*No unreleased changes*

## [0.2.0] - 2026-01-25

### Added
- Project structure (R/, db/, logs/, data/, scripts/, tests/)
- MIT License
- Database schema for DuckDB with 6 tables + 3 views
  - Tables: `stores`, `players`, `deck_archetypes`, `archetype_cards`, `tournaments`, `results`, `ingestion_log`
  - Views: `player_standings`, `archetype_meta`, `store_activity`
- Database connection module (`R/db_connection.R`)
  - Auto-detecting `connect_db()` for local/MotherDuck environments
  - Local DuckDB for Windows development
  - MotherDuck support for Linux/Posit Connect deployment
- DigimonCard.io API integration (`R/digimoncard_api.R`)
  - Card search by name, number, color, type
  - Card image URL generation
  - Built-in rate limiting (15 req/10 sec)
- Seed data scripts
  - 13 DFW stores with addresses, coordinates, and Digimon event schedules
  - 25 deck archetypes with display cards for BT23/BT24 meta
- Logging framework
  - `CHANGELOG.md` - Version history
  - `logs/dev_log.md` - Development decisions
  - `data/archetype_changelog.md` - Archetype maintenance
- Python sync script for MotherDuck deployment (`scripts/sync_to_motherduck.py`)

### Technical Notes
- JSON columns use TEXT type (DuckDB JSON extension unavailable on Windows mingw)
- MotherDuck extension unavailable on Windows R; use local DuckDB for dev

## [0.1.0] - 2026-01-25

### Added
- Project initialization
- PROJECT_PLAN.md technical specification
