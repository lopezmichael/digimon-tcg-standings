'use client'

import { useEffect, useState } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import type { PlayerGrowthMonth } from '@/lib/types'

interface PlayerGrowthProps {
  queryString: string
}

export function PlayerGrowthChart({ queryString }: PlayerGrowthProps) {
  const [data, setData] = useState<PlayerGrowthMonth[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/player-growth${qs}`)
      .then(r => r.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  if (loading) return <Skeleton className="h-[280px] rounded-lg" />

  return (
    <Card className="h-full">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium flex items-center gap-2">
          <span className="text-green-500">&#x1F465;</span>
          Player Growth & Retention
        </CardTitle>
      </CardHeader>
      <CardContent>
        {data.length === 0 ? (
          <p className="text-center text-muted-foreground py-8">No player data yet</p>
        ) : (
          <ResponsiveContainer width="100%" height={220}>
            <BarChart
              data={data.map(d => ({
                ...d,
                label: formatMonth(d.month),
              }))}
              margin={{ top: 5, right: 10, left: 0, bottom: 5 }}
            >
              <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
              <XAxis dataKey="label" fontSize={11} />
              <YAxis fontSize={12} />
              <Tooltip />
              <Legend />
              <Bar dataKey="new_players" name="New" stackId="a" fill="#38A169" />
              <Bar dataKey="returning_players" name="Returning" stackId="a" fill="#2D7DD2" />
              <Bar dataKey="regulars" name="Regulars" stackId="a" fill="#805AD5" />
            </BarChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  )
}

function formatMonth(monthStr: string): string {
  // monthStr is "YYYY-MM"
  const [year, month] = monthStr.split('-')
  const date = new Date(Number(year), Number(month) - 1)
  return date.toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
}
