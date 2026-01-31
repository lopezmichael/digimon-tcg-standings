# Changelog

All notable changes to the DFW Digimon TCG Tournament Tracker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

*No unreleased changes*

---

## [0.10.0] - 2026-01-30 - Digital Design Language Extension

### Added
- **Header Bar Enhancement**: Subtle grid pattern overlay (4% opacity), glowing circuit node in top-right corner, faint circuit line along right edge
- **Sidebar Circuit Theming**: Vertical circuit line along left edge of navigation, glowing cyan node on active nav item
- **Card Search Scanner Effect**: Digital grid overlay on card preview (scanner aesthetic), hover glow on search results, selection pulse animation
- **Page Title Strips**: Players, Meta, and Tournaments pages now use integrated title strips with filters (matching dashboard style)
- **Modal Header Theming**: Grid pattern and circuit node in modal headers, blue gradient background, styled close button
- **Feature Card Headers**: Charts/key data cards automatically get grid pattern + circuit node in header (using CSS :has() selector)

### Changed
- **Consistent Filter UI**: All pages now use title strip pattern with compact inline filters
- **Card Hover Effects**: Data cards show subtle cyan glow on hover
- **Design System**: Extended digital Digimon aesthetic from value boxes to entire app

### Technical
- Design language documented in `docs/plans/2026-01-30-design-language-extension-proposal.md`
- CSS organized with clear section headers for each component type
- Uses CSS custom properties for consistent glow colors

---

## [0.9.0] - 2026-01-30 - Digital Value Box Redesign

### Added
- **Digital Digimon Aesthetic**: Value boxes redesigned with grid pattern overlay and circuit/wireframe accents inspired by Digimon TCG card designs
- **Title Strip**: New integrated filter bar showing format context ("BT-19 Format · Locals") with compact dropdown controls
- **Hot Deck Metric**: New value box showing trending deck with biggest meta share increase (with fallback for insufficient data)
- **Meta Share Display**: Top Deck now shows percentage of meta alongside deck name
- **Color-Coded Borders**: Each value box has distinctive left border (orange, blue, red, green)

### Changed
- **Format-Filtered Stats**: Tournaments and Players counts now respect format/event type filters
- **Value Box Layout**: Custom CSS implementation replacing bslib value_box for full design control
- **Filter UI**: Replaced separate filter row with integrated title strip
- **Reset Button**: Now uses refresh icon instead of text button

### Fixed
- **Mobile Layout**: Value boxes display as 2x2 grid on mobile devices
- **Dark Mode**: Value boxes properly styled for dark theme
- **Responsive Title Strip**: Stacks controls on smaller screens

---

## [0.8.0] - 2026-01-30 - Desktop UI Polish

### Changed
- **App Rebranding**: Renamed to "Digimon Locals Meta Tracker" with egg icon in header
- **Sidebar Logo**: Added Digimon TCG logo to sidebar, removed "Menu" text
- **Value Boxes**: Smaller titles, larger numbers and icons for better visual hierarchy
- **Format Default**: Overview page now auto-selects the most recent format
- **Meta Default**: Meta Analysis now shows all decks by default (min entries = 0)

### Added
- **Player Rating Column**: Players page now displays weighted rating (win% + top 3 rate + attendance)
- **Tournament Sorting**: Tournament History auto-sorts by date descending

### Fixed
- **Filter Alignment**: Reset buttons and search inputs properly aligned on all filter bars
- **Chart Polish**: Removed redundant x-axis labels from color distribution, capped meta share y-axis at 100%
- **Value Box Overflow**: Long deck names now truncate properly in "Most Popular Deck" box

---

## [0.7.0] - 2026-01-28 - UI Refactor & Card Sync Improvements

### Added
- **GitHub Pages Hosting**: App now accessible via clean URL at `lopezmichael.github.io/digimon-tcg-standings`
- **Card Sync Improvements**: Enhanced `sync_cards.py` with new flags:
  - `--by-set`: Fetch by set/pack for comprehensive coverage (catches multi-color cards)
  - `--incremental`: Only sync new cards for faster updates
  - `--discover`: Detect new set prefixes from API
- **Cloud-to-Local Sync**: New `sync_from_motherduck.py` script to pull cloud database locally
- **GitHub Actions**: Automated monthly card sync with manual trigger options
- **Documentation**: Added `docs/card-sync.md` guide and `scripts/README.md`

### Changed
- **Server Modularization**: Split monolithic `app.R` into focused server modules:
  - `server/shared-server.R`: Database, navigation, auth helpers
  - `server/results-server.R`: Tournament entry wizard
  - `server/admin-decks-server.R`: Deck archetype CRUD
  - `server/admin-stores-server.R`: Store management
  - `server/admin-formats-server.R`: Format management
