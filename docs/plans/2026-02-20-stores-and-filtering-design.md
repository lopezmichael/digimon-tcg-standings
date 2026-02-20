# Stores Display & Filtering Enhancements Design

**Date:** 2026-02-20
**Status:** Approved
**Target Version:** v0.25+

## Overview

Three related enhancements to improve store/organizer visibility and filtering:

1. **Online Organizers Display** - Better presentation when "Online" scene is selected
2. **Community Links** - Store-specific filtering with shareable URLs
3. **Admin Scene Filtering** - Admin tables respect scene selection

---

## Feature 1: Online Organizers Display

### Problem

When the "Online" scene is selected on the Stores tab:
- Map shows DFW center with no markers (online stores have no coordinates)
- Schedule/All Stores views are empty or irrelevant
- Online organizers section shows at bottom, but it's the only relevant content

### Solution

**1.1 World Map with Region-Level Markers**

When "Online" scene is selected, replace the regional map with a world map:
- Each online organizer gets a marker based on their region
- Markers placed at regional coordinates (e.g., DMV Drakes near DC area, not just "USA" center)
- Clicking a marker opens that organizer's modal

**1.2 Consistent View Toggle: Schedule / Cards**

Replace "Schedule / All Stores" toggle with "Schedule / Cards" across ALL scenes:

| View | Physical Scenes | Online Scene |
|------|-----------------|--------------|
| Schedule | Weekly calendar of local events | Weekly calendar of online tournaments |
| Cards | Grid of store cards with stats | Grid of organizer cards with stats |

This provides consistency - users learn one pattern that works everywhere.

**1.3 Schema Change: Add Country Column**

```sql
ALTER TABLE stores ADD COLUMN country VARCHAR DEFAULT 'USA';
```

| Store Type | `country` | `city` | `state` |
|------------|-----------|--------|---------|
| Physical (USA) | "USA" (default) | "Dallas" | "TX" |
| Physical (international) | "Mexico" | "Mexico City" | NULL |
| Online organizer | "USA" | "DC/MD/VA" (region) | NULL |
| Online organizer | "Argentina" | NULL | NULL |
| Online organizer | "Brazil" | NULL | NULL |

**1.4 Coordinate Mapping for Online Organizers**

For map placement, we need coordinates for each online organizer's region. Options:
- Admin manually enters lat/lng when creating online store
- Lookup table mapping common regions to coordinates
- Auto-geocode from `city` (region) + `country` fields

Recommend: Lookup table for known regions, with manual override capability.

**Region Coordinate Lookup (seed data):**

| Country | Region | Latitude | Longitude |
|---------|--------|----------|-----------|
| USA | DC/MD/VA | 38.9 | -77.0 |
| USA | Texas | 31.0 | -97.0 |
| USA | (default) | 39.8 | -98.6 |
| Argentina | (default) | -34.6 | -58.4 |
| Brazil | (default) | -23.5 | -46.6 |

**1.5 Admin UI Updates**

- Add `country` dropdown to store creation/edit (default: "USA")
- For online stores: country is required, city becomes optional "region" label
- Consider auto-populating lat/lng from region lookup when country/city changes

---

## Feature 2: Community Links (Store-Specific Filtering)

### Problem

Organizers like Eagle's Nest want to share a link with their player base that shows their community's stats - not just the store modal, but filtered dashboards, player rankings, and meta analysis.

### Solution

**2.1 URL Parameter**

```
digilab.cards/?community=eagles-nest
```

The `?community=` parameter filters the entire app to a single store/organizer's data.

**2.2 Filtered Behavior by Tab**

| Tab | Filtered View |
|-----|---------------|
| Dashboard | Stats, charts, top decks, recent tournaments - all from this store's tournaments |
| Players | Players who've competed at this store, ranked by performance there |
| Deck Meta | Meta breakdown from this store's tournaments |
| Tournaments | Only this store's tournaments |
| Stores | No change - shows all stores in that store's scene (regional directory) |

**2.3 UI: Dismissible Banner**

When community filter is active, show a banner at the top of the content area:

```
┌─────────────────────────────────────────────────────────────┐
│ 📍 Showing data for Eagle's Nest                [View All] │
└─────────────────────────────────────────────────────────────┘
```

- Banner persists across tab navigation while filter is active
- "View All" clears the `?community=` param and returns to full scene view
- Banner is dismissible but reappears on navigation until filter is cleared

**2.4 Store Modal: Two Share Buttons**

Store modal footer updated with two buttons:

```
[ Copy Link ]  [ Share Community View ]                [ Close ]
```

- **Copy Link** - copies `?store=eagles-nest` (opens store modal)
- **Share Community View** - copies `?community=eagles-nest` (filtered dashboard)

