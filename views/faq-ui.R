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
      p("Your Competitive Rating uses an ", strong("Elo-style system"), " adapted for Swiss-style ",
        "tournaments. Unlike traditional Elo that only considers wins/losses, our system uses ",
        strong("implied results"), " based on final placements."),
      p("After each tournament, your rating adjusts based on:"),
      tags$ul(
        tags$li("Your placement relative to ", em("every"), " other player in the tournament"),
        tags$li("The current ratings of those players"),
        tags$li("Whether you placed above or below where your rating predicted")
      ),
      div(class = "formula-box",
          "New Rating = Old Rating + K × (Actual Score - Expected Score)"),
      p(strong("K-factor:"), " New players (fewer than 10 tournaments) use K=32, which means ",
        "ratings adjust faster while the system learns your skill level. Established players ",
        "use K=16 for more stable ratings."),
      p(strong("Starting rating:"), " All players begin at 1500."),
      p(strong("Why implied results?"), " In Swiss tournaments, you don't play everyone. If you ",
        "place 3rd and another player places 7th, we treat that as a \"win\" for you against them, ",
        "even if you never actually played. This gives a more complete picture of tournament performance.")
    ),
    accordion_panel(
      title = "What is Achievement Score?",
      value = "achievement-score",
      icon = bsicons::bs_icon("trophy"),
      p("Achievement Score is a ", strong("cumulative points system"), " that rewards both ",
        "participation and strong finishes. Unlike Competitive Rating (which can go up or down), ",
        "Achievement Score only grows over time."),
      p(strong("Base points by placement:")),
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
          tags$tr(tags$td("17th+"), tags$td("1"))
        )
      ),
      p(strong("Tournament size bonus:"), " Larger tournaments (16+ players) award 50% bonus ",
        "points, reflecting the increased difficulty of placing well against more competition."),
      p(strong("What it measures:"), " Achievement Score reflects your overall engagement with ",
        "the competitive scene. A player with a lower Competitive Rating but high Achievement Score ",
        "is someone who shows up consistently and contributes to the community.")
    ),
    accordion_panel(
      title = "How does Store Rating work?",
      value = "store-rating",
      icon = bsicons::bs_icon("shop"),
      p("Store Rating measures the ", strong("competitive strength"), " of a store's player base. ",
        "It helps answer the question: \"How tough is the competition at this store?\""),
      p(strong("How it's calculated:")),
      tags$ul(
        tags$li("We take the Competitive Ratings of all players who have competed at a store"),
        tags$li("Recent attendees are weighted more heavily than players who haven't been in a while"),
        tags$li("Frequent attendees have slightly more influence than one-time visitors")
      ),
      p(strong("What it means:")),
      tags$ul(
        tags$li(strong("Higher Store Rating"), " = Tougher competition, more experienced players"),
        tags$li(strong("Lower Store Rating"), " = More beginner-friendly, good for new players")
      ),
      p("Store Rating isn't a quality judgment - some players prefer casual environments while ",
        "others seek the most competitive fields. Use it to find stores that match your goals.")
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
        actionLink("faq_to_for_tos", "For Organizers page"), " to learn how to submit results.")
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
      p("Thank you for helping improve DigiLab! We appreciate bug reports."),
      p(strong("What to include:")),
      tags$ul(
        tags$li("What you were trying to do"),
        tags$li("What you expected to happen"),
        tags$li("What actually happened"),
        tags$li("Screenshots if possible")
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
          href = "https://github.com/lopezmichael/digimon-tcg-standings/issues/new?title=Bug%20Report",
          target = "_blank",
          bsicons::bs_icon("github"), "Report via GitHub"
        )
      )
    )
  )
)
