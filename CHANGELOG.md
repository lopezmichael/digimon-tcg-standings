# Changelog

All notable changes to the DFW Digimon TCG Tournament Tracker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Interactive store map with MapGL integration
  - Atom-branded basemap via `atom_mapgl()` from atomtemplates
  - Uses "minimal" theme for consistent appearance in both light/dark app modes
  - Store markers with orange circles (#F7941D) and white stroke
  - Rich popups showing store details (name, city, address, schedule)
  - Light-themed popups for consistent readability
- Draw-to-filter region selection
  - Freehand polygon drawing for geographic filtering
  - Store list filters based on drawn region
  - Dashboard data (tournaments, players, meta) filters by selected stores
  - Visual filter indicator banner when region is active
  - "Clear Region" buttons on Stores and Dashboard pages
- Decklist URL field in tournament results entry form
- Auto-geocoding for stores using tidygeocoder
  - Addresses automatically geocoded when stores are added
  - Uses OpenStreetMap Nominatim API

### Changed
- Enhanced database views with additional metrics
  - `player_standings`: added favorite_deck, avg_placement
  - `archetype_meta`: added secondary_color, conversion_rate, top4_rate
  - `store_activity`: added latitude, longitude, unique_players
- Store management form no longer requires manual lat/lng entry

### Dependencies Added
- `mapgl` - Mapbox GL JS for interactive maps
- `sf` - Simple Features for spatial operations
- `tidygeocoder` - Address geocoding

---

## [0.3.0] - 2026-01-26 - UI Refresh

### Added
- Views folder structure for modular UI organization
  - `views/dashboard-ui.R` - Dashboard with value boxes
  - `views/stores-ui.R` - Store directory
  - `views/players-ui.R` - Player standings
  - `views/meta-ui.R` - Meta analysis
  - `views/tournaments-ui.R` - Tournament history
  - `views/admin-results-ui.R` - Tournament entry form
  - `views/admin-decks-ui.R` - Deck archetype management
  - `views/admin-stores-ui.R` - Store management
- Digimon-themed brand configuration (`_brand.yml`)
  - Primary: Deep Digimon Blue (#0F4C81)
  - Secondary: Digimon Orange (#F7941D)
  - TCG deck colors for data visualization
  - Sequential/diverging palettes for charts
  - Typography (Poppins, Inter, Fira Code via Google Fonts)
- Custom CSS styling (`www/custom.css`)
  - Header bar with gradient and full-bleed design
  - Sidebar navigation with active state management
  - Responsive value boxes with fluid typography
  - Card styling with hover effects
  - Dark mode support with cohesive color scheme
  - Deck color badge utilities
- Sidebar + Header layout (modern dashboard pattern)
  - Full-bleed header with branding and actions
  - Collapsible sidebar navigation
  - Dark mode toggle in header
  - Admin login button in header

### Changed
- Refactored UI from shinydashboard to bslib + atomtemplates
  - `dashboardPage()` → `page_fillable()` with `layout_sidebar()`
  - Applied `atom_dashboard_theme()` for consistent theming
- Replaced all `tableOutput()` with `reactableOutput()` for better tables
- Migrated to `bslib` layout components (`layout_columns`, `card`, `value_box`)
- Value boxes use all-blue gradient theme for visual cohesion
- Added Bootstrap icons via `bsicons` package

### Dependencies Added
- `bslib` - Bootstrap theming framework
- `bsicons` - Bootstrap icons
- `reactable` - Interactive tables
- `atomtemplates` - Atom design system
- `sysfonts` - Google Fonts loading
- `showtext` - Font rendering

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
