import path from 'path'

// Use require() to load duckdb at runtime, avoiding Turbopack static analysis
// of the native addon's package.json (which causes build failures).
// eslint-disable-next-line @typescript-eslint/no-require-imports
const duckdb = require('duckdb')

// Singleton database connection
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let db: any = null

function getDbPath(): string {
  // Local dev: use the same DuckDB file as the Shiny app
  // The file is at repo_root/data/local.duckdb
  // digilab-next/ is one level deep from repo root
  return path.resolve(process.cwd(), '..', 'data', 'local.duckdb')
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function getDatabase(): any {
  if (!db) {
    const dbPath = getDbPath()
    db = new duckdb.Database(dbPath, { access_mode: 'READ_ONLY' })
  }
  return db
}

/**
 * Convert BigInt values to numbers in query results.
 * DuckDB returns COUNT(*), SUM(), and other aggregate results as BigInt,
 * which cannot be serialized to JSON. This converts them to regular numbers.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function convertBigInts(rows: any[]): any[] {
  return rows.map(row => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const converted: Record<string, any> = {}
    for (const [key, value] of Object.entries(row)) {
      converted[key] = typeof value === 'bigint' ? Number(value) : value
    }
    return converted
  })
}

export function query<T = Record<string, unknown>>(sql: string): Promise<T[]> {
  return new Promise((resolve, reject) => {
    const database = getDatabase()
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    database.all(sql, (err: Error | null, rows: any[]) => {
      if (err) reject(err)
      else resolve(convertBigInts(rows ?? []) as T[])
    })
  })
}
