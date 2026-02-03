# DigiLab - Roadmap

This document outlines the planned features, improvements, and bug fixes for the tournament tracker.

**Current Version:** v0.18.0
**Target:** v1.0 Public Launch
**Cadence:** ~1 milestone per week

---

## v0.18 - Server Extraction Refactor ✓

**COMPLETED** - Internal codebase refactor (no user-facing changes)

| ID | Type | Description |
|----|------|-------------|
| R1 | REFACTOR | Extract public page server logic from monolithic `app.R` into modular `server/public-*.R` files |
| R2 | REFACTOR | Standardize naming convention: `public-*` for public tabs, `admin-*` for admin tabs |
| R3 | REFACTOR | Reduce `app.R` from 3,178 to 566 lines (~82% reduction) |

**Files Created:**
- `server/public-dashboard-server.R` (889 lines)
- `server/public-stores-server.R` (851 lines)
- `server/public-players-server.R` (364 lines)
- `server/public-meta-server.R` (305 lines)
- `server/public-tournaments-server.R` (237 lines)

---

## v0.18.1 - Code Cleanup Refactor

**IN PROGRESS** - Internal codebase cleanup (no user-facing changes)

| ID | Type | Description | Status |
|----|------|-------------|--------|
| R4 | REFACTOR | Reactive value cleanup - document, group, and standardize naming convention for `rv` (32 values) | ✓ |
| R5 | REFACTOR | CSS cleanup - consolidate `custom.css`, remove inline styles from R code, organize by component | |

**R4 Deliverables:**
- `ARCHITECTURE.md` - Technical reference for server modules, reactive values, patterns
- Reactive values reorganized into 6 categories (Core, Navigation, Modal State, Form/Wizard, Refresh Triggers, Delete Permission)
- Renamed `selected_store_detail` → `selected_store_id`, `selected_online_store_detail` → `selected_online_store_id`

---

## v0.19 - Onboarding & Help

| ID | Type | Description |
|----|------|-------------|
| F7 | FEATURE | Contextual help - "Click a row for details" hint text above clickable tables |
| F7b | FEATURE | Info icons on Rating/Score column headers → link to website methodology page |
| F7c | FEATURE | Light hints on admin pages explaining how to use each function |

---

## v0.20 - Self-Service & Sustainability

| ID | Type | Description |
|----|------|-------------|
| F3 | FEATURE | Community-submitted suggestions for deck archetypes and stores (anonymous, approval queue for admins) |
| I9 | FEATURE | Simple player merge tool - admin can merge duplicate players (e.g., "John Smith" and "J. Smith") |
| F10 | FEATURE | Player achievement badges - auto-calculated, displayed in player modal, top 3-5 shown with "show all" expansion |

**Achievement Badge Categories:**
- Wins: First Win, 5 Wins, 10 Wins, 25 Wins
- Participation: 10 Events, 25 Events, 50 Events
- Consistency: 5 Top 3s, 10 Top 3s, 25 Top 3s
- Store Explorer: Played at 3/5/10 stores
- Deck Variety: Won with 3 different decks
- Streaks: 3 wins in a row, 5 wins in a row
- Special: First tournament, Underdog win

---

## v0.21 - Multi-Region Foundation

| ID | Type | Description |
|----|------|-------------|
| R1 | FEATURE | Region/geography selector for filtering |
| R2 | FEATURE | Stores, players, tournaments scoped by region |
| R3 | FEATURE | Data visibility model - cross-region visibility with filtering |
| R4 | FEATURE | Regional vs global leaderboards |
| R5 | FEATURE | Admin permissions per region |
| A1 | FEATURE | Admin user login (per user accounts, audit trail) |
| L1 | FEATURE | Limitless API exploration for online/webcam tournaments |

**Design Notes (to explore in design session):**
- Custom links with auto-set region/radius (e.g., `?region=houston` or `?radius=50`)
- Ask user location on load → auto-filter to nearby (50mi radius)
- "My Region" vs "Everyone" toggle
- Online tournaments via Limitless could be its own "region" or view

---

## v1.0 - Public Launch

| ID | Type | Description |
|----|------|-------------|
| W1 | FEATURE | Website landing page - about the tool, who it's for, geographic scope, how to use |
| W2 | FEATURE | Methodology pages - simple rating overview + detailed formula breakdown |
| W3 | FEATURE | Weekly Meta Report page - auto-generated from tournament data |
| W4 | FEATURE | "For Tournament Organizers" guide - how to submit results, get involved |
| W5 | FEATURE | App iframe integration |
| I7 | IMPROVEMENT | Replace header cards icon with Digivice SVG |
| M1 | IMPROVEMENT | Mobile table column prioritization - determine which columns to show/hide on small screens |
| X1 | IMPROVEMENT | Remove BETA badge |

