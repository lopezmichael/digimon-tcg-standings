# R/ocr.R
# Google Cloud Vision OCR integration for screenshot parsing

library(httr2)
library(base64enc)

#' Call Google Cloud Vision API for text detection
#'
#' @param image_data Path to local image file OR raw bytes
#' @param api_key Google Cloud Vision API key
#' @param verbose Print debug messages
#' @return Character string of detected text, or NULL on error
gcv_detect_text <- function(image_data, api_key = Sys.getenv("GOOGLE_CLOUD_VISION_API_KEY"), verbose = TRUE) {
  if (verbose) message("[OCR] Starting text detection...")

  if (is.null(api_key) || api_key == "") {
    warning("GOOGLE_CLOUD_VISION_API_KEY not set")
    if (verbose) message("[OCR] ERROR: API key not set")
    return(NULL)
  }
  if (verbose) message("[OCR] API key found (length: ", nchar(api_key), ")")

  # Handle both file path and raw bytes
  if (is.character(image_data) && file.exists(image_data)) {
    if (verbose) message("[OCR] Reading file: ", image_data)
    image_base64 <- base64encode(image_data)
  } else if (is.raw(image_data)) {
    if (verbose) message("[OCR] Using raw bytes (length: ", length(image_data), ")")
    image_base64 <- base64encode(image_data)
  } else {
    warning("Invalid image_data: must be file path or raw bytes")
    if (verbose) message("[OCR] ERROR: Invalid image_data type: ", class(image_data))
    return(NULL)
  }
  if (verbose) message("[OCR] Base64 encoded (length: ", nchar(image_base64), ")")

  # Build and execute request
  tryCatch({
    if (verbose) message("[OCR] Calling Google Cloud Vision API...")

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

    if (verbose) message("[OCR] API response received")

    # Check for API errors in response
    if (!is.null(response$responses[[1]]$error)) {
      err <- response$responses[[1]]$error
      warning(paste("Vision API error:", err$message))
      if (verbose) message("[OCR] API ERROR: ", err$message)
      return(NULL)
    }

    # Extract full text annotation
    text <- response$responses[[1]]$fullTextAnnotation$text
    if (is.null(text)) {
      warning("No text detected in image")
      if (verbose) message("[OCR] No text detected in image")
      return("")
    }

    if (verbose) message("[OCR] Text extracted (", nchar(text), " chars)")
    return(text)
  }, error = function(e) {
    warning(paste("OCR API error:", e$message))
    if (verbose) message("[OCR] EXCEPTION: ", e$message)
    return(NULL)
  })
}

