# views/about-ui.R
# About page UI - introduction to DigiLab

about_ui <- div(
class = "content-page",

  # Header
  div(
    class = "content-page-header",
    h1(class = "content-page-title", "About DigiLab"),
    p(class = "content-page-subtitle", "Regional tournament tracking for the Digimon TCG community")
  ),

  # Hero section
  div(
    class = "about-hero",
    div(class = "about-mascot", agumon_svg(size = "64px")),
    p(class = "about-tagline", "Track. Compete. Connect."),
    p(class = "about-description",
      "DigiLab is a community-built tool for tracking local Digimon TCG tournament results, ",
      "player performance, and regional meta trends."
    )
  ),

  # What is DigiLab
  div(
    class = "content-section",
    h2(class = "content-section-title",
       bsicons::bs_icon("info-circle"), "What is DigiLab?"),
    p("DigiLab brings tournament data to your local Digimon TCG scene. Unlike global meta trackers, ",
      "we focus on regional communities - helping you understand how you stack up against players ",
      "you actually compete with."),
    tags$ul(
      tags$li("Track your tournament history and rating progression"),
      tags$li("See what decks are performing in your local meta"),
      tags$li("Compare your performance across different stores"),
      tags$li("Discover active tournament locations near you")
    )
  ),

  # Who is it for
  div(
    class = "content-section",
    h2(class = "content-section-title",
       bsicons::bs_icon("people"), "Who is it For?"),
    p(strong("Players"), " - Track your results, upload tournament data, and see your rating"),
    p(strong("Tournament Organizers"), " - Upload event results directly or get contributor access for your community"),
    p(strong("Community Members"), " - Follow the scene even when you can't make it to every event")
  ),

  # Current coverage with live stats
  div(
    class = "content-section",
    h2(class = "content-section-title",
       bsicons::bs_icon("geo-alt"), "Current Coverage"),
    p("DigiLab currently covers the ", strong("Dallas-Fort Worth"), " Digimon TCG community. ",
      "We're looking to expand to more regions - see the ",
      actionLink("about_to_for_tos", "For Organizers page"), " to learn how to get your area added."),

    # Live stats (populated by server)
    div(
      class = "about-stats-grid",
      div(
        class = "about-stat-item",
        div(class = "about-stat-value", textOutput("about_store_count", inline = TRUE)),
        div(class = "about-stat-label", "Active Stores")
      ),
      div(
        class = "about-stat-item",
        div(class = "about-stat-value", textOutput("about_player_count", inline = TRUE)),
        div(class = "about-stat-label", "Players Tracked")
      ),
      div(
        class = "about-stat-item",
        div(class = "about-stat-value", textOutput("about_tournament_count", inline = TRUE)),
        div(class = "about-stat-label", "Tournaments")
      ),
      div(
        class = "about-stat-item",
        div(class = "about-stat-value", textOutput("about_result_count", inline = TRUE)),
        div(class = "about-stat-label", "Results Recorded")
      )
    )
  ),

  # The team / Built by
  div(
    class = "content-section",
    h2(class = "content-section-title",
       bsicons::bs_icon("code-slash"), "Built By"),
    p("DigiLab was created by a North Texas Digimon TCG player who wanted better tools for tracking ",
      "local tournament performance. The project is open source and community-driven."),
    div(
      class = "contact-links contact-links--centered",
      tags$a(
        class = "contact-link",
        href = "https://github.com/lopezmichael/digimon-tcg-standings",
        target = "_blank",
        bsicons::bs_icon("github"), "View on GitHub"
      ),
      tags$a(
        class = "contact-link",
        href = "https://ko-fi.com/digilab",
        target = "_blank",
        bsicons::bs_icon("cup-hot"), "Support on Ko-fi"
      ),
      tags$a(
        class = "contact-link",
        href = "https://forms.google.com/digilab-contact",
        target = "_blank",
        bsicons::bs_icon("envelope"), "Contact Form"
      )
    )
  ),

  # Disclaimer
  div(
    class = "content-section",
    h2(class = "content-section-title",
       bsicons::bs_icon("exclamation-triangle"), "Disclaimer"),
    p(class = "text-muted",
      "DigiLab is a fan-made community tool and is not affiliated with, endorsed by, or ",
      "connected to Bandai Namco, Bandai Card Games, or any official Digimon TCG organization. ",
      "All Digimon-related trademarks and copyrights belong to their respective owners.")
  )
)
