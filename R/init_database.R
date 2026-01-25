# =============================================================================
# Database Initialization Script
# Run once to create tables: source("R/init_database.R")
# =============================================================================

cat("
╔═══════════════════════════════════════════════════════════╗
║     DFW Digimon TCG Tournament Tracker                    ║
║     Database Initialization                               ║
╚═══════════════════════════════════════════════════════════╝
\n")

# Load environment variables
if (file.exists(".env")) {
  readRenviron(".env")
}

# Check packages
required <- c("DBI", "duckdb")
missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  install.packages(missing)
}

# Load connection module
source("R/db_connection.R")

# Connect (auto-detects local vs cloud)
cat("Connecting to database...\n")
con <- connect_db()

# Initialize schema
cat("Creating tables...\n")
init_schema(con, "db/schema.sql")

# Verify
cat("\nVerifying schema...\n")
check_schema(con)

# Done
disconnect(con)

cat("
╔═══════════════════════════════════════════════════════════╗
║     Setup complete!                                       ║
╠═══════════════════════════════════════════════════════════╣
║  Next steps:                                              ║
║    1. source('R/seed_stores.R')      - Add DFW stores     ║
║    2. source('R/seed_archetypes.R')  - Add deck types     ║
║    3. shiny::runApp()                - Launch app         ║
╚═══════════════════════════════════════════════════════════╝
\n")
