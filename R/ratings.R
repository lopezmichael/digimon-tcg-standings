# R/ratings.R
# Rating calculation functions for player and store ratings
# See docs/plans/2026-02-01-rating-system-design.md for methodology

# -----------------------------------------------------------------------------
# COMPETITIVE PLAYER RATING (Elo-style with implied results)
# -----------------------------------------------------------------------------

#' Calculate competitive ratings for all players
#' Uses Elo-style system with implied results from tournament placements
#'
#' @param db_con DuckDB connection
#' @param format_filter Optional format filter (e.g., "BT19")
#' @return Data frame with player_id and competitive_rating
calculate_competitive_ratings <- function(db_con, format_filter = NULL) {

  # Build format condition
  format_condition <- if (!is.null(format_filter) && format_filter != "") {
    sprintf("AND t.format = '%s'", format_filter)
  } else ""

  # Get all tournament results with player counts and dates
  results <- dbGetQuery(db_con, sprintf("
    SELECT r.tournament_id, r.player_id, r.placement,
           t.event_date, t.player_count, t.rounds,
           p.display_name
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    JOIN players p ON r.player_id = p.player_id
    WHERE r.placement IS NOT NULL
      AND t.player_count IS NOT NULL
      AND t.player_count >= 4
      %s
    ORDER BY t.event_date ASC, r.tournament_id, r.placement
  ", format_condition))

  if (nrow(results) == 0) {
    return(data.frame(player_id = integer(), competitive_rating = numeric()))
  }

  # Initialize all players at 1500
 players <- unique(results$player_id)
  ratings <- setNames(rep(1500, length(players)), as.character(players))
  events_played <- setNames(rep(0, length(players)), as.character(players))

  # Get unique tournaments in chronological order
  tournaments <- unique(results[, c("tournament_id", "event_date", "player_count", "rounds")])
  tournaments <- tournaments[order(tournaments$event_date), ]

  # Calculate months ago for decay
  current_date <- Sys.Date()

  # Iterate through tournaments (multiple passes for convergence)
  for (pass in 1:5) {
    for (i in 1:nrow(tournaments)) {
      tourney <- tournaments[i, ]
      tourney_results <- results[results$tournament_id == tourney$tournament_id, ]
      tourney_results <- tourney_results[order(tourney_results$placement), ]

      if (nrow(tourney_results) < 2) next

      # Calculate decay weight (4-month half-life)
      months_ago <- as.numeric(difftime(current_date, tourney$event_date, units = "days")) / 30.44
      decay_weight <- 0.5 ^ (months_ago / 4)

      # Calculate round multiplier: min(1.0 + (rounds - 3) * 0.1, 1.4)
      rounds <- if (is.na(tourney$rounds)) 3 else tourney$rounds
      round_mult <- min(1.0 + (rounds - 3) * 0.1, 1.4)

      # Process each player's implied results
      for (j in 1:nrow(tourney_results)) {
        player_id <- as.character(tourney_results$player_id[j])
        placement <- tourney_results$placement[j]
        player_rating <- ratings[player_id]

        # Determine K-factor (provisional vs established)
        k_factor <- if (events_played[player_id] < 5) 48 else 24

        # Calculate rating change from implied results
        rating_change <- 0

        for (k in 1:nrow(tourney_results)) {
          if (j == k) next

          opponent_id <- as.character(tourney_results$player_id[k])
          opponent_placement <- tourney_results$placement[k]
          opponent_rating <- ratings[opponent_id]

          # Determine if win or loss (lower placement = better)
          actual_result <- if (placement < opponent_placement) 1 else 0

          # Expected score (Elo formula)
          expected <- 1 / (1 + 10^((opponent_rating - player_rating) / 400))

          # Accumulate rating change
          rating_change <- rating_change + k_factor * (actual_result - expected)
        }

        # Apply decay and round multiplier
        rating_change <- rating_change * decay_weight * round_mult

        # Scale down based on number of opponents (normalize)
        num_opponents <- nrow(tourney_results) - 1
        rating_change <- rating_change / num_opponents

        # Update rating
        ratings[player_id] <- ratings[player_id] + rating_change
      }

      # Update events played (only on first pass)
      if (pass == 1) {
        for (pid in tourney_results$player_id) {
          events_played[as.character(pid)] <- events_played[as.character(pid)] + 1
        }
      }
    }
  }

  # Return as data frame
  data.frame(
    player_id = as.integer(names(ratings)),
    competitive_rating = round(as.numeric(ratings), 0),
    stringsAsFactors = FALSE
  )
}


# -----------------------------------------------------------------------------
# ACHIEVEMENT SCORE (Points-based)
# -----------------------------------------------------------------------------

#' Calculate achievement scores for all players
#' Points-based system rewarding placements, diversity, and milestones
#'
#' @param db_con DuckDB connection
#' @return Data frame with player_id and achievement_score
calculate_achievement_scores <- function(db_con) {

  # Get all results with tournament info
  results <- dbGetQuery(db_con, "
    SELECT r.player_id, r.tournament_id, r.placement, r.archetype_id,
           t.player_count, t.store_id, t.format
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE r.placement IS NOT NULL
  ")

  if (nrow(results) == 0) {
    return(data.frame(player_id = integer(), achievement_score = numeric()))
  }

  # Base placement points
  get_placement_points <- function(placement, player_count) {
    base_points <- if (placement == 1) 50
      else if (placement == 2) 30
      else if (placement == 3) 20
      else if (placement <= 4) 15
      else if (placement <= 8) 10
      else 5

    # Size multiplier
    size_mult <- if (is.na(player_count) || player_count < 8) 1.0
      else if (player_count < 12) 1.0
      else if (player_count < 16) 1.25
      else if (player_count < 24) 1.5
      else if (player_count < 32) 1.75
      else 2.0

    round(base_points * size_mult)
  }

  # Calculate per-player scores
  players <- unique(results$player_id)
  scores <- sapply(players, function(pid) {
    player_results <- results[results$player_id == pid, ]

    # Placement points
    placement_pts <- sum(sapply(1:nrow(player_results), function(i) {
      get_placement_points(player_results$placement[i], player_results$player_count[i])
    }))

    # Store diversity bonus
    unique_stores <- length(unique(player_results$store_id))
    store_bonus <- if (unique_stores >= 6) 50
      else if (unique_stores >= 4) 25
      else if (unique_stores >= 2) 10
      else 0

    # Deck variety bonus (3+ different decks)
    unique_decks <- length(unique(na.omit(player_results$archetype_id)))
    deck_bonus <- if (unique_decks >= 3) 15 else 0

    # Format variety bonus (2+ formats)
    unique_formats <- length(unique(na.omit(player_results$format)))
    format_bonus <- if (unique_formats >= 2) 10 else 0

    placement_pts + store_bonus + deck_bonus + format_bonus
  })

  data.frame(
    player_id = players,
    achievement_score = as.integer(scores),
    stringsAsFactors = FALSE
  )
}


# -----------------------------------------------------------------------------
# STORE RATING (Weighted blend)
# -----------------------------------------------------------------------------

#' Calculate store ratings
#' Weighted blend of player strength, attendance, and activity
#'
#' @param db_con DuckDB connection
#' @param player_ratings Data frame from calculate_competitive_ratings()
#' @return Data frame with store_id and store_rating
calculate_store_ratings <- function(db_con, player_ratings) {

  # Get store tournament activity (last 6 months)
  six_months_ago <- Sys.Date() - 180

  store_stats <- dbGetQuery(db_con, sprintf("
    SELECT s.store_id, s.name,
           COUNT(DISTINCT t.tournament_id) as event_count,
           AVG(t.player_count) as avg_attendance
    FROM stores s
    LEFT JOIN tournaments t ON s.store_id = t.store_id
      AND t.event_date >= '%s'
    WHERE s.is_active = TRUE AND (s.is_online = FALSE OR s.is_online IS NULL)
    GROUP BY s.store_id, s.name
  ", six_months_ago))

  if (nrow(store_stats) == 0) {
    return(data.frame(store_id = integer(), store_rating = numeric()))
  }

  # Get player ratings per store (last 6 months)
  store_players <- dbGetQuery(db_con, sprintf("
    SELECT DISTINCT t.store_id, r.player_id
    FROM results r
    JOIN tournaments t ON r.tournament_id = t.tournament_id
    WHERE t.event_date >= '%s'
  ", six_months_ago))

  # Calculate average player rating per store
  store_stats$avg_player_rating <- sapply(store_stats$store_id, function(sid) {
    players_at_store <- store_players$player_id[store_players$store_id == sid]
    if (length(players_at_store) == 0) return(1500)

    player_rtgs <- player_ratings$competitive_rating[player_ratings$player_id %in% players_at_store]
    if (length(player_rtgs) == 0) return(1500)

    mean(player_rtgs)
  })

  # Normalize components to 0-100 scale
  # Player strength: 1200-2000 -> 0-100
  store_stats$strength_score <- pmin(pmax((store_stats$avg_player_rating - 1200) / 8, 0), 100)

  # Attendance: 4-32 players -> 0-100
  store_stats$attendance_score <- pmin(pmax((store_stats$avg_attendance - 4) / 0.28, 0), 100)
  store_stats$attendance_score[is.na(store_stats$attendance_score)] <- 0

  # Activity: 0-4 events per month (over 6 months = 0-24 events) -> 0-100
  store_stats$activity_score <- pmin(store_stats$event_count / 24 * 100, 100)

  # Weighted blend: 50% strength, 30% attendance, 20% activity
  store_stats$store_rating <- round(
    (store_stats$strength_score * 0.5) +
    (store_stats$attendance_score * 0.3) +
    (store_stats$activity_score * 0.2),
    0
  )

  store_stats[, c("store_id", "store_rating")]
}
