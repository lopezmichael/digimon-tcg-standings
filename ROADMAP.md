# DFW Digimon TCG Tournament Tracker - Roadmap

This document outlines the planned features, improvements, and bug fixes for the tournament tracker.

**Current Version:** v0.15.0
**Target:** v1.0 Public Launch
**Cadence:** ~1 milestone per week

---

## v0.16 - UX Improvements

| ID | Type | Description |
|----|------|-------------|
| I2 | IMPROVEMENT | Add 'None' option in admin page dropdowns |
| I4 | FEATURE | New "Manage Tournaments" admin tab - edit tournament details, delete tournaments (replaces buried deletion flow) |
| I5 | IMPROVEMENT | Database auto-refresh for admins - no more hard browser refresh needed after modifications |
| F1 | FEATURE | Overview click → modal + tab switch - clicking player/tournament in Overview opens modal and switches to appropriate tab |
| I12 | IMPROVEMENT | Modal updates - see details below |
| I13 | IMPROVEMENT | Sort "Meta Share Over Time" chart series by deck color for visual grouping |

**I12 Details - Modal Updates:**

*All Modals:*
- Consistent naming with table columns (Score not Achv, 1sts not 1st Places, etc.)
- Cross-modal links (click store name → opens store modal, etc.)

*Store Modal:*
- Add: Store Rating, Total unique players, Most popular deck at this store
- Link to: Tournament modals (recent tournaments)

*Player Modal:*
- Add: Rating, Score, Avg Placement
- Change: Record to W-L-T with colors (green-red-orange)
- Link to: Store modal (home store)

*Deck/Archetype Modal:*
- Add: Meta %, Conv %, Win %, Avg Placement
- Link to: Player modals (top pilots)

*Tournament Modal:*
- Add: Store Rating
- Link to: Store modal

---

## v0.17 - Onboarding & Help

| ID | Type | Description |
|----|------|-------------|
| F7 | FEATURE | Contextual help - "Click a row for details" hint text above clickable tables |
| F7b | FEATURE | Info icons on Rating/Score column headers → link to website methodology page |
| F7c | FEATURE | Light hints on admin pages explaining how to use each function |

---

## v0.18 - Self-Service & Sustainability

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

## v0.19 - Multi-Region Foundation

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
| F2 | FEATURE | Screenshot OCR → parse results | Scope: Bandai TCG Plus screenshots only |
| F8 | FEATURE | Embed widgets for stores | Let stores embed tournament history on their sites |
| P1 | FEATURE | Limitless TCG API deep integration | Beyond basic exploration |
| P2 | FEATURE | Discord bot for result reporting | |
| P3 | FEATURE | Expand to other Texas regions | After multi-region foundation works |
| P4 | FEATURE | One Piece TCG support | Multi-game expansion |
| P5 | FEATURE | Mobile-first data entry PWA | |
| GA | FEATURE | Google Analytics | Add when needed to show traction |
| DOM | FEATURE | Custom domain | Ideas: dfwdigimon.com, digitcg.gg, digimonmeta.com |
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
