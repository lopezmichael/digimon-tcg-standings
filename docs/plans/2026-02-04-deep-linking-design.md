# Deep Linking Design

**Date:** 2026-02-04
**Status:** Draft
**Target Version:** v0.21+

## Overview

Enable shareable URLs that link directly to specific content within DigiLab. Users can share links to player profiles, deck archetypes, stores, and more. Links also enable bookmarking specific views (e.g., "DFW Meta analysis").

## Goals

1. **Shareability** - Copy a link, paste in Discord, recipient sees the same thing
2. **Bookmarkability** - Save a link to your local Scene's leaderboard
3. **Native feel** - Browser back button works as expected
4. **Graceful degradation** - Bad links land somewhere useful, not error pages

## URL Structure

### Linkable Entities

| Entity | URL Format | Behavior |
|--------|------------|----------|
| Player | `?player=atomshell` | Opens player modal |
| Deck | `?deck=blue-flare` | Opens deck modal on Meta tab |
| Store | `?store=sci-fi-factory` | Opens store modal |
| Tournament | `?tournament=123` | Opens tournament modal |
| Scene | `?scene=dfw` | Sets Scene filter, saves preference |
| Tab | `?tab=meta` | Navigates to specified tab |

### Valid Tabs

- `overview` (default)
- `players`
- `meta`
- `tournaments`
- `stores`
- `submit` (future)

### Identifier Format

**Hybrid approach - support both slugs and IDs:**

```
?player=atomshell       # Search by display_name (readable, shareable)
?player_id=123          # Direct lookup by ID (guaranteed unique)
```

- Social sharing uses slugs (human-readable)
- "Copy Link" button in modals uses IDs (reliable)
- Both resolve to the same content

### Combinations

Supported combinations:

```
?scene=dfw                          # Set Scene filter
?scene=dfw&tab=meta                 # Scene + specific tab
?scene=dfw&player=atomshell         # Scene context + player modal
?tab=players&player=atomshell       # Tab + modal
```

Processing order:
1. Set Scene filter (if present)
2. Navigate to tab (if present)
3. Open modal (if present)

## Slug Resolution

### Search Logic

For slug-based URLs (`?player=atomshell`):

1. **Exact match** on display_name/name → Open modal directly
2. **Multiple matches** → Navigate to tab with search pre-filled, user picks
3. **No match** → Navigate to tab with search pre-filled, show "No results"

### Entity-Specific Search Fields

