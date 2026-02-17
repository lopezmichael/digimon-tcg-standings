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
} from '@/lib/types'
import { DECK_COLORS, COLOR_ORDER } from '@/lib/types'

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

// --- Most Popular Deck ---

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

  const countResult = await query<{ n: number }>(`
    SELECT COUNT(*) as n FROM tournaments t WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
  `)
  const tournamentCount = countResult[0]?.n ?? 0

  if (tournamentCount < 10) {
    return { insufficient_data: true, tournament_count: tournamentCount }
  }

  const medianResult = await query<{ median_date: string | Date }>(`
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY event_date) as median_date
    FROM tournaments t WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
  `)
  const rawMedian = medianResult[0]?.median_date
  if (!rawMedian) return { insufficient_data: true, tournament_count: tournamentCount }
  // DuckDB may return a Date object; convert to YYYY-MM-DD string
  const medianDate = rawMedian instanceof Date
    ? rawMedian.toISOString().split('T')[0]
    : String(rawMedian).slice(0, 10)

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

  const olderMap = new Map(olderMeta.map(r => [r.archetype_name, r.meta_share]))
  const merged = newerMeta.map(r => ({
    ...r,
    delta: r.meta_share - (olderMap.get(r.archetype_name) ?? 0),
  }))

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

// --- Top Decks ---

