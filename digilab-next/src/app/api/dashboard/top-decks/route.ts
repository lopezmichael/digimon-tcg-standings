import { NextRequest, NextResponse } from 'next/server'
import { getTopDecks } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getTopDecks({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Top decks error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch top decks' },
      { status: 500 }
    )
  }
}
