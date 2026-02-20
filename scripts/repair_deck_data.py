"""
Repair deck data for Limitless results

Re-fetches standings from Limitless API and updates results that are missing
archetype_id with the deck data from the API.

Usage:
    python scripts/repair_deck_data.py --organizer 452  # Eagle's Nest
    python scripts/repair_deck_data.py --organizer 578  # MasterRukasu
"""

import argparse
import duckdb
import requests
import time
from collections import defaultdict
from pathlib import Path

API_BASE = "https://play.limitlesstcg.com/api"
UNKNOWN_ID = 50
LOCAL_DB = "data/local.duckdb"


def main():
    parser = argparse.ArgumentParser(description="Repair deck data for Limitless results")
    parser.add_argument("--organizer", required=True, help="Limitless organizer ID")
    args = parser.parse_args()

    organizer_id = args.organizer

    # Connect to local DB
    conn = duckdb.connect(LOCAL_DB)

    # Get the deck map cache
    deck_map = {}
    rows = conn.execute("""
        SELECT ldm.limitless_deck_id, ldm.archetype_id
        FROM limitless_deck_map ldm
        WHERE ldm.archetype_id IS NOT NULL
    """).fetchall()
    for r in rows:
        deck_map[r[0]] = r[1]
    print(f"Loaded {len(deck_map)} deck mappings")

    # Get results without deck data for this organizer
    results_to_fix = conn.execute("""
        SELECT r.result_id, r.tournament_id, r.player_id, t.limitless_id
        FROM results r
        JOIN tournaments t ON r.tournament_id = t.tournament_id
        JOIN stores s ON t.store_id = s.store_id
        WHERE s.limitless_organizer_id = ?
        AND r.archetype_id IS NULL
        ORDER BY t.limitless_id
    """, [organizer_id]).fetchall()

    print(f"Found {len(results_to_fix)} results to potentially fix")

    # Group by tournament
    by_tournament = defaultdict(list)
    for r in results_to_fix:
        by_tournament[r[3]].append(r)  # group by limitless_id

    print(f"Across {len(by_tournament)} tournaments")
    print()

    # Fetch and update each tournament
    fixed = 0
    no_deck_in_api = 0
    new_decks = {}

    for limitless_id, results in by_tournament.items():
        print(f"Fetching tournament {limitless_id}...")

        # Get standings from API
        url = f"{API_BASE}/tournaments/{limitless_id}/standings"
        resp = requests.get(url, headers={"User-Agent": "DigiLab/1.0"})

        if resp.status_code != 200:
            print(f"  Failed: {resp.status_code}")
            time.sleep(1.5)
            continue

        standings = resp.json()

        # Build player name to deck mapping
        player_decks = {}
        for s in standings:
            name = s.get("name", "")
            deck = s.get("deck", {})
            deck_id = deck.get("id", "") if deck else ""
            deck_name = deck.get("name", "") if deck else ""
            if deck_id:
                player_decks[name] = (deck_id, deck_name)

        players_with_deck = len(player_decks)
        players_without_deck = len(standings) - players_with_deck

        # Now match results to standings
        tournament_fixed = 0
        for result in results:
            result_id = result[0]
            player_id = result[2]

            # Get player name
            player = conn.execute(
                "SELECT display_name FROM players WHERE player_id = ?",
                [player_id]
            ).fetchone()
            if not player:
                continue
            player_name = player[0]

            # Find deck in API response
            deck_info = player_decks.get(player_name)
            if not deck_info:
                no_deck_in_api += 1
                continue

            deck_id, deck_name = deck_info

            # Resolve archetype
            if deck_id == "other":
                archetype_id = UNKNOWN_ID
            else:
                archetype_id = deck_map.get(deck_id)
                if not archetype_id:
                    # New deck we haven't seen - track it
                    if deck_id not in new_decks:
                        new_decks[deck_id] = deck_name
                    continue

            if archetype_id:
                conn.execute(
                    "UPDATE results SET archetype_id = ? WHERE result_id = ?",
                    [archetype_id, result_id]
                )
                fixed += 1
                tournament_fixed += 1

        print(f"  API: {players_with_deck} with deck, {players_without_deck} without | Fixed: {tournament_fixed}")
        time.sleep(1.5)  # Rate limit

    conn.close()
    print()
    print(f"Fixed {fixed} results with deck data")
    print(f"No deck in API: {no_deck_in_api}")
    if new_decks:
        print(f"Found {len(new_decks)} new unmapped decks:")
        for deck_id, deck_name in new_decks.items():
            print(f"  {deck_id}: {deck_name}")


if __name__ == "__main__":
    main()
