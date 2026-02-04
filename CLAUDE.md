# DigiLab - Claude Code Context

This document provides context for Claude Code to quickly understand and contribute to this project.

## Project Overview

A regional tournament tracking application for the Dallas-Fort Worth Digimon Trading Card Game community. Track player performance, store activity, deck meta, and local tournament results.

**Live App:** https://digilab.cards/

## Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | R Shiny with bslib + atomtemplates |
| Database | DuckDB (local) / MotherDuck (cloud) |
| Charts | Highcharter |
| Maps | mapgl (Mapbox GL JS) |
| Tables | reactable |
| Card Data | DigimonCard.io API (cached locally) |
| Hosting | Posit Connect Cloud |

## Project Structure

```
digimon-tcg-standings/
├── app.R                    # Main Shiny application (thin wrapper, ~566 lines)
├── server/                  # Server logic modules
│   ├── shared-server.R      # Database, navigation, auth helpers
│   ├── public-dashboard-server.R  # Dashboard/Overview tab
│   ├── public-players-server.R    # Players tab
│   ├── public-meta-server.R       # Meta analysis tab
│   ├── public-tournaments-server.R # Tournaments tab
│   ├── public-stores-server.R     # Stores tab with map
│   ├── admin-results-server.R     # Tournament entry wizard
│   ├── admin-tournaments-server.R # Tournament management
│   ├── admin-decks-server.R       # Deck archetype CRUD
│   ├── admin-stores-server.R      # Store management
│   ├── admin-players-server.R     # Player management
│   └── admin-formats-server.R     # Format management
├── views/                   # UI components
│   ├── dashboard-ui.R       # Dashboard with charts and stats
│   ├── stores-ui.R          # Store directory with map
│   ├── players-ui.R         # Player standings
│   ├── meta-ui.R            # Meta analysis
│   ├── tournaments-ui.R     # Tournament history
│   ├── admin-results-ui.R   # Tournament entry form
│   ├── admin-decks-ui.R     # Deck archetype management
│   └── admin-stores-ui.R    # Store management
├── R/
│   ├── db_connection.R      # Database connection module
│   └── digimoncard_api.R    # DigimonCard.io API integration
├── scripts/                 # Python scripts for data sync
│   ├── sync_cards.py        # Sync cards from DigimonCard.io API
│   ├── sync_to_motherduck.py# Push local DB to cloud
│   └── sync_from_motherduck.py # Pull cloud DB to local
├── db/
│   └── schema.sql           # Database schema
├── docs/
│   ├── card-sync.md         # Card sync documentation
│   ├── plans/               # Design documents
│   └── solutions/           # Technical solutions & fixes
├── logs/
│   └── dev_log.md           # Development decisions log
├── data/
│   └── local.duckdb         # Local database (gitignored)
├── www/
│   └── custom.css           # Custom styles
├── _brand.yml               # Atom brand configuration
├── CHANGELOG.md             # Version history
├── ARCHITECTURE.md          # Technical architecture reference
└── ROADMAP.md               # Future features and milestones
```

## Architecture Reference

**Always consult `ARCHITECTURE.md` before:**
- Adding new reactive values
- Creating new server modules
- Modifying navigation or modal patterns

The architecture doc contains:
- Server module structure and naming conventions (`public-*`, `admin-*`)
- Complete reactive values reference (32 values across 6 categories)
- Navigation patterns (tab switching, sidebar sync)
- Modal patterns (Bootstrap vs Shiny modals)
- Database patterns (connection handling, refresh triggers)

## Outstanding TODO Items

### UI Polish (Current Priority)
- [x] ~~Fix menu bar "menu" text and white space issues~~ - Renamed to "Digimon TCG Tracker", added Digimon TCG logo to sidebar
- [x] ~~Comprehensive mobile view review and fixes~~ - Mobile UI polish complete (v0.13.0)
- [x] ~~Correct button alignment throughout the app~~ - Fixed filter/reset button alignment on all pages
- [x] ~~Improve header design and add Digimon TCG logo~~ - Header now has cards icon (placeholder), BETA badge, circuit line accent, and pulse animation
- [ ] Add links to GitHub repo and "Buy Me a Coffee"
- [x] ~~Replace individual chart spinners with app-wide loading screen~~ - Digital "Opening Digital Gate..." loading screen with themed messages
- [ ] Replace header cards icon with actual Digivice SVG icon (placeholder for now)

