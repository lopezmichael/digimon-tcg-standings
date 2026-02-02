# Player & Store Rating System Design

**Date:** 2026-02-01
**Status:** Draft
**Author:** Claude (with Michael)

## Overview

This document defines three distinct rating systems for DigiLab:

1. **Competitive Rating** - Elo-style rating measuring player skill
2. **Store Rating** - Quality/prestige score for tournament venues
3. **Achievement Score** - Points-based system rewarding participation and accomplishments

---

## 1. Competitive Player Rating

### What It Measures

The Competitive Rating answers: **"How good is this player at winning tournaments?"**

This is a skill-based rating that predicts how well a player will perform against others. Higher rating = stronger player.

### How It Works

We use an **Elo-style system with implied results**. When you finish a tournament, your placement tells us who you "beat" and who you "lost to":

- **Placing 3rd in a 16-player event** means you:
  - "Beat" everyone who placed 4th-16th (13 implied wins)
  - "Lost to" players who placed 1st-2nd (2 implied losses)

Your rating changes based on:
- **Who you beat**: Beating higher-rated players gains you more points
- **Who beat you**: Losing to higher-rated players costs you less
- **Tournament quality**: Events with stronger players affect your rating more

### Rating Scale

| Rating Range | Tier | Description |
|--------------|------|-------------|
| 2000+ | Elite | Dominant in the scene |
| 1800-2000 | Top Local | Frequently wins or top 3 |
| 1600-1800 | Strong | Consistently places well |
| 1400-1600 | Average | Regular competitive player |
| 1200-1400 | Developing | Still learning, improving |

All players start at **1500** (baseline).

### Key Features

#### Strength of Schedule
Your rating accounts for the strength of your opponents. Winning a tournament full of high-rated players boosts your rating more than winning against newcomers.

#### Recency Weighting
Recent results matter more than old ones. We use a **4-month half-life**:

| Time Ago | Weight |
|----------|--------|
| This month | 100% |
| 2 months | ~80% |
| 4 months | 50% |
| 8 months | 25% |
| 12 months | ~12% |

This keeps ratings responsive to current form while not punishing players who take breaks.

#### Tournament Round Multiplier
Longer events produce more reliable results and count slightly more:

| Rounds | Multiplier | Typical Event |
|--------|------------|---------------|
| 3 | 1.0x | Small locals |
| 4 | 1.1x | Standard locals |
| 5 | 1.2x | Large locals |
| 6 | 1.3x | Store championships |
| 7+ | 1.4x | Regionals |

#### New Player Handling
New players have a **provisional period** (first 5 events) where ratings adjust faster. This helps quickly find your true skill level. After 5 events, ratings stabilize and change more gradually.

### How to Improve Your Rating

1. **Win against strong players** - Beating higher-rated opponents gains more points
2. **Place consistently** - Top finishes at any event help
3. **Play regularly** - More data = more accurate rating
4. **Compete at tough stores** - Events with strong fields boost gains

---

## 2. Store Rating

### What It Measures

The Store Rating answers: **"Is this a thriving, competitive scene worth playing at?"**

This combines multiple factors to identify stores that offer quality tournament experiences.

### How It Works

Store Rating is a weighted blend of three components:

```
Store Rating = (Player Strength × 50%) + (Attendance × 30%) + (Activity × 20%)
```

| Component | Weight | What It Measures |
|-----------|--------|------------------|
| Player Strength | 50% | Average Competitive Rating of players (last 6 months) |
| Attendance | 30% | Average tournament size |
| Activity | 20% | How frequently events are held |

### Rating Scale

Stores are rated on a normalized 0-100 scale:

| Score | Tier | Description |
|-------|------|-------------|
| 80-100 | Premier | Top-tier competitive scene |
| 60-80 | Strong | Active, competitive store |
| 40-60 | Average | Regular events, mixed skill levels |
| 20-40 | Developing | Smaller or newer scene |
| 0-20 | Casual | Infrequent events or very casual |

### What Makes a High-Rated Store

- **Strong players attend regularly** - High average player rating
- **Good turnout** - Tournaments with 12+ players
- **Consistent schedule** - Weekly or bi-weekly events
- **Event variety** - Hosts special events (Evo Cups, store championships)

---

## 3. Achievement Score

### What It Measures

The Achievement Score answers: **"How accomplished and engaged is this player in the community?"**

Unlike Competitive Rating (which measures skill), Achievement Score rewards participation, accomplishments, and community involvement.

### How It Works

You earn points from three sources:

1. **Tournament Placements** - Points for how you finish
2. **Diversity Bonuses** - Rewards for exploring the scene
3. **Milestone Badges** - One-time unlocks for achievements

### Tournament Placement Points

Base points for each finish, multiplied by tournament size:

