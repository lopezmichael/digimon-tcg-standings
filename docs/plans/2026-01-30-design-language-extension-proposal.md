# Design Language Extension Proposal

**Date:** 2026-01-30
**Status:** Draft Proposal
**Basis:** Value Box Redesign (v0.9.0)

## Overview

The digital Digimon aesthetic from the value box redesign creates a cohesive visual identity inspired by actual TCG card designs. This proposal explores how to thoughtfully extend this language to other UI elements without overwhelming the interface.

### Core Design Elements (from Value Boxes)

| Element | Purpose | Intensity |
|---------|---------|-----------|
| Grid pattern | Retro digital feel (EX1 cards) | Subtle (6-8% opacity) |
| Circuit accents | Digital World vibe (card backs) | Accent (corners, edges) |
| Glowing nodes | Data/connection points | Sparse (1-2 per component) |
| Color-coded borders | Visual categorization | 4px left border |
| Deep blue gradients | Cohesive base | Background |

### Design Philosophy

**Hero Elements (full treatment):** Value boxes, key metrics, featured content
**Supporting Elements (lighter touch):** Navigation, headers, cards
**Neutral Elements (minimal/none):** Forms, tables, modals

---

## Proposal 1: Header Bar Enhancement

**Current State:** Simple blue gradient, flat design
**Proposed:** Subtle grid overlay + circuit accent

```
┌────────────────────────────────────────────────────────────────┐
│  🥚 Digimon Locals Meta Tracker              [Admin] [🌙]  ·──●│
└────────────────────────────────────────────────────────────────┘
                                                         ↑
                                               Single circuit node
```

### Changes
- Add very subtle grid pattern (4% opacity, larger spacing ~30px)
- Single glowing node in top-right corner
- Faint circuit line along right edge
- Keep flat design for buttons/actions

### Rationale
The header is always visible - it should feel "digital" but not distract. The grid should be nearly imperceptible, just enough to tie it to the value boxes below.

---

## Proposal 2: Sidebar Navigation

