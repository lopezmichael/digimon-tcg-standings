# Reactive Values Cleanup Design

**Goal:** Document, group, and standardize naming convention for reactive values (~32 values).

**Date:** 2026-02-03

---

## Current State

24 reactive values initialized in `app.R` plus ~8 additional values created dynamically in server files:

- Mixed purposes: auth, database, navigation, modals, forms, refresh triggers
- Some have comments, some don't
- No clear grouping or naming convention
- Values created ad-hoc in server files aren't documented
- Inconsistent naming (e.g., `selected_store_detail` vs `selected_player_id`)

---

## Design

### Categorization (6 Groups)

```r
rv <- reactiveValues(
  # === CORE ===
  db_con = NULL,
  is_admin = FALSE,

  # === NAVIGATION ===
  current_nav = "dashboard",
  navigate_to_tournament_id = NULL,

  # === MODAL STATE (selected_* pattern) ===
  selected_store_id = NULL,
  selected_online_store_id = NULL,
  selected_player_id = NULL,
  selected_archetype_id = NULL,
  selected_tournament_id = NULL,
  selected_store_ids = NULL,  # Map filter (plural = multiple)

  # === FORM/WIZARD STATE ===
  wizard_step = 1,
  active_tournament_id = NULL,
  current_results = data.frame(),
  duplicate_tournament = NULL,
  modal_tournament_id = NULL,
  editing_store = NULL,
  editing_archetype = NULL,
  card_search_results = NULL,
  card_search_page = 1,

  # === REFRESH TRIGGERS (*_refresh pattern) ===
  data_refresh = 0,
  results_refresh = 0,
  format_refresh = 0,
  tournament_refresh = 0,
  modal_results_refresh = 0,

  # === DELETE PERMISSION STATE ===
  can_delete_store = FALSE,
  can_delete_format = FALSE,
  can_delete_player = FALSE,
  can_delete_archetype = FALSE,
  store_tournament_count = 0,
  format_tournament_count = 0,
  player_result_count = 0,
  archetype_result_count = 0
)
```

### Naming Changes

| Old Name | New Name | Reason |
|----------|----------|--------|
| `selected_store_detail` | `selected_store_id` | Consistent with `selected_player_id` pattern |
| `selected_online_store_detail` | `selected_online_store_id` | Consistent with `selected_player_id` pattern |

### Documentation Strategy

Create `ARCHITECTURE.md` in project root containing:
- Server module structure and naming conventions
- Complete reactive values reference
- Navigation and modal patterns
- Database patterns

Update `CLAUDE.md` to reference ARCHITECTURE.md.

---

## Implementation Tasks

1. Create `ARCHITECTURE.md` with full documentation
2. Update `app.R` reactive values initialization (grouped, all 32 values)
3. Update server files to use renamed values
4. Update `CLAUDE.md` to reference ARCHITECTURE.md
5. Test the app
6. Commit and update ROADMAP

---

## Success Criteria

- [ ] All reactive values documented in ARCHITECTURE.md
- [ ] All values initialized explicitly in app.R (no ad-hoc creation)
- [ ] Consistent naming convention applied
- [ ] CLAUDE.md references ARCHITECTURE.md
- [ ] App works correctly after changes
