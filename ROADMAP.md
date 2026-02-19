# DigiLab - Roadmap

This document outlines the planned features, improvements, and bug fixes for the tournament tracker.

**Current Version:** v0.23.1
**Target:** v1.0 Public Launch
**Cadence:** ~1 milestone per week

---

## v0.22 - User Accounts & Permissions

**Design:** `docs/plans/2026-02-05-user-accounts-design.md`

| ID | Type | Description |
|----|------|-------------|
| UA1 | FEATURE | Discord OAuth login ("Login with Discord") via `httr2` |
| UA2 | FEATURE | Users table with Discord ID, username, role, scene assignment |
| UA3 | FEATURE | Permission levels: Viewer (default, no login), Scene Admin, Super Admin |
| UA4 | FEATURE | Scene Admin can manage data for their assigned scene only |
| UA5 | FEATURE | Super Admin can manage all data, users, and scenes |
| UA6 | FEATURE | Admin invite links (Super Admin generates link, recipient becomes Scene Admin) |
| UA7 | FEATURE | Direct user promotion (Super Admin promotes existing users) |
| UA8 | UI | Permission-scoped admin tabs (hidden unless logged in with appropriate role) |
| UA9 | SECURITY | Cookie-based session persistence (survives page refresh) |
| UA10 | SECURITY | Permission middleware — check auth at data level on every admin mutation |
| UA11 | SECURITY | `admin_actions` audit log table (who, what, when, before/after values) |
| UA12 | SECURITY | Rate limiting on admin mutations (prevent accidental bulk operations) |

**Technical Notes:**
- Discord OAuth is free and widely used in TCG communities
- localStorage for scene preference (no login required for viewers)
- Session management via secure HTTP-only cookies
- First Super Admin seeded via database during deployment
- Admin modules lazy-loaded after Discord OAuth confirms permissions (building on PF4)

---

## v0.23 - Multi-Region & Online Scene

**Design:** `docs/plans/2026-02-04-region-expansion-design.md`

| ID | Type | Description | Status |
|----|------|-------------|--------|
| MR1 | FEATURE | Scenes table with hierarchy (Global → Country → State → Metro) | Done (v0.21) |
| MR2 | FEATURE | Scene selector in header + first-visit modal | Done |
| MR3 | FEATURE | All tabs filter by selected scene | Done |
| MR4 | FEATURE | "Online" as special top-level scene for webcam/Discord tournaments | Done |
| MR5 | FEATURE | Leaderboards filtered by scene (players who competed there) | Done |
| MR6 | FEATURE | "All Scenes" / Global toggle for cross-region viewing | Done |
| MR7 | SCHEMA | Add `scene_id` to stores table | Done (v0.21) |
| MR8 | SCHEMA | Add `tier` to tournaments table (local, regional, national, international) | Deferred to v0.24+ |
| MR9 | FEATURE | Player "home scene" inference (mode of tournament scenes played) | Deferred to v0.24+ |
| MR10 | FEATURE | Scene comparison page (DFW vs Houston side-by-side stats) | Deferred to v0.24+ |
| MR11 | FEATURE | Cross-scene badges in player modal ("Competed in: DFW, Houston, Austin") | Deferred to v0.24+ |
| MR12 | FEATURE | Scene health dashboard for Scene Admins (trends, retention, store activity) | Deferred to v0.24+ |
| MR13 | PERFORMANCE | Query builder abstraction for consistent scene filtering across all queries | Done |
| MR14 | PERFORMANCE | Connection auto-reconnection in safe_query (pool not needed for embedded DuckDB) | Done |
| MR15 | PERFORMANCE | Batch dashboard queries (deck_analytics + core_metrics batch reactives) | Done |
| MR16 | PERFORMANCE | Pre-computed dashboard stats cache table (recalc on data change) | Deferred |
| MR17 | PERFORMANCE | Profile with `shinyloadtest` and size Posit Connect tier | Deferred |
| L1 | FEATURE | Limitless API exploration for online tournament data | Done (design doc) |

**v0.23 Additional Features (implemented):**
- Scene dropdown dynamically loaded from database
- Onboarding collapsed to single step (welcome + scene picker combined)
- Pill toggle filters on Players tab (5+/10+) and Deck Meta tab
- Dashboard split into format-specific and community sections
- Top Decks and Rising Stars clickable (open modals)
- Admin button → lock icon, Ko-fi → header
- Tab renamed: "Meta Analysis" → "Deck Meta"
- Historical format rating snapshots (frozen Elo at era boundaries)
- Mobile header alignment fixes

