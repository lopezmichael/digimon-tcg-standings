# React Rewrite - Dashboard PoC Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a full-fidelity Next.js Dashboard that matches DigiLab's current Shiny dashboard, reading from the same local DuckDB database.

**Architecture:** Next.js 15 App Router with API routes as thin query wrappers over DuckDB. Client components for charts, tables, and interactivity. CSS modules + Tailwind for styling, porting the existing digital Digimon aesthetic.

**Tech Stack:** Next.js 15, TypeScript, Tailwind CSS, Recharts, TanStack Table, next-themes, @duckdb/node-api

**Important:** The existing Shiny app lives in the repo root. The Next.js app goes in `digilab-next/` subdirectory. The DuckDB database is at `data/local.duckdb` (relative to repo root). Node.js must be installed first.

---

## Prerequisites

Before starting Task 1, ensure:
1. Node.js (v20+) and npm are installed: `node --version && npm --version`
2. Local DuckDB has data: `data/local.duckdb` exists (run `python scripts/sync_from_motherduck.py --yes` if needed)
3. You are on branch `explore/react-rewrite`

If Node.js is not installed, ask the user to install it from https://nodejs.org/ (LTS version) before proceeding.

---

### Task 1: Initialize Next.js Project

**Files:**
- Create: `digilab-next/` (entire directory via create-next-app)

**Step 1: Scaffold the project**

Run from repo root:
```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
npx create-next-app@latest digilab-next --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm
```

When prompted, accept defaults (Yes to all). This creates the full Next.js project structure.

**Step 2: Verify it runs**

```bash
cd digilab-next
npm run dev
```

Expected: Dev server starts on http://localhost:3000, shows Next.js default page.

**Step 3: Clean up boilerplate**

Replace `digilab-next/src/app/page.tsx` with:
```tsx
export default function Home() {
  return (
    <main className="min-h-screen p-8">
      <h1 className="text-2xl font-bold">DigiLab - React Dashboard PoC</h1>
      <p className="text-gray-600 mt-2">Coming soon...</p>
    </main>
  )
}
```

Replace `digilab-next/src/app/globals.css` with:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

**Step 4: Add .gitignore entries**

Ensure `digilab-next/.gitignore` includes (create-next-app should handle this):
```
node_modules/
.next/
```

**Step 5: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/
git commit -m "feat: initialize Next.js project for React dashboard PoC"
```

---

### Task 2: Install Dependencies

**Files:**
- Modify: `digilab-next/package.json`

**Step 1: Install core dependencies**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings/digilab-next"
npm install recharts @tanstack/react-table next-themes duckdb
```

Note: `duckdb` is the Node.js DuckDB driver. If `duckdb` fails on Windows, try `@duckdb/node-api` instead.

**Step 2: Install shadcn/ui**

```bash
npx shadcn@latest init
```

When prompted:
- Style: Default
- Base color: Slate
- CSS variables: Yes

Then install needed components:
```bash
npx shadcn@latest add card select button skeleton table
```

**Step 3: Verify dependencies installed**

```bash
npm run build
```

Expected: Build succeeds with no errors.

**Step 4: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/
git commit -m "feat: install dependencies (recharts, tanstack-table, duckdb, shadcn/ui)"
```

---

### Task 3: Database Connection Layer

**Files:**
- Create: `digilab-next/src/lib/db.ts`
- Create: `digilab-next/src/lib/types.ts`

**Step 1: Create TypeScript types from schema**

Create `digilab-next/src/lib/types.ts`:
```typescript
// Types derived from db/schema.sql

export interface Store {
  store_id: number
  name: string
  address: string | null
  city: string
  state: string
  zip_code: string | null
  latitude: number | null
  longitude: number | null
  is_active: boolean
  is_online: boolean
}

export interface Format {
  format_id: string
  set_name: string
  display_name: string
  release_date: string | null
  sort_order: number | null
  is_active: boolean
}

export interface Player {
  player_id: number
  display_name: string
  member_number: string | null
  is_active: boolean
}

export interface DeckArchetype {
  archetype_id: number
  archetype_name: string
  display_card_id: string | null
  primary_color: string
  secondary_color: string | null
  is_active: boolean
}

export interface Tournament {
  tournament_id: number
  store_id: number
  event_date: string
  event_type: string
  format: string | null
  player_count: number | null
  rounds: number | null
}

export interface Result {
  result_id: number
  tournament_id: number
  player_id: number
  archetype_id: number | null
  placement: number | null
  wins: number
  losses: number
  ties: number
}

// Dashboard-specific response types

export interface DashboardStats {
  totalTournaments: number
  totalPlayers: number
  totalStores: number
  totalDecks: number
}

export interface TopDeck {
  archetype_name: string
  display_card_id: string | null
  primary_color: string
  times_played: number
  first_places: number
  win_rate: number
}

export interface HotDeck {
  insufficient_data: boolean
  no_trending?: boolean
  tournament_count?: number
  archetype_name?: string
  display_card_id?: string | null
  delta?: number
}

export interface MostPopularDeck {
  archetype_name: string
  display_card_id: string | null
  entries: number
  meta_share: number
}

export interface RecentTournament {
  tournament_id: number
  store_id: number
  Store: string
  Date: string
  Players: number
  Winner: string
  store_rating: number
}

export interface TopPlayer {
  player_id: number
  Player: string
  Events: number
  event_wins: number
  top3_placements: number
  competitive_rating: number
  achievement_score: number
}

export interface ConversionData {
  name: string
  color: string
  entries: number
  top3: number
  conversion: number
}

export interface ColorDistData {
  color: string
  count: number
}

export interface TrendData {
  event_date: string
  tournaments: number
  avg_players: number
  rolling_avg: number
}

export interface MetaTimelineData {
  week_start: string
  archetype_name: string
  primary_color: string
  entries: number
  share: number
}

export const DECK_COLORS: Record<string, string> = {
  Red: '#E5383B',
  Blue: '#2D7DD2',
  Yellow: '#F5B700',
  Green: '#38A169',
  Black: '#2D3748',
  Purple: '#805AD5',
  White: '#A0AEC0',
  Multi: '#EC4899',
  Other: '#9CA3AF',
}

export const COLOR_ORDER = ['Red', 'Blue', 'Yellow', 'Green', 'Purple', 'Black', 'White', 'Multi', 'Other']
```

**Step 2: Create database connection**

Create `digilab-next/src/lib/db.ts`:
```typescript
import duckdb from 'duckdb'
import path from 'path'

// Singleton database connection
let db: duckdb.Database | null = null

