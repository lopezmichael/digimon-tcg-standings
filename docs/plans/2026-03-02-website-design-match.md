# DigiLab App Styling Update - Match New Website Design

**Date:** 2026-03-02
**Status:** Approved
**Branch:** `feature/website-design-match`

## Overview

Update the DigiLab Shiny app's header, footer, and overall aesthetic to match the redesigned marketing website (digilab.cards). The app will be embedded via iframe at app.digilab.cards, so styling should be cohesive.

## Goals

1. Simplify header with consolidated Help dropdown
2. Streamline footer with social links and minimal content
3. Remove redundant in-app content pages (About, FAQ, For Organizers) since website now handles these
4. Update typography to match website (Righteous font for branding)

## Design Details

### Header Updates

**Current state:**
- Logo links to dashboard via JS click handler
- Ko-fi button as separate header action
- No Help/menu dropdown

**New state:**

1. **Logo link**: Change to external link to `https://digilab.cards/` (opens in new tab)

2. **Remove**: Ko-fi button from header (moving to footer)

3. **Add Help dropdown** (positioned where Ko-fi was):
   - **Trigger**: Three-dots icon (⋮) with `header-action-btn` styling
   - **Contents**:
     - FAQ → `https://digilab.cards/faq` (external, new tab)
     - For Organizers → `https://digilab.cards/organizers` (external, new tab)
     - Roadmap → `https://digilab.cards/roadmap` (external, new tab)
     - *divider*
     - Report a Bug → Opens existing bug report modal
     - Request Store/Scene → Opens existing store request modal

4. **Keep unchanged**:
   - Version badge (cyan "v1.1.2" badge)
   - Scene selector dropdown
   - Dark mode toggle
   - Admin login button

5. **Typography**: Change header title font from Poppins to Righteous

### Footer Updates

**Current state:**
- Navigation links: About, FAQ, For Organizers, Report a Bug, GitHub
- Version + copyright + Welcome Guide (?)

**New minimal layout:**

```
[v1.1.2]    [GitHub] [Discord] [Ko-fi]    © 2026 DigiLab    [Privacy] [💡]
```

**Structure:**
- **Left**: Version number (e.g., "v1.1.2")
- **Center-left**: Social/support icon buttons
  - GitHub → `https://github.com/lopezmichael/digilab-app`
  - Discord → `https://discord.gg/ABcjha7bHk`
  - Ko-fi → `https://ko-fi.com/digilab`
- **Center**: Copyright "© 2026 DigiLab"
- **Right**:
  - Privacy Policy → `https://digilab.cards/privacy` (external link)
  - Welcome Guide → Lightbulb icon (opens onboarding modal)

**Remove:**
- About, FAQ, For Organizers links (now external via Help dropdown)
- Report a Bug link (moved to Help dropdown)
- The `//` dividers

### Remove In-App Content Pages

The website now has dedicated pages for this content, so remove from app:

**Files to delete:**
- `views/about-ui.R`
- `views/faq-ui.R`
- `views/for-tos-ui.R`

**Update `app.R`:**
- Remove `source()` calls for deleted view files
- Remove `nav_panel_hidden()` entries for "about", "faq", "for_tos"
- Remove footer navigation actionLinks

**Update `server/shared-server.R`:**
- Remove navigation observers: `nav_about`, `nav_faq`, `nav_for_tos`
- Remove About page stats outputs: `about_scene_count`, `about_store_count`, `about_player_count`, `about_tournament_count`
- Remove cross-page navigation observers: `about_to_for_tos`, `faq_to_for_tos`, `faq_to_for_tos2`, `faq_to_upload`, `faq_to_upload2`, `faq_to_upload3`
- Keep bug report modal (still used via Help dropdown)

**Update other files as needed:**
- Remove any remaining references to these pages in other server files

### Typography Updates

**Add Google Fonts:**
```html
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Righteous&display=swap" rel="stylesheet">
```

**Font usage:**
- **Righteous**: Header title "DigiLab" only
- **Inter**: Available for body text (atomtemplates may already handle this)

**CSS update in `www/custom.css`:**
```css
.header-title-text {
  font-family: 'Righteous', sans-serif;
  /* ... existing styles ... */
}
```

