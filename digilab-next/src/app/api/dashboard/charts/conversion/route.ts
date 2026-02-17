import { NextRequest, NextResponse } from 'next/server'
import { getConversionData } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getConversionData({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Conversion data error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch conversion data' },
      { status: 500 }
    )
  }
}