function getDbPath(): string {
  // Local dev: use the same DuckDB file as the Shiny app
  // The file is at repo_root/data/local.duckdb
  // digilab-next/ is one level deep from repo root
  return path.resolve(process.cwd(), '..', 'data', 'local.duckdb')
}

function getDatabase(): duckdb.Database {
  if (!db) {
    const dbPath = getDbPath()
    db = new duckdb.Database(dbPath, { access_mode: 'READ_ONLY' })
  }
  return db
}

export function query<T = Record<string, unknown>>(sql: string): Promise<T[]> {
  return new Promise((resolve, reject) => {
    const database = getDatabase()
    database.all(sql, (err: Error | null, rows: T[]) => {
      if (err) reject(err)
      else resolve(rows ?? [])
    })
  })
}
```

**Step 3: Test the connection**

Create a temporary test file `digilab-next/src/app/api/test-db/route.ts`:
```typescript
import { NextResponse } from 'next/server'
import { query } from '@/lib/db'

export async function GET() {
  try {
    const result = await query<{ n: number }>('SELECT COUNT(*) as n FROM tournaments')
    return NextResponse.json({ success: true, count: result[0].n })
  } catch (error) {
    return NextResponse.json({ success: false, error: String(error) }, { status: 500 })
  }
}
```

Run: `npm run dev` and open http://localhost:3000/api/test-db

Expected: JSON response like `{"success": true, "count": 42}` (actual count depends on data)

**Step 4: Troubleshooting DuckDB on Windows**

If `duckdb` npm package fails:
- Try: `npm install @duckdb/node-api` and update `db.ts` to use the alternative API
- Or try: `npm install duckdb@1.1.3` (pin to a known-working version)
- DuckDB requires the database file to exist. Verify `data/local.duckdb` is present.

**Step 5: Clean up test route and commit**

Delete `digilab-next/src/app/api/test-db/route.ts` after verifying.

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/lib/
git commit -m "feat: add DuckDB connection layer and TypeScript types"
```

---

### Task 4: Dashboard Filter Queries

**Files:**
- Create: `digilab-next/src/lib/queries/dashboard.ts`

**Step 1: Create the query module**

This file ports all SQL queries from `server/public-dashboard-server.R` and the rating calculations from `R/ratings.R`.

