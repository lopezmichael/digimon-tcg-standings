"""
Sync DigimonCard.io Cards to Database

Fetches all cards from DigimonCard.io API and caches them in the database.
This allows the Shiny app to search cards locally without external API calls.

Usage:
    python scripts/sync_cards.py              # Sync to MotherDuck (default)
    python scripts/sync_cards.py --local      # Sync to local DuckDB
    python scripts/sync_cards.py --set BT24   # Sync specific set only

Prerequisites:
    pip install duckdb python-dotenv requests
    MOTHERDUCK_TOKEN in .env file (for MotherDuck sync)
"""

import os
import re
import sys
import time
import argparse
import requests
import duckdb
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

# Configuration
MOTHERDUCK_DB = os.getenv("MOTHERDUCK_DATABASE", "digimon_tcg_dfw")
MOTHERDUCK_TOKEN = os.getenv("MOTHERDUCK_TOKEN")
API_BASE = "https://digimoncard.io/index.php/api-public"
COLORS = ["Red", "Blue", "Yellow", "Green", "Purple", "Black", "White"]

# Rate limiting: 15 requests per 10 seconds
REQUEST_DELAY = 0.7  # ~14 requests per 10 seconds (safe margin)


def is_standard_art(card_id: str) -> bool:
    """Check if card ID is a standard (non-alternate) art."""
    # Valid patterns: BT13-087, EX10-042, ST15-01, P-001, LM-001
    # Invalid: BT13-087_P1, BT13-087-P1, anything with underscore or extra suffix
    pattern = r'^[A-Z]{1,3}\d{0,2}-\d{2,3}$'
    return bool(re.match(pattern, card_id))


def extract_set_code(card_id: str) -> str:
    """Extract set code from card ID (e.g., 'BT13' from 'BT13-087')."""
    match = re.match(r'^([A-Z]{1,3}\d{0,2})-', card_id)
    return match.group(1) if match else None


def fetch_cards_by_color(color: str, set_filter: str = None) -> list:
    """Fetch all cards of a specific color from the API."""
    url = f"{API_BASE}/search"
    params = {
        "color": color,
        "limit": 1000  # Get all cards
    }
    if set_filter:
        params["pack"] = set_filter

    headers = {
        "User-Agent": "DigimonTCGTracker/1.0 (CardSync)"
    }

    try:
        response = requests.get(url, params=params, headers=headers, timeout=30)

        if response.status_code == 400:
            return []  # No results

        if response.status_code != 200:
            print(f"    API error: HTTP {response.status_code}")
            return []

        return response.json()

    except Exception as e:
        print(f"    Request failed: {e}")
        return []


def process_card(card: dict) -> dict:
    """Transform API card data to our schema format."""
    card_id = card.get("id") or card.get("cardnumber", "")
    name = card.get("name", "")

    return {
        "card_id": card_id,
        "name": name,
        "display_name": f"{name} ({card_id})",
        "card_type": card.get("type", ""),
        "color": card.get("color", ""),
        "color2": card.get("color2") or None,
        "level": int(card.get("level")) if card.get("level") else None,
        "dp": int(card.get("dp")) if card.get("dp") else None,
        "play_cost": int(card.get("play_cost")) if card.get("play_cost") else None,
        "digi_type": card.get("digi_type") or card.get("digi_type2") or None,
        "stage": card.get("stage") or None,
        "rarity": card.get("rarity") or None,
        "set_code": extract_set_code(card_id)
    }


def sync_cards(conn, set_filter: str = None):
    """Fetch cards from API and upsert to database."""
    all_cards = []

    print("\nFetching cards from DigimonCard.io API...")

    for color in COLORS:
        print(f"  Fetching {color} cards...", end=" ", flush=True)
        cards = fetch_cards_by_color(color, set_filter)

        # Filter to standard arts only
        standard_cards = [c for c in cards if is_standard_art(c.get("id") or c.get("cardnumber", ""))]

        print(f"found {len(cards)}, keeping {len(standard_cards)} (standard art)")
        all_cards.extend(standard_cards)

        # Rate limiting
        time.sleep(REQUEST_DELAY)

    # Deduplicate by card_id (some cards appear in multiple colors)
    seen_ids = set()
    unique_cards = []
    for card in all_cards:
        card_id = card.get("id") or card.get("cardnumber", "")
        if card_id not in seen_ids:
            seen_ids.add(card_id)
            unique_cards.append(card)

    print(f"\nTotal unique cards to sync: {len(unique_cards)}")

    if not unique_cards:
        print("No cards to sync.")
        return 0

    # Process and upsert cards
    print("\nUpserting to MotherDuck...")

    processed = 0
    for card in unique_cards:
        try:
            card_data = process_card(card)

            # Upsert using INSERT OR REPLACE
            conn.execute("""
                INSERT OR REPLACE INTO cards
                (card_id, name, display_name, card_type, color, color2,
                 level, dp, play_cost, digi_type, stage, rarity, set_code, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            """, [
                card_data["card_id"],
                card_data["name"],
                card_data["display_name"],
                card_data["card_type"],
                card_data["color"],
                card_data["color2"],
                card_data["level"],
                card_data["dp"],
                card_data["play_cost"],
                card_data["digi_type"],
                card_data["stage"],
                card_data["rarity"],
                card_data["set_code"]
            ])
            processed += 1

        except Exception as e:
            print(f"  Error processing {card.get('id', 'unknown')}: {e}")

    return processed


def main():
    parser = argparse.ArgumentParser(description="Sync DigimonCard.io cards to database")
    parser.add_argument("--set", help="Sync specific set only (e.g., BT24)")
    parser.add_argument("--local", action="store_true", help="Sync to local DuckDB instead of MotherDuck")
    args = parser.parse_args()

    if not args.local and not MOTHERDUCK_TOKEN:
        print("Error: MOTHERDUCK_TOKEN not set in .env")
        print("Use --local flag to sync to local DuckDB instead")
        sys.exit(1)

    print("=" * 60)
    print("DigimonCard.io Card Sync")
    print("=" * 60)

    if args.local:
        db_path = "data/local.duckdb"
        print(f"Database: {db_path} (local)")
    else:
        print(f"Database: {MOTHERDUCK_DB} (MotherDuck)")

    print(f"Mode: {'Set ' + args.set if args.set else 'Full sync'}")
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Connect to database
    if args.local:
        print(f"\nConnecting to local DuckDB...")
        conn = duckdb.connect(db_path)
    else:
        print(f"\nConnecting to MotherDuck...")
        conn = duckdb.connect(f"md:{MOTHERDUCK_DB}?motherduck_token={MOTHERDUCK_TOKEN}")
    print("Connected!")

    # Ensure table exists
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

    # Get count before sync
    before_count = conn.execute("SELECT COUNT(*) FROM cards").fetchone()[0]
    print(f"Cards in database before sync: {before_count}")

    # Sync cards
    processed = sync_cards(conn, args.set)

    # Get count after sync
    after_count = conn.execute("SELECT COUNT(*) FROM cards").fetchone()[0]

    conn.close()

    print("\n" + "=" * 60)
    print("Sync complete!")
    print("=" * 60)
    print(f"Cards processed: {processed}")
    print(f"Cards in database: {after_count}")
    print(f"New cards added: {after_count - before_count}")
    print("=" * 60)


if __name__ == "__main__":
    main()