### From UI Refactor Design (docs/plans/2026-01-28-ui-refactor-design.md)
- [x] ~~Fix &times; delete button bug~~ - Uses icon("xmark") now
- [x] ~~Improve notification styling~~ - Custom notifications with icons and colors
- [x] ~~Desktop: Filter section single-row layouts~~ - All filter pages use layout_columns
- [x] ~~Desktop: Add Results page two-column + inline W/L/T~~ - Implemented
- [x] ~~Desktop: Duplicate Tournament modal buttons alignment~~ - Fixed with flexbox
- [x] ~~Desktop/Mobile: Sidebar "Menu" header simplification~~ - Removed "Menu", added Digimon TCG logo
- [x] ~~Desktop: Overview value boxes resizing~~ - Smaller titles, larger numbers/icons
- [x] ~~Desktop: Overview charts polish~~ - Removed x-axis labels, capped y-axis at 100%
- [x] ~~Desktop: Format auto-select~~ - Defaults to most recent format
- [x] ~~Desktop: Players page Rating column~~ - Added weighted rating calculation
- [x] ~~Desktop: Tournaments auto-sort~~ - Defaults to date descending
- [x] ~~Desktop: Overview value boxes with card backgrounds~~ - Redesigned with digital Digimon aesthetic (grid pattern, circuit accents, color-coded borders). See docs/plans/2026-01-30-value-box-redesign-design.md
- [x] ~~Desktop: Enter Tournament Details constrained width~~ - Tournament summary bar with digital styling
- [x] ~~Desktop: Manage Decks Card ID input width~~ - Info icon moved to label, search button properly aligned
- [x] ~~Mobile: Navigation menu height optimization~~ - Reduced header/content spacing via bslib class overrides
- [x] ~~Mobile: Overview 2x2 value box grid~~ - Implemented via bslib breakpoints()
- [x] ~~Mobile: Filter sections vertical stacking~~ - Dashboard 2-row, other pages 3-row layout
- [ ] Mobile: Table column prioritization (Future)
- [ ] Mobile: Enter Tournament center button (Future)
- [ ] Mobile: Add Results compact layout (Future)

### Desktop & Mobile Design - COMPLETE ✓
The UI design overhaul is now complete (v0.13.0). Key features implemented:

**Desktop (v0.12.0):**
- Digital Digimon aesthetic throughout (grid patterns, circuit accents, cyan glow effects)
- App-wide loading screen with "Opening Digital Gate..." sequence
- Digital empty states with scanner aesthetic
- Modal stat boxes with grid overlay and section headers
- Placement colors (gold/silver/bronze for 1st/2nd/3rd)
- Header with icon pulse animation, BETA badge, circuit line accent
- Online Tournament Organizers section with connection node animations
- Card search scanner effect with corner accents
- Map card with "Location Scanner" styling
- Title strip filter inputs with light backgrounds and native HTML selects

**Mobile (v0.13.0):**
- Responsive value boxes via bslib breakpoints() (full width → 2x2 → 4-column)
- Smart filter layouts: Dashboard 2-row, other pages 3-row (via CSS :has())
- Reduced header/content spacing targeting bslib-gap-spacing classes
- BETA badge hidden on mobile to prevent overlap
- App title shortened to "Digimon TCG Tracker"

**Next Phase: User experience & onboarding improvements**

### User Experience & Onboarding (Future)
- [ ] Tool introduction / onboarding flow for new users
- [ ] "About This Tool" section explaining what the tool is, how to use it, and geographic coverage
- [ ] Contextual help throughout the app (info icons, tooltips, or help text for each tab/feature)

### Multi-Region / Geography Expansion (Future)
Currently the tool is focused on the North Texas / DFW playerbase. Rethink how geography works to support broader adoption:
- [ ] Allow users from other regions/states to add their own results
- [ ] Region/geography selector for users to filter data to their area
- [ ] Consider how stores, players, and tournaments are scoped by region
- [ ] Think through data isolation vs. cross-region visibility (can a Houston player see DFW data?)
- [ ] User-defined regions or predefined metro areas?
- [ ] How does the map experience change with multiple regions?
- [ ] Regional leaderboards vs. global leaderboards
- [ ] Admin permissions per region (who can add data for which areas?)

### Rating System Implementation (Current Priority)
See `docs/plans/2026-02-01-rating-system-design.md` for full design document.

