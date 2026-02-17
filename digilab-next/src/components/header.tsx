'use client'

import { useTheme } from 'next-themes'
import { useEffect, useState } from 'react'
import { Sun, Moon, Github, Coffee } from 'lucide-react'

export function Header() {
  const { theme, setTheme } = useTheme()
  const [mounted, setMounted] = useState(false)

  useEffect(() => setMounted(true), [])

  return (
    <header className="sticky top-0 z-40 bg-gradient-to-r from-[#0A3055] to-[#0F4C81] text-white px-4 py-3 flex items-center justify-between">
      <div className="flex items-center gap-3">
        {/* Animated header icon */}
        <div className="header-icon-glow">
          <svg className="w-6 h-6 text-[#00C8FF]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="2" y="3" width="20" height="14" rx="2" ry="2"/>
            <line x1="8" y1="21" x2="16" y2="21"/>
            <line x1="12" y1="17" x2="12" y2="21"/>
          </svg>
        </div>
        <h1 className="text-xl font-bold tracking-wide">
          <span className="text-[#F7941D]">Digi</span>Lab
        </h1>
        <span className="text-xs opacity-60 hidden sm:inline">Digimon TCG Tournament Tracker</span>
      </div>
      <div className="flex items-center gap-1">
        <a
          href="https://github.com/yourusername/digimon-tcg-standings"
          target="_blank"
          rel="noopener noreferrer"
          className="header-action-btn"
          aria-label="GitHub"
        >
          <Github className="w-4 h-4" />
        </a>
        <a
          href="https://ko-fi.com"
          target="_blank"
          rel="noopener noreferrer"
          className="header-action-btn header-coffee-btn"
          aria-label="Support on Ko-fi"
        >
          <Coffee className="w-4 h-4" />
        </a>
        {mounted && (
          <button
            onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
            className="header-action-btn"
            aria-label="Toggle dark mode"
          >
            {theme === 'dark' ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
          </button>
        )}
      </div>
    </header>
  )
}
