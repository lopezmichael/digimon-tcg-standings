# Archetype Maintenance Log

This log tracks changes to the `deck_archetypes` and `archetype_cards` tables, documenting when archetypes are added, renamed, retired, or modified.

---

## Format Guide

Each entry should include:
- **Date**: When the change was made
- **Action**: Added, Renamed, Retired, Updated
- **Archetype(s)**: Name(s) affected
- **Rationale**: Why the change was made
- **Set Context**: Which set release prompted the change (if applicable)

---

## 2026-01-25: Initial Setup

### Action: Schema Created
- Archetype system tables created (`deck_archetypes`, `archetype_cards`)
- No archetypes populated yet - pending Phase 1 data collection

### Planned Initial Archetypes (BT24 Meta)
The following archetypes will be added during Phase 1 based on current meta analysis:

| Archetype Name | Primary Color | Notes |
|----------------|---------------|-------|
| War OTK | Red | Wargreymon-based aggro/OTK |
| Jesmon GX | Red/Yellow | Combo/midrange |
| Blue Flare | Blue | Midrange/swarm |
| 7 Great Demon Lords | Purple | Control/combo |
| Royal Knights | Yellow | Midrange/toolbox |
| Imperialdramon | Blue/Green | Combo/OTK |
| Leviamon | Purple | Control |
| Numemon | Yellow | Control/stall |
| MagnaGarurumon | Blue | Aggro |
| Miragegaogamon | Blue | Midrange |
| Beelzemon | Purple | Aggro |
| Mastemon | Yellow/Purple | Control |
| Bloomlordmon | Green | Midrange |
| Fenriloogamon | Black | Combo |
| Magnamon X | Yellow | Midrange |

*Full archetype data with card mappings will be compiled using data from DigimonMeta.com and DCG-Nexus.com*

---

## Naming Conventions

1. **Use community-standard names** - Prioritize names commonly used in DFW locals and online discussion
2. **Avoid version numbers** - Use "War OTK" not "Wargreymon v3"
3. **Color prefixes only when necessary** - Only add color prefix if multiple color variants exist (e.g., "Blue Imperialdramon" vs "Green Imperialdramon")
4. **Abbreviations** - Use common abbreviations (7DL for Seven Great Demon Lords, RK for Royal Knights)

## Retirement Policy

Archetypes are marked `is_active = FALSE` (not deleted) when:
- No longer meta-relevant for 2+ set releases
- Replaced by a strictly better variant
- Community consensus name has shifted

Retired archetypes remain queryable for historical analysis.
