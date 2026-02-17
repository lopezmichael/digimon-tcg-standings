import { NextRequest, NextResponse } from 'next/server'
import { getHotDeck } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getHotDeck({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Hot deck error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch hot deck' },
      { status: 500 }
    )
  }
}
