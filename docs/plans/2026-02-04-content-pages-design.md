# Content Pages Design

**Date:** 2026-02-04
**Status:** Draft
**Target Version:** v0.19+

## Overview

Add informational content pages to help users understand DigiLab, learn how features work, and get involved with their local community. Pages are accessed via a styled footer bar that complements the header aesthetic.

## Goals

1. **Educate users** - Explain ratings, features, methodology
2. **Onboard new visitors** - What is this tool, who is it for
3. **Enable contribution** - How to submit results, add stores, request regions
4. **Maintain aesthetic** - Match the digital Digimon style throughout

## Page Structure

### Three Content Pages

| Page | Purpose | Key Content |
|------|---------|-------------|
| **About** | Introduction to DigiLab | What it is, who built it, coverage, vision |
| **FAQ** | Feature explanations | How to use, rating methodology, common questions |
| **For TOs** | Contribution guide | Submit results, add stores, request regions |

### Navigation

- Footer bar with styled links
- Pages are `nav_panel_hidden` (like other tabs)
- Deep-linkable: `?tab=about`, `?tab=faq`, `?tab=for-tos`
- Back navigation returns to previous tab

## Footer Design

### Aesthetic

Match the header's digital Digimon style:
- Dark background with subtle grid pattern
- Circuit line accent (top border)
- Cyan glow on hover
- Consistent typography

### Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ ── About ── FAQ ── For TOs ──────────────── v0.19 │ © 2026 ── │
└─────────────────────────────────────────────────────────────────┘
```

- Left: Navigation links with circuit dividers
- Right: Version number, copyright
- Mobile: Stack vertically or hide version/copyright

### CSS

```css
.app-footer {
  background: linear-gradient(135deg,
    rgba(15, 23, 42, 0.95),
    rgba(30, 41, 59, 0.95));
  border-top: 1px solid rgba(34, 211, 238, 0.3);
  padding: 0.75rem 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.85rem;
}

.app-footer::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 1px;
  background: linear-gradient(90deg,
    transparent,
    rgba(34, 211, 238, 0.5),
    transparent);
}

.footer-nav {
  display: flex;
  gap: 1.5rem;
}

.footer-link {
  color: rgba(255, 255, 255, 0.7);
  text-decoration: none;
  transition: all 0.2s ease;
  position: relative;
}

.footer-link:hover {
  color: #22d3ee;
  text-shadow: 0 0 8px rgba(34, 211, 238, 0.5);
}

.footer-link::after {
  content: '//';
  margin-left: 1.5rem;
  color: rgba(34, 211, 238, 0.3);
}

.footer-link:last-child::after {
  content: none;
}

