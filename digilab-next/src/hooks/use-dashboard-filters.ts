'use client'

import { useState, useCallback } from 'react'

export interface DashboardFilters {
  format: string
  eventType: string
}

export function useDashboardFilters() {
  const [filters, setFilters] = useState<DashboardFilters>({
    format: '',
    eventType: 'locals',
  })

  const setFormat = useCallback((format: string) => {
    setFilters(prev => ({ ...prev, format }))
  }, [])

  const setEventType = useCallback((eventType: string) => {
    setFilters(prev => ({ ...prev, eventType }))
  }, [])

  const resetFilters = useCallback(() => {
    setFilters({ format: '', eventType: 'locals' })
  }, [])

  const queryString = new URLSearchParams(
    Object.entries(filters).filter(([, v]) => v !== '')
  ).toString()

  return { filters, setFormat, setEventType, resetFilters, queryString }
}
