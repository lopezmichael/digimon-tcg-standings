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
- [x] Add loading spinners/overlays
- [ ] Enhance reactable tables with color-coded columns
- [x] Add store map visualization

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
- [x] Add loading spinners/overlays
- [x] Enhance reactable tables with deck color badges
- [x] Add store map visualization

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
- [x] Add loading spinners/overlays
- [x] Enhance reactable tables with deck color badges
- [x] Add store map visualization

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
- [x] Add loading spinners/overlays
- [x] Enhance reactable tables with deck color badges
- [x] Add store map visualization

---

## 2026-01-26: MapGL Integration with Draw-to-Filter

### Completed
- [x] Added `mapgl` and `sf` packages for interactive mapping
- [x] Integrated atomtemplates `atom_mapgl()` for Atom-branded basemaps
- [x] Created interactive store map on Stores page
- [x] Added freehand polygon draw controls for region selection
- [x] Implemented draw-to-filter: stores list filters based on drawn region
- [x] Connected region filter to dashboard - Recent Tournaments, Top Players, and Meta Breakdown all filter by selected stores
- [x] Added visual filter indicator on dashboard when region is active
- [x] Added "Clear Region" buttons on both Stores and Dashboard pages
- [x] Styled draw controls and popups with Digimon theme colors
- [x] Added Mapbox token handling (MAPBOX_ACCESS_TOKEN from .env)

### Technical Decisions

**MapGL with atomtemplates Integration**
- Using `atom_mapgl(theme = "light"|"dark")` for branded basemap styles
- Using `add_atom_popup_style()` for consistent popup theming
- Using `atom_popup_html_metrics()` for rich store popup content
- Token automatically loaded from .env file and aliased to MAPBOX_PUBLIC_TOKEN

**Draw-to-Filter Architecture**
- `add_draw_control()` with freehand polygon drawing enabled
- `get_drawn_features()` returns drawn polygons as sf object
- `st_filter()` used to find stores within drawn region
- `rv$selected_store_ids` reactive value propagates filter to all views
- Dashboard queries dynamically include store filter when active

