"""
Find Digimon tournament organizers with good deck data coverage.

Scans recent tournaments, groups by organizer, and checks deck submission rates.
"""

import sys
import requests
import time
from collections import defaultdict

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

API_BASE = "https://play.limitlesstcg.com/api"

# Already synced organizers - skip these
ALREADY_SYNCED = {"452", "281", "559", "578"}


def discover_organizers():
    """Discover organizers from recent tournaments."""
    print("Discovering organizers from recent Digimon tournaments...")
    organizers = defaultdict(lambda: {"count": 0, "sample_name": ""})

    for page in range(1, 11):
        url = f"{API_BASE}/tournaments?game=DCG&limit=50&page={page}"
        resp = requests.get(url, headers={"User-Agent": "DigiLab/1.0"})
        if resp.status_code != 200:
            print(f"  Failed page {page}: {resp.status_code}")
            break
        data = resp.json()
        if not data:
            break
        for t in data:
            org_id = str(t.get("organizerId", ""))
            if org_id and org_id not in ALREADY_SYNCED:
                organizers[org_id]["count"] += 1
                if not organizers[org_id]["sample_name"]:
                    organizers[org_id]["sample_name"] = t.get("name", "")[:35]
        print(f"  Page {page}: {len(data)} tournaments")
        time.sleep(1)

    # Sort by count
    sorted_orgs = sorted(organizers.items(), key=lambda x: x[1]["count"], reverse=True)
    return [(org_id, info["sample_name"], info["count"]) for org_id, info in sorted_orgs]


def check_deck_coverage(org_id):
    """Check deck data coverage for an organizer by sampling tournaments."""
    url = f"{API_BASE}/tournaments?game=DCG&organizerId={org_id}&limit=5"
    resp = requests.get(url, headers={"User-Agent": "DigiLab/1.0"})
    if resp.status_code != 200:
        return None

    tournaments = resp.json()
    if not tournaments:
        return None

    total_players = 0
    players_with_deck = 0

    for t in tournaments[:3]:
        t_id = t.get("id")
        url = f"{API_BASE}/tournaments/{t_id}/standings"
        resp = requests.get(url, headers={"User-Agent": "DigiLab/1.0"})
        if resp.status_code != 200:
            continue

        standings = resp.json()
        for s in standings:
            total_players += 1
            deck = s.get("deck", {})
            if deck and deck.get("id"):
                players_with_deck += 1

        time.sleep(1.5)

    if total_players > 0:
        return 100 * players_with_deck / total_players
    return None


def main():
    # Discover organizers
    organizers = discover_organizers()

    print()
    print(f"Found {len(organizers)} unique organizers (excluding already synced)")
    print()
    print("Top 15 by tournament count:")
    print("-" * 70)
    for org_id, name, count in organizers[:15]:
        print(f"  ID: {org_id:6s} | {count:3d} tournaments | {name}")

    print()
    print("=" * 70)
    print("Checking deck coverage for organizers with 3+ tournaments...")
    print("=" * 70)

    good_orgs = []
    partial_orgs = []

    for org_id, name, count in organizers:
        if count < 3:
            continue

        print(f"Checking {org_id} ({name[:25]})...", end=" ")
        coverage = check_deck_coverage(org_id)

        if coverage is not None:
            status = "GOOD" if coverage >= 80 else "PARTIAL" if coverage >= 50 else "LOW"
            print(f"{coverage:.0f}% - {status}")
            if coverage >= 80:
                good_orgs.append((org_id, name, count, coverage))
            elif coverage >= 50:
                partial_orgs.append((org_id, name, count, coverage))
        else:
            print("No data")

    print()
    print("=" * 70)
    print("RESULTS")
    print("=" * 70)

    print()
    print("GOOD (80%+ deck coverage):")
    if good_orgs:
        for org in sorted(good_orgs, key=lambda x: x[2], reverse=True):
            print(f"  ID: {org[0]:6s} | {org[2]:3d} tournaments | {org[3]:.0f}% | {org[1]}")
    else:
        print("  None found")

    print()
    print("PARTIAL (50-79% deck coverage):")
    if partial_orgs:
        for org in sorted(partial_orgs, key=lambda x: x[2], reverse=True):
            print(f"  ID: {org[0]:6s} | {org[2]:3d} tournaments | {org[3]:.0f}% | {org[1]}")
    else:
        print("  None found")


if __name__ == "__main__":
    main()
