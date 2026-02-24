# =============================================================================
# Database Initialization Script
# Run once to create tables: source("R/init_database.R")
# =============================================================================

cat("
╔═══════════════════════════════════════════════════════════╗
║     DigiLab - Digimon TCG Tournament Tracker              ║
║     Database Initialization                               ║
╚═══════════════════════════════════════════════════════════╝
\n")

# Load environment variables
if (file.exists(".env")) {
  readRenviron(".env")
}

# Check packages
required <- c("DBI", "pool", "RPostgres")
missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]
if (length(missing) > 0) {
  install.packages(missing)
}

# Load connection module
source("R/db_connection.R")

# Connect to Neon PostgreSQL
cat("Connecting to database...\n")
db_pool <- create_db_pool()

# Initialize schema
cat("Creating tables...\n")
init_schema(db_pool)

# Verify
cat("\nVerifying schema...\n")
check_schema(db_pool)

# Done
close_db_pool(db_pool)

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
