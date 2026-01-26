# Development Log

This log tracks development decisions, blockers, and technical notes for the DFW Digimon TCG Tournament Tracker project.

---

## 2026-01-25: Phase 1 Kickoff - Project Foundation

### Completed
- [x] Created project directory structure (R/, data/, logs/, db/, tests/)
- [x] Added MIT License
- [x] Designed and created database schema for MotherDuck/DuckDB
- [x] Created R database connection module with MotherDuck support
- [x] Set up logging framework (CHANGELOG.md, dev_log.md, archetype_changelog.md)

### Technical Decisions

**Database Choice: MotherDuck (Cloud DuckDB)**
- Rationale: Serverless, fast OLAP queries, excellent R integration via duckdb package
- MotherDuck provides cloud hosting with generous free tier
- Falls back to local DuckDB file for offline development
- Connection uses token-based auth via environment variable

**Schema Design Notes**
- Added `ingestion_log` table for tracking API calls and data imports
- Created views for common dashboard queries (player standings, archetype meta, store activity)
- Junction table `archetype_cards` enables "find decks using card X" feature
- All tables include `created_at` and `updated_at` timestamps

**Environment Configuration**
- MotherDuck token stored in `.env` file (gitignored)
- Database name configurable via `MOTHERDUCK_DATABASE` env var
- Default database name: `digimon_tcg_dfw`

### Next Steps
- [ ] Populate initial DFW store data
- [ ] Build DigimonCard.io API integration
- [ ] Create initial deck archetype reference data
- [ ] Build Shiny data entry forms

---

## 2026-01-25: Database Connection Strategy

### Issue Encountered
MotherDuck extension not available for Windows mingw DuckDB R package (HTTP 404 when installing extension).

### Solution: Dual-Mode Connection
Implemented auto-detecting `connect_db()` function:
- **Windows (local dev)**: Uses `data/local.duckdb` file
- **Linux (Posit Connect)**: Uses MotherDuck cloud

### Rationale
- Posit Connect Cloud runs on Linux where MotherDuck works
- Local development works identically (same DuckDB SQL)
- Python sync script (`scripts/sync_to_motherduck.py`) provided for deployment

### Workflow
```
Local Dev (Windows)     →    Deploy (Posit Connect)
─────────────────────        ────────────────────────
R + local.duckdb             R + MotherDuck
                    ↘      ↗
               Python sync script
               (one-time before deploy)
```

---

## 2026-01-25: Data Entry Architecture Decision

### Decision: Option A - Production Entry
All real data entry happens in production (MotherDuck via Posit Connect app).

**Data Flow:**
```
┌─────────────────────────────────────────────────────────────────┐
│  DEVELOPMENT                    │  PRODUCTION                   │
├─────────────────────────────────┼───────────────────────────────┤
│  local.duckdb                   │  MotherDuck                   │
│  - Test/sample data             │  - Real tournament data       │
│  - Schema development           │  - Entered via Shiny forms    │
│  - Seed scripts for testing     │  - Source of truth            │
└─────────────────────────────────┴───────────────────────────────┘
```

**Reference Data** (stores, archetypes):
- Managed via seed scripts (version controlled)
- Run in production when stores/archetypes need updates

**Transactional Data** (tournaments, results, players):
- Entered via Shiny app forms
- Written directly to MotherDuck

### Future Consideration: Screenshot Parsing
**Idea:** Allow users to upload screenshots of tournament standings (from Bandai TCG+ app) and parse them automatically using OCR/AI.

**Status:** Noted for potential future enhancement. May be too complex for initial scope.

**If implemented, would involve:**
- Image upload in Shiny
- OCR service (Google Vision, AWS Textract, or local tesseract)
- Parsing logic to extract player names, placements, records
- Review/confirmation UI before saving

**Complexity concerns:**
- Variable screenshot formats
- OCR accuracy on phone photos
- Cost of cloud OCR services
- Edge cases (ties, drops, etc.)

Parking this for now - revisit after core app is functional.

---

## 2026-01-25: Windows DuckDB Extension Limitations

### Issue
Windows mingw DuckDB R package cannot auto-install extensions (JSON, MotherDuck).
Error: `Extension "json" not found` when creating tables with JSON columns.

### Solution
Replaced all `JSON` column types with `TEXT` in schema.
- `stores.schedule_info` → TEXT
- `deck_archetypes.playstyle_tags` → TEXT
- `results.decklist_json` → TEXT
- `ingestion_log.metadata` → TEXT

Use `jsonlite::toJSON()` / `jsonlite::fromJSON()` in R for serialization.

### Result
Schema initialization now succeeds on Windows. All 6 tables + 3 views created.

---

## 2026-01-25: Phase 1 Complete

