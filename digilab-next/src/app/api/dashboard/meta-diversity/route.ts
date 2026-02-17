import { NextRequest, NextResponse } from 'next/server'
import { getMetaDiversity } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getMetaDiversity({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Meta diversity error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch meta diversity' },
      { status: 500 }
    )
  }
}
