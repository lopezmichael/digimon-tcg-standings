# Card Database Sync

Sync cards from DigimonCard.io API to local/cloud database.

## Quick Reference

```bash
# Regular update (fast - only adds new cards)
py scripts/sync_cards.py --by-set --incremental

# Full re-sync (slower - updates all cards)
py scripts/sync_cards.py --by-set

# Sync specific set only
py scripts/sync_cards.py --set BT-25 --by-set

# Check for new set prefixes
py scripts/sync_cards.py --discover

# Sync to local database instead of MotherDuck
py scripts/sync_cards.py --by-set --local
```

## Flags

| Flag | Description |
|------|-------------|
| `--by-set` | Fetch by set/pack instead of color. **Recommended** - catches multi-color and unusual cards that color-based search misses. |
| `--incremental` | Only add cards not already in database. Much faster for routine updates. |
| `--discover` | Scan API for new/unknown set prefixes. Run periodically to check for new set types. |
| `--set X` | Sync only a specific set (e.g., `BT-25`, `ST-15`, `EX-12`). |
| `--local` | Sync to local DuckDB (`data/local.duckdb`) instead of MotherDuck cloud. |

## Set Coverage

The script syncs these set types:

| Prefix | Sets | Description |
|--------|------|-------------|
| BT | BT-01 to BT-24 | Booster sets |
| EX | EX-01 to EX-11 | Extra Boosters |
| ST | ST-1 to ST-22 | Starter Decks (note: ST-1 to ST-9 use single digit) |
| LM | LM-01 to LM-08 | Limited Card Packs |
| RB | RB-01 | Resurgence Booster |
| P/BO | 49 packs | Promo cards (Tamer Battle Packs, Box Promos, Dash Packs, etc.) |

**Excluded sets:**
- BTC-01 (Ultimate Evolution - different game variant)
- DM (Demo Decks)
- MO (Unknown/Miscellaneous)

## Typical Workflows

### When a new booster set releases (e.g., BT-25)

1. Update `get_all_sets()` in `scripts/sync_cards.py` to include the new set
2. Run: `py scripts/sync_cards.py --set BT-25 --by-set`

### Monthly maintenance

```bash
# Check for any new set prefixes
py scripts/sync_cards.py --discover

# Pull any new cards across all sets
py scripts/sync_cards.py --by-set --incremental
```

### Fresh database setup

```bash
# Full sync to local database
py scripts/sync_cards.py --by-set --local

# Or full sync to MotherDuck
py scripts/sync_cards.py --by-set
```

## API Notes

- **Rate limit**: 15 requests per 10 seconds (script uses 0.7s delay)
- **Pack name format**: Use dashes (e.g., `BT-21`, not `BT21`)
- **ST decks 1-9**: Use single digit (`ST-1`, not `ST-01`)
- **Promo cards**: P-xxx cards are scattered across many promo packs, not a single "P-" pack

## Adding New Sets

When new sets release, edit `scripts/sync_cards.py`:

```python
def get_all_sets() -> list:
    # Update the range for new boosters
    bt_sets = [f"BT-{i:02d}" for i in range(1, 26)]  # Changed 25 to 26 for BT-25

    # Or add new promo packs to the list
    promo_packs = [
        ...
        "New Promo Pack Name",  # Add new packs here
    ]
```

## Troubleshooting

**Cards missing from a set?**
- Use `--by-set` flag (color-based search misses some multi-color cards)
- Check if the API uses a different pack name format

**New prefix discovered?**
- Run `--discover` to identify it
- Decide whether to add it to `get_all_sets()` or exclude it
- Update `get_known_prefixes()` if adding

**Sync taking too long?**
- Use `--incremental` for routine updates
- Use `--set X` to sync only specific sets
