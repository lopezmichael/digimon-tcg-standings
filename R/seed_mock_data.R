# =============================================================================
# Seed Mock Tournament Data for Testing
# Run to populate test data: source("R/seed_mock_data.R")
# Delete mock data with: source("R/delete_mock_data.R")
#
# WARNING: This creates fake data for testing charts and UI.
# Delete this data before collecting real tournament results!
# =============================================================================

# Set seed for reproducible random data
set.seed(42)

cat("Seeding mock tournament data for testing...\n")

# Load modules
source("R/db_connection.R")

# Connect to database
con <- connect_db()

# -----------------------------------------------------------------------------
# Check if mock data already exists
# -----------------------------------------------------------------------------

existing_players <- dbGetQuery(con, "SELECT COUNT(*) as n FROM players")$n
if (existing_players > 0) {
  cat("Players table already has", existing_players, "records.\n")
  cat("To re-seed mock data, first run: source('R/delete_mock_data.R')\n")
  dbDisconnect(con)
  cat("Disconnected\n")
  stop("Mock data may already exist. Delete first if you want to re-seed.")
}

# -----------------------------------------------------------------------------
# Mock Players (25 players with varied names)
# -----------------------------------------------------------------------------

cat("Creating mock players...\n")

mock_players <- data.frame(
  player_id = 1:25,
  display_name = c(
    "TamerKai", "DigiDestined_Alex", "WarGreymon_Main", "PurpleHybridPro",
    "BlueFlareKing", "MastemomMike", "JesmonJosh", "GallantKnight99",
    "MetaBreaker", "RookieRusher", "OptionLockSam", "SecurityStacker",
    "MemoryMaster", "TamerTech", "EvoSourcer", "DigiEggHunter",
    "XrosHeartFan", "ImperialdramonIvy", "BeelstarBob", "NumeQueen",
    "DarkMasterDan", "YellowHopeYuki", "GreenNatureMia", "RedRageRex",
    "BlackVirusVic"
  ),
  home_store_id = c(1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11),
  is_active = TRUE,
  stringsAsFactors = FALSE
)

for (i in 1:nrow(mock_players)) {
  dbExecute(con, sprintf(
    "INSERT INTO players (player_id, display_name, home_store_id, is_active) VALUES (%d, '%s', %d, %s)",
    mock_players$player_id[i],
    mock_players$display_name[i],
    mock_players$home_store_id[i],
    "TRUE"
  ))
}

cat("  Created", nrow(mock_players), "mock players\n")

# -----------------------------------------------------------------------------
# Mock Tournaments (20 tournaments over past 4 months, varied formats)
# -----------------------------------------------------------------------------

cat("Creating mock tournaments...\n")

# Available formats
formats <- c("BT19", "BT19", "BT19", "EX08", "EX08", "BT18", "BT17", "EX07")

# Generate dates over the past 4 months
base_date <- Sys.Date()
tournament_dates <- c(
  base_date - 3,    # 3 days ago
  base_date - 7,    # 1 week ago
  base_date - 10,   # ~1.5 weeks ago
  base_date - 14,   # 2 weeks ago
  base_date - 17,   # ~2.5 weeks ago
  base_date - 21,   # 3 weeks ago
  base_date - 25,   # ~3.5 weeks ago
  base_date - 28,   # 4 weeks ago
  base_date - 35,   # 5 weeks ago
  base_date - 42,   # 6 weeks ago
  base_date - 49,   # 7 weeks ago
  base_date - 56,   # 8 weeks ago
  base_date - 63,   # 9 weeks ago
  base_date - 70,   # 10 weeks ago
  base_date - 77,   # 11 weeks ago
  base_date - 84,   # 12 weeks ago
  base_date - 91,   # 13 weeks ago
  base_date - 98,   # 14 weeks ago
  base_date - 105,  # 15 weeks ago
  base_date - 112   # 16 weeks ago
)

# Different stores
stores <- c(1, 2, 4, 1, 6, 8, 1, 3, 5, 11, 1, 7, 2, 4, 9, 1, 3, 6, 10, 12)

# Event types
event_types <- c("locals", "locals", "locals", "locals", "locals",
                 "evo_cup", "locals", "locals", "locals", "locals",
                 "store_championship", "locals", "locals", "locals", "locals",
                 "locals", "evo_cup", "locals", "locals", "locals")

# Player counts (varied)
player_counts <- c(14, 10, 12, 16, 8, 18, 12, 10, 8, 14, 20, 10, 12, 8, 10, 14, 16, 10, 8, 12)

# Rounds
rounds <- c(4, 4, 4, 5, 3, 5, 4, 4, 3, 4, 5, 4, 4, 3, 4, 4, 5, 4, 3, 4)

mock_tournaments <- data.frame(
  tournament_id = 1:20,
  store_id = stores,
  event_date = as.character(tournament_dates),
  event_type = event_types,
  format = sample(formats, 20, replace = TRUE),  # Varied formats
  player_count = player_counts,
  rounds = rounds,
  stringsAsFactors = FALSE
)

