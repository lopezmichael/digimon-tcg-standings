# DigiLab - Digimon TCG Tournament Tracker

**Project Plan & Technical Specification**
Version 2.0 | February 2026

> **Note**: This document has been updated to reflect the current implementation (v0.18.0). Original planning sections preserved for historical context.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Project Overview](#2-project-overview)
3. [Niche Analysis](#3-niche-analysis)
4. [Research Findings](#4-research-findings)
5. [Technical Architecture](#5-technical-architecture)
6. [Implementation Plan](#6-implementation-plan)
7. [Logging & Documentation Requirements](#7-logging--documentation-requirements)
8. [Key Dashboard Features](#8-key-dashboard-features)
9. [Risks & Mitigations](#9-risks--mitigations)
10. [Future Enhancements](#10-future-enhancements)
11. [Conclusion](#11-conclusion)
12. [Appendices](#appendices)

---

## 1. Executive Summary

This project plan outlines the development of a web application to track Digimon Trading Card Game (TCG) tournament results, player performance, store activity, and deck meta across the Dallas-Fort Worth (DFW) metropolitan area.

The primary goal is to create a centralized resource for the DFW Digimon TCG community that provides insights no existing national-level resource offers: regional store comparisons, cross-venue player tracking, and local meta analysis. The system is designed to be extensible to other Bandai TCG games in the future.

---

## 2. Project Overview

### 2.1 Problem Statement

The Digimon TCG community lacks a centralized, regional-specific tool for tracking tournament performance. Key challenges include:

- Bandai TCG+ (the official tournament app) has no public API
- Local tournament results are scattered across Discord servers and social media
- No way to track individual player progression or local meta trends
- Store schedules and tournament information are fragmented

### 2.2 Project Objectives

1. Build a comprehensive database schema to store stores, players, decks, tournaments, and results
2. Create a data entry interface for manual tournament result collection
3. Integrate with existing public APIs for card data and images
4. Develop an interactive web dashboard for data visualization and analysis
5. Include geographic mapping of stores and tournament activity
6. Implement comprehensive logging for project execution tracking

---

## 3. Niche Analysis

### 3.1 Existing Solutions Assessment

Several community resources already exist for Digimon TCG. Understanding what they do well clarifies where this project adds unique value:

| Resource | Strengths | Gaps |
|----------|-----------|------|
| **Limitless TCG** | Full API, tournament platform, standings, decklists | Only tracks events run through their platform; misses most local store events |
| **DCG-Nexus** | Live meta breakdown, community event submissions | Heavily Latin America focused; not comprehensive for US locals |
| **DigimonMeta** | High-quality deck guides, curated tournament reports | Editorial content, not a queryable database; no regional filtering |
| **Egman Events** | Archives of major tournaments, livestreams | Focuses on large events, not weekly local scenes |
| **Bandai TCG+** | Official source for all sanctioned events | No public API; data locked in app with no export |

### 3.2 The Genuine Niche

This project is **NOT** primarily a meta analysis tool - existing resources already do that well at the national/global level. Instead, this is a **regional community analytics and engagement platform** with capabilities no current solution provides:

- **Regional/Local Focus**: Answer questions like "Which DFW store has the most competitive field?" or "What's the DFW meta vs national meta?"
- **Store-Level Analytics**: Compare stores by attendance, competition level, and which decks perform best at specific locations
- **Cross-Venue Player Tracking**: Follow the same players across different local stores over time; track rivalries and improvement
- **Bandai TCG+ Data Liberation**: Extract value from tournament data that's otherwise locked in a closed system
- **New Player Onboarding**: Help newcomers find stores that match their skill level and schedule

### 3.3 Target Users

- Competitive local players wanting to track progress and scout rivals
- New players looking for where and when to play in DFW
- Store owners/TOs interested in their venue's competitive standing
- Community organizers building the local Digimon TCG scene

---

## 4. Research Findings

### 4.1 Available Data Sources

#### DigimonCard.io API

- **Endpoint**: `https://digimoncard.io/index.php/api-public/search`
- **Data**: Card names, numbers, colors, types, images, effects, set information
- **Rate Limit**: 15 requests per 10 seconds per IP
- **CORS**: Enabled for cross-origin requests
- **Documentation**: https://documenter.getpostman.com/view/14059948/TzecB4fH

#### Limitless TCG API

- **Base URL**: `https://play.limitlesstcg.com/api`
- **Endpoints**: `/tournaments`, `/tournaments/{id}/details`, `/standings`, `/pairings`
- **Authentication**: API key required (free registration)
- **Games**: Digimon TCG, Pokemon TCG, One Piece TCG, and others
- **Documentation**: https://docs.limitlesstcg.com/developer/tournaments

#### Bandai TCG+ App

> **Key finding**: No public API available. Data extraction requires manual entry. This is the primary reason for building this tool.

- Used by stores for official event registration and management
- Contains store locations, event schedules, and participant data
- Data locked in mobile app with no export capability

---

## 5. Technical Architecture

### 5.1 Tech Stack (Current Implementation)

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Frontend | R Shiny with bslib + atomtemplates | Modern Bootstrap 5, custom design system |
| Database | DuckDB (local) / MotherDuck (cloud) | Fast OLAP queries, cloud sync capability |
| Charts | Highcharter | Interactive JavaScript charts with theming |
| Maps | mapgl (Mapbox GL JS) | Modern vector maps with draw-to-filter |
| Tables | reactable | Interactive, sortable, filterable tables |
| Card Data | DigimonCard.io API (cached locally) | 4,200+ cards synced monthly |
| Hosting | Posit Connect Cloud | Professional R/Shiny hosting |
| Version Control | GitHub | Code storage, GitHub Actions for automation |

### 5.1.1 Server Module Architecture (v0.18.0+)

The application uses a modular server architecture with logic extracted into separate files:

```
server/
├── shared-server.R            # Database, navigation, auth helpers
├── public-dashboard-server.R  # Dashboard/Overview tab (889 lines)
├── public-stores-server.R     # Stores tab with map (851 lines)
├── public-players-server.R    # Players tab (364 lines)
├── public-meta-server.R       # Meta analysis tab (305 lines)
├── public-tournaments-server.R # Tournaments tab (237 lines)
├── admin-results-server.R     # Tournament entry wizard
├── admin-tournaments-server.R # Tournament management
├── admin-decks-server.R       # Deck archetype CRUD
├── admin-stores-server.R      # Store management
├── admin-players-server.R     # Player management
└── admin-formats-server.R     # Format management
```

### 5.2 Database Schema

#### `stores`

| Field | Type | Description |
|-------|------|-------------|
| store_id | INTEGER PK | Unique identifier |
| name | VARCHAR | Store name (e.g., Common Ground Games) |
| address | VARCHAR | Full street address |
| city | VARCHAR | City (Dallas, Fort Worth, etc.) |
| latitude | DECIMAL | GPS coordinate for mapping |
| longitude | DECIMAL | GPS coordinate for mapping |
| schedule_info | JSON | Tournament schedule details |
| tcgplus_store_id | VARCHAR NULL | Optional Bandai TCG+ reference |

#### `players`

| Field | Type | Description |
|-------|------|-------------|
| player_id | INTEGER PK | Unique identifier |
| display_name | VARCHAR | Player's preferred name/handle |
| tcgplus_id | VARCHAR NULL | Optional Bandai TCG+ membership ID |
| limitless_username | VARCHAR NULL | Optional Limitless TCG username |
| created_at | TIMESTAMP | First tracked date |

#### `deck_archetypes` (Reference Table)

> Community deck names often don't directly match card names (e.g., "War OTK" for Wargreymon-based aggro). This manually maintained table maps community names to associated cards.

| Field | Type | Description |
|-------|------|-------------|
| archetype_id | INTEGER PK | Unique identifier |
| archetype_name | VARCHAR | Community name (e.g., "War OTK", "Jesmon GX", "7DL") |
| display_card_id | VARCHAR | Card ID for icon/image display (DigimonCard.io) |
| primary_color | VARCHAR | Main deck color (Red, Blue, Yellow, Green, Purple, Black) |
| secondary_color | VARCHAR NULL | Optional secondary color for multi-color decks |
| playstyle_tags | JSON | Array: ["aggro", "otk", "control", "combo", "midrange"] |
| is_active | BOOLEAN | Whether deck is currently meta-relevant |
| notes | TEXT NULL | Optional description or strategy notes |

#### `archetype_cards` (Junction Table)

> Many-to-many relationship linking archetypes to their associated cards. Enables queries like "show all decks that use Greymon X" regardless of archetype name.

| Field | Type | Description |
|-------|------|-------------|
| archetype_id | INTEGER FK | Reference to deck_archetypes |
| card_id | VARCHAR | DigimonCard.io card number (e.g., BT12-070) |
| card_role | VARCHAR | Role: "boss", "engine", "support", "tamer", "tech" |
| is_core | BOOLEAN | TRUE if essential to archetype, FALSE if flex slot |

*Example: "War OTK" would link to Wargreymon (boss), Wargreymon X (boss), Marcus Damon (tamer), Greymon X (engine), etc.*

#### `tournaments`

| Field | Type | Description |
|-------|------|-------------|
| tournament_id | INTEGER PK | Unique identifier |
| store_id | INTEGER FK | Reference to stores table |
| event_date | DATE | Tournament date |
| event_type | VARCHAR | locals, regionals, evo_cup, store_championship |
| format | VARCHAR | Current set format (e.g., BT24) |
| player_count | INTEGER | Number of participants |
| rounds | INTEGER | Number of Swiss rounds played |
| limitless_id | VARCHAR NULL | Optional Limitless tournament ID |

#### `results`

| Field | Type | Description |
|-------|------|-------------|
| result_id | INTEGER PK | Unique identifier |
| tournament_id | INTEGER FK | Reference to tournaments |
| player_id | INTEGER FK | Reference to players |
| archetype_id | INTEGER FK | Reference to deck_archetypes |
| placement | INTEGER | Final standing (1st, 2nd, etc.) |
| wins | INTEGER | Match wins |
| losses | INTEGER | Match losses |
| ties | INTEGER | Match ties |
| decklist_json | JSON NULL | Optional full 50-card list if available |

#### `formats` (Added in Implementation)

| Field | Type | Description |
|-------|------|-------------|
| format_id | INTEGER PK | Unique identifier |
| format_code | VARCHAR | Format code (e.g., BT19, EX08) |
| name | VARCHAR | Display name |
| release_date | DATE | Set release date |
| is_current | BOOLEAN | Whether format is current |

#### `cards` (Added in Implementation)

| Field | Type | Description |
|-------|------|-------------|
| card_id | VARCHAR PK | DigimonCard.io card number (e.g., BT12-070) |
| name | VARCHAR | Card name |
| card_type | VARCHAR | Digimon, Tamer, Option |
| color | VARCHAR | Primary color |
| rarity | VARCHAR | Common, Uncommon, Rare, etc. |
| set_code | VARCHAR | Set identifier |
| image_url | VARCHAR | CDN URL for card image |
| ... | ... | Additional card attributes |

#### `ingestion_log` (Added in Implementation)

| Field | Type | Description |
|-------|------|-------------|
| log_id | INTEGER PK | Unique identifier |
| table_name | VARCHAR | Table that was modified |
| operation | VARCHAR | INSERT, UPDATE, DELETE |
| record_count | INTEGER | Number of records affected |
| timestamp | TIMESTAMP | When operation occurred |

### 5.3 Entity Relationship Diagram

```
stores (1) ──────< tournaments (1) ──────< results >────── players (1)
                                              │
                                              │
                                              ▼
                                    deck_archetypes (1)
                                              │
                                              │
                                              ▼
                                    archetype_cards >────── [Card API]
```

---

## 6. Implementation Plan

> **Note**: Original timeline preserved for historical context. Actual implementation completed over ~2 months with iterative development.

### 6.1 Phase 1: Foundation ✓ COMPLETE

1. ✓ Set up GitHub repository with README and project structure
2. ✓ Create DuckDB database schema with all tables (including archetype tables)
3. ✓ Populate initial store data for DFW area (13 stores)
4. ✓ Build R scripts to interact with DigimonCard.io API
5. ✓ Implement logging framework (CHANGELOG.md, dev_log.md)
6. ✓ Build initial deck_archetypes reference (25+ meta decks)

### 6.2 Phase 2: Data Collection ✓ COMPLETE

1. ✓ Create Shiny form for manual tournament entry with archetype dropdown
2. ✓ Build archetype selection dropdown with card image preview
3. ✓ Collect tournament data (ongoing)
4. ○ Limitless TCG API integration (planned for v0.21)
5. ✓ Set up automated data validation

### 6.3 Phase 3: Dashboard Development ✓ COMPLETE

1. ✓ Build main dashboard layout (bslib, not shinydashboard)
2. ✓ Create store map view with mapgl (Mapbox GL JS, not Leaflet)
3. ✓ Implement deck meta breakdown with boss monster images
4. ✓ Add player leaderboard and player modals
5. ✓ Build deck filtering and archetype management
6. ✓ Implement changelog and dev log documentation

### 6.4 Phase 4: Deployment & Polish ✓ COMPLETE

1. ✓ Deploy to Posit Connect Cloud (not shinyapps.io)
2. ✓ Admin authentication for data entry
3. ✓ Create comprehensive README and documentation
4. ✓ Performance optimization (card caching, modular server)
5. ✓ Live at https://digilab.cards/ with community feedback

### 6.5 Phase 5: Rating System ✓ COMPLETE (v0.14.0)

1. ✓ Competitive Rating (Elo-style with implied results)
2. ✓ Achievement Score (points-based)
3. ✓ Store Rating (weighted blend)
4. ✓ Ratings displayed in Overview, Players, and Stores tabs

### 6.6 Phase 6: Server Extraction Refactor ✓ COMPLETE (v0.18.0)

1. ✓ Extract public page server logic into modular files
2. ✓ Standardize naming convention (public-*, admin-*)
3. ✓ Reduce app.R from 3,178 to 566 lines (~82% reduction)

---

## 7. Logging & Documentation Requirements

### 7.1 Development Logs

- **CHANGELOG.md**: Semantic versioning log of all features, fixes, and changes
- **logs/dev_log.md**: Dated entries explaining development decisions and blockers
- **Git commit messages**: Following conventional commits format

### 7.2 Application Logs

- **Data ingestion logs**: Track API calls, data validation, errors
- **User activity logs**: Manual data entry actions (anonymized)
- **System health logs**: Performance metrics, error rates

### 7.3 Archetype Maintenance Log

- **data/archetype_changelog.md**: Records when archetypes are added, renamed, or retired
- Documents rationale for naming decisions
- Tracks which set release prompted archetype updates

### 7.4 README Requirements

The project README.md will include:

- Project overview and objectives
- Installation and setup instructions
- Data model documentation (including archetype system)
- API integration details
- Guide for adding new archetypes
- Contributing guidelines
- License information

---

## 8. Key Dashboard Features (Implemented)

### 8.1 Store Map & Directory

- Interactive mapgl (Mapbox GL JS) map showing all DFW stores
- Draw-to-filter region selection
- Click-through to store modals with details and recent results
- Store ratings based on tournament attendance and competition level
- Online Tournament Organizers section

### 8.2 Meta Analysis

- Deck archetype representation charts (Highcharter)
- Win rate and conversion rate analysis by deck type
- Meta share timeline showing shifts over time
- Color distribution chart
- Top decks grid with boss monster images

### 8.3 Player Profiles

- Leaderboard with Competitive Rating (Elo-style) and Achievement Score
- Player modals with match history and deck preferences
- Win/Loss/Tie records with color-coded display
- Cross-modal navigation (click player → see tournaments)

### 8.4 Tournament Tracking

- Tournament history with store, date, format, player count
- Tournament modals showing full standings
- Admin tools for adding/editing/duplicating tournaments
- Bulk result entry with decklist URL support

### 8.5 Dashboard Overview

- Value boxes with key stats (digital Digimon aesthetic)
- Recent tournaments and top players tables
- Meta share and conversion rate charts
- Top decks carousel with images

---

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Manual data entry burden | Incomplete data, user fatigue | Streamlined forms, Google Sheets option |
| API rate limits | Failed card image loads | Local caching, request throttling |
| Data accuracy | Incorrect results recorded | Validation rules, community verification |
| Player privacy concerns | Opt-out requests | Anonymous mode, data removal process |
| Archetype naming drift | Community names change | Archetype changelog, periodic review |
| New archetype tracking lag | New decks can't be recorded | "Other" option + quick-add workflow |

---

## 10. Future Enhancements

See `ROADMAP.md` for detailed version-by-version plans.

### Near-Term (v0.19-v0.21)

- **v0.19 - Onboarding & Help**: Contextual help, info icons, methodology pages
- **v0.20 - Self-Service**: Community suggestions, player merge tool, achievement badges
- **v0.21 - Multi-Region**: Region selector, geographic filtering, Limitless API exploration

### v1.0 - Public Launch

- Website landing page with about, methodology, weekly meta reports
- Mobile table column prioritization
- Remove BETA badge

### Long-Term (Parking Lot)

- Screenshot OCR for Bandai TCG+ results parsing
- Expand to One Piece TCG and other Bandai games
- Discord bot for result reporting
- Expand to other Texas regions (Houston, Austin, San Antonio)
- Mobile-first data entry PWA

---

## 11. Conclusion

This project has successfully launched as **DigiLab** at https://digilab.cards/, filling a genuine niche as a regional community analytics platform for the DFW Digimon TCG community.

### Achievements

- **Live Application**: Fully functional tournament tracking with 13 stores, 25+ deck archetypes, 4,200+ cards
- **Rating System**: Competitive Rating (Elo-style) and Achievement Score for player progression
- **Modern Tech Stack**: bslib + atomtemplates design system, Highcharter charts, mapgl maps
- **Clean Architecture**: Modular server extraction reduced app.R by 82%
- **Automated Pipelines**: Monthly card sync via GitHub Actions, MotherDuck cloud sync

### Next Milestone

**v0.19 - Onboarding & Help**: Contextual help and methodology documentation to improve user understanding.

---

## Appendices

### Appendix A: API Reference Links

- **DigimonCard.io**: https://documenter.getpostman.com/view/14059948/TzecB4fH
- **Limitless TCG**: https://docs.limitlesstcg.com/developer/tournaments
- **DigimonMeta**: https://digimonmeta.com/
- **DCG-Nexus**: https://dcg-nexus.com/
- **Egman Events**: https://egmanevents.com/digimon
- **Bandai TCG+**: https://www.bandai-tcg-plus.com/

### Appendix B: Deck Archetypes (25+ Meta Decks)

The `deck_archetypes` table is populated with 25+ competitive decks covering all colors. Sample entries:

| Archetype Name | Display Card | Colors | Playstyle |
|----------------|--------------|--------|-----------|
| War OTK | BT12-070 | Red | aggro, otk |
| Jesmon GX | BT10-112 | Red/Yellow | combo, midrange |
| Blue Flare | BT10-030 | Blue | midrange, swarm |
| 7 Great Demon Lords | EX6-073 | Purple | control, combo |
| Royal Knights | BT13-019 | Yellow/Multi | midrange, toolbox |
| Imperialdramon | BT12-031 | Blue/Green | combo, otk |
| Leviamon | EX5-063 | Purple | control |

*Archetypes are community-maintained via the Admin panel and updated as the meta evolves. See `scripts/seed_archetypes.R` for full dataset.*

### Appendix C: DFW Stores (13 Locations)

Currently tracking:

- Common Ground Games (Dallas)
- Cloud Collectibles
- The Card Haven
- Game Nerdz (Mesquite, Allen, Wylie)
- Andyseous Odyssey
- Boardwalk Games
- Lone Star Pack Breaks
- Eclipse Cards and Hobby
- Evolution Games
- Primal Cards & Collectables
- Tony's DTX Cards

Plus online tournament organizers for webcam events.

---

*Document Version: 2.0*
*Last Updated: February 2026*
