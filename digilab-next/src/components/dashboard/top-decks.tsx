'use client'

import { useEffect, useState } from 'react'
import { Skeleton } from '@/components/ui/skeleton'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Swords } from 'lucide-react'
import { DECK_COLORS, type TopDeck } from '@/lib/types'

interface TopDecksProps {
  queryString: string
}

export function TopDecks({ queryString }: TopDecksProps) {
  const [decks, setDecks] = useState<TopDeck[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/top-decks${qs}`)
      .then(r => r.json())
      .then(data => setDecks(data))
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  if (loading) {
    return (
      <Card className="mb-4">
        <CardHeader><CardTitle>Top Decks</CardTitle></CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {[...Array(6)].map((_, i) => (
              <Skeleton key={i} className="h-32 rounded-lg" />
            ))}
          </div>
        </CardContent>
      </Card>
    )
  }

  if (decks.length === 0) {
    return (
      <Card className="mb-4">
        <CardHeader><CardTitle>Top Decks</CardTitle></CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-center py-8">No deck data available for current filters.</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="card-hover mb-4">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Swords className="w-4 h-4 text-muted-foreground" />
          Top Decks
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {decks.map(deck => {
            const barColor = DECK_COLORS[deck.primary_color] ?? '#6B7280'
            const imgUrl = deck.display_card_id
              ? `https://images.digimoncard.io/images/cards/${deck.display_card_id}.jpg`
              : null

            return (
              <div key={deck.archetype_name} className="deck-item flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                {imgUrl && (
                  <img
                    src={imgUrl}
                    alt={deck.archetype_name}
                    className="w-14 h-14 rounded object-cover object-top shrink-0"
                    onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
                  />
                )}
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-sm truncate">{deck.archetype_name}</div>
                  <div className="text-xs text-muted-foreground mb-1">
                    {deck.first_places} win{deck.first_places !== 1 ? 's' : ''} &middot; {deck.times_played} entries
                  </div>
                  <div className="h-2 rounded-full bg-muted overflow-hidden">
                    <div
                      className="h-full rounded-full transition-all duration-500"
                      style={{
                        width: `${Math.min(deck.win_rate, 100)}%`,
                        backgroundColor: barColor,
                      }}
                    />
                  </div>
                  <div className="text-xs text-muted-foreground mt-0.5">{deck.win_rate}% win rate</div>
                </div>
              </div>
            )
          })}
        </div>
      </CardContent>
    </Card>
  )
}
