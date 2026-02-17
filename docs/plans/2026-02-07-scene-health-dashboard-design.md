# Scene Health Dashboard Section

**Date:** 2026-02-07
**Status:** Approved
**Version Target:** v0.21 or later

## Overview

Add a "Scene Health" section to the dashboard that visualizes competition health metrics. This helps organizers and players understand whether the local scene is thriving, growing, and competitively balanced.

## Motivation

With sufficient tournament data now collected, we can provide meaningful insights beyond just "what decks are popular." Scene health metrics answer:
- Is the meta diverse or dominated by 1-2 decks?
- Is the player base growing or shrinking?
- Are events well-attended?
- Is competition spread across many players or dominated by a few?

## Design

### Placement

The Scene Health section appears after the Top Decks card and before the existing charts row (Conversion Rate, Color Distribution, Player Counts).

### Layout

```
┌─────────────────────────────────────────────────────────────┐
│  SCENE HEALTH                                               │
├──────────────────────────┬──────────────────────────────────┤
│  ┌──────────┬──────────┐ │  Player Growth & Retention       │
│  │ Meta     │ Event    │ │  [Stacked area chart]            │
│  │ Diversity│ Health   │ │  - New / Returning / Regulars    │
│  │ [gauge]  │ [trend]  │ │  - By month                      │
│  │ 78/100   │ 14.2 avg │ │                                  │
│  │ 12 decks │ ↑ +18%   │ │                                  │
│  └──────────┴──────────┘ │                                  │
├──────────────────────────┴──────────────────────────────────┤
│  Competitive Balance                                        │
│  [Horizontal bar chart - Top 15 players by wins]            │
│  "12 different winners across 45 tournaments"               │
└─────────────────────────────────────────────────────────────┘
```

### Components

#### 1. Meta Diversity Gauge (Compact)

**Purpose:** Show how concentrated or spread out the meta is.

**Calculation:**
- Use normalized Herfindahl-Hirschman Index (HHI) based on deck win shares
- HHI = sum of squared market shares (0 to 1)
- Diversity Score = (1 - HHI) * 100 (inverted so higher = more diverse)
- Score of 100 = perfectly even distribution
- Score near 0 = one deck dominates everything

**Visual:**
- Semi-circular gauge with color zones:
  - Red (0-40): Unhealthy, dominated meta
  - Yellow (40-70): Moderate diversity
  - Green (70-100): Healthy, diverse meta
- Large score number in center
- Subtitle: "X decks with wins"

**Query Logic:**
```sql
SELECT archetype_id,
       COUNT(CASE WHEN placement = 1 THEN 1 END) as wins
FROM results r
JOIN tournaments t ON r.tournament_id = t.tournament_id
WHERE [filters]
GROUP BY archetype_id
HAVING wins > 0
```
Then calculate HHI from win shares in R.

#### 2. Event Health Indicator (Compact)

**Purpose:** Show whether event attendance is trending up or down.

**Calculation:**
- Average player_count for tournaments in last 30 days
- Compare to prior 30-day period
- Calculate percentage change

**Visual:**
- Large number showing current average attendance
- Trend arrow with color coding:
  - Green ↑: Growing (+10% or more)
  - Light green ↗: Slight growth (+1% to +10%)
  - Gray →: Flat (-1% to +1%)
  - Orange ↘: Slight decline (-10% to -1%)
  - Red ↓: Declining (-10% or more)
- Percentage change displayed
- Subtitle: "X events this month"

**Query Logic:**
```sql
-- Recent period
SELECT AVG(player_count) as avg_recent, COUNT(*) as event_count
FROM tournaments
WHERE event_date >= CURRENT_DATE - INTERVAL 30 DAY
  AND [filters]

-- Prior period
SELECT AVG(player_count) as avg_prior
FROM tournaments
WHERE event_date >= CURRENT_DATE - INTERVAL 60 DAY
  AND event_date < CURRENT_DATE - INTERVAL 30 DAY
  AND [filters]
```

