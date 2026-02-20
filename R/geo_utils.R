# =============================================================================
# Geographic Utilities
# Helper functions for coordinate lookups and map rendering
# =============================================================================

#' Get approximate coordinates for a country/region combination
#' Used for placing online organizers on world map
#'
#' @param country Country name (e.g., "USA", "Argentina")
#' @param region Optional region within country (e.g., "DC/MD/VA", "Texas")
#' @return List with lat and lng, or NULL if not found
get_region_coordinates <- function(country, region = NULL) {
  # Region-specific coordinates (more precise placement)
  region_coords <- list(
    "USA" = list(
      "DC/MD/VA" = list(lat = 38.9, lng = -77.0),
      "Texas" = list(lat = 31.0, lng = -97.0),
      "DFW" = list(lat = 32.8, lng = -96.8),
      "default" = list(lat = 39.8, lng = -98.6)  # Geographic center of USA
    ),
    "Argentina" = list(
      "default" = list(lat = -34.6, lng = -58.4)  # Buenos Aires
    ),
    "Brazil" = list(
      "default" = list(lat = -23.5, lng = -46.6)  # São Paulo
    ),
    "Mexico" = list(
      "default" = list(lat = 19.4, lng = -99.1)  # Mexico City
    ),
    "Canada" = list(
      "default" = list(lat = 45.4, lng = -75.7)  # Ottawa
    )
  )

  # Try to find region-specific coordinates
  if (!is.null(country) && country %in% names(region_coords)) {
    country_regions <- region_coords[[country]]

    # Try exact region match first
    if (!is.null(region) && region %in% names(country_regions)) {
      return(country_regions[[region]])
    }

    # Try partial region match
    if (!is.null(region)) {
      for (region_name in names(country_regions)) {
        if (region_name != "default" && grepl(region_name, region, ignore.case = TRUE)) {
          return(country_regions[[region_name]])
        }
      }
    }

    # Fall back to country default
    return(country_regions[["default"]])
  }

  # Unknown country - return NULL
  NULL
}

#' Get world map bounds for fitting all online organizers
#' @return List with sw (southwest) and ne (northeast) coordinates
get_world_map_bounds <- function() {
  list(
    sw = list(lat = -60, lng = -140),
    ne = list(lat = 70, lng = 60)
  )
}
