# Stores Tab Improvements Design

**Created:** 2026-02-08
**Status:** Planning
**Branch:** `feature/stores-improvements` (to be created)

---

## Overview

This document outlines planned improvements to the Stores tab and Edit Stores admin functionality, including geocoding fixes, schedule management, and UI enhancements.

---

## 1. Mapbox Geocoding (Immediate)

**Problem:** Current OSM/Nominatim geocoding via tidygeocoder produces inaccurate coordinates for some stores.

**Solution:** Switch to Mapbox Geocoding API (already have token for maps).

**Implementation:**
- Update `server/admin-stores-server.R` to use Mapbox API instead of `tidygeocoder::geo()`
- Create migration script to re-geocode all existing stores
- Mapbox endpoint: `https://api.mapbox.com/geocoding/v5/mapbox.places/{query}.json`

**Files:**
- `server/admin-stores-server.R` - Replace geocoding calls
- `scripts/migrate_geocode_stores.R` - One-time re-geocode script

---

## 2. Store Rating Adjustments (Future)

**Current Formula:**
| Component | Weight | Scale |
|-----------|--------|-------|
| Player Strength | 50% | Avg competitive rating (1200-2000 → 0-100) |
| Attendance | 30% | Avg tournament size (4-32 → 0-100) |
| Activity | 20% | Events in 6 months (0-24 → 0-100) |

**Potential Adjustments:**
- [ ] Adjust weights (TBD based on user feedback)
- [ ] Change time window (currently 6 months)
- [ ] Add recency weighting within the window
- [ ] Consider consistency bonus (regular weekly events)

**Files:**
- `R/ratings.R` - `calculate_store_ratings()` function

---

## 3. Store Schedules Schema (Future)

**Problem:** Current `schedule_info` is free-text, can't power an "Upcoming Tournaments" feature.

**Proposed Schema:**

```sql
-- New table for recurring store schedules
CREATE TABLE IF NOT EXISTS store_schedules (
    schedule_id INTEGER PRIMARY KEY,
    store_id INTEGER NOT NULL REFERENCES stores(store_id),
    day_of_week INTEGER NOT NULL,  -- 0=Sunday, 1=Monday, ..., 6=Saturday
    start_time TEXT NOT NULL,       -- "19:00" format (TEXT for DuckDB compatibility)
    event_type VARCHAR NOT NULL,    -- locals, evo_cup, etc.
    format VARCHAR,                 -- Optional: specific format if always the same
    frequency VARCHAR DEFAULT 'weekly',  -- weekly, biweekly, monthly, first_saturday, etc.
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_store_schedules_store ON store_schedules(store_id);
CREATE INDEX IF NOT EXISTS idx_store_schedules_day ON store_schedules(day_of_week);
```

**Frequency Options:**
- `weekly` - Every week on this day
- `biweekly` - Every other week
- `monthly` - Once a month on this day
- `first_saturday` - First Saturday of month
- `last_saturday` - Last Saturday of month

**Migration:**
- Add table to schema
- Parse existing `schedule_info` text where possible
- Keep `schedule_info` as backup/notes field

**Files:**
- `db/schema.sql` - Add table
- `scripts/migrate_store_schedules.R` - Migration script
- `server/admin-stores-server.R` - CRUD for schedules
- `views/admin-stores-ui.R` - Schedule management UI

---

## 4. Upcoming Tournaments Display (Future)

**Concept:** Show a table of expected upcoming tournaments based on store schedules.

**Location Options:**
1. New card at top of Stores tab (above map)
2. Separate "Calendar" or "This Week" section
3. Within store detail modal

**Proposed UI - Stores Tab:**
```
┌─────────────────────────────────────────────────────┐
│ Upcoming This Week                                  │
├─────────┬──────────┬─────────────────┬─────────────┤
│ Day     │ Time     │ Store           │ Type        │
├─────────┼──────────┼─────────────────┼─────────────┤
│ Wed 2/10│ 7:00 PM  │ Sci-Fi Factory  │ Locals      │
│ Thu 2/11│ 6:30 PM  │ Collected       │ Locals      │
│ Sat 2/13│ 2:00 PM  │ Madness Games   │ Locals      │
└─────────┴──────────┴─────────────────┴─────────────┘
```

**Logic:**
- Query `store_schedules` for next 7 days
- Handle frequency patterns (skip biweekly if not this week, etc.)
- Respect region filter if active