.footer-meta {
  color: rgba(255, 255, 255, 0.4);
}
```

### R Implementation

```r
# In app.R, after navset_hidden closing
footer_ui <- tags$footer(
  class = "app-footer",
  tags$nav(
    class = "footer-nav",
    actionLink("nav_about", "About", class = "footer-link"),
    actionLink("nav_faq", "FAQ", class = "footer-link"),
    actionLink("nav_for_tos", "For TOs", class = "footer-link")
  ),
  tags$div(
    class = "footer-meta",
    paste0("v", APP_VERSION, " · © 2026 DigiLab")
  )
)
```

## About Page

### Content Structure

```
┌─────────────────────────────────────────┐
│ ABOUT DIGILAB                           │
│ ═══════════════                         │
│                                         │
│ [Hero section with digital styling]     │
│ "Track. Compete. Connect."              │
│                                         │
├─────────────────────────────────────────┤
│ WHAT IS DIGILAB?                        │
│ A regional tournament tracking tool...  │
│                                         │
├─────────────────────────────────────────┤
│ WHO IS IT FOR?                          │
│ • Players wanting to track progress     │
│ • TOs managing local scenes             │
│ • Community members following meta      │
│                                         │
├─────────────────────────────────────────┤
│ CURRENT COVERAGE                        │
│ [Map showing active Scenes]             │
│ • DFW Digimon - 12 stores, 150 players  │
│ • More regions coming soon...           │
│                                         │
├─────────────────────────────────────────┤
│ THE TEAM                                │
│ Built by [name], a DFW player who...    │
│                                         │
│ [GitHub] [Ko-fi] [Contact]              │
└─────────────────────────────────────────┘
```

### Key Elements

- Hero tagline with digital styling
- Quick "what/who/where" sections
- Live stats pulled from database (stores, players, tournaments)
- Mini map showing coverage
- Links to GitHub, Ko-fi, contact

## FAQ Page

### Content Structure

Accordion-based with expandable sections grouped by category.

```
┌─────────────────────────────────────────┐
│ FREQUENTLY ASKED QUESTIONS              │
│ ═══════════════════════════             │
│                                         │
│ ┌─ USING THE APP ─────────────────────┐ │
│ │ ▶ How do I find my local scene?     │ │
│ │ ▶ How do I see my tournament history│ │
│ │ ▶ What do the columns mean?         │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─ RATINGS & SCORES ──────────────────┐ │
│ │ ▶ How is Competitive Rating calc'd? │ │
│ │ ▶ What is Achievement Score?        │ │
│ │ ▶ How does Store Rating work?       │ │
│ │ ▶ Why did my rating go down?        │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─ DATA & COVERAGE ───────────────────┐ │
│ │ ▶ Where does the data come from?    │ │
│ │ ▶ Why isn't my tournament listed?   │ │
│ │ ▶ How often is data updated?        │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ ┌─ GENERAL ───────────────────────────┐ │
│ │ ▶ Is this an official Bandai tool?  │ │
│ │ ▶ How can I support DigiLab?        │ │
│ │ ▶ I found a bug, how do I report it?│ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Accordion Implementation

```r
faq_ui <- page_fillable(
  class = "content-page",

  tags$h1(class = "content-page-title", "Frequently Asked Questions"),

  # Using the App
  tags$h2(class = "faq-category",
          bsicons::bs_icon("display"), " Using the App"),
  accordion(
    id = "faq_using",
    open = FALSE,
    accordion_panel(
      title = "How do I find my local scene?",
      value = "find-scene",
      icon = bsicons::bs_icon("geo-alt"),
      tagList(
        p("Use the Scene selector at the top of the page to choose your region."),
        p("If your area isn't listed, check out the 'For TOs' page to learn how
           to request a new Scene.")
      )
    ),
    accordion_panel(
      title = "How do I see my tournament history?",
      value = "tournament-history",
      icon = bsicons::bs_icon("clock-history"),
      tagList(
        p("Navigate to the Players tab and search for your name."),
        p("Click on your row to open your player profile, which shows all
           your tournament results, deck history, and stats.")
      )
    )
    # ... more panels
  ),

  # Ratings & Scores
  tags$h2(class = "faq-category",
          bsicons::bs_icon("graph-up"), " Ratings & Scores"),
  accordion(
    id = "faq_ratings",
    open = FALSE,
    accordion_panel(
      title = "How is Competitive Rating calculated?",
      value = "competitive-rating",
      icon = bsicons::bs_icon("calculator"),
      tagList(
        p("Your Competitive Rating uses an Elo-style system that considers:"),
        tags$ul(
          tags$li("Your placement relative to other players"),
          tags$li("The ratings of players you placed above/below"),
          tags$li("Tournament size and competitiveness")
        ),
        p(class = "formula-box",
          "New Rating = Old Rating + K × (Actual - Expected)"),
        p("Where K is 32 for new players and 16 for established players."),
        p("See the ", actionLink("link_to_rating_design", "full methodology"),
          " for complete details.")
      )
    ),
    accordion_panel(
      title = "What is Achievement Score?",
      value = "achievement-score",
      icon = bsicons::bs_icon("trophy"),
      tagList(
        p("Achievement Score rewards consistent participation and strong finishes:"),
        tags$table(
          class = "achievement-table",
          tags$tr(tags$th("Placement"), tags$th("Points")),
          tags$tr(tags$td("1st"), tags$td("10")),
          tags$tr(tags$td("2nd"), tags$td("7")),
          tags$tr(tags$td("3rd-4th"), tags$td("5")),
          tags$tr(tags$td("5th-8th"), tags$td("3")),
          tags$tr(tags$td("9th-16th"), tags$td("1")),
          tags$tr(tags$td("Participation"), tags$td("1"))
        ),
        p("Bonus points for larger tournaments (16+, 32+ players).")
      )
    )
    # ... more panels
  )
  # ... more categories
)
```

