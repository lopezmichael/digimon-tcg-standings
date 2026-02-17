'use client'

import { useEffect, useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { TrendingUp, Trophy, Medal } from 'lucide-react'
import type { RisingStar } from '@/lib/types'

interface RisingStarsProps {
  queryString: string
}

export function RisingStars({ queryString }: RisingStarsProps) {
  const [data, setData] = useState<RisingStar[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/rising-stars${qs}`)
      .then(r => r.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  return (
    <Card className="card-hover mb-4">
      <CardHeader className="pb-2">
        <div className="flex justify-between items-center">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-green-500" />
            Rising Stars
          </CardTitle>
          <span className="text-xs text-muted-foreground">Top finishes (last 30 days)</span>
        </div>
      </CardHeader>
      <CardContent>
        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            {[1, 2, 3, 4].map(i => (
              <Skeleton key={i} className="h-20 rounded-lg" />
            ))}
          </div>
        ) : data.length === 0 ? (
          <p className="text-center text-muted-foreground py-4">No recent top placements</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            {data.map((player, index) => (
              <div
                key={player.player_id}
                className="rising-star-card flex items-center gap-3 rounded-lg border p-3 bg-card"
              >
                <div className="flex-shrink-0 w-7 h-7 rounded-full bg-muted flex items-center justify-center text-xs font-bold text-muted-foreground">
                  {index + 1}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-medium text-sm truncate">{player.display_name}</div>
                  <div className="flex gap-2 mt-0.5">
                    {player.recent_wins > 0 && (
                      <span className="inline-flex items-center gap-0.5 text-xs px-1.5 py-0.5 rounded-full bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300">
                        <Trophy className="w-3 h-3" /> {player.recent_wins}
                      </span>
                    )}
                    {player.recent_top3 - player.recent_wins > 0 && (
                      <span className="inline-flex items-center gap-0.5 text-xs px-1.5 py-0.5 rounded-full bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300">
                        <Medal className="w-3 h-3" /> {player.recent_top3 - player.recent_wins}
                      </span>
                    )}
                  </div>
                </div>
                <div className="text-right flex-shrink-0">
                  <div className="text-sm font-bold">{player.competitive_rating}</div>
                  <div className="text-[10px] text-muted-foreground">Rating</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  )
}
