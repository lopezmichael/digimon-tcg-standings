"""
Database Migration v0.5.0 for MotherDuck

Adds:
- is_online column to stores table
- is_multi_color column to deck_archetypes table
- Updates store_activity view

Usage:
    python scripts/migrate_v0.5.0.py
"""

import os
import duckdb
from dotenv import load_dotenv

load_dotenv()

MOTHERDUCK_DB = os.getenv("MOTHERDUCK_DATABASE", "digimon_tcg_dfw")
MOTHERDUCK_TOKEN = os.getenv("MOTHERDUCK_TOKEN")

def main():
    if not MOTHERDUCK_TOKEN:
        print("Error: MOTHERDUCK_TOKEN not set in .env")
        return

    print("=" * 60)
    print("Migration v0.5.0 for MotherDuck")
    print("=" * 60)

    # Connect to MotherDuck
    print(f"\nConnecting to MotherDuck: {MOTHERDUCK_DB}")
    conn = duckdb.connect(f"md:{MOTHERDUCK_DB}?motherduck_token={MOTHERDUCK_TOKEN}")
    print("Connected!")

    print("\nRunning migration v0.5.0...\n")

    # Add is_online to stores
    try:
        conn.execute("ALTER TABLE stores ADD COLUMN is_online BOOLEAN DEFAULT FALSE")
        print("  + Added is_online column to stores")
    except Exception as e:
        if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
            print("  - is_online column already exists")
        else:
            print(f"  ERROR: {e}")

    # Add is_multi_color to deck_archetypes
    try:
        conn.execute("ALTER TABLE deck_archetypes ADD COLUMN is_multi_color BOOLEAN DEFAULT FALSE")
        print("  + Added is_multi_color column to deck_archetypes")
    except Exception as e:
        if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
            print("  - is_multi_color column already exists")
        else:
            print(f"  ERROR: {e}")

    # Update store_activity view
    try:
        conn.execute("""
            CREATE OR REPLACE VIEW store_activity AS
            SELECT
                s.store_id,
                s.name AS store_name,
                s.city,
                s.latitude,
                s.longitude,
                s.address,
                s.is_online,
                COUNT(DISTINCT t.tournament_id) AS total_tournaments,
                COUNT(DISTINCT r.player_id) AS unique_players,
                SUM(t.player_count) AS total_attendance,
                ROUND(AVG(t.player_count), 1) AS avg_attendance,
                MAX(t.event_date) AS last_event_date,
                MIN(t.event_date) AS first_event_date
            FROM stores s
            LEFT JOIN tournaments t ON s.store_id = t.store_id
            LEFT JOIN results r ON t.tournament_id = r.tournament_id
            WHERE s.is_active = TRUE
            GROUP BY s.store_id, s.name, s.city, s.latitude, s.longitude, s.address, s.is_online
        """)
        print("  + Updated store_activity view")
    except Exception as e:
        print(f"  ERROR updating view: {e}")

    conn.close()

    print("\n" + "=" * 60)
    print("Migration v0.5.0 complete!")
    print("=" * 60)

if __name__ == "__main__":
    main()
