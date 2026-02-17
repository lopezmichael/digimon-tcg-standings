# =============================================================================
# Migration: Add store_schedules table
# Run once: source("scripts/migrate_add_store_schedules.R")
# =============================================================================

cat("
===============================================
Migration: Add store_schedules table
===============================================
\n")

# Load environment variables
if (file.exists(".env")) {
  readRenviron(".env")
}

# Load connection module
source("R/db_connection.R")

# Connect
cat("Connecting to database...\n")
con <- connect_db()

# Check if table already exists
existing_tables <- DBI::dbListTables(con)
if ("store_schedules" %in% existing_tables) {
  cat("Table 'store_schedules' already exists. No migration needed.\n")
  disconnect(con)
  stop("Migration already applied.", call. = FALSE)
}

# Create the table
cat("Creating store_schedules table...\n")

DBI::dbExecute(con, "
CREATE TABLE IF NOT EXISTS store_schedules (
    schedule_id INTEGER PRIMARY KEY,
    store_id INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    frequency VARCHAR DEFAULT 'weekly',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
")

# Create indexes
cat("Creating indexes...\n")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_store_schedules_store ON store_schedules(store_id)")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_store_schedules_day ON store_schedules(day_of_week)")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_store_schedules_active ON store_schedules(is_active)")

# Verify
cat("\nVerifying...\n")
tables <- DBI::dbListTables(con)
if ("store_schedules" %in% tables) {
  cat("  store_schedules table created successfully\n")

  # Show table structure
  cols <- DBI::dbGetQuery(con, "DESCRIBE store_schedules")
  cat("\nTable structure:\n")
  print(cols[, c("column_name", "column_type", "null")])
} else {
  cat("  ERROR: Table not created!\n")
}

# Done
disconnect(con)

cat("
===============================================
Migration complete!
===============================================
\n")
