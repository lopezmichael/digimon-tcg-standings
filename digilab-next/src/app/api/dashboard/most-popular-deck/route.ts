import { NextRequest, NextResponse } from 'next/server'
import { getMostPopularDeck } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getMostPopularDeck({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Most popular deck error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch most popular deck' },
      { status: 500 }
    )
  }
}
