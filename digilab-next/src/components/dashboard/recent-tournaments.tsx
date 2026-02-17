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
import type { RecentTournament } from '@/lib/types'

interface RecentTournamentsProps {
  queryString: string
}

const columnHelper = createColumnHelper<RecentTournament>()

export function RecentTournaments({ queryString }: RecentTournamentsProps) {
  const [data, setData] = useState<RecentTournament[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    const qs = queryString ? `?${queryString}` : ''
    fetch(`/api/dashboard/recent-tournaments${qs}`)
      .then(r => r.json())
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [queryString])

  const columns = useMemo(() => [
    columnHelper.accessor('Store', {
      header: 'Store',
      cell: info => (
        <span className="truncate max-w-[150px] block">{info.getValue()}</span>
      ),
    }),
    columnHelper.accessor('Date', {
      header: 'Date',
      cell: info => info.getValue(),
    }),
    columnHelper.accessor('Players', {
      header: 'Players',
      cell: info => <span className="text-center block">{info.getValue()}</span>,
    }),
    columnHelper.accessor('Winner', {
      header: 'Winner',
      cell: info => info.getValue(),
    }),
    columnHelper.accessor('store_rating', {
      header: 'Rating',
      cell: info => (
        <span className="text-center block">
          {info.getValue() > 0 ? info.getValue() : '-'}
        </span>
      ),
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
        <CardHeader><CardTitle>Recent Tournaments</CardTitle></CardHeader>
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
        <CardTitle>Recent Tournaments</CardTitle>
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
                  No tournaments found.
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
