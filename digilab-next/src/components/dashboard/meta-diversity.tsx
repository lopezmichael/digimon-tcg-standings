'use client'

import { useEffect, useState } from 'react'
import { PieChart, Pie, Cell, ResponsiveContainer } from 'recharts'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { Palette } from 'lucide-react'
import type { MetaDiversity as MetaDiversityType } from '@/lib/types'

interface MetaDiversityProps {
  queryString: string
}

function getScoreStyle(score: number) {
  if (score < 40) return { color: '#E5383B', label: 'Low Diversity', desc: 'A few decks dominate the meta' }
  if (score < 70) return { color: '#F5B700', label: 'Moderate Diversity', desc: 'Several viable decks in the meta' }
  return { color: '#38A169', label: 'High Diversity', desc: 'Many competitive decks in the meta' }
}

export function MetaDiversityGauge({ queryString }: MetaDiversityProps) {
  const [data, setData] = useState<MetaDiversityType | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/meta-diversity${qs}`)
      .then(r => r.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  if (loading) return <Skeleton className="h-[280px] rounded-lg" />

  if (!data || data.score === null) {
    return (
      <Card className="card-hover h-full">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <Palette className="w-4 h-4 text-blue-400" />
            Meta Diversity
          </CardTitle>
        </CardHeader>
        <CardContent className="flex items-center justify-center h-48">
          <p className="text-muted-foreground text-sm">No data available</p>
        </CardContent>
      </Card>
    )
  }

  const { color, label, desc } = getScoreStyle(data.score)
  const chartData = [
    { name: 'Score', value: data.score },
    { name: 'Remaining', value: 100 - data.score },
  ]

  return (
    <Card className="card-hover h-full">
      <CardHeader className="pb-2">
        <div className="flex justify-between items-center">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <Palette className="w-4 h-4 text-blue-400" />
            Meta Diversity
          </CardTitle>
          <span className="text-xs text-muted-foreground">
            {data.decks_with_wins} decks with wins
          </span>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col items-center">
        <div className="relative w-full" style={{ height: 180 }}>
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={chartData}
                cx="50%"
                cy="50%"
                innerRadius={55}
                outerRadius={75}
                startAngle={90}
                endAngle={-270}
                dataKey="value"
                strokeWidth={0}
              >
                <Cell fill={color} />
                <Cell fill="var(--color-muted)" />
              </Pie>
            </PieChart>
          </ResponsiveContainer>
          {/* Center text overlay */}
          <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
            <span className="text-3xl font-bold" style={{ color }}>
              {data.score}
            </span>
            <span className="text-xs text-muted-foreground">/ 100</span>
          </div>
        </div>
        <div className="text-center mt-1">
          <div className="text-xs font-medium" style={{ color }}>{label}</div>
          <div className="text-[10px] text-muted-foreground mt-0.5">{desc}</div>
        </div>
      </CardContent>
    </Card>
  )
}
