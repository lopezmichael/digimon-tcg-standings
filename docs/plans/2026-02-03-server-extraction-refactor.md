# Server Extraction Refactor

> **For Claude:** Use incremental chunks approach. Create branch `refactor/server-extraction`, extract one file at a time, verify after each, commit frequently.

**Goal:** Extract public page server logic from monolithic `app.R` into modular `server/public-*.R` files.

**Motivation:**
- Maintainability - easier to find and change code
- Onboarding - less intimidating for contributors
- Bug prevention - standardize patterns that have caused issues
- Future-proofing - cleaner base for multi-game expansion

---

## Scope

### In Scope
- Extract public page server logic from `app.R` into `server/public-*.R` files
- Rename `results-server.R` → `admin-results-server.R` for consistency
- Standardize navigation/modal patterns during extraction
- Reduce `app.R` to thin shell (~300-500 lines)

### Out of Scope (Future Tasks)
1. **Reactive value cleanup** - Document, group, standardize naming convention for `rv` (~30+ values)
2. **CSS cleanup** - Consolidate `custom.css`, remove inline styles from R code, organize by component

---

## Target Structure

```
server/
├── public-dashboard-server.R    # NEW - Dashboard tab
├── public-players-server.R      # NEW - Players tab
├── public-stores-server.R       # NEW - Stores tab
├── public-meta-server.R         # NEW - Meta tab
├── public-tournaments-server.R  # NEW - Tournaments tab
├── admin-results-server.R       # RENAMED from results-server.R
├── admin-tournaments-server.R   # existing
├── admin-decks-server.R         # existing
├── admin-stores-server.R        # existing
├── admin-formats-server.R       # existing
├── admin-players-server.R       # existing
└── shared-server.R              # existing
```

**`app.R` after refactor (~300-500 lines):**
- UI definition (page_navbar, sidebar, navset_hidden)
- Reactive values initialization
- `source()` calls to all server files
- Sidebar navigation observer
- Database connection setup
- Any truly shared/global logic

---

## Extraction Order

Extract simplest first to validate pattern before tackling complex files:

| Order | Task | To File | Est. Lines | Complexity |
|-------|------|---------|------------|------------|
| 1 | Meta tab logic | `public-meta-server.R` | ~150 | Low |
| 2 | Stores tab logic | `public-stores-server.R` | ~250 | Low |
| 3 | Tournaments tab logic | `public-tournaments-server.R` | ~200 | Low |
| 4 | Players tab logic | `public-players-server.R` | ~400 | Medium |
| 5 | Dashboard tab logic | `public-dashboard-server.R` | ~600 | Medium |
| 6 | Rename results-server.R | `admin-results-server.R` | 0 | Trivial |
| 7 | Final cleanup | Slim `app.R`, verify all sources | - | Low |

---

## Pattern Standardization

Fix these patterns during extraction:

### Navigation (correct pattern)
```r
nav_select("main_content", "target_tab")
rv$current_nav <- "target_tab"
session$sendCustomMessage("updateSidebarNav", "nav_target_tab")
```

### Modal Show (correct pattern)
```r
# Bootstrap modals defined in UI
shinyjs::runjs("$('#modal_id').modal('show');")

# Dynamic Shiny modals
showModal(modalDialog(...))
```

### Modal Hide (correct pattern)
```r
shinyjs::runjs("$('#modal_id').modal('hide');")
# or
removeModal()
```

### Null Coalescing
```r
value <- input$something %||% default_value
```

---

## Testing Strategy

### After Each Extraction
1. **Syntax check** - `source()` the new file
2. **App launch** - `shiny::runApp()` and verify:
   - App loads without errors
   - Extracted tab renders correctly
   - Navigation to/from tab works
   - Modals open/close properly
   - Cross-tab interactions work
3. **Commit** - If pass, commit to refactor branch

### Final Verification
- Full walkthrough of all tabs (public + admin)
- Test duplicate tournament flow
- Test cross-modal navigation (Overview → Players, etc.)
- Verify no console errors

### Merge Criteria
- All syntax checks pass
- Full app walkthrough works
- Manual confirmation from user
- Merge `refactor/server-extraction` → `main`

---

## Success Criteria

- [ ] App works identically after refactor
- [ ] Each `server/*.R` file is self-contained for one tab
- [ ] All navigation uses correct pattern
- [ ] `app.R` under 500 lines
- [ ] All files follow `public-*` / `admin-*` naming convention

---

## Current State (Pre-Refactor)

| File | Lines |
|------|-------|
| `app.R` | 3,178 |
| `server/` total | 3,357 |
| `views/` total | 1,645 |
| `R/` total | 800 |
| **Total** | **8,980** |

Target: `app.R` reduced to ~400 lines, with ~2,700 lines moved to `server/public-*.R` files.
