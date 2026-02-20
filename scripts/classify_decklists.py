#!/usr/bin/env python3
"""
Deck Archetype Auto-Classification Script

Analyzes decklist_json in results table and assigns archetypes based on signature cards.
Only processes UNKNOWN archetype results that have decklists.

Usage:
    python scripts/classify_decklists.py --dry-run    # Preview changes
    python scripts/classify_decklists.py              # Apply changes
"""

import argparse
import duckdb
import json
from collections import Counter

# Classification rules: list of (archetype_name, required_cards, min_matches)
# required_cards can be a list of card name patterns (substring match)
# min_matches is how many of the required cards must be present
CLASSIFICATION_RULES = [
    # Specific deck archetypes (order matters - more specific first)

    # Blastmon (Sunarizamon/Rock deck)
    ("Blastmon", ["Blastmon", "Sunarizamon", "Landramon", "Proganomon"], 3),

    # Millenniummon (Jogress with Machinedramon + Kimeramon)
    ("Millenniummon", ["Millenniummon", "Machinedramon", "Kimeramon"], 3),

    # Magnamon Armors (Veemon armor evolution)
    ("Magnamon Armors", ["Magnamon", "Veemon", "Flamedramon"], 3),
    ("Magnamon Armors", ["Magnamon", "Veemon", "Shadramon"], 3),

    # Myotismon Loop
    ("Myotismon Loop", ["MaloMyotismon", "Myotismon", "Arukenimon", "Mummymon"], 3),

    # Medusamon (Elizamon line)
    ("Medusamon", ["Medusamon", "Lamiamon", "Elizamon"], 3),
    ("Medusamon", ["Medusamon", "Lamiamon", "Dimetromon"], 3),

    # Insectoids (Bug/Bee deck)
    ("Insectoids", ["TigerVespamon", "CannonBeemon", "FunBeemon"], 3),
    ("Insectoids", ["TigerVespamon", "Waspmon", "FunBeemon"], 3),

    # Gigaseadramon (Seadramon line)
    ("Gigaseadramon", ["GigaSeadramon", "MegaSeadramon", "Seadramon"], 3),
    ("Gigaseadramon", ["MetalSeadramon", "MegaSeadramon", "Seadramon"], 3),

    # Shakkoumon
    ("Shakkoumon", ["Shakkoumon", "Angemon", "Patamon"], 2),
    ("Shakkoumon", ["Shakkoumon", "Ankylomon"], 2),

    # Galaxy (space theme - Vademon, etc.)
    ("Galaxy", ["Vademon", "MetalMamemon", "Vegiemon"], 3),

    # Fenriloogamon
    ("Fenriloggamon", ["Fenriloogamon", "Cerberusmon", "Kazuchimon"], 2),
    ("Fenriloggamon", ["Fenriloogamon: Takemikazuchi"], 1),

    # Xros Heart (Shoutmon line)
    ("Xros Heart", ["OmniShoutmon", "Shoutmon"], 2),

    # Creepymon
    ("Creepymon", ["Creepymon", "SkullSatamon"], 2),

    # Beelzemon
    ("Beelzemon", ["Beelzemon", "Impmon"], 2),
    ("Beelzemon", ["Beelzemon: Blast Mode"], 1),

    # Gallantmon
    ("Gallantmon", ["Gallantmon", "Guilmon", "Growlmon"], 3),

    # Eaters
    ("Eaters", ["Eater", "EDEN's Javelin"], 1),

    # Imperialdramon variants
    ("Imperialdramon (UG)", ["Imperialdramon", "Paildramon", "ExVeemon"], 3),
    ("Imperialdramon (PR)", ["Imperialdramon", "Stingmon", "Wormmon"], 3),

    # Jesmon
    ("Jesmon", ["Jesmon", "Sistermon", "Huckmon"], 2),

    # Mastemon
    ("Mastemon (Tribal)", ["Mastemon", "Angewomon", "LadyDevimon"], 2),

    # Blue Flare
    ("Blue Flare", ["MetalGreymon", "MailBirdramon", "Greymon"], 3),

    # Leviamon
    ("Leviamon", ["Leviamon", "Gesomon", "Syakomon"], 2),

    # Lucemon
    ("Lucemon", ["Lucemon", "Lucemon: Chaos Mode", "Lucemon: Shadowlord Mode"], 2),

    # Alphamon
    ("CS Alphamon", ["Alphamon", "Dorumon", "DexDorugoramon"], 2),

    # UlforceVeedramon
    ("UlforceVeedramon", ["UlforceVeedramon", "AeroVeedramon"], 2),

    # MagnaGarurumon
    ("MagnaGarurumon", ["MagnaGarurumon", "Lobomon", "KendoGarurumon"], 2),

    # Wargreymon
    ("Wargreymon OTK", ["WarGreymon", "MetalGreymon", "Greymon", "Agumon"], 4),

    # Diaboromon
    ("Diaboromon", ["Diaboromon", "Infermon", "Keramon"], 2),

    # Royal Knights
    ("Royal Knights", ["Omnimon", "WarGreymon", "MetalGarurumon"], 3),

    # Numemon
    ("Numemon", ["Numemon", "PlatinumNumemon", "Monzaemon"], 2),

    # Rosemon
    ("Rosemon", ["Rosemon", "Lilamon", "Palmon"], 2),

    # Miragegaogamon
    ("Miragegaogamon", ["MirageGaogamon", "Gaogamon", "Gaomon"], 2),

    # Shinegreymon
    ("Shinegreymon", ["ShineGreymon", "RizeGreymon", "GeoGreymon"], 2),

    # Belphemon
    ("Belphemon", ["Belphemon", "Astamon"], 2),

    # Bloomlordmon
    ("Bloomlordmon", ["Bloomlordmon", "Lotosmon", "Rafflesimon"], 2),

    # Sakuyamon
    ("Sakuyamon", ["Sakuyamon", "Taomon", "Renamon"], 2),

    # Ravemon
    ("Ravemon", ["Ravemon", "Crowmon", "Falcomon"], 2),

    # D-Brigade
    ("D-Brigade", ["Darkdramon", "Commandramon", "Sealsdramon"], 2),

    # Bagra Army
    ("Bagra Army", ["Bagramon", "DarkKnightmon"], 2),

    # Hunters
    ("Hunters", ["Arresterdramon", "Gumdramon"], 2),

    # Justimon
    ("Justimon", ["Justimon", "Cyberdramon"], 2),

    # Leopardmon
    ("Leopardmon", ["Leopardmon", "LoaderLiomon"], 2),

    # LordKnightmon
    ("LordKnightmon", ["LordKnightmon", "Knightmon"], 2),

    # Examon
    ("Examon", ["Examon", "Breakdramon", "Slayerdramon"], 2),

    # Kentaurosmon
    ("Kentaurosmon", ["Kentaurosmon", "Sleipmon"], 1),

    # Hudiemon
    ("Hudiemon", ["Hudiemon", "Wormmon"], 2),

    # Gammamon
    ("Gammamon", ["Gammamon", "BetelGammamon", "Canoweissmon"], 2),

    # Chronicle (BT20 theme)
    ("Chronicle", ["Chronomon", "Valdurmon"], 1),

    # Jellymon
    ("Jellymon", ["Jellymon", "TeslaJellymon"], 2),

    # Angoramon
    ("Angoramon", ["Angoramon", "SymbareAngoramon"], 2),

    # Phoenixmon (Biyomon line)
    ("Phoenixmon", ["Phoenixmon", "Garudamon", "Birdramon", "Biyomon"], 3),

    # Wind Guardians
    ("Wind Guardians", ["Valdurmon", "Harpymon", "Aquilamon"], 2),

    # Deep Savers (aquatic)
    ("Deep Savers", ["Plesiomon", "MarineAngemon", "Gomamon"], 2),

    # TyrantKabuterimon
    ("TyrantKabuterimon", ["TyrantKabuterimon", "MegaKabuterimon", "Kabuterimon", "Tentomon"], 3),

    # Quartzmon
    ("Quartzmon", ["Quartzmon", "QueenBeemon"], 2),

    # Machinedramon (standalone, not Millenniummon)
    ("Machinedramon", ["Machinedramon", "MetalTyrannomon", "Megadramon"], 3),
    ("Machinedramon", ["Machinedramon", "Andromon", "Megadramon"], 3),

    # Gabu Bond / MetalGarurumon line
    ("Gabu Bond", ["Gabumon", "Garurumon", "WereGarurumon", "MetalGarurumon"], 4),

    # Agu Bond / WarGreymon line (if not caught by OTK)
    ("Agu Bond", ["Agumon - Bond of Bravery", "WarGreymon"], 2),

    # GAS (Garuru Alter-S)
    ("GAS (Garuru Alter-S)", ["Alter-S", "CresGarurumon"], 1),

    # Invisimon
    ("Invisimon", ["Invisimon", "Chaosdramon"], 1),

    # Blackwargreymon
    ("Blackwargreymon", ["BlackWarGreymon", "BlackGreymon"], 2),

    # Dorbickmon
    ("Dorbickmon Combo", ["Dorbickmon", "NeoVamdemon"], 1),

    # Silphymon
    ("Silphymon", ["Silphymon", "Aquilamon", "Gatomon"], 2),

    # Cherubimon
    ("Cherubimon", ["Cherubimon", "Antylamon", "Lopmon"], 2),

    # Megidramon
    ("Megidramon", ["Megidramon", "WarGrowlmon", "Guilmon"], 3),

    # Olympus XII
    ("Olympus XII", ["Jupitermon", "Junomon", "Apollomon"], 2),
    ("Olympus XII", ["Neptunemon", "Mercurymon"], 2),

    # TS Titans (Ogre/Titamon deck)
    ("TS Titans", ["Titamon", "Ogremon", "Goblimon"], 3),
    ("TS Titans", ["Titamon", "SkullBaluchimon"], 2),

    # Deusmon
    ("Deusmon", ["Deusmon", "Cometmon", "Warudamon"], 2),

    # Ghosts (Ghost/Phantom deck)
    ("Ghosts", ["DanDevimon", "Phantomon", "Ghostmon"], 2),
    ("Ghosts", ["NeoDevimon", "Phantomon", "DemiDevimon"], 3),

    # Examon (expanded rules)
    ("Examon", ["Examon", "Wingdramon", "Coredramon"], 3),
    ("Examon", ["Examon", "Groundramon", "Dracomon"], 3),

    # Royal Base (Magnamon + Royal Knights)
    ("Royal Base", ["Magnamon", "Omnimon", "Alphamon"], 2),
    ("Royal Base", ["Magnamon", "Omekamon", "Gallantmon"], 2),

    # Bloomlordmon / Plant deck (expanded)
    ("Bloomlordmon", ["Lillymon", "Sunflowmon", "Palmon"], 3),
    ("Bloomlordmon", ["Ajatarmon", "Argomon", "Palmon"], 2),

    # Abbadomon
    ("Abbadomon", ["Abbadomon", "Negamon"], 1),

    # DarkKnightmon (if not caught by Bagra)
    ("DarkKnightmon", ["DarkKnightmon", "SkullKnightmon", "DeadlyAxemon"], 2),

    # Three Musketeers
    ("Three Musketeers", ["Beelstarmon", "GrandisKuwagamon", "Minervamon"], 2),

    # Four Great Dragons
    ("Four Great Dragons", ["Azulongmon", "Ebonwumon", "Baihumon", "Zhuqiaomon"], 2),

    # Seven Great Demon Lords
    ("Seven Great Demon Lords", ["Daemon", "Barbamon", "Lilithmon", "Leviamon"], 2),

    # Lilithmon
    ("Lilithmon", ["Lilithmon", "LadyDevimon", "BlackGatomon"], 2),

    # Zephagamon
    ("Zephagamon", ["Zephagamon", "Cyclomon", "Airdramon"], 2),

    # Argomon
    ("Argomon", ["Argomon", "Woodmon", "Mushroomon"], 2),

    # HeavyLeomon
    ("HeavyLeomon", ["HeavyLeomon", "BanchoLeomon", "Leomon"], 2),

    # Rapidmon
    ("Rapidmon", ["Rapidmon", "Gargomon", "Terriermon"], 2),

    # Dinomon
    ("Dinomon", ["Dinorexmon", "Triceramon", "Monochromon"], 2),

    # Red Hybrid (Takuya line)
    ("Red Hybrid", ["EmperorGreymon", "Aldamon", "BurningGreymon"], 2),
    ("Red Hybrid", ["Aldamon", "Agunimon", "Flamemon"], 2),

    # Ariemon
    ("Ariemon", ["Ariemon", "Huankunmon", "Sanzomon"], 2),
    ("Ariemon", ["Ariemon", "Xiangpengmon"], 2),

    # Dynasmon
    ("Dynasmon", ["Dynasmon", "Lordomon"], 1),
    ("Dynasmon", ["Dynasmon (X Antibody)", "Lordomon"], 1),

    # Aquatic / Marine (Sangomon line)
    ("Deep Savers", ["Sangomon", "Shellmon", "MarineBullmon"], 2),
    ("Deep Savers", ["Ryugumon", "Sangomon", "MetalSeadramon"], 2),

    # Blue Hybrid (Koji line)
    ("Blue Hybrid", ["MagnaGarurumon", "KendoGarurumon", "Lobomon"], 2),

    # Wizardmon / Witchmon variants
    ("Nightmare Soldiers", ["Wizardmon", "Candlemon", "Witchmon"], 2),
    ("Nightmare Soldiers", ["Wizardmon (X Antibody)", "Wizardmon", "Candlemon"], 2),
]


