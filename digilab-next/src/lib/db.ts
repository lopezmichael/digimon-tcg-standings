import duckdb from 'duckdb'
import path from 'path'

// Singleton database connection
let db: InstanceType<typeof duckdb.Database> | null = null

function getDbPath(): string {
  // Local dev: use the same DuckDB file as the Shiny app
  // The file is at repo_root/data/local.duckdb
  // digilab-next/ is one level deep from repo root
  return path.resolve(process.cwd(), '..', 'data', 'local.duckdb')
}

function getDatabase(): InstanceType<typeof duckdb.Database> {
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
function convertBigInts(rows: duckdb.TableData): duckdb.TableData {
  return rows.map(row => {
    const converted: duckdb.RowData = {}
    for (const [key, value] of Object.entries(row)) {
      converted[key] = typeof value === 'bigint' ? Number(value) : value
    }
    return converted
  })
}

export function query<T = Record<string, unknown>>(sql: string): Promise<T[]> {
  return new Promise((resolve, reject) => {
    const database = getDatabase()
    database.all(sql, (err: duckdb.DuckDbError | null, rows: duckdb.TableData) => {
      if (err) reject(err)
      else resolve(convertBigInts(rows ?? []) as T[])
    })
  })
}
