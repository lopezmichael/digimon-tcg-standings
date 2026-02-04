# R/ocr.R
# Google Cloud Vision OCR integration for screenshot parsing

library(httr2)
library(base64enc)

#' Call Google Cloud Vision API for text detection
#'
#' @param image_data Path to local image file OR raw bytes
#' @param api_key Google Cloud Vision API key
#' @return Character string of detected text, or NULL on error
gcv_detect_text <- function(image_data, api_key = Sys.getenv("GOOGLE_CLOUD_VISION_API_KEY")) {
  if (is.null(api_key) || api_key == "") {
    warning("GOOGLE_CLOUD_VISION_API_KEY not set")
    return(NULL)
  }

  # Handle both file path and raw bytes
  if (is.character(image_data) && file.exists(image_data)) {
    image_base64 <- base64encode(image_data)
  } else if (is.raw(image_data)) {
    image_base64 <- base64encode(image_data)
  } else {
    warning("Invalid image_data: must be file path or raw bytes")
    return(NULL)
  }

  # Build and execute request
  tryCatch({
    response <- request("https://vision.googleapis.com/v1/images:annotate") |>
      req_url_query(key = api_key) |>
      req_body_json(list(
        requests = list(list(
          image = list(content = image_base64),
          features = list(list(type = "TEXT_DETECTION"))
        ))
      )) |>
      req_perform() |>
      resp_body_json()

    # Extract full text annotation
    text <- response$responses[[1]]$fullTextAnnotation$text
    if (is.null(text)) {
      warning("No text detected in image")
      return("")
    }
    return(text)
  }, error = function(e) {
    warning(paste("OCR API error:", e$message))
    return(NULL)
  })
}

#' Parse tournament standings from OCR text
#'
#' Extracts player data from Bandai TCG+ tournament rankings screenshot.
#' Expected format per player:
#'   Ranking | Username | Win Points | OMW% | GW%
#'   Member Number 0000XXXXXX
#'
#' @param ocr_text Raw text from gcv_detect_text()
#' @param total_rounds Total rounds in tournament (for calculating losses)
#' @return Data frame with columns: placement, username, member_number, points, wins, losses, ties
parse_tournament_standings <- function(ocr_text, total_rounds = 4) {
  if (is.null(ocr_text) || ocr_text == "") {
    return(data.frame(
      placement = integer(),
      username = character(),
      member_number = character(),
      points = integer(),
      wins = integer(),
      losses = integer(),
      ties = integer()
    ))
  }

  lines <- strsplit(ocr_text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[lines != ""]

  results <- list()

  # Pattern for member number line
  member_pattern <- "Member\\s*Number\\s*:?\\s*(\\d{10,})"

  # Pattern for ranking row: number, username, points, percentages
  # Flexible to handle various OCR quirks
  ranking_pattern <- "^(\\d{1,2})\\s+([A-Za-z0-9_]+)\\s+(\\d{1,2})\\s+"

  current_placement <- NULL
  current_username <- NULL
  current_points <- NULL

  for (line in lines) {
    # Check for member number
    member_match <- regmatches(line, regexec(member_pattern, line, ignore.case = TRUE))[[1]]
    if (length(member_match) > 1) {
      member_number <- member_match[2]
      if (!is.null(current_username)) {
        # Calculate W-L-T from points
        # 3 points per win, 1 point per tie, 0 per loss
        wins <- current_points %/% 3
        remaining <- current_points %% 3
        ties <- remaining  # Each remaining point is a tie
        losses <- total_rounds - wins - ties

        results[[length(results) + 1]] <- data.frame(
          placement = current_placement,
          username = current_username,
          member_number = member_number,
          points = current_points,
          wins = wins,
          losses = max(0, losses),
          ties = ties,
          stringsAsFactors = FALSE
        )

        current_username <- NULL
        current_placement <- NULL
        current_points <- NULL
      }
      next
    }

    # Check for ranking row
    ranking_match <- regmatches(line, regexec(ranking_pattern, line))[[1]]
    if (length(ranking_match) > 1) {
      current_placement <- as.integer(ranking_match[2])
      current_username <- ranking_match[3]
      current_points <- as.integer(ranking_match[4])
    }
  }

  if (length(results) == 0) {
    return(data.frame(
      placement = integer(),
      username = character(),
      member_number = character(),
      points = integer(),
      wins = integer(),
      losses = integer(),
      ties = integer()
    ))
  }

  do.call(rbind, results)
}

#' Parse match history from OCR text
#'
#' Extracts round-by-round match data from Bandai TCG+ match history screenshot.
#'
#' @param ocr_text Raw text from gcv_detect_text()
#' @return Data frame with columns: round, opponent_username, opponent_member_number,
#'         games_won, games_lost, games_tied, match_points
parse_match_history <- function(ocr_text) {
  if (is.null(ocr_text) || ocr_text == "") {
    return(data.frame(
      round = integer(),
      opponent_username = character(),
      opponent_member_number = character(),
      games_won = integer(),
      games_lost = integer(),
      games_tied = integer(),
      match_points = integer()
    ))
  }

  lines <- strsplit(ocr_text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[lines != ""]

  results <- list()

  # Pattern for round row with results
  # Format: Round# | Opponent | Results (W-L-T) | Points
  round_pattern <- "^(\\d)\\s+"
  result_pattern <- "(\\d)\\s*-\\s*(\\d)\\s*-\\s*(\\d)"
  member_pattern <- "Member\\s*Number\\s*:?\\s*(\\d{10,})"

  current_round <- NULL
  current_opponent <- NULL
  current_games <- NULL
  current_points <- NULL

  for (i in seq_along(lines)) {
    line <- lines[i]

    # Check for member number (comes after opponent name)
    member_match <- regmatches(line, regexec(member_pattern, line, ignore.case = TRUE))[[1]]
    if (length(member_match) > 1 && !is.null(current_opponent)) {
      results[[length(results) + 1]] <- data.frame(
        round = current_round,
        opponent_username = current_opponent,
        opponent_member_number = member_match[2],
        games_won = current_games[1],
        games_lost = current_games[2],
        games_tied = current_games[3],
        match_points = current_points,
        stringsAsFactors = FALSE
      )
      current_opponent <- NULL
      next
    }

    # Check for round row
    round_match <- regmatches(line, regexec(round_pattern, line))[[1]]
    if (length(round_match) > 1) {
      current_round <- as.integer(round_match[2])

      # Extract results (W-L-T)
      result_match <- regmatches(line, regexec(result_pattern, line))[[1]]
      if (length(result_match) > 1) {
        current_games <- as.integer(result_match[2:4])
      }

      # Extract points (last number in line)
      points_match <- regmatches(line, regexec("(\\d)\\s*$", line))[[1]]
      if (length(points_match) > 1) {
        current_points <- as.integer(points_match[2])
      }

      # Extract opponent name (between round and results)
      # This is tricky - opponent name is in the middle
      parts <- strsplit(line, "\\s{2,}")[[1]]
      if (length(parts) >= 2) {
        current_opponent <- trimws(parts[2])
        # Remove any numbers that got captured
        current_opponent <- gsub("^\\d+\\s*", "", current_opponent)
        current_opponent <- gsub("\\s*\\d.*$", "", current_opponent)
      }
    }
  }

  if (length(results) == 0) {
    return(data.frame(
      round = integer(),
      opponent_username = character(),
      opponent_member_number = character(),
      games_won = integer(),
      games_lost = integer(),
      games_tied = integer(),
      match_points = integer()
    ))
  }

  do.call(rbind, results)
}