**Current State:** Dark navy (#0A3055), flat nav links, orange active state
**Proposed:** Circuit-enhanced navigation with category indicators

### Option A: Circuit Connector Style
```
┌─────────────────────┐
│  [Digimon Logo]     │
├─────────────────────┤
│  ●─ Overview ←active│
│  ○─ Stores          │
│  ○─ Players         │
│  ○─ Meta Analysis   │
│  ○─ Tournaments     │
│                     │
│  ─── Admin ─────────│
│  ○─ Enter Results   │
│  ○─ Manage Decks    │
│  ○─ Manage Stores   │
│  ○─ Manage Formats  │
└─────────────────────┘
```

- Small circuit nodes (○) before each nav item
- Active item has glowing filled node (●)
- Vertical line connects nodes (circuit trace)
- Section dividers are horizontal circuit lines

### Option B: Minimal Enhancement
- Keep current flat design
- Add single vertical circuit line on left edge of sidebar
- Glowing node appears only on active item
- No changes to inactive items

### Recommendation
**Option B** - The sidebar is a utility element. Heavy theming would compete with content. A single vertical circuit line with glowing active indicator adds personality without distraction.

---

## Proposal 3: Admin Deck Management - Card Search/Preview

**Current State:** Generic bordered box with search input
**Proposed:** Digital "scanner" aesthetic

```
┌──────────────────────────────────────┐
│  DISPLAY CARD                        │
│  ┌─────────┐   ┌──────────────────┐ │
│  │         │   │ [Search Input]   │ │
│  │  Card   │   │ [Card ID]        │ │
│  │ Preview │   └──────────────────┘ │
│  │         │                        │
│  └────●────┘   ← circuit node       │
│                                      │
│  ┌──────────────────────────────────┐│
│  │ ╔═══╗ ╔═══╗ ╔═══╗ ╔═══╗        ││
│  │ ║   ║ ║   ║ ║   ║ ║   ║ Search ││
│  │ ╚═══╝ ╚═══╝ ╚═══╝ ╚═══╝ Results││
│  └──────────────────────────────────┘│
└──────────────────────────────────────┘
```

### Changes
- Card preview box gets subtle grid overlay (like scanning)
- "Selected" state has glowing border animation (brief pulse)
- Search results cards get hover glow effect
- Circuit node below preview (connection point)

### Interaction Enhancement
- When card is selected: Brief cyan glow pulse around preview
- Search results: Hover shows subtle cyan border
- Empty state: Animated "scanning" dots pattern

### Rationale
The card search is about finding the right visual representation for a deck. Making it feel like a "digital scanner" reinforces the Digital World theme and makes the interaction more engaging.

---

## Proposal 4: Page-Level Cards

**Current State:** Generic white cards with subtle shadows
**Proposed:** Tiered theming based on content importance

### Tier 1: Feature Cards (charts, key data)
- Subtle grid pattern in header only
- Single circuit node in top-right of header
- Current shadow/border styling

### Tier 2: Data Cards (tables, lists)
- No grid pattern
- Slightly enhanced border (1px with subtle glow on hover)
- Current styling otherwise

### Tier 3: Form Cards (inputs, admin)
- No changes - keep clean and functional
- Forms should be invisible, not themed

### Example: Top Decks Card
```
┌─────────────────────────────────────────────·──●
│  Top Decks (12 Tournaments)                    │
├─────────────────────────────────────────────────┤
│  [deck items with current styling]             │
└─────────────────────────────────────────────────┘
```

---

## Proposal 5: Filter Bars (Non-Dashboard)

**Current State:** Various layouts, some inconsistent
**Proposed:** Mini title strip style

The dashboard title strip works well. Consider adapting for other pages:

### Players Page
```
┌──────────────────────────────────────────────────────┐
│  📊 Player Standings    [Format ▼] [Min Events ▼] ↺ │
└──────────────────────────────────────────────────────┘
```

### Meta Analysis Page
```
┌──────────────────────────────────────────────────────┐
│  📊 Archetype Performance  [Format ▼] [Min ▼] 🔍 ↺  │
└──────────────────────────────────────────────────────┘
```

### Benefits
- Consistent filter UI across all pages
- Context always visible
- Compact, doesn't waste vertical space

---

## Proposal 6: Modals

**Current State:** Bootstrap default modals
**Proposed:** Light digital theming

### Changes
- Modal header: Subtle grid pattern (matches app header)
- Single circuit node in header corner
- No changes to modal body (keep clean)
- Footer buttons: Keep current styling

### Example: Delete Confirmation
```
┌─────────────────────────────────────────────·──●
│  ⚠️ Confirm Delete                              │
├─────────────────────────────────────────────────┤
│                                                 │
│  Are you sure you want to delete "Agumon"?     │
│  This deck has 5 tournament entries.           │
│                                                 │
├─────────────────────────────────────────────────┤
│                         [Cancel]  [Delete]      │
└─────────────────────────────────────────────────┘
```

---

## Implementation Priority

### Phase 1: High Impact, Low Risk
1. **Header grid overlay** - Single CSS change, big cohesion impact
2. **Sidebar circuit line** - Minimal change, ties navigation to theme
3. **Filter bars on other pages** - Adopt title strip pattern

### Phase 2: Feature Enhancement
4. **Card search scanner effect** - Makes admin more engaging
5. **Feature card headers** - Grid pattern on chart cards

### Phase 3: Polish
6. **Modal headers** - Subtle theming
7. **Hover effects** - Consistent glow on interactive elements

---

## What NOT to Theme

| Element | Reason |
|---------|--------|
| Form inputs | Should be invisible/functional |
| Table cells | Data should be clear, not decorated |
| Button interiors | Keep Bootstrap defaults for familiarity |
| Error messages | Red/warning colors should stand alone |
| Loading spinners | Already have good animation |

---

## Color Palette Reference

From value boxes (for consistency):

| Use | Color | Hex |
|-----|-------|-----|
| Grid lines | White | rgba(255,255,255, 0.06) |
| Circuit glow | Cyan | rgba(0, 200, 255, 0.4) |
| Node glow | Cyan | rgba(0, 200, 255, 0.6) |
| Active accent | Orange | #F7941D |
| Base dark | Navy | #0A3055 |
| Base medium | Blue | #0F4C81 |

---

## Open Questions

1. **Intensity level:** Should the grid be more or less visible than value boxes?
2. **Animation:** Add subtle animations (pulse on load, glow on hover)?
3. **Mobile:** Simplify/remove effects on mobile for performance?
4. **Dark mode:** Different glow intensity for dark mode?

---

## Next Steps

1. Review this proposal and pick which elements to pursue
2. Create design mockups or prototypes for chosen elements
3. Implement in phases, testing visual cohesion at each step
4. Consider A/B testing with users if uncertain

---

*This is a living document. Update as decisions are made.*
