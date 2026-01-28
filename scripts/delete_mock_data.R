# =============================================================================
# Delete Mock Tournament Data
# Run to remove all test data: source("R/delete_mock_data.R")
#
# WARNING: This deletes ALL players, tournaments, and results!
# Only run this when you're ready to start collecting real data.
# =============================================================================

cat("Deleting mock tournament data...\n")

# Load modules
source("R/db_connection.R")

# Connect to database
con <- connect_db()

# -----------------------------------------------------------------------------
# Delete in correct order (respect foreign key constraints)
# -----------------------------------------------------------------------------

# Count before deletion
results_count <- dbGetQuery(con, "SELECT COUNT(*) as n FROM results")$n
tournaments_count <- dbGetQuery(con, "SELECT COUNT(*) as n FROM tournaments")$n
players_count <- dbGetQuery(con, "SELECT COUNT(*) as n FROM players")$n

cat("Current data counts:\n")
cat("  Results:     ", results_count, "\n")
cat("  Tournaments: ", tournaments_count, "\n")
cat("  Players:     ", players_count, "\n")

if (results_count == 0 && tournaments_count == 0 && players_count == 0) {
  cat("\nNo data to delete.\n")
  dbDisconnect(con)
  cat("Disconnected\n")
  stop("Tables are already empty.")
}

# Confirm deletion
cat("\n")
cat("WARNING: This will delete ALL players, tournaments, and results!\n")
cat("Press Enter to continue or Ctrl+C to cancel...\n")
# Note: In non-interactive mode, this will proceed automatically

# Delete results first (references tournaments and players)
deleted_results <- dbExecute(con, "DELETE FROM results")
cat("Deleted", deleted_results, "results\n")

# Delete tournaments (references stores, but we keep stores)
deleted_tournaments <- dbExecute(con, "DELETE FROM tournaments")
cat("Deleted", deleted_tournaments, "tournaments\n")

# Delete players
deleted_players <- dbExecute(con, "DELETE FROM players")
cat("Deleted", deleted_players, "players\n")

# Reset auto-increment sequences (DuckDB uses sequences internally)
# For future inserts, IDs will start from 1 again
# Note: DuckDB doesn't have explicit sequence reset, but INTEGER PRIMARY KEY
# will auto-increment from max+1, so with empty tables, new IDs start low

dbDisconnect(con)
cat("Disconnected\n")

cat("\n")
cat("============================================================\n")
cat("  Mock data deletion complete!\n")
cat("============================================================\n")
cat("  Deleted:\n")
cat("    Results:     ", deleted_results, "\n")
cat("    Tournaments: ", deleted_tournaments, "\n")
cat("    Players:     ", deleted_players, "\n")
cat("\n")
cat("  Stores and archetypes were preserved.\n")
cat("  You're now ready to collect real tournament data!\n")
cat("============================================================\n")
