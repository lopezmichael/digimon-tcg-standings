# DigiLab - Roadmap

This document outlines the planned features, improvements, and bug fixes for the tournament tracker.

**Current Version:** v0.21.0
**Target:** v1.0 Public Launch
**Cadence:** ~1 milestone per week

---

## v0.21.1 - Performance & Foundations

**Design:** `docs/plans/2026-02-17-performance-foundations-design.md`

Quick wins and foundational improvements to prepare for user accounts (v0.22) and multi-region (v0.23). No new features — focused on speed, security, resilience, and discoverability.

| ID | Type | Description |
|----|------|-------------|
| PF1 | PERFORMANCE | Remove forced 800ms loading delay after DB connection |
| PF2 | PERFORMANCE | Add `bindCache()` to all dashboard reactives (keyed by format + event type) |
| PF3 | PERFORMANCE | Pre-compute player ratings into cache table (recalc on result entry, not page load) |
| PF4 | PERFORMANCE | Lazy-load admin server modules behind `observeEvent(rv$is_admin)` |
| PF5 | SECURITY | Parameterize all SQL queries (replace sprintf/paste0 with `?` placeholders) |
| PF6 | RESILIENCE | Add `safe_query()` wrapper with tryCatch + graceful UI fallbacks |
| PF7 | SEO | Add `robots.txt` to digilab.cards wrapper |
| PF8 | SEO | Add `sitemap.xml` to digilab.cards wrapper |
| PF9 | SEO | Add `og:image` meta tag (branded 1200x630 social preview image) |
| PF10 | UX | Visibility-aware keepalive script (prevents timeout while tab is active) |
| PF11 | UX | Custom branded disconnect overlay with deep-link resume button |
| PF12 | UX | "Last updated" timestamp on dashboard |

**Technical Notes:**
- `bindCache()` cache key: format + event_type (+ scene_id in v0.23)
- Ratings cache table recomputed via trigger in admin-results-server after result submission
- Keepalive only fires when tab is visible (Page Visibility API) — avoids burning Posit Connect hours
- Disconnect overlay leverages existing deep linking (v0.21) to restore exact state on resume

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
| MR8 | SCHEMA | Add `tier` to tournaments table (local, regional, national, international) | Pending |
| MR9 | FEATURE | Player "home scene" inference (mode of tournament scenes played) | Pending |
| MR10 | FEATURE | Scene comparison page (DFW vs Houston side-by-side stats) | Pending |
| MR11 | FEATURE | Cross-scene badges in player modal ("Competed in: DFW, Houston, Austin") | Pending |
| MR12 | FEATURE | Scene health dashboard for Scene Admins (trends, retention, store activity) | Pending |
| MR13 | PERFORMANCE | Query builder abstraction for consistent scene filtering across all queries | Pending |
| MR14 | PERFORMANCE | Connection pooling via `pool` package | Pending |
| MR15 | PERFORMANCE | Batch dashboard queries (reduce from 8 separate to 2-3 combined) | Pending |
| MR16 | PERFORMANCE | Pre-computed dashboard stats cache table (recalc on data change) | Pending |
| MR17 | PERFORMANCE | Profile with `shinyloadtest` and size Posit Connect tier | Pending |
| L1 | FEATURE | Limitless API exploration for online tournament data | Deferred |

**Remaining:**
- Fix mobile header alignment (dark mode toggle, right alignment)
- Testing and QA

**Key Design Decisions:**
- Players don't belong to scenes (no accounts required for viewers)
- Stores belong to scenes; players appear on leaderboards based on where they've competed
- Rating is global; leaderboards are filtered views
- Scene Admins can only manage their assigned scene's data
- Player "home scene" inferred from tournament history (most-played scene)
- Scene comparison builds community rivalry and engagement

---

## v0.24 - Onboarding, Help & UX Polish

| ID | Type | Description |
|----|------|-------------|
| F7 | FEATURE | Contextual help — "Click a row for details" hint text above clickable tables |
| F7b | FEATURE | Info icons on Rating/Score column headers → link to FAQ methodology section |
| F7c | FEATURE | Light hints on admin pages explaining how to use each function |
| OH1 | FEATURE | First-visit scene selection modal (stored in localStorage) |
| OH2 | FEATURE | Guided tour for new users (optional, dismissible) |
| UX1 | UX | Player table minimum-events filter (5+ / 10+ / All, default 5+, pill buttons) |
| UX2 | UX | Global search bar in header (players, decks, stores, tournaments) |
| UX3 | UX | Player modal: rating trend sparkline (mini line chart) |
| UX4 | UX | Player modal: deck history (which decks they've played) |
| UX5 | UX | Deck modal: matchup matrix (win/loss vs top 5 other decks) |
| UX6 | UX | Deck modal: pilots leaderboard (best players of this deck) |
| UX7 | UX | Stores tab: "Next Event" prominently shown per store |
| UX8 | UX | Dashboard: community pulse ("3 tournaments this week, 47 active players") |
| UX9 | UX | Dashboard: new format callout banner when a new set drops |
| UX10 | UX | Custom GA4 events (track tab visits, filter usage, modal opens) |

---

## v0.25 - Self-Service Extras

| ID | Type | Description |
|----|------|-------------|
| I9 | FEATURE | Simple player merge tool — admin can merge duplicate players |
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
| P1 | FEATURE | Limitless TCG API deep integration | Beyond basic exploration in v0.23 |
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