- **UI Layouts**: Standardized form layouts using `layout_columns` with consistent column widths
- **Input Width Fix**: Fixed Shiny input overflow caused by default `min-width: 300px`
- **Card Database**: Expanded from ~2,800 to 4,200+ cards with fixed ST deck format and promo packs

### Fixed
- ST-1 through ST-9 starter deck cards now sync correctly (API uses single-digit format)
- Multi-color cards no longer missed during sync (set-based fetching catches all)

---

## [0.6.0] - 2026-01-27 - Format Management

### Added
- **Format Management Admin UI**: Manage game formats/sets via admin interface
  - Add, edit, and delete formats
  - Fields: Set Code, Set Name, Display Name, Release Date, Sort Order, Active status
  - Referential integrity checks (blocks delete if tournaments use format)
  - Dynamic dropdown updates across app when formats change
- **Formats Database Table**: New `formats` table for storing set information
  - `format_id` (primary key): Set code like 'BT19', 'EX08'
  - `set_name`: Full name like 'Xros Encounter'
  - `display_name`: Combined display like 'BT19 (Xros Encounter)'
  - `release_date`: For sorting by newest
  - `sort_order`: Manual sort override
  - `is_active`: Toggle visibility in dropdowns
- **Database Migration Script**: `R/migrate_v0.6.0.R` for adding formats table and seeding data

### Changed
- Format dropdowns now load from database instead of hardcoded list
- Dashboard and tournament entry forms dynamically update when formats are modified

### Migration Required
Run `source("R/migrate_v0.6.0.R")` then `migrate_v0.6.0(con)` to add formats table and seed initial data.

---

## [0.5.0] - 2026-01-27 - Admin Pages Enhancement

### Added
- **Online Store Support**: Flag-based system for online tournament organizers
  - "Online store" checkbox in Manage Stores form
  - Conditional fields: physical stores show address, online stores show region
  - Online Tournament Organizers section on Stores page
- **Wizard-based Results Entry**: Replaced bulk paste mode with 2-step wizard
  - Step 1: Tournament Details (store, date, type, format, players, rounds)
  - Step 2: Add Results with real-time results table
  - Tournament summary bar showing current tournament info
  - Results count header (X/Y players entered)
- **Duplicate Tournament Detection**: Modal warning when creating tournament for same store/date
  - Options: View/Edit Existing, Create Anyway, or Cancel
- **Quick Add Forms**: Add new players and decks inline during result entry
  - "+ New Player" link opens inline form
  - "+ New Deck" link opens inline form with color selection
- **Delete Functionality**: Hard delete for stores and deck archetypes
  - Referential integrity checks (blocks delete if related records exist)
  - Modal confirmation dialogs
- **Multi-color Deck Support**: Checkbox for decks with 3+ colors
  - Pink "Multi" badge display in tables
- **Database Migration Script**: `R/migrate_v0.5.0.R` for schema updates

### Changed
- Manage Decks form reorganized: card preview on left, search on right
- Results entry now uses wizard flow instead of single-page form
- Removed bulk paste mode entirely (replaced by wizard)

### Fixed
- Bind parameter error: NULL values now use NA_character_ for DuckDB compatibility
- Search button alignment in card search using flexbox
- NULL/NA handling in nchar() checks throughout admin forms

### Database
- Added `is_online` column to stores table (BOOLEAN DEFAULT FALSE)
- Added `is_multi_color` column to deck_archetypes table (BOOLEAN DEFAULT FALSE)
- Updated `store_activity` view to include `is_online` column

### Migration Required
Run `source("R/migrate_v0.5.0.R")` then `migrate_v0.5.0(con)` to add new columns to existing database.

---

## [0.4.0] - 2026-01-27 - Admin Improvements & Deployment Prep

### Added
- Bulk tournament entry mode (paste multiple results at once)
- Quick-add deck feature in results entry (for missing archetypes)
- Edit functionality for stores and decks (click row to edit)
- Admin table pagination (default 20 rows, options: 10/20/50/100)
- Card search in Manage Decks with clickable image results
- shinyjs integration for dynamic UI updates

### Changed
- All admin inputs now use single-row layout (no side-by-side fields)
- Card search uses DigimonCard.io API `id` field (not `cardnumber`)
- Card images use `.webp` format for better browser support
- Search box and button alignment fixed with Bootstrap grid

### Fixed
- Card search images now display correctly (was broken due to wrong API field)
- Selected Card ID auto-fills when clicking search results

### Documentation
- Updated README with current features, tech stack, and deployment instructions
- Added MAPBOX_ACCESS_TOKEN to .env.example
- Updated package installation list to match actual dependencies

