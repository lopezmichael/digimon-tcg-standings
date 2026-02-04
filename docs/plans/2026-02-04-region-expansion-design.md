# Region Expansion Design

**Date:** 2026-02-04
**Status:** Draft
**Target Version:** v0.21+

## Overview

Expand DigiLab from a single DFW-focused tool to support multiple regional communities while maintaining a cohesive global view. The primary goal is **community identity** - users should feel part of their local Digimon scene while being able to compare and connect with other regions.

## Goals (Priority Order)

1. **Community identity** - "I'm part of the DFW Digimon scene"
2. **Data comparison** - "How does DFW meta compare to Houston?"
3. **Competition context** - "How do I rank against local players?"
4. **Discovery** - "Where can I play near me?" (secondary)

## Core Design Decisions

### Players Don't Belong to Scenes

Without user accounts, we cannot ask players to self-identify their "home" scene. Players who travel (e.g., Austin visitors at a DFW tournament) would create edge cases.

**Solution:** Only Stores belong to Scenes. Players appear on leaderboards based on where they've competed.

### Nested Geographic Hierarchy

```
Global
└── Country (USA, Japan, etc.)
    └── State/Region (Texas, California, Kanto)
        └── Scene (DFW Digimon, Houston Tamers, Austin TCG)
            └── Stores (Sci-Fi Factory, Common Ground, etc.)
```

### Tournament Tiers

| Tier | Belongs To | Example |
|------|------------|---------|
| Local | Scene (host store's Scene) | Friday locals at Sci-Fi Factory |
| Regional | State/Region | Texas Regional (256 players) |
| National | Country | US Nationals |
| International | Global | World Championship |

Tournament tier is set when entering results. Most tournaments are "Local" by default.

## How It Works

### Rating System

- **Rating is global and consistent** - Every tournament affects your Elo regardless of where
- Playing in DFW, Houston, or Japan all contribute to the same rating
- No separate "scene ratings"

### Leaderboards

Leaderboards are **filtered views** of global ratings:

| View | Shows |
|------|-------|
| DFW Leaderboard | Players who have played DFW tournaments, sorted by global rating |
| Texas Leaderboard | Players who have played any Texas tournament (all Scenes + Regionals) |
| Global Leaderboard | All players everywhere |

**No minimum threshold** - Anyone who has played in a Scene appears on that leaderboard. Regulars naturally stand out through activity and results.

### Roll-ups

- View "DFW Digimon" → Local tournaments + players who competed in them
- View "Texas" → All Texas Scenes aggregated + Regional tournaments
- View "Global" → Everything, full map visualization

### Player History

A player's history always shows **all tournaments everywhere**. Scene filtering only affects leaderboards and meta analysis, not individual player records.

## Data Model Changes

### New: `scenes` Table

```sql
CREATE TABLE scenes (
  scene_id INTEGER PRIMARY KEY,
  name VARCHAR NOT NULL,           -- "DFW Digimon"
  display_name VARCHAR,            -- "Dallas-Fort Worth"
  parent_scene_id INTEGER,         -- FK to parent (Texas → DFW)
  scene_type VARCHAR NOT NULL,     -- 'global', 'country', 'state', 'metro'
  latitude DECIMAL,                -- Center point for map
  longitude DECIMAL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Modified: `stores` Table

```sql
ALTER TABLE stores ADD COLUMN scene_id INTEGER REFERENCES scenes(scene_id);
```

### Modified: `tournaments` Table

```sql
ALTER TABLE tournaments ADD COLUMN tier VARCHAR DEFAULT 'local';
-- Values: 'local', 'regional', 'national', 'international'
```

## User Experience

### First Visit

1. App detects approximate location (or asks)
2. Suggests nearest Scene: "Looks like you're in DFW. Show DFW Digimon?"
3. User confirms or selects different Scene
4. Preference saved in browser (localStorage)

### Default View

- All tabs filter to selected Scene by default
- Scene selector in header or filter bar for easy switching
- "All Scenes" / "Global" toggle always available

### Scene Switching

Options for UI placement:
1. **Header dropdown** - Always visible, quick switch
2. **Filter bar** - Alongside existing Format filter
3. **Dedicated selector** - More prominent for first-time users

### Global Map

- Shows all stores across all Scenes
- Stores colored/grouped by Scene
- Click store → see details, link to Scene
- Potential: Animation showing stores added over time

## Scene Creation & Management

### How Scenes Are Created

1. **Admin-only** initially - keeps quality controlled
2. Community requests via "Get Involved" page
3. Suggested threshold: 2-3 active stores before creating Scene

### Scene Request Flow

1. User fills out form: "Request a new Scene"
   - Proposed Scene name
   - City/metro area
   - Known stores in the area
   - Contact info
2. Admin reviews and creates if appropriate
3. Admin assigns existing stores to new Scene (if any)

### Admin UI

- Manage Scenes page (CRUD)
- Assign stores to Scenes
- Set tournament tiers
- View Scene health metrics (stores, tournaments, players)

## Migration Path

### Phase 1: Foundation

1. Create `scenes` table with hierarchy
2. Add initial Scenes: Global → USA → Texas → DFW Digimon
3. Assign all existing stores to "DFW Digimon"
4. Add `scene_id` to stores table
5. All existing functionality continues working (single Scene)

### Phase 2: Multi-Scene Support

1. Add Scene selector to UI
2. Update queries to filter by Scene
3. Implement leaderboard roll-ups
4. Add "All Scenes" toggle

### Phase 3: Expansion

1. Add "Request a Scene" form
2. Create additional Scenes as requested
3. Global map visualization
4. Cross-Scene comparison features

## Edge Cases

### Player Travels to Another Scene

- Their results appear in that Scene's tournament history
- They appear on that Scene's leaderboard
- Their global rating is affected
- Their player history shows all tournaments

### Tournament Draws from Multiple Scenes

- Regional tournaments (tier: 'regional') belong to State level
- Local tournaments always belong to host store's Scene
- Players from various Scenes all get credit

### Store Changes Scenes

- Rare, but possible (store moves, boundary adjustments)
- Historical tournaments stay with the Scene they were in at the time? Or move with store?
- **Decision:** Tournaments stay with their original Scene (immutable)

### Scene Becomes Inactive

- Keep Scene but mark inactive
- Historical data preserved
- Doesn't appear in Scene selector
- Stores can be reassigned to other Scenes

## Open Questions

1. **Scene naming** - Let communities name themselves, or standardize (e.g., "City + Digimon")?
2. **Scene boundaries** - Hard geographic boundaries or fuzzy? (Probably fuzzy, based on store assignment)
3. **Cross-Scene events** - How to handle a tournament that's explicitly "Texas-wide" but not a Regional?
4. **Rivalry features?** - "DFW vs Houston" comparison pages? (Future, if communities want it)

## Success Metrics

- Number of active Scenes
- Scene retention (do users stick with their Scene filter?)
- Cross-Scene engagement (do users explore other Scenes?)
- Community requests for new Scenes

## References

- Current roadmap: v0.21 Multi-Region Foundation
- Rating system: `docs/plans/2026-02-01-rating-system-design.md`