| Finish | Base Points |
|--------|-------------|
| 1st Place | 50 |
| 2nd Place | 30 |
| 3rd Place | 20 |
| Top 4 | 15 |
| Top 8 | 10 |
| Participated | 5 |

#### Tournament Size Multiplier

Bigger events = bigger rewards:

| Players | Multiplier | 1st Place Points |
|---------|------------|------------------|
| 8-11 | 1.0x | 50 |
| 12-15 | 1.25x | 62 |
| 16-23 | 1.5x | 75 |
| 24-31 | 1.75x | 87 |
| 32+ | 2.0x | 100 |

### Diversity Bonuses

Rewards for being active across the community:

| Achievement | Bonus Points |
|-------------|--------------|
| **Store Diversity** | |
| Visit 2-3 different stores | +10 |
| Visit 4-5 different stores | +25 |
| Visit 6+ different stores | +50 |
| **Deck Variety** | |
| Play 3+ different decks | +15 |
| **Format Variety** | |
| Compete in multiple formats | +10 |

### Milestone Badges

One-time achievements that unlock special recognition:

| Badge | Requirement |
|-------|-------------|
| First Blood | Win your first tournament |
| Regular | Attend 10 events |
| Veteran | Attend 25 events |
| Road Warrior | Play at 4+ different stores |
| Meta Scientist | Play 5+ different decks |
| Store Champion | Win at 3 different stores |
| Consistency King | Top 4 finish 5 times in a row |

### How to Improve Your Achievement Score

1. **Show up** - Every event earns participation points
2. **Place well** - Top finishes earn significantly more
3. **Travel** - Visit different stores for diversity bonuses
4. **Experiment** - Try different decks for variety bonus
5. **Chase milestones** - Unlock badges for permanent recognition

---

## Technical Specification

### Competitive Rating Algorithm

```
For each rating calculation cycle:
  1. Initialize all players at 1500 (or previous rating)
  2. For each tournament (chronologically):
     a. Calculate time decay weight: weight = 0.5^(months_ago / 4)
     b. Calculate round multiplier: min(1.0 + (rounds - 3) × 0.1, 1.4)
     c. For each player in tournament:
        - Generate implied wins (beat all below) and losses (lost to all above)
        - For each implied result:
          - Calculate expected score: E = 1 / (1 + 10^((opponent_rating - player_rating) / 400))
          - Calculate rating change: ΔR = K × (actual - expected) × decay × round_mult
          - K = 48 if provisional (< 5 events), else K = 24
        - Update player rating
  3. Repeat steps 2 for 3-5 iterations until ratings converge
```

### Store Rating Algorithm

```
For each store:
  1. Get all tournaments from last 6 months
  2. Get unique players who attended
  3. Calculate components:
     - player_strength = mean(player competitive ratings)
     - attendance_score = normalize(mean(tournament sizes), min=4, max=32)
     - activity_score = normalize(events_per_month, min=0.5, max=4)
  4. Store Rating = (player_strength × 0.5) + (attendance_score × 0.3) + (activity_score × 0.2)
  5. Normalize to 0-100 scale
```

### Achievement Score Algorithm

```
For each player:
  1. Sum placement points across all tournaments:
     - For each result: base_points × size_multiplier
  2. Calculate diversity bonuses:
     - Count unique stores → apply tier bonus
     - Count unique decks → apply if 3+
     - Count unique formats → apply if 2+
  3. Check milestone badges (one-time)
  4. Achievement Score = placement_points + diversity_bonuses
```

### Database Considerations

New fields/tables that may be needed:
- `players.competitive_rating` - Current Elo-style rating
- `players.achievement_score` - Current achievement points
- `players.events_played` - Count for provisional status
- `stores.store_rating` - Calculated store quality score
- `player_badges` table - Track unlocked milestones

### Calculation Timing

- **Competitive Rating**: Recalculate on each page load (lightweight) or cache and refresh on new results
- **Store Rating**: Recalculate daily or on new tournament data
- **Achievement Score**: Update when new results are entered

---

## Summary Comparison

| Aspect | Competitive Rating | Store Rating | Achievement Score |
|--------|-------------------|--------------|-------------------|
| Measures | Skill | Venue quality | Engagement |
| Method | Elo + implied results | Weighted average | Points accumulation |
| Scale | ~1200-2100 | 0-100 | Unbounded |
| Updates | Per tournament | Rolling 6 months | Cumulative |
| Decay | 4-month half-life | 6-month window | None |

---

## Open Questions

1. Should Achievement Score have any decay, or is it purely cumulative?
2. Display format in UI - separate tabs, combined player profile, or both?
3. Leaderboards - separate for each rating type?
4. Should badges be visible to other players or just the individual?

---

## Next Steps

1. [ ] Get user approval on this design
2. [ ] Plan database schema changes
3. [ ] Implement calculation logic in R
4. [ ] Add UI components (ratings display, methodology tab)
5. [ ] Backfill ratings from existing tournament data
