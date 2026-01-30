# Value Box Redesign - Digital Digimon Aesthetic

**Date:** 2026-01-30
**Status:** Approved
**Branch:** `feature/value-box-redesign`

## Overview

Redesign the Overview page value boxes to capture an authentic Digimon TCG aesthetic, drawing inspiration from the card designs (EX1 retro grid patterns) and card backs (circuit/wireframe digital effects). Also restructure the filter UI into an integrated title strip.

## Goals

1. Transform generic blue value boxes into visually distinctive "Digital World" styled components
2. Make stats more dynamic and format-aware
3. Streamline the filter UI by integrating into a title strip
4. Add "Hot Deck" metric to show meta trends (with graceful fallback for limited data)

## Design References

Inspiration drawn from:
- **EX1 Gabumon card**: Grid pattern background, retro digital feel
- **Digimon card backs**: Circuit/wireframe patterns, glowing nodes, deep blue with cyan accents
- **Modern foiled cards**: Color-coded borders matching deck colors

## Structure

### Title Strip (replaces filter bar)

```
┌────────────────────────────────────────────────────────────────────┐
│  [icon] BT-19 Format · Locals          [Format ▼] [Event ▼]  ↺   │
└────────────────────────────────────────────────────────────────────┘
```

**Left side:** Dynamic context display showing current filter selections
**Right side:** Compact dropdowns (no labels) + reset icon button

Styling:
- Deep blue gradient background (matches value boxes)
- Subtle grid pattern overlay
- Height: ~48px
- Border-radius: 8px

### Value Box Grid (4 equal-width boxes)

```
┌─────────────┬─────────────┬─────────────┬─────────────┐
│ TOURNAMENTS │   PLAYERS   │  HOT DECK   │  TOP DECK   │
│     12      │     47      │  🔥 +8%     │ [card img]  │
│ this format │   unique    │  DeckName   │  DeckName   │
└─────────────┴─────────────┴─────────────┴─────────────┘
```

## Visual Styling

### Grid Pattern Overlay

Thin horizontal and vertical lines (10-15% opacity white) creating retro digital/pixel aesthetic:

```css
background:
  repeating-linear-gradient(0deg, rgba(255,255,255,0.08) 0px, transparent 1px, transparent 20px),
  repeating-linear-gradient(90deg, rgba(255,255,255,0.08) 0px, transparent 1px, transparent 20px),
  linear-gradient(135deg, #0A3055, #0F4C81);
```

### Circuit/Wireframe Accents

- Subtle glowing dots at grid intersections (data nodes)
- Faint diagonal circuit line through corners
- Soft glow effect on border (1-2px cyan/blue bloom)

### Color-Coded Left Borders

4px left border accent per box:
- **Tournaments**: Orange (#F7941D) - brand accent
- **Players**: Blue (#2D7DD2) - community vibe
- **Hot Deck**: Red (#E5383B) - heat/trending
- **Top Deck**: Green (#38A169) - success/top performer

## Value Box Content

### Box 1: Tournaments
- **Label**: "TOURNAMENTS" (small, uppercase)
- **Value**: Count of tournaments matching Format + Event Type filters
- **Subtitle**: "this format"

### Box 2: Players
- **Label**: "PLAYERS"
- **Value**: Count of distinct players in filtered tournaments
- **Subtitle**: "unique"

### Box 3: Hot Deck
- **Label**: "HOT DECK" with flame icon
- **Value**: Deck name with biggest meta share increase
- **Subtitle**: "+X% share" (trend indicator)
- **Fallback** (< 10 tournaments): "Tracking..." with pulse animation, or "Newest: [DeckName]"
- **Logic**: Compare meta share between older half and newer half of tournaments

### Box 4: Top Deck
- **Label**: "TOP DECK"
- **Value**: Most played deck archetype name
- **Showcase**: Card image (left side)
- **Subtitle**: "X% of meta" (optional)

## States & Responsive

### Hover States
- Subtle lift (translateY -2px)
- Enhanced border glow
- Grid pattern brightens slightly

### Dark Mode
- Minimal changes needed (already dark base)
- Grid lines remain white at low opacity
- Circuit glow shifts slightly more cyan

### Loading States
- Value shows "—" with subtle pulse
- Hot Deck fallback has more pronounced pulse

### Mobile (< 768px)
- Value boxes: 2x2 grid
- Grid pattern: Reduced density (30px spacing)
- Title strip: May stack to two rows
- Top Deck card image: Hidden on very small screens

## Implementation

### Files to Modify
1. `views/dashboard-ui.R` - Restructure value boxes, add title strip
2. `server/shared-server.R` - Add Hot Deck calculation, update outputs
3. `www/custom.css` - Grid pattern, circuit effects, title strip styles

### Implementation Order
1. Create branch `feature/value-box-redesign`
2. Add title strip (structure + basic styling)
3. Refactor value boxes to new layout
4. Implement grid/circuit CSS effects
5. Update Tournaments/Players to be format-filtered
6. Add Hot Deck logic with fallback
7. Test dark mode + responsive
8. Update documentation (CLAUDE.md, CHANGELOG.md, dev_log.md)

### Testing Checkpoints
- After step 3: Visual review of structure
- After step 4: Aesthetic matches design intent
- After step 6: Data displays correctly with filters
- After step 7: Works on mobile + dark mode

## Out of Scope

- Animated circuit lines (potential future enhancement)
- Value box click interactions (could link to filtered views later)
- Additional stats beyond the four defined