Create `digilab-next/src/lib/queries/dashboard.ts`:
```typescript
import { query } from '@/lib/db'
import type {
  DashboardStats,
  TopDeck,
  HotDeck,
  MostPopularDeck,
  RecentTournament,
  TopPlayer,
  ConversionData,
  ColorDistData,
  TrendData,
  MetaTimelineData,
  DECK_COLORS,
  COLOR_ORDER,
} from '@/lib/types'

// --- Filter Builder (port of build_dashboard_filters) ---

interface DashboardFilters {
  format: string
  eventType: string
  store: string
}

function buildFilterClauses(
  filters: { format?: string; eventType?: string },
  tableAlias = 't'
): DashboardFilters {
  const format = filters.format
    ? `AND ${tableAlias}.format = '${filters.format}'`
    : ''
  const eventType = filters.eventType
    ? `AND ${tableAlias}.event_type = '${filters.eventType}'`
    : ''
  // Store filter not used in PoC (no map/scene selection yet)
  const store = ''
  return { format, eventType, store }
}

// --- Stats Queries ---

export async function getDashboardStats(
  filters: { format?: string; eventType?: string }
): Promise<DashboardStats> {
  const f = buildFilterClauses(filters)

  const [tournaments, players, stores, decks] = await Promise.all([
    query<{ n: number }>(`
      SELECT COUNT(*) as n FROM tournaments t
      WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
    `),
    query<{ n: number }>(`
      SELECT COUNT(DISTINCT r.player_id) as n
      FROM results r
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
    `),
    query<{ n: number }>(`SELECT COUNT(*) as n FROM stores WHERE is_active = TRUE`),
    query<{ n: number }>(`SELECT COUNT(*) as n FROM deck_archetypes WHERE is_active = TRUE`),
  ])

  return {
    totalTournaments: tournaments[0]?.n ?? 0,
    totalPlayers: players[0]?.n ?? 0,
    totalStores: stores[0]?.n ?? 0,
    totalDecks: decks[0]?.n ?? 0,
  }
}

// --- Most Popular Deck (Top Deck value box) ---

export async function getMostPopularDeck(
  filters: { format?: string; eventType?: string }
): Promise<MostPopularDeck | null> {
  const f = buildFilterClauses(filters)

  const result = await query<MostPopularDeck>(`
    SELECT da.archetype_name, da.display_card_id,
           COUNT(r.result_id) as entries,
           ROUND(COUNT(r.result_id) * 100.0 / NULLIF(SUM(COUNT(r.result_id)) OVER(), 0), 1) as meta_share
    FROM deck_archetypes da
    JOIN results r ON da.archetype_id = r.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' ${f.format} ${f.eventType} ${f.store}
    GROUP BY da.archetype_id, da.archetype_name, da.display_card_id
    ORDER BY entries DESC
    LIMIT 1
  `)

  return result[0] ?? null
}

// --- Hot Deck (Trending) ---

export async function getHotDeck(
  filters: { format?: string; eventType?: string }
): Promise<HotDeck> {
  const f = buildFilterClauses(filters)

  // Check tournament count
  const countResult = await query<{ n: number }>(`
    SELECT COUNT(*) as n FROM tournaments t WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
  `)
  const tournamentCount = countResult[0]?.n ?? 0

  if (tournamentCount < 10) {
    return { insufficient_data: true, tournament_count: tournamentCount }
  }

  // Get median date
  const medianResult = await query<{ median_date: string }>(`
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY event_date) as median_date
    FROM tournaments t WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
  `)
  const medianDate = medianResult[0]?.median_date
  if (!medianDate) return { insufficient_data: true, tournament_count: tournamentCount }

  // Get older and newer meta shares
  const [olderMeta, newerMeta] = await Promise.all([
    query<{ archetype_name: string; display_card_id: string | null; meta_share: number }>(`
      SELECT da.archetype_name, da.display_card_id,
             ROUND(COUNT(r.result_id) * 100.0 / NULLIF(SUM(COUNT(r.result_id)) OVER(), 0), 2) as meta_share
      FROM deck_archetypes da
      JOIN results r ON da.archetype_id = r.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE t.event_date < '${medianDate}' AND da.archetype_name != 'UNKNOWN' ${f.format} ${f.eventType} ${f.store}
      GROUP BY da.archetype_id, da.archetype_name, da.display_card_id
    `),
    query<{ archetype_name: string; display_card_id: string | null; meta_share: number }>(`
      SELECT da.archetype_name, da.display_card_id,
             ROUND(COUNT(r.result_id) * 100.0 / NULLIF(SUM(COUNT(r.result_id)) OVER(), 0), 2) as meta_share
      FROM deck_archetypes da
      JOIN results r ON da.archetype_id = r.archetype_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE t.event_date >= '${medianDate}' AND da.archetype_name != 'UNKNOWN' ${f.format} ${f.eventType} ${f.store}
      GROUP BY da.archetype_id, da.archetype_name, da.display_card_id
    `),
  ])

  if (olderMeta.length === 0 || newerMeta.length === 0) {
    return { insufficient_data: true, tournament_count: tournamentCount }
  }

  // Merge and calculate delta
  const olderMap = new Map(olderMeta.map(r => [r.archetype_name, r.meta_share]))
  const merged = newerMeta.map(r => ({
    ...r,
    delta: r.meta_share - (olderMap.get(r.archetype_name) ?? 0),
  }))

  // Find biggest positive increase
  const hot = merged.reduce((best, curr) =>
    curr.delta > (best?.delta ?? -Infinity) ? curr : best
  , merged[0])

  if (!hot || hot.delta <= 0) {
    return { insufficient_data: false, no_trending: true }
  }

  return {
    insufficient_data: false,
    archetype_name: hot.archetype_name,
    display_card_id: hot.display_card_id,
    delta: Math.round(hot.delta * 10) / 10,
  }
}

// --- Top Decks with Card Images ---

export async function getTopDecks(
  filters: { format?: string; eventType?: string }
): Promise<TopDeck[]> {
  const f = buildFilterClauses(filters)

  // Get total tournaments for win rate calculation
  const countResult = await query<{ total: number }>(`
    SELECT COUNT(DISTINCT tournament_id) as total
    FROM tournaments t WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
  `)
  const totalTournaments = countResult[0]?.total ?? 0
  if (totalTournaments === 0) return []

  const result = await query<{
    archetype_name: string
    display_card_id: string | null
    primary_color: string
    times_played: number
    first_places: number
  }>(`
    SELECT da.archetype_name, da.display_card_id, da.primary_color,
           COUNT(r.result_id) as times_played,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as first_places
    FROM deck_archetypes da
    JOIN results r ON da.archetype_id = r.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' ${f.format} ${f.eventType} ${f.store}
    GROUP BY da.archetype_id, da.archetype_name, da.display_card_id, da.primary_color
    HAVING COUNT(r.result_id) >= 1
    ORDER BY COUNT(CASE WHEN r.placement = 1 THEN 1 END) DESC, COUNT(r.result_id) DESC
    LIMIT 6
  `)

  return result.map(r => ({
    ...r,
    win_rate: Math.round((r.first_places / totalTournaments) * 1000) / 10,
  }))
}

// --- Recent Tournaments ---

export async function getRecentTournaments(
  filters: { format?: string; eventType?: string }
): Promise<RecentTournament[]> {
  const f = buildFilterClauses(filters)

  const result = await query<{
    tournament_id: number
    store_id: number
    Store: string
    Date: string
    Players: number
    Winner: string | null
  }>(`
    SELECT t.tournament_id, s.store_id, s.name as Store,
           t.event_date as Date, t.player_count as Players,
           p.display_name as Winner
    FROM tournaments t
    JOIN stores s ON t.store_id = s.store_id
    LEFT JOIN results r ON t.tournament_id = r.tournament_id AND r.placement = 1
    LEFT JOIN players p ON r.player_id = p.player_id
    WHERE 1=1 ${f.store} ${f.format} ${f.eventType}
    ORDER BY t.event_date DESC
    LIMIT 10
  `)

  // Get store ratings and merge
  const storeRatings = await getStoreRatings()
  const ratingMap = new Map(storeRatings.map(r => [r.store_id, r.store_rating]))

  return result.map(r => ({
    ...r,
    Winner: r.Winner ?? '-',
    store_rating: ratingMap.get(r.store_id) ?? 0,
  }))
}

// --- Top Players ---

export async function getTopPlayers(
  filters: { format?: string; eventType?: string }
): Promise<TopPlayer[]> {
  const f = buildFilterClauses(filters)

  const result = await query<{
    player_id: number
    Player: string
    Events: number
    event_wins: number
    top3_placements: number
  }>(`
    SELECT p.player_id,
           p.display_name as Player,
           COUNT(DISTINCT r.tournament_id) as Events,
           COUNT(CASE WHEN r.placement = 1 THEN 1 END) as event_wins,
           COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3_placements
    FROM players p
    JOIN results r ON p.player_id = r.player_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 ${f.store} ${f.format} ${f.eventType}
    GROUP BY p.player_id, p.display_name
    HAVING COUNT(DISTINCT r.tournament_id) > 0
  `)

  if (result.length === 0) return []

  // Get ratings and achievement scores
  const [compRatings, achScores] = await Promise.all([
    getCompetitiveRatings(),
    getAchievementScores(),
  ])

  const ratingMap = new Map(compRatings.map(r => [r.player_id, r.competitive_rating]))
  const achMap = new Map(achScores.map(r => [r.player_id, r.achievement_score]))

  return result
    .map(r => ({
      ...r,
      competitive_rating: ratingMap.get(r.player_id) ?? 1500,
      achievement_score: achMap.get(r.player_id) ?? 0,
    }))
    .sort((a, b) => b.competitive_rating - a.competitive_rating)
    .slice(0, 10)
}

// --- Chart Data ---

export async function getConversionData(
  filters: { format?: string; eventType?: string }
): Promise<ConversionData[]> {
  const f = buildFilterClauses(filters)

  return query<ConversionData>(`
    SELECT da.archetype_name as name, da.primary_color as color,
           COUNT(r.result_id) as entries,
           COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3,
           ROUND(COUNT(CASE WHEN r.placement <= 3 THEN 1 END) * 100.0 / COUNT(r.result_id), 1) as conversion
    FROM results r
    JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' ${f.format} ${f.eventType} ${f.store}
    GROUP BY da.archetype_id, da.archetype_name, da.primary_color
    HAVING COUNT(r.result_id) >= 2
    ORDER BY conversion DESC
    LIMIT 5
  `)
}

export async function getColorDistribution(
  filters: { format?: string; eventType?: string }
): Promise<ColorDistData[]> {
  const f = buildFilterClauses(filters)

  return query<ColorDistData>(`
    SELECT
      CASE WHEN da.secondary_color IS NOT NULL THEN 'Multi' ELSE da.primary_color END as color,
      COUNT(r.result_id) as count
    FROM results r
    JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' ${f.format} ${f.eventType} ${f.store}
    GROUP BY CASE WHEN da.secondary_color IS NOT NULL THEN 'Multi' ELSE da.primary_color END
    ORDER BY count DESC
  `)
}

export async function getTrendData(
  filters: { format?: string; eventType?: string }
): Promise<TrendData[]> {
  const f = buildFilterClauses(filters)

  const result = await query<{
    event_date: string
    tournaments: number
    avg_players: number
  }>(`
    SELECT event_date,
           COUNT(*) as tournaments,
           ROUND(AVG(player_count), 1) as avg_players
    FROM tournaments t
    WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
    GROUP BY event_date
    ORDER BY event_date
  `)

  // Calculate 7-day rolling average (port from R)
  return result.map((row, i) => {
    const currentDate = new Date(row.event_date)
    const weekAgo = new Date(currentDate.getTime() - 7 * 24 * 60 * 60 * 1000)

    const inWindow = result.filter(r => {
      const d = new Date(r.event_date)
      return d >= weekAgo && d <= currentDate
    })

    const rollingAvg = inWindow.reduce((sum, r) => sum + r.avg_players, 0) / inWindow.length

    return {
      ...row,
      rolling_avg: Math.round(rollingAvg * 10) / 10,
    }
  })
}

export async function getMetaTimeline(
  filters: { format?: string; eventType?: string }
): Promise<{ weeks: string[]; series: { name: string; color: string; data: number[] }[] }> {
  const f = buildFilterClauses(filters)

  const result = await query<{
    week_start: string
    archetype_name: string
    primary_color: string
    entries: number
  }>(`
    SELECT date_trunc('week', t.event_date) as week_start,
           da.archetype_name,
           da.primary_color,
           COUNT(r.result_id) as entries
    FROM results r
    JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE 1=1 AND da.archetype_name != 'UNKNOWN' ${f.format} ${f.eventType} ${f.store}
    GROUP BY date_trunc('week', t.event_date), da.archetype_id, da.archetype_name, da.primary_color
    ORDER BY week_start, entries DESC
  `)

  if (result.length === 0) return { weeks: [], series: [] }

  // Get unique weeks
  const weeks = [...new Set(result.map(r => r.week_start))].sort()

  // Calculate week totals
  const weekTotals = new Map<string, number>()
  for (const row of result) {
    weekTotals.set(row.week_start, (weekTotals.get(row.week_start) ?? 0) + row.entries)
  }

  // Calculate overall share per archetype and sort by color then share
  const archetypeStats = new Map<string, { color: string; total: number }>()
  for (const row of result) {
    const existing = archetypeStats.get(row.archetype_name)
    archetypeStats.set(row.archetype_name, {
      color: row.primary_color,
      total: (existing?.total ?? 0) + row.entries,
    })
  }

  const totalEntries = [...archetypeStats.values()].reduce((sum, v) => sum + v.total, 0)

  // Sort by color order, then by share within color
  const { COLOR_ORDER, DECK_COLORS } = await import('@/lib/types')
  const sortedDecks = [...archetypeStats.entries()]
    .map(([name, stats]) => ({
      name,
      color: stats.color,
      share: stats.total / totalEntries,
      colorRank: COLOR_ORDER.indexOf(stats.color) ?? 999,
    }))
    .sort((a, b) => a.colorRank - b.colorRank || b.share - a.share)

  // Build series
  const series = sortedDecks.map(deck => {
    const data = weeks.map(week => {
      const row = result.find(r => r.week_start === week && r.archetype_name === deck.name)
      const weekTotal = weekTotals.get(week) ?? 1
      return row ? Math.round((row.entries / weekTotal) * 1000) / 10 : 0
    })

    return {
      name: deck.name,
      color: DECK_COLORS[deck.color] ?? '#6B7280',
      data,
    }
  })

  // Format week labels
  const weekLabels = weeks.map(w => {
    const d = new Date(w)
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  })

  return { weeks: weekLabels, series }
}

// --- Rating Calculations (port from R/ratings.R) ---

export async function getCompetitiveRatings(): Promise<{ player_id: number; competitive_rating: number }[]> {
  const results = await query<{
    tournament_id: number
    player_id: number
    placement: number
    event_date: string
    player_count: number
    rounds: number | null
  }>(`
    SELECT r.tournament_id, r.player_id, r.placement,
           t.event_date, t.player_count, t.rounds
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    JOIN players p ON r.player_id = p.player_id
    WHERE r.placement IS NOT NULL
      AND t.player_count IS NOT NULL
      AND t.player_count >= 4
    ORDER BY t.event_date ASC, r.tournament_id, r.placement
  `)

  if (results.length === 0) return []

  // Initialize ratings
  const ratings = new Map<number, number>()
  const eventsPlayed = new Map<number, number>()
  for (const r of results) {
    if (!ratings.has(r.player_id)) {
      ratings.set(r.player_id, 1500)
      eventsPlayed.set(r.player_id, 0)
    }
  }

  // Group by tournament
  const tournamentMap = new Map<number, typeof results>()
  for (const r of results) {
    if (!tournamentMap.has(r.tournament_id)) tournamentMap.set(r.tournament_id, [])
    tournamentMap.get(r.tournament_id)!.push(r)
  }

  // Get unique tournaments sorted by date
  const tournaments = [...new Set(results.map(r => r.tournament_id))]
    .map(id => {
      const first = results.find(r => r.tournament_id === id)!
      return { id, event_date: first.event_date, rounds: first.rounds }
    })
    .sort((a, b) => a.event_date.localeCompare(b.event_date))

  const currentDate = new Date()

  // 5 passes for convergence
  for (let pass = 0; pass < 5; pass++) {
    for (const tourney of tournaments) {
      const tourneyResults = (tournamentMap.get(tourney.id) ?? [])
        .sort((a, b) => a.placement - b.placement)

      if (tourneyResults.length < 2) continue

      // Decay weight (4-month half-life)
      const eventDate = new Date(tourney.event_date)
      const monthsAgo = (currentDate.getTime() - eventDate.getTime()) / (1000 * 60 * 60 * 24 * 30.44)
      const decayWeight = Math.pow(0.5, monthsAgo / 4)

      // Round multiplier
      const rounds = tourney.rounds ?? 3
      const roundMult = Math.min(1.0 + (rounds - 3) * 0.1, 1.4)

      for (const player of tourneyResults) {
        const playerRating = ratings.get(player.player_id)!
        const kFactor = (eventsPlayed.get(player.player_id)! < 5) ? 48 : 24
        let ratingChange = 0

        for (const opponent of tourneyResults) {
          if (player.player_id === opponent.player_id) continue

          const opponentRating = ratings.get(opponent.player_id)!
          const actualResult = player.placement < opponent.placement ? 1 : 0
          const expected = 1 / (1 + Math.pow(10, (opponentRating - playerRating) / 400))
          ratingChange += kFactor * (actualResult - expected)
        }

        ratingChange *= decayWeight * roundMult
        ratingChange /= (tourneyResults.length - 1)
        ratings.set(player.player_id, playerRating + ratingChange)
      }

      // Update events played (first pass only)
      if (pass === 0) {
        for (const player of tourneyResults) {
          eventsPlayed.set(player.player_id, (eventsPlayed.get(player.player_id) ?? 0) + 1)
        }
      }
    }
  }

  return [...ratings.entries()].map(([player_id, rating]) => ({
    player_id,
    competitive_rating: Math.round(rating),
  }))
}

export async function getAchievementScores(): Promise<{ player_id: number; achievement_score: number }[]> {
  const results = await query<{
    player_id: number
    tournament_id: number
    placement: number
    archetype_id: number | null
    player_count: number | null
    store_id: number
    format: string | null
    archetype_name: string | null
  }>(`
    SELECT r.player_id, r.tournament_id, r.placement, r.archetype_id,
           t.player_count, t.store_id, t.format, da.archetype_name
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    LEFT JOIN deck_archetypes da ON r.archetype_id = da.archetype_id
    WHERE r.placement IS NOT NULL
  `)

  if (results.length === 0) return []

  // Group by player
  const playerResults = new Map<number, typeof results>()
  for (const r of results) {
    if (!playerResults.has(r.player_id)) playerResults.set(r.player_id, [])
    playerResults.get(r.player_id)!.push(r)
  }

  function getPlacementPoints(placement: number, playerCount: number | null): number {
    let base: number
    if (placement === 1) base = 50
    else if (placement === 2) base = 30
    else if (placement === 3) base = 20
    else if (placement <= 4) base = 15
    else if (placement <= 8) base = 10
    else base = 5

    let sizeMult: number
    const count = playerCount ?? 0
    if (count < 8) sizeMult = 1.0
    else if (count < 12) sizeMult = 1.0
    else if (count < 16) sizeMult = 1.25
    else if (count < 24) sizeMult = 1.5
    else if (count < 32) sizeMult = 1.75
    else sizeMult = 2.0

    return Math.round(base * sizeMult)
  }

  return [...playerResults.entries()].map(([player_id, pResults]) => {
    // Placement points
    const placementPts = pResults.reduce(
      (sum, r) => sum + getPlacementPoints(r.placement, r.player_count), 0
    )

    // Store diversity bonus
    const uniqueStores = new Set(pResults.map(r => r.store_id)).size
    const storeBonus = uniqueStores >= 6 ? 50 : uniqueStores >= 4 ? 25 : uniqueStores >= 2 ? 10 : 0

    // Deck variety bonus (exclude UNKNOWN)
    const knownDecks = pResults.filter(r => r.archetype_name && r.archetype_name !== 'UNKNOWN')
    const uniqueDecks = new Set(knownDecks.map(r => r.archetype_id)).size
    const deckBonus = uniqueDecks >= 3 ? 15 : 0

    // Format variety bonus
    const uniqueFormats = new Set(pResults.map(r => r.format).filter(Boolean)).size
    const formatBonus = uniqueFormats >= 2 ? 10 : 0

    return {
      player_id,
      achievement_score: placementPts + storeBonus + deckBonus + formatBonus,
    }
  })
}

export async function getStoreRatings(): Promise<{ store_id: number; store_rating: number }[]> {
  const sixMonthsAgo = new Date()
  sixMonthsAgo.setDate(sixMonthsAgo.getDate() - 180)
  const cutoff = sixMonthsAgo.toISOString().split('T')[0]

  const [storeStats, storePlayers, compRatings] = await Promise.all([
    query<{
      store_id: number
      event_count: number
      avg_attendance: number | null
    }>(`
      SELECT s.store_id,
             COUNT(DISTINCT t.tournament_id) as event_count,
             AVG(t.player_count) as avg_attendance
      FROM stores s
      LEFT JOIN tournaments t ON s.store_id = t.store_id AND t.event_date >= '${cutoff}'
      WHERE s.is_active = TRUE AND (s.is_online = FALSE OR s.is_online IS NULL)
      GROUP BY s.store_id
    `),
    query<{ store_id: number; player_id: number }>(`
      SELECT DISTINCT t.store_id, r.player_id
      FROM results r
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE t.event_date >= '${cutoff}'
    `),
    getCompetitiveRatings(),
  ])

  if (storeStats.length === 0) return []

  const ratingMap = new Map(compRatings.map(r => [r.player_id, r.competitive_rating]))

  // Group players by store
  const storePlayerMap = new Map<number, number[]>()
  for (const sp of storePlayers) {
    if (!storePlayerMap.has(sp.store_id)) storePlayerMap.set(sp.store_id, [])
    storePlayerMap.get(sp.store_id)!.push(sp.player_id)
  }

  return storeStats.map(store => {
    // Avg player rating at store
    const players = storePlayerMap.get(store.store_id) ?? []
    const playerRatings = players.map(pid => ratingMap.get(pid) ?? 1500)
    const avgRating = playerRatings.length > 0
      ? playerRatings.reduce((a, b) => a + b, 0) / playerRatings.length
      : 1500

    // Normalize to 0-100
    const strengthScore = Math.min(Math.max((avgRating - 1200) / 8, 0), 100)
    const attendanceScore = store.avg_attendance
      ? Math.min(Math.max((store.avg_attendance - 4) / 0.28, 0), 100)
      : 0
    const activityScore = Math.min((store.event_count / 24) * 100, 100)

    // Weighted blend: 50% strength, 30% attendance, 20% activity
    const storeRating = Math.round(
      strengthScore * 0.5 + attendanceScore * 0.3 + activityScore * 0.2
    )

    return { store_id: store.store_id, store_rating: storeRating }
  })
}

// --- Format List (for dropdown) ---

export async function getFormats(): Promise<{ format_id: string; display_name: string }[]> {
  return query<{ format_id: string; display_name: string }>(`
    SELECT format_id, display_name
    FROM formats
    WHERE is_active = TRUE
    ORDER BY sort_order ASC, release_date DESC
  `)
}
```