**Files:**
- `views/stores-ui.R` - Add upcoming tournaments card
- `server/public-stores-server.R` - Query and render logic

---

## 5. Store Modal Improvements (Future)

**Current Content:**
- Location info (city, address, website)
- Stats box (Store Rating, Events, Players, Avg Size, Last Event)
- Most popular deck ← REMOVE
- Recent Tournaments table
- Top Players table

**Proposed Changes:**

### 5a. Remove Most Popular Deck
- Delete the `popular_deck` query and UI section

### 5b. Add Mini Map
- Small static Mapbox map showing store pin
- Use Mapbox Static Images API: `https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/pin-s+F7941D({lng},{lat})/{lng},{lat},14,0/300x200@2x?access_token={token}`
- Or embed a small interactive mapgl

### 5c. Add Regular Schedule Section
- Show when this store typically has events
- Format for multiple events per week:

```
Regular Schedule
┌───────────┬──────────┬─────────┐
│ Day       │ Time     │ Type    │
├───────────┼──────────┼─────────┤
│ Wednesday │ 7:00 PM  │ Locals  │
│ Saturday  │ 2:00 PM  │ Locals  │
└───────────┴──────────┴─────────┘
```

**Files:**
- `server/public-stores-server.R` - Modal rendering logic

---

## 6. Map Bubble Sizing Alternatives (Future)

**Current:** Linear scale 8-20px based on tournament count relative to most active store.

**Alternatives to Consider:**

| Approach | Implementation | Pros | Cons |
|----------|---------------|------|------|
| Log scale | `8 + log(count + 1) * 4` | Better distribution | Less intuitive |
| Fixed tiers | 0=8, 1-3=12, 4-10=16, 11+=20 | Clear categories | Less granular |
| Recent activity | Last 3 months only | Shows current health | Ignores history |
| Attendance-based | Avg players instead of count | Shows popularity | New stores disadvantaged |
| Hybrid | Size=activity, color=recency | More info encoded | More complex |

**Decision:** TBD - gather feedback on current approach first.

**Files:**
- `server/public-stores-server.R` - Lines 779-783

---

## 7. Edit Stores Admin Updates (Future)

**Changes needed to support schedules:**

### 7a. Schedule Management UI
- Add "Schedules" section below main store form
- Table showing current schedules for selected store
- Add/Edit/Delete schedule entries
- Fields: Day of week (dropdown), Time (time input), Event type (dropdown), Frequency (dropdown)

### 7b. Form Layout
```
┌─────────────────────────────────────────────────────┐
│ Store Information                                   │
│ [Name] [City] [State] [Zip]                        │
│ [Address]                                          │
│ [Website] [Is Online checkbox]                     │
├─────────────────────────────────────────────────────┤
│ Regular Schedules                          [+ Add]  │
│ ┌─────────┬────────┬────────┬───────────┬────────┐ │
│ │ Day     │ Time   │ Type   │ Frequency │ Action │ │
│ ├─────────┼────────┼────────┼───────────┼────────┤ │
│ │ Wed     │ 7:00PM │ Locals │ Weekly    │ [Edit] │ │
│ │ Sat     │ 2:00PM │ Locals │ Weekly    │ [Del]  │ │
│ └─────────┴────────┴────────┴───────────┴────────┘ │
└─────────────────────────────────────────────────────┘
```

**Files:**
- `views/admin-stores-ui.R` - Schedule management UI
- `server/admin-stores-server.R` - Schedule CRUD handlers

---

## Implementation Order

1. **Immediate:** Mapbox geocoding + re-geocode existing stores
2. **Phase 2:** Store schedules schema + Edit Stores UI
3. **Phase 3:** Upcoming tournaments display
4. **Phase 4:** Store modal improvements (map, schedule display)
5. **Future:** Store rating adjustments, bubble sizing changes

---

## Open Questions

1. Should we keep the `schedule_info` free-text field as a notes field, or remove it entirely?
2. For biweekly schedules, how do we track which week is "on"?
3. Should the upcoming tournaments table be clickable (navigate to store modal)?
4. Do we need to handle special events (Evo Cups, Store Championships) differently from regular locals?

---

## References

- Store Rating methodology: `docs/plans/2026-02-01-rating-system-design.md`
- Current stores server: `server/public-stores-server.R`
- Current admin stores: `server/admin-stores-server.R`
- Mapbox Geocoding API: https://docs.mapbox.com/api/search/geocoding/
- Mapbox Static Images API: https://docs.mapbox.com/api/maps/static-images/
