"""
Delete Mock Data from MotherDuck

Removes all test/mock tournament data from MotherDuck cloud database
while preserving reference data (stores, formats, archetypes).

Usage:
    pip install duckdb python-dotenv
    python scripts/delete_mock_data.py           # Interactive (asks for confirmation)
    python scripts/delete_mock_data.py --confirm # Skip confirmation prompt

Prerequisites:
    - MOTHERDUCK_TOKEN in .env file
"""

import os
import sys
import duckdb
from dotenv import load_dotenv

# Load environment
load_dotenv()

MOTHERDUCK_DB = os.getenv("MOTHERDUCK_DATABASE", "digimon_tcg_dfw")
MOTHERDUCK_TOKEN = os.getenv("MOTHERDUCK_TOKEN")

# Tables to delete (in order respecting foreign keys)
TABLES_TO_DELETE = [
    "results",      # References tournaments and players
    "tournaments",  # References stores
    "players",      # No dependencies
    "ingestion_log" # No dependencies
]

def main():
    if not MOTHERDUCK_TOKEN:
        print("Error: MOTHERDUCK_TOKEN not set in .env")
        print("Get your token at: https://app.motherduck.com/settings/tokens")
        return

    print("=" * 60)
    print("Delete Mock Data from MotherDuck")
    print("=" * 60)

    # Connect to MotherDuck
    print(f"\nConnecting to MotherDuck database: {MOTHERDUCK_DB}")
    md_conn = f"md:{MOTHERDUCK_DB}?motherduck_token={MOTHERDUCK_TOKEN}"
    conn = duckdb.connect(md_conn)
    print("Connected!")

    # Show current counts
    print("\nCurrent data counts:")
    counts = {}
    for table in TABLES_TO_DELETE:
        try:
            count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            counts[table] = count
            print(f"  {table}: {count}")
        except Exception as e:
            print(f"  {table}: ERROR - {e}")
            counts[table] = 0

    total = sum(counts.values())
    if total == 0:
        print("\nNo data to delete. Tables are already empty.")
        conn.close()
        return

    # Confirm deletion
    print("\n" + "-" * 60)
    print("WARNING: This will delete ALL players, tournaments, and results!")
    print("Stores, formats, and archetypes will be preserved.")
    print("-" * 60)

    if "--confirm" in sys.argv:
        print("\n--confirm flag provided, proceeding with deletion...")
    else:
        response = input("\nType 'DELETE' to confirm: ")
        if response != "DELETE":
            print("Cancelled.")
            conn.close()
            return

    # Delete data
    print("\nDeleting data...")
    deleted = {}
    for table in TABLES_TO_DELETE:
        try:
            conn.execute(f"DELETE FROM {table}")
            deleted[table] = counts[table]
            print(f"  Deleted {counts[table]} rows from {table}")
        except Exception as e:
            print(f"  {table}: ERROR - {e}")
            deleted[table] = 0

    conn.close()

    # Summary
    print("\n" + "=" * 60)
    print("Mock data deletion complete!")
    print("=" * 60)
    print("\nDeleted:")
    for table, count in deleted.items():
        print(f"  {table}: {count} rows")
    print("\nPreserved:")
    print("  stores, formats, deck_archetypes, archetype_cards")
    print("\nYou're now ready to collect real tournament data!")
    print("=" * 60)

if __name__ == "__main__":
    main()
