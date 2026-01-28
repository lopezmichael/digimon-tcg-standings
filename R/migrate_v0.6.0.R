# =============================================================================
# Database Migration v0.6.0
# Adds: formats table for managing game set/format choices
# Run: source("R/migrate_v0.6.0.R"); migrate_v0.6.0(con)
# =============================================================================

#' Migrate database to v0.6.0
#' @param con DBI connection to DuckDB
#' @export
migrate_v0.6.0 <- function(con) {
  cat("Running migration v0.6.0...\n")

  # Create formats table
  tryCatch({
    dbExecute(con, "
      CREATE TABLE IF NOT EXISTS formats (
        format_id VARCHAR PRIMARY KEY,
        set_name VARCHAR NOT NULL,
        display_name VARCHAR NOT NULL,
        release_date DATE,
        sort_order INTEGER,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ")
    cat("  + Created formats table\n")
  }, error = function(e) {
    cat("  x Failed to create formats table:", e$message, "\n")
  })

  # Create indexes
  tryCatch({
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_formats_active ON formats(is_active)")
    dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_formats_sort ON formats(sort_order)")
    cat("  + Created indexes on formats table\n")
  }, error = function(e) {
    cat("  - Indexes may already exist\n")
  })

  # Seed initial format data
  seed_formats(con)

  cat("Migration v0.6.0 complete.\n")
}

#' Seed formats table with initial data
#' @param con DBI connection to DuckDB
seed_formats <- function(con) {
  cat("  Seeding formats data...\n")

  # Check if formats already exist
  existing <- dbGetQuery(con, "SELECT COUNT(*) as n FROM formats")
  if (existing$n > 0) {
    cat("    - Formats table already has data (", existing$n, " records)\n")
    return(invisible(NULL))
  }

  # Format data: format_id, set_name, display_name, release_date, sort_order
  formats <- data.frame(
    format_id = c("BT19", "EX08", "BT18", "EX07", "BT17", "ST19", "BT16", "EX06", "BT15", "older"),
    set_name = c(
      "Xros Encounter",
      "New Awakening",
      "Dimensional Phase",
      "Digimon Liberator",
      "Secret Crisis",
      "Fable Waltz",
      "Beginning Observer",
      "Infernal Ascension",
      "Exceed Apocalypse",
      "Older Format"
    ),
    display_name = c(
      "BT19 (Xros Encounter)",
      "EX08 (New Awakening)",
      "BT18 (Dimensional Phase)",
      "EX07 (Digimon Liberator)",
      "BT17 (Secret Crisis)",
      "ST19/ST20 (Fable Waltz)",
      "BT16 (Beginning Observer)",
      "EX06 (Infernal Ascension)",
      "BT15 (Exceed Apocalypse)",
      "Older Format"
    ),
    release_date = as.Date(c(
      "2025-01-24",  # BT19
      "2024-11-22",  # EX08
      "2024-09-27",  # BT18
      "2024-08-09",  # EX07
      "2024-05-31",  # BT17
      "2024-04-26",  # ST19
      "2024-02-23",  # BT16
      "2024-01-26",  # EX06
      "2023-11-17",  # BT15
      NA            # older
    )),
    sort_order = 1:10,
    is_active = TRUE,
    stringsAsFactors = FALSE
  )

  # Insert formats
  for (i in 1:nrow(formats)) {
    tryCatch({
      dbExecute(con, "
        INSERT INTO formats (format_id, set_name, display_name, release_date, sort_order, is_active)
        VALUES ($1, $2, $3, $4, $5, $6)
      ", params = list(
        formats$format_id[i],
        formats$set_name[i],
        formats$display_name[i],
        formats$release_date[i],
        formats$sort_order[i],
        formats$is_active[i]
      ))
    }, error = function(e) {
      if (!grepl("duplicate|already exists|unique", e$message, ignore.case = TRUE)) {
        cat("    x Failed to insert format", formats$format_id[i], ":", e$message, "\n")
      }
    })
  }

  cat("    + Inserted", nrow(formats), "formats\n")
}
