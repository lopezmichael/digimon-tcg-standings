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
    "scenes",
    "stores",
    "store_schedules",
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


def get_table_columns(conn, db_name, table_name):
    """Get column names for a table"""
    try:
        result = conn.execute(f"SELECT * FROM {db_name}.{table_name} LIMIT 0")
        return [desc[0] for desc in result.description]
    except Exception:
        return []


def sync_schema_columns(conn, local_db, cloud_db, table):
    """Add missing columns from local to cloud table"""
    local_cols = get_table_columns(conn, local_db, table)
    cloud_cols = get_table_columns(conn, cloud_db, table)

    if not local_cols or not cloud_cols:
        return

    # Find columns in local but not in cloud
    missing_cols = set(local_cols) - set(cloud_cols)

    for col in missing_cols:
        # Get column type from local table
        try:
            col_info = conn.execute(f"DESCRIBE {local_db}.{table}").fetchall()
            col_type = None
            for row in col_info:
                if row[0] == col:
                    col_type = row[1]
                    break

            if col_type:
                conn.execute(f"ALTER TABLE {cloud_db}.{table} ADD COLUMN {col} {col_type}")
                print(f"    Added column {col} to {table}")
        except Exception as e:
            print(f"    Warning: Could not add column {col} to {table}: {str(e)[:60]}")

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

    # Sync schema columns (add missing columns to cloud)
    print(f"\n[4/5] Syncing schema columns...")
    for table in TABLES:
        try:
            sync_schema_columns(conn, "local_db", MOTHERDUCK_DB, table)
        except Exception as e:
            print(f"    {table}: schema sync error - {str(e)[:60]}")

    # Sync data for each table using direct SQL
    print(f"\n[5/5] Syncing table data...")
    total_rows = 0

    # First, delete all data in REVERSE order (children before parents) to respect FK constraints
    print("    Clearing cloud tables (reverse FK order)...")
    for table in reversed(TABLES):
        try:
            conn.execute(f"DELETE FROM {MOTHERDUCK_DB}.{table}")
        except Exception as e:
            err_str = str(e).lower()
            # Table might not exist yet, that's OK
            if "does not exist" not in err_str and "not found" not in err_str:
                print(f"    Warning: Could not clear {table}: {str(e)[:60]}")

    # Then insert data in FORWARD order (parents before children)
    for table in TABLES:
        try:
            # Check if table has data locally
            count = conn.execute(f"SELECT COUNT(*) FROM local_db.{table}").fetchone()[0]

            if count == 0:
                print(f"    {table}: skipped (empty)")
                continue

            # Get local columns to ensure we only copy what exists
            local_cols = get_table_columns(conn, "local_db", table)
            if not local_cols:
                print(f"    {table}: ERROR - could not get columns")
                continue

            cols_str = ", ".join(local_cols)

            # Copy data using explicit column list
            conn.execute(f"INSERT INTO {MOTHERDUCK_DB}.{table} ({cols_str}) SELECT {cols_str} FROM local_db.{table}")

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