**Step 2: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/lib/queries/
git commit -m "feat: port all dashboard SQL queries and rating calculations from R"
```

---

### Task 5: API Routes

**Files:**
- Create: `digilab-next/src/app/api/dashboard/stats/route.ts`
- Create: `digilab-next/src/app/api/dashboard/top-decks/route.ts`
- Create: `digilab-next/src/app/api/dashboard/recent-tournaments/route.ts`
- Create: `digilab-next/src/app/api/dashboard/top-players/route.ts`
- Create: `digilab-next/src/app/api/dashboard/charts/conversion/route.ts`
- Create: `digilab-next/src/app/api/dashboard/charts/color-dist/route.ts`
- Create: `digilab-next/src/app/api/dashboard/charts/trend/route.ts`
- Create: `digilab-next/src/app/api/dashboard/charts/meta-timeline/route.ts`
- Create: `digilab-next/src/app/api/dashboard/formats/route.ts`

Each API route is a thin wrapper that reads query params and calls the query function.

**Step 1: Create all API routes**

Pattern for each route (example - `stats/route.ts`):
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { getDashboardStats } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getDashboardStats({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Dashboard stats error:', error)
    return NextResponse.json({ error: 'Failed to fetch stats' }, { status: 500 })
  }
}
```

Repeat this pattern for each route, calling the corresponding query function:
- `stats/route.ts` → `getDashboardStats()`
- `top-decks/route.ts` → `getTopDecks()`
- `recent-tournaments/route.ts` → `getRecentTournaments()`
- `top-players/route.ts` → `getTopPlayers()`
- `charts/conversion/route.ts` → `getConversionData()`
- `charts/color-dist/route.ts` → `getColorDistribution()`
- `charts/trend/route.ts` → `getTrendData()`
- `charts/meta-timeline/route.ts` → `getMetaTimeline()`
- `formats/route.ts` → `getFormats()`

