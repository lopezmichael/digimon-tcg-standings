'use client'

import { useState } from 'react'
import {
  BarChart3,
  Users,
  Layers,
  Trophy,
  MapPin,
  Menu,
  X,
} from 'lucide-react'

const NAV_ITEMS = [
  { id: 'overview', label: 'Overview', icon: BarChart3 },
  { id: 'players', label: 'Players', icon: Users },
  { id: 'meta', label: 'Meta Analysis', icon: Layers },
  { id: 'tournaments', label: 'Tournaments', icon: Trophy },
  { id: 'stores', label: 'Stores', icon: MapPin },
]

interface SidebarProps {
  activeTab: string
  onTabChange: (tab: string) => void
}

export function Sidebar({ activeTab, onTabChange }: SidebarProps) {
  const [mobileOpen, setMobileOpen] = useState(false)

  return (
    <>
      {/* Mobile toggle button */}
      <button
        onClick={() => setMobileOpen(true)}
        className="fixed bottom-4 left-4 z-50 lg:hidden p-3 rounded-full bg-gradient-to-br from-[#0A3055] to-[#0F4C81] text-white shadow-lg hover:shadow-xl transition-all duration-200"
        aria-label="Open navigation"
      >
        <Menu className="w-5 h-5" />
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`
          fixed top-0 left-0 z-50 h-full w-56
          bg-gradient-to-b from-[#0A3055] to-[#071E38]
          transition-transform duration-300 ease-in-out
          lg:translate-x-0 lg:z-30
          ${mobileOpen ? 'translate-x-0' : '-translate-x-full'}
        `}
      >
        {/* Grid overlay */}
        <div
          className="absolute inset-0 pointer-events-none opacity-[0.03]"
          style={{
            backgroundImage:
              'repeating-linear-gradient(0deg, transparent, transparent 19px, rgba(255,255,255,0.5) 19px, rgba(255,255,255,0.5) 20px), repeating-linear-gradient(90deg, transparent, transparent 19px, rgba(255,255,255,0.5) 19px, rgba(255,255,255,0.5) 20px)',
          }}
        />

        {/* Close button (mobile) */}
        <div className="relative z-10 flex items-center justify-between px-4 py-3 lg:hidden">
          <span className="text-white font-bold text-lg">
            <span className="text-[#F7941D]">Digi</span>Lab
          </span>
          <button
            onClick={() => setMobileOpen(false)}
            className="p-1.5 rounded-md hover:bg-white/10 text-white/70 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Spacer for desktop to align below header */}
        <div className="hidden lg:block h-[52px]" />

        {/* Nav items */}
        <nav className="relative z-10 px-3 py-2 space-y-1">
          {NAV_ITEMS.map(item => {
            const isActive = activeTab === item.id
            const Icon = item.icon
            return (
              <button
                key={item.id}
                onClick={() => {
                  onTabChange(item.id)
                  setMobileOpen(false)
                }}
                className={`
                  relative w-full flex items-center gap-3 px-3 py-2.5 rounded-lg
                  text-sm font-medium transition-all duration-200
                  ${isActive
                    ? 'bg-[#F7941D] text-white shadow-md'
                    : 'text-white/70 hover:text-white hover:bg-white/10'
                  }
                `}
              >
                {/* Cyan glow node for active item */}
                {isActive && (
                  <span className="absolute left-0 top-1/2 -translate-y-1/2 -translate-x-1/2 w-2 h-2 rounded-full bg-[#00C8FF] shadow-[0_0_8px_rgba(0,200,255,0.8)]" />
                )}
                <Icon className="w-4 h-4 shrink-0" />
                {item.label}
              </button>
            )
          })}
        </nav>

        {/* Bottom branding (desktop) */}
        <div className="hidden lg:flex absolute bottom-4 left-0 right-0 px-4">
          <div className="text-[10px] text-white/30 text-center w-full">
            Dallas-Fort Worth TCG
          </div>
        </div>
      </aside>
    </>
  )
}
