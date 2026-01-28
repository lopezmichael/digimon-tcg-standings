"""
Database Migration: Add cards table to MotherDuck

Creates the cards table for caching DigimonCard.io data.

Usage:
    python scripts/migrate_cards.py
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
    print("Migration: Add cards table")
    print("=" * 60)

    # Connect to MotherDuck
    print(f"\nConnecting to MotherDuck: {MOTHERDUCK_DB}")
    conn = duckdb.connect(f"md:{MOTHERDUCK_DB}?motherduck_token={MOTHERDUCK_TOKEN}")
    print("Connected!")

    print("\nCreating cards table...")

    # Create cards table
    conn.execute("""
        CREATE TABLE IF NOT EXISTS cards (
            card_id VARCHAR PRIMARY KEY,
            name VARCHAR NOT NULL,
            display_name VARCHAR NOT NULL,
            card_type VARCHAR NOT NULL,
            color VARCHAR,
            color2 VARCHAR,
            level INTEGER,
            dp INTEGER,
            play_cost INTEGER,
            digi_type VARCHAR,
            stage VARCHAR,
            rarity VARCHAR,
            set_code VARCHAR,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    print("  + Created cards table")

    # Create indexes
    indexes = [
        ("idx_cards_name", "cards(name)"),
        ("idx_cards_type", "cards(card_type)"),
        ("idx_cards_color", "cards(color)"),
        ("idx_cards_set", "cards(set_code)")
    ]

    for idx_name, idx_def in indexes:
        try:
            conn.execute(f"CREATE INDEX IF NOT EXISTS {idx_name} ON {idx_def}")
        except Exception as e:
            if "already exists" not in str(e).lower():
                print(f"  Warning: {e}")
    print("  + Created indexes")

    conn.close()

    print("\n" + "=" * 60)
    print("Migration complete!")
    print("=" * 60)
    print("\nNext: Run 'python scripts/sync_cards.py' to populate the table")

if __name__ == "__main__":
    main()
