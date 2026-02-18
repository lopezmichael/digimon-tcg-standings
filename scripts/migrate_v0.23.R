# Migration script for v0.23
# Adds rating_snapshots table for historical format-era ratings

migrate_v0.23 <- function(con) {
  message("Running v0.23 migration...")

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS rating_snapshots (
      player_id INTEGER NOT NULL,
      format_id VARCHAR NOT NULL,
      competitive_rating INTEGER NOT NULL DEFAULT 1500,
      achievement_score INTEGER NOT NULL DEFAULT 0,
      events_played INTEGER NOT NULL DEFAULT 0,
      player_rank INTEGER,
      snapshot_date DATE NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (player_id, format_id)
    )
  ")

  DBI::dbExecute(con, "
    CREATE INDEX IF NOT EXISTS idx_rating_snapshots_format ON rating_snapshots(format_id)
  ")

  message("v0.23 migration complete: rating_snapshots table created")
}