---

## [0.3.1] - 2026-01-27 - Profiles & Filters

### Added
- Player profile modal (stats, favorite decks, tournament history)
- Deck archetype profile modal (card image, top pilots, recent results)
- Tournament detail modal (full standings with deck badges)
- Search filters on Players page (by player name)
- Search filters on Meta page (by deck name)
- Filters on Tournaments page (store search, format, event type)
- Winner and Winning Deck columns in Tournaments table
- Store detail modal with recent tournaments and top players

### Changed
- Consistent two-row filter layout across all pages
- Stats in profile modals use evenly distributed flexbox
- Store modal includes winning deck name and decklist link
- Dynamic bubble sizing on store map based on tournament activity

---

## [0.3.0] - 2026-01-26 - Dashboard & Visualizations

### Added
- Most Popular Deck value box with card image
  - Replaces Stores value box
  - Shows deck thumbnail from DigimonCard.io
  - Respects all dashboard filters
- Weighted Player Rating system
  - Formula: (Win% x 0.5) + (Top 3 Rate x 30) + (Events Bonus up to 20)
  - Tooltip explains rating calculation
  - Rewards consistent performance, top finishes, and attendance
- Meta Share Over Time stacked area chart
  - Replaces Meta Breakdown table
  - Shows deck popularity trends by week
  - Decks with <5% share grouped as "Other Decks"
  - Color-coded by deck color
- Winner column in Recent Tournaments table
- 4-week rolling average line in Tournament Activity chart
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
- Dashboard visualizations with Highcharter
  - Top 4 Conversion Rate chart showing best performing decks (min. 2 entries)
  - Color Distribution bar chart counting both primary and secondary deck colors
  - Tournament Activity spline chart with weekly aggregation (dual-axis)
  - All charts respect store region filter, format filter, and dark mode
  - Uses atomtemplates `hc_theme_atom_switch()` for theming
- Comprehensive dashboard filtering system
  - Format filter: Filter by card set (BT19, EX08, BT18, etc.)
  - Event Type filter: Filter by tournament type (Locals, Evo Cup, Store Championship, etc.)
  - Date Range picker: Filter by custom date range
  - Reset Filters button: Clear all filters at once
  - All filters work together with store region filter from map
- Multi-color deck support
  - Dual-color decks (with secondary_color) shown as "Multi" in pink (#EC4899)
  - Color Distribution chart groups dual-color decks together
  - Added deck-badge-multi-color CSS class
- Top Decks display with card images
  - Shows top 8 deck archetypes with card thumbnails from DigimonCard.io
  - Horizontal progress bars color-coded by deck color
  - Responsive grid layout with dark mode support
- Format/set tracking for tournaments
  - Dropdown for selecting game format (BT19, EX08, etc.)
  - Stored in tournaments table
- Mock data seed scripts for testing
  - `R/seed_mock_data.R` - Creates 25 players, 20 tournaments, ~240 results
  - Proper format values (BT19, EX08, BT18, BT17, EX07, older)
  - Varied event types (locals, evo_cup, store_championship)
  - 4 months of date range with realistic distribution
  - `R/delete_mock_data.R` - Removes all mock data for real data collection
- Database migration script (`R/migrate_db.R`)
  - Adds decklist_url column to results table
  - Adds format column to tournaments table

### Changed
- Dashboard filter defaults now set to first format (BT19) and Locals
  - Future-proofed: always uses first item in FORMAT_CHOICES
- Top Decks section now shows win rate % instead of entry count
  - Minimum 2 entries required to appear
  - Sorted by win rate descending
- Top 3 Conversion Rate chart (changed from Top 4)
  - Shows top 5 decks for better visibility
- Tournament Activity chart now shows average players per event
  - Added 4-week rolling average trend line
  - Removed tournament count (redundant with value box)
- All Highcharts removed inline titles (titles now in card headers only)
- Recent Tournaments table improvements
  - Added Winner column (player with placement = 1)
  - Event type formatted nicely (e.g., "Evo Cup" instead of "evo_cup")
- Top Players table now sorted by weighted rating
  - Shows 1st place finishes column
  - Rating column with hover tooltip explaining formula
- Enhanced database views with additional metrics
  - `player_standings`: added favorite_deck, avg_placement
  - `archetype_meta`: added secondary_color, conversion_rate, top4_rate
  - `store_activity`: added latitude, longitude, unique_players
- Store management form no longer requires manual lat/lng entry

### Dependencies Added
- `mapgl` - Mapbox GL JS for interactive maps
- `sf` - Simple Features for spatial operations
- `tidygeocoder` - Address geocoding
- `highcharter` - Highcharts for R (interactive charts)

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