#' Parse tournament standings from OCR text
#'
#' Extracts player data from Bandai TCG+ tournament rankings screenshot.
#' Uses flexible parsing to handle various OCR output formats.
#'
#' @param ocr_text Raw text from gcv_detect_text()
#' @param total_rounds Total rounds in tournament (for calculating losses)
#' @param verbose Print debug messages
#' @return Data frame with columns: placement, username, member_number, points, wins, losses, ties
parse_tournament_standings <- function(ocr_text, total_rounds = 4, verbose = TRUE) {
  if (verbose) message("[PARSE] Starting to parse tournament standings...")

  if (is.null(ocr_text) || ocr_text == "") {
    if (verbose) message("[PARSE] No OCR text to parse")
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

  if (verbose) message("[PARSE] OCR text length: ", nchar(ocr_text))

  lines <- strsplit(ocr_text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[lines != ""]

  if (verbose) message("[PARSE] Found ", length(lines), " non-empty lines")

  # Print first few lines for debugging
  if (verbose && length(lines) > 0) {
    message("[PARSE] First 15 lines:")
    for (i in seq_len(min(15, length(lines)))) {
      message("[PARSE]   ", i, ": '", lines[i], "'")
    }
  }

  results <- list()

  # Strategy: Find all member numbers first, then work backwards to find associated data
  # Member number pattern: "Member Number 0000XXXXXX"
  member_pattern <- "Member\\s*Number\\s*:?\\s*(\\d{10})"

  # Find all member number lines
  member_indices <- c()
  member_numbers <- c()
  for (i in seq_along(lines)) {
    match <- regmatches(lines[i], regexec(member_pattern, lines[i], ignore.case = TRUE))[[1]]
    if (length(match) > 1) {
      member_indices <- c(member_indices, i)
      member_numbers <- c(member_numbers, match[2])
    }
  }

  if (verbose) message("[PARSE] Found ", length(member_indices), " member numbers")

  if (length(member_indices) == 0) {
    # Try alternative: look for 10-digit numbers that might be member numbers
    if (verbose) message("[PARSE] Trying alternative member number detection...")
    for (i in seq_along(lines)) {
      match <- regmatches(lines[i], regexec("\\b(\\d{10})\\b", lines[i]))[[1]]
      if (length(match) > 1) {
        member_indices <- c(member_indices, i)
        member_numbers <- c(member_numbers, match[2])
      }
    }
    if (verbose) message("[PARSE] Found ", length(member_indices), " 10-digit numbers")
  }

  # For each member number, look for ranking data in preceding lines
  for (j in seq_along(member_indices)) {
    idx <- member_indices[j]
    member_num <- member_numbers[j]

    # Look at the line before member number for username
    # And look for placement and points nearby
    search_start <- max(1, idx - 3)
    search_lines <- lines[search_start:(idx - 1)]

    placement <- NA
    username <- NA
    points <- NA

    # Try to find placement (1, 2, 3, etc.) - usually a standalone number or at start
    for (line in search_lines) {
      # Check for standalone placement number
      if (grepl("^\\d{1,2}$", line)) {
        placement <- as.integer(line)
      }
      # Check for username-like text (not a number, not a percentage)
      if (grepl("^[A-Za-z][A-Za-z0-9_\\s]*$", line) && !grepl("%", line)) {
        # Remove "Rank" or "Ranking" header text
        if (!grepl("^Rank", line, ignore.case = TRUE) &&
            !grepl("^User", line, ignore.case = TRUE) &&
            !grepl("^Win", line, ignore.case = TRUE) &&
            !grepl("^OMW", line, ignore.case = TRUE) &&
            !grepl("^GW", line, ignore.case = TRUE)) {
          username <- trimws(line)
        }
      }
    }

    # Try combined line format: "1 Username 12 62.5% 72.7%"
    if (is.na(placement) || is.na(username)) {
      for (line in search_lines) {
        # Pattern: placement username points percentage percentage
        match <- regmatches(line, regexec("^(\\d{1,2})\\s+([A-Za-z][A-Za-z0-9_]*)\\s+(\\d{1,2})\\s+", line))[[1]]
        if (length(match) > 1) {
          placement <- as.integer(match[2])
          username <- match[3]
          points <- as.integer(match[4])
          break
        }
      }
    }

    # Look for points if not found yet - search for standalone small numbers (0-15)
    if (is.na(points)) {
      for (line in search_lines) {
        if (grepl("^\\d{1,2}$", line)) {
          val <- as.integer(line)
          # Points are typically 0-15 for a 4-5 round tournament
          if (val <= 15 && val != placement) {
            points <- val
          }
        }
      }
    }

    # Also check the line with member number for additional data
    full_line <- lines[idx]
    if (is.na(points)) {
      # Look for points in the member number line context
      nums <- as.integer(unlist(regmatches(full_line, gregexpr("\\b\\d{1,2}\\b", full_line))))
      nums <- nums[!is.na(nums) & nums <= 15]
      if (length(nums) > 0) points <- nums[1]
    }

    if (verbose) {
      message("[PARSE] Player ", j, ": placement=", placement, ", username=", username,
              ", points=", points, ", member=", member_num)
    }

    # Only add if we have at least username
    if (!is.na(username) && username != "") {
      # Use position as placement if not found
      if (is.na(placement)) placement <- j

      # Default points to 0 if not found
      if (is.na(points)) points <- 0

      # Calculate W-L-T from points
      wins <- points %/% 3
      remaining <- points %% 3
      ties <- remaining
      losses <- max(0, total_rounds - wins - ties)

      results[[length(results) + 1]] <- data.frame(
        placement = placement,
        username = username,
        member_number = member_num,
        points = points,
        wins = wins,
        losses = losses,
        ties = ties,
        stringsAsFactors = FALSE
      )
    }
  }

  if (verbose) message("[PARSE] Parsed ", length(results), " player results")

  if (length(results) == 0) {
    if (verbose) message("[PARSE] No results extracted - patterns may not match OCR output")
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
