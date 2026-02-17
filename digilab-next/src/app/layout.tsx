import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { ThemeProvider } from '@/components/theme-provider'
import { Header } from '@/components/header'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'DigiLab - Digimon TCG Tournament Tracker',
  description: 'Track player performance, store activity, and deck meta for the Digimon TCG community.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider>
          <Header />
          <div className="lg:pl-56">
            {children}
          </div>
        </ThemeProvider>
      </body>
    </html>
  )
}
