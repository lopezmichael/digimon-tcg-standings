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
