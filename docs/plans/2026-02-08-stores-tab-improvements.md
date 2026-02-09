# Stores Tab Improvements Design

**Created:** 2026-02-08
**Updated:** 2026-02-09
**Status:** In Progress
**Branch:** `feature/stores-tab-improvements`

---

## Overview

This document outlines planned improvements to the Stores tab and Edit Stores admin functionality, including geocoding fixes, schedule management, and UI enhancements.

**Core Goal:** Help users answer "What stores have events today/this week?" while preserving the ability to browse all stores with sorting options.

---

## Completed

### Mapbox Geocoding ✓

Switched from OSM/Nominatim to Mapbox Geocoding API for more accurate store coordinates.

- Added `geocode_with_mapbox()` helper to `server/admin-stores-server.R`
- Re-geocoded all existing stores
- Removed migration scripts after completion

---

## Phase 1: Store Schedules Schema

### Schema

Simplified schema focused on day/time (no event type tracking):

```sql
CREATE TABLE IF NOT EXISTS store_schedules (
    schedule_id INTEGER PRIMARY KEY,
    store_id INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,  -- 0=Sunday, 1=Monday, ..., 6=Saturday
    start_time TEXT NOT NULL,       -- "19:00" format (24-hour)
    frequency VARCHAR DEFAULT 'weekly',  -- weekly, biweekly, monthly
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_store_schedules_store ON store_schedules(store_id);
CREATE INDEX IF NOT EXISTS idx_store_schedules_day ON store_schedules(day_of_week);
```

**Notes:**
- One row per day/time slot (store with Wed + Sat events = 2 rows)
- No event_type - just tracking when stores run events
- Keep existing `schedule_info` on stores table as general notes field
- No FK constraint (DuckDB limitation - handle at app level)

**Frequency Options:**
- `weekly` - Every week on this day
- `biweekly` - Every other week (simplified: no tracking of which week)
- `monthly` - Once a month on this day

**Files:**
- `db/schema.sql` - Add table definition
- Migration script to create table in local DB

---

## Phase 2: Admin Schedule Management

Add schedule management to Edit Stores admin page.

### UI Layout

```
┌─────────────────────────────────────────────────────┐
│ Store Information                                   │
│ [Existing form fields...]                          │
├─────────────────────────────────────────────────────┤
│ Regular Schedule                           [+ Add]  │
│ ┌───────────┬──────────┬───────────┬─────────────┐ │
│ │ Day       │ Time     │ Frequency │ Actions     │ │
│ ├───────────┼──────────┼───────────┼─────────────┤ │
│ │ Wednesday │ 7:00 PM  │ Weekly    │ [Delete]    │ │
│ │ Saturday  │ 2:00 PM  │ Weekly    │ [Delete]    │ │
│ └───────────┴──────────┴───────────┴─────────────┘ │
│                                                     │
│ Add Schedule:                                       │
│ [Day ▼] [Time] [Frequency ▼] [Add]                 │
└─────────────────────────────────────────────────────┘
```

**Files:**
- `views/admin-stores-ui.R` - Schedule management UI
- `server/admin-stores-server.R` - CRUD handlers for schedules

---

## Phase 3: Stores Tab View Toggle

Replace single store list with toggle between two views.

### Layout

```
┌─────────────────────────────────────────────────────┐
│ [Map - unchanged]                                   │
├─────────────────────────────────────────────────────┤
│ [Schedule] [All Stores]  ← view toggle              │
├─────────────────────────────────────────────────────┤
│                                                     │
│ (Content changes based on selected view)            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Schedule View

Weekly calendar sorted starting from current day of week.

```
MONDAY (Today)
  Sci-Fi Factory · 7:00 PM          [clickable → modal]
  Collected · 6:30 PM

TUESDAY
  No scheduled events

WEDNESDAY
  Madness Games · 7:00 PM
  ...

────────────────────────────────────
Stores without regular schedules
  Game Store X, Game Store Y        [clickable → modal]
```

**Features:**
- Days sorted starting from today (Mon→Tue→Wed... if today is Monday)
- Click store name → opens store detail modal
- "Stores without regular schedules" section at bottom
- Online stores excluded from Schedule view
- Respects region filter if active

### All Stores View

Current store cards/list with sorting options.

**Features:**
- Shows ALL stores including online and those without schedules
- Sort by: Rating, Name, Activity, etc.
- Existing store card format with stats

**Files:**
- `views/stores-ui.R` - Add view toggle UI
- `server/public-stores-server.R` - Schedule view query and rendering

---

## Phase 4: Store Modal Improvements (Future)

### Add Regular Schedule Section

Show store's regular schedule in the detail modal:

```
Regular Schedule
┌───────────┬──────────┐
│ Day       │ Time     │
├───────────┼──────────┤
│ Wednesday │ 7:00 PM  │
│ Saturday  │ 2:00 PM  │
└───────────┴──────────┘
```

### Remove Most Popular Deck
- Delete the `popular_deck` query and UI section (low value)

### Add Mini Map (Optional)
- Small static Mapbox map showing store location
- Lower priority

**Files:**
- `server/public-stores-server.R` - Modal rendering logic

---

## Future Considerations

### Store Rating Adjustments
- Current: 50% player strength, 30% attendance, 20% activity
- Potential: Adjust weights, add recency weighting, consistency bonus
- Status: Gather feedback first

### Map Bubble Sizing
- Current: Linear scale 8-20px based on tournament count
- Alternatives: Log scale, fixed tiers, attendance-based
- Status: TBD

---

## Implementation Order

1. ✓ Mapbox geocoding
2. **Phase 1:** Store schedules schema (current)
3. **Phase 2:** Admin schedule management UI
4. **Phase 3:** Stores tab view toggle (Schedule / All Stores)
5. **Phase 4:** Store modal improvements

---

## Decisions Made

| Question | Decision |
|----------|----------|
| Keep `schedule_info` field? | Yes, as general notes (not tournament-specific) |
| Track event types? | No, just day/time |
| Handle multiple events/week? | Yes, one row per day/time slot |
| Calendar layout? | Week list sorted from today |
| Replace or add to store list? | View toggle - both Schedule and All Stores views |
| Online stores in schedule? | No, only in All Stores view |

---

## References

- Store Rating methodology: `docs/plans/2026-02-01-rating-system-design.md`
- Current stores server: `server/public-stores-server.R`
- Current admin stores: `server/admin-stores-server.R`
- Mapbox Geocoding API: https://docs.mapbox.com/api/search/geocoding/
