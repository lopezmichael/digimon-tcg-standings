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