All routes accept `?format=X&eventType=Y` query params.

**Step 2: Verify API routes**

Run `npm run dev` and test:
- http://localhost:3000/api/dashboard/stats
- http://localhost:3000/api/dashboard/top-decks
- http://localhost:3000/api/dashboard/formats

Expected: JSON responses with real data from local DuckDB.

**Step 3: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/app/api/
git commit -m "feat: add all dashboard API routes"
```

---

### Task 6: Dark Mode & Theme Provider

**Files:**
- Create: `digilab-next/src/components/theme-provider.tsx`
- Modify: `digilab-next/src/app/layout.tsx`

**Step 1: Create theme provider**

Create `digilab-next/src/components/theme-provider.tsx`:
```tsx
'use client'

import { ThemeProvider as NextThemesProvider } from 'next-themes'
import { type ReactNode } from 'react'

export function ThemeProvider({ children }: { children: ReactNode }) {
  return (
    <NextThemesProvider attribute="class" defaultTheme="light" enableSystem={false}>
      {children}
    </NextThemesProvider>
  )
}
```

**Step 2: Update root layout**

Replace `digilab-next/src/app/layout.tsx`:
```tsx
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { ThemeProvider } from '@/components/theme-provider'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'DigiLab - Digimon TCG Tournament Tracker',
  description: 'Track player performance, store activity, and deck meta for the Digimon TCG community.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider>
          {children}
        </ThemeProvider>
      </body>
    </html>
  )
}
```

**Step 3: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/components/theme-provider.tsx digilab-next/src/app/layout.tsx
git commit -m "feat: add dark mode theme provider"
```

