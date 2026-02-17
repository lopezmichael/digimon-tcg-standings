'use client'

import { useEffect, useState } from 'react'
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'

interface MetaTimelineProps {
  queryString: string
}

interface TimelineData {
  weeks: string[]
  series: { name: string; color: string; data: number[] }[]
}

export function MetaTimeline({ queryString }: MetaTimelineProps) {
  const [timeline, setTimeline] = useState<TimelineData | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/charts/meta-timeline${qs}`)
      .then(r => r.json())
      .then(setTimeline)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  if (loading) {
    return (
      <Card className="mb-4">
        <CardHeader><CardTitle>Meta Share Over Time</CardTitle></CardHeader>
        <CardContent><Skeleton className="h-80 rounded-lg" /></CardContent>
      </Card>
    )
  }

  if (!timeline || timeline.weeks.length === 0 || timeline.series.length === 0) {
    return (
      <Card className="mb-4">
        <CardHeader><CardTitle>Meta Share Over Time</CardTitle></CardHeader>
        <CardContent>
          <p className="text-center text-muted-foreground py-8">No meta timeline data available.</p>
        </CardContent>
      </Card>
    )
  }

  // Transform API data into Recharts format
  // Recharts needs: [{ week: 'Jan 15', DeckA: 30, DeckB: 20, ... }, ...]
  const chartData = timeline.weeks.map((week, i) => {
    const point: Record<string, string | number> = { week }
    for (const series of timeline.series) {
      point[series.name] = series.data[i] ?? 0
    }
    return point
  })

  return (
    <Card className="mb-4">
      <CardHeader>
        <CardTitle>Meta Share Over Time</CardTitle>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={400}>
          <AreaChart data={chartData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
            <XAxis dataKey="week" fontSize={11} />
            <YAxis
              domain={[0, 100]}
              tickFormatter={(v: number) => `${v}%`}
              fontSize={12}
            />
            <Tooltip
              formatter={(value, name) => [`${value}%`, name]}
              itemSorter={(item) => -(Number(item.value) || 0)}
            />
            <Legend
              wrapperStyle={{ fontSize: '11px', maxHeight: '100px', overflowY: 'auto' }}
            />
            {timeline.series.map(s => (
              <Area
                key={s.name}
                type="monotone"
                dataKey={s.name}
                stackId="1"
                stroke={s.color}
                fill={s.color}
                fillOpacity={0.6}
              />
            ))}
          </AreaChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  )
}
