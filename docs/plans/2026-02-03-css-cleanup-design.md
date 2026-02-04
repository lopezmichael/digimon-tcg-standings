# CSS Cleanup Design

**Goal:** Move inline styles from R code to CSS classes for cleaner, more maintainable code.

**Date:** 2026-02-03

---

## Current State

- `custom.css`: 3,311 lines, 45 named sections (already well-structured)
- 38 inline styles across R files

## Scope

**Move to CSS (~28 styles):**
- Card search grid/items in admin-decks-server.R
- Card preview containers in admin-decks-ui.R
- Result action buttons in admin-results-server.R
- Top deck images in public-dashboard-server.R
- Deck modal images in public-meta-server.R
- Clickable rows in public-meta-server.R, public-tournaments-server.R
- Store filter badges in public-stores-server.R
- Map container in stores-ui.R

**Keep inline (~10 styles):**
- `display: none;` for Shiny toggle buttons (required for JS show/hide)
- Dynamic HTML colors (win/loss/tie in sprintf templates)
- One-off decorative spans

---

## New CSS Classes

### ADMIN DECK MANAGEMENT section (~line 2624)

```css
.card-search-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
  margin-top: 10px;
}

.card-search-item {
  background: #f8f9fa;
  border: 2px solid #ddd;
  border-radius: 6px;
  padding: 8px;
  text-align: center;
  cursor: pointer;
  transition: border-color 0.2s;
}

.card-search-item:hover {
  border-color: #0F4C81;
}

.card-search-thumbnail {
  width: 100%;
  max-width: 80px;
  height: auto;
  border-radius: 4px;
  display: block;
  margin: 0 auto;
}

.card-search-text-id {
  font-weight: bold;
  font-size: 11px;
  margin-top: 4px;
  color: #0F4C81;
}

.card-search-text-name {
  font-size: 9px;
  color: #666;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-search-text-color {
  font-size: 8px;
  color: #999;
}

.card-search-no-image {
  display: none;
  height: 60px;
  background: #eee;
  border-radius: 4px;
  line-height: 60px;
  text-align: center;
  font-size: 10px;
}

.card-search-pagination {
  padding: 2px 6px;
}

.card-preview-container {
  min-height: 150px;
  max-height: 200px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.card-search-results {
  min-height: 60px;
}
```

### TABLES section (~line 1234)

```css
.clickable-row {
  cursor: pointer;
}

.help-icon {
  cursor: help;
}
```

### TOP DECKS WITH CARD IMAGES section (~line 2566)

```css
.top-deck-image {
  height: 85px;
  width: auto;
  border-radius: 6px;
  object-fit: contain;
  box-shadow: 0 2px 8px rgba(0,0,0,0.2);
}

.deck-modal-image {
  width: 120px;
  height: auto;
}
```

### QUICK ADD FORMS section (~line 2738)

```css
.result-action-btn {
  width: 24px;
  height: 24px;
  line-height: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}
```

### MAPGL STYLING section (~line 1779)

```css
.map-container-flush {
  padding: 0;
}
```

### New section: FILTER BADGES

```css
.store-filter-badge {
  /* Base badge styles */
}

.store-filter-badge--success {
  background-color: rgba(22, 163, 74, 0.1);
  border-color: #16A34A;
  color: #166534;
}

.store-filter-badge--info {
  background-color: rgba(15, 76, 129, 0.1);
  border-color: #0F4C81;
  color: #0F4C81;
}
```

---

## Files to Update

1. `www/custom.css` - Add new classes to existing sections
2. `server/admin-decks-server.R` - Replace 12 inline styles
3. `views/admin-decks-ui.R` - Replace 4 inline styles
4. `server/admin-results-server.R` - Replace 2 inline styles
5. `server/public-dashboard-server.R` - Replace 1 inline style
6. `server/public-meta-server.R` - Replace 2 inline styles
7. `server/public-stores-server.R` - Replace 2 inline styles
8. `server/public-tournaments-server.R` - Replace 1 inline style
9. `views/stores-ui.R` - Replace 1 inline style

---

## Success Criteria

- [ ] All movable inline styles replaced with CSS classes
- [ ] CSS classes added to appropriate existing sections
- [ ] App works correctly after changes
- [ ] No visual regressions