# Ensure recent tournaments are BT19, older ones are mixed
mock_tournaments$format[1:5] <- "BT19"  # Most recent 5 are BT19
mock_tournaments$format[6:10] <- sample(c("BT19", "EX08"), 5, replace = TRUE)
mock_tournaments$format[11:15] <- sample(c("EX08", "BT18", "EX07"), 5, replace = TRUE)
mock_tournaments$format[16:20] <- sample(c("BT18", "BT17", "EX07", "older"), 5, replace = TRUE)

for (i in 1:nrow(mock_tournaments)) {
  dbExecute(con, sprintf(
    "INSERT INTO tournaments (tournament_id, store_id, event_date, event_type, format, player_count, rounds)
     VALUES (%d, %d, '%s', '%s', '%s', %d, %d)",
    mock_tournaments$tournament_id[i],
    mock_tournaments$store_id[i],
    mock_tournaments$event_date[i],
    mock_tournaments$event_type[i],
    mock_tournaments$format[i],
    mock_tournaments$player_count[i],
    mock_tournaments$rounds[i]
  ))
}

cat("  Created", nrow(mock_tournaments), "mock tournaments\n")

# -----------------------------------------------------------------------------
# Mock Results (realistic distribution of deck archetypes)
# -----------------------------------------------------------------------------

cat("Creating mock results...\n")

# Get archetype info for better distribution
# Mix of single-color and multi-color decks
# Archetypes with secondary_color should appear in "Multi" category

# Weighted archetype distribution (based on meta relevance)
# Higher IDs are generally less popular rogue decks
top_tier <- c(1, 2, 3, 4, 5)       # Hudiemon, Mastemon, Machinedramon, Royal Knights, Gallantmon
strong_tier <- c(6, 7, 8, 9, 10)   # Beelzemon, Fenriloogamon, Imperialdramon, Blue Flare, MagnaGarurumon
mid_tier <- c(11, 12, 13, 14, 15)  # Jesmon, Leviamon, Bloomlordmon, Xros Heart, Miragegaogamon
rogue_tier <- c(16, 17, 18, 19, 20, 21, 22, 23, 24, 25)  # Various rogue decks

# Weighted distribution favoring meta decks
archetype_weights <- c(
  rep(top_tier, 5),      # Top tier appears most
  rep(strong_tier, 4),   # Strong tier appears often
  rep(mid_tier, 3),      # Mid tier moderately
  rep(rogue_tier, 1)     # Rogue tier occasionally
)

result_id <- 1
results_created <- 0

for (t in 1:nrow(mock_tournaments)) {
  tournament_id <- mock_tournaments$tournament_id[t]
  player_count <- mock_tournaments$player_count[t]
  rounds <- mock_tournaments$rounds[t]

  # Select random players for this tournament (may not be same players each time)
  players_in_tournament <- sample(1:25, min(player_count, 25))

  for (p in seq_along(players_in_tournament)) {
    player_id <- players_in_tournament[p]
    placement <- p  # Placement based on order (1st, 2nd, etc.)

    # Assign archetype - top placements more likely to be meta decks
    if (placement <= 4) {
      # Top 4 is almost always meta
      archetype_id <- sample(c(top_tier, strong_tier), 1, prob = c(rep(3, 5), rep(2, 5)))
    } else if (placement <= player_count / 2) {
      # Middle of pack - mix of meta and off-meta
      archetype_id <- sample(archetype_weights, 1)
    } else {
      # Bottom half - more variety including rogue
      archetype_id <- sample(c(mid_tier, rogue_tier), 1)
    }

    # Generate realistic win/loss based on placement
    total_matches <- rounds
    if (placement == 1) {
      wins <- total_matches
      losses <- 0
    } else if (placement == 2) {
      wins <- total_matches - 1
      losses <- 1
    } else if (placement <= 4) {
      wins <- max(1, total_matches - sample(1:2, 1))
      losses <- total_matches - wins
    } else if (placement <= player_count / 2) {
      wins <- sample(1:(total_matches - 1), 1)
      losses <- total_matches - wins
    } else {
      wins <- sample(0:1, 1)
      losses <- total_matches - wins
    }
    ties <- 0

    dbExecute(con, sprintf(
      "INSERT INTO results (result_id, tournament_id, player_id, archetype_id, placement, wins, losses, ties)
       VALUES (%d, %d, %d, %d, %d, %d, %d, %d)",
      result_id, tournament_id, player_id, archetype_id, placement, wins, losses, ties
    ))

    result_id <- result_id + 1
    results_created <- results_created + 1
  }
}

cat("  Created", results_created, "mock results\n")

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

dbDisconnect(con)
cat("Disconnected\n")

cat("\n")
cat("============================================================\n")
cat("  Mock data seeding complete!\n")
cat("============================================================\n")
cat("  Players:     25\n")
cat("  Tournaments: 20\n")
cat("  Results:    ", results_created, "\n")
cat("\n")
cat("  Formats used: BT19, EX08, BT18, BT17, EX07, older\n")
cat("  Date range: Last 4 months\n")
cat("\n")
cat("  Run the app to test the dashboard charts.\n")
cat("  When ready for real data, run: source('R/delete_mock_data.R')\n")
cat("============================================================\n")
