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
MOTHERDUCK_DB = os.getenv("MOTHERDUCK_DATABASE", "digimon_tcg_dfw")
MOTHERDUCK_TOKEN = os.getenv("MOTHERDUCK_TOKEN")

TABLES = [
    "stores",
    "players",
    "deck_archetypes",
    "archetype_cards",
    "tournaments",
    "results",
    "ingestion_log"
]

def main():
    if not MOTHERDUCK_TOKEN:
        print("Error: MOTHERDUCK_TOKEN not set in .env")
        return

    if not Path(LOCAL_DB).exists():
        print(f"Error: Local database not found at {LOCAL_DB}")
        return

    print("=" * 50)
    print("Syncing local DuckDB → MotherDuck")
    print("=" * 50)

    # Connect to local
    print(f"\nConnecting to local: {LOCAL_DB}")
    local = duckdb.connect(LOCAL_DB, read_only=True)

    # Connect to MotherDuck
    print(f"Connecting to MotherDuck: {MOTHERDUCK_DB}")
    md_conn = f"md:{MOTHERDUCK_DB}?motherduck_token={MOTHERDUCK_TOKEN}"
    cloud = duckdb.connect(md_conn)

    # Sync each table
    for table in TABLES:
        try:
            # Check if table has data locally
            count = local.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

            if count == 0:
                print(f"  {table}: skipped (empty)")
                continue

            # Get data from local
            data = local.execute(f"SELECT * FROM {table}").fetchdf()

            # Drop and recreate in cloud (simple approach)
            cloud.execute(f"DROP TABLE IF EXISTS {table}")
            cloud.execute(f"CREATE TABLE {table} AS SELECT * FROM data")

            print(f"  {table}: synced {count} rows")

        except Exception as e:
            print(f"  {table}: ERROR - {e}")

    # Close connections
    local.close()
    cloud.close()

    print("\n" + "=" * 50)
    print("Sync complete!")
    print(f"Your data is now in MotherDuck: {MOTHERDUCK_DB}")
    print("=" * 50)

if __name__ == "__main__":
    main()
