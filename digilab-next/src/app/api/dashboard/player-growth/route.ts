import { NextRequest, NextResponse } from 'next/server'
import { getPlayerGrowth } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getPlayerGrowth({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Player growth error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch player growth' },
      { status: 500 }
    )
  }
}
