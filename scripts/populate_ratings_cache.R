# =============================================================================
# Populate Ratings Cache
#
# Run this script to populate the ratings cache.
# The cache tables will be empty after a fresh sync since they contain computed
# data, not source data.
#
# Usage:
#   Rscript scripts/populate_ratings_cache.R
#
# Or from R console:
#   source("scripts/populate_ratings_cache.R")
# =============================================================================

# Load required packages
library(DBI)
library(pool)
library(RPostgres)

# Load environment variables
if (file.exists(".env")) {
  readRenviron(".env")
}

# Load database connection and ratings modules
source("R/db_connection.R")
source("R/ratings.R")

# Connect to database
message("Connecting to database...")
db_pool <- create_db_pool()

# Check current cache status
player_count <- dbGetQuery(db_pool, "SELECT COUNT(*) as n FROM player_ratings_cache")$n
store_count <- dbGetQuery(db_pool, "SELECT COUNT(*) as n FROM store_ratings_cache")$n

message(sprintf("Current cache status: %d players, %d stores", player_count, store_count))

# Populate cache
message("Recalculating ratings cache...")
start_time <- Sys.time()

success <- recalculate_ratings_cache(db_pool)

end_time <- Sys.time()
elapsed <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)

if (success) {
  # Verify
  player_count <- dbGetQuery(db_pool, "SELECT COUNT(*) as n FROM player_ratings_cache")$n
  store_count <- dbGetQuery(db_pool, "SELECT COUNT(*) as n FROM store_ratings_cache")$n

  message(sprintf("Cache populated in %.2f seconds", elapsed))
  message(sprintf("Final cache status: %d players, %d stores", player_count, store_count))
} else {
  message("Cache population failed!")
}

# Close pool
close_db_pool(db_pool)
message("Done.")