def extract_card_names(decklist_json):
    """Extract all card names from a decklist JSON."""
    try:
        decklist = json.loads(decklist_json)
        cards = []
        for category in ['digimon', 'tamer', 'option', 'digi-egg']:
            for card in decklist.get(category, []):
                name = card.get('name', '')
                count = card.get('count', 1)
                # Add card name multiple times based on count for weighted matching
                cards.extend([name] * count)
        return cards
    except:
        return []


def classify_decklist(decklist_json):
    """Classify a decklist based on signature cards. Returns archetype name or None."""
    cards = extract_card_names(decklist_json)
    if not cards:
        return None

    # Create a set of card names for faster lookup (case-insensitive)
    card_set = set(c.lower() for c in cards)
    card_text = ' '.join(cards).lower()

    for archetype_name, required_cards, min_matches in CLASSIFICATION_RULES:
        matches = 0
        for req_card in required_cards:
            # Check if any card contains the required card name (substring match)
            if req_card.lower() in card_text:
                matches += 1

        if matches >= min_matches:
            return archetype_name

    return None


def main():
    parser = argparse.ArgumentParser(description='Auto-classify UNKNOWN decklists')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without applying')
    parser.add_argument('--online-only', action='store_true', default=True, help='Only process online tournaments')
    args = parser.parse_args()

    con = duckdb.connect('data/local.duckdb', read_only=args.dry_run)

    # Get archetype name to ID mapping
    archetypes = con.execute('''
        SELECT archetype_id, archetype_name FROM deck_archetypes
    ''').fetchall()
    archetype_map = {name: id for id, name in archetypes}

    # Get UNKNOWN decklist results
    if args.online_only:
        results = con.execute('''
            SELECT r.result_id, r.decklist_json
            FROM results r
            JOIN tournaments t ON r.tournament_id = t.tournament_id
            JOIN stores s ON t.store_id = s.store_id
            JOIN deck_archetypes d ON r.archetype_id = d.archetype_id
            WHERE s.is_online = TRUE
              AND d.archetype_name = 'UNKNOWN'
              AND r.decklist_json IS NOT NULL
              AND r.decklist_json != ''
        ''').fetchall()
    else:
        results = con.execute('''
            SELECT r.result_id, r.decklist_json
            FROM results r
            JOIN deck_archetypes d ON r.archetype_id = d.archetype_id
            WHERE d.archetype_name = 'UNKNOWN'
              AND r.decklist_json IS NOT NULL
              AND r.decklist_json != ''
        ''').fetchall()

    print(f"Found {len(results)} UNKNOWN results with decklists")
    print()

    # Classify each decklist
    classifications = Counter()
    updates = []

    for result_id, decklist_json in results:
        archetype_name = classify_decklist(decklist_json)
        if archetype_name:
            archetype_id = archetype_map.get(archetype_name)
            if archetype_id:
                classifications[archetype_name] += 1
                updates.append((archetype_id, result_id))
            else:
                print(f"WARNING: Archetype '{archetype_name}' not found in database")

    # Print summary
    print("Classification Results:")
    print("=" * 50)
    for archetype, count in classifications.most_common():
        print(f"  {archetype:<30} {count:>5}")
    print("-" * 50)
    print(f"  {'Total classified':<30} {len(updates):>5}")
    print(f"  {'Remaining UNKNOWN':<30} {len(results) - len(updates):>5}")
    print()

    if args.dry_run:
        print("DRY RUN - No changes applied")
    else:
        # Apply updates
        print(f"Applying {len(updates)} archetype updates...")
        for archetype_id, result_id in updates:
            con.execute(
                "UPDATE results SET archetype_id = ? WHERE result_id = ?",
                [archetype_id, result_id]
            )
        print("Done!")

    con.close()


if __name__ == '__main__':
    main()
