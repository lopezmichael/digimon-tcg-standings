# =============================================================================
# Admin: Edit Stores Server Logic
# =============================================================================

# -----------------------------------------------------------------------------
# Mapbox Geocoding Helper
# -----------------------------------------------------------------------------
#' Geocode an address using Mapbox Geocoding API
#'
#' @param address Full address string to geocode
#' @return List with lat and lng, or list(lat = NA, lng = NA) if failed
geocode_with_mapbox <- function(address) {
  # Get Mapbox token from environment

  mapbox_token <- Sys.getenv("MAPBOX_ACCESS_TOKEN")
  if (mapbox_token == "") {
    warning("MAPBOX_ACCESS_TOKEN not set")
    return(list(lat = NA_real_, lng = NA_real_))
  }

  tryCatch({
    # URL encode the address
    encoded_address <- utils::URLencode(address, reserved = TRUE)

    # Build request URL
    url <- sprintf(
      "https://api.mapbox.com/geocoding/v5/mapbox.places/%s.json?access_token=%s&limit=1",
      encoded_address,
      mapbox_token
    )

    # Make request using httr2
    resp <- httr2::request(url) |>
      httr2::req_timeout(10) |>
      httr2::req_perform()

    # Parse response
    result <- httr2::resp_body_json(resp)

    # Check if we got results
    if (length(result$features) == 0) {
      return(list(lat = NA_real_, lng = NA_real_))
    }

    # Mapbox returns [longitude, latitude]
    coords <- result$features[[1]]$center
    list(lat = coords[[2]], lng = coords[[1]])

  }, error = function(e) {
    warning(paste("Mapbox geocoding error:", e$message))
    list(lat = NA_real_, lng = NA_real_)
  })
}

