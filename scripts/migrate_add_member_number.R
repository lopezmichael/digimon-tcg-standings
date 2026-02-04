# Migration: Add member_number column to players table
# Run once on existing database
# Usage: Rscript scripts/migrate_add_member_number.R
#
# Note: DuckDB ALTER TABLE doesn't support adding columns with constraints,
# so UNIQUE is not enforced at DB level. Uniqueness handled in application code.

library(DBI)
source("R/db_connection.R")

con <- connect_db()

# Check if column exists
cols <- dbGetQuery(con, "PRAGMA table_info(players)")
if (!"member_number" %in% cols$name) {
  dbExecute(con, "ALTER TABLE players ADD COLUMN member_number VARCHAR")
  message("Added member_number column to players table")
} else {
  message("member_number column already exists")
}

dbDisconnect(con)