---

### Task 7: Header Component

**Files:**
- Create: `digilab-next/src/components/header.tsx`
- Modify: `digilab-next/src/app/layout.tsx`

**Step 1: Create header**

Create `digilab-next/src/components/header.tsx`:
```tsx
'use client'

import { useTheme } from 'next-themes'
import { useEffect, useState } from 'react'

export function Header() {
  const { theme, setTheme } = useTheme()
  const [mounted, setMounted] = useState(false)

  useEffect(() => setMounted(true), [])

  return (
    <header className="bg-gradient-to-r from-[#0A3055] to-[#0F4C81] text-white px-4 py-3 flex items-center justify-between">
      <div className="flex items-center gap-3">
        <h1 className="text-xl font-bold tracking-wide">
          <span className="text-[#F7941D]">Digi</span>Lab
        </h1>
        <span className="text-xs opacity-60 hidden sm:inline">Digimon TCG Tournament Tracker</span>
      </div>
      <div className="flex items-center gap-2">
        {mounted && (
          <button
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            className="p-2 rounded-md hover:bg-white/10 transition-colors text-sm"
            aria-label="Toggle dark mode"
          >
            {theme === 'dark' ? '☀️' : '🌙'}
          </button>
        )}
      </div>
    </header>
  )
}
```

**Step 2: Add header to layout**

Update `digilab-next/src/app/layout.tsx` to include the Header inside ThemeProvider, above `{children}`.

**Step 3: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/components/header.tsx digilab-next/src/app/layout.tsx
git commit -m "feat: add header with DigiLab branding and dark mode toggle"
```

---

### Task 8: Dashboard Filter Hook & Title Strip

**Files:**
- Create: `digilab-next/src/hooks/use-dashboard-filters.ts`
- Create: `digilab-next/src/components/dashboard/title-strip.tsx`

**Step 1: Create filter hook**

Create `digilab-next/src/hooks/use-dashboard-filters.ts`:
```tsx
'use client'

import { useState, useCallback } from 'react'

export interface DashboardFilters {
  format: string
  eventType: string
}

export function useDashboardFilters() {
  const [filters, setFilters] = useState<DashboardFilters>({
    format: '',
    eventType: 'locals',  // Default matches Shiny app
  })

  const setFormat = useCallback((format: string) => {
    setFilters(prev => ({ ...prev, format }))
  }, [])

  const setEventType = useCallback((eventType: string) => {
    setFilters(prev => ({ ...prev, eventType }))
  }, [])

  const resetFilters = useCallback(() => {
    setFilters({ format: '', eventType: 'locals' })
  }, [])

  // Build query string for API calls
  const queryString = new URLSearchParams(
    Object.entries(filters).filter(([, v]) => v !== '')
  ).toString()

  return { filters, setFormat, setEventType, resetFilters, queryString }
}
```

**Step 2: Create title strip component**

Create `digilab-next/src/components/dashboard/title-strip.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'
import type { DashboardFilters } from '@/hooks/use-dashboard-filters'

interface TitleStripProps {
  filters: DashboardFilters
  onFormatChange: (format: string) => void
  onEventTypeChange: (eventType: string) => void
  onReset: () => void
}

const EVENT_TYPES = [
  { value: '', label: 'All Events' },
  { value: 'locals', label: 'Locals' },
  { value: 'regional', label: 'Regional' },
  { value: 'major', label: 'Major' },
  { value: 'online', label: 'Online' },
]

