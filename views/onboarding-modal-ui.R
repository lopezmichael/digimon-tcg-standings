# =============================================================================
# Onboarding Modal UI
# Two-step first-visit modal: Welcome + Scene Selection
# =============================================================================

#' Welcome step content (Step 1)
onboarding_welcome_ui <- function() {
  div(
    class = "onboarding-step onboarding-welcome",

    # Decorative top accent
    div(class = "onboarding-accent-top"),

    # Heading
    div(
      class = "onboarding-header",
      h2("Welcome to DigiLab"),
      p(class = "onboarding-tagline", "Your Local Digimon TCG Hub")
    ),

    # Description
    p(class = "onboarding-description",
      "Track tournament results, discover top players, and explore the deck meta in your local scene."
    ),

    # What you can do - card style
    div(
      class = "onboarding-features",
      div(class = "onboarding-feature-card",
          div(class = "onboarding-feature-icon",
              bsicons::bs_icon("trophy-fill")),
          div(class = "onboarding-feature-text",
              span(class = "onboarding-feature-title", "Tournaments"),
              span(class = "onboarding-feature-desc", "Browse results & standings"))),
      div(class = "onboarding-feature-card",
          div(class = "onboarding-feature-icon",
              bsicons::bs_icon("person-fill")),
          div(class = "onboarding-feature-text",
              span(class = "onboarding-feature-title", "Players"),
              span(class = "onboarding-feature-desc", "Rankings & stats"))),
      div(class = "onboarding-feature-card",
          div(class = "onboarding-feature-icon",
              bsicons::bs_icon("stack")),
          div(class = "onboarding-feature-text",
              span(class = "onboarding-feature-title", "Meta"),
              span(class = "onboarding-feature-desc", "Deck trends & analysis")))
    ),

    # Action button
    div(
      class = "onboarding-actions",
      actionButton("onboarding_get_started",
                   tagList(span("Get Started"), bsicons::bs_icon("arrow-right")),
                   class = "btn-primary btn-lg onboarding-cta")
    ),

    # Decorative bottom accent
    div(class = "onboarding-accent-bottom")
  )
}

#' Scene selection step content (Step 2)
#' @param scenes_data Data frame with scene_id, display_name, slug, latitude, longitude
onboarding_scene_picker_ui <- function(scenes_data = NULL) {
  div(
    class = "onboarding-step onboarding-scene-picker",

    # Decorative top accent
    div(class = "onboarding-accent-top"),

    # Heading with icon
    div(
      class = "onboarding-scene-header",
      div(class = "onboarding-scene-icon",
          bsicons::bs_icon("geo-alt-fill")),
      h3("Select Your Scene"),
      p(class = "onboarding-subtitle",
        "Choose a local scene to see tournaments and players in your area.")
    ),

    # Map container with glow effect
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

    # Find my scene button - prominent
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

    # Back button
    div(
      class = "onboarding-back",
      actionLink("onboarding_back",
                 tagList(bsicons::bs_icon("chevron-left"), " Back"))
    ),

    # Decorative bottom accent
    div(class = "onboarding-accent-bottom")
  )
}
