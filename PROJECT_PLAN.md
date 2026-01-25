# DFW Digimon TCG Tournament Tracker

**Project Plan & Technical Specification**  
Version 1.1 | January 2026

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

### 5.1 Tech Stack: R Shiny + DuckDB

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Frontend | R Shiny / shinydashboard | Interactive dashboards, reactive data binding |
| Database | DuckDB | Fast OLAP queries, embedded (no server), Parquet support |
| Visualization | ggplot2 / plotly / leaflet | Publication-quality charts, interactive maps |
| Data Entry | Shiny forms / Google Sheets | Simple input, mobile-friendly option |
| Hosting | shinyapps.io / Docker | Free tier available, easy deployment |
| Version Control | GitHub | Code storage, README, GitHub Pages for docs |

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

### 6.1 Phase 1: Foundation (Weeks 1-2)

1. Set up GitHub repository with README and project structure
2. Create DuckDB database schema with all tables (including archetype tables)
3. Populate initial store data for DFW area (5-10 stores)
4. Build basic R scripts to interact with DigimonCard.io API
5. Implement logging framework for development tracking
6. **Build initial deck_archetypes reference (~20-30 meta decks) with archetype_cards mappings**

### 6.2 Phase 2: Data Collection (Weeks 3-4)

1. Create Shiny form for manual tournament entry with archetype dropdown
2. Build archetype selection dropdown with card image preview
3. Collect historical data from 2-3 months of local events
4. Integrate Limitless TCG API for online tournament data (optional)
5. Set up automated data validation and error logging

### 6.3 Phase 3: Dashboard Development (Weeks 5-7)

1. Build main dashboard layout with shinydashboard
2. Create store map view with Leaflet (locations, activity heatmap)
3. Implement deck meta breakdown with boss monster images from display_card_id
4. Add player leaderboard and individual player profiles
5. Build "find decks using card X" search via archetype_cards
6. Implement change logs viewable within the application

### 6.4 Phase 4: Deployment & Polish (Weeks 8-9)

1. Deploy to shinyapps.io (free tier) or Docker container
2. Add authentication for data entry (optional)
3. Create comprehensive README and user documentation
4. Performance optimization and caching
5. Share with local community for feedback

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

## 8. Key Dashboard Features

### 8.1 Store Map & Directory

- Interactive Leaflet map showing all DFW stores hosting Digimon events
- Color-coded markers by activity level
- Click-through to store details (schedule, recent results)
- Filter by day of week, event type

### 8.2 Meta Analysis

- Deck archetype representation charts with boss monster images
- Win rate analysis by deck type
- Trend lines showing meta shifts over time
- "Find decks using card X" search via archetype_cards

### 8.3 Player Profiles

- Leaderboard ranked by tournament placements
- Individual player pages with match history
- Deck preferences and performance by archetype
- Head-to-head records (if match-level data collected)

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

- Expand to One Piece TCG and other Bandai games
- Add matchup analysis (deck A vs deck B win rates)
- Implement Elo-style player rating system
- Mobile-first data entry app (PWA)
- Discord bot for result reporting
- Expand to other Texas regions (Houston, Austin, San Antonio)
- Community-submitted archetype suggestions with approval workflow

---

## 11. Conclusion

This project fills a genuine niche as a regional community analytics platform - not competing with national meta analysis tools, but providing unique value through DFW-specific insights, store-level comparisons, and cross-venue player tracking.

The revised database schema with `deck_archetypes` and `archetype_cards` tables properly handles the complexity of community deck naming, enabling intuitive data entry (dropdown selection) and powerful queries ("find decks using card X").

**Next steps**: Review and approve this plan, then begin Phase 1 implementation with Claude Code.

---

## Appendices

### Appendix A: API Reference Links

- **DigimonCard.io**: https://documenter.getpostman.com/view/14059948/TzecB4fH
- **Limitless TCG**: https://docs.limitlesstcg.com/developer/tournaments
- **DigimonMeta**: https://digimonmeta.com/
- **DCG-Nexus**: https://dcg-nexus.com/
- **Egman Events**: https://egmanevents.com/digimon
- **Bandai TCG+**: https://www.bandai-tcg-plus.com/

### Appendix B: Example Archetype Reference Data

Sample entries for `deck_archetypes` table (current BT24 meta):

| Archetype Name | Display Card | Colors | Playstyle |
|----------------|--------------|--------|-----------|
| War OTK | BT12-070 | Red | aggro, otk |
| Jesmon GX | BT10-112 | Red/Yellow | combo, midrange |
| Blue Flare | BT10-030 | Blue | midrange, swarm |
| 7 Great Demon Lords | EX6-073 | Purple | control, combo |
| Royal Knights | BT13-019 | Yellow/Multi | midrange, toolbox |
| Imperialdramon | BT12-031 | Blue/Green | combo, otk |
| Leviamon | EX5-063 | Purple | control |

*A full archetype reference dataset (~20-30 decks) with archetype_cards mappings will be compiled during Phase 1 using current meta data from DigimonMeta and DCG-Nexus.*

### Appendix C: DFW Store Examples

Initial stores to track (to be expanded during Phase 1):

- **Common Ground Games** (Dallas) - Fridays 7:15pm, Saturdays 3:00pm
- Additional stores to be identified via Bandai TCG+ store locator

---

*Document Version: 1.1*  
*Last Updated: January 2026*