export async function getTopDecks(
  filters: { format?: string; eventType?: string }
): Promise<TopDeck[]> {
  const f = buildFilterClauses(filters)

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
           CAST(t.event_date AS VARCHAR) as Date, t.player_count as Players,
           p.display_name as Winner
    FROM tournaments t
    JOIN stores s ON t.store_id = s.store_id
    LEFT JOIN results r ON t.tournament_id = r.tournament_id AND r.placement = 1
    LEFT JOIN players p ON r.player_id = p.player_id
    WHERE 1=1 ${f.store} ${f.format} ${f.eventType}
    ORDER BY t.event_date DESC
    LIMIT 10
  `)

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
    SELECT CAST(event_date AS VARCHAR) as event_date,
           COUNT(*) as tournaments,
           ROUND(AVG(player_count), 1) as avg_players
    FROM tournaments t
    WHERE 1=1 ${f.format} ${f.eventType} ${f.store}
    GROUP BY event_date
    ORDER BY event_date
  `)

  return result.map((row, _i) => {
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
    SELECT CAST(date_trunc('week', t.event_date) AS VARCHAR) as week_start,
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

  const weeks = [...new Set(result.map(r => r.week_start))].sort()

  const weekTotals = new Map<string, number>()
  for (const row of result) {
    weekTotals.set(row.week_start, (weekTotals.get(row.week_start) ?? 0) + row.entries)
  }

  const archetypeStats = new Map<string, { color: string; total: number }>()
  for (const row of result) {
    const existing = archetypeStats.get(row.archetype_name)
    archetypeStats.set(row.archetype_name, {
      color: row.primary_color,
      total: (existing?.total ?? 0) + row.entries,
    })
  }

  const totalEntries = [...archetypeStats.values()].reduce((sum, v) => sum + v.total, 0)

  const sortedDecks = [...archetypeStats.entries()]
    .map(([name, stats]) => ({
      name,
      color: stats.color,
      share: stats.total / totalEntries,
      colorRank: COLOR_ORDER.indexOf(stats.color) ?? 999,
    }))
    .sort((a, b) => a.colorRank - b.colorRank || b.share - a.share)

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

  const weekLabels = weeks.map(w => {
    const d = new Date(w)
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  })

  return { weeks: weekLabels, series }
}

// --- Rating Calculations ---

export async function getCompetitiveRatings(): Promise<{ player_id: number; competitive_rating: number }[]> {
  const results = await query<{
    tournament_id: number
    player_id: number
    placement: number
    event_date: string | Date
    player_count: number
    rounds: number | null
  }>(`
    SELECT r.tournament_id, r.player_id, r.placement,
           CAST(t.event_date AS VARCHAR) as event_date, t.player_count, t.rounds
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    JOIN players p ON r.player_id = p.player_id
    WHERE r.placement IS NOT NULL
      AND t.player_count IS NOT NULL
      AND t.player_count >= 4
    ORDER BY t.event_date ASC, r.tournament_id, r.placement
  `)

  if (results.length === 0) return []

  const ratings = new Map<number, number>()
  const eventsPlayed = new Map<number, number>()
  for (const r of results) {
    if (!ratings.has(r.player_id)) {
      ratings.set(r.player_id, 1500)
      eventsPlayed.set(r.player_id, 0)
    }
  }

  const tournamentMap = new Map<number, typeof results>()
  for (const r of results) {
    if (!tournamentMap.has(r.tournament_id)) tournamentMap.set(r.tournament_id, [])
    tournamentMap.get(r.tournament_id)!.push(r)
  }

  const tournaments = [...new Set(results.map(r => r.tournament_id))]
    .map(id => {
      const first = results.find(r => r.tournament_id === id)!
      return { id, event_date: first.event_date, rounds: first.rounds }
    })
    .sort((a, b) => String(a.event_date).localeCompare(String(b.event_date)))

  const currentDate = new Date()

  for (let pass = 0; pass < 5; pass++) {
    for (const tourney of tournaments) {
      const tourneyResults = (tournamentMap.get(tourney.id) ?? [])
        .sort((a, b) => a.placement - b.placement)

      if (tourneyResults.length < 2) continue

      const eventDate = new Date(tourney.event_date)
      const monthsAgo = (currentDate.getTime() - eventDate.getTime()) / (1000 * 60 * 60 * 24 * 30.44)
      const decayWeight = Math.pow(0.5, monthsAgo / 4)

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
    const placementPts = pResults.reduce(
      (sum, r) => sum + getPlacementPoints(r.placement, r.player_count), 0
    )

    const uniqueStores = new Set(pResults.map(r => r.store_id)).size
    const storeBonus = uniqueStores >= 6 ? 50 : uniqueStores >= 4 ? 25 : uniqueStores >= 2 ? 10 : 0

    const knownDecks = pResults.filter(r => r.archetype_name && r.archetype_name !== 'UNKNOWN')
    const uniqueDecks = new Set(knownDecks.map(r => r.archetype_id)).size
    const deckBonus = uniqueDecks >= 3 ? 15 : 0

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

  const storePlayerMap = new Map<number, number[]>()
  for (const sp of storePlayers) {
    if (!storePlayerMap.has(sp.store_id)) storePlayerMap.set(sp.store_id, [])
    storePlayerMap.get(sp.store_id)!.push(sp.player_id)
  }

  return storeStats.map(store => {
    const players = storePlayerMap.get(store.store_id) ?? []
    const playerRatings = players.map(pid => ratingMap.get(pid) ?? 1500)
    const avgRating = playerRatings.length > 0
      ? playerRatings.reduce((a, b) => a + b, 0) / playerRatings.length
      : 1500

    const strengthScore = Math.min(Math.max((avgRating - 1200) / 8, 0), 100)
    const attendanceScore = store.avg_attendance
      ? Math.min(Math.max((store.avg_attendance - 4) / 0.28, 0), 100)
      : 0
    const activityScore = Math.min((store.event_count / 24) * 100, 100)

    const storeRating = Math.round(
      strengthScore * 0.5 + attendanceScore * 0.3 + activityScore * 0.2
    )

    return { store_id: store.store_id, store_rating: storeRating }
  })
}

// --- Format List ---

export async function getFormats(): Promise<{ format_id: string; display_name: string }[]> {
  return query<{ format_id: string; display_name: string }>(`
    SELECT format_id, display_name
    FROM formats
    WHERE is_active = TRUE
    ORDER BY sort_order ASC, release_date DESC
  `)
}
