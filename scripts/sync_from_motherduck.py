"""
Sync MotherDuck cloud to local DuckDB

Run this script to pull cloud data to your local development database.
Useful for fresh dev setup, restoring from cloud, or debugging with production data.

Usage:
    pip install duckdb python-dotenv
    python scripts/sync_from_motherduck.py
    python scripts/sync_from_motherduck.py --yes  # Skip confirmation prompt

Prerequisites:
    - MOTHERDUCK_TOKEN in .env file
    - Local database path at data/local.duckdb (will be created if missing)
"""

import os
import sys
import argparse
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
# Insert in this order (parents first), delete in reverse order (children first)
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
    "ingestion_log",
    # Cache tables (computed, but synced for consistency)
    "player_ratings_cache",
    "store_ratings_cache",
    "rating_snapshots"
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


def get_cloud_table_counts(conn):
    """Get row counts for all tables in cloud"""
    counts = {}
    for table in TABLES:
        try:
            count = conn.execute(f"SELECT COUNT(*) FROM {MOTHERDUCK_DB}.{table}").fetchone()[0]
            counts[table] = count
        except Exception:
            counts[table] = 0
    return counts


def get_table_columns(conn, db_name, table_name):
    """Get column names for a table"""
    try:
        # Use DESCRIBE which works with MotherDuck
        result = conn.execute(f"DESCRIBE {db_name}.{table_name}").fetchall()
        return [row[0] for row in result]
    except Exception as e:
        # Fallback: try SELECT with LIMIT 0 and get column names
        try:
            result = conn.execute(f"SELECT * FROM {db_name}.{table_name} LIMIT 0")
            return [desc[0] for desc in result.description]
        except Exception:
            return []


def main():
    if not MOTHERDUCK_TOKEN:
        print("Error: MOTHERDUCK_TOKEN not set in .env")
        return

    print("=" * 60)
    print("Syncing MotherDuck -> local DuckDB")
    print("=" * 60)

    # Connect to MotherDuck first to check what's there
    print(f"\n[1/5] Connecting to MotherDuck...")
    md_conn = f"md:?motherduck_token={MOTHERDUCK_TOKEN}"
    conn = duckdb.connect(md_conn)

    # Use the database
    try:
        conn.execute(f"USE {MOTHERDUCK_DB}")
        print(f"    Connected to '{MOTHERDUCK_DB}'")
    except Exception as e:
        print(f"Error: Could not access database '{MOTHERDUCK_DB}': {e}")
        conn.close()
        return

    # Show what will be synced
    print(f"\n[2/5] Checking cloud data...")
    counts = get_cloud_table_counts(conn)
    total_rows = sum(counts.values())

    for table, count in counts.items():
        status = f"{count} rows" if count > 0 else "empty"
        print(f"    {table}: {status}")

    print(f"\n    Total: {total_rows} rows to sync")

    # Confirmation prompt
    if total_rows == 0:
        print("\nWarning: Cloud database appears empty. Nothing to sync.")
        conn.close()
        return

    # Confirmation prompt (skip with --yes flag)
    print(f"\nThis will OVERWRITE your local database at: {LOCAL_DB}")

    parser = argparse.ArgumentParser()
    parser.add_argument('--yes', '-y', action='store_true', help='Skip confirmation prompt')
    args = parser.parse_args()

    if not args.yes:
        try:
            response = input("Continue? [y/N]: ").strip().lower()
            if response != 'y':
                print("Aborted.")
                conn.close()
                return
        except EOFError:
            print("\nNo interactive input available. Use --yes flag to skip confirmation.")
            conn.close()
            return

    # Ensure local data directory exists
    Path(LOCAL_DB).parent.mkdir(parents=True, exist_ok=True)

    # Attach local database (create if doesn't exist)
    print(f"\n[3/5] Attaching local database: {LOCAL_DB}")
    local_path = str(Path(LOCAL_DB).absolute())
    conn.execute(f"ATTACH '{local_path}' AS local_db")
    print(f"    Local database attached")

    # Check if tables exist in local DB, create if needed
    print(f"\n[4/5] Verifying local schema...")
    tables_exist = True
    for table in TABLES:
        try:
            conn.execute(f"SELECT 1 FROM local_db.{table} LIMIT 0")
        except Exception:
            tables_exist = False
            break

    if tables_exist:
        print("    Tables already exist in local database")
    else:
        print("    Creating tables from schema...")
        schema_sql = read_schema()
        if schema_sql:
            # Switch to local_db context for schema creation
            conn.execute("USE local_db")
            execute_statements(conn, schema_sql)
            conn.execute(f"USE {MOTHERDUCK_DB}")
            print("    Schema initialized")
        else:
            print("    Warning: Schema file not found, tables may be missing")

    # Sync data for each table
    print(f"\n[5/5] Syncing table data...")
    synced_rows = 0

    # Delete in reverse order (children first)
    print("    Clearing local tables...")
    for table in reversed(TABLES):
        try:
            conn.execute(f"DELETE FROM local_db.{table}")
        except Exception as e:
            if "does not exist" not in str(e).lower():
                print(f"    Warning clearing {table}: {str(e)[:60]}")

    # Insert in order (parents first)
    print("    Copying from cloud...")
    for table in TABLES:
        try:
            count = counts.get(table, 0)
            if count == 0:
                print(f"    {table}: skipped (empty)")
                continue

            # Get columns from cloud table (source of truth for what data exists)
            cloud_cols = get_table_columns(conn, MOTHERDUCK_DB, table)
            if not cloud_cols:
                print(f"    {table}: ERROR - could not get columns")
                continue

            # Copy data from cloud to local, only selecting columns that exist in cloud
            cols_str = ", ".join(cloud_cols)
            conn.execute(f"INSERT INTO local_db.{table} ({cols_str}) SELECT {cols_str} FROM {MOTHERDUCK_DB}.{table}")

            print(f"    {table}: synced {count} rows")
            synced_rows += count

        except Exception as e:
            print(f"    {table}: ERROR - {e}")

    # Detach local database
    conn.execute("DETACH local_db")

    # Close connection
    conn.close()

    print("\n" + "=" * 60)
    print(f"Sync complete! {synced_rows} total rows synced.")
    print(f"Local database ready at: {LOCAL_DB}")
    print("=" * 60)


if __name__ == "__main__":
    main()