### Remove Outer Whitespace/Margins

**Issue:** The app has whitespace margins on all four sides from bslib's `page_fillable()` defaults. For seamless iframe embedding, these should be removed.

**CSS changes:**
```css
/* Remove outer padding from page_fillable */
.bslib-page-fill {
  padding: 0 !important;
}

/* Ensure header spans full width edge-to-edge */
.app-header {
  margin: 0;  /* Remove negative margin hack */
  width: 100%;
}

/* Ensure footer spans full width edge-to-edge */
.app-footer {
  margin: 0;  /* Remove negative margin hack */
  width: 100%;
}
```

**Goal:** Header and footer should touch all edges of the viewport with no visible gaps when embedded in an iframe.

### Color Tokens (Reference)

The app already uses the correct palette. No changes needed:

| Token | Value | Usage |
|-------|-------|-------|
| Primary | #0F4C81 | Digimon blue |
| Primary Dark | #0A3055 | Header, footer, sidebar |
| Accent | #F7941D | Orange highlights, active states |
| Digital | #00C8FF | Cyan circuit accents |

### Circuit Background

**Decision: Skip**

The app already has subtle grid patterns in header/footer/sidebar that provide a "digital" aesthetic. Adding animated canvas circuits would:
- Add unnecessary complexity
- Potentially impact Shiny performance
- Compete visually with existing patterns

## Implementation Checklist

### Phase 1: Header
- [ ] Update logo to external link (`https://digilab.cards/`, `target="_blank"`)
- [ ] Remove Ko-fi button from header
- [ ] Add Help dropdown with three-dots icon
- [ ] Add dropdown items (FAQ, For Organizers, Roadmap, divider, Report Bug, Request Store)
- [ ] Add Righteous font and update header title CSS
- [ ] Test mobile responsiveness of dropdown

### Phase 2: Footer
- [ ] Remove old navigation links and dividers
- [ ] Add version number (left)
- [ ] Add social icon buttons (GitHub, Discord, Ko-fi)
- [ ] Add copyright text (center)
- [ ] Add Privacy Policy external link
- [ ] Change Welcome Guide icon from ? to lightbulb
- [ ] Update footer CSS for new layout
- [ ] Test mobile responsiveness

### Phase 3: Remove Content Pages
- [ ] Delete `views/about-ui.R`
- [ ] Delete `views/faq-ui.R`
- [ ] Delete `views/for-tos-ui.R`
- [ ] Update `app.R` - remove source calls and nav panels
- [ ] Update `server/shared-server.R` - remove observers and outputs
- [ ] Search for and remove any remaining references
- [ ] Test that app loads without errors

### Phase 4: Remove Outer Whitespace
- [ ] Remove padding from `.bslib-page-fill`
- [ ] Update header margins to be truly edge-to-edge
- [ ] Update footer margins to be truly edge-to-edge
- [ ] Test in iframe context (or simulate with border)

### Phase 5: Cleanup & Testing
- [ ] Verify all external links work and open in new tabs
- [ ] Test Help dropdown on desktop and mobile
- [ ] Test bug report modal still works from dropdown
- [ ] Test store request modal still works from dropdown
- [ ] Test Welcome Guide modal opens from footer
- [ ] Verify dark mode styling for new elements
- [ ] Run app and check for console errors

## Links Reference

| Link | URL |
|------|-----|
| Website Home | https://digilab.cards |
| FAQ | https://digilab.cards/faq |
| For Organizers | https://digilab.cards/organizers |
| Roadmap | https://digilab.cards/roadmap |
| Privacy Policy | https://digilab.cards/privacy |
| Discord | https://discord.gg/ABcjha7bHk |
| Ko-fi | https://ko-fi.com/digilab |
| GitHub | https://github.com/lopezmichael/digilab-app |

## Notes

- All external links should use `target="_blank"` and `rel="noopener noreferrer"`
- The existing store/scene request modal will be reused (no new modal needed)
- The existing bug report modal will be reused
- Mobile hamburger menu behavior for Help dropdown: simple icon that shows dropdown on tap