export function TitleStrip({ filters, onFormatChange, onEventTypeChange, onReset }: TitleStripProps) {
  const [formats, setFormats] = useState<{ format_id: string; display_name: string }[]>([])

  useEffect(() => {
    fetch('/api/dashboard/formats')
      .then(r => r.json())
      .then(setFormats)
      .catch(console.error)
  }, [])

  const formatDisplay = filters.format
    ? formats.find(f => f.format_id === filters.format)?.display_name ?? filters.format
    : 'All Formats'

  const eventDisplay = EVENT_TYPES.find(e => e.value === filters.eventType)?.label ?? 'All Events'

  return (
    <div className="title-strip mb-2">
      <div className="flex justify-between items-center gap-4">
        <div className="flex items-center gap-2 text-white">
          <svg className="w-5 h-5 opacity-80" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
              d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
          </svg>
          <span className="font-semibold whitespace-nowrap">
            {formatDisplay} <span className="opacity-60">·</span> {eventDisplay}
          </span>
        </div>
        <div className="flex items-center gap-2 flex-shrink-1">
          <select
            value={filters.format}
            onChange={e => onFormatChange(e.target.value)}
            className="title-strip-select"
          >
            <option value="">All Formats</option>
            {formats.map(f => (
              <option key={f.format_id} value={f.format_id}>{f.display_name}</option>
            ))}
          </select>
          <select
            value={filters.eventType}
            onChange={e => onEventTypeChange(e.target.value)}
            className="title-strip-select"
          >
            {EVENT_TYPES.map(e => (
              <option key={e.value} value={e.value}>{e.label}</option>
            ))}
          </select>
          <button
            onClick={onReset}
            className="p-1.5 rounded hover:bg-white/10 text-white/70 hover:text-white transition-colors"
            title="Reset filters"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  )
}
```

**Step 3: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/hooks/ digilab-next/src/components/dashboard/title-strip.tsx
git commit -m "feat: add dashboard filter hook and title strip component"
```

---

### Task 9: Value Boxes (Stat Cards)

**Files:**
- Create: `digilab-next/src/components/dashboard/stat-boxes.tsx`

**Step 1: Create stat boxes**

This component renders the 4 value boxes: Tournaments, Players, Hot Deck, Top Deck.
Port the CSS from `www/custom.css` `.value-box-digital` classes.

The component should:
- Accept `queryString` prop to fetch filtered data
- Fetch from `/api/dashboard/stats` for tournament/player counts
- Fetch from `/api/dashboard/top-decks` for top deck (most popular)
- Calculate hot deck from a separate endpoint or include in stats
- Show card images from `https://images.digimoncard.io/images/cards/{id}.jpg`
- Match the digital aesthetic (gradient background, grid overlay, colored left borders)
- Handle loading states with skeleton shimmer

Create a dedicated API route for hot deck and most-popular-deck data, or combine into the stats route.

Refer to `www/custom.css` lines for `.value-box-digital`, `.vb-digital-grid`, `.vb-content`, etc. (cataloged in design doc).

**Step 2: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/components/dashboard/stat-boxes.tsx
git commit -m "feat: add dashboard value boxes with digital Digimon aesthetic"
```

---

### Task 10: Top Decks Card Grid

**Files:**
- Create: `digilab-next/src/components/dashboard/top-decks.tsx`

**Step 1: Create top decks component**

Port the `.top-decks-grid`, `.deck-item`, `.deck-card-img`, `.deck-bar`, `.deck-info` CSS.

The component should:
- Fetch from `/api/dashboard/top-decks?{queryString}`
- Show 6 decks in a responsive grid (`grid-cols-1 md:grid-cols-2 lg:grid-cols-3`)
- Each deck shows: card image, name, win rate bar (colored by deck color), win count and win rate text
- Card images from `https://images.digimoncard.io/images/cards/{display_card_id}.jpg`
- Fallback image: `BT1-001.jpg`
- Bar width = win_rate%, bar color from `DECK_COLORS[primary_color]`
- Show total tournament count in card header

**Step 2: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/components/dashboard/top-decks.tsx
git commit -m "feat: add top decks card grid with win rate bars"
```

---

### Task 11: Recent Tournaments Table

**Files:**
- Create: `digilab-next/src/components/dashboard/recent-tournaments.tsx`

**Step 1: Create table component**

Use TanStack Table. Port from the reactable config in `public-dashboard-server.R` lines 289-350.

Columns:
- Store (minWidth 150, ellipsis overflow)
- Date (width 100)
- Players (width 65, center aligned)
- Winner (width 110)
- Rating (width 60, center aligned, show "-" if 0)

Hidden columns: `tournament_id`, `store_id`

Rows should be clickable (cursor pointer). For the PoC, clicking can just log the tournament_id.

Table should be compact and striped.

**Step 2: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/components/dashboard/recent-tournaments.tsx
git commit -m "feat: add recent tournaments table with TanStack Table"
```

---

### Task 12: Top Players Table

**Files:**
- Create: `digilab-next/src/components/dashboard/top-players.tsx`

**Step 1: Create table component**

Same approach as Task 11. Columns:
- Player (minWidth 120)
- Events (minWidth 60, center)
- Wins (minWidth 60, center)
- Top 3 (minWidth 60, center)
- Rating (minWidth 70, center) — competitive_rating
- Achv (minWidth 60, center) — achievement_score

Header should include an info icon with tooltip explaining Rating and Achievement.

**Step 2: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/components/dashboard/top-players.tsx
git commit -m "feat: add top players table with rating and achievement columns"
```

---

### Task 13: Charts (Conversion, Color Dist, Trend)

**Files:**
- Create: `digilab-next/src/components/dashboard/charts.tsx`

**Step 1: Create chart components**

Use Recharts. Create three chart components in one file (or separate files if cleaner):

1. **ConversionChart** — Horizontal `<BarChart>` with deck-colored bars, percentage labels
2. **ColorDistChart** — Horizontal `<BarChart>` with deck-colored bars, entry counts
3. **TrendChart** — `<LineChart>` with two series:
   - "Daily Avg" (blue #0F4C81, with dots)
   - "7-Day Rolling Avg" (orange #F7941D, dashed)
   - DateTime X-axis

Each chart fetches from its respective API endpoint.

Wrap each in a Card component (shadcn/ui) with appropriate headers matching the Shiny app:
- "Top 3 Conversion Rate"
- "Color Distribution of Decks Played"
- "Tournament Player Counts Over Time"

**Step 2: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/components/dashboard/charts.tsx
git commit -m "feat: add conversion, color distribution, and trend charts"
```

---

### Task 14: Meta Share Timeline Chart

**Files:**
- Create: `digilab-next/src/components/dashboard/meta-timeline.tsx`

**Step 1: Create meta timeline**

This is the most complex chart. Use Recharts `<AreaChart>` with stacking.