### Styling for FAQ

```css
.content-page {
  max-width: 900px;
  margin: 0 auto;
  padding: 2rem;
}

.content-page-title {
  font-size: 1.75rem;
  color: #22d3ee;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin-bottom: 2rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid rgba(34, 211, 238, 0.3);
}

.faq-category {
  font-size: 1.1rem;
  color: rgba(255, 255, 255, 0.9);
  margin-top: 2rem;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.formula-box {
  font-family: 'Monaco', 'Consolas', monospace;
  background: rgba(34, 211, 238, 0.1);
  border-left: 3px solid #22d3ee;
  padding: 0.75rem 1rem;
  margin: 1rem 0;
}

.achievement-table {
  width: 100%;
  max-width: 300px;
  margin: 1rem 0;
  border-collapse: collapse;
}

.achievement-table th,
.achievement-table td {
  padding: 0.5rem 1rem;
  text-align: left;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.achievement-table th {
  color: #22d3ee;
  font-weight: 600;
}

/* Accordion styling overrides */
.accordion-button {
  background: rgba(30, 41, 59, 0.8) !important;
  color: rgba(255, 255, 255, 0.9) !important;
}

.accordion-button:not(.collapsed) {
  background: rgba(34, 211, 238, 0.1) !important;
  color: #22d3ee !important;
}

.accordion-body {
  background: rgba(15, 23, 42, 0.6);
  border-left: 2px solid rgba(34, 211, 238, 0.2);
}
```

## For TOs Page

### Content Structure

```
┌─────────────────────────────────────────┐
│ FOR TOURNAMENT ORGANIZERS               │
│ ═══════════════════════════             │
│                                         │
│ "Help grow your local Digimon scene"    │
│                                         │
├─────────────────────────────────────────┤
│ ▼ SUBMIT TOURNAMENT RESULTS             │
│   Step-by-step guide with screenshots   │
│   • Take screenshot from Bandai TCG+    │
│   • Go to Submit tab                    │
│   • Upload and verify                   │
│                                         │
├─────────────────────────────────────────┤
│ ▼ ADD YOUR STORE                        │
│   Request form or contact info          │
│   • Store name and location             │
│   • Tournament schedule                 │
│   • Contact person                      │
│                                         │
├─────────────────────────────────────────┤
│ ▼ REQUEST A NEW SCENE                   │
│   Requirements and process              │
│   • Minimum 2-3 active stores           │
│   • Consistent tournament activity      │
│   • Community organizer contact         │
│                                         │
├─────────────────────────────────────────┤
│ ▼ REPORT AN ERROR                       │
│   Found wrong data? Let us know         │
│   • Link to error report form           │
│   • What info to include                │
│                                         │
├─────────────────────────────────────────┤
│ CONTACT                                 │
│ [Email] [Discord] [GitHub Issues]       │
└─────────────────────────────────────────┘
```

### Key Sections

Each section is an accordion panel with detailed instructions:

1. **Submit Tournament Results**
   - Screenshots showing Bandai TCG+ results screen
   - Step-by-step upload process
   - What happens after submission (admin review)

2. **Add Your Store**
   - What information is needed
   - Form or contact method
   - Timeline expectations

3. **Request a New Scene**
   - Requirements (2-3 active stores)
   - What to include in request
   - How long it takes

