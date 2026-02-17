import { NextRequest, NextResponse } from 'next/server'
import { getRecentTournaments } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getRecentTournaments({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Recent tournaments error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch recent tournaments' },
      { status: 500 }
    )
  }
}
