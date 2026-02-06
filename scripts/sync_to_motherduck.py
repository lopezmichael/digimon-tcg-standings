"""
Sync local DuckDB to MotherDuck

Run this script when you're ready to deploy and want to push
your local data to MotherDuck cloud.

Usage:
    pip install duckdb python-dotenv
    python scripts/sync_to_motherduck.py

Prerequisites:
    - MOTHERDUCK_TOKEN in .env file
    - Local database at data/local.duckdb with data
"""

import os
import duckdb
from pathlib import Path
from dotenv import load_dotenv

# Load environment
load_dotenv()

LOCAL_DB = "data/local.duckdb"
SCHEMA_FILE = "db/schema.sql"
MOTHERDUCK_DB = os.getenv("MOTHERDUCK_DATABASE", "digimon_tcg_dfw")
MOTHERDUCK_TOKEN = os.getenv("MOTHERDUCK_TOKEN")

# Tables in order (respects foreign key dependencies)
TABLES = [
    "stores",
    "formats",
    "cards",
    "players",
    "deck_archetypes",
    "deck_requests",
    "archetype_cards",
    "tournaments",
    "results",
    "matches",
    "ingestion_log"
]

def read_schema():
    """Read and parse schema.sql file"""
    if not Path(SCHEMA_FILE).exists():
        print(f"Warning: Schema file not found at {SCHEMA_FILE}")
        return None

    with open(SCHEMA_FILE, 'r') as f:
        content = f.read()

    # Remove comment lines
    lines = [line for line in content.split('\n') if not line.strip().startswith('--')]
    return '\n'.join(lines)

def execute_statements(conn, sql):
    """Execute multiple SQL statements separated by semicolons"""
    statements = sql.split(';')
    for stmt in statements:
        stmt = stmt.strip()
        if stmt and len(stmt) > 5:
            try:
                conn.execute(stmt)
            except Exception as e:
                # Ignore "already exists" errors
                if "already exists" not in str(e).lower():
                    print(f"    Warning: {str(e)[:80]}")

def main():
    if not MOTHERDUCK_TOKEN:
        print("Error: MOTHERDUCK_TOKEN not set in .env")
        return

    if not Path(LOCAL_DB).exists():
        print(f"Error: Local database not found at {LOCAL_DB}")
        return

    print("=" * 60)
    print("Syncing local DuckDB -> MotherDuck")
    print("=" * 60)

    # Connect to MotherDuck first
    print(f"\n[1/4] Connecting to MotherDuck...")
    md_conn = f"md:?motherduck_token={MOTHERDUCK_TOKEN}"
    conn = duckdb.connect(md_conn)

    # Create database if it doesn't exist
    try:
        conn.execute(f"CREATE DATABASE IF NOT EXISTS {MOTHERDUCK_DB}")
        print(f"    Database '{MOTHERDUCK_DB}' created/verified")
    except Exception as e:
        print(f"    Note: {e}")

    # Use the database
    conn.execute(f"USE {MOTHERDUCK_DB}")

    # Attach local database
    print(f"\n[2/4] Attaching local database: {LOCAL_DB}")
    local_path = str(Path(LOCAL_DB).absolute())
    conn.execute(f"ATTACH '{local_path}' AS local_db (READ_ONLY)")
    print(f"    Local database attached")

    # Initialize schema in MotherDuck
    print(f"\n[3/4] Initializing schema in MotherDuck...")
    schema_sql = read_schema()
    if schema_sql:
        execute_statements(conn, schema_sql)
        print("    Schema initialized (tables, indexes, views created)")
    else:
        print("    Warning: Skipping schema initialization")

    # Sync data for each table using direct SQL
    print(f"\n[4/4] Syncing table data...")
    total_rows = 0

    for table in TABLES:
        try:
            # Check if table has data locally
            count = conn.execute(f"SELECT COUNT(*) FROM local_db.{table}").fetchone()[0]

            if count == 0:
                print(f"    {table}: skipped (empty)")
                continue

            # Delete existing data in cloud table
            conn.execute(f"DELETE FROM {MOTHERDUCK_DB}.{table}")

            # Copy data directly using SQL
            conn.execute(f"INSERT INTO {MOTHERDUCK_DB}.{table} SELECT * FROM local_db.{table}")

            print(f"    {table}: synced {count} rows")
            total_rows += count

        except Exception as e:
            print(f"    {table}: ERROR - {e}")

    # Detach local database
    conn.execute("DETACH local_db")

    # Close connection
    conn.close()

    print("\n" + "=" * 60)
    print(f"Sync complete! {total_rows} total rows synced.")
    print(f"Your data is now in MotherDuck: {MOTHERDUCK_DB}")
    print("=" * 60)
    print("\nNext steps:")
    print("  1. Verify at https://app.motherduck.com")
    print("  2. Set MOTHERDUCK_TOKEN in Posit Connect")
    print("  3. Deploy with rsconnect::deployApp()")

if __name__ == "__main__":
    main()
