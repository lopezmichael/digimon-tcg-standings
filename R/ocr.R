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
          features = list(list(type = "DOCUMENT_TEXT_DETECTION"))
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

#' Check if a string looks like status bar noise (time, battery, signal)
#'
#' Used during USERNAME detection phase to skip status bar lines.
#' Note: This does NOT filter numbers during the forward-scan phase (after finding usernames)
#' because the forward-scan is position-based and won't reach status bar lines.
#'
#' @param text String to check
#' @return TRUE if it looks like status bar noise
is_status_bar_noise <- function(text) {
 # Time patterns: 12:17, 9:45 AM, 14:30
  if (grepl("^\\d{1,2}:\\d{2}", text)) return(TRUE)

  # Battery percentages with % symbol
  if (grepl("^\\d{1,3}%$", text)) return(TRUE)

  # Signal indicators that OCR might pick up
  if (grepl("^[.oO]{2,5}$", text)) return(TRUE)  # Signal dots
  if (grepl("^LTE$|^5G$|^4G$|^WiFi$", text, ignore.case = TRUE)) return(TRUE)

  # Common status bar text
  if (grepl("^AM$|^PM$", text)) return(TRUE)

  FALSE
}

#' Check if a string looks like a store/business name
#'
#' @param text String to check
#' @return TRUE if it looks like a store name
is_store_name <- function(text) {
  # Common store name patterns
  store_keywords <- c("games", "cards", "hobby", "collectibles", "comics",
                      "gaming", "tcg", "shop", "store", "arena", "lounge",
                      "cafe", "bar", "grill", "pizza", "coffee")

  text_lower <- tolower(text)

  # Check for store keywords
  for (keyword in store_keywords) {
    if (grepl(keyword, text_lower)) return(TRUE)
  }

  # Multi-word names with "The" or ending in common suffixes
 if (grepl("^The\\s+", text, ignore.case = TRUE)) return(TRUE)
  if (grepl("'s$", text)) return(TRUE)  # "Tony's", "Joe's"

  FALSE
}

#' Check if a string looks like event/tournament metadata
#'
#' @param text String to check
#' @return TRUE if it looks like event metadata
is_event_metadata <- function(text) {
  # Bracketed date ranges: [Jan-Mar 2026]
 if (grepl("^\\[.*\\]", text)) return(TRUE)

  # Event type keywords
  if (grepl("tournament|event|championship|regional|locals|cup", text, ignore.case = TRUE)) return(TRUE)

  # Date patterns
  if (grepl("\\d{4}", text) && grepl("jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec", text, ignore.case = TRUE)) return(TRUE)

  FALSE
}

