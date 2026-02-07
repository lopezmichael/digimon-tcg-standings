# Seed test deck requests for approval queue testing
# Run this script to add fake pending deck requests to the local database

library(DBI)
library(duckdb)

# Connect to local database
con <- dbConnect(duckdb::duckdb(), "data/local.duckdb")

# Check current pending requests
current <- dbGetQuery(con, "SELECT * FROM deck_requests WHERE status = 'pending'")
cat("Current pending requests:", nrow(current), "\n")

# Get the next available request_id
max_id <- dbGetQuery(con, "SELECT COALESCE(MAX(request_id), 0) as max_id FROM deck_requests")$max_id

# Insert fake deck requests for testing with explicit IDs
dbExecute(con, sprintf("
INSERT INTO deck_requests (request_id, deck_name, primary_color, secondary_color, display_card_id, status)
VALUES
  (%d, 'Mastemon', 'Purple', 'Yellow', 'BT6-112', 'pending'),
  (%d, 'Blue Flare', 'Blue', NULL, 'BT10-030', 'pending'),
  (%d, 'Gallantmon X', 'Red', NULL, 'BT9-017', 'pending')
", max_id + 1, max_id + 2, max_id + 3))

# Verify the inserts
result <- dbGetQuery(con, "SELECT * FROM deck_requests WHERE status = 'pending'")
cat("\nPending deck requests after insert:\n")
print(result)

dbDisconnect(con)
cat("\nDone! You should now see 3 pending deck requests in the admin queue.\n")