- Fetch from `/api/dashboard/charts/meta-timeline`
- API returns `{ weeks: string[], series: { name, color, data[] }[] }`
- Each series is a stacked area with deck color
- X-axis: week labels (e.g., "Jan 15")
- Y-axis: 0-100% meta share
- Legend: vertical, right side, scrollable if many decks
- Tooltip: shared, show only non-zero decks sorted by value descending

Wrap in a Card with header "Meta Share Over Time".

**Step 2: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/components/dashboard/meta-timeline.tsx
git commit -m "feat: add stacked area meta share timeline chart"
```

---

### Task 15: Dashboard Page Assembly

**Files:**
- Modify: `digilab-next/src/app/page.tsx`

**Step 1: Assemble all components**

Update `digilab-next/src/app/page.tsx` to compose all dashboard components:

```tsx
'use client'

import { useDashboardFilters } from '@/hooks/use-dashboard-filters'
import { TitleStrip } from '@/components/dashboard/title-strip'
import { StatBoxes } from '@/components/dashboard/stat-boxes'
import { TopDecks } from '@/components/dashboard/top-decks'
import { Charts } from '@/components/dashboard/charts'
import { RecentTournaments } from '@/components/dashboard/recent-tournaments'
import { TopPlayers } from '@/components/dashboard/top-players'
import { MetaTimeline } from '@/components/dashboard/meta-timeline'

export default function Dashboard() {
  const { filters, setFormat, setEventType, resetFilters, queryString } = useDashboardFilters()

  return (
    <main className="max-w-7xl mx-auto px-4 py-4">
      <TitleStrip
        filters={filters}
        onFormatChange={setFormat}
        onEventTypeChange={setEventType}
        onReset={resetFilters}
      />

      {/* Value Boxes - 4 column grid */}
      <StatBoxes queryString={queryString} />

      {/* Top Decks Card */}
      <TopDecks queryString={queryString} />

      {/* Charts - 3 column grid */}
      <Charts queryString={queryString} />

      {/* Tables - 2 column grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        <RecentTournaments queryString={queryString} />
        <TopPlayers queryString={queryString} />
      </div>

      {/* Meta Timeline - full width */}
      <MetaTimeline queryString={queryString} />
    </main>
  )
}
```

**Step 2: Verify the full dashboard**

Run `npm run dev` and check http://localhost:3000

Expected: Full dashboard with all components rendering, data loading from local DuckDB.

**Step 3: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/app/page.tsx
git commit -m "feat: assemble complete dashboard page with all components"
```

---

### Task 16: Digital Digimon CSS Aesthetic

**Files:**
- Modify: `digilab-next/src/app/globals.css`

**Step 1: Port the key CSS classes**

Add to `globals.css` the digital Digimon aesthetic styles. Key classes to port from `www/custom.css`:

1. `.title-strip` — gradient background with grid overlay pattern
2. `.title-strip-select` — styled native select dropdowns (light bg, dark text)
3. Value box gradient backgrounds (already in components as Tailwind, but may need grid overlay as CSS)
4. `.vb-digital-grid` — the repeating grid lines overlay effect
5. `.vb-digital-grid::before` — circuit accent diagonal
6. `.vb-digital-grid::after` — corner node glow
7. Dark mode variants using `dark:` Tailwind classes or `.dark` CSS selectors
8. Card, table, and chart dark mode styles
9. `@keyframes pulse-glow` for hot deck tracking animation

Reference: The complete CSS is cataloged in the design doc and in `www/custom.css`.

**Step 2: Verify light and dark mode**

Toggle between modes and compare visually to the Shiny app.

**Step 3: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/src/app/globals.css
git commit -m "feat: port digital Digimon CSS aesthetic with dark mode support"
```

---

### Task 17: Mobile Responsive Layout

**Files:**
- Modify: Various component files for responsive tweaks

**Step 1: Verify Tailwind responsive classes**

Most responsiveness should be handled by existing Tailwind grid classes:
- Value boxes: `grid-cols-1 sm:grid-cols-2 lg:grid-cols-4`
- Top decks: `grid-cols-1 md:grid-cols-2 lg:grid-cols-3`
- Charts: `grid-cols-1 md:grid-cols-3`
- Tables: `grid-cols-1 md:grid-cols-2`

**Step 2: Fix any mobile issues**

Check at 375px, 768px, and 1024px widths:
- Title strip should stack on mobile (filters below context)
- Value boxes should stack to 1 column on small screens
- Charts should stack to full-width on mobile
- Tables should be horizontally scrollable if needed
- Header should remain compact

**Step 3: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/
git commit -m "feat: mobile responsive layout adjustments"
```

---

### Task 18: Loading States & Polish

**Files:**
- Modify: Component files to add loading skeletons

**Step 1: Add loading states**

Each data-fetching component should show a skeleton while loading:
- Stat boxes: shimmer rectangles
- Top decks: card-shaped placeholders
- Charts: gray rectangle placeholders
- Tables: row shimmer placeholders

Use shadcn/ui `Skeleton` component (already installed in Task 2).

**Step 2: Add error states**

Show a simple error message if an API call fails, matching the Shiny app's `digital_empty_state` pattern.

**Step 3: Final visual pass**

Compare the complete dashboard side-by-side with the Shiny version:
- Same data for same filters?
- Same visual hierarchy?
- Same colors and aesthetic?
- Dark mode matches?
- Mobile layout reasonable?

**Step 4: Commit**

```bash
cd "E:\Michael Lopez\Projects\repos\digimon-tcg-standings"
git add digilab-next/
git commit -m "feat: add loading skeletons and error states"
```

---

## Human Checkpoints

| After Task | What to Check |
|-----------|---------------|
| Task 1 | `npm run dev` loads default page |
| Task 3 | `/api/test-db` returns tournament count |
| Task 5 | API routes return real data from DuckDB |
| Task 15 | Full dashboard renders with all components |
| Task 16 | Visual design matches Shiny app |
| Task 17 | Mobile layout works |
| Task 18 | Side-by-side comparison with Shiny dashboard |

## Notes for Implementer

- **DuckDB on Windows:** The `duckdb` npm package may have issues. `@duckdb/node-api` is the alternative. Check compatibility before proceeding.
- **SQL injection:** The filter builder uses string interpolation for simplicity in this PoC. For production, parameterized queries are required.
- **Rating calculations:** These are compute-heavy (5-pass Elo). For the PoC they run on every API call. Production would cache them.
- **DigimonCard.io images:** CDN URLs work from any frontend. Format: `https://images.digimoncard.io/images/cards/{card_id}.jpg`
- **Event types in Shiny app:** The R code references `EVENT_TYPES` constant. Values are: `locals`, `regional`, `major`, `online`.
