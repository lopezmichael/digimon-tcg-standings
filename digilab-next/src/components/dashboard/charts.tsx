'use client'

import { useEffect, useState } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  LineChart, Line, Legend, Cell,
} from 'recharts'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { ArrowRightLeft, PieChart as PieChartIcon, TrendingUp } from 'lucide-react'
import { DECK_COLORS } from '@/lib/types'
import type { ConversionData, ColorDistData, TrendData } from '@/lib/types'

interface ChartsProps {
  queryString: string
}

// ---- Conversion Chart ----

function ConversionChart({ queryString }: { queryString: string }) {
  const [data, setData] = useState<ConversionData[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/charts/conversion${qs}`)
      .then(r => r.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  if (loading) return <Skeleton className="h-64 rounded-lg" />
  if (data.length === 0) return <p className="text-center text-muted-foreground py-8">No data</p>

  return (
    <ResponsiveContainer width="100%" height={250}>
      <BarChart data={data} layout="vertical" margin={{ top: 5, right: 30, left: 80, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
        <XAxis type="number" domain={[0, 100]} tickFormatter={(v: number) => `${v}%`} fontSize={12} />
        <YAxis type="category" dataKey="name" fontSize={11} width={75} />
        <Tooltip
          formatter={(value) => [`${value}%`, 'Conversion']}
          labelFormatter={(label) => String(label)}
        />
        <Bar dataKey="conversion" radius={[0, 4, 4, 0]}>
          {data.map((entry, index) => (
            <Cell key={index} fill={DECK_COLORS[entry.color] ?? '#6B7280'} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  )
}

// ---- Color Distribution Chart ----

function ColorDistChart({ queryString }: { queryString: string }) {
  const [data, setData] = useState<ColorDistData[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/charts/color-dist${qs}`)
      .then(r => r.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  if (loading) return <Skeleton className="h-64 rounded-lg" />
  if (data.length === 0) return <p className="text-center text-muted-foreground py-8">No data</p>

  return (
    <ResponsiveContainer width="100%" height={250}>
      <BarChart data={data} layout="vertical" margin={{ top: 5, right: 30, left: 60, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
        <XAxis type="number" fontSize={12} />
        <YAxis type="category" dataKey="color" fontSize={12} width={55} />
        <Tooltip />
        <Bar dataKey="count" radius={[0, 4, 4, 0]}>
          {data.map((entry, index) => (
            <Cell key={index} fill={DECK_COLORS[entry.color] ?? '#6B7280'} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  )
}

// ---- Trend Chart ----

function TrendChart({ queryString }: { queryString: string }) {
  const [data, setData] = useState<TrendData[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/charts/trend${qs}`)
      .then(r => r.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  if (loading) return <Skeleton className="h-64 rounded-lg" />
  if (data.length === 0) return <p className="text-center text-muted-foreground py-8">No data</p>

  // Format dates for display
  const chartData = data.map(d => ({
    ...d,
    label: new Date(d.event_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
  }))

  return (
    <ResponsiveContainer width="100%" height={250}>
      <LineChart data={chartData} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
        <CartesianGrid strokeDasharray="3 3" opacity={0.3} />
        <XAxis dataKey="label" fontSize={11} />
        <YAxis fontSize={12} />
        <Tooltip />
        <Legend />
        <Line
          type="monotone"
          dataKey="avg_players"
          stroke="#0F4C81"
          name="Daily Avg"
          dot={{ r: 3 }}
          strokeWidth={2}
        />
        <Line
          type="monotone"
          dataKey="rolling_avg"
          stroke="#F7941D"
          name="7-Day Rolling Avg"
          strokeDasharray="5 5"
          dot={false}
          strokeWidth={2}
        />
      </LineChart>
    </ResponsiveContainer>
  )
}

// ---- Charts Container ----

export function Charts({ queryString }: ChartsProps) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
      <Card className="card-hover">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <ArrowRightLeft className="w-4 h-4 text-muted-foreground" />
            Top 3 Conversion Rate
          </CardTitle>
        </CardHeader>
        <CardContent>
          <ConversionChart queryString={queryString} />
        </CardContent>
      </Card>
      <Card className="card-hover">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <PieChartIcon className="w-4 h-4 text-muted-foreground" />
            Color Distribution
          </CardTitle>
        </CardHeader>
        <CardContent>
          <ColorDistChart queryString={queryString} />
        </CardContent>
      </Card>
      <Card className="card-hover">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-muted-foreground" />
            Player Counts Over Time
          </CardTitle>
        </CardHeader>
        <CardContent>
          <TrendChart queryString={queryString} />
        </CardContent>
      </Card>
    </div>
  )
}
