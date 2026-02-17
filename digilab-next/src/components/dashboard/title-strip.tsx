'use client'

import { useEffect, useState } from 'react'
import { LayoutGrid, RotateCcw } from 'lucide-react'
import type { DashboardFilters } from '@/hooks/use-dashboard-filters'

interface TitleStripProps {
  filters: DashboardFilters
  onFormatChange: (format: string) => void
  onEventTypeChange: (eventType: string) => void
  onReset: () => void
}

const EVENT_TYPES = [
  { value: '', label: 'All Events' },
  { value: 'locals', label: 'Locals' },
  { value: 'regional', label: 'Regional' },
  { value: 'major', label: 'Major' },
  { value: 'online', label: 'Online' },
]

export function TitleStrip({ filters, onFormatChange, onEventTypeChange, onReset }: TitleStripProps) {
  const [formats, setFormats] = useState<{ format_id: string; display_name: string }[]>([])

  useEffect(() => {
    fetch('/api/dashboard/formats')
      .then(r => r.json())
      .then(setFormats)
      .catch(console.error)
  }, [])

  const formatDisplay = filters.format
    ? formats.find(f => f.format_id === filters.format)?.display_name ?? filters.format
    : 'All Formats'

  const eventDisplay = EVENT_TYPES.find(e => e.value === filters.eventType)?.label ?? 'All Events'

  return (
    <div className="title-strip mb-2">
      <div className="flex justify-between items-center gap-4">
        <div className="flex items-center gap-2 text-white">
          <LayoutGrid className="w-5 h-5 opacity-80" />
          <span className="font-semibold whitespace-nowrap">
            {formatDisplay} <span className="opacity-60">&middot;</span> {eventDisplay}
          </span>
        </div>
        <div className="flex items-center gap-2 shrink">
          <select
            value={filters.format}
            onChange={e => onFormatChange(e.target.value)}
            className="title-strip-select"
          >
            <option value="">All Formats</option>
            {formats.map(f => (
              <option key={f.format_id} value={f.format_id}>{f.display_name}</option>
            ))}
          </select>
          <select
            value={filters.eventType}
            onChange={e => onEventTypeChange(e.target.value)}
            className="title-strip-select"
          >
            {EVENT_TYPES.map(e => (
              <option key={e.value} value={e.value}>{e.label}</option>
            ))}
          </select>
          <button
            onClick={onReset}
            className="p-1.5 rounded hover:bg-white/10 text-white/70 hover:text-white transition-all duration-200"
            title="Reset filters"
          >
            <RotateCcw className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  )
}
