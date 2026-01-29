# Shiny Input Width Fix for layout_columns

**Date:** 2026-01-28
**Problem:** Shiny inputs (textInput, selectInput, selectizeInput) overflow their `layout_columns` grid cells

## The Problem

When using bslib's `layout_columns()` with Shiny inputs, the inputs ignore the column width constraints and overflow/overlap adjacent columns.

```r
layout_columns(
  col_widths = c(5, 3, 2, 2),
  textInput("search", "Search"),      # Overflows!
  selectInput("filter", "Filter"),    # Overflows!
  ...
)
```

## Root Cause

Shiny sets `min-width: 300px` on `.shiny-input-container` elements by default. This prevents inputs from shrinking below 300px, regardless of CSS grid/flexbox constraints.

Additionally, selectize.js (used by selectInput) may have its own min-width settings.

## The Solution

Add CSS to override the min-width and force elements to respect grid boundaries:

```css
/* Force all filter elements to respect grid column boundaries */
.dashboard-filters .bslib-grid-item {
  min-width: 0 !important;
  max-width: 100%;
}

.dashboard-filters .shiny-input-container {
  width: 100% !important;
  max-width: 100% !important;
  min-width: 0 !important;
  box-sizing: border-box;
}

.dashboard-filters .selectize-control,
.dashboard-filters .selectize-input {
  width: 100% !important;
  max-width: 100% !important;
  min-width: 0 !important;
  box-sizing: border-box;
}
```

## Best Practice Pattern

1. **Use `layout_columns()` to control proportions** via `col_widths`
2. **Don't set `width` parameter** on Shiny inputs - let the grid handle sizing
3. **Add the CSS override** above to your custom.css

```r
# Good - let layout_columns handle sizing
layout_columns(
  col_widths = c(5, 3, 2, 2),
  textInput("search", "Search", placeholder = "..."),
  selectInput("format", "Format", choices = ...),
  selectInput("min_events", "Min Events", choices = ...),
  actionButton("reset", "Reset")
)
```

```r
# Avoid - width parameter often gets overridden anyway
textInput("search", "Search", width = "100%")  # Not needed
selectInput("format", "Format", width = "150px")  # May not work
```

## Key Insight

The `min-width: 0` rule is critical for CSS Grid and Flexbox children. By default, grid/flex items have `min-width: auto`, which prevents them from shrinking smaller than their content. Setting `min-width: 0` allows them to shrink to fit their allocated space.

## Debugging Tips

1. Right-click the input and Inspect
2. Look for `min-width` in the Computed styles
3. Check both the input element AND its parent `.shiny-input-container`
4. Selectize inputs have additional wrappers (`.selectize-control`, `.selectize-input`)
