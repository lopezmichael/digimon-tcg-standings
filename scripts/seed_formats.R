# =============================================================================
# Seed Formats Data
# Run once to populate initial format data: source("scripts/seed_formats.R")
# =============================================================================

cat("Seeding format data...\n")

# Load connection module
source("R/db_connection.R")

# Connect to database
con <- connect_db()

# -----------------------------------------------------------------------------
# Game Formats (Sets)
# Last updated: January 2026
# -----------------------------------------------------------------------------

formats <- data.frame(
  format_id = c(
    "BT19", "EX08", "BT18", "EX07", "BT17",
    "BT16", "EX06", "BT15", "EX05", "BT14",
    "BT13", "EX04", "BT12", "EX03", "BT11",
    "BT10", "EX02", "BT09", "EX01", "BT08",
    "BT07", "BT06", "BT05", "BT04", "BT03",
    "BT02", "BT01"
  ),
  set_name = c(
    "Xros Encounter", "Infernal Ascension", "Beginning Observer",
    "Cyber Legacy", "Secret Crisis",
    "Versus Galaxy", "Guardians of the Future", "Exceed Apocalypse",
    "Animal Colosseum", "Blast Ace",
    "Supreme Virtue", "Alternative Being", "Across Time",
    "Draconic Roar", "Dimension Phase",
    "Xros Heart", "Digital Hazard", "X Record",
    "Classic Collection", "New Awakening",
    "Next Adventure", "Double Diamond", "Battle of Omega",
    "Great Legend", "Union Impact",
    "Ultimate Power", "Release Special"
  ),
  display_name = c(
    "BT19 (Xros Encounter)", "EX08 (Infernal Ascension)", "BT18 (Beginning Observer)",
    "EX07 (Cyber Legacy)", "BT17 (Secret Crisis)",
    "BT16 (Versus Galaxy)", "EX06 (Guardians)", "BT15 (Exceed Apocalypse)",
    "EX05 (Animal Colosseum)", "BT14 (Blast Ace)",
    "BT13 (Supreme Virtue)", "EX04 (Alternative Being)", "BT12 (Across Time)",
    "EX03 (Draconic Roar)", "BT11 (Dimension Phase)",
    "BT10 (Xros Heart)", "EX02 (Digital Hazard)", "BT09 (X Record)",
    "EX01 (Classic Collection)", "BT08 (New Awakening)",
    "BT07 (Next Adventure)", "BT06 (Double Diamond)", "BT05 (Battle of Omega)",
    "BT04 (Great Legend)", "BT03 (Union Impact)",
    "BT02 (Ultimate Power)", "BT01 (Release Special)"
  ),
  release_date = as.Date(c(
    "2025-09-13", "2025-07-25", "2025-05-23",
    "2025-03-28", "2025-01-24",
    "2024-11-15", "2024-09-27", "2024-07-26",
    "2024-05-31", "2024-03-29",
    "2024-01-26", "2023-11-17", "2023-09-29",
    "2023-07-28", "2023-05-26",
    "2023-03-31", "2023-02-24", "2023-01-27",
    "2022-10-28", "2022-09-30",
    "2022-07-29", "2022-05-27", "2022-03-04",
    "2022-01-14", "2021-10-08",
    "2021-06-11", "2021-01-29"
  )),
  sort_order = 1:27,  # Lower = newer
  is_active = c(
    rep(TRUE, 10),   # Recent formats active
    rep(FALSE, 17)   # Older formats inactive in dropdowns
  ),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------------------------
# Insert data
# -----------------------------------------------------------------------------

# Check if formats table has data already
existing <- dbGetQuery(con, "SELECT COUNT(*) as n FROM formats")$n

if (existing > 0) {
  cat("Formats table already has", existing, "records.\n")
  cat("To re-seed, first run: DELETE FROM formats;\n")
} else {
  # Insert formats
  for (i in 1:nrow(formats)) {
    sql <- "INSERT INTO formats (format_id, set_name, display_name, release_date, sort_order, is_active)
            VALUES (?, ?, ?, ?, ?, ?)"

    dbExecute(con, sql, params = list(
      formats$format_id[i],
      formats$set_name[i],
      formats$display_name[i],
      as.character(formats$release_date[i]),
      formats$sort_order[i],
      formats$is_active[i]
    ))
  }

  cat("Inserted", nrow(formats), "formats.\n")
}

# -----------------------------------------------------------------------------
# Verify
# -----------------------------------------------------------------------------

cat("\nFormats in database:\n")
result <- dbGetQuery(con,
  "SELECT format_id, display_name, is_active FROM formats ORDER BY sort_order LIMIT 15")
print(result)

# Cleanup
disconnect(con)

cat("\nFormat seeding complete!\n")