**Map Features**
- Store markers: Orange circles (#F7941D) with white stroke
- Popups: Show store name, city, address, and schedule info
- Auto-fits bounds to show all stores
- Respects dark mode toggle for map theme

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Added mapgl/sf libraries, store map rendering, draw-to-filter logic, dashboard filtering |
| `views/stores-ui.R` | Added map card with draw controls, filter badge |
| `views/dashboard-ui.R` | Added region filter indicator |
| `www/custom.css` | Added mapgl draw control styling |

### Dependencies Added
- `mapgl` - Mapbox GL JS for R
- `sf` - Simple Features for spatial operations

### Next Steps
- [x] Enhanced dashboard visualizations (charts for meta share, trends)
- [ ] Player profile views
- [ ] Deck profile views
- [ ] Date range filtering

---

## 2026-01-26: MapGL Theme and Marker Refinements

### Completed
- [x] Switched to "minimal" basemap theme for consistent appearance in both light/dark app modes
- [x] Fixed popup theme to always use "light" for readability
- [x] Reverted from symbol markers to circle markers for better cross-theme visibility
- [x] Fixed all `set_paint_property` calls to use `circle-color`/`circle-opacity` instead of `icon-*`
- [x] Styled draw control buttons (white with blue border, orange active state)

### Technical Decisions

**Basemap Theme: "minimal" for All Modes**
- Previously tried switching between "light" and "dark" themes based on app dark mode
- Symbol markers with `icon_emissive_strength` only visible in dark mode
- Circle markers lack `emissive_strength` support in mapgl
- Solution: Use "minimal" theme which provides neutral appearance in both modes
- Popups always use "light" theme for consistent readability

**Circle vs Symbol Markers**
- Attempted symbol markers (`add_symbol_layer`) for emissive strength support
- Symbols only rendered in dark mode, invisible in light mode
- Reverted to `add_circle_layer` with orange circles (#F7941D) and white stroke
- Circles visible in both modes, acceptable tradeoff vs 3D lighting effects

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Updated all `atom_mapgl()` to use `theme = "minimal"`, popups use `theme = "light"`, reverted to circle layer, fixed paint property names |
| `www/custom.css` | Draw control button styling (white bg, blue border, orange active) |

### Next Steps
- [x] Enhanced dashboard visualizations (charts for meta share, trends)
- [ ] Player profile views
- [ ] Deck profile views
- [ ] Date range filtering

---

## 2026-01-26: Dashboard Visualizations with Highcharter (UNTESTED)

### Completed
- [x] Added `highcharter` library to app.R
- [x] Created Meta Share donut chart showing top deck archetypes
- [x] Created Color Distribution bar chart showing deck color popularity
- [x] Created Tournament Activity spline chart (dual-axis: tournaments + players over time)
- [x] Updated dashboard UI with new chart row (3 columns)
- [x] All charts respect store region filter from map
- [x] All charts support light/dark mode via `hc_theme_atom_switch()`

### Technical Decisions

**Highcharter with atomtemplates Integration**
- Using `hc_theme_atom_switch(mode)` to apply Atom-styled themes
- Charts respond to `input$dark_mode` for theme switching
- Digimon TCG deck colors used for chart colors (Red, Blue, Yellow, Green, Black, Purple, White)

**Chart Types**
- Meta Share: Pie chart with 50% inner radius (donut), color-coded by deck color
- Color Distribution: Horizontal bar chart with deck-color-coded bars
- Tournament Activity: Dual-axis spline with tournaments (left) and players (right)

### Status: UNTESTED
- Charts have been implemented but not tested due to lack of tournament data
- Mock data scripts created for testing

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Added highcharter library, 3 renderHighchart outputs with deck color mapping |
| `views/dashboard-ui.R` | Added chart row with 3 highchartOutput cards (280px height) |

### Files Created
| File | Purpose |
|------|---------|
| `R/seed_mock_data.R` | Seeds 20 players, 12 tournaments, ~120 results for testing |
| `R/delete_mock_data.R` | Deletes all mock data when ready for real data collection |

### Dependencies Added
- `highcharter` - Highcharts for R

### Testing Instructions
1. Run `source('R/seed_mock_data.R')` to create test data
2. Run `shiny::runApp()` to view charts
3. When ready for real data: `source('R/delete_mock_data.R')`

### Next Steps
- [ ] Test all three charts with mock data
- [ ] Player profile views
- [ ] Deck profile views
- [ ] Date range filtering

---

## 2026-01-26: Priority 1 Dashboard Improvements

### Completed
- [x] Meta share donut: Added "Other" slice for decks outside top 10
- [x] Color distribution: Now counts both primary AND secondary colors (UNION query)
- [x] Tournament activity chart: Changed from daily to weekly aggregation
- [x] New "Top Decks" section with card images from DigimonCard.io
- [x] Database migrations for decklist_url and format columns
- [x] Fixed store add NULL parameter error (NULL → NA_character_/NA_real_)
- [x] Added format/set tracking to tournaments (BT19, EX08, etc.)

### Technical Decisions

**Meta Share Donut with "Other" Slice**
- Queries ALL decks, then takes top 10 for display
- Calculates "Other" as total minus top 10
- Shows gray (#9CA3AF) slice for "Other" category
- Subtitle shows total entry count

**Dual-Color Support in Color Distribution**
- Uses UNION ALL to combine primary_color and secondary_color counts
- Secondary color only counted when not NULL
- Final grouping sums both contributions
- Updated subtitle to clarify "Primary + secondary deck colors"

**Weekly Tournament Activity Aggregation**
- Changed from daily to weekly using `date_trunc('week', event_date)`
- Better trend visualization for sparse data
- Reduces noise in charts

**Top Decks with Card Images**
- New UI element showing top 8 decks with card thumbnails
- Images from DigimonCard.io: `https://images.digimoncard.io/images/cards/{card_id}.jpg`
- Horizontal progress bars color-coded by deck color
- Responsive grid layout (2 columns on desktop, 1 on mobile)
- Custom CSS in `www/custom.css` with dark mode support

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Meta share "Other" slice, dual-color UNION queries, weekly aggregation, top decks UI |
| `views/dashboard-ui.R` | Added "Top Decks" card with `uiOutput("top_decks_with_images")` |
| `www/custom.css` | Top decks grid styling (`.deck-item`, `.deck-bar`, dark mode support) |
| `R/migrate_db.R` | Created migration script for decklist_url and format columns |

---

## 2026-01-26: Dashboard Filters Enhancement

### Completed
- [x] Added Event Type filter dropdown (Locals, Evo Cup, Store Championship, etc.)
- [x] Added Date Range picker for filtering by date
- [x] Added Reset Filters button to clear all filters
- [x] Added "Multi" color (pink #EC4899) for dual-color decks
- [x] Updated Color Distribution chart to show "Multi" for decks with secondary color
- [x] Recreated mock data with proper format values and more variety
- [x] All dashboard elements now filter by: Format, Event Type, Date Range, Store Region

### Technical Decisions

**Dashboard Filter Architecture**
- Created `build_dashboard_filters()` helper function for consistent filter generation
- Returns list with: format, event_type, store, date, any_active
- All dashboard outputs use this helper for consistent filtering
- Filters combine with AND logic

**Multi-Color Deck Handling**
- Decks with `secondary_color IS NOT NULL` show as "Multi" in Color Distribution chart
- Added pink color (#EC4899) to `digimon_deck_colors` named vector
- Added `deck-badge-multi-color` CSS class for badges
- Single-color decks show their actual color, dual-color show "Multi"

**Mock Data Improvements**
- 25 players (up from 20)
- 20 tournaments over 4 months (up from 12 over 3 months)
- ~240 results (up from ~120)
- Proper format values: BT19, EX08, BT18, BT17, EX07, older
- Recent tournaments use BT19, older ones use older formats
- Varied event types: locals, evo_cup, store_championship
- Tiered deck distribution favoring meta decks in top placements

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Added `build_dashboard_filters()`, event_type filter, Multi color support, reset observer |
| `views/dashboard-ui.R` | Added Event Type dropdown, Date Range picker, Reset button |
| `www/custom.css` | Added `.deck-badge-multi-color`, `.dashboard-filters` styles |
| `R/seed_mock_data.R` | Completely rewritten with formats, more variety, better distribution |

### Filter Implementation Details
All these outputs now respect all 4 filters:
- `top_decks_with_images`
- `conversion_rate_chart`
- `color_dist_chart`
- `tournaments_trend_chart`
- `recent_tournaments`
- `top_players`
- `meta_summary`

---

## 2026-01-26: Dashboard Layout Refinements

### Completed
- [x] Replaced Meta Share donut with Top 4 Conversion Rate bar chart
- [x] Moved Top Decks section above charts row (more visually prominent)
- [x] Added Format filter dropdown to dashboard
- [x] All dashboard elements now respect format filter

### Technical Decisions

**Top 4 Conversion Rate Chart**
- Shows top 3 decks by their top 4 conversion rate (minimum 2 entries)
- More insightful than meta share - shows performance, not just popularity
- Complements Top Decks section (which shows popularity)

**Dashboard Layout Order**
1. Value boxes (summary stats)
2. Format filter dropdown
3. Top Decks with card images (primary visual)
4. Charts row: Conversion Rate, Color Distribution, Tournament Activity
5. Tables: Recent Tournaments, Top Players
6. Meta Breakdown table

**Format Filter Implementation**
- Dropdown with all FORMAT_CHOICES + "All Formats" option
- Filters applied via `WHERE 1=1 AND t.format = 'X'` pattern
- All dashboard outputs updated: top_decks, conversion_rate, color_dist, tournaments_trend, recent_tournaments, top_players, meta_summary

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Replaced meta_share_chart with conversion_rate_chart, added format filtering to all dashboard queries |
| `views/dashboard-ui.R` | Reordered sections, changed chart output ID, added format filter dropdown |
| `www/custom.css` | Added .dashboard-filters styling |

### Next Steps
- [ ] Priority 2: Stores improvements (bubble sizing, quality metrics)
- [ ] Priority 3: Players/Meta profiles (individual player/deck pages)
- [ ] Priority 4: Tournaments (full results view, filters)
- [ ] Priority 5: Admin improvements (bulk entry, card search)

---

## 2026-01-26: Dashboard Redesign - Value Boxes, Charts, and Tables

### Completed
- [x] Replaced Stores value box with Most Popular Deck (with card image)
- [x] Set filter defaults to first format (BT19) and Locals
- [x] Changed Top Decks to show win rate % instead of entry count
- [x] Removed inline titles from all 3 Highcharts (titles now in card headers)
- [x] Changed Top 4 to Top 3 Conversion Rate chart
- [x] Changed Tournament Activity chart to show avg players with 4-week rolling avg
- [x] Added Winner column to Recent Tournaments table
- [x] Formatted event types nicely (e.g., "Evo Cup" instead of "evo_cup")
- [x] Added weighted rating to Top Players table with tooltip explanation
- [x] Replaced Meta Breakdown table with Meta Share Over Time stacked area chart

### Technical Decisions

**Most Popular Deck Value Box**
- Uses `showcase_left_center()` layout with card thumbnail
- Image from DigimonCard.io API
- Respects all dashboard filters (format, event type, date range, store region)
- Falls back to icon if no card image available

**Filter Defaults: Future-Proofed**
- Format defaults to `FORMAT_CHOICES[1]` (always first/most recent format)
- Event type defaults to "locals" (most common event type)
- Reset button restores these defaults, not empty values

**Top Decks: Win Rate %**
- Now sorted by win rate descending (minimum 2 entries)
- Bar width based on win rate relative to max
- Shows both entry count and win rate in stats line

**Top 3 Conversion Rate**
- Changed from top 4 to top 3 finishes
- Shows top 5 decks (was 3) for better visibility
- Minimum 2 entries required

**Tournament Activity: Avg Players**
- Changed from showing tournaments + total players to avg players per event
- Added 4-week rolling average trend line (dashed orange)
- Better visualization of attendance trends

**Weighted Player Rating**
- Formula: (Win% × 0.5) + (Top 3 Rate × 30) + (Events Bonus up to 20)
- Rewards: consistent performance, top finishes, and attendance
- Rating column has hover tooltip explaining calculation
- Players sorted by weighted rating descending

**Meta Share Over Time Chart**
- Stacked area chart showing deck popularity by week
- Decks with <5% overall share grouped as "Other Decks"
- Ensures at least 3 decks shown, max 8 individual decks
- Color-coded by deck primary color
- Gray (#9CA3AF) for "Other Decks" category

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Most popular deck value box, win rate Top Decks, conversion rate changes, tournament activity rolling avg, recent tournaments Winner column, weighted rating for players, meta share timeline chart |
| `views/dashboard-ui.R` | Value box replacement, filter defaults, meta_share_timeline output |
| `CHANGELOG.md` | Documented all changes |

### Next Steps
- [ ] Priority 2: Stores improvements (bubble sizing, quality metrics)
- [ ] Priority 3: Players/Meta profiles (individual player/deck pages)
- [ ] Priority 4: Tournaments (full results view, filters)
- [ ] Priority 5: Admin improvements (bulk entry, card search)

---

## 2026-01-26: Dashboard Polish - Filters, Charts, and UX Refinements

### Completed
- [x] Added "All Formats" and "All Events" as selectable dropdown options (grouped optgroups)
- [x] Fixed Top Decks math: win rate = 1st place finishes / total tournaments in filter
- [x] Moved tournament count from Top Decks stats to dynamic card header
- [x] Renamed chart titles for clarity (Top 3 Conversion Rate, Color Distribution of Decks Played, Tournament Player Counts Over Time)
- [x] Removed Format column from Recent Tournaments table
- [x] Moved Top Players rating tooltip to (i) icon in card header
- [x] Removed date range filter entirely (simplified UX)
- [x] Made mock data reproducible with `set.seed(42)`

### Meta Share Chart Improvements
- [x] Changed from stacked area to areaspline (curved lines with fill)
- [x] Added custom JS tooltip formatter that filters 0% values
- [x] Tooltip now sorts entries by value descending
- [x] Moved legend to right side with vertical layout and scroll navigation
- [x] Initially added Top 5 / All toggle, then removed for simplicity
- [x] Always shows all decks - legend scroll + tooltip filtering handles complexity

### Technical Decisions

**Grouped Filter Dropdowns**
- Changed from simple named vectors to list structure for optgroups:
  ```r
  choices = list(
    "All Formats" = "",
    "Recent Formats" = FORMAT_CHOICES
  )
  ```
- Empty string value triggers "no filter" in `build_dashboard_filters()`

**Top Decks Win Rate Calculation**
- Win rate = (1st place finishes for deck) / (total tournaments in current filter) × 100
- More meaningful than match win rate for measuring deck success
- Bar width now shows actual percentage (not relative to max)

**Meta Share Chart Design**
- Uses `hc_chart(type = "areaspline")` with `stacking = "normal"`
- Custom JS tooltip formatter:
  - Filters points where `p.y > 0`
  - Sorts remaining points by `b.y - a.y` (descending)
  - Shows deck name with color dot and percentage
- Right-side legend with `maxHeight: 280` and scroll navigation
- Handles many decks gracefully without cluttering the chart

**Info Icon Tooltip Pattern**
- Rating explanation moved from column tooltip to (i) icon in card header
- Uses native `title` attribute for hover tooltip
- CSS styled with `.rating-info-icon` class
- More discoverable and consistent across the app

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Grouped filter choices, Top Decks math fix, meta share areaspline with JS formatter, removed date filter |
| `views/dashboard-ui.R` | Dynamic Top Decks header, (i) icon for rating, simplified meta share card |
| `www/custom.css` | Rating info icon styles, responsive filter grid, removed unused toggle CSS |
| `R/seed_mock_data.R` | Added `set.seed(42)` for reproducibility |

### Next Steps
- [x] Priority 2: Stores improvements (bubble sizing, quality metrics)
- [ ] Priority 3: Players/Meta profiles (individual player/deck pages)
- [ ] Priority 4: Tournaments (full results view, filters)
- [ ] Priority 5: Admin improvements (bulk entry, card search)

---

## 2026-01-26: Priority 2 - Stores Improvements

### Completed
- [x] Dynamic bubble sizing on map based on tournament activity
- [x] Store metrics in list table (Events, Avg Players, Last Event)
- [x] Store detail modal with click-to-view
- [x] Map legend explaining bubble sizes

### Technical Decisions

**Dynamic Bubble Sizing**
- Query joins stores with tournaments to get activity metrics
- Bubble radius scales from 8px (no events) to 20px (most active)
- Formula: `8 + (tournament_count / max_tournaments) * 12`
- Visual indicator helps users identify active stores at a glance

**Store Activity Metrics**
- Added to `stores_data` reactive: `tournament_count`, `avg_players`, `last_event`
- Uses LEFT JOIN to include stores with zero tournaments
- `last_event` displayed as relative time ("2 days ago", "3 weeks ago")

**Store Detail Modal**
- Click any row in store list table to open modal
- Uses reactable's `selection = "single"` and `onClick = "select"`
- Modal shows:
  - Store info (city, address, website)
  - Activity stats (Events, Avg Players, Last Event)
  - Recent tournaments table (last 5)
  - Top players at store (by wins)
- Uses `showModal()` / `modalDialog()` from Shiny

**Enhanced Popups**
- Map popups now show activity metrics (Events, Avg Players)
- Shows "Last event: X days ago" for active stores
- Subtitle changes to "Active Game Store" for stores with events

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Updated `stores_data` query with metrics, dynamic bubble sizing, store detail modal with recent tournaments and top players |
| `views/stores-ui.R` | Added modal output, click hint, map legend note |

### Next Steps
- [x] Priority 3: Players/Meta profiles (individual player/deck pages)
- [ ] Priority 4: Tournaments (full results view, filters)
- [ ] Priority 5: Admin improvements (bulk entry, card search)

---

## 2026-01-26: Priority 3 - Player & Deck Profiles

### Completed
- [x] Player profile modal with stats, favorite decks, tournament history
- [x] Deck archetype profile modal with card image, top pilots, recent results
- [x] Filters on Players page (format, minimum events)
- [x] Filters on Meta page (format, minimum entries)
- [x] Click-to-view on all profile tables
- [x] Decklist links throughout all profile modals

### Technical Decisions

**Player Profile Modal**
- Click any row in Player Standings to open profile
- Shows: overall stats (events, record, win rate, 1st places, top 3s)
- Favorite decks section with color badges and win counts
- Recent results table with store, deck, placement, record, decklist link
- Home store displayed when available

**Deck Archetype Profile Modal**
- Click any row in Archetype Performance to open profile
- Shows card image from DigimonCard.io alongside stats
- Stats: entries, pilots, 1st places, top 3s, win rate, avg placement
- Top pilots table showing who plays the deck best
- Recent results showing all players' performances with this deck

**Ordinal Helper Function**
- Added `ordinal(n)` function for displaying placements (1st, 2nd, 3rd, etc.)
- Handles special cases (11th, 12th, 13th)

**Consistent Profile Pattern**
- Both player and deck profiles follow same UX pattern as store detail modal
- Row selection via reactable's `selection = "single"` and `onClick = "select"`
- Cursor pointer styling for clickable rows
- "Click a row for profile" hint in card headers

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Added `ordinal()` helper, player profile modal, deck profile modal, filters for both pages, reactive values for selection |
| `views/players-ui.R` | Added filters (format, min events), click hint, modal output |
| `views/meta-ui.R` | Added filters (format, min entries), click hint, modal output |

### Next Steps
- [x] Priority 4: Tournaments (full results view, filters)
- [ ] Priority 5: Admin improvements (bulk entry, card search)

---

## 2026-01-27: Priority 3 Refinements - Search & Layout

### Completed
- [x] Added search filter to Players page (search by player name)
- [x] Added search filter to Meta page (search by deck name)
- [x] Consistent two-row filter layout on both pages
- [x] Stats layout in profile modals now evenly distributed (justify-content-evenly)
- [x] Store detail modal includes winning deck name and decklist link
- [x] All three profile modals (store, player, deck) have consistent stats styling

### Technical Decisions

**Two-Row Filter Layout**
- Row 1: Search input (max-width 300px)
- Row 2: Dropdowns + Reset button using flexbox with gap-3
- Avoids overlap issues with layout_columns
- Cleaner visual hierarchy

**Search Filter Implementation**
- Case-insensitive partial match using `LOWER(column) LIKE LOWER('%search%')`
- Applied to both main query and row selection query for consistency
- Reset button clears search along with other filters

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Search filters for players and meta, evenly distributed stats in all modals, deck name in store modal |
| `views/players-ui.R` | Two-row filter layout with search |
| `views/meta-ui.R` | Two-row filter layout with search |

### Next Steps
- [x] Priority 4: Tournaments (full results view, filters)
- [ ] Priority 5: Admin improvements (bulk entry, card search)

---

## 2026-01-27: Priority 4 - Tournaments Page

### Completed
- [x] Added filters to Tournaments page (search store, format, event type)
- [x] Tournament table now shows Winner and Winning Deck columns
- [x] Click any tournament row to view full results modal
- [x] Tournament detail modal shows all placements with deck badges
- [x] Decklist links in tournament results
- [x] Consistent two-row filter layout matching other pages

### Technical Decisions

**Tournament Detail Modal**
- Shows tournament metadata: Event Type, Format, Players, Rounds
- Full standings table with all placements
- Deck badges color-coded by primary color
- Ordinal placements (1st, 2nd, 3rd) with color highlighting
- Decklist icon links when available

**Enhanced Tournament List**
- Added Winner and Winning Deck columns to main table
- JOIN with results (placement=1), players, and deck_archetypes
- Formatted event types (e.g., "Store Champ" instead of "store_championship")

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Tournament filters, enhanced query with winner/deck, detail modal with full standings |
| `views/tournaments-ui.R` | Two-row filters, click hint, modal output |

### Next Steps
- [x] Priority 5: Admin improvements (bulk entry, card search)

---

## 2026-01-27: Priority 5 - Admin Improvements

### Completed
- [x] Bulk tournament entry (paste multiple results at once)
- [x] Card search for deck assignment in results entry
- [x] Enhanced data validation and error handling across admin forms

### Technical Decisions

**Bulk Results Entry**
- Added toggle between "Single Entry" and "Bulk Paste" modes
- Format: `Place, Player Name, Deck Name, W-L-T, [Decklist URL]`
- Parser validates each line and shows errors/warnings
- Deck name matching: exact match first, then partial match
- Preview table shows parsed results before submission
- Highlights unmatched decks in red
- Creates new players automatically if not found (case-insensitive matching)

**Card Search for Deck Assignment**
- Expandable section under deck dropdown: "Find deck by card..."
- Uses existing `search_by_name()` API function
- Searches deck_archetypes by display_card_id
- Click-to-select deck from search results
- Shows card thumbnails for matching decks

**Data Validation Enhancements**

Tournament Creation:
- Required field validation (store, date, player count, rounds)
- Duplicate tournament warning (same store, date, event type)

Result Entry:
- Required player name and deck validation
- Duplicate placement warning
- Duplicate player in same tournament warning
- URL format validation for decklist URLs
- Case-insensitive player matching (finds existing player first)

Archetype Creation:
- Required name validation (min 2 characters)
- Duplicate archetype name check (case-insensitive)
- Card ID format validation (e.g., BT17-042)

Store Creation:
- Required name and city validation
- Duplicate store check (same name in same city)
- Website URL format validation

**UI Updates**
- Deck dropdown now uses selectizeInput for searchable selection
- All updateSelectInput calls for deck changed to updateSelectizeInput

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Bulk entry parsing/submission, deck card search, validation for all admin forms |
| `views/admin-results-ui.R` | Entry mode toggle, bulk paste textarea, preview table, card search expander |

### Next Steps
- [ ] Data import/export functionality
- [ ] Player deduplication tools
- [ ] Archetype merging/aliasing
- [ ] Historical data backfill

---

## 2026-01-27: Admin UI Polish & Edit Functionality

### Completed
- [x] All admin inputs now single-row layout (no side-by-side fields)
- [x] Fixed card search in Manage Decks (working images, clickable buttons)
- [x] Added quick-add deck feature in results entry
- [x] Added edit functionality for stores and decks (click row to edit)
- [x] Added shinyjs library for show/hide button functionality

### Technical Decisions

**Single-Row Admin Layouts**
- Removed all `layout_columns()` wrappers in admin forms
- Each input field now has its own row for clearer UI
- Better mobile responsiveness

**Card Search Fix (Manage Decks)**
- Changed from inline `onclick` handlers to proper `actionButton` per card
- Switched to .jpg image format instead of .webp for better browser support
- Store card search results in `rv$card_search_results` reactive
- Used `lapply(1:8, ...)` pattern for observeEvent handlers

**Quick-Add Deck in Results Entry**
- Removed confusing "Find deck by card" section
- Added expandable "Quick add new deck" section
- Creates deck with minimal info (name + primary color only)
- Notification reminds user to complete details in Manage Decks later
- Auto-selects newly created deck in dropdown

**Edit Functionality Pattern**
- Click any row in admin tables to populate form for editing
- Hidden `editing_*_id` input tracks edit mode
- Add button hidden, Update button shown during edit
- Cancel Edit button clears form and returns to add mode
- Uses `shinyjs::show()` / `shinyjs::hide()` for button visibility
- Archetype updates refresh both list and results dropdown

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Added shinyjs, quick-add deck, edit observers for stores/decks, fixed card search |
| `views/admin-stores-ui.R` | Single-row layout, edit mode UI, cancel button |
| `views/admin-decks-ui.R` | Single-row layout, edit mode UI, cancel button |
| `views/admin-results-ui.R` | Single-row layout, quick-add deck section |
| `www/custom.css` | Card search button styles, edit mode styles |

### Dependencies Added
- `shinyjs` - Show/hide UI elements programmatically

---

## 2026-01-27: Admin UI Fixes - Card Search, Pagination, Alignment

### Completed
- [x] Fixed card search images in Manage Decks (now displaying correctly)
- [x] Added pagination to admin tables (default 20 rows, options: 10/20/50/100)
- [x] Fixed search box and button alignment in Manage Decks
- [x] Added helper text for Selected Card ID field

### Technical Decisions

**Card Search Image Fix**
- DigimonCard.io API returns card number in `id` field, not `cardnumber`
- Previous code was using `card_data$cardnumber` which was undefined
- Fixed to use `card_data$id` for card number
- Image URLs use `.webp` format: `https://images.digimoncard.io/images/cards/{id}.webp`
- Server returns WebP format regardless of file extension in URL

**Debug Logging Added (Temporary)**
- Console logging shows API response structure
- UI debug panel shows column names and image URLs
- Helped identify the `id` vs `cardnumber` field issue
- Can be removed once card search is confirmed stable

**Admin Table Pagination**
- Both Manage Stores and Manage Decks tables now have pagination
- `defaultPageSize = 20` for reasonable default
- `showPageSizeOptions = TRUE` with options `c(10, 20, 50, 100)`
- Improves usability when many entries exist

**Search Box Alignment**
- Changed from flexbox to Bootstrap row/col layout
- Uses `align-items-end` to align button with input field
- Added spacer label (`&nbsp;`) above button for proper vertical alignment

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Fixed card search to use `id` field, `.webp` image format, added pagination to admin tables, debug logging |
| `views/admin-decks-ui.R` | Fixed search box/button alignment with Bootstrap grid |

### API Response Structure (DigimonCard.io)
Key fields returned by `/api-public/search`:
- `id` - Card number (e.g., "BT10-082")
- `name` - Card name
- `color` - Primary color
- `color2` - Secondary color (if any)
- `type` - Card type (Digimon, Tamer, Option)
- `level`, `dp`, `play_cost`, `evolution_cost`
- `digi_type`, `digi_type2`, etc.
- `pretty_url` - URL-friendly name
- NO `image_url` field - must construct URL manually

---

## 2026-01-27: Deployment Preparation

### Completed
- [x] Removed debug logging from card search
- [x] Updated README with current features and tech stack
- [x] Updated CHANGELOG with version 0.4.0
- [x] Added MAPBOX_ACCESS_TOKEN to .env.example
- [x] Fixed package list in README to match actual dependencies
- [x] Added `nul` to .gitignore (Windows artifact)
- [x] Verified .env loading is conditional (won't fail if file missing)

### Deployment Checklist

**For Posit Connect Cloud:**
1. Set environment variables in Posit Connect settings:
   - `MOTHERDUCK_TOKEN` - For cloud database
   - `MAPBOX_ACCESS_TOKEN` - For map features
   - `ADMIN_PASSWORD` - (Optional) Override default admin password
2. Deploy via `rsconnect::deployApp()`
3. MotherDuck will be used automatically on Linux (Posit Connect)

**For Local Development:**
1. Copy `.env.example` to `.env`
2. Add your tokens
3. Run `source("R/init_database.R")` to create local database
4. Run seed scripts for initial data
5. `shiny::runApp()`

### Files Ready for Commit
- Modified: app.R, README.md, CHANGELOG.md, .env.example, .gitignore, dev_log.md
- Modified: All view files (admin-*.R, dashboard-ui.R, etc.)
- Untracked (should add): R/seed_mock_data.R, R/delete_mock_data.R, R/migrate_db.R

---

## 2026-01-27: v0.5.0 - Admin Pages Enhancement

### Completed
- [x] Bug fixes: bind parameter error (NULL → NA_character_), search button alignment
- [x] Schema updates: is_online for stores, is_multi_color for deck_archetypes
- [x] Online store support with conditional UI and separate display section
- [x] Deck management: reorganized form, multi-color support, delete functionality
- [x] Store management: online store handling, delete functionality
- [x] Results wizard: 2-step flow replacing bulk paste mode
- [x] Duplicate tournament detection with modal options
- [x] Quick add forms for players and decks during result entry
- [x] Migration script for existing databases

### Technical Decisions

**Online Store Support: Flag-based Approach**
- Added `is_online` boolean column instead of separate table
- Conditional UI using `conditionalPanel()` based on checkbox state
- Physical stores: address, city, state, zip (geocoded)
- Online stores: name, region (no geocoding)
- Display: separate "Online Tournament Organizers" card on Stores page

**Results Entry: Wizard over Bulk Paste**
- Removed bulk paste mode entirely (confusing UX, error-prone parsing)
- 2-step wizard: Tournament Details → Add Results
- Step navigation via `rv$wizard_step` reactive value
- Tournament summary bar persists context in step 2
- Quick-add forms reduce friction for new players/decks

**Delete Functionality: Hard Delete with Referential Integrity**
- Hard DELETE instead of soft delete (is_active = FALSE)
- Pre-delete check counts related records
- Block delete if records exist, show count in error message
- Modal confirmation with specific warning message

**NULL/NA Handling for DuckDB**
- DuckDB bind parameters require NA values, not NULL
- Pattern: `if (nchar(x) > 0) x else NA_character_`
- Fixed throughout: decklist_url, address, zip, state, schedule, website

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Wizard logic, online store handling, delete handlers, quick add forms, NULL fixes |
| `views/admin-stores-ui.R` | Online checkbox, conditional panels, delete button/modal |
| `views/admin-decks-ui.R` | Reorganized layout, multi-color checkbox, delete button/modal |
| `views/admin-results-ui.R` | Complete rewrite for wizard flow |
| `views/stores-ui.R` | Online stores section |
| `db/schema.sql` | New columns, updated view |
| `R/migrate_v0.5.0.R` | New migration script |
| `www/custom.css` | Wizard step styles |

### Migration Instructions
```r
library(DBI)
library(duckdb)
source("R/migrate_v0.5.0.R")
con <- dbConnect(duckdb::duckdb(), dbdir = "data/local.duckdb")
migrate_v0.5.0(con)
dbDisconnect(con)
```

---

## 2026-01-27: v0.6.0 - Format Management

### Completed
- [x] Added formats table to database schema for managing game sets
- [x] Created migration script (R/migrate_v0.6.0.R) with seed data
- [x] Built admin UI for format CRUD operations
- [x] Dynamic format dropdown loading from database
- [x] Referential integrity checks for format deletion
- [x] Fixed reactable selection event for row editing

### Technical Decisions

**Formats Table Design**
- `format_id` (VARCHAR PRIMARY KEY): Set code like 'BT19', 'EX08'
- `set_name`: Full name like 'Xros Encounter'
- `display_name`: Combined display like 'BT19 (Xros Encounter)'
- `release_date`: For sorting by newest
- `sort_order`: Manual sort override (lower = appears first)
- `is_active`: Toggle visibility in dropdowns

**Dynamic Format Loading**
- Added `get_format_choices(con)` helper function
- Falls back to hardcoded FORMAT_CHOICES if DB unavailable
- Observer updates dashboard and tournament dropdowns on format change
- `rv$format_refresh` reactive value triggers dropdown updates

**Admin UI Pattern**
- Follows existing stores/decks admin pattern
- Click row to edit, form populates with current values
- Add/Update/Delete buttons with shinyjs show/hide
- Modal confirmation for delete with referential integrity check
- Blocks delete if tournaments reference the format

**Reactable Selection Event**
- Correct pattern: `{outputId}__reactable__selected`
- Initial bug used `__selected` instead of `__reactable__selected`
- Fixed to match working stores/decks implementations

### Files Created
| File | Purpose |
|------|---------|
| `views/admin-formats-ui.R` | Admin UI for format management |
| `R/migrate_v0.6.0.R` | Migration script with formats table and seed data |

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Format admin handlers, get_format_choices helper, dynamic dropdown updates |
| `db/schema.sql` | Added formats table definition and indexes |
| `CHANGELOG.md` | Added v0.6.0 release notes |

### Migration Instructions
```r
source("R/db_connection.R")
con <- connect_db()
source("R/migrate_v0.6.0.R")
migrate_v0.6.0(con)
dbDisconnect(con)
```

### Seeded Formats
| Code | Set Name | Release Date |
|------|----------|--------------|
| BT19 | Xros Encounter | 2025-01-24 |
| EX08 | New Awakening | 2024-11-22 |
| BT18 | Dimensional Phase | 2024-09-27 |
| EX07 | Digimon Liberator | 2024-08-09 |
| BT17 | Secret Crisis | 2024-05-31 |
| ST19 | Fable Waltz | 2024-04-26 |
| BT16 | Beginning Observer | 2024-02-23 |
| EX06 | Infernal Ascension | 2024-01-26 |
| BT15 | Exceed Apocalypse | 2023-11-17 |
| older | Older Format | N/A |

---

## 2026-01-27: Card Cache & UI Improvements

### Completed
- [x] Implemented card cache in MotherDuck to bypass DigimonCard.io API 403 blocks
- [x] Created Python sync script for fetching cards from API
- [x] Added GitHub Actions workflow for monthly card sync
- [x] Fixed DuckDB bind parameter error (NULL → NA_character_) for archetype updates
- [x] Added tournament deletion feature via enhanced "Start Over" modal
- [x] UI improvements: card preview placeholder, smaller search inputs, W/L/T stacked layout
- [x] Simplified Manage Formats (auto-generate display_name, sort by release_date)
- [x] Added "Online Tournament" event type
- [x] Removed hardcoded FORMAT_CHOICES, load dynamically from database
- [x] Standardized reset buttons across all filter tabs

### Technical Decisions

**Card Cache for Local Search**
- DigimonCard.io API returns 403 on Posit Connect Cloud (blocks server IPs)
- Solution: Cache 2,843 cards in MotherDuck `cards` table
- Python script `scripts/sync_cards.py` fetches cards respecting rate limits
- R function `search_cards_local()` queries cached cards instead of API
- Card images still loaded from DigimonCard.io CDN (works fine)
- GitHub Actions workflow runs monthly to sync new cards

**Tournament Deletion Feature**
- Enhanced "Start Over" button to show modal with two options:
  - "Clear Results": Keeps tournament, removes results (stays on Step 2)
  - "Delete Tournament": Cascade deletes tournament and all results (returns to Step 1)
- Confirmation shows result count to prevent accidental deletion
- Designed for "accidentally created tournament" use case

**W/L/T Input Layout**
- Attempted various approaches: CSS Grid, flexbox, splitLayout, fixed widths
- Bootstrap 5's form-control has aggressive min-width that resists shrinking
- Final solution: Simple stacked layout with full labels (Wins, Losses, Ties)
- Clean, works reliably, better mobile experience

**Manage Formats Simplification**
- Removed display_name and sort_order fields from UI
- Auto-generate display_name as "{format_id} ({set_name})"
- Sort by release_date DESC (most recent first)
- Reduces admin friction when adding new formats

### Files Created
| File | Purpose |
|------|---------|
| `scripts/sync_cards.py` | Python script to fetch cards from DigimonCard.io API |
| `scripts/migrate_v0.5.0.py` | Python migration for MotherDuck (adds missing columns) |
| `.github/workflows/sync-cards.yml` | Monthly GitHub Actions workflow for card sync |
| `docs/plans/2026-01-27-tournament-deletion-design.md` | Design doc for deletion feature |

### Files Modified
| File | Changes |
|------|---------|
| `app.R` | Card cache search, tournament deletion handlers, format simplification, NA_character_ fix |
| `db/schema.sql` | Added cards table for cache |
| `R/digimoncard_api.R` | Added search_cards_local() function |
| `views/admin-results-ui.R` | Start over modal, W/L/T stacked layout |
| `views/admin-decks-ui.R` | Card preview placeholder, smaller search inputs |
| `views/admin-formats-ui.R` | Simplified form (removed display_name, sort_order) |
| `views/*.R` | Standardized reset buttons across all filter tabs |

### API 403 Issue Details
- Card search worked locally but returned 403 on Posit Connect
- DigimonCard.io blocks cloud server IP ranges
- Card images (CDN) work fine - only API endpoints blocked
- Cache solution allows full functionality without API dependency

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
