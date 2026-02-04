# views/for-tos-ui.R
# For Tournament Organizers page UI - guides for contributing

for_tos_ui <- div(
  class = "content-page",

  # Header
  div(
    class = "content-page-header",
    h1(class = "content-page-title", "For Organizers"),
    p(class = "content-page-subtitle", "Help grow your local Digimon TCG scene")
  ),

  # Intro
  p("Tournament organizers are the backbone of the Digimon TCG community. DigiLab helps you ",
    "showcase your events and build engagement with your local player base."),
  p("Here's how you can get involved:"),

  # Submit Tournament Results
  h2(class = "faq-category", bsicons::bs_icon("cloud-upload"), "Submit Tournament Results"),
  accordion(
    id = "tos_submit",
    open = TRUE,
    accordion_panel(
      title = "How to submit results",
      value = "submit-results",
      icon = bsicons::bs_icon("list-check"),
      p("Currently, results are submitted manually. Here's the process:"),
      tags$ol(
        class = "steps-list",
        tags$li(
          strong("Take screenshots from Bandai TCG+"),
          p("After your tournament ends, take screenshots of the final standings from the ",
            "Bandai TCG+ app. Make sure placements, usernames, and member numbers are visible.")
        ),
        tags$li(
          strong("Gather tournament details"),
          p("Note the store name, date, format (Standard/Limit 1/etc.), and total number of ",
            "rounds played.")
        ),
        tags$li(
          strong("Submit via contact"),
          p("For now, send your screenshots and details to us through the contact links below. ",
            "We're working on a self-service submission feature!")
        )
      ),
      div(
        class = "contact-links",
        tags$a(
          class = "contact-link",
          href = "https://forms.google.com/digilab-submit",
          target = "_blank",
          bsicons::bs_icon("envelope"), "Submit via Form"
        ),
        tags$a(
          class = "contact-link",
          href = "https://github.com/lopezmichael/digimon-tcg-standings/issues",
          target = "_blank",
          bsicons::bs_icon("github"), "Submit via GitHub"
        )
      )
    ),
    accordion_panel(
      title = "What information do we need?",
      value = "submit-info",
      icon = bsicons::bs_icon("info-circle"),
      p(strong("Required:")),
      tags$ul(
        tags$li("Screenshot of final standings (showing placements, usernames, member numbers)"),
        tags$li("Store name"),
        tags$li("Tournament date"),
        tags$li("Number of rounds")
      ),
      p(strong("Optional but helpful:")),
      tags$ul(
        tags$li("Deck archetypes played (if known)"),
        tags$li("Match history screenshots (for detailed win/loss records)"),
        tags$li("Format (Standard, Limit 1, etc.)")
      ),
      p(class = "info-note",
        bsicons::bs_icon("info-circle"),
        " Don't worry if you don't have all the information! We can add deck archetypes later ",
        "as players self-report or as the community helps identify them.")
    ),
    accordion_panel(
      title = "Submitting match history",
      value = "submit-matchups",
      icon = bsicons::bs_icon("list-ol"),
      p("In addition to final standings, you can submit ", strong("individual round results"),
        " to provide more detailed data:"),
      tags$ul(
        tags$li("Screenshot each player's match history from Bandai TCG+"),
        tags$li("This shows their round-by-round opponents and results"),
        tags$li("Helps calculate more accurate ratings and head-to-head records")
      ),
      p("Match history is optional but valuable for competitive analysis. Even partial data helps!")
    )
  ),

  # Add Your Store
  h2(class = "faq-category", bsicons::bs_icon("shop-window"), "Add Your Store"),
  accordion(
    id = "tos_store",
    open = FALSE,
    accordion_panel(
      title = "How to get your store listed",
      value = "add-store",
      icon = bsicons::bs_icon("plus-circle"),
      p("We want to include every store that runs Digimon TCG events! To add your store:"),
      tags$ol(
        class = "steps-list",
        tags$li(
          strong("Provide store information"),
          p("Store name, address, city, and state/region.")
        ),
        tags$li(
          strong("Share your tournament schedule"),
          p("What days/times do you run Digimon events? Weekly? Monthly?")
        ),
        tags$li(
          strong("Contact us"),
          p("Reach out through GitHub or the links below with your store details.")
        )
      ),
      div(
        class = "contact-links",
        tags$a(
          class = "contact-link",
          href = "https://forms.google.com/digilab-contact",
          target = "_blank",
          bsicons::bs_icon("envelope"), "Request via Form"
        ),
        tags$a(
          class = "contact-link",
          href = "https://github.com/lopezmichael/digimon-tcg-standings/issues/new?title=New%20Store%20Request",
          target = "_blank",
          bsicons::bs_icon("github"), "Request via GitHub"
        )
      )
    ),
    accordion_panel(
      title = "Store requirements",
      value = "store-requirements",
      icon = bsicons::bs_icon("check-circle"),
      p("To be listed on DigiLab, stores should:"),
      tags$ul(
        tags$li("Run regular Digimon TCG events (at least monthly)"),
        tags$li("Use Bandai TCG+ for tournament management"),
        tags$li("Be open to the public (not private play groups)")
      ),
      p("Online tournament platforms may be added in the future.")
    )
  ),

  # Request a New Region/Scene
  h2(class = "faq-category", bsicons::bs_icon("globe"), "Request a New Region"),
  accordion(
    id = "tos_region",
    open = FALSE,
    accordion_panel(
      title = "How to get your region added",
      value = "add-region",
      icon = bsicons::bs_icon("geo-alt"),
      p("DigiLab currently focuses on the Dallas-Fort Worth area, but we're looking to expand! ",
        "If you want your region added:"),
      tags$ol(
        class = "steps-list",
        tags$li(
          strong("Check prerequisites"),
          p("Your region should have at least 2-3 active stores running regular Digimon events.")
        ),
        tags$li(
          strong("Identify a community contact"),
          p("We need someone local who can help gather initial tournament data and stay in ",
            "touch as the community grows.")
        ),
        tags$li(
          strong("Submit your request"),
          p("Tell us about your region: which stores are active, how many players typically ",
            "attend events, and who we can contact.")
        )
      ),
      div(
        class = "contact-links",
        tags$a(
          class = "contact-link",
          href = "https://forms.google.com/digilab-contact",
          target = "_blank",
          bsicons::bs_icon("envelope"), "Request via Form"
        ),
        tags$a(
          class = "contact-link",
          href = "https://github.com/lopezmichael/digimon-tcg-standings/issues/new?title=New%20Region%20Request",
          target = "_blank",
          bsicons::bs_icon("github"), "Request via GitHub"
        )
      )
    ),
    accordion_panel(
      title = "What makes a region?",
      value = "region-definition",
      icon = bsicons::bs_icon("map"),
      p("A \"region\" or \"scene\" in DigiLab is a community of players who regularly compete ",
        "against each other. This is usually defined by:"),
      tags$ul(
        tags$li(strong("Geography"), " - A metro area or collection of nearby cities"),
        tags$li(strong("Community"), " - Players who know each other and attend the same events"),
        tags$li(strong("Activity"), " - At least 2-3 stores with regular events")
      ),
      p("Examples: \"DFW Digimon\", \"Houston TCG\", \"Austin Tamers\"")
    )
  ),

  # Become a Contributor
  h2(class = "faq-category", bsicons::bs_icon("person-badge"), "Become a Contributor"),
  accordion(
    id = "tos_contributor",
    open = FALSE,
    accordion_panel(
      title = "What is a contributor?",
      value = "contributor-info",
      icon = bsicons::bs_icon("star"),
      p("Contributors are trusted community members who can directly enter tournament data ",
        "into DigiLab, rather than submitting screenshots for manual processing."),
      p("As a contributor, you can:"),
      tags$ul(
        tags$li("Enter tournament results directly after events"),
        tags$li("Add and edit deck archetype assignments"),
        tags$li("Update player information and fix errors"),
        tags$li("Help maintain data quality for your local scene")
      )
    ),
    accordion_panel(
      title = "How do I become a contributor?",
      value = "become-contributor",
      icon = bsicons::bs_icon("person-plus"),
      p("We're looking for active tournament organizers and community members who regularly ",
        "attend events. To become a contributor:"),
      tags$ol(
        class = "steps-list",
        tags$li(
          strong("Build a track record"),
          p("Submit a few tournaments via screenshot first so we can verify data quality.")
        ),
        tags$li(
          strong("Express interest"),
          p("Let us know you'd like contributor access when submitting results.")
        ),
        tags$li(
          strong("Get set up"),
          p("We'll provide you with access credentials and a quick orientation on the data entry process.")
        )
      ),
      div(
        class = "contact-links",
        tags$a(
          class = "contact-link",
          href = "https://forms.google.com/digilab-contact",
          target = "_blank",
          bsicons::bs_icon("envelope"), "Request Contributor Access"
        )
      )
    )
  ),

  # Report an Error
  h2(class = "faq-category", bsicons::bs_icon("exclamation-triangle"), "Report an Error"),
  accordion(
    id = "tos_errors",
    open = FALSE,
    accordion_panel(
      title = "How to report data errors",
      value = "report-error",
      icon = bsicons::bs_icon("flag"),
      p("Spotted something wrong? We want to fix it! Common errors include:"),
      tags$ul(
        tags$li("Incorrect tournament results or placements"),
        tags$li("Wrong deck archetype assignments"),
        tags$li("Duplicate player entries"),
        tags$li("Incorrect store information")
      ),
      p("To report an error:"),
      tags$ol(
        class = "steps-list",
        tags$li(
          strong("Identify the issue"),
          p("Note which tournament, player, or store has the error.")
        ),
        tags$li(
          strong("Provide correct information"),
          p("If you know what it should be, include that in your report.")
        ),
        tags$li(
          strong("Submit your report"),
          p("Use the GitHub link below or reach out via the About page.")
        )
      ),
      div(
        class = "contact-links",
        tags$a(
          class = "contact-link",
          href = "https://forms.google.com/digilab-contact",
          target = "_blank",
          bsicons::bs_icon("envelope"), "Report via Form"
        ),
        tags$a(
          class = "contact-link",
          href = "https://github.com/lopezmichael/digimon-tcg-standings/issues/new?title=Data%20Error%20Report",
          target = "_blank",
          bsicons::bs_icon("github"), "Report via GitHub"
        )
      )
    )
  ),

  # Contact section
  div(
    class = "content-section",
    style = "margin-top: 2rem; padding-top: 1rem; border-top: 1px solid rgba(255,255,255,0.1);",
    h2(class = "content-section-title",
       bsicons::bs_icon("chat-square-text"), "Questions?"),
    p("If you have questions about submitting results or getting involved, don't hesitate to reach out."),
    div(
      class = "contact-links",
      tags$a(
        class = "contact-link",
        href = "https://forms.google.com/digilab-contact",
        target = "_blank",
        bsicons::bs_icon("envelope"), "Contact Form"
      ),
      tags$a(
        class = "contact-link",
        href = "https://github.com/lopezmichael/digimon-tcg-standings",
        target = "_blank",
        bsicons::bs_icon("github"), "GitHub"
      ),
      tags$a(
        class = "contact-link",
        href = "https://ko-fi.com/digilab",
        target = "_blank",
        bsicons::bs_icon("cup-hot"), "Ko-fi"
      )
    )
  )
)