### Completed Tasks
- [x] Project structure setup
- [x] MIT License
- [x] Database schema (6 tables, 3 views)
- [x] Database connection module (auto-detect local/cloud)
- [x] DigimonCard.io API integration with image URLs
- [x] Seed 13 DFW stores
- [x] Seed 25 deck archetypes (BT23/BT24 meta)
- [x] Logging framework
- [x] Git commit and push

### DFW Stores Seeded
1. Common Ground Games (Dallas) - Fri/Sat
2. Cloud Collectibles (Garland) - Fri
3. The Card Haven (Lewisville) - Wed
4. Game Nerdz Mesquite - Sun
5. Andyseous Odyssey (Dallas) - Wed
6. Boardwalk Games (Carrollton) - Thu
7. Lone Star Pack Breaks (Carrollton) - Tue
8. Game Nerdz Allen - Sun
9. Game Nerdz Wylie - Mon
10. Eclipse Cards and Hobby (N. Richland Hills) - Mon
11. Evolution Games (Fort Worth) - Tue
12. Primal Cards & Collectables (Fort Worth) - Fri
13. Tony's DTX Cards (Dallas) - Wed

### Archetypes Seeded (25)
Top tier: Hudiemon, Mastemon, Machinedramon, Royal Knights, Gallantmon
Strong: Beelzemon, Fenriloogamon, Imperialdramon, Blue Flare, MagnaGarurumon
Established: Jesmon, Leviamon, Bloomlordmon, Xros Heart, Miragegaogamon
Competitive: Belphemon, Sakuyamon, Numemon, Chronicle, Omnimon
Rogue: Dark Animals, Dark Masters, Eater, Blue Hybrid, Purple Hybrid

### Next Phase
Phase 2: Data Collection
- Shiny form for tournament entry
- Archetype dropdown with card image preview
- Historical data collection from past 2-3 months

---

## 2026-01-25: Phase 2 - UI Refactoring with atomtemplates

### Completed
- [x] Created views folder structure for modular UI organization
- [x] Added `_brand.yml` Atom brand configuration
- [x] Created `www/custom.css` with responsive styling
- [x] Broke up monolithic app.R into 8 view files
- [x] Refactored from shinydashboard to bslib + atomtemplates
- [x] Replaced tableOutput with reactable for better tables
- [x] Added dark mode toggle support

### Technical Decisions

**UI Framework: bslib + atomtemplates**
- Migrated from shinydashboard to bslib's `page_navbar()`
- Using `atom_dashboard_theme()` for consistent Atom design system
- Enables dark mode support via `input_dark_mode()`
- Better Bootstrap 5 integration and modern responsive design

**Views Folder Structure**
Following Atom Shiny best practices:
```
views/
├── dashboard-ui.R      # Dashboard with value boxes
├── stores-ui.R         # Store directory
├── players-ui.R        # Player standings
├── meta-ui.R           # Meta analysis
├── tournaments-ui.R    # Tournament history
├── admin-results-ui.R  # Tournament entry form
├── admin-decks-ui.R    # Deck archetype management
└── admin-stores-ui.R   # Store management
```

**Styling Architecture**
- `_brand.yml`: Atom color palettes, typography (Poppins, Inter, Fira Code), Bootstrap defaults
- `www/custom.css`: Responsive value boxes, card styling, admin panels, dark mode overrides
- Uses `clamp()` for fluid typography scaling
- Mobile-friendly breakpoints

**Table Rendering: reactable**
- Replaced all `tableOutput()` with `reactableOutput()`
- Better pagination, sorting, and styling
- Consistent compact/striped styling across app

### Files Created
| File | Purpose |
|------|---------|
| `_brand.yml` | Atom brand colors, fonts, Bootstrap config |
| `www/custom.css` | Responsive CSS overrides (150+ lines) |
| `views/*.R` | 8 modular UI view files |

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Complete refactor: shinydashboard → bslib, tableOutput → reactable, source views |

### Dependencies Added
- `bslib` - Bootstrap theming
- `bsicons` - Bootstrap icons
- `reactable` - Interactive tables
- `atomtemplates` - Atom design system
- `sysfonts` - Google Fonts support
- `showtext` - Font rendering

### Next Steps
- [x] Customize Atom styling for Digimon theme (colors, branding)
- [ ] Add loading spinners/overlays
- [ ] Enhance reactable tables with color-coded columns
- [ ] Add store map visualization

---

## 2026-01-26: Digimon Theme Customization

### Completed
- [x] Created Digimon-branded color palette (blue/orange from logo)
- [x] Updated `_brand.yml` with full Digimon color system
- [x] Added TCG deck colors for future data visualization
- [x] Updated `custom.css` with Digimon accent colors
- [x] Added deck color badge utilities for reactable tables

### Technical Decisions

