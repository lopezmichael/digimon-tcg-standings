import { NextRequest, NextResponse } from 'next/server'
import { getDashboardStats } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getDashboardStats({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Dashboard stats error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch dashboard stats' },
      { status: 500 }
    )
  }
}
