import { NextRequest, NextResponse } from 'next/server'
import { getRisingStars } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getRisingStars({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Rising stars error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch rising stars' },
      { status: 500 }
    )
  }
}
