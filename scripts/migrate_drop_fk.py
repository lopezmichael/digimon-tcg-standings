#!/usr/bin/env python3
"""
Migration: Drop foreign key constraints from results table.

DuckDB rewrites UPDATE as DELETE + INSERT internally, which causes
FK violations when updating rows that are referenced by other tables.
Since we handle referential integrity manually (checking before delete),
we can safely drop these constraints.

Run: python scripts/migrate_drop_fk.py
"""

import os
import duckdb
from dotenv import load_dotenv

load_dotenv()

def migrate():
    token = os.getenv("MOTHERDUCK_TOKEN")
    if not token:
        print("Error: MOTHERDUCK_TOKEN not set")
        return False

    db_name = os.getenv("MOTHERDUCK_DATABASE", "digimon_tcg_dfw")
    con = duckdb.connect(f"md:{db_name}?motherduck_token={token}")

    print("Connected to MotherDuck")

    # DuckDB doesn't support ALTER TABLE DROP CONSTRAINT directly
    # We need to recreate the table without the FK constraints

    print("Recreating results table without FK constraints...")

    try:
        # Create new table without FK constraints
        con.execute("""
            CREATE TABLE IF NOT EXISTS results_new (
                result_id INTEGER PRIMARY KEY,
                tournament_id INTEGER NOT NULL,
                player_id INTEGER NOT NULL,
                archetype_id INTEGER,
                placement INTEGER,
                wins INTEGER DEFAULT 0,
                losses INTEGER DEFAULT 0,
                ties INTEGER DEFAULT 0,
                decklist_url VARCHAR,
                decklist_json TEXT,
                notes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(tournament_id, player_id)
            )
        """)

        # Copy data
        con.execute("""
            INSERT INTO results_new
            SELECT * FROM results
        """)

        # Get count
        count = con.execute("SELECT COUNT(*) FROM results_new").fetchone()[0]
        print(f"Copied {count} results to new table")

        # Drop old table
        con.execute("DROP TABLE results")

        # Rename new table
        con.execute("ALTER TABLE results_new RENAME TO results")

        # Recreate indexes
        con.execute("CREATE INDEX IF NOT EXISTS idx_results_tournament ON results(tournament_id)")
        con.execute("CREATE INDEX IF NOT EXISTS idx_results_player ON results(player_id)")
        con.execute("CREATE INDEX IF NOT EXISTS idx_results_archetype ON results(archetype_id)")
        con.execute("CREATE INDEX IF NOT EXISTS idx_results_placement ON results(placement)")

        print("Migration complete! FK constraints removed from results table.")
        print("Referential integrity is now handled at the application level.")

        con.close()
        return True

    except Exception as e:
        print(f"Error: {e}")
        con.close()
        return False

if __name__ == "__main__":
    migrate()
