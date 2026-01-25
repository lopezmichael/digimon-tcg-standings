# =============================================================================
# Seed DFW Stores Data
# Run once to populate initial store data: source("R/seed_stores.R")
# =============================================================================

cat("Seeding DFW store data...\n")

# Load connection module
source("R/db_connection.R")

# Connect to database
con <- connect_db()

# -----------------------------------------------------------------------------
# DFW Digimon TCG Stores
# Last updated: January 2026
# -----------------------------------------------------------------------------

stores <- data.frame(
  store_id = 1:13,
  name = c(
    "Common Ground Games",
    "Cloud Collectibles",
    "The Card Haven",
    "Game Nerdz Mesquite",
    "Andyseous Odyssey",
    "Boardwalk Games",
    "Lone Star Pack Breaks",
    "Game Nerdz Allen",
    "Game Nerdz Wylie",
    "Eclipse Cards and Hobby",
    "Evolution Games",
    "Primal Cards & Collectables",
    "Tony's DTX Cards"
  ),
  address = c(
    "1314 Inwood Rd",
    "6313 N President George Bush Hwy",
    "500 E Round Grove Rd, Ste 129",
    "1425 Gross Rd, Suite 102",
    "2910 S Beckley Ave, Suite 175",
    "2810 E Trinity Mills Rd, Ste 184",
    "3733 N Josey Ln, Suite 108",
    "190 E Stacy Rd, Suite 1334",
    "803 Woodbridge Pkwy, Suite 1100",
    "9155 Blvd 26, Ste 280",
    "3132 SE Loop 820",
    "3401 Altamesa Blvd, Ste 122",
    "8443 Lake June Rd, Suite 106"
  ),
  city = c(
    "Dallas",
    "Garland",
    "Lewisville",
    "Mesquite",
    "Dallas",
    "Carrollton",
    "Carrollton",
    "Allen",
    "Wylie",
    "North Richland Hills",
    "Fort Worth",
    "Fort Worth",
    "Dallas"
  ),
  state = rep("TX", 13),
  zip_code = c(
    "75247",
    "75044",
    "75067",
    "75149",
    "75216",
    "75006",
    "75007",
    "75002",
    "75098",
    "76180",
    "76140",
    "76133",
    "75217"
  ),
  # Coordinates (approximate - can be updated with exact geocoding later)
  latitude = c(
    32.8070,   # Common Ground Games
    32.9157,   # Cloud Collectibles
    33.0198,   # The Card Haven
    32.7668,   # Game Nerdz Mesquite
    32.7073,   # Andyseous Odyssey
    32.9743,   # Boardwalk Games
    32.9878,   # Lone Star Pack Breaks
    33.1290,   # Game Nerdz Allen
    33.0151,   # Game Nerdz Wylie
    32.8550,   # Eclipse Cards and Hobby
    32.6520,   # Evolution Games
    32.6730,   # Primal Cards & Collectables
    32.7010    # Tony's DTX Cards
  ),
  longitude = c(
    -96.8575,  # Common Ground Games
    -96.6370,  # Cloud Collectibles
    -96.9942,  # The Card Haven
    -96.5992,  # Game Nerdz Mesquite
    -96.8540,  # Andyseous Odyssey
    -96.8390,  # Boardwalk Games
    -96.8903,  # Lone Star Pack Breaks
    -96.6727,  # Game Nerdz Allen
    -96.5388,  # Game Nerdz Wylie
    -97.2280,  # Eclipse Cards and Hobby
    -97.2680,  # Evolution Games
    -97.3730,  # Primal Cards & Collectables
    -96.6690   # Tony's DTX Cards
  ),
  # Schedule info as JSON string (Digimon TCG event days)
  schedule_info = c(
    '{"digimon_days": ["Friday", "Saturday"], "friday_time": "7:15 PM", "saturday_time": "3:00 PM", "entry_fee": "$8"}',
    '{"digimon_days": ["Friday"]}',
    '{"digimon_days": ["Wednesday"], "notes": "May be moving to Mondays"}',
    '{"digimon_days": ["Sunday"]}',
    '{"digimon_days": ["Wednesday"]}',
    '{"digimon_days": ["Thursday"]}',
    '{"digimon_days": ["Tuesday"]}',
    '{"digimon_days": ["Sunday"]}',
    '{"digimon_days": ["Monday"]}',
    '{"digimon_days": ["Monday"]}',
    '{"digimon_days": ["Tuesday"]}',
    '{"digimon_days": ["Friday"]}',
    '{"digimon_days": ["Wednesday"]}'
  ),
  tcgplus_store_id = rep(NA_character_, 13),
  website = c(
    "https://www.boardgamesdallas.com/",
    "https://cloudcollectibles.my.canva.site/",
    "https://www.cardhavenonline.com/",
    "https://www.gamenerdz.com/",
    "https://www.andyseous-odyssey.com/",
    "https://boardwalk-games.com/",
    "https://www.lonestarpackbreaks.com/",
    "https://www.gamenerdz.com/",
    "https://www.gamenerdz.com/",
    "https://eclipsecardsandhobby.com/",
    "https://evolutiontcg.com/",
    "https://primalcards.net/",
    NA_character_
  ),
  phone = c(
    "214-631-4263",
    NA_character_,
    "214-222-5957",
    "972-288-4200",
    "469-493-7156",
    "972-810-0182",
    NA_character_,
    "972-573-3006",
    "972-429-7375",
    "817-576-4030",
    "817-585-1399",
    NA_character_,
    NA_character_
  ),
  is_active = rep(TRUE, 13),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------------------------
# Insert data
# -----------------------------------------------------------------------------

# Check if stores table has data already
existing <- dbGetQuery(con, "SELECT COUNT(*) as n FROM stores")$n

if (existing > 0) {
  cat("Stores table already has", existing, "records.\n")
  cat("To re-seed, first run: DELETE FROM stores;\n")
} else {
  # Insert stores
  for (i in 1:nrow(stores)) {
    sql <- "INSERT INTO stores (store_id, name, address, city, state, zip_code,
            latitude, longitude, schedule_info, tcgplus_store_id, website, phone, is_active)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

    dbExecute(con, sql, params = list(
      stores$store_id[i],
      stores$name[i],
      stores$address[i],
      stores$city[i],
      stores$state[i],
      stores$zip_code[i],
      stores$latitude[i],
      stores$longitude[i],
      stores$schedule_info[i],
      stores$tcgplus_store_id[i],
      stores$website[i],
      stores$phone[i],
      stores$is_active[i]
    ))
  }

  cat("Inserted", nrow(stores), "stores.\n")
}

# -----------------------------------------------------------------------------
# Verify
# -----------------------------------------------------------------------------

cat("\nStores in database:\n")
result <- dbGetQuery(con, "SELECT store_id, name, city, schedule_info FROM stores ORDER BY store_id")
print(result)

# Cleanup
disconnect(con)

cat("\nStore seeding complete!\n")