#' Parse tournament standings from OCR text
#'
#' Extracts player data from Bandai TCG+ tournament rankings screenshot.
#' OCR typically returns each table cell as a separate line.
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
    message("[PARSE] First 20 lines:")
    for (i in seq_len(min(20, length(lines)))) {
      message("[PARSE]   ", i, ": '", lines[i], "'")
    }
  }

  results <- list()

  # Header words and noise to skip
  headers <- c("ranking", "ranki", "user name", "username", "win", "omw", "gw",
               "points", "digimon", "card game", "home", "my events", "event search",
               "decks", "others", "ng", "privacy policy", "o o o", "store events",
               "match history", "results", "opponent", "round")

  # Find potential usernames: alphabetic text that's not a header or percentage
  # Usernames in Bandai TCG+ are typically alphanumeric, starting with letter
  username_indices <- c()
  for (i in seq_along(lines)) {
    line <- lines[i]
    line_lower <- tolower(line)

    # Skip if it's a header or noise
    if (line_lower %in% headers) next

    # Skip "Member Number" lines - these are NOT usernames!
    if (grepl("^Member\\s*Number", line, ignore.case = TRUE)) next

    # Skip if contains percentage
    if (grepl("%", line)) next

    # Skip if it's just numbers or time format
    if (grepl("^[\\d\\.:\\-]+$", line)) next

    # Skip very short lines (likely OCR artifacts) - but allow 3+ char usernames
    if (nchar(line) < 3) next

    # Skip common OCR noise patterns
    if (grepl("^[^A-Za-z]", line)) next
    if (grepl("^B⭑", line)) next  # App logo

    # NEW: Skip status bar noise (time, battery, signal)
    if (is_status_bar_noise(line)) {
      if (verbose) message("[PARSE] Skipping status bar noise: '", line, "'")
      next
    }

    # NEW: Skip store/business names
    if (is_store_name(line)) {
      if (verbose) message("[PARSE] Skipping store name: '", line, "'")
      next
    }

    # NEW: Skip event metadata
    if (is_event_metadata(line)) {
      if (verbose) message("[PARSE] Skipping event metadata: '", line, "'")
      next
    }

    # Check if it looks like a username (starts with letter, allows alphanumeric, underscore, space)
    if (grepl("^[A-Za-z][A-Za-z0-9_. ]*$", line) && nchar(line) >= 3) {
      # Additional check: must have at least 3 letters total to avoid noise
      letter_count <- nchar(gsub("[^A-Za-z]", "", line))
      if (letter_count >= 3) {
        username_indices <- c(username_indices, i)
        if (verbose) message("[PARSE] Potential username at line ", i, ": '", line, "'")
      }
    }
  }

  if (verbose) message("[PARSE] Found ", length(username_indices), " potential usernames")

  # Track expected placement (for sequential assignment)
  next_expected_placement <- 1

  # For each username, look FORWARD for member number and numbers for placement/points
  for (j in seq_along(username_indices)) {
    idx <- username_indices[j]
    username <- lines[idx]

    # Search forward up to 12 lines for member number
    # (increased from 8 to handle noise like headers between username and data)
    search_end <- min(length(lines), idx + 12)

    member_num <- NA
    placement <- NA
    points <- NA

    # Collect all numbers between username and member number
    numbers_found <- c()

    for (k in (idx + 1):search_end) {
      line <- lines[k]

      # Check for member number
      member_match <- regmatches(line, regexec("Member\\s*Number\\s*:?\\s*(\\d{10})", line, ignore.case = TRUE))[[1]]
      if (length(member_match) > 1) {
        member_num <- member_match[2]
        break  # Found member number, stop searching
      }

      # Check for standalone 10-digit number (member number without label)
      if (grepl("^\\d{10}$", line)) {
        member_num <- line
        break
      }

      # Collect standalone numbers (potential placement or points)
      # Now handles large tournaments (64, 128+ players)
      if (grepl("^\\d{1,3}$", line)) {
        val <- as.integer(line)
        # We're already scanning FORWARD from a username, so we're past the status bar
        # This contextual position means these numbers are likely tournament data, not battery
        # Only filter obvious non-data: values over 200 (no tournament that large)
        if (val <= 200) {
          numbers_found <- c(numbers_found, val)
        }
      }

      # Stop if we hit another username (but not Member Number lines)
      if (k %in% username_indices && k != idx) break
    }

    # Interpret the numbers found between username and member number
    # OCR Pattern: username -> placement -> points -> percentages -> member number
    # So numbers_found should be [placement, points] in that order
    if (length(numbers_found) >= 2) {
      # First number is placement (1-32 range), second is points (0-15 range)
      potential_placement <- numbers_found[1]
      potential_points <- numbers_found[2]

      # Validate: placement should be reasonable (1-32), points typically 0-15
      if (potential_placement >= 1 && potential_placement <= 32) {
        placement <- potential_placement
        points <- potential_points
      } else {
        # First number doesn't look like placement, maybe both are data
        points <- potential_points
      }
    } else if (length(numbers_found) == 1) {
      # Single number - is it placement or points?
      val <- numbers_found[1]
      # If it's close to expected placement and in valid range, treat as placement
      if (val >= 1 && val <= 32 && abs(val - next_expected_placement) <= 3) {
        placement <- val
      } else {
        # Otherwise treat as points
        points <- val
      }
    }

    # If no placement found, use expected placement
    if (is.na(placement)) {
      placement <- next_expected_placement
    }

    if (verbose) {
      message("[PARSE] Player ", j, ": username='", username, "', placement=", placement,
              ", points=", points, ", member=", member_num)
    }

    # Only add if we found a member number (confirms this is a real player row)
    if (!is.na(member_num)) {
      # Default points to 0 if not found
      if (is.na(points)) points <- 0

      # Validate points - should be 0-15 for typical tournament (up to 5 rounds * 3 points)
      if (points > 15) {
        if (verbose) message("[PARSE] Warning: points=", points, " seems high, might be misread")
      }

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

      # Update expected placement for next player
      next_expected_placement <- placement + 1
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
#' OCR format (each on separate lines):
#'   Opponent username
#'   Round number (1-digit)
#'   Results (X-X-X format)
#'   Points (0, 1, or 3)
#'   Member Number: XXXXXXXXXX
#'
#' @param ocr_text Raw text from gcv_detect_text()
#' @param verbose Print debug messages
#' @return Data frame with columns: round, opponent_username, opponent_member_number,
#'         games_won, games_lost, games_tied, match_points
parse_match_history <- function(ocr_text, verbose = TRUE) {
  if (verbose) message("[MATCH] Starting to parse match history...")

  if (is.null(ocr_text) || ocr_text == "") {
    if (verbose) message("[MATCH] No OCR text to parse")
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

  if (verbose) message("[MATCH] OCR text length: ", nchar(ocr_text))

  lines <- strsplit(ocr_text, "\n")[[1]]
  lines <- trimws(lines)
  lines <- lines[lines != ""]

  if (verbose) message("[MATCH] Found ", length(lines), " non-empty lines")

  # Print all lines for debugging
  if (verbose && length(lines) > 0) {
    message("[MATCH] All lines:")
    for (i in seq_len(length(lines))) {
      message("[MATCH]   ", i, ": '", lines[i], "'")
    }
  }

  results <- list()

  # Headers and noise to skip when looking for usernames
  headers <- c("round", "opponent", "results", "points", "ranking", "match history",
               "store events", "home", "my events", "event search", "decks", "others",
               "3: win, 1: draw, 0: lose", "digimon", "card game", "g", "user name",
               "username", "win", "omw", "gw", "privacy policy")

  # Strategy: Find potential usernames, then scan FORWARD for round, results, points, member number
  # This matches the OCR output order we observed

  username_indices <- c()
  for (i in seq_along(lines)) {
    line <- lines[i]
    line_lower <- tolower(line)

    # Skip headers
    if (line_lower %in% headers) next

    # Skip if contains special patterns
    if (grepl("Member\\s*Number", line, ignore.case = TRUE)) next
    if (grepl("^\\d{1,2}$", line)) next  # Pure numbers (round, points)
    if (grepl("^\\d+-\\d+-\\d+$", line)) next  # Results pattern
    if (grepl("%", line)) next
    if (grepl("\\[", line)) next  # Event names in brackets
    if (grepl("☐", line)) next  # Checkbox characters
    if (grepl("^B⭑", line)) next  # App logo
    if (nchar(line) < 3) next

    # Skip status bar noise (time, battery, signal)
    if (is_status_bar_noise(line)) {
      if (verbose) message("[MATCH] Skipping status bar noise: '", line, "'")
      next
    }

    # Skip store/business names
    if (is_store_name(line)) {
      if (verbose) message("[MATCH] Skipping store name: '", line, "'")
      next
    }

    # Skip event metadata
    if (is_event_metadata(line)) {
      if (verbose) message("[MATCH] Skipping event metadata: '", line, "'")
      next
    }

    # Check if it looks like a username
    if (grepl("^[A-Za-z][A-Za-z0-9_. ]*$", line)) {
      # Must have at least 3 letters
      letter_count <- nchar(gsub("[^A-Za-z]", "", line))
      if (letter_count >= 3) {
        username_indices <- c(username_indices, i)
        if (verbose) message("[MATCH] Potential opponent at line ", i, ": '", line, "'")
      }
    }
  }

  if (verbose) message("[MATCH] Found ", length(username_indices), " potential opponents")

  # For each username, scan forward for: round, results, points, member number
  # Note: OCR order varies - sometimes member number comes before results, sometimes after
  for (idx in username_indices) {
    opponent <- lines[idx]

    # Search forward up to 10 lines for match data
    # (increased from 6 to handle noise between username and data)
    search_end <- min(length(lines), idx + 10)

    round_num <- NA
    games_won <- NA
    games_lost <- NA
    games_tied <- NA
    match_points <- NA
    member_num <- NA

    for (j in (idx + 1):search_end) {
      check_line <- lines[j]

      # Stop if we hit another username (next opponent)
      if (j %in% username_indices) break

      # Check for round number (single digit 1-9)
      if (grepl("^[1-9]$", check_line) && is.na(round_num)) {
        round_num <- as.integer(check_line)
        if (verbose) message("[MATCH]   Round: ", round_num)
        next
      }

      # Check for results pattern (X-X-X)
      result_match <- regmatches(check_line, regexec("^(\\d)\\s*-\\s*(\\d)\\s*-\\s*(\\d)$", check_line))[[1]]
      if (length(result_match) > 1 && is.na(games_won)) {
        games_won <- as.integer(result_match[2])
        games_lost <- as.integer(result_match[3])
        games_tied <- as.integer(result_match[4])
        if (verbose) message("[MATCH]   Results: ", games_won, "-", games_lost, "-", games_tied)
        next
      }

      # Check for points (0, 1, or 3) - must come after results
      if (grepl("^[013]$", check_line) && !is.na(games_won) && is.na(match_points)) {
        match_points <- as.integer(check_line)
        if (verbose) message("[MATCH]   Points: ", match_points)
        next
      }

      # Check for member number (don't break - results might come after)
      member_match <- regmatches(check_line, regexec("Member\\s*Number\\s*:?\\s*(\\d{10})", check_line, ignore.case = TRUE))[[1]]
      if (length(member_match) > 1 && is.na(member_num)) {
        member_num <- member_match[2]
        if (verbose) message("[MATCH]   Member: ", member_num)
        next  # Continue scanning - results might come after member number
      }
    }

    # Only add if we found a member number (confirms this is a real match row)
    if (!is.na(member_num)) {
      results[[length(results) + 1]] <- data.frame(
        round = if (is.na(round_num)) length(results) + 1 else round_num,
        opponent_username = opponent,
        opponent_member_number = member_num,
        games_won = if (is.na(games_won)) 0 else games_won,
        games_lost = if (is.na(games_lost)) 0 else games_lost,
        games_tied = if (is.na(games_tied)) 0 else games_tied,
        match_points = if (is.na(match_points)) 0 else match_points,
        stringsAsFactors = FALSE
      )
      if (verbose) message("[MATCH] Added match #", length(results), ": ", opponent, " (Round ", round_num, ")")
    }
  }

  if (verbose) message("[MATCH] Parsed ", length(results), " match results")

  if (length(results) == 0) {
    if (verbose) message("[MATCH] No results extracted - patterns may not match OCR output")
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

  # Sort by round number
  result_df <- do.call(rbind, results)
  result_df <- result_df[order(result_df$round), ]
  rownames(result_df) <- NULL

  result_df
}