| Entity | Search Field(s) |
|--------|-----------------|
| Player | `display_name` |
| Deck | `name`, `slug` (if we add slugs) |
| Store | `name`, `slug` (if we add slugs) |
| Tournament | ID only (no slug - names aren't unique) |
| Scene | `name`, `slug` |

### Generating Slugs

For entities that need slugs:

```r
# Simple slugify function
slugify <- function(text) {
  text |>
    tolower() |>
    gsub("[^a-z0-9]+", "-", x = _) |>
    gsub("^-|-$", "", x = _)
}

# "Sci-Fi Factory" → "sci-fi-factory"
# "Blue Flare" → "blue-flare"
# "DFW Digimon" → "dfw-digimon"
```

Slugs stored in database for stores, decks, scenes. Generated on creation, editable by admin.

## URL Updates

### When to Update URL

| Action | URL Update |
|--------|------------|
| Open player modal | `?player=atomshell` or `?player_id=123` |
| Open deck modal | `?deck=blue-flare` |
| Open store modal | `?store=sci-fi-factory` |
| Open tournament modal | `?tournament=123` |
| Change Scene filter | `?scene=dfw` |
| Navigate to tab | `?tab=meta` |
| Close modal | Remove entity param, keep scene/tab |

### History Management

Use `pushState` (not `replaceState`) so browser history tracks navigation:

```javascript
// Opening a modal adds to history
history.pushState({type: 'player', id: 123}, '', '?player=atomshell');

// Closing modal goes back
history.back(); // or pushState to base URL
```

### Browser Back Button

When user clicks back:
1. `popstate` event fires
2. JavaScript handler notifies Shiny
3. Shiny closes modal or restores previous state

## Implementation

### File Structure

```
server/
├── url-routing-server.R    # NEW - centralized URL logic
├── shared-server.R
└── ...

www/
├── url-routing.js          # NEW - browser history handling
└── custom.css
```

### url-routing-server.R (~150-200 lines)

```r
# Parse URL on app load
observe({
  query <- parseQueryString(session$clientData$url_search)

  # Set scene first (affects all other queries)
  if (!is.null(query$scene)) {
    set_scene_filter(query$scene)
  }

  # Navigate to tab
  if (!is.null(query$tab)) {
    nav_select("main_content", query$tab)
    rv$current_nav <- query$tab
  }

  # Open modal (player, deck, store, tournament)
  if (!is.null(query$player) || !is.null(query$player_id)) {
    open_player_from_url(query$player, query$player_id)
  }
  # ... similar for deck, store, tournament
})

# Function to update URL when modal opens
update_url_for_modal <- function(session, type, id = NULL, slug = NULL) {
  param <- if (!is.null(slug)) slug else id
  query <- paste0("?", type, "=", param)

  # Preserve scene if set
  if (!is.null(rv$current_scene)) {
    query <- paste0("?scene=", rv$current_scene, "&", type, "=", param)
  }

  session$sendCustomMessage("pushUrl", list(url = query))
}

# Function to handle slug search
resolve_player_slug <- function(slug) {
  # Query database
  matches <- dbGetQuery(db, "
    SELECT player_id, display_name
    FROM players
    WHERE LOWER(display_name) = LOWER(?)
  ", params = list(slug))

  if (nrow(matches) == 1) {
    return(list(found = TRUE, player_id = matches$player_id[1]))
  } else if (nrow(matches) > 1) {
    return(list(found = FALSE, multiple = TRUE, matches = matches))
  } else {
    return(list(found = FALSE, multiple = FALSE))
  }
}
```

### url-routing.js (~40-50 lines)

```javascript
// Listen for back/forward button
window.addEventListener('popstate', function(event) {
  Shiny.setInputValue('url_popstate', {
    state: event.state,
    timestamp: Date.now()
  });
});

// Handler for Shiny to push new URL
Shiny.addCustomMessageHandler('pushUrl', function(message) {
  history.pushState(message.state || {}, '', message.url);
});

// Handler to replace URL (no history entry)
Shiny.addCustomMessageHandler('replaceUrl', function(message) {
  history.replaceState(message.state || {}, '', message.url);
});
```

### Modal Handler Updates

Each modal open needs to call URL update:

```r
# In player modal handler (public-players-server.R)
observeEvent(input$player_row_clicked, {
  player_id <- input$player_row_clicked$player_id
  player_name <- input$player_row_clicked$display_name

  # Existing modal logic...
  showModal(player_modal(player_data))

  # NEW: Update URL
  update_url_for_modal(session, "player",
                       id = player_id,
                       slug = slugify(player_name))
})
```

### Copy Link Button

Add to each modal:

```r
# In modal UI
actionButton("copy_player_link", "Copy Link",
             icon = icon("link"),
             onclick = "copyCurrentUrl()")
```

```javascript
// In url-routing.js
function copyCurrentUrl() {
  navigator.clipboard.writeText(window.location.href);
  // Show toast notification
  Shiny.setInputValue('link_copied', Date.now());
}
```

## Database Changes

### Add Slug Columns

```sql
-- Stores
ALTER TABLE stores ADD COLUMN slug VARCHAR UNIQUE;

-- Deck archetypes
ALTER TABLE deck_archetypes ADD COLUMN slug VARCHAR UNIQUE;

-- Scenes (from region design)
-- Already has name, add slug
ALTER TABLE scenes ADD COLUMN slug VARCHAR UNIQUE;
```

### Generate Slugs for Existing Data

```sql
-- One-time migration
UPDATE stores SET slug = LOWER(REPLACE(REPLACE(name, ' ', '-'), '''', ''));
UPDATE deck_archetypes SET slug = LOWER(REPLACE(REPLACE(name, ' ', '-'), '''', ''));
```

## Edge Cases

### Multiple Players with Same Name

1. Search finds multiple matches
2. Navigate to Players tab with search pre-filled
3. Show message: "Multiple players found for 'atomshell'"
4. User clicks the one they want

### Entity Deleted

1. URL references deleted player/deck/store
2. Search returns no results
3. Navigate to appropriate tab
4. Show message: "Player not found"

### Scene in URL Doesn't Exist

1. Ignore invalid scene parameter
2. Use default scene (or last saved preference)
3. Continue processing rest of URL

### Modal Already Open

1. URL changes while modal is open
2. Close current modal
3. Open new modal from URL

## User Experience

### Sharing Flow

1. User views a player modal
2. URL automatically updates to `?player=atomshell`
3. User copies URL from browser (or clicks "Copy Link")
4. Pastes in Discord: "Check out this player's stats!"
5. Recipient clicks link → lands directly in player modal

### Bookmarking Flow

1. User sets Scene to "DFW Digimon"
2. Navigates to Meta tab
3. URL is now `?scene=dfw&tab=meta`
4. User bookmarks page
5. Next visit via bookmark → DFW Meta view loads directly

### Back Button Flow

1. User on Overview tab (URL: `/`)
2. Opens player modal (URL: `?player=atomshell`)
3. Clicks browser back
4. Modal closes, returns to Overview (URL: `/`)

## Testing Checklist

- [ ] Direct player link opens modal
- [ ] Direct deck link opens modal on Meta tab
- [ ] Direct store link opens modal
- [ ] Direct tournament link opens modal
- [ ] Scene parameter sets filter
- [ ] Tab parameter navigates correctly
- [ ] Combinations work (scene + tab + entity)
- [ ] Back button closes modal
- [ ] Forward button re-opens modal
- [ ] Copy Link button copies correct URL
- [ ] Invalid slug shows search results
- [ ] Multiple matches shows disambiguation
- [ ] No match shows empty state with message

## Future Enhancements

- **Short URLs** - `digilab.cards/p/atomshell` instead of query params
- **QR codes** - Generate QR for player profiles (for badges/events)
- **Social cards** - Open Graph tags update based on URL (player image, stats)

## References

- Region expansion: `docs/plans/2026-02-04-region-expansion-design.md`
- Shiny URL handling: https://shiny.rstudio.com/articles/client-data.html
