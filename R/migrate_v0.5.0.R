# =============================================================================
# Database Migration v0.5.0
# Adds: is_online to stores, is_multi_color to deck_archetypes
# Run: source("R/migrate_v0.5.0.R"); migrate_v0.5.0(con)
# =============================================================================

#' Migrate database to v0.5.0
#' @param con DBI connection to DuckDB
#' @export
migrate_v0.5.0 <- function(con) {
  cat("Running migration v0.5.0...\n")

  # Add is_online to stores
  tryCatch({
    dbExecute(con, "ALTER TABLE stores ADD COLUMN is_online BOOLEAN DEFAULT FALSE")
    cat("  ✓ Added is_online column to stores\n")
  }, error = function(e) {
    if (grepl("already exists|duplicate|already has", e$message, ignore.case = TRUE)) {
      cat("  - is_online column already exists\n")
    } else {
      stop(e)
    }
  })

  # Add is_multi_color to deck_archetypes
  tryCatch({
    dbExecute(con, "ALTER TABLE deck_archetypes ADD COLUMN is_multi_color BOOLEAN DEFAULT FALSE")
    cat("  ✓ Added is_multi_color column to deck_archetypes\n")
  }, error = function(e) {
    if (grepl("already exists|duplicate|already has", e$message, ignore.case = TRUE)) {
      cat("  - is_multi_color column already exists\n")
    } else {
      stop(e)
    }
  })

  # Update store_activity view
  tryCatch({
    dbExecute(con, "
      CREATE OR REPLACE VIEW store_activity AS
      SELECT
          s.store_id,
          s.name AS store_name,
          s.city,
          s.latitude,
          s.longitude,
          s.address,
          s.is_online,
          COUNT(DISTINCT t.tournament_id) AS total_tournaments,
          COUNT(DISTINCT r.player_id) AS unique_players,
          SUM(t.player_count) AS total_attendance,
          ROUND(AVG(t.player_count), 1) AS avg_attendance,
          MAX(t.event_date) AS last_event_date,
          MIN(t.event_date) AS first_event_date
      FROM stores s
      LEFT JOIN tournaments t ON s.store_id = t.store_id
      LEFT JOIN results r ON t.tournament_id = r.tournament_id
      WHERE s.is_active = TRUE
      GROUP BY s.store_id, s.name, s.city, s.latitude, s.longitude, s.address, s.is_online
    ")
    cat("  ✓ Updated store_activity view\n")
  }, error = function(e) {
    cat("  ✗ Failed to update store_activity view:", e$message, "\n")
  })

  cat("Migration v0.5.0 complete.\n")
}
