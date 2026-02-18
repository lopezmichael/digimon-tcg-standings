# =============================================================================
# Onboarding Modal UI
# Single-step first-visit modal: Welcome + Scene Selection combined
# =============================================================================

#' Onboarding scene picker with welcome heading
#' @param scenes_data Data frame with scene_id, display_name, slug, latitude, longitude
onboarding_ui <- function(scenes_data = NULL) {
  div(
    class = "onboarding-step onboarding-scene-picker",

    # Decorative top accent
    div(class = "onboarding-accent-top"),

    # Welcome heading (merged from old step 1)
    div(
      class = "onboarding-header",
      h2("Welcome to DigiLab"),
      p(class = "onboarding-tagline", "Your Local Digimon TCG Hub")
    ),

    # Brief description
    p(class = "onboarding-description",
      "Select your local scene to see tournaments, players, and deck meta in your area."
    ),

    # Map container
    div(
      class = "onboarding-map-wrapper",
      div(
        class = "onboarding-map-container",
        mapgl::mapboxglOutput("onboarding_map", height = "280px")
      ),
      div(class = "onboarding-map-hint",
          bsicons::bs_icon("hand-index"),
          span("Click a marker to select"))
    ),

    # Find my scene button
    div(
      class = "onboarding-geolocation",
      actionButton("find_my_scene",
                   tagList(bsicons::bs_icon("crosshair"), " Find My Scene"),
                   class = "btn-primary")
    ),

    # Divider
    div(class = "onboarding-divider",
        span("or choose")),

    # Alternative options
    div(
      class = "onboarding-scene-alternatives",
      actionButton("select_scene_online",
                   tagList(bsicons::bs_icon("camera-video-fill"), " Online / Webcam"),
                   class = "btn-outline-secondary"),
      actionButton("select_scene_all",
                   tagList(bsicons::bs_icon("globe2"), " All Scenes"),
                   class = "btn-outline-secondary")
    ),

    # Decorative bottom accent
    div(class = "onboarding-accent-bottom")
  )
}
