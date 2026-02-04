# views/faq-ui.R
# FAQ page UI - expandable accordion sections

faq_ui <- div(
  class = "content-page",

  # Header
  div(
    class = "content-page-header",
    h1(class = "content-page-title", "Frequently Asked Questions"),
    p(class = "content-page-subtitle", "Learn how to use DigiLab and understand the metrics")
  ),

  # Using the App
  h2(class = "faq-category", bsicons::bs_icon("display"), "Using the App"),
  accordion(
    id = "faq_using",
    open = FALSE,
    accordion_panel(
      title = "How do I find tournaments near me?",
      value = "find-tournaments",
      icon = bsicons::bs_icon("geo-alt"),
      p("Head to the ", strong("Stores"), " tab to see all active tournament locations. ",
        "The map shows store locations, and clicking on a store reveals their tournament schedule ",
        "and history."),
      p("You can also check the ", strong("Tournaments"), " tab for a chronological list of all ",
        "recorded events.")
    ),
    accordion_panel(
      title = "How do I see my tournament history?",
      value = "my-history",
      icon = bsicons::bs_icon("clock-history"),
      p("Go to the ", strong("Players"), " tab and search for your name. Click on your row to ",
        "open your player profile, which shows:"),
      tags$ul(
        tags$li("All your tournament results"),
        tags$li("Your rating and achievement score"),
        tags$li("Decks you've played"),
        tags$li("Your performance over time")
      )
    ),
    accordion_panel(
      title = "What do the columns in the tables mean?",
      value = "columns",
      icon = bsicons::bs_icon("table"),
      p(strong("Rating"), " - Your competitive rating (Elo-style score)"),
      p(strong("Achv"), " - Achievement score (points from placements)"),
      p(strong("Record"), " - Your win-loss-tie record"),
      p(strong("Meta %"), " - How often a deck appears in tournaments"),
      p(strong("Conv %"), " - Conversion rate (top finishes / total appearances)")
    )
  ),

  # Ratings & Scores
  h2(class = "faq-category", bsicons::bs_icon("graph-up"), "Ratings & Scores"),
  accordion(
    id = "faq_ratings",
    open = FALSE,
    accordion_panel(
      title = "How is Competitive Rating calculated?",
      value = "competitive-rating",
      icon = bsicons::bs_icon("calculator"),
      p("Your Competitive Rating uses an Elo-style system. After each tournament, your rating ",
        "adjusts based on:"),
      tags$ul(
        tags$li("Your placement relative to other players"),
        tags$li("The ratings of players you placed above or below"),
        tags$li("Tournament size")
      ),
      div(class = "formula-box",
          "New Rating = Old Rating + K x (Actual Score - Expected Score)"),
      p("Where K is 32 for newer players (fewer than 10 tournaments) and 16 for established ",
        "players. This means new players' ratings adjust faster."),
      p("All players start at ", strong("1500"), " rating.")
    ),
    accordion_panel(
      title = "What is Achievement Score?",
      value = "achievement-score",
      icon = bsicons::bs_icon("trophy"),
      p("Achievement Score rewards consistent participation and strong finishes. You earn ",
        "points based on your placement:"),
      tags$table(
        class = "points-table",
        tags$thead(
          tags$tr(tags$th("Placement"), tags$th("Points"))
        ),
        tags$tbody(
          tags$tr(tags$td("1st Place"), tags$td("10")),
          tags$tr(tags$td("2nd Place"), tags$td("7")),
          tags$tr(tags$td("3rd - 4th"), tags$td("5")),
          tags$tr(tags$td("5th - 8th"), tags$td("3")),
          tags$tr(tags$td("9th - 16th"), tags$td("1")),
          tags$tr(tags$td("Participation"), tags$td("1"))
        )
      ),
      p("Larger tournaments (16+ players) award bonus points.")
    ),
    accordion_panel(
      title = "How does Store Rating work?",
      value = "store-rating",
      icon = bsicons::bs_icon("shop"),
      p("Store Rating reflects the competitive level of a store's player base. It's calculated as ",
        "a weighted average of ratings from players who compete there, with more weight given to ",
        "recent and frequent attendees."),
      p("A higher Store Rating means the store tends to attract stronger competition.")
    ),
    accordion_panel(
      title = "Why did my rating go down even though I won matches?",
      value = "rating-down",
      icon = bsicons::bs_icon("arrow-down-circle"),
      p("Rating changes are based on ", em("placement"), ", not just wins. If you were expected to ",
        "place higher based on your rating compared to other players in the tournament, your ",
        "rating may decrease even with a positive record."),
      p("For example, if you're the highest-rated player at a tournament and place 3rd, your ",
        "rating will likely decrease because you underperformed relative to expectations.")
    )
  ),

  # Data & Coverage
  h2(class = "faq-category", bsicons::bs_icon("database"), "Data & Coverage"),
  accordion(
    id = "faq_data",
    open = FALSE,
    accordion_panel(
      title = "Where does the data come from?",
      value = "data-source",
      icon = bsicons::bs_icon("cloud-download"),
      p("Tournament results are submitted by tournament organizers and community members. ",
        "We use screenshots from the Bandai TCG+ app to verify placements and player information."),
      p("Card data and images come from the community-maintained DigimonCard.io API.")
    ),
    accordion_panel(
      title = "Why isn't my tournament listed?",
      value = "missing-tournament",
      icon = bsicons::bs_icon("question-circle"),
      p("There are a few possible reasons:"),
      tags$ul(
        tags$li("The tournament organizer hasn't submitted the results yet"),
        tags$li("The store isn't registered in our system"),
        tags$li("The tournament was an unofficial or casual event")
      ),
      p("If you're a tournament organizer, check out the ",
        actionLink("faq_to_for_tos", "For TOs page"), " to learn how to submit results.")
    ),
    accordion_panel(
      title = "How often is data updated?",
      value = "update-frequency",
      icon = bsicons::bs_icon("arrow-repeat"),
      p("Results are added as tournament organizers submit them, typically within a few days of ",
        "each event. Ratings and statistics are recalculated automatically when new results are added."),
      p("Card data is synced monthly from DigimonCard.io to include new releases.")
    ),
    accordion_panel(
      title = "Can I get my data corrected or removed?",
      value = "data-correction",
      icon = bsicons::bs_icon("pencil-square"),
      p("Yes! If you spot an error in your results or want your data removed, please reach out ",
        "through the links on the ", actionLink("faq_to_about", "About page"), "."),
      p("We want to ensure accuracy and respect player privacy.")
    )
  ),

  # General
  h2(class = "faq-category", bsicons::bs_icon("chat-dots"), "General"),
  accordion(
    id = "faq_general",
    open = FALSE,
    accordion_panel(
      title = "Is this an official Bandai tool?",
      value = "official",
      icon = bsicons::bs_icon("patch-question"),
      p(strong("No."), " DigiLab is a fan-made community project and is not affiliated with, ",
        "endorsed by, or connected to Bandai Namco, Bandai Card Games, or any official ",
        "Digimon TCG organization.")
    ),
    accordion_panel(
      title = "How can I support DigiLab?",
      value = "support",
      icon = bsicons::bs_icon("heart"),
      p("There are several ways to support the project:"),
      tags$ul(
        tags$li("Submit your tournament results to help grow the database"),
        tags$li("Spread the word to your local community"),
        tags$li("Report bugs or suggest features on GitHub"),
        tags$li("Support hosting costs via Ko-fi")
      ),
      div(
        class = "contact-links",
        tags$a(
          class = "contact-link",
          href = "https://ko-fi.com/digilab",
          target = "_blank",
          bsicons::bs_icon("cup-hot"), "Support on Ko-fi"
        )
      )
    ),
    accordion_panel(
      title = "I found a bug! How do I report it?",
      value = "bugs",
      icon = bsicons::bs_icon("bug"),
      p("Thank you for helping improve DigiLab! You can report bugs by:"),
      tags$ul(
        tags$li("Opening an issue on GitHub (preferred for technical bugs)"),
        tags$li("Reaching out via the contact links on the About page")
      ),
      p("Please include as much detail as possible: what you were doing, what you expected, ",
        "and what actually happened.")
    )
  )
)
