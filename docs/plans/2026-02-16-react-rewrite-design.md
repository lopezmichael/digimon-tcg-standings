# React Rewrite - Dashboard Proof of Concept

**Date:** 2026-02-16
**Branch:** `explore/react-rewrite`
**Status:** Design approved, implementation pending

## Goal

Evaluate whether DigiLab should migrate from R Shiny to a modern JavaScript framework by building a full-fidelity Dashboard tab as a proof of concept. This also tests how autonomously Claude Code can build a production-quality React app.

**Success criteria:**
- Dashboard loads in under 1 second (vs ~3-5s for Shiny cold start)
- All numbers match the Shiny dashboard for the same filters
- Dark/light mode works
- Mobile layout is functional
- Visual design matches the current DigiLab digital Digimon aesthetic

## Why Rewrite?

The current Shiny app has outgrown what the framework does well:

1. **Slow initial load** - Every page load boots an R process, loads packages, connects to DB, renders server-side, then establishes a WebSocket. A static JS bundle served from a CDN skips all of this.
2. **Deep linking was painful** - Built a custom 381-line `url-routing-server.R` to do what React Router gives for free.
3. **3,500 lines of custom CSS** - Fighting Shiny's UI defaults constantly. A component library like shadcn/ui gives full control.
4. **Every click round-trips to the server** - Opening a modal requires WebSocket → R → re-render → send back. In React it's instant client-side state.
5. **32 reactive values across 6 categories** - Shiny's reactivity model works but gets unwieldy. React state management is more explicit.

## Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Framework | **Next.js 15 (App Router)** | SSR for SEO, file-based routing, server components, Vercel deployment |
| UI Components | **shadcn/ui + Tailwind CSS** | Full design control, dark mode built-in, accessible |
| Charts | **Recharts** | React-native, declarative JSX, good defaults |
| Tables | **TanStack Table** | Sorting, filtering, pagination — React equivalent of reactable |
| Dark Mode | **next-themes** | 3-line setup, system preference detection |
| Database (dev) | **DuckDB via @duckdb/node-api** | Reads same `data/local.duckdb` file as Shiny app |
| Database (prod) | **MotherDuck** | Same cloud DB the Shiny app uses |
| Hosting | **Vercel** | Zero-config Next.js deployment, free tier |
| Language | **TypeScript** | Type safety, better DX, one language for everything |

### Alternatives Considered

**Next.js Pages Router:** More established but being phased out. App Router is the future and handles layouts/loading/streaming better.

**Astro + React Islands:** Fastest initial load but awkward for complex interactivity. Would need another rewrite when adding admin pages.

**Python FastAPI backend:** More familiar language but means two repos/deployments and two ecosystems to maintain.

## Scope

**In scope (Dashboard tab only):**
- 4 value boxes (Tournaments, Players, Hot Deck, Top Deck)
- Top Decks card grid with DigimonCard.io images
- 3 chart cards (Conversion Rate, Color Distribution, Tournament Trend)
- Meta Share Timeline chart
- Recent Tournaments table (clickable rows)
- Top Players table with Rating/Achievement columns
- Format and Event Type filter dropdowns
- Dark/light mode toggle
- Mobile responsive layout
- Digital Digimon visual aesthetic

**Out of scope:**
- Other tabs (Players, Meta, Tournaments, Stores)
- Admin pages
- Scene selection / multi-region
- User authentication
- Deep linking / URL routing beyond the dashboard
- Public submissions / OCR

## Project Structure

```
digilab-next/
├── src/
│   ├── app/
│   │   ├── layout.tsx           # Root layout (header, dark mode provider)
│   │   ├── page.tsx             # Dashboard (home page)
│   │   ├── globals.css          # Global styles + Tailwind
│   │   └── api/
│   │       └── dashboard/
│   │           ├── stats/route.ts
│   │           ├── top-decks/route.ts
│   │           ├── recent-tournaments/route.ts
│   │           ├── top-players/route.ts
│   │           └── charts/
│   │               ├── conversion/route.ts
│   │               ├── color-dist/route.ts
│   │               ├── trend/route.ts
│   │               └── meta-timeline/route.ts
│   ├── components/
│   │   ├── ui/                  # shadcn/ui components
│   │   ├── dashboard/
│   │   │   ├── stat-boxes.tsx
│   │   │   ├── top-decks.tsx
│   │   │   ├── charts.tsx
│   │   │   ├── recent-tournaments.tsx
│   │   │   ├── top-players.tsx
│   │   │   └── meta-timeline.tsx
│   │   ├── header.tsx
│   │   └── theme-provider.tsx
│   ├── lib/
│   │   ├── db.ts               # DuckDB/MotherDuck connection
│   │   ├── queries/
│   │   │   └── dashboard.ts    # All dashboard SQL queries
│   │   └── utils.ts
│   └── hooks/
│       └── use-dashboard-filters.ts
├── tailwind.config.ts
├── next.config.ts
├── package.json
└── tsconfig.json
```

## Data Layer

### Connection Strategy

Same pattern as the R app's `connect_db()` — auto-detect environment:

```typescript
function getConnection() {
  if (process.env.MOTHERDUCK_TOKEN && process.env.NODE_ENV === 'production') {
    return connectMotherDuck(process.env.MOTHERDUCK_TOKEN)
  }
  return connectLocal('../data/local.duckdb')
}
```

