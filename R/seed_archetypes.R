# =============================================================================
# Seed Deck Archetypes Data
# Run once to populate initial archetype data: source("R/seed_archetypes.R")
#
# Based on BT23/BT24 meta research from:
# - digimonmeta.com
# - digitalgateopen.com
# - egmanevents.com
# =============================================================================

cat("Seeding deck archetype data...\n")

# Load modules
source("R/db_connection.R")
source("R/digimoncard_api.R")

# Connect to database
con <- connect_db()

# -----------------------------------------------------------------------------
# Deck Archetypes
# Last updated: January 2026 (BT23/BT24 meta)
#
# Colors: Red, Blue, Yellow, Green, Purple, Black, White
# Playstyles: aggro, control, combo, midrange, otk, tempo
# -----------------------------------------------------------------------------

archetypes <- data.frame(
  archetype_id = 1:25,
  archetype_name = c(
    # Top tier BT23 meta
    "Hudiemon",
    "Mastemon",
    "Machinedramon",
    "Royal Knights",
    "Gallantmon",

    # Strong meta contenders
    "Beelzemon",
    "Fenriloogamon",
    "Imperialdramon",
    "Blue Flare",
    "MagnaGarurumon",

    # Established archetypes
    "Jesmon",
    "Leviamon",
    "Bloomlordmon",
    "Xros Heart",
    "Miragegaogamon",

    # Other competitive decks
    "Belphemon",
    "Sakuyamon",
    "Numemon",
    "Chronicle",
    "Omnimon",

    # Rogue/emerging
    "Dark Animals",
    "Dark Masters",
    "Eater",
    "Blue Hybrid",
    "Purple Hybrid"
  ),
  display_card_id = c(
    # Top tier
    "BT23-101",   # Hudiemon
    "BT23-102",   # Mastemon
    "EX9-073",    # Machinedramon
    "BT13-007",   # King Drasil_7D6 (Royal Knights)
    "EX8-073",    # Gallantmon X Antibody

    # Strong contenders
    "EX10-074",   # Beelzemon
    "BT17-101",   # Fenriloogamon: Takemikazuchi
    "BT16-028",   # Imperialdramon: Dragon Mode
    "BT10-030",   # MetalGreymon (Blue Flare)
    "P-153",      # MagnaGarurumon

    # Established
    "BT23-013",   # Jesmon (aggro variant)
    "EX5-063",    # Leviamon
    "BT10-057",   # Bloomlordmon
    "BT19-014",   # Shoutmon EX6 (Xros Heart)
    "BT13-033",   # Miragegaogamon BM

    # Other competitive
    "EX10-022",   # Belphemon: Rage Mode
    "EX8-037",    # Sakuyamon X Antibody
    "BT22-031",   # GoldNumemon
    "BT20-060",   # Alphamon: Ouryuken ACE (Chronicle)
    "BT22-015",   # Omnimon

    # Rogue/emerging
    "EX5-061",    # Cerberusmon X Antibody (Dark Animals)
    "EX10-061",   # Apocalymon (Dark Masters)
    "BT22-079",   # Eater
    "BT17-028",   # Blue Hybrid
    "BT18-078"    # Purple Hybrid
  ),
  primary_color = c(
    # Top tier
    "Green",      # Hudiemon
    "Yellow",     # Mastemon
    "Black",      # Machinedramon
    "Yellow",     # Royal Knights
    "Red",        # Gallantmon

    # Strong contenders
    "Purple",     # Beelzemon
    "Black",      # Fenriloogamon
    "Blue",       # Imperialdramon
    "Blue",       # Blue Flare
    "Blue",       # MagnaGarurumon

    # Established
    "Red",        # Jesmon
    "Purple",     # Leviamon
    "Green",      # Bloomlordmon
    "Red",        # Xros Heart
    "Blue",       # Miragegaogamon

    # Other competitive
    "Purple",     # Belphemon
    "Yellow",     # Sakuyamon
    "Yellow",     # Numemon
    "Black",      # Chronicle (Alphamon)
    "White",      # Omnimon

    # Rogue/emerging
    "Purple",     # Dark Animals (Cerberusmon)
    "Purple",     # Dark Masters
    "Purple",     # Eater
    "Blue",       # Blue Hybrid
    "Purple"      # Purple Hybrid
  ),
  secondary_color = c(
    # Top tier
    NA,           # Hudiemon
    "Purple",     # Mastemon
    NA,           # Machinedramon
    NA,           # Royal Knights
    NA,           # Gallantmon

    # Strong contenders
    NA,           # Beelzemon
    NA,           # Fenriloogamon
    "Green",      # Imperialdramon
    NA,           # Blue Flare
    NA,           # MagnaGarurumon

    # Established
    "Yellow",     # Jesmon
    NA,           # Leviamon
    NA,           # Bloomlordmon
    NA,           # Xros Heart
    NA,           # Miragegaogamon

    # Other competitive
    NA,           # Belphemon
    NA,           # Sakuyamon
    NA,           # Numemon
    NA,           # Alphamon
    NA,           # Omnimon

    # Rogue/emerging
    NA,           # Cerberusmon
    NA,           # Dark Masters
    NA,           # Eater
    NA,           # Blue Hybrid
    NA            # Purple Hybrid
  ),
  playstyle_tags = c(
    # Top tier
    '["combo", "control"]',        # Hudiemon
    '["control", "combo"]',        # Mastemon
    '["control", "midrange"]',     # Machinedramon
    '["midrange", "toolbox"]',     # Royal Knights
    '["aggro", "tempo"]',          # Gallantmon

    # Strong contenders
    '["aggro", "otk"]',            # Beelzemon
    '["combo", "aggro"]',          # Fenriloogamon
    '["combo", "otk"]',            # Imperialdramon
    '["midrange", "swarm"]',       # Blue Flare
    '["aggro", "otk"]',            # MagnaGarurumon

    # Established
    '["combo", "midrange"]',       # Jesmon
    '["control"]',                 # Leviamon
    '["midrange"]',                # Bloomlordmon
    '["aggro", "swarm"]',          # Xros Heart
    '["midrange"]',                # Miragegaogamon

    # Other competitive
    '["control", "combo"]',        # Belphemon
    '["control", "combo"]',        # Sakuyamon
    '["control", "stall"]',        # Numemon
    '["combo", "control"]',        # Alphamon
    '["midrange", "otk"]',         # Omnimon

    # Rogue/emerging
    '["aggro", "combo"]',          # Cerberusmon
    '["control", "combo"]',        # Dark Masters
    '["control", "combo"]',        # Eater
    '["aggro", "otk"]',            # Blue Hybrid
    '["aggro", "otk"]'             # Purple Hybrid
  ),
  is_active = rep(TRUE, 25),
  notes = c(
    # Top tier
    "BT23 meta dominant. CS/Hudie trait synergy.",
    "DNA digivolve deck. Yellow/Purple hybrid.",
    "Zaxon trait. De-Digivolve control.",
    "Multi-color toolbox deck.",
    "Red aggro with Crimson Mode finisher.",

    # Strong contenders
    "ACE mechanic. Fast aggro/OTK.",
    "Eiji Nagasumi synergy. Restricted to 1 copy.",
    "Blue/Green DNA. Jamming OTK.",
    "MetalGreymon engine. DigiXros.",
    "Blue aggro OTK.",

    # Established
    "Sistermon engine. Red/Yellow.",
    "Purple control. Trash manipulation.",
    "Green midrange. Plant types.",
    "Red aggro swarm. DigiXros.",
    "Blue midrange. Burst mode.",

    # Other competitive
    "Sleep mode to rage mode.",
    "Yellow control/combo. X-Antibody.",
    "Yellow stall/control. GoldNumemon.",
    "Alphamon: Ouryuken ACE. X-Antibody.",
    "Classic finisher deck.",

    # Rogue/emerging
    "Cerberusmon X-Antibody aggro.",
    "Apocalymon/Dark Masters control.",
    "BT22/23 Eater cards.",
    "Blue Hybrid/Susanoomon.",
    "Purple Hybrid/Susanoomon."
  ),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------------------------
# Insert data
# -----------------------------------------------------------------------------

# Check if archetypes table has data already
existing <- dbGetQuery(con, "SELECT COUNT(*) as n FROM deck_archetypes")$n

if (existing > 0) {
  cat("Archetypes table already has", existing, "records.\n")
  cat("To re-seed, first run: DELETE FROM deck_archetypes;\n")
} else {
  # Insert archetypes
  for (i in 1:nrow(archetypes)) {
    sql <- "INSERT INTO deck_archetypes
            (archetype_id, archetype_name, display_card_id, primary_color,
             secondary_color, playstyle_tags, is_active, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)"

    dbExecute(con, sql, params = list(
      archetypes$archetype_id[i],
      archetypes$archetype_name[i],
      archetypes$display_card_id[i],
      archetypes$primary_color[i],
      archetypes$secondary_color[i],
      archetypes$playstyle_tags[i],
      archetypes$is_active[i],
      archetypes$notes[i]
    ))
  }

  cat("Inserted", nrow(archetypes), "archetypes.\n")
}

# -----------------------------------------------------------------------------
# Verify and show card images
# -----------------------------------------------------------------------------

cat("\nArchetypes in database:\n")
result <- dbGetQuery(con,
  "SELECT archetype_id, archetype_name, display_card_id, primary_color
   FROM deck_archetypes ORDER BY archetype_id")
print(result)

# Show image URLs for verification
cat("\nSample image URLs (verify these work):\n")
for (i in 1:min(5, nrow(result))) {
  cat(result$archetype_name[i], ":", get_card_image_url(result$display_card_id[i]), "\n")
}

# Cleanup
disconnect(con)

cat("\nArchetype seeding complete!\n")
cat("You can add more archetypes or modify via direct SQL or by editing this script.\n")
