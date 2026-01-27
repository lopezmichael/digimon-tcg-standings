# Digimon TCG Tournament Tracker

A regional tournament tracking application for the Dallas-Fort Worth Digimon Trading Card Game community. Track player performance, store activity, deck meta, and local tournament results.

## Features

- **Interactive Dashboard**: Value boxes, charts, and tables showing tournament activity at a glance
- **Store Directory**: Interactive map of DFW stores with draw-to-filter region selection
- **Tournament Tracking**: Record and browse local tournament results with full standings
- **Player Profiles**: Track individual player performance, favorite decks, and tournament history
- **Meta Analysis**: Deck archetype breakdown with win rates, conversion rates, and trends
- **Admin Panel**: Easy data entry with single and bulk result modes, deck management, and store management

## Screenshots

*Coming soon*

## Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | R Shiny with bslib + atomtemplates |
| Database | DuckDB (local) / MotherDuck (cloud) |
| Charts | Highcharter |
| Maps | mapgl (Mapbox GL JS) |
| Tables | reactable |
| Card Data | DigimonCard.io API |
| Hosting | Posit Connect Cloud |

## Installation

### Prerequisites

- R 4.3+
- Mapbox access token (for map features)

### Required R Packages

```r
install.packages(c(
  # Core Shiny
  "shiny", "shinyjs", "bslib", "bsicons", "htmltools",
  # Database
  "DBI", "duckdb",
  # API/Data
  "httr", "jsonlite",
  # Visualization
  "reactable", "highcharter", "mapgl", "sf",
  # Fonts
  "sysfonts", "showtext",
  # Geocoding
  "tidygeocoder"
))

# Install atomtemplates from GitHub
remotes::install_github("lopezmichael/atomtemplates")
```

### Setup

1. Clone the repository:
```bash
git clone https://github.com/lopezmichael/digimon-tcg-standings.git
cd digimon-tcg-standings
```

2. Create a `.env` file with your tokens:
```bash
cp .env.example .env
```

3. Edit `.env` and add your credentials:
```
MOTHERDUCK_TOKEN=your_motherduck_token_here
MAPBOX_ACCESS_TOKEN=your_mapbox_token_here
```

4. Initialize the database and seed data:
```r
source("R/init_database.R")
source("R/seed_stores.R")
source("R/seed_archetypes.R")
```

5. (Optional) Add mock data for testing:
```r
source("R/seed_mock_data.R")
```

6. Run the app:
```r
shiny::runApp()
```

## Project Structure

```
digimon-tcg-standings/
├── R/
│   ├── db_connection.R      # Database connection module
│   ├── digimoncard_api.R    # DigimonCard.io API integration
│   ├── init_database.R      # Schema initialization
│   ├── seed_stores.R        # DFW store data
│   ├── seed_archetypes.R    # Deck archetype data
│   ├── seed_mock_data.R     # Test data generator
│   ├── delete_mock_data.R   # Test data cleanup
│   └── migrate_db.R         # Database migrations
├── views/
│   ├── dashboard-ui.R       # Dashboard with charts and stats
│   ├── stores-ui.R          # Store directory with map
│   ├── players-ui.R         # Player standings
│   ├── meta-ui.R            # Meta analysis
│   ├── tournaments-ui.R     # Tournament history
│   ├── admin-results-ui.R   # Tournament entry form
│   ├── admin-decks-ui.R     # Deck archetype management
│   └── admin-stores-ui.R    # Store management
├── db/
│   └── schema.sql           # Database schema
├── www/
│   └── custom.css           # Custom styles
├── data/
│   ├── local.duckdb         # Local database (gitignored)
│   └── archetype_changelog.md
├── logs/
│   └── dev_log.md           # Development decisions
├── scripts/
│   └── sync_to_motherduck.py  # Cloud sync utility
├── app.R                    # Main Shiny application
├── _brand.yml               # Atom brand configuration
├── .env                     # Environment variables (gitignored)
├── .env.example             # Environment template
├── CHANGELOG.md             # Version history
├── LICENSE                  # MIT License
└── README.md
```

## Database Schema

### Tables
- `stores` - Local game store information
- `players` - Player profiles
- `deck_archetypes` - Community deck names and display cards
- `archetype_cards` - Card-to-archetype mappings
- `tournaments` - Tournament events
- `results` - Player tournament results
- `ingestion_log` - Data import tracking

### Views
- `player_standings` - Aggregated player statistics
- `archetype_meta` - Deck performance metrics
- `store_activity` - Store tournament summary

## Deployment to Posit Connect Cloud

1. Ensure all required packages are listed in your app
2. Set environment variables in Posit Connect:
   - `MOTHERDUCK_TOKEN`
   - `MAPBOX_ACCESS_TOKEN`
3. Deploy via rsconnect:
```r
rsconnect::deployApp()
```

## Data Sources

- **DigimonCard.io API**: Card data and images
- **Manual Entry**: Tournament results from Bandai TCG+ app
- **Limitless TCG API**: Online tournament data (future)

## Current Data

### Stores (13 DFW locations)
Common Ground Games, Cloud Collectibles, The Card Haven, Game Nerdz (Mesquite, Allen, Wylie), Andyseous Odyssey, Boardwalk Games, Lone Star Pack Breaks, Eclipse Cards and Hobby, Evolution Games, Primal Cards & Collectables, Tony's DTX Cards

### Archetypes (25 BT23/BT24 meta decks)
Hudiemon, Mastemon, Machinedramon, Royal Knights, Gallantmon, Beelzemon, Fenriloogamon, Imperialdramon, Blue Flare, MagnaGarurumon, Jesmon, Leviamon, Bloomlordmon, Xros Heart, Miragegaogamon, Belphemon, Sakuyamon, Numemon, Chronicle, Omnimon, Dark Animals, Dark Masters, Eater, Blue Hybrid, Purple Hybrid

## Contributing

Contributions welcome! Please open an issue or submit a pull request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [DigimonCard.io](https://digimoncard.io) for card data API
- [DigimonMeta](https://digimonmeta.com) and [Digital Gate Open](https://digitalgateopen.com) for meta research
- [atomtemplates](https://lopezmichael.dev) for the Shiny design system
- The DFW Digimon TCG community