**Color Palette: Digimon Logo Inspired**
- Primary: Deep Digimon Blue (#0F4C81)
- Secondary/Accent: Digimon Orange (#F7941D)
- Navy variant for headers (#0A3055)
- Amber variant for deeper orange (#E8842C)

**TCG Deck Colors**
Added all 7 deck colors for future meta analysis visualizations:
- Red (#DC2626) - Agumon/aggressive decks
- Blue (#2563EB) - Gabumon/control decks
- Yellow (#EAB308) - Patamon/holy decks
- Green (#16A34A) - Palmon/nature decks
- Black (#1F2937) - Virus/dark decks
- Purple (#7C3AED) - Impmon/death decks
- White (#E5E7EB) - Colorless/option cards

**CSS Enhancements**
- Orange hover states for links and buttons
- Blue/orange focus rings on form inputs
- Deck color utility classes (.deck-red, .deck-blue, etc.)
- Deck badge styles for table cells (.deck-badge-red, etc.)

### Files Modified
| File | Changes |
|------|---------|
| `_brand.yml` | Complete Digimon color palette, sequential/diverging scales |
| `www/custom.css` | Digimon accents, deck color utilities |

### Next Steps
- [ ] Add loading spinners/overlays
- [ ] Enhance reactable tables with deck color badges
- [ ] Add store map visualization

---

## 2026-01-26: Layout Refactor - Sidebar + Header

### Completed
- [x] Refactored from `page_navbar()` to `page_fillable()` with sidebar
- [x] Created custom header bar with branding and user actions
- [x] Built sidebar navigation with section labels
- [x] Updated value boxes to all-blue gradient theme
- [x] Added new CSS for header and sidebar components
- [x] Moved admin login button to header (fixed positioning issue)

### Technical Decisions

**Layout: Sidebar + Header Pattern**
- Header bar: Fixed at top with logo, title, admin login, dark mode toggle
- Sidebar: Dark navy (#0A3055) with navigation links
- Main content: Uses `navset_hidden()` for page switching
- More modern dashboard aesthetic than horizontal navbar

**Value Box Colors: All-Blue Gradient**
- Tournaments: #0A3055 (darkest - navy)
- Players: #0F4C81 (primary Digimon blue)
- Stores: #1565A8 (medium blue)
- Deck Types: #2A7AB8 (lightest blue)
- Creates visual cohesion with sidebar

**Navigation Architecture**
- `actionLink()` buttons in sidebar trigger `nav_select()`
- `navset_hidden()` contains all page content
- Admin section conditionally shown via `conditionalPanel()`
- Orange (#F7941D) highlight for active nav item

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Complete UI restructure: page_fillable, layout_sidebar, navset_hidden |
| `views/dashboard-ui.R` | Value boxes now use value_box_theme() with blue gradient |
| `www/custom.css` | Added header bar, sidebar nav, and responsive styles |

### Next Steps
- [ ] Add loading spinners/overlays
- [ ] Enhance reactable tables with deck color badges
- [ ] Add store map visualization

---

## 2026-01-26: UI Polish and Dark Mode Improvements

### Completed
- [x] Renamed app title from "DFW Digimon TCG" to "Digimon TCG"
- [x] Fixed header to be single-row with proper text wrapping
- [x] Made header full-bleed (spans entire page width)
- [x] Fixed header icon to be white and properly sized
- [x] Added JavaScript for sidebar active state management
- [x] Replaced "Dashboard" section label with "Navigation" sidebar title
- [x] Improved dark mode color scheme for header and sidebar

### Technical Decisions

**Header Improvements**
- Added `white-space: nowrap` and `flex-wrap: nowrap` to prevent text wrapping
- Set `min-height: 48px` and `max-height: 56px` for consistent sizing
- Full-bleed margins (`margin: -1rem`) for edge-to-edge appearance

**Active Navigation State**
- Added jQuery click handler to toggle `.active` class on nav items
- Orange highlight (#F7941D) follows user selection
- Works across all navigation items including admin section

**Dark Mode Color Scheme**
- Header: Dark gray gradient (#1A202C → #2D3748) instead of blue
- Sidebar: Matching dark gray (#1A202C) for cohesion
- Maintains orange accent for active states
- Better contrast and visual harmony with dark page background

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Title rename, icon styling, sidebar title, JS for active state |
| `www/custom.css` | Header full-bleed, icon class, dark mode styles |

### Next Steps
- [ ] Add loading spinners/overlays
- [ ] Enhance reactable tables with deck color badges
- [ ] Add store map visualization

---

*Template for future entries:*

```
## YYYY-MM-DD: Brief Description

### Completed
- [x] Task 1
- [x] Task 2

### Technical Decisions
**Decision Title**
- Rationale and context

### Blockers
- Any issues encountered

### Next Steps
- [ ] Upcoming tasks
```
