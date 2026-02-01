# Rating System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the basic weighted rating with Elo-style Competitive Rating, add Achievement Score for players, and add Store Rating - displaying them in Overview, Players, and Stores tables.

**Architecture:** Create a new `R/ratings.R` module containing three calculation functions. These functions will be called reactively in `app.R` when tournament data changes. Ratings are computed on-the-fly (lightweight enough for in-app calculation).

**Tech Stack:** R, DuckDB queries, reactable tables

---

## Task 1: Create Rating Calculation Module

**Files:**
- Create: `R/ratings.R`

**Step 1: Create the ratings module file with helper functions**

```r
# R/ratings.R
# Rating calculation functions for player and store ratings

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
```

**Step 2: Verify file created correctly**

Check that the file exists and has the expected structure.

**Step 3: Commit**

```bash
git add R/ratings.R
git commit -m "feat: add rating calculation module with Elo, Achievement, and Store ratings"
```

---

## Task 2: Source Ratings Module in app.R

**Files:**
- Modify: `app.R` (near top, with other source statements)

**Step 1: Add source statement for ratings module**

Find the section near the top of app.R where other R files are sourced and add:

```r
source("R/ratings.R")
```

This should be placed after other source() calls like `source("R/db_connection.R")`.

**Step 2: Commit**

```bash
git add app.R
git commit -m "feat: source ratings module in app.R"
```

---

## Task 3: Add Reactive Rating Calculations

**Files:**
- Modify: `app.R` (in server function, after database connection setup)

**Step 1: Add reactive expressions for ratings**

Add these reactive expressions in the server function, after the database connection is established (around line 500-600, after `rv <- reactiveValues(...)`):

```r
  # Reactive: Calculate competitive ratings for all players
  player_competitive_ratings <- reactive({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) {
      return(data.frame(player_id = integer(), competitive_rating = numeric()))
    }
    # Invalidate when results change
    rv$results_updated
    calculate_competitive_ratings(rv$db_con)
  })

  # Reactive: Calculate achievement scores for all players
  player_achievement_scores <- reactive({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) {
      return(data.frame(player_id = integer(), achievement_score = numeric()))
    }
    rv$results_updated
    calculate_achievement_scores(rv$db_con)
  })

  # Reactive: Calculate store ratings
  store_ratings <- reactive({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) {
      return(data.frame(store_id = integer(), store_rating = numeric()))
    }
    rv$results_updated
    player_rtgs <- player_competitive_ratings()
    calculate_store_ratings(rv$db_con, player_rtgs)
  })
```

**Step 2: Commit**

```bash
git add app.R
git commit -m "feat: add reactive rating calculations to server"
```

---

## Task 4: Update Overview Top Players Table

**Files:**
- Modify: `app.R` (output$top_players around line 772)

**Step 1: Replace the existing top_players renderReactable**

Replace the entire `output$top_players <- renderReactable({...})` block (approximately lines 772-837) with:

```r
  # Top players (filters by selected stores, format, date range)
  # Shows: Player, Events, Event Wins, Top 3, Rating (Elo), Achievement
  output$top_players <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    filters <- build_dashboard_filters("t")

    # Query players with basic stats
    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.player_id,
             p.display_name as Player,
             COUNT(DISTINCT r.tournament_id) as Events,
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as event_wins,
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as top3_placements
      FROM players p
      JOIN results r ON p.player_id = r.player_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s %s %s
      GROUP BY p.player_id, p.display_name
      HAVING COUNT(DISTINCT r.tournament_id) > 0
    ", filters$store, filters$format, filters$event_type, filters$date))

    if (nrow(result) == 0) {
      return(reactable(data.frame(Message = "No player data yet"), compact = TRUE))
    }

    # Join with competitive ratings
    comp_ratings <- player_competitive_ratings()
    result <- merge(result, comp_ratings, by = "player_id", all.x = TRUE)
    result$competitive_rating[is.na(result$competitive_rating)] <- 1500

    # Join with achievement scores
    ach_scores <- player_achievement_scores()
    result <- merge(result, ach_scores, by = "player_id", all.x = TRUE)
    result$achievement_score[is.na(result$achievement_score)] <- 0

    # Sort by competitive rating
    result <- result[order(-result$competitive_rating), ]
    result <- head(result, 10)

    reactable(result, compact = TRUE, striped = TRUE,
      columns = list(
        player_id = colDef(show = FALSE),
        Player = colDef(minWidth = 120),
        Events = colDef(minWidth = 60, align = "center"),
        event_wins = colDef(name = "Wins", minWidth = 60, align = "center"),
        top3_placements = colDef(name = "Top 3", minWidth = 60, align = "center"),
        competitive_rating = colDef(
          name = "Rating",
          minWidth = 70,
          align = "center"
        ),
        achievement_score = colDef(
          name = "Achv",
          minWidth = 60,
          align = "center"
        )
      )
    )
  })
```

