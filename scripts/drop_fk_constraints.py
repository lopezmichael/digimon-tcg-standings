"""
Drop foreign key constraints from MotherDuck database.

DuckDB UPDATE = DELETE + INSERT internally, which violates FK constraints.
On MotherDuck, this manifests as "Remote catalog has changed" errors.
We handle referential integrity at the application level instead.

Usage:
    python scripts/drop_fk_constraints.py

Prerequisites:
    - MOTHERDUCK_TOKEN in .env file
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
    print("Dropping FK constraints from MotherDuck")
    print("=" * 60)

    # Connect to MotherDuck
    print("\nConnecting to MotherDuck...")
    md_conn = f"md:?motherduck_token={MOTHERDUCK_TOKEN}"
    conn = duckdb.connect(md_conn)
    conn.execute(f"USE {MOTHERDUCK_DB}")
    print(f"    Connected to '{MOTHERDUCK_DB}'")

    # Find all FK constraints
    print("\nLooking for foreign key constraints...")
    try:
        fk_constraints = conn.execute("""
            SELECT
                table_name,
                constraint_index,
                constraint_column_names
            FROM duckdb_constraints()
            WHERE constraint_type = 'FOREIGN KEY'
        """).fetchall()
    except Exception as e:
        print(f"    Error querying constraints: {e}")
        # Fallback: try to drop known FK constraints by recreating tables
        fk_constraints = []

    if not fk_constraints:
        print("    No FK constraints found via duckdb_constraints().")
        print("    Trying to drop known constraints by table recreation...")
        drop_by_recreation(conn)
    else:
        print(f"    Found {len(fk_constraints)} FK constraint(s):")
        for table, idx, cols in fk_constraints:
            print(f"      - {table} (index: {idx}, columns: {cols})")

        # Drop each FK constraint
        print("\nDropping constraints...")
        for table, idx, cols in fk_constraints:
            constraint_name = f"{table}_{idx}_fkey"
            try:
                # Try dropping by index name patterns
                # DuckDB auto-names FK constraints, try common patterns
                dropped = False
                for name_attempt in [
                    constraint_name,
                    f"fk_{table}_{idx}",
                    f"{table}_fk",
                ]:
                    try:
                        conn.execute(f"ALTER TABLE {table} DROP CONSTRAINT \"{name_attempt}\"")
                        print(f"    Dropped: {name_attempt} from {table}")
                        dropped = True
                        break
                    except Exception:
                        continue

                if not dropped:
                    print(f"    Could not drop constraint on {table} by name, will recreate table")
                    drop_table_fk_by_recreation(conn, table)

            except Exception as e:
                print(f"    Error on {table}: {e}")

    # Verify
    print("\nVerifying no FK constraints remain...")
    try:
        remaining = conn.execute("""
            SELECT table_name, constraint_column_names
            FROM duckdb_constraints()
            WHERE constraint_type = 'FOREIGN KEY'
        """).fetchall()
        if remaining:
            print(f"    WARNING: {len(remaining)} FK constraint(s) still exist:")
            for table, cols in remaining:
                print(f"      - {table}: {cols}")
        else:
            print("    All FK constraints removed successfully!")
    except Exception as e:
        print(f"    Could not verify: {e}")

    conn.close()
    print("\n" + "=" * 60)
    print("Done!")
    print("=" * 60)


def drop_by_recreation(conn):
    """Drop FK constraints by recreating tables without them."""
    # Tables known to have FK constraints in schema.sql:
    # 1. players: home_store_id REFERENCES stores(store_id)
    # 2. archetype_cards: archetype_id REFERENCES deck_archetypes(archetype_id)
    # 3. tournaments: store_id REFERENCES stores(store_id)

    tables_with_fks = ["players", "archetype_cards", "tournaments"]

    for table in tables_with_fks:
        drop_table_fk_by_recreation(conn, table)


def drop_table_fk_by_recreation(conn, table):
    """Recreate a single table without FK constraints."""
    temp_table = f"{table}_no_fk"

    try:
        # Get columns
        cols_info = conn.execute(f"DESCRIBE {table}").fetchall()
        col_names = [row[0] for row in cols_info]
        cols_str = ", ".join(col_names)

        print(f"    Recreating {table} without FK constraints...")

        # Create temp copy
        conn.execute(f"CREATE TABLE {temp_table} AS SELECT * FROM {table}")

        # Get row count for verification
        count = conn.execute(f"SELECT COUNT(*) FROM {temp_table}").fetchone()[0]

        # Drop original (CASCADE to drop dependent objects)
        conn.execute(f"DROP TABLE {table} CASCADE")

        # Get the CREATE TABLE statement without FK constraints
        # We'll recreate with just the column definitions
        create_sql = get_create_without_fk(conn, table, cols_info)
        conn.execute(create_sql)

        # Copy data back
        conn.execute(f"INSERT INTO {table} ({cols_str}) SELECT {cols_str} FROM {temp_table}")

        # Verify row count
        new_count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        if new_count != count:
            print(f"    WARNING: Row count mismatch! Original: {count}, New: {new_count}")
        else:
            print(f"    {table}: recreated ({count} rows preserved)")

        # Drop temp table
        conn.execute(f"DROP TABLE {temp_table}")

    except Exception as e:
        print(f"    ERROR recreating {table}: {e}")
        # Try to recover
        try:
            exists = conn.execute(
                f"SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '{table}'"
            ).fetchone()[0]
            if exists == 0:
                # Original was dropped but recreation failed, restore from temp
                conn.execute(f"ALTER TABLE {temp_table} RENAME TO {table}")
                print(f"    Recovered {table} from temp table")
        except Exception:
            print(f"    CRITICAL: Could not recover {table}! Check MotherDuck manually.")


def get_create_without_fk(conn, table, cols_info):
    """Generate CREATE TABLE SQL without FK constraints."""
    # Map DuckDB types
    parts = []
    pk_col = None

    for col_name, col_type, is_null, default_val, pk, *rest in cols_info:
        col_def = f'"{col_name}" {col_type}'

        if pk:
            col_def += " PRIMARY KEY"
            pk_col = col_name
        if is_null == "NO" and not pk:
            col_def += " NOT NULL"
        if default_val is not None and default_val != "NULL":
            col_def += f" DEFAULT {default_val}"

        parts.append(col_def)

    cols_sql = ",\n    ".join(parts)
    return f"CREATE TABLE {table} (\n    {cols_sql}\n)"


if __name__ == "__main__":
    main()
