'use client'

import { useEffect, useState, useMemo } from 'react'
import {
  useReactTable,
  getCoreRowModel,
  flexRender,
  createColumnHelper,
} from '@tanstack/react-table'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import type { TopPlayer } from '@/lib/types'

interface TopPlayersProps {
  queryString: string
}

const columnHelper = createColumnHelper<TopPlayer>()

export function TopPlayers({ queryString }: TopPlayersProps) {
  const [data, setData] = useState<TopPlayer[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/top-players${qs}`)
      .then(r => r.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  const columns = useMemo(() => [
    columnHelper.accessor('Player', {
      header: 'Player',
      cell: info => <span className="font-medium">{info.getValue()}</span>,
    }),
    columnHelper.accessor('Events', {
      header: 'Events',
      cell: info => <span className="text-center block">{info.getValue()}</span>,
    }),
    columnHelper.accessor('event_wins', {
      header: 'Wins',
      cell: info => <span className="text-center block">{info.getValue()}</span>,
    }),
    columnHelper.accessor('top3_placements', {
      header: 'Top 3',
      cell: info => <span className="text-center block">{info.getValue()}</span>,
    }),
    columnHelper.accessor('competitive_rating', {
      header: 'Rating',
      cell: info => <span className="text-center block font-semibold">{info.getValue()}</span>,
    }),
    columnHelper.accessor('achievement_score', {
      header: 'Achv',
      cell: info => <span className="text-center block">{info.getValue()}</span>,
    }),
  ], [])

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  })

  if (loading) {
    return (
      <Card>
        <CardHeader><CardTitle>Top Players</CardTitle></CardHeader>
        <CardContent>
          {[...Array(5)].map((_, i) => (
            <Skeleton key={i} className="h-8 mb-2 rounded" />
          ))}
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle>Top Players</CardTitle>
          <span
            className="text-muted-foreground cursor-help"
            title="Rating: Elo-style skill rating (1200-2000+) based on tournament placements and opponent strength. Achv: Achievement score based on placements, store diversity, and deck variety."
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
          </span>
        </div>
      </CardHeader>
      <CardContent className="px-0">
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map(headerGroup => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map(header => (
                  <TableHead key={header.id} className="text-xs">
                    {header.isPlaceholder
                      ? null
                      : flexRender(header.column.columnDef.header, header.getContext())}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows.length === 0 ? (
              <TableRow>
                <TableCell colSpan={columns.length} className="text-center text-muted-foreground py-8">
                  No player data available.
                </TableCell>
              </TableRow>
            ) : (
              table.getRowModel().rows.map(row => (
                <TableRow key={row.id} className="cursor-pointer hover:bg-muted/50">
                  {row.getVisibleCells().map(cell => (
                    <TableCell key={cell.id} className="text-sm py-2">
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  )
}
