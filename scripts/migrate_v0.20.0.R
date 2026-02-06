# Migration: v0.20.0 Schema Changes
# Adds: deck_requests table, pending_deck_request_id column to results
#
# Usage: Rscript scripts/migrate_v0.20.0.R
#
# Run this AFTER sync_from_motherduck.py to apply changes locally,
# then run sync_to_motherduck.py to push changes to cloud.

library(DBI)
source("R/db_connection.R")

con <- connect_db()

message("Running v0.20.0 migration...")

# 1. Create deck_requests table if it doesn't exist
tryCatch({
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS deck_requests (
      request_id INTEGER PRIMARY KEY,
      deck_name TEXT NOT NULL,
      primary_color TEXT NOT NULL,
      secondary_color TEXT,
      display_card_id TEXT,
      status TEXT DEFAULT 'pending',
      approved_archetype_id INTEGER,
      submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      reviewed_at TIMESTAMP
    )
  ")
  message("  [OK] deck_requests table created/verified")
}, error = function(e) {

message("  [ERROR] deck_requests table: ", e$message)
})

# 2. Create index on deck_requests.status
tryCatch({
  dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_deck_requests_status ON deck_requests(status)")
  message("  [OK] idx_deck_requests_status index created/verified")
}, error = function(e) {
  message("  [WARN] idx_deck_requests_status: ", e$message)
})

# 3. Add pending_deck_request_id column to results table
cols <- dbGetQuery(con, "PRAGMA table_info(results)")
if (!"pending_deck_request_id" %in% cols$name) {
  tryCatch({
    dbExecute(con, "ALTER TABLE results ADD COLUMN pending_deck_request_id INTEGER")
    message("  [OK] Added pending_deck_request_id column to results table")
  }, error = function(e) {
    message("  [ERROR] pending_deck_request_id column: ", e$message)
  })
} else {
  message("  [OK] pending_deck_request_id column already exists")
}

# 4. Create index on results.pending_deck_request_id
tryCatch({
  dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_results_pending_deck ON results(pending_deck_request_id)")
  message("  [OK] idx_results_pending_deck index created/verified")
}, error = function(e) {
  message("  [WARN] idx_results_pending_deck: ", e$message)
})

# 5. Create matches table if it doesn't exist (in case it's missing)
tryCatch({
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS matches (
      match_id INTEGER PRIMARY KEY,
      tournament_id INTEGER NOT NULL,
      round_number INTEGER NOT NULL,
      player_id INTEGER NOT NULL,
      opponent_id INTEGER NOT NULL,
      games_won INTEGER NOT NULL DEFAULT 0,
      games_lost INTEGER NOT NULL DEFAULT 0,
      games_tied INTEGER NOT NULL DEFAULT 0,
      match_points INTEGER NOT NULL DEFAULT 0,
      submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(tournament_id, round_number, player_id)
    )
  ")
  message("  [OK] matches table created/verified")
}, error = function(e) {
  message("  [WARN] matches table: ", e$message)
})

# 6. Add member_number column to players if missing
cols <- dbGetQuery(con, "PRAGMA table_info(players)")
if (!"member_number" %in% cols$name) {
  tryCatch({
    dbExecute(con, "ALTER TABLE players ADD COLUMN member_number VARCHAR")
    message("  [OK] Added member_number column to players table")
  }, error = function(e) {
    message("  [ERROR] member_number column: ", e$message)
  })
} else {
  message("  [OK] member_number column already exists")
}

dbDisconnect(con)
message("\nv0.20.0 migration complete!")
