# views/for-tos-ui.R
# For Tournament Organizers page UI - guides for contributing

for_tos_ui <- div(
  class = "content-page",

  # Header
  div(
    class = "content-page-header",
    h1(class = "content-page-title", "For Tournament Organizers"),
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
        tags$li("Match history screenshots (for detailed results)"),
        tags$li("Format (Standard, Limit 1, etc.)")
      )
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
          href = "https://github.com/lopezmichael/digimon-tcg-standings/issues/new?title=New%20Store%20Request",
          target = "_blank",
          bsicons::bs_icon("shop"), "Request Store Addition"
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
          href = "https://github.com/lopezmichael/digimon-tcg-standings/issues/new?title=New%20Region%20Request",
          target = "_blank",
          bsicons::bs_icon("globe-americas"), "Request New Region"
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
          href = "https://github.com/lopezmichael/digimon-tcg-standings/issues/new?title=Data%20Error%20Report",
          target = "_blank",
          bsicons::bs_icon("bug"), "Report an Error"
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
