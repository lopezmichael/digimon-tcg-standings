import { NextRequest, NextResponse } from 'next/server'
import { getColorDistribution } from '@/lib/queries/dashboard'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const format = searchParams.get('format') ?? undefined
  const eventType = searchParams.get('eventType') ?? undefined

  try {
    const data = await getColorDistribution({ format, eventType })
    return NextResponse.json(data)
  } catch (error) {
    console.error('Color distribution error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch color distribution' },
      { status: 500 }
    )
  }
}
