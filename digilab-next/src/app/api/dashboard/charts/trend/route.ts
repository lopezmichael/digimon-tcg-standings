import { NextRequest, NextResponse } from 'next/server'
import { getTrendData } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getTrendData({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Trend data error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch trend data' },
      { status: 500 }
    )
  }
}
