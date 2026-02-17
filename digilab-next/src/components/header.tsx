'use client'

import { useTheme } from 'next-themes'
import { useEffect, useState } from 'react'

export function Header() {
  const { theme, setTheme } = useTheme()
  const [mounted, setMounted] = useState(false)

  useEffect(() => setMounted(true), [])

  return (
    <header className="bg-gradient-to-r from-[#0A3055] to-[#0F4C81] text-white px-4 py-3 flex items-center justify-between">
      <div className="flex items-center gap-3">
        <h1 className="text-xl font-bold tracking-wide">
          <span className="text-[#F7941D]">Digi</span>Lab
        </h1>
        <span className="text-xs opacity-60 hidden sm:inline">Digimon TCG Tournament Tracker</span>
      </div>
      <div className="flex items-center gap-2">
        {mounted && (
          <button
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            className="p-2 rounded-md hover:bg-white/10 transition-colors text-sm"
            aria-label="Toggle dark mode"
          >
            {theme === 'dark' ? '\u2600\uFE0F' : '\uD83C\uDF19'}
          </button>
        )}
      </div>
    </header>
  )
}