# Add store
observeEvent(input$add_store, {
  req(rv$is_superadmin, rv$db_con)

  # Check if this is an online store
  is_online <- isTRUE(input$store_is_online)

  # Get name from appropriate input based on is_online
  store_name <- if (is_online) {
    trimws(input$store_name_online)
  } else {
    trimws(input$store_name)
  }

  # Use region as "city" for online stores
  store_city <- if (is_online) {
    trimws(input$store_region)
  } else {
    trimws(input$store_city)
  }

  # Validation
  if (nchar(store_name) == 0) {
    showNotification("Please enter a store name", type = "error")
    return()
  }

  # City is required for physical stores, optional for online stores
  if (!is_online && nchar(store_city) == 0) {
    showNotification("Please enter a city", type = "error")
    return()
  }

  # Check for duplicate store name in same city/region
  # For online stores with no region, check for duplicate name among online stores
  if (is_online && nchar(store_city) == 0) {
    existing <- dbGetQuery(rv$db_con, "
      SELECT store_id FROM stores
      WHERE LOWER(name) = LOWER(?) AND is_online = TRUE AND (city IS NULL OR city = '')
    ", params = list(store_name))
  } else {
    existing <- dbGetQuery(rv$db_con, "
      SELECT store_id FROM stores
      WHERE LOWER(name) = LOWER(?) AND LOWER(city) = LOWER(?)
    ", params = list(store_name, store_city))
  }

  if (nrow(existing) > 0) {
    if (is_online && nchar(store_city) == 0) {
      showNotification(
        sprintf("Online store '%s' already exists", store_name),
        type = "error"
      )
    } else {
      showNotification(
        sprintf("Store '%s' in %s already exists", store_name, store_city),
        type = "error"
      )
    }
    return()
  }

  # Validate website URL format if provided
  if (nchar(input$store_website) > 0 && !grepl("^https?://", input$store_website)) {
    showNotification("Website should start with http:// or https://", type = "warning")
  }

  tryCatch({
    # Online stores don't need geocoding
    if (is_online) {
      lat <- NA_real_
      lng <- NA_real_
      address <- NA_character_
      state <- NA_character_
      zip_code <- NA_character_
    } else {
      # Build full address for geocoding (physical stores only)
      address_parts <- c(input$store_address, store_city)
      address_parts <- c(address_parts, if (nchar(input$store_state) > 0) input$store_state else "TX")
      if (nchar(input$store_zip) > 0) {
        address_parts <- c(address_parts, input$store_zip)
      }
      full_address <- paste(address_parts, collapse = ", ")

      # Geocode the address using Mapbox
      showNotification("Geocoding address...", type = "message", duration = 2)
      geo_result <- geocode_with_mapbox(full_address)

      lat <- geo_result$lat
      lng <- geo_result$lng

      if (is.na(lat) || is.na(lng)) {
        showNotification("Could not geocode address. Store added without coordinates.", type = "warning")
        lat <- NA_real_
        lng <- NA_real_
      }

      # Use NA instead of NULL for DuckDB parameterized queries
      zip_code <- if (nchar(input$store_zip) > 0) input$store_zip else NA_character_
      address <- if (nchar(input$store_address) > 0) input$store_address else NA_character_
      state <- if (nchar(input$store_state) > 0) input$store_state else "TX"
    }

    max_id <- dbGetQuery(rv$db_con, "SELECT COALESCE(MAX(store_id), 0) as max_id FROM stores")$max_id
    new_id <- max_id + 1

    # Common fields for both online and physical stores
    schedule_info <- if (nchar(input$store_schedule) > 0) input$store_schedule else NA_character_
    website <- if (nchar(input$store_website) > 0) input$store_website else NA_character_

    # Use NA for empty city/region
    store_city_db <- if (nchar(store_city) > 0) store_city else NA_character_

    dbExecute(rv$db_con, "
      INSERT INTO stores (store_id, name, address, city, state, zip_code, latitude, longitude, website, schedule_info, is_online)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ", params = list(new_id, store_name, address, store_city_db,
                     state, zip_code, lat, lng, website, schedule_info, is_online))

    showNotification(paste("Added store:", store_name), type = "message")

    # Clear form - both physical and online store fields
    updateTextInput(session, "store_name", value = "")
    updateTextInput(session, "store_name_online", value = "")
    updateTextInput(session, "store_region", value = "")
    updateTextInput(session, "store_address", value = "")
    updateTextInput(session, "store_city", value = "")
    updateSelectInput(session, "store_state", selected = "TX")
    updateTextInput(session, "store_zip", value = "")
    updateTextInput(session, "store_website", value = "")
    updateTextAreaInput(session, "store_schedule", value = "")
    updateCheckboxInput(session, "store_is_online", value = FALSE)

    # Update store dropdown
    updateSelectInput(session, "tournament_store", choices = get_store_choices(rv$db_con, include_none = TRUE))

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Admin store list
output$admin_store_list <- renderReactable({
  if (is.null(rv$db_con) || !dbIsValid(rv$db_con)) return(NULL)

  # Trigger refresh
  input$add_store
  input$update_store
  input$confirm_delete_store

  data <- dbGetQuery(rv$db_con, "
    SELECT store_id, name as Store, city as City, state as State, is_online
    FROM stores
    WHERE is_active = TRUE
    ORDER BY name
  ")
  if (nrow(data) == 0) {
    data <- data.frame(Message = "No stores yet")
    return(reactable(data, compact = TRUE))
  }
  reactable(data, compact = TRUE, striped = TRUE,
    selection = "single",
    onClick = "select",
    rowStyle = list(cursor = "pointer"),
    defaultPageSize = 20,
    showPageSizeOptions = TRUE,
    pageSizeOptions = c(10, 20, 50, 100),
    columns = list(
      store_id = colDef(show = FALSE),
      is_online = colDef(
        name = "Type",
        cell = function(value) if (isTRUE(value)) "Online" else "Physical"
      )
    )
  )
})

# Handle store selection for editing
observeEvent(input$admin_store_list__reactable__selected, {
  req(rv$db_con)
  selected_idx <- input$admin_store_list__reactable__selected

  if (is.null(selected_idx) || length(selected_idx) == 0) {
    return()
  }

  # Get store data
  data <- dbGetQuery(rv$db_con, "
    SELECT store_id, name, address, city, state, zip_code, website, schedule_info, is_online
    FROM stores
    WHERE is_active = TRUE
    ORDER BY name
  ")

  if (selected_idx > nrow(data)) return()

  store <- data[selected_idx, ]

  # Populate form for editing
  updateTextInput(session, "editing_store_id", value = as.character(store$store_id))

  # Handle online store fields
  is_online <- isTRUE(store$is_online)
  updateCheckboxInput(session, "store_is_online", value = is_online)

  if (is_online) {
    updateTextInput(session, "store_name_online", value = store$name)
    updateTextInput(session, "store_region", value = if (is.na(store$city)) "" else store$city)
    updateTextInput(session, "store_name", value = "")  # Clear physical store name
  } else {
    updateTextInput(session, "store_name", value = store$name)
    updateTextInput(session, "store_name_online", value = "")  # Clear online store name
    updateTextInput(session, "store_region", value = "")
  }

  updateTextInput(session, "store_address", value = if (is.na(store$address)) "" else store$address)
  updateTextInput(session, "store_city", value = if (is.na(store$city)) "" else store$city)
  updateSelectInput(session, "store_state", selected = if (is.na(store$state)) "TX" else store$state)
  updateTextInput(session, "store_zip", value = if (is.na(store$zip_code)) "" else store$zip_code)
  updateTextInput(session, "store_website", value = if (is.na(store$website)) "" else store$website)
  updateTextAreaInput(session, "store_schedule", value = if (is.na(store$schedule_info)) "" else store$schedule_info)

  # Show/hide buttons
  shinyjs::hide("add_store")
  shinyjs::show("update_store")
  shinyjs::show("delete_store")

  showNotification(sprintf("Editing: %s", store$name), type = "message", duration = 2)
})

# Update store
observeEvent(input$update_store, {
  req(rv$is_superadmin, rv$db_con)
  req(input$editing_store_id)

  store_id <- as.integer(input$editing_store_id)
  is_online <- isTRUE(input$store_is_online)

  store_name <- if (is_online) {
    trimws(input$store_name_online)
  } else {
    trimws(input$store_name)
  }

  store_city <- if (is_online) {
    trimws(input$store_region)
  } else {
    trimws(input$store_city)
  }

  if (nchar(store_name) == 0) {
    showNotification("Store name is required", type = "error")
    return()
  }

  # City only required for physical stores
  if (!is_online && nchar(store_city) == 0) {
    showNotification("Please enter a city", type = "error")
    return()
  }

  # Validate website URL format if provided
  if (nchar(input$store_website) > 0 && !grepl("^https?://", input$store_website)) {
    showNotification("Website should start with http:// or https://", type = "warning")
  }

  tryCatch({
    # Online stores don't need geocoding
    if (is_online) {
      lat <- NA_real_
      lng <- NA_real_
      address <- NA_character_
      state <- NA_character_
      zip_code <- NA_character_
      store_city_db <- if (nchar(store_city) > 0) store_city else NA_character_
    } else {
      # Build full address for geocoding
      address_parts <- c(input$store_address, store_city)
      address_parts <- c(address_parts, if (nchar(input$store_state) > 0) input$store_state else "TX")
      if (nchar(input$store_zip) > 0) {
        address_parts <- c(address_parts, input$store_zip)
      }
      full_address <- paste(address_parts, collapse = ", ")

      # Geocode the address using Mapbox
      showNotification("Geocoding address...", type = "message", duration = 2)
      geo_result <- geocode_with_mapbox(full_address)

      lat <- geo_result$lat
      lng <- geo_result$lng

      if (is.na(lat) || is.na(lng)) {
        showNotification("Could not geocode address. Keeping existing coordinates.", type = "warning")
        # Keep existing coordinates
        existing <- dbGetQuery(rv$db_con, "SELECT latitude, longitude FROM stores WHERE store_id = ?",
                               params = list(store_id))
        lat <- existing$latitude
        lng <- existing$longitude
      }

      zip_code <- if (nchar(input$store_zip) > 0) input$store_zip else NA_character_
      address <- if (nchar(input$store_address) > 0) input$store_address else NA_character_
      state <- if (nchar(input$store_state) > 0) input$store_state else "TX"
      store_city_db <- store_city
    }

    schedule_info <- if (nchar(input$store_schedule) > 0) input$store_schedule else NA_character_
    website <- if (nchar(input$store_website) > 0) input$store_website else NA_character_

    dbExecute(rv$db_con, "
      UPDATE stores
      SET name = ?, address = ?, city = ?, state = ?, zip_code = ?,
          latitude = ?, longitude = ?, website = ?, schedule_info = ?, is_online = ?, updated_at = CURRENT_TIMESTAMP
      WHERE store_id = ?
    ", params = list(store_name, address, store_city_db, state, zip_code, lat, lng, website, schedule_info, is_online, store_id))

    showNotification(sprintf("Updated store: %s", store_name), type = "message")

    # Clear form and reset to add mode
    updateTextInput(session, "editing_store_id", value = "")
    updateTextInput(session, "store_name", value = "")
    updateTextInput(session, "store_name_online", value = "")
    updateTextInput(session, "store_region", value = "")
    updateTextInput(session, "store_address", value = "")
    updateTextInput(session, "store_city", value = "")
    updateTextInput(session, "store_zip", value = "")
    updateTextInput(session, "store_website", value = "")
    updateTextAreaInput(session, "store_schedule", value = "")
    updateCheckboxInput(session, "store_is_online", value = FALSE)
    updateSelectInput(session, "store_state", selected = "TX")

    shinyjs::show("add_store")
    shinyjs::hide("update_store")
    shinyjs::hide("delete_store")

    # Update dropdown
    updateSelectInput(session, "tournament_store", choices = get_store_choices(rv$db_con, include_none = TRUE))

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})

# Cancel edit store
observeEvent(input$cancel_edit_store, {
  updateTextInput(session, "editing_store_id", value = "")
  updateTextInput(session, "store_name", value = "")
  updateTextInput(session, "store_name_online", value = "")
  updateTextInput(session, "store_region", value = "")
  updateTextInput(session, "store_address", value = "")
  updateTextInput(session, "store_city", value = "")
  updateTextInput(session, "store_zip", value = "")
  updateTextInput(session, "store_website", value = "")
  updateTextAreaInput(session, "store_schedule", value = "")
  updateCheckboxInput(session, "store_is_online", value = FALSE)
  updateSelectInput(session, "store_state", selected = "TX")

  shinyjs::show("add_store")
  shinyjs::hide("update_store")
  shinyjs::hide("delete_store")
})

# Check if store can be deleted (no related tournaments)
observe({
  req(input$editing_store_id)
  store_id <- as.integer(input$editing_store_id)

  count <- dbGetQuery(rv$db_con, "
    SELECT COUNT(*) as cnt FROM tournaments WHERE store_id = ?
  ", params = list(store_id))$cnt

  rv$store_tournament_count <- count
  rv$can_delete_store <- count == 0
})

# Delete button click - show modal
observeEvent(input$delete_store, {
  req(rv$is_superadmin, input$editing_store_id)

  store_id <- as.integer(input$editing_store_id)
  store <- dbGetQuery(rv$db_con, "SELECT name FROM stores WHERE store_id = ?",
                      params = list(store_id))

  if (rv$can_delete_store) {
    output$delete_store_message <- renderUI({
      div(
        p(sprintf("Are you sure you want to delete '%s'?", store$name)),
        p(class = "text-danger", "This action cannot be undone.")
      )
    })
    shinyjs::runjs("$('#delete_store_modal').modal('show');")
  } else {
    showNotification(
      sprintf("Cannot delete: %d tournament(s) reference this store", rv$store_tournament_count),
      type = "error"
    )
  }
})

# Confirm delete
observeEvent(input$confirm_delete_store, {
  req(rv$is_superadmin, rv$db_con, input$editing_store_id)
  store_id <- as.integer(input$editing_store_id)

  tryCatch({
    dbExecute(rv$db_con, "DELETE FROM stores WHERE store_id = ?",
              params = list(store_id))
    showNotification("Store deleted", type = "message")

    # Hide modal and reset form
    shinyjs::runjs("$('#delete_store_modal').modal('hide');")

    # Clear form
    updateTextInput(session, "editing_store_id", value = "")
    updateTextInput(session, "store_name", value = "")
    updateTextInput(session, "store_name_online", value = "")
    updateTextInput(session, "store_region", value = "")
    updateTextInput(session, "store_address", value = "")
    updateTextInput(session, "store_city", value = "")
    updateSelectInput(session, "store_state", selected = "TX")
    updateTextInput(session, "store_zip", value = "")
    updateTextInput(session, "store_website", value = "")
    updateTextAreaInput(session, "store_schedule", value = "")
    updateCheckboxInput(session, "store_is_online", value = FALSE)

    shinyjs::show("add_store")
    shinyjs::hide("update_store")
    shinyjs::hide("delete_store")

    # Update dropdown
    updateSelectInput(session, "tournament_store", choices = get_store_choices(rv$db_con, include_none = TRUE))

    # Trigger refresh of public tables
    rv$data_refresh <- (rv$data_refresh %||% 0) + 1

  }, error = function(e) {
    showNotification(paste("Error:", e$message), type = "error")
  })
})