**Website Requirements:**
- Digital Digimon aesthetic matching the app
- Static site (GitHub Pages or similar)
- Custom domain (TBD)

---

## Parking Lot

Items for future consideration, not scheduled:

| ID | Type | Description | Notes |
|----|------|-------------|-------|
| F2 | FEATURE | Screenshot OCR → parse results | Bandai TCG+ only. Extracts: placement, username, member#, win points. Still manual: deck, decklist. Design: `docs/plans/2026-02-03-admin-ux-improvements-design.md` |
| F2b | FEATURE | Public result submission with approval | Allow non-admins to submit results for admin review. Wait until admin bandwidth is bottleneck. |
| F2c | FEATURE | Error flagging | "Report Error" link in modals → creates admin notification. Lightweight feedback channel. |
| F8 | FEATURE | Embed widgets for stores | Let stores embed tournament history on their sites |
| P1 | FEATURE | Limitless TCG API deep integration | Beyond basic exploration |
| P2 | FEATURE | Discord bot for result reporting | |
| P3 | FEATURE | Expand to other Texas regions | After multi-region foundation works |
| P4 | FEATURE | One Piece TCG support | Multi-game expansion |
| P5 | FEATURE | Mobile-first data entry PWA | Consider platform rewrite if scaling demands it |
| DL | FEATURE | "Claim your result to add decklist" | Lightweight way for players to add their decklist without accounts |

---

## Removed / Won't Do

| Description | Reason |
|-------------|--------|
| Date range filtering on dashboard | Not needed - format filter is sufficient |
| Detailed player profile views | Modals already cover this |
| Detailed deck profile views | Modals already cover this |
| Matchup analysis (deck A vs deck B) | No round-by-round data available |
| Event calendar page | Bandai TCG Plus already covers this |
| Store directory page | Bandai TCG Plus already covers this |
| Data export for users | Handle manually on request |
| Season/format archive view | Format filter already covers this |

---

## Completed

### v0.17.0 - Admin UX Improvements
- A2: Edit Results modal from Edit Tournaments page
- A3: Blank date field with required validation
- A4: Duplicate tournament flow navigates to Edit Tournaments
- Bug fixes: date observer, reactable columns, input widths, decklist URL handling

### v0.16.1 - DigiLab Rebranding
- Custom domain: digilab.cards
- Google Analytics (GA4)
- Open Graph meta tags for link previews
- Branding assets (logo, icon, favicon)
- Player search SQL bug fix

### v0.16.0 - UX Improvements & Modal Enhancements
- I2: 'None' option in admin dropdowns (clear/reset selection)
- I4: Manage Tournaments admin tab (full edit + delete)
- I5: Database auto-refresh for admins (all tables)
- F1: Overview click → modal + tab switch
- I12: Modal updates (Meta %, Conv %, Store Rating, cross-modal links, consistent naming)
- I13: Meta chart series sorted by deck color
- Sidebar sync fix for programmatic navigation

### v0.15.0 - Bug Fixes & Quick Polish
- Modal selection bug fixed (JS onClick with row data)
- Blue deck badge changed to "U" (black remains "B")
- Default 32 rows for main tables
- GitHub and Ko-fi links in header
- Players Tab: added Record (colored W-L-T), Main Deck columns
- Meta Tab: added Meta %, Conv % columns, removed Avg Place
- Top Decks reduced to 6 for cleaner grid layouts

### v0.14.0 - Rating System
- Competitive Rating (Elo-style with implied results)
- Achievement Score (points-based)
- Store Rating (weighted blend)
- Ratings displayed in Overview, Players, and Stores tabs

### v0.13.0 - Mobile UI Polish
- Responsive value boxes
- Smart filter layouts
- Reduced header/content spacing
- Mobile-optimized navigation

### v0.12.0 - Desktop Design Overhaul
- Digital Digimon aesthetic
- App-wide loading screen
- Digital empty states
- Modal stat boxes
- Header with BETA badge and animations

*See CHANGELOG.md for full version history.*

---

## References

- **Bug Documentation:** `docs/solutions/`
- **Design Documents:** `docs/plans/`
- **Development Log:** `logs/dev_log.md`
- **User Feedback:** [Google Sheet](https://docs.google.com/spreadsheets/d/11ZeL7yZo7ee4rIdbGCCLvx_Om2VtvXtcj4U6WmH4bS8/edit?gid=0#gid=0)
