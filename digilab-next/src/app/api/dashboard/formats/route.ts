import { NextResponse } from 'next/server'
import { getFormats } from '@/lib/queries/dashboard'

export async function GET() {
  try {
    const data = await getFormats()
    return NextResponse.json(data)
  } catch (error) {
    console.error('Formats error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch formats' },
      { status: 500 }
    )
  }
}
