# Seed test deck requests for approval queue testing
# Run this script to add fake pending deck requests to the local database

library(DBI)
library(pool)
library(RPostgres)

# Load environment variables
if (file.exists(".env")) {
  readRenviron(".env")
}

source("R/db_connection.R")
db_pool <- create_db_pool()

# Check current pending requests
current <- dbGetQuery(db_pool, "SELECT * FROM deck_requests WHERE status = 'pending'")
cat("Current pending requests:", nrow(current), "\n")

# Insert fake deck requests for testing (auto-increment IDs)
dbExecute(db_pool, "
INSERT INTO deck_requests (deck_name, primary_color, secondary_color, display_card_id, status)
VALUES
  ('Mastemon', 'Purple', 'Yellow', 'BT6-112', 'pending'),
  ('Blue Flare', 'Blue', NULL, 'BT10-030', 'pending'),
  ('Gallantmon X', 'Red', NULL, 'BT9-017', 'pending')
")

# Verify the inserts
result <- dbGetQuery(db_pool, "SELECT * FROM deck_requests WHERE status = 'pending'")
cat("\nPending deck requests after insert:\n")
print(result)

close_db_pool(db_pool)

dbDisconnect(con)
cat("\nDone! You should now see 3 pending deck requests in the admin queue.\n")