**Step 2: Verify the app loads without errors**

Run `shiny::runApp()` and check the Overview tab.

**Step 3: Commit**

```bash
git add app.R
git commit -m "feat: update Overview Top Players with Elo rating and achievement score"
```

---

## Task 5: Update Overview Recent Tournaments Table

**Files:**
- Modify: `app.R` (output$recent_tournaments around line 719)

**Step 1: Update the recent_tournaments query and display to include store rating**

Replace the entire `output$recent_tournaments <- renderReactable({...})` block with:

```r
  # Recent tournaments (filters by selected stores, format, date range)
  # Shows Winner column, formatted Type, and Store Rating
  output$recent_tournaments <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    filters <- build_dashboard_filters("t")

    # Query with winner (player who got placement = 1)
    query <- sprintf("
      SELECT t.tournament_id, s.store_id, s.name as Store,
             t.event_date as Date, t.event_type as Type,
             t.player_count as Players, p.display_name as Winner
      FROM tournaments t
      JOIN stores s ON t.store_id = s.store_id
      LEFT JOIN results r ON t.tournament_id = r.tournament_id AND r.placement = 1
      LEFT JOIN players p ON r.player_id = p.player_id
      WHERE 1=1 %s %s %s %s
      ORDER BY t.event_date DESC
      LIMIT 10
    ", filters$store, filters$format, filters$event_type, filters$date)

    data <- dbGetQuery(rv$db_con, query)
    if (nrow(data) == 0) {
      return(reactable(data.frame(Message = "No tournaments yet"), compact = TRUE))
    }

    # Join with store ratings
    str_ratings <- store_ratings()
    data <- merge(data, str_ratings, by = "store_id", all.x = TRUE)
    data$store_rating[is.na(data$store_rating)] <- 0

    # Re-sort by date (merge may have changed order)
    data <- data[order(as.Date(data$Date), decreasing = TRUE), ]

    # Format event type nicely
    event_type_labels <- c(
      "locals" = "Locals",
      "evo_cup" = "Evo Cup",
      "store_championship" = "Store Champ",
      "regionals" = "Regionals",
      "regulation_battle" = "Reg Battle",
      "release_event" = "Release",
      "other" = "Other"
    )
    data$Type <- sapply(data$Type, function(t) {
      if (t %in% names(event_type_labels)) event_type_labels[t] else t
    })

    # Replace NA winners with "-"
    data$Winner[is.na(data$Winner)] <- "-"

    reactable(data, compact = TRUE, striped = TRUE,
      columns = list(
        tournament_id = colDef(show = FALSE),
        store_id = colDef(show = FALSE),
        Store = colDef(minWidth = 120),
        Date = colDef(minWidth = 90),
        Type = colDef(minWidth = 80),
        Players = colDef(minWidth = 60, align = "center"),
        Winner = colDef(minWidth = 100),
        store_rating = colDef(
          name = "Store",
          minWidth = 60,
          align = "center",
          cell = function(value) if (value == 0) "-" else value
        )
      )
    )
  })
```

**Step 2: Commit**

```bash
git add app.R
git commit -m "feat: add Store Rating column to Recent Tournaments table"
```

---

## Task 6: Update Players Tab Table

