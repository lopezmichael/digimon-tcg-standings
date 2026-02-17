'use client'

import { useDashboardFilters } from '@/hooks/use-dashboard-filters'
import { TitleStrip } from '@/components/dashboard/title-strip'
import { StatBoxes } from '@/components/dashboard/stat-boxes'
import { TopDecks } from '@/components/dashboard/top-decks'
import { Charts } from '@/components/dashboard/charts'
import { RecentTournaments } from '@/components/dashboard/recent-tournaments'
import { TopPlayers } from '@/components/dashboard/top-players'
import { MetaTimeline } from '@/components/dashboard/meta-timeline'

export default function Dashboard() {
  const { filters, setFormat, setEventType, resetFilters, queryString } = useDashboardFilters()

  return (
    <main className="max-w-7xl mx-auto px-4 py-4">
      <TitleStrip
        filters={filters}
        onFormatChange={setFormat}
        onEventTypeChange={setEventType}
        onReset={resetFilters}
      />

      {/* Value Boxes - 4 column grid */}
      <StatBoxes queryString={queryString} />

      {/* Top Decks Card */}
      <TopDecks queryString={queryString} />

      {/* Charts - 3 column grid */}
      <Charts queryString={queryString} />

      {/* Tables - 2 column grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        <RecentTournaments queryString={queryString} />
        <TopPlayers queryString={queryString} />
      </div>

      {/* Meta Timeline - full width */}
      <MetaTimeline queryString={queryString} />
    </main>
  )
}
