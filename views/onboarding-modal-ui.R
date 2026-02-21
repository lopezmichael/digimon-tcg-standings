# =============================================================================
# Onboarding Modal UI
# 3-step carousel: Welcome & Features, Scene Selection, Community
# =============================================================================

#' Onboarding carousel with 3 steps
onboarding_ui <- function() {
  tagList(
    # Decorative top accent
    div(class = "onboarding-accent-top"),

    # Dot indicators (3 dots)
    div(
      class = "onboarding-dots",
      style = "padding-top: 1rem;",
      span(id = "onboarding_dot_1", class = "onboarding-dot active"),
      span(id = "onboarding_dot_2", class = "onboarding-dot"),
      span(id = "onboarding_dot_3", class = "onboarding-dot")
    ),

    # --- Step 1: Welcome & Features ---
    div(
      id = "onboarding_step_1",
      class = "onboarding-step",
      div(
        class = "onboarding-welcome-row",
        div(class = "onboarding-mascot", agumon_svg(size = "80px", color = "#F7941D")),
        div(
          class = "onboarding-welcome-text",
          h2("Welcome to DigiLab"),
          p(class = "onboarding-tagline", "Your Local Digimon TCG Hub"),
          p(class = "onboarding-description",
            "Everything you need to track your local Digimon TCG scene ",
            HTML("&mdash;"), " all in one place."
          )
        )
      ),
      # Features grid
      div(
        class = "onboarding-features-grid",
        div(
          class = "onboarding-feature-item",
          div(class = "onboarding-feature-icon", bsicons::bs_icon("grid-3x3-gap")),
          div(class = "onboarding-feature-text",
              tags$strong("Dashboard"),
              span("Trending decks, top performers, and scene health at a glance"))
        ),
        div(
          class = "onboarding-feature-item",
          div(class = "onboarding-feature-icon", bsicons::bs_icon("people")),
          div(class = "onboarding-feature-text",
              tags$strong("Players"),
              span("Elo-style ratings, win rates, and head-to-head records"))
        ),
        div(
          class = "onboarding-feature-item",
          div(class = "onboarding-feature-icon", bsicons::bs_icon("stack")),
          div(class = "onboarding-feature-text",
              tags$strong("Deck Meta"),
              span("Which archetypes are winning and how the meta is shifting"))
        ),
        div(
          class = "onboarding-feature-item",
          div(class = "onboarding-feature-icon", bsicons::bs_icon("trophy")),
          div(class = "onboarding-feature-text",
              tags$strong("Tournaments"),
              span("Full standings, decklists, and match records for every event"))
        ),
        div(
          class = "onboarding-feature-item",
          div(class = "onboarding-feature-icon", bsicons::bs_icon("geo-alt-fill")),
          div(class = "onboarding-feature-text",
              tags$strong("Stores"),
              span("Find stores near you with schedules and event history"))
        )
      )
    ),

    # --- Step 2: Scene Selection ---
    shinyjs::hidden(
      div(
        id = "onboarding_step_2",
        class = "onboarding-step onboarding-scene-picker",

        div(
          class = "onboarding-header",
          h2("Pick Your Scene"),
          p(class = "onboarding-tagline", "See Data That Matters to You")
        ),

        p(class = "onboarding-description",
          "DigiLab covers multiple communities. Pick yours below to filter everything ",
          HTML("&mdash;"), " leaderboards, meta, and tournaments ",
          HTML("&mdash;"), " to your local area."
        ),

        # Map container
        div(
          class = "onboarding-map-wrapper",
          div(
            class = "onboarding-map-container",
            mapgl::mapboxglOutput("onboarding_map", height = "220px")
          ),
          div(class = "onboarding-map-hint",
              bsicons::bs_icon("hand-index"),
              span("Tap a marker to select your scene"))
        ),

        # Find my scene button
        div(
          class = "onboarding-geolocation",
          actionButton("find_my_scene",
                       tagList(bsicons::bs_icon("crosshair"), " Find My Scene"),
                       class = "btn-primary btn-sm")
        ),

        # Divider
        div(class = "onboarding-divider",
            span("or choose")),

        # Alternative options
        div(
          class = "onboarding-scene-alternatives",
          actionButton("select_scene_online",
                       tagList(bsicons::bs_icon("camera-video-fill"), " Online / Webcam"),
                       class = "btn-outline-secondary btn-sm"),
          actionButton("select_scene_all",
                       tagList(bsicons::bs_icon("globe2"), " All Scenes"),
                       class = "btn-outline-secondary btn-sm")
        ),

        p(class = "onboarding-scene-footnote",
          tags$small("You can change your scene anytime from the dropdown in the header.")
        )
      )
    ),

    # --- Step 3: Community ---
    shinyjs::hidden(
      div(
        id = "onboarding_step_3",
        class = "onboarding-step",
        div(
          class = "onboarding-header",
          h2("Join the Community"),
          p(class = "onboarding-tagline", "Help Shape DigiLab")
        ),
        p(class = "onboarding-description",
          "DigiLab is community-built, open source, and still in beta. ",
          "Your feedback directly shapes what gets built next."
        ),
        div(
          class = "onboarding-community-links",
          tags$a(
            class = "onboarding-community-link",
            href = "https://discord.gg/rKNe9FKwkN",
            target = "_blank",
            div(class = "link-icon", bsicons::bs_icon("discord")),
            div(class = "link-text",
                tags$strong("Discord"),
                span("Chat with players, report bugs, and suggest features"))
          ),
          tags$a(
            class = "onboarding-community-link",
            href = "https://ko-fi.com/digilab",
            target = "_blank",
            div(class = "link-icon", bsicons::bs_icon("cup-hot")),
            div(class = "link-text",
                tags$strong("Ko-fi"),
                span("Support server costs and ongoing development"))
          ),
          div(
            class = "onboarding-community-link",
            style = "cursor: pointer;",
            onclick = "Shiny.setInputValue('onboarding_to_organizers', true, {priority: 'event'});",
            div(class = "link-icon", bsicons::bs_icon("megaphone")),
            div(class = "link-text",
                tags$strong("For Organizers"),
                span("Want your community on DigiLab? Here's how"))
          )
        ),
        p(class = "onboarding-scene-footnote mt-2",
          tags$small(
            bsicons::bs_icon("info-circle"),
            " Visit About, FAQ, and For Organizers anytime from the footer links."
          )
        )
      )
    ),

    # --- Navigation Buttons ---
    div(
      class = "onboarding-nav-buttons",
      div(
        class = "onboarding-nav-left",
        actionButton("onboarding_skip", "Skip",
                     class = "onboarding-skip"),
        shinyjs::hidden(
          actionButton("onboarding_back", "Back",
                       class = "btn-outline-secondary btn-sm",
                       icon = icon("arrow-left"))
        )
      ),
      div(
        class = "onboarding-nav-right",
        actionButton("onboarding_next", "Next",
                     class = "btn-primary btn-sm",
                     icon = icon("arrow-right")),
        shinyjs::hidden(
          actionButton("onboarding_finish", "Get Started",
                       class = "btn-primary btn-sm",
                       icon = icon("rocket"))
        )
      )
    ),

    # Decorative bottom accent
    div(class = "onboarding-accent-bottom")
  )
}