**Files:**
- Modify: `app.R` (output$player_standings around line 2096)

**Step 1: Update the player_standings renderReactable to use new ratings**

Replace the entire `output$player_standings <- renderReactable({...})` block with:

```r
  output$player_standings <- renderReactable({
    if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

    # Build filters
    search_filter <- if (!is.null(input$players_search) && nchar(trimws(input$players_search)) > 0) {
      sprintf("AND LOWER(p.display_name) LIKE LOWER('%%%s%%')", trimws(input$players_search))
    } else ""

    format_filter <- if (!is.null(input$players_format) && input$players_format != "") {
      sprintf("AND t.format = '%s'", input$players_format)
    } else ""

    min_events <- as.numeric(input$players_min_events)
    if (is.na(min_events)) min_events <- 0

    result <- dbGetQuery(rv$db_con, sprintf("
      SELECT p.player_id, p.display_name as Player,
             COUNT(DISTINCT r.tournament_id) as Events,
             SUM(r.wins) as W, SUM(r.losses) as L, SUM(r.ties) as T,
             ROUND(SUM(r.wins) * 100.0 / NULLIF(SUM(r.wins) + SUM(r.losses), 0), 1) as 'Win %%',
             COUNT(CASE WHEN r.placement = 1 THEN 1 END) as '1st',
             COUNT(CASE WHEN r.placement <= 3 THEN 1 END) as 'Top 3'
      FROM players p
      JOIN results r ON p.player_id = r.player_id
      JOIN tournaments t ON r.tournament_id = t.tournament_id
      WHERE 1=1 %s %s
      GROUP BY p.player_id, p.display_name
      HAVING COUNT(DISTINCT r.tournament_id) >= %d
    ", search_filter, format_filter, min_events))

    if (nrow(result) == 0) {
      return(reactable(data.frame(Message = "No player data matches filters"), compact = TRUE))
    }

    # Join with competitive ratings
    comp_ratings <- player_competitive_ratings()
    result <- merge(result, comp_ratings, by = "player_id", all.x = TRUE)
    result$competitive_rating[is.na(result$competitive_rating)] <- 1500

    # Join with achievement scores
    ach_scores <- player_achievement_scores()
    result <- merge(result, ach_scores, by = "player_id", all.x = TRUE)
    result$achievement_score[is.na(result$achievement_score)] <- 0

    # Sort by competitive rating
    result <- result[order(-result$competitive_rating), ]

    reactable(
      result,
      compact = TRUE,
      striped = TRUE,
      pagination = TRUE,
      defaultPageSize = 20,
      selection = "single",
      onClick = "select",
      rowStyle = list(cursor = "pointer"),
      columns = list(
        player_id = colDef(show = FALSE),
        Player = colDef(minWidth = 150),
        Events = colDef(minWidth = 70, align = "center"),
        W = colDef(minWidth = 50, align = "center"),
        L = colDef(minWidth = 50, align = "center"),
        T = colDef(minWidth = 50, align = "center"),
        `Win %` = colDef(minWidth = 70, align = "center"),
        `1st` = colDef(minWidth = 50, align = "center"),
        `Top 3` = colDef(minWidth = 60, align = "center"),
        competitive_rating = colDef(
          name = "Rating",
          minWidth = 70,
          align = "center"
        ),
        achievement_score = colDef(
          name = "Achv",
          minWidth = 60,
          align = "center"
        )
      )
    )
  })
```

**Step 2: Commit**

```bash
git add app.R
git commit -m "feat: update Players tab with Elo rating and achievement score"
```

---

## Task 7: Update Stores Tab Table

**Files:**
- Modify: `app.R` (output$store_list around line 1318)

**Step 1: Update the store_list renderReactable to include store rating**

Replace the entire `output$store_list <- renderReactable({...})` block with:

