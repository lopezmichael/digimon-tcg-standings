# Mobile UI Fixes Design

**Date:** 2026-01-31
**Target Device:** iPhone 14 Pro Max (430px width)
**Branch:** feature/ui-design-overhaul

## Overview

This document outlines mobile-specific UI fixes to improve the experience on phone-sized screens. Desktop UI remains unchanged unless specified.

---

## 1. App Rename

**Change:** "Digimon Locals Meta Tracker" → "Digimon TCG Tracker"

**Scope:** Global rename throughout the app
- Header title text
- Browser tab title
- Any other references

**Rationale:** Shorter name reduces header crowding on mobile, saves ~10 characters.

---

## 2. Mobile Navigation: Dropdown Menu

**Problem:** Sidebar pushes content to the right on mobile, creating awkward layout.

**Solution:** Conditional navigation - show sidebar on desktop, dropdown menu on mobile.

### Implementation

**Desktop (≥992px):**
- Keep existing sidebar with left-slide behavior
- No changes to current functionality

**Mobile (<992px):**
- Hide sidebar completely via CSS
- Add hamburger menu button in header (right side, before dark mode toggle)
- Clicking hamburger opens a dropdown nav menu below the header
- Menu contains same navigation links as sidebar
- Uses Bootstrap 5 collapse component (already loaded)

### HTML Structure (Mobile Nav)
```html
<div class="mobile-nav-container d-lg-none">
  <button class="mobile-nav-toggle" data-bs-toggle="collapse" data-bs-target="#mobile-nav">
    <icon: list/hamburger>
  </button>
</div>

<div id="mobile-nav" class="collapse mobile-nav-dropdown">
  <!-- Same nav links as sidebar -->
</div>
```

### CSS Approach
```css
/* Hide sidebar on mobile */
@media (max-width: 991px) {
  .bslib-sidebar-layout > .sidebar {
    display: none !important;
  }
}

/* Show mobile nav only on mobile */
.mobile-nav-container { display: none; }
@media (max-width: 991px) {
  .mobile-nav-container { display: block; }
}

/* Dropdown styling */
.mobile-nav-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: linear-gradient(135deg, #0A3055 0%, #0F4C81 100%);
  z-index: 1000;
  /* Similar styling to sidebar */
}
```

### Performance Impact
- Negligible - CSS media queries, no JavaScript computation
- Both nav elements exist in DOM, only one visible at a time (~1-2KB extra HTML)
- Uses Bootstrap's native collapse (already loaded)

---

## 3. Reset Button Placement

**Problem:** Reset button appears on its own row on mobile, wasting vertical space.

**Solution:** Keep reset button inline with the last filter dropdown using CSS.

### Implementation
```css
@media (max-width: 768px) {
  .title-strip-controls {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  /* Dropdowns take full width */
  .title-strip-select {
    flex: 1 1 100%;
  }

  /* Reset button stays with last item */
  .btn-title-strip-reset {
    flex: 0 0 auto;
    margin-left: auto;
  }
}
```

**Affected Pages:**
- Overview (dashboard)
- Players
- Meta Analysis
- Tournaments

---

## 4. Value Boxes Full Width

**Problem:** Value boxes only take ~50% of screen width on mobile instead of full width.

**Root Cause:** `layout_columns` with `col_widths = c(3, 3, 3, 3)` creates a 4-column grid that doesn't properly collapse on mobile. The existing CSS targets `.overview-value-boxes` but bslib's grid system may be overriding it.

**Solution:** Force the bslib grid to use 2-column layout on mobile with `!important` overrides.

### Implementation
```css
@media (max-width: 768px) {
  .overview-value-boxes .bslib-grid {
    display: grid !important;
    grid-template-columns: repeat(2, 1fr) !important;
    gap: 0.5rem !important;
  }

  .overview-value-boxes .bslib-grid > div {
    grid-column: span 1 !important;
    width: 100% !important;
  }
}
```

**Expected Result:** 2x2 grid of value boxes, each taking 50% width (full use of available space).

---

## 5. Stores Page Buttons

**Problem:** Apply and Clear buttons may wrap to separate rows on mobile.

**Solution:** Keep buttons on same row with `flex-wrap: nowrap` and allow them to shrink.

### Implementation
```css
@media (max-width: 768px) {
  .stores-filter-buttons {
    display: flex;
    flex-wrap: nowrap;
    gap: 0.5rem;
  }

  .stores-filter-buttons .btn {
    flex: 1 1 auto;
    min-width: 0;
    padding: 0.25rem 0.5rem;
    font-size: 0.8rem;
  }
}
```

May need to add a wrapper class or target `.title-strip-controls` on stores page specifically.

---

## 6. Tournament Summary Bar

**Problem:** Content overflows the styled box on mobile (store name, date, event type, players all in one row).

**Solution:** Stack into 3 rows on mobile.

### Mobile Layout
```
┌─────────────────────────────┐
│ 📍 Store Name               │
│ Jan 31, 2026                │
│ Locals · 8 Players          │
└─────────────────────────────┘
```

### Implementation

**Server-side (results-server.R):** No changes - keep same HTML structure.

**CSS:**
```css
@media (max-width: 768px) {
  .tournament-summary-bar {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.25rem;
  }

  .tournament-summary-bar .summary-divider {
    display: none;
  }

  /* Group the last two items (event type + players) */
  .tournament-summary-bar .summary-row-mobile {
    display: flex;
    gap: 0.5rem;
  }
}
```

**Alternative:** May need to modify server-side HTML to wrap items in row containers for better CSS control:
```r
div(
  class = "tournament-summary-bar",
  div(class = "summary-row", span(class = "summary-icon", ...), span(info$store_name)),
  div(class = "summary-row", span(format(date))),
  div(class = "summary-row", span(event_type), span("·"), span(players))
)
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `app.R` | Rename title, add mobile nav HTML |
| `www/custom.css` | All mobile CSS fixes |
| `server/results-server.R` | Tournament summary bar HTML structure (if needed) |

---

## Testing Checklist

- [ ] iPhone 14 Pro Max dimensions (430 x 932)
- [ ] Header shows "Digimon TCG Tracker" without overflow
- [ ] Mobile nav dropdown works and closes after selection
- [ ] Sidebar hidden on mobile
- [ ] Reset buttons inline with last dropdown on all filter pages
- [ ] Value boxes display as 2x2 grid using full width
- [ ] Store Apply/Clear buttons on same row
- [ ] Tournament summary bar readable without overflow
- [ ] Dark mode works correctly on mobile
- [ ] Desktop remains unchanged

---

## Implementation Order

1. App rename (quick, global impact)
2. Value boxes full width (CSS only)
3. Reset button placement (CSS only)
4. Store buttons (CSS only)
5. Tournament summary bar (CSS + possibly server)
6. Mobile navigation dropdown (most complex, save for last)