#### 3. Player Growth & Retention Chart (Full)

**Purpose:** Visualize new player acquisition and retention over time.

**Calculation:**
For each month, categorize each unique player:
- **New:** First tournament ever was this month
- **Returning:** Has played before, but not a regular yet (< 3 total events)
- **Regular:** Has played 3+ events total (as of that month)

**Visual:**
- Stacked area chart (or grouped bar chart)
- X-axis: Months
- Y-axis: Player count
- Three series with distinct colors:
  - New players (e.g., cyan/teal)
  - Returning players (e.g., blue)
  - Regulars (e.g., purple)
- Tooltip shows breakdown: "Jan 2026: 8 new, 12 returning, 15 regulars (35 total)"

**Query Logic:**
```sql
-- Get each player's first tournament date and cumulative count by month
WITH player_history AS (
  SELECT
    r.player_id,
    DATE_TRUNC('month', MIN(t.event_date)) as first_month,
    DATE_TRUNC('month', t.event_date) as event_month,
    COUNT(*) as events_this_month
  FROM results r
  JOIN tournaments t ON r.tournament_id = t.tournament_id
  WHERE [filters]
  GROUP BY r.player_id, DATE_TRUNC('month', t.event_date)
)
-- Then categorize in R based on first_month and cumulative events
```

#### 4. Competitive Balance Chart (Full)

**Purpose:** Show whether tournament wins are spread across many players or concentrated among a few.

**Calculation:**
- Count 1st place finishes per player
- Rank by wins descending
- Show top 15 players

**Visual:**
- Horizontal bar chart
- Y-axis: Player names (top 15 by wins)
- X-axis: Number of tournament wins
- Bars colored by a gradient or single accent color
- Header subtitle: "X different winners across Y tournaments"

**Query Logic:**
```sql
SELECT p.display_name,
       COUNT(*) as wins
FROM results r
JOIN players p ON r.player_id = p.player_id
JOIN tournaments t ON r.tournament_id = t.tournament_id
WHERE r.placement = 1 AND [filters]
GROUP BY r.player_id, p.display_name
ORDER BY wins DESC
LIMIT 15
```

Subtitle query:
```sql
SELECT COUNT(DISTINCT r.player_id) as unique_winners,
       COUNT(DISTINCT r.tournament_id) as total_tournaments
FROM results r
JOIN tournaments t ON r.tournament_id = t.tournament_id
WHERE r.placement = 1 AND [filters]
```

### Styling

- Compact indicators styled to match existing value boxes (digital Digimon aesthetic with grid overlay)
- Full charts use existing Highcharter theme (`hc_theme_atom_switch`)
- Section wrapped in a card with header "Scene Health"
- Respects dark mode toggle

### Filter Integration

All metrics respect existing dashboard filters:
- Format dropdown
- Event type dropdown
- Store selection (from map)

## Implementation Notes

### Files to Modify

- `views/dashboard-ui.R` - Add Scene Health section UI
- `server/public-dashboard-server.R` - Add reactive calculations and chart renders

### New Outputs

- `output$meta_diversity_gauge` - renderUI for gauge
- `output$event_health_indicator` - renderUI for trend indicator
- `output$player_growth_chart` - renderHighchart for stacked area
- `output$competitive_balance_chart` - renderHighchart for bar chart
- `output$competitive_balance_subtitle` - renderUI for "X winners across Y tournaments"

### Dependencies

- Existing: highcharter, bslib, bsicons
- No new packages required

## Future Considerations

- Could add a "Scene Health Score" that combines all metrics into one number
- Could add tooltips explaining what each metric means for new users
- Could make gauges clickable to show historical trend in a modal
- Retention rate line overlay on Player Growth chart (% who returned)

## Alternatives Considered

1. **All compact indicators:** Rejected - Player Growth and Competitive Balance tell richer stories as full charts
2. **Separate "Analytics" tab:** Rejected - scene health is relevant context alongside meta data
3. **Donut chart for Competitive Balance:** Rejected - bar distribution shows more detail about individual player dominance