### SQL Query Porting

The ~20 SQL queries in `public-dashboard-server.R` port directly. The SQL stays identical — same tables, same joins, same filter logic. Only the wrapper changes from R to TypeScript.

The `build_dashboard_filters()` helper becomes a TypeScript function that constructs the same SQL WHERE clauses based on format, event type, and store filters.

### Development Workflow

1. Run `python scripts/sync_from_motherduck.py --yes` to get fresh data
2. Both Shiny and Next.js apps read from the same `data/local.duckdb`
3. Develop and compare side-by-side

## Component Mapping

### Value Boxes
Port the CSS classes (`value-box-digital`, `vb-digital-grid`, `vb-content`) to Tailwind + CSS modules. The "Hot Deck" and "Top Deck" boxes use DigimonCard.io CDN images which work from any frontend.

### Charts

| Current (Highcharter) | New (Recharts) | Type |
|---|---|---|
| `conversion_rate_chart` | `<BarChart layout="vertical">` | Top 3 conversion rate |
| `color_dist_chart` | `<BarChart layout="vertical">` | Color distribution |
| `tournaments_trend_chart` | `<LineChart>` (two series) | Player counts + rolling avg |
| `meta_share_timeline` | `<AreaChart>` stacked | Meta share over time |

Digimon deck colors port as a TypeScript constant:
```typescript
const DECK_COLORS = {
  Red: '#E5383B', Blue: '#2D7DD2', Yellow: '#F5B700',
  Green: '#38A169', Black: '#2D3748', Purple: '#805AD5',
  White: '#A0AEC0', Multi: '#EC4899', Other: '#9CA3AF'
}
```

### Tables
TanStack Table replaces reactable. Column definitions map 1:1. Clickable rows become `onClick` handlers that set React state (no WebSocket round-trip).

### Dark/Light Mode
`next-themes` with Tailwind's `dark:` variant classes. Colors from `_brand.yml` map to CSS custom properties.

### Responsive Layout
`layout_columns` with `breakpoints(sm, md, lg)` → Tailwind grid: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4`.

## Claude Code Autonomy Assessment

### High confidence (autonomous)
- Project scaffolding (create-next-app, Tailwind, shadcn/ui)
- API routes with SQL queries (direct port from R)
- Dashboard page layout (Tailwind + JSX)
- TanStack Table setup (column defs map 1:1 from reactable)
- Dark mode toggle (boilerplate)
- Filter state management (useState + URL params)
- TypeScript types from schema.sql

### Medium confidence (may need one feedback round)
- DuckDB Node.js connection (Windows quirks possible)
- Recharts styling to match Highcharter (exact look takes iteration)
- CSS aesthetic port (digital grid, glowing borders, colors)
- Hot Deck trend calculation (non-trivial R logic port)

### Low confidence (needs human help)
- MotherDuck production connection (token, Vercel env config)
- Visual QA (Claude Code can't see rendered output)
- Vercel deployment (interactive account setup)
- Node.js/npm environment setup (if not installed)

**Estimated split: ~70% autonomous, ~20% one feedback round, ~10% needs human.**

## Development Phases

### Phase 1: Scaffold & Connect
1. Initialize Next.js in `digilab-next/`
2. Install dependencies
3. Set up DuckDB connection to `data/local.duckdb`
4. Create TypeScript types from schema
5. Verify DB connection with simple query

**Human checkpoint:** Run `npm run dev`, confirm it loads.

### Phase 2: API Routes
1. Port all ~20 dashboard SQL queries to TypeScript
2. Create 8 API route files
3. Port `build_dashboard_filters()` helper
4. Port Hot Deck trend calculation
5. Port rating/achievement score joins

**Human checkpoint:** Hit `/api/dashboard/stats` in browser, confirm numbers match Shiny.

### Phase 3: Layout & Static Components
1. Root layout with header and dark/light toggle
2. Title strip with filter dropdowns
3. 4 value box components with digital aesthetic
4. Page grid layout

**Human checkpoint:** Visual check of skeleton.

### Phase 4: Interactive Components
1. Wire stat boxes to API with loading states
2. Top Decks card grid with card images
3. Recent Tournaments table (clickable rows)
4. Top Players table with Rating/Achievement
5. All 4 Recharts charts
6. Connect filters to refetch

**Human checkpoint:** Side-by-side comparison with Shiny dashboard.

### Phase 5: Polish & Dark Mode
1. Port digital Digimon CSS aesthetic
2. Dark mode with brand colors
3. Mobile responsive layout
4. Loading skeletons

**Human checkpoint:** Toggle dark mode, resize to mobile, compare to Shiny.

## Commit Strategy

One commit per sub-task within each phase. Small, logical commits for easy debugging if something breaks.

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | Next.js App Router | Future-proof, best routing, Vercel deployment |
| Charts | Recharts | Most React-native, declarative |
| Tables | TanStack Table | Feature parity with reactable |
| Styling | Tailwind + shadcn/ui | Full control, dark mode, accessible |
| DB (dev) | Local DuckDB file | Same data as Shiny, no network dependency |
| DB (prod) | MotherDuck serverless | Same cloud DB, minimal backend code |
| Scope | Dashboard only | Prove the stack before committing to full rewrite |
