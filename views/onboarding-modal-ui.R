# =============================================================================
# Onboarding Modal UI
# Two-step first-visit modal: Welcome + Scene Selection
# =============================================================================

#' Welcome step content (Step 1)
onboarding_welcome_ui <- function() {
  div(
    class = "onboarding-step onboarding-welcome",

    # Logo and heading
    div(
      class = "onboarding-header",
      tags$img(src = "digilab-logo.svg", class = "onboarding-logo", alt = "DigiLab"),
      h2("Welcome to DigiLab")
    ),

    # Description
    p(class = "onboarding-description",
      "Track local Digimon TCG tournament results, player standings, and deck meta."
    ),

    # What you can do
    div(
      class = "onboarding-features",
      div(class = "onboarding-feature",
          bsicons::bs_icon("trophy"),
          span("Browse tournament results")),
      div(class = "onboarding-feature",
          bsicons::bs_icon("people"),
          span("See player rankings")),
      div(class = "onboarding-feature",
          bsicons::bs_icon("layers"),
          span("Explore deck meta"))
    ),

    # Links - clicking these will close the modal and navigate
    div(
      class = "onboarding-links",
      actionLink("onboarding_about", "Learn more about DigiLab"),
      span(" | "),
      actionLink("onboarding_faq", "FAQ")
    ),

    # Action button
    div(
      class = "onboarding-actions",
      actionButton("onboarding_get_started", "Get Started",
                   class = "btn-primary btn-lg")
    )
  )
}

#' Scene selection step content (Step 2)
#' @param scenes_data Data frame with scene_id, display_name, slug, latitude, longitude
onboarding_scene_picker_ui <- function(scenes_data = NULL) {
  div(
    class = "onboarding-step onboarding-scene-picker",

    # Heading
    h3("Select Your Scene"),
    p(class = "onboarding-subtitle",
      "Choose a local scene to see tournaments and players in your area."),

    # Map container
    div(
      class = "onboarding-map-container",
      mapgl::mapboxglOutput("onboarding_map", height = "300px")
    ),

    # Find my scene button
    div(
      class = "onboarding-geolocation",
      actionButton("find_my_scene",
                   tagList(bsicons::bs_icon("geo-alt"), " Find My Scene"),
                   class = "btn-outline-primary")
    ),

    # Alternative options
    div(
      class = "onboarding-scene-alternatives",
      actionButton("select_scene_online",
                   tagList(bsicons::bs_icon("camera-video"), " Online / Webcam"),
                   class = "btn-outline-secondary"),
      actionButton("select_scene_all",
                   tagList(bsicons::bs_icon("globe"), " All Scenes"),
                   class = "btn-outline-secondary")
    ),

    # Back button
    div(
      class = "onboarding-back",
      actionLink("onboarding_back",
                 tagList(bsicons::bs_icon("arrow-left"), " Back"))
    )
  )
}
