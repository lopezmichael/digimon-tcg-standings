'use client'

import { useEffect, useState } from 'react'
import { Skeleton } from '@/components/ui/skeleton'
import { Calendar, Users, Flame, Crown } from 'lucide-react'

interface StatBoxesProps {
  queryString: string
}

interface Stats {
  totalTournaments: number
  totalPlayers: number
  totalStores: number
  totalDecks: number
}

interface MostPopularDeck {
  archetype_name: string
  display_card_id: string | null
  entries: number
  meta_share: number
}

interface HotDeck {
  insufficient_data: boolean
  no_trending?: boolean
  tournament_count?: number
  archetype_name?: string
  display_card_id?: string | null
  delta?: number
}

const BOX_ICONS = [
  { Icon: Calendar, color: 'text-blue-400' },
  { Icon: Users, color: 'text-emerald-400' },
  { Icon: Flame, color: 'text-orange-400' },
  { Icon: Crown, color: 'text-purple-400' },
]

export function StatBoxes({ queryString }: StatBoxesProps) {
  const [stats, setStats] = useState<Stats | null>(null)
  const [topDeck, setTopDeck] = useState<MostPopularDeck | null>(null)
  const [hotDeck, setHotDeck] = useState<HotDeck | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''

    Promise.all([
      fetch(`/api/dashboard/stats${qs}`).then(r => r.json()),
      fetch(`/api/dashboard/most-popular-deck${qs}`).then(r => r.json()),
      fetch(`/api/dashboard/hot-deck${qs}`).then(r => r.json()),
    ])
      .then(([statsData, topDeckData, hotDeckData]) => {
        setStats(statsData)
        setTopDeck(topDeckData)
        setHotDeck(hotDeckData)
      })
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  if (loading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
        {[...Array(4)].map((_, i) => (
          <Skeleton key={i} className="h-24 rounded-lg" />
        ))}
      </div>
    )
  }

  const cardImgUrl = (cardId: string | null | undefined) =>
    cardId ? `https://images.digimoncard.io/images/cards/${cardId}.jpg` : null

  const isHotDeckTracking = hotDeck?.insufficient_data

  const boxes = [
    {
      label: 'Tournaments',
      value: stats?.totalTournaments ?? 0,
      borderColor: 'border-l-blue-500',
      subtitle: null as string | null,
      image: null as string | null,
      isTracking: false,
    },
    {
      label: 'Players',
      value: stats?.totalPlayers ?? 0,
      borderColor: 'border-l-emerald-500',
      subtitle: null,
      image: null,
      isTracking: false,
    },
    {
      label: 'Hot Deck',
      value: hotDeck?.insufficient_data
        ? 'Tracking...'
        : hotDeck?.no_trending
          ? 'No trend'
          : hotDeck?.archetype_name ?? '-',
      borderColor: 'border-l-orange-500',
      subtitle: hotDeck?.insufficient_data
        ? `${10 - (hotDeck?.tournament_count ?? 0)} more events needed`
        : hotDeck?.no_trending
          ? 'stable meta'
          : hotDeck?.delta ? `+${hotDeck.delta}% share` : null,
      image: cardImgUrl(hotDeck?.display_card_id),
      isTracking: isHotDeckTracking,
    },
    {
      label: 'Top Deck',
      value: topDeck?.archetype_name ?? '-',
      borderColor: 'border-l-purple-500',
      subtitle: topDeck ? `${topDeck.meta_share}% of meta` : null,
      image: cardImgUrl(topDeck?.display_card_id),
      isTracking: false,
    },
  ]

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
      {boxes.map((box, index) => {
        const { Icon, color } = BOX_ICONS[index]
        return (
          <div
            key={box.label}
            className={`
              stat-box relative overflow-hidden rounded-lg border-l-4 ${box.borderColor}
              bg-gradient-to-br from-[#0A3055] to-[#0D3B66] p-4 text-white
              ${box.isTracking ? 'stat-box-tracking' : ''}
            `}
          >
            {/* Grid overlay */}
            <div
              className="absolute inset-0 opacity-[0.03] pointer-events-none"
              style={{
                backgroundImage:
                  'repeating-linear-gradient(0deg, transparent, transparent 19px, rgba(255,255,255,0.5) 19px, rgba(255,255,255,0.5) 20px), repeating-linear-gradient(90deg, transparent, transparent 19px, rgba(255,255,255,0.5) 19px, rgba(255,255,255,0.5) 20px)',
              }}
            />
            <div className="relative z-10 flex items-center gap-3">
              {box.image ? (
                <img
                  src={box.image}
                  alt=""
                  className="w-12 h-12 rounded object-cover object-top opacity-80"
                  onError={(e) => {
                    ;(e.target as HTMLImageElement).style.display = 'none'
                  }}
                />
              ) : (
                <div className="w-10 h-10 rounded-lg bg-white/10 flex items-center justify-center shrink-0">
                  <Icon className={`w-5 h-5 ${color}`} />
                </div>
              )}
              <div className="min-w-0">
                <div className="text-2xl font-bold truncate">{box.value}</div>
                <div className="text-xs text-white/60 uppercase tracking-wider">
                  {box.label}
                </div>
                {box.subtitle && (
                  <div className="text-xs text-white/50 mt-0.5">
                    {box.subtitle}
                  </div>
                )}
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}