**Key Design Decisions:**
- Players don't belong to scenes (no accounts required for viewers)
- Stores belong to scenes; players appear on leaderboards based on where they've competed
- Rating is global; leaderboards are filtered views
- Connection pooling skipped — DuckDB is embedded (in-process), auto-reconnection is sufficient
- Historical ratings use date-cutoff Elo calculation, frozen as snapshots per format era

---

## v0.24 - Limitless Integration & UX Polish

**Design:** `docs/plans/2026-02-19-limitless-integration-design.md`

### Limitless TCG Online Tournament Sync

| ID | Type | Description |
|----|------|-------------|
| LI1 | SCHEMA | Add `limitless_organizer_id` to stores, create `limitless_deck_map` and `limitless_sync_state` tables |
| LI2 | FEATURE | Sync script (`scripts/sync_limitless.py`) — fetches tournaments, standings, pairings from Limitless API |
| LI3 | FEATURE | Player matching by `limitless_username`, auto-create new players from Limitless data |
| LI4 | FEATURE | Deck archetype mapping — known decks auto-mapped, unknown routed to deck request queue |
| LI5 | FEATURE | Format inference — regex parse from tournament name, date-based fallback from `formats` table |
| LI6 | DATA | Seed Tier 1 organizers: Eagle's Nest (452), PHOENIX REBORN (281), DMV Drakes (559), MasterRukasu (578) |
| LI7 | DATA | Initial historical sync (BT23 era onward, ~Oct 2025) |
| LI8 | FEATURE | GitHub Actions workflow for daily automated sync (`.github/workflows/sync-limitless.yml`) |
| LI9 | IMPROVEMENT | Enhance player merge tool — add matches transfer + `limitless_username` copy + ratings recalc |
| LI10 | FUTURE | Stores page adaptation for online organizers (Discord/YouTube links instead of address/map) |

**Tier 1 Organizers (launch):** Eagle's Nest (USA, 111 events), PHOENIX REBORN (Argentina, 146+ events), DMV Drakes (USA, 50+ events), MasterRukasu (Brazil, 44 events)

**Key Decisions:**
- Organizer = virtual store (`is_online = TRUE`, Online scene)
- `event_type = "online"` for all Limitless tournaments
- Online tournaments feed same Elo rating pool as locals
- Unmapped decks route through existing deck request queue
- No decklist storage (card-by-card data deferred)
- GitHub Actions daily cron for ongoing sync (mirrors `sync-cards.yml` pattern)

### Onboarding & Help

