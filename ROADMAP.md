# DigiLab - Roadmap

This document outlines the planned features, improvements, and bug fixes for the tournament tracker.

**Current Version:** v0.21.0
**Target:** v1.0 Public Launch
**Cadence:** ~1 milestone per week

---

## v0.22 - User Accounts & Permissions

**Design:** `docs/plans/2026-02-05-user-accounts-design.md` (to be created)

| ID | Type | Description |
|----|------|-------------|
| UA1 | FEATURE | Discord OAuth login ("Login with Discord") |
| UA2 | FEATURE | Users table with Discord ID, username, role, scene assignment |
| UA3 | FEATURE | Permission levels: Viewer (default, no login), Scene Admin, Super Admin |
| UA4 | FEATURE | Scene Admin can manage data for their assigned scene only |
| UA5 | FEATURE | Super Admin can manage all data, users, and scenes |
| UA6 | FEATURE | Admin invite links (Super Admin generates link, recipient becomes Scene Admin) |
| UA7 | FEATURE | Direct user promotion (Super Admin promotes existing users) |
| UA8 | UI | Permission-scoped admin tabs (hidden unless logged in with appropriate role) |

**Technical Notes:**
- Discord OAuth is free and widely used in TCG communities
- localStorage for scene preference (no login required for viewers)
- Session management via secure cookies
- First Super Admin seeded via database during deployment

---

## v0.23 - Multi-Region & Online Scene

**Design:** `docs/plans/2026-02-04-region-expansion-design.md`

| ID | Type | Description |
|----|------|-------------|
| MR1 | FEATURE | Scenes table with hierarchy (Global → Country → State → Metro) |
| MR2 | FEATURE | Scene selector in header + first-visit modal |
| MR3 | FEATURE | All tabs filter by selected scene |
| MR4 | FEATURE | "Online" as special top-level scene for webcam/Discord tournaments |
| MR5 | FEATURE | Leaderboards filtered by scene (players who competed there) |
| MR6 | FEATURE | "All Scenes" / Global toggle for cross-region viewing |
| MR7 | SCHEMA | Add `scene_id` to stores table |
| MR8 | SCHEMA | Add `tier` to tournaments table (local, regional, national, international) |
| L1 | FEATURE | Limitless API exploration for online tournament data |

**Key Design Decisions:**
- Players don't belong to scenes (no accounts required for viewers)
- Stores belong to scenes; players appear on leaderboards based on where they've competed
- Rating is global; leaderboards are filtered views
- Scene Admins can only manage their assigned scene's data

---

## v0.24 - Onboarding & Help

| ID | Type | Description |
|----|------|-------------|
| F7 | FEATURE | Contextual help - "Click a row for details" hint text above clickable tables |
| F7b | FEATURE | Info icons on Rating/Score column headers → link to FAQ methodology section |
| F7c | FEATURE | Light hints on admin pages explaining how to use each function |
| OH1 | FEATURE | First-visit scene selection modal (stored in localStorage) |
| OH2 | FEATURE | Guided tour for new users (optional, dismissible) |

---

## v0.25 - Self-Service Extras

| ID | Type | Description |
|----|------|-------------|
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

## v1.0 - Public Launch

| ID | Type | Description |
|----|------|-------------|
| W1 | FEATURE | Website landing page - about the tool, who it's for, geographic scope, how to use |
| W2 | FEATURE | Methodology pages - simple rating overview + detailed formula breakdown |
| W3 | FEATURE | Weekly Meta Report page - auto-generated from tournament data |
| I7 | IMPROVEMENT | Replace header cards icon with Digivice SVG |
| M1 | IMPROVEMENT | Mobile table column prioritization - determine which columns to show/hide on small screens |
| X1 | IMPROVEMENT | Remove BETA badge |
| DC1 | COMMUNITY | Discord server for community coordination, admin requests, feedback |

**Website Requirements:**
- Digital Digimon aesthetic matching the app
- Static site (GitHub Pages or similar)
- Custom domain already set up (digilab.cards)

---

## Stores Tab Improvements (v0.20.1-v0.20.2) - COMPLETE

**Design:** `docs/plans/2026-02-08-stores-tab-improvements.md`

| ID | Type | Description |
|----|------|-------------|
| ST1 | DONE | Switch to Mapbox geocoding (replaces OSM/Nominatim) |
| ST2 | DONE | Store schedules schema (recurring day/time/event type) |
| ST3 | DONE | Weekly calendar view with schedule/all stores toggle |
| ST4 | DONE | Store modal improvements (mini map, two-column stats layout) |
| ST5 | DONE | Replaced Store Rating with Avg Player Rating (weighted Elo) |
| ST6 | DONE | Tiered bubble sizing based on avg event size |
| ST7 | DONE | Removed region filter (replaced by scene selection in v0.23) |

---

## Parking Lot

Items for future consideration, not scheduled:

| ID | Type | Description | Notes |
|----|------|-------------|-------|
| F2c | FEATURE | Error flagging | "Report Error" link in modals → creates admin notification |
| F8 | FEATURE | Embed widgets for stores | Let stores embed tournament history on their sites |
| P1 | FEATURE | Limitless TCG API deep integration | Beyond basic exploration in v0.23 |
| P2 | FEATURE | Discord bot for result reporting | Could integrate with user accounts system |
| P3 | FEATURE | Expand to other Texas regions | After multi-region foundation works |
| P4 | FEATURE | One Piece TCG support | Multi-game expansion |
| P5 | FEATURE | Mobile-first data entry PWA | Consider platform rewrite if scaling demands it |
| RA1 | FEATURE | Regional Admin role | Middle tier between Scene Admin and Super Admin, if needed |

---

## Removed / Won't Do

| Description | Reason |
|-------------|--------|
| Date range filtering on dashboard | Not needed - format filter is sufficient |
| Detailed player profile views | Modals already cover this |
| Detailed deck profile views | Modals already cover this |
| Matchup analysis (deck A vs deck B) | Revisit after v0.20 - will have round-by-round data |
| Event calendar page | Bandai TCG Plus already covers this |
| Store directory page | Bandai TCG Plus already covers this |
| Data export for users | Handle manually on request |
| Season/format archive view | Format filter already covers this |

---

## Completed

### v0.21.0 - Deep Linking & Shareable URLs
- Shareable URLs for players, decks, stores, tournaments
- Tab navigation via URL (`?tab=meta`, `?tab=about`, etc.)
- Scene parameter foundation (`?scene=dfw`)
- Copy Link button in all modal footers
- Browser back/forward support for modal navigation
- Schema: `slug` columns on stores and deck_archetypes
- Schema: `scenes` table with hierarchy for future multi-region

### v0.20.2 - Store Modal Polish & Map Improvements
- Store modal redesign: two-column layout (stats + mini map)
- Replaced Store Rating with Avg Player Rating (weighted Elo)
- Tiered bubble sizing based on avg event size
- Removed region filter (to be replaced by scene selection in v0.23)
- Text selection enabled in modals

### v0.20.1 - Store Schedules & Calendar
- Store schedules schema (recurring day/time/frequency)
- Admin UI for schedule management
- Weekly calendar view with schedule/all stores toggle
- Store modal mini map with interactive Mapbox display
- Mapbox geocoding (replaces OSM/Nominatim)

### v0.20.0 - Public Submissions & OCR
- Public "Upload Results" tab with screenshot-based submission
- Google Cloud Vision OCR integration for automatic data extraction
- Player pre-matching by member number and username
- Match history submission with tournament selector
- Image thumbnail previews for uploads
- Pre-declared player count validation
- GUEST ID handling (ignored)
- UI redesign with combined cards and compact layout

### v0.19.0 - Content Pages & UI Polish
- About, FAQ, For Organizers content pages
- Footer navigation with digital styling
- Seamless app frame (header/sidebar/footer)
- Hot Deck card image, Top Deck trophy icon
- Open Graph meta tags, favicon, GA4 tracking

### v0.18.1 - Code Cleanup Refactor
- Reactive value cleanup and documentation
- CSS cleanup - extracted 21 inline styles to classes
- ARCHITECTURE.md technical reference

### v0.18.0 - Server Extraction Refactor
- Extracted public page server logic into modular files
- Reduced `app.R` from 3,178 to 566 lines (~82% reduction)
- Standardized naming: `public-*` and `admin-*` prefixes

### v0.17.0 - Admin UX Improvements
- Edit Results modal from Edit Tournaments page
- Required date field validation
- Duplicate tournament flow improvements

### v0.16.1 - DigiLab Rebranding
- Custom domain: digilab.cards
- Google Analytics (GA4)
- Open Graph meta tags, branding assets

### v0.16.0 - UX Improvements & Modal Enhancements
- Manage Tournaments admin tab
- Overview click navigation
- Cross-modal navigation
- Database auto-refresh for admins

### v0.15.0 - Bug Fixes & Quick Polish
- Modal selection bug fix
- GitHub and Ko-fi links
- Meta %, Conv %, Record columns

### v0.14.0 - Rating System
- Competitive Rating (Elo-style)
- Achievement Score (points-based)
- Store Rating (weighted blend)

### v0.13.0 - Mobile UI Polish
- Responsive value boxes
- Smart filter layouts
- Mobile-optimized navigation

### v0.12.0 - Desktop Design Overhaul
- Digital Digimon aesthetic
- App-wide loading screen
- Modal stat boxes

*See CHANGELOG.md for full version history.*

---

## References

- **Bug Documentation:** `docs/solutions/`
- **Design Documents:** `docs/plans/`
- **Development Log:** `logs/dev_log.md`
- **User Feedback:** [Google Sheet](https://docs.google.com/spreadsheets/d/11ZeL7yZo7ee4rIdbGCCLvx_Om2VtvXtcj4U6WmH4bS8/edit?gid=0#gid=0)