```r
  # Store list (uses filtered stores from map selection)
  output$store_list <- renderReactable({
    stores <- filtered_stores()

    if (is.null(stores) || nrow(stores) == 0) {
      return(reactable(data.frame(Message = "No stores yet"), compact = TRUE))
    }

    # Join with store ratings
    str_ratings <- store_ratings()
    stores <- merge(stores, str_ratings, by = "store_id", all.x = TRUE)
    stores$store_rating[is.na(stores$store_rating)] <- 0

    # Format last event date
    stores$last_event_display <- sapply(stores$last_event, function(d) {
      if (is.na(d)) return("-")
      days_ago <- as.integer(Sys.Date() - as.Date(d))
      if (days_ago == 0) "Today"
      else if (days_ago == 1) "Yesterday"
      else if (days_ago <= 7) paste(days_ago, "days ago")
      else if (days_ago <= 30) paste(ceiling(days_ago / 7), "weeks ago")
      else format(as.Date(d), "%b %d")
    })

    # Format for display - include activity metrics and rating
    data <- stores[order(-stores$store_rating, -stores$tournament_count, stores$city, stores$name),
                   c("name", "city", "tournament_count", "avg_players", "store_rating", "last_event_display", "store_id")]
    names(data) <- c("Store", "City", "Events", "Avg Players", "Rating", "Last Event", "store_id")

    reactable(
      data,
      compact = TRUE,
      striped = TRUE,
      selection = "single",
      onClick = "select",
      defaultSorted = list(Rating = "desc"),
      rowStyle = list(cursor = "pointer"),
      columns = list(
        Store = colDef(minWidth = 180),
        City = colDef(minWidth = 100),
        Events = colDef(
          minWidth = 70,
          align = "center",
          cell = function(value) {
            if (value == 0) "-" else value
          }
        ),
        `Avg Players` = colDef(
          minWidth = 90,
          align = "center",
          cell = function(value) {
            if (value == 0) "-" else value
          }
        ),
        Rating = colDef(
          minWidth = 70,
          align = "center",
          cell = function(value) {
            if (value == 0) "-" else value
          }
        ),
        `Last Event` = colDef(minWidth = 100, align = "center"),
        store_id = colDef(show = FALSE)
      )
    )
  })
```

**Step 2: Commit**

```bash
git add app.R
git commit -m "feat: add Store Rating column to Stores tab table"
```

---

## Task 8: Update Info Tooltips for New Ratings

**Files:**
- Modify: `views/dashboard-ui.R` (Top Players card header)

**Step 1: Find and update the Top Players card header tooltip**

The current Top Players card has an info icon with a tooltip explaining the old rating formula. Update it to explain the new Elo-style rating.

Search for the Top Players card header in `views/dashboard-ui.R` and update the tooltip text to:

```r
title = "Rating: Elo-style skill rating based on tournament placements and opponent strength. Achv: Achievement score based on placements, store diversity, and deck variety."
```

**Step 2: Commit**

```bash
git add views/dashboard-ui.R
git commit -m "feat: update rating tooltip to explain Elo and Achievement scores"
```

---

## Task 9: Final Verification and Cleanup

**Step 1: Run the app and verify all tables display correctly**

```r
shiny::runApp()
```

Check:
- [ ] Overview > Top Players shows Rating and Achv columns
- [ ] Overview > Recent Tournaments shows Store Rating column
- [ ] Players tab shows Rating and Achv columns
- [ ] Stores tab shows Rating column
- [ ] No errors in console
- [ ] Ratings appear reasonable (players around 1300-1700 range initially)

**Step 2: Final commit with all changes**

```bash
git add -A
git commit -m "feat: complete rating system implementation (Elo, Achievement, Store)"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Create ratings calculation module | `R/ratings.R` |
| 2 | Source module in app.R | `app.R` |
| 3 | Add reactive rating calculations | `app.R` |
| 4 | Update Overview Top Players table | `app.R` |
| 5 | Update Overview Recent Tournaments table | `app.R` |
| 6 | Update Players tab table | `app.R` |
| 7 | Update Stores tab table | `app.R` |
| 8 | Update info tooltips | `views/dashboard-ui.R` |
| 9 | Final verification | - |

**Total estimated tasks:** 9 discrete tasks with ~20 individual steps