**Phase 1 - Core Implementation: COMPLETE**
- [x] ~~Implement Competitive Rating (Elo-style with implied results)~~ - `R/ratings.R`
- [x] ~~Implement Achievement Score (points-based)~~ - `R/ratings.R`
- [x] ~~Implement Store Rating (weighted blend)~~ - `R/ratings.R`
- [x] ~~Add ratings to Overview > Top Players table~~ - Rating + Achv columns
- [x] ~~Add Store Rating to Overview > Recent Tournaments table~~
- [x] ~~Add ratings to Players tab table~~ - Rating + Achv columns
- [x] ~~Add Store Rating to Stores tab table~~

**Phase 2 - UI/UX (Future Session):**
- [ ] Achievement Score decay - keep cumulative or add decay?
- [ ] UI display - separate tabs, combined player profile, or both?
- [ ] Separate leaderboards for each rating type?
- [ ] Badge visibility - public or private to player?
- [ ] Methodology explanation tab/page for users

### Future Features
- [ ] Limitless TCG API integration for online tournament data
- [ ] Matchup analysis (deck A vs deck B win rates)
- [ ] Discord bot for result reporting
- [ ] Expand to other Texas regions (Houston, Austin, San Antonio)
- [ ] One Piece TCG support (multi-game expansion)
- [ ] Community-submitted archetype suggestions with approval workflow
- [ ] Mobile-first data entry PWA
- [ ] Player profile views (detailed)
- [ ] Deck profile views (detailed)
- [ ] Date range filtering on dashboard

## Key Logs and Documentation

### Development Log
**Location:** `logs/dev_log.md`

Contains dated entries explaining development decisions, technical choices, and blockers. Always update this log when making significant technical decisions.

### Changelog
**Location:** `CHANGELOG.md`

Semantic versioning log of all features, fixes, and changes. Update when releasing new versions.

### Design Documents
**Location:** `docs/plans/`

Contains design documents for features before implementation. Current plans:
- `2026-02-01-rating-system-design.md` - Competitive Rating, Achievement Score, Store Rating methodology
- `2026-01-28-ui-refactor-design.md` - UI refactor and polish plan
- `2026-01-27-admin-enhancement-design.md` - Admin page enhancements
- `2026-01-27-card-cache-design.md` - Card caching solution
- `2026-01-27-tournament-deletion-design.md` - Tournament deletion feature

## Important Technical Notes

### Database Connection
- **Windows (local dev):** Uses `data/local.duckdb` file
- **Linux (Posit Connect):** Uses MotherDuck cloud
- Connection auto-detects environment via `connect_db()` in `R/db_connection.R`

### DuckDB Gotchas
1. **NULL values:** DuckDB bind parameters require `NA_character_` or `NA_real_`, not R's `NULL`
2. **JSON columns:** Use TEXT type (JSON extension unavailable on Windows mingw)
3. **Foreign keys:** DuckDB UPDATE = DELETE + INSERT internally, causing FK violations. We removed FK constraints and handle referential integrity at application level.

### Shiny selectInput Styling
- **Use `selectize = FALSE` for title strip dropdowns** - Native HTML selects are more consistently stylable
- Selectize.js dropdown options cannot be reliably styled with CSS (browser ignores most option styling)
- Native selects with light backgrounds (`rgba(255, 255, 255, 0.9)`) and dark text work best
- When using native selects, choice values should use `list()` with string values for consistency

### DigimonCard.io API
- API returns 403 on Posit Connect Cloud (blocks server IPs)
- Solution: Cards cached in `cards` table, synced via `scripts/sync_cards.py`
- Card images (CDN) work fine - only API endpoints blocked
- GitHub Actions runs monthly sync via `.github/workflows/sync-cards.yml`

### Environment Variables
Required in `.env` file (copy from `.env.example`):
```
MOTHERDUCK_TOKEN=your_motherduck_token_here
MAPBOX_ACCESS_TOKEN=your_mapbox_token_here
```

## Required Workflows

### Superpowers (REQUIRED)

**Always use superpowers for any non-trivial work.** This is not optional.

| Superpower | When to Use | Required? |
|------------|-------------|-----------|
| `brainstorming` | Before any new feature or creative work | Yes |
| `writing-plans` | Before implementing multi-step tasks | Yes |
| `subagent-driven-development` | When executing plans with independent tasks | Yes |
| `verification-before-completion` | Before claiming work is complete | Yes |
| `finishing-a-development-branch` | When ready to merge/PR | Yes |

### Standard Feature Workflow