**2.5 Technical Implementation**

- New reactive value: `rv$community_filter` (store slug or NULL)
- `?community=` and `?scene=` are mutually exclusive
  - Community filter implies the store's scene
  - Scene selector disabled or hidden when community filter active
- All data queries updated to check community filter:
  ```r
  if (!is.null(rv$community_filter)) {
    # Filter by store_id from community slug
  } else {
    # Use normal scene filtering
  }
  ```
- URL routing updated:
  - `open_entity_from_url()` handles `community` parameter
  - `update_browser_url()` preserves community filter
  - `clear_url_entity()` preserves community filter

---

## Feature 3: Admin Tables Filtered by Scene

### Problem

As DigiLab expands to multiple regions, different admins will manage different scenes. Admin tables currently show all data regardless of scene selection, which will become overwhelming and error-prone.

### Solution

**3.1 Filtering Logic**

| Admin Tab | Filter Method |
|-----------|---------------|
| Edit Stores | `WHERE stores.scene_id = ?` |
| Edit Tournaments | `JOIN stores ON tournaments.store_id = stores.store_id WHERE stores.scene_id = ?` |
| Edit Players | Players with ≥1 result at a store in the selected scene |

**3.2 Default Behavior**

- Admin tables respect the current scene selection from header dropdown
- "All Scenes" shows all data (current behavior, unchanged)
- Specific scene selection filters tables accordingly

**3.3 Super Admin Override**

Super admins (only) see a toggle to bypass scene filtering:

```
                                          ☐ Show all scenes
┌─────────────────────────────────────────────────────────────┐
│ Players Table                                    Filtered: DFW │
├─────────────────────────────────────────────────────────────┤
│ ...                                                         │
```

- Toggle is per-tab (not global)
- Resets on page refresh
- Regular scene admins don't see this toggle - locked to their scene

**3.4 Visual Indicator**

When scene filter is active on admin tables, show subtle indicator:
- `"Filtered to: DFW"` badge near table header
- Helps admins remember they're viewing a subset
- Disappears when "All Scenes" selected or override toggle checked

---

## Schema Changes Summary

```sql
-- Add country column to stores
ALTER TABLE stores ADD COLUMN country VARCHAR DEFAULT 'USA';

-- Update existing online stores with country data (migration)
UPDATE stores SET country = 'USA' WHERE limitless_organizer_id = 452;  -- Eagle's Nest
UPDATE stores SET country = 'USA' WHERE limitless_organizer_id = 559;  -- DMV Drakes
UPDATE stores SET country = 'Argentina' WHERE limitless_organizer_id = 281;  -- PHOENIX REBORN
UPDATE stores SET country = 'Brazil' WHERE limitless_organizer_id = 578;  -- MasterRukasu
```

---

## Implementation Order

**Phase 1: Schema & Data**
1. Add `country` column to stores table
2. Update existing online stores with country values
3. Update admin UI to include country field

**Phase 2: Online Organizers Display**
4. Create region-to-coordinates lookup
5. Update stores map to show world view for Online scene
6. Update online store markers to use region coordinates
7. Replace "All Stores" table view with "Cards" view
8. Apply Schedule/Cards toggle to all scenes

**Phase 3: Community Links**
9. Add `rv$community_filter` reactive value
10. Update URL routing to handle `?community=` parameter
11. Add community filter banner component
12. Update all data queries to respect community filter
13. Add "Share Community View" button to store modal

**Phase 4: Admin Scene Filtering**
14. Update Edit Stores query with scene filter
15. Update Edit Tournaments query with scene filter
16. Update Edit Players query with scene filter
17. Add "Show all scenes" toggle (super admin only)
18. Add "Filtered to: X" indicator on admin tables

---

## Open Questions (Resolved)

1. ~~How to handle multiple organizers in same country?~~ → Region-level placement
2. ~~What shows below map for Online scene?~~ → Schedule/Cards toggle (consistent with physical)
3. ~~Where to store country for online organizers?~~ → New `country` column
4. ~~URL parameter for community filter?~~ → `?community=store-slug`
5. ~~How to indicate community filter is active?~~ → Dismissible banner
6. ~~How to get community link?~~ → Second button in store modal
7. ~~How to filter Edit Players by scene?~~ → Players with results in scene
8. ~~Can admins override scene filter?~~ → Super admins only, via toggle

---

## Future Considerations

- **Store schedules for online organizers**: Online organizers have regular schedules too (e.g., "Wednesdays at 8pm EST"). The schedule view will work once schedule data is entered.
- **Community link analytics**: Track how often community links are used to measure organizer engagement.
- **Embedded widgets**: Future feature could let organizers embed their community stats on their own sites.