4. **Report an Error**
   - What qualifies as an error
   - How to report
   - What happens next

## Implementation Plan

### File Structure

```
views/
├── about-ui.R           # NEW
├── faq-ui.R             # NEW
├── for-tos-ui.R         # NEW
└── ...

server/
├── content-pages-server.R   # NEW - navigation handlers
└── ...

www/
├── custom.css           # Add footer + content page styles
└── ...
```

### Database Queries for About Page

Pull live stats:

```r
# In about-ui.R or server
get_about_stats <- function(db) {
  list(
    total_stores = dbGetQuery(db, "SELECT COUNT(*) FROM stores WHERE is_active")[[1]],
    total_players = dbGetQuery(db, "SELECT COUNT(*) FROM players WHERE is_active")[[1]],
    total_tournaments = dbGetQuery(db, "SELECT COUNT(*) FROM tournaments")[[1]],
    active_scenes = dbGetQuery(db, "SELECT COUNT(*) FROM scenes WHERE is_active")[[1]]
  )
}
```

### Navigation Handlers

```r
# In content-pages-server.R
observeEvent(input$nav_about, {
  nav_select("main_content", "about")
  rv$current_nav <- "about"
})

observeEvent(input$nav_faq, {
  nav_select("main_content", "faq")
  rv$current_nav <- "faq"
})

observeEvent(input$nav_for_tos, {
  nav_select("main_content", "for_tos")
  rv$current_nav <- "for_tos"
})
```

## Mobile Considerations

### Footer

- Stack links vertically on very small screens
- Or use icon-only with tooltips
- Hide version/copyright to save space

```css
@media (max-width: 576px) {
  .app-footer {
    flex-direction: column;
    gap: 0.5rem;
    text-align: center;
  }

  .footer-link::after {
    content: none;
  }

  .footer-nav {
    gap: 1rem;
  }

  .footer-meta {
    font-size: 0.75rem;
  }
}
```

### Content Pages

- Accordions work well on mobile (native touch expand)
- Reduce padding on smaller screens
- Ensure formula boxes don't overflow

## Deep Linking Integration

Content pages support deep linking:

| URL | Behavior |
|-----|----------|
| `?tab=about` | Opens About page |
| `?tab=faq` | Opens FAQ page |
| `?tab=faq&section=competitive-rating` | Opens FAQ, expands specific section |
| `?tab=for-tos` | Opens For TOs page |

Section linking for FAQ:

```r
# On page load, check for section param
observe({
  query <- parseQueryString(session$clientData$url_search)
  if (!is.null(query$section)) {
    # Expand the specified accordion panel
    accordion_panel_open("faq_ratings", query$section)
  }
})
```

## Content Maintenance

### Where Content Lives

FAQ content embedded in R code for now. Future options:
- Markdown files parsed at runtime
- Database-driven content (admin editable)
- External CMS

### Update Process

1. Edit `views/faq-ui.R` (or other content file)
2. Redeploy app
3. Changes live immediately

## Testing Checklist

- [ ] Footer displays correctly on desktop
- [ ] Footer displays correctly on mobile
- [ ] About page loads with live stats
- [ ] FAQ accordions expand/collapse smoothly
- [ ] For TOs page has clear CTAs
- [ ] Deep links work for all content pages
- [ ] Back button returns to previous tab
- [ ] Styling matches app aesthetic
- [ ] Links to external resources work (GitHub, Ko-fi)

## Future Enhancements

- **Inline video tutorials** - Short clips showing how to use features
- **Interactive rating calculator** - "What if" tool for rating changes
- **Community spotlights** - Feature active TOs or players
- **Localization** - Translate content for non-English speakers

## References

- Deep linking: `docs/plans/2026-02-04-deep-linking-design.md`
- Region expansion: `docs/plans/2026-02-04-region-expansion-design.md`
- Rating system: `docs/plans/2026-02-01-rating-system-design.md`