```
1. User requests new feature
2. /brainstorming - Explore intent and requirements
3. /writing-plans - Create design doc in docs/plans/
4. Get user approval
5. Create feature branch (git checkout -b feature/feature-name)
6. /subagent-driven-development - Execute implementation
7. Commit regularly (small, logical commits)
8. /verification-before-completion - Verify everything works
9. /finishing-a-development-branch - Create PR for review
10. Merge to main after approval
```

### Git Workflow (REQUIRED)

**Feature branches:** All new features and non-trivial changes must be developed on feature branches, not directly on main.

```bash
# Create feature branch
git checkout -b feature/feature-name

# Or for refactors
git checkout -b refactor/refactor-name

# Or for fixes
git checkout -b fix/fix-name
```

**Commit regularly:** Make small, logical commits as you work. Don't wait until everything is done.

**Review before merge:** Feature branches require review before merging to main. Use PRs or get explicit user approval.

**v1.0 Release Strategy:** All new features from v0.19 onward should be developed in feature branches and NOT merged to main until v1.0 release. This keeps main stable with the current working version while new features are developed and tested.

**Exception:** Documentation-only changes, bug fixes, and minor config tweaks can go directly to main.

### Code Verification (REQUIRED)

Before committing, always verify code works:

**R Installation Path (Windows):**
```bash
# R is installed at:
"/c/Program Files/R/R-4.5.0/bin/Rscript.exe"

# Run syntax check
"/c/Program Files/R/R-4.5.0/bin/Rscript.exe" -e "source('app.R')"

# Run lintr (if available)
"/c/Program Files/R/R-4.5.0/bin/Rscript.exe" -e "lintr::lint('app.R')"
```

**Manual verification:** If R can't be run from bash, ask the user to:
1. Run `shiny::runApp()` and verify app loads
2. Test the specific feature/fix that was changed
3. Confirm no console errors

### Documentation Updates (REQUIRED)

Keep documentation in sync with code changes. Update these files regularly:

| File | When to Update |
|------|----------------|
| `CHANGELOG.md` | Every version release (features, fixes, changes) |
| `logs/dev_log.md` | Significant technical decisions, blockers, architecture changes |
| `ARCHITECTURE.md` | New reactive values, server modules, or patterns |
| `README.md` | New features, changed setup instructions, updated screenshots |
| `ROADMAP.md` | Completed milestones, new planned features |

**Guidelines:**
- Update `CHANGELOG.md` when releasing a new version (not every commit)
- Update `dev_log.md` for technical decisions worth remembering
- Update `README.md` when user-facing features change significantly
- Update `ARCHITECTURE.md` before adding new reactive values or modules
- Don't let documentation drift - if you change code, check if docs need updating

## Development Workflow

### Running Locally

1. Copy `.env.example` to `.env` and add your tokens
2. Initialize database: `source("scripts/init_database.R")`
3. Seed data: Run seed scripts in `scripts/`
4. Run app: `shiny::runApp()`

### Adding Mock Data for Testing

```r
source("scripts/seed_mock_data.R")
```

### Syncing Database

```bash
# Push local to MotherDuck
python scripts/sync_to_motherduck.py

# Pull MotherDuck to local
python scripts/sync_from_motherduck.py --yes
```

### Card Sync

```bash
# Regular update (fast - only new cards)
python scripts/sync_cards.py --by-set --incremental

# Full re-sync
python scripts/sync_cards.py --by-set
```

## Code Style Notes

- **UI refactoring:** Server logic is in `server/` files, UI in `views/` files
- **Tables:** Use `reactable` (not `tableOutput`)
- **Charts:** Use `highcharter` with `hc_theme_atom_switch()` for theming
- **Maps:** Use `atom_mapgl()` from atomtemplates
- **Layout:** Use `layout_columns` from bslib for consistent layouts

### CSS Guidelines

- **Location:** All custom styles in `www/custom.css`, brand config in `_brand.yml`
- **Organization:** CSS file has 45+ labeled sections - find the right section before adding
- **Prefer CSS classes over inline styles** - only use inline for JS visibility toggles or dynamic R values
- **Naming:** Component-based (`card-search-grid`), modifiers with `--` (`badge--success`)
- **Existing utilities:** `clickable-row`, `help-icon`, `deck-badge-{color}`, `place-1st/2nd/3rd`
- **Test both light/dark mode and mobile** when adding styles

See `ARCHITECTURE.md` > CSS Architecture for full documentation.

## Current Version

**v0.18.1** - Code Cleanup Refactor (reactive values documented, ARCHITECTURE.md created)

See `CHANGELOG.md` for full version history and `ROADMAP.md` for upcoming features.