| ID | Type | Description |
|----|------|-------------|
| F7 | FEATURE | Contextual help — "Click a row for details" hint text above clickable tables |
| F7b | FEATURE | Info icons on Rating/Score column headers → link to FAQ methodology section |
| F7c | FEATURE | Light hints on admin pages explaining how to use each function |
| OH2 | FEATURE | Guided tour for new users (optional, dismissible) |
| UX2 | UX | Global search bar in header (players, decks, stores, tournaments) |
| UX3 | UX | Player modal: rating trend sparkline (mini line chart) |
| UX4 | UX | Player modal: deck history (which decks they've played) |
| UX5 | UX | Deck modal: matchup matrix (win/loss vs top 5 other decks) |
| UX6 | UX | Deck modal: pilots leaderboard (best players of this deck) |
| UX7 | UX | Stores tab: "Next Event" prominently shown per store |
| UX8 | UX | Dashboard: community pulse ("3 tournaments this week, 47 active players") |
| UX9 | UX | Dashboard: new format callout banner when a new set drops |
| UX10 | UX | Custom GA4 events (track tab visits, filter usage, modal opens) |

**Note:** OH1 (onboarding modal) and UX1 (player min-events filter) completed in v0.23.

---

## v0.25 - Self-Service Extras

| ID | Type | Description |
|----|------|-------------|
| I9 | DONE | Simple player merge tool — admin can merge duplicate players |
| F10 | FEATURE | Player achievement badges — auto-calculated, displayed in player modal |
| UX11 | UX | Player modal: head-to-head teaser ("Best record vs: PlayerX (3-0)") |
| UX12 | UX | Tournament table: result distribution mini-chart (top 3 deck colors inline) |

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
| W1 | FEATURE | Website landing page — about the tool, who it's for, geographic scope |
| W2 | FEATURE | Methodology pages — simple rating overview + detailed formula breakdown |
| W3 | FEATURE | Weekly Meta Report page — auto-generated from tournament data |
| SEO1 | SEO | Static landing pages outside iframe (crawlable About/FAQ for Google) |
| SEO2 | SEO | Structured data (JSON-LD) on wrapper site |
| SEO3 | SEO | Search Console integration |
| I7 | IMPROVEMENT | Replace header cards icon with Digivice SVG |
| M1 | IMPROVEMENT | Mobile table column prioritization |
| X1 | IMPROVEMENT | Remove BETA badge |
| DC1 | COMMUNITY | Discord server for community coordination, admin requests, feedback |
| ERR1 | RESILIENCE | Error tracking (Sentry R SDK or similar) |
| PWA1 | FEATURE | PWA manifest + service worker for mobile "install" and offline shell |

**Website Requirements:**
- Digital Digimon aesthetic matching the app
- Static site (GitHub Pages or similar)
- Custom domain already set up (digilab.cards)

---

## Post-v1.0 Decision Point: Platform Evaluation

After v1.0 launch data, evaluate whether to begin a Next.js migration based on:

| Question | If Yes → Next.js | If No → Stay Shiny |
|----------|------------------|---------------------|
| Is organic search traffic a growth priority? | SSR pages are crawlable | Word-of-mouth via Discord is enough |
| Hitting Posit Connect scaling limits? | Stateless architecture scales better | Caching solved the problem |
| Want standalone API for bots/tools? | API routes are native | Manual data sharing is fine |
| Want mobile app / PWA features? | Native strengths | Basic PWA on Shiny is sufficient |
| Multiple regions need fast edge loading? | CDN + edge rendering | Single-region performance is adequate |

The React PoC on `explore/react-rewrite` branch serves as a reference for future migration decisions.

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
| FD1 | IMPROVEMENT | Smart format default | Default to current format group instead of "All Formats" |
| F2c | FEATURE | Error flagging | "Report Error" link in modals → creates admin notification |
| F8 | FEATURE | Embed widgets for stores | Let stores embed tournament history on their sites |
| P1 | FEATURE | ~~Limitless TCG API deep integration~~ | Moved to v0.24 — design doc complete |
| P2 | FEATURE | Discord bot for result reporting | Could integrate with user accounts system |
| P3 | FEATURE | Expand to other Texas regions | After multi-region foundation works |
| P4 | FEATURE | One Piece TCG support | Multi-game expansion |
| P5 | FEATURE | Mobile-first data entry PWA | Consider after v1.0 platform evaluation |
| RA1 | FEATURE | Regional Admin role | Middle tier between Scene Admin and Super Admin |
| UX13 | UX | Distance-based store sorting | Sort stores by proximity using localStorage scene |
| UX14 | UX | Tournament "upcoming" section | Show future events from store schedules above recent results |

---

## Removed / Won't Do

| Description | Reason |
|-------------|--------|
| Date range filtering on dashboard | Not needed — format filter is sufficient |
| Detailed player profile views | Modals already cover this |
| Detailed deck profile views | Modals already cover this |
| Matchup analysis (deck A vs deck B) | Revisit after v0.20 — will have round-by-round data |
| Event calendar page | Bandai TCG Plus already covers this |
| Store directory page | Bandai TCG Plus already covers this |
| Data export for users | Handle manually on request |
| Season/format archive view | Format filter already covers this |
| GitHub Action keepalive ping | Burns Posit Connect hours 24/7 for minimal benefit |
| Aggressive idle timeout increases | Wastes Posit Connect hours on zombie sessions |

---

## Completed

### v0.23.1 - Multi-Region, Polish & Performance
- Scene selector with dynamic DB loading, onboarding modal, localStorage persistence
- Geolocation "Find My Scene" support
- Scene filtering across all tabs
- Dashboard split: format-specific meta + community health sections
- Dashboard layout: removed Top Players table, rearranged into Meta Diversity + Recent Tournaments row
- Player Growth chart switched from monthly to weekly granularity
- Meta Share chart uses percent stacking (always sums to 100%)
- Overview modals open in-place instead of switching tabs
- Pill toggle filters on Players and Deck Meta tabs
- Top Decks and Rising Stars clickable (open modals)
- Historical format rating snapshots (frozen Elo at era boundaries)
- Batched dashboard queries (deck_analytics + core_metrics)
- Connection auto-reconnection, clean shutdown handler
- Admin lock icon, Ko-fi to header, tab rename to "Deck Meta"
- Release events auto-assign UNKNOWN deck archetype (sealed packs)
- Mobile navbar: scene selector wraps to own row, circuit line preserved, whitespace reduced
- XSS prevention: HTML-escape database-sourced strings in dashboard and player tables
- Event type filter defaults and display formatting fixes

### v0.21.1 - Performance & Security Foundations
- SQL parameterization for all public queries (security)
- safe_query() wrapper for graceful error handling (resilience)
- bindCache() on dashboard outputs (performance)
- Pre-computed ratings cache tables (performance)
- Faster loading: removed delays, lazy-load admin modules
- Library audit: removed 5 unused packages from startup
- Visibility-aware keepalive, custom disconnect overlay (UX)
- SEO: robots.txt, sitemap.xml, og:image meta tags

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
