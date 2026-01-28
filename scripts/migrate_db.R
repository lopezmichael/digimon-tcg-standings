# =============================================================================
# Database Migration Script
# Run to apply schema updates: source("R/migrate_db.R")
# =============================================================================

cat("Running database migrations...\n")

# Load modules
source("R/db_connection.R")

# Connect to database
con <- connect_db()

# -----------------------------------------------------------------------------
# Migration 1: Add decklist_url column to results table
# -----------------------------------------------------------------------------

cat("Checking for decklist_url column...\n")

# Check if column exists
columns <- dbGetQuery(con, "SELECT column_name FROM information_schema.columns WHERE table_name = 'results'")

if (!"decklist_url" %in% columns$column_name) {
  cat("  Adding decklist_url column to results table...\n")
  dbExecute(con, "ALTER TABLE results ADD COLUMN decklist_url VARCHAR")
  cat("  Done!\n")
} else {
  cat("  decklist_url column already exists.\n")
}

# -----------------------------------------------------------------------------
# Migration 2: Add format column to tournaments table
# -----------------------------------------------------------------------------

cat("Checking for format column in tournaments...\n")

columns <- dbGetQuery(con, "SELECT column_name FROM information_schema.columns WHERE table_name = 'tournaments'")

if (!"format" %in% columns$column_name) {
  cat("  Adding format column to tournaments table...\n")
  dbExecute(con, "ALTER TABLE tournaments ADD COLUMN format VARCHAR DEFAULT 'Standard'")
  cat("  Done!\n")
} else {
  cat("  format column already exists.\n")
}

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

dbDisconnect(con)
cat("Disconnected\n")

cat("\n")
cat("============================================================\n")
cat("  Database migrations complete!\n")
cat("============================================================\n")
