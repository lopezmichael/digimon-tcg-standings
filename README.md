# Digimon TCG Tournament Tracker

A regional tournament tracking application for the Dallas-Fort Worth Digimon Trading Card Game community. Track player performance, store activity, deck meta, and local tournament results.

**Live App:** https://lopezmichael.github.io/digimon-tcg-standings/

## Features

- **Interactive Dashboard**: Value boxes, charts, and tables showing tournament activity at a glance
- **Store Directory**: Interactive map of DFW stores with draw-to-filter region selection
- **Tournament Tracking**: Record and browse local tournament results with full standings
- **Player Profiles**: Track individual player performance, favorite decks, and tournament history
- **Meta Analysis**: Deck archetype breakdown with win rates, conversion rates, and trends
- **Admin Panel**: Easy data entry with single and bulk result modes, deck management, and store management

## Screenshots

The app features a responsive design optimized for both desktop and mobile. Screenshots available in the live deployment.

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
source("scripts/init_database.R")
source("scripts/seed_stores.R")
source("scripts/seed_archetypes.R")
source("scripts/seed_formats.R")
```

5. (Optional) Add mock data for testing:
```r
source("scripts/seed_mock_data.R")
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
│   └── digimoncard_api.R    # DigimonCard.io API integration
├── server/
│   ├── shared-server.R      # Database, navigation, auth helpers
│   ├── results-server.R     # Tournament entry wizard
│   ├── admin-decks-server.R # Deck archetype CRUD
│   ├── admin-stores-server.R# Store management
│   └── admin-formats-server.R# Format management
├── views/
│   ├── dashboard-ui.R       # Dashboard with charts and stats
│   ├── stores-ui.R          # Store directory with map
│   ├── players-ui.R         # Player standings
│   ├── meta-ui.R            # Meta analysis
│   ├── tournaments-ui.R     # Tournament history
│   ├── admin-results-ui.R   # Tournament entry form
│   ├── admin-decks-ui.R     # Deck archetype management
│   └── admin-stores-ui.R    # Store management
├── scripts/
│   ├── init_database.R      # Schema initialization
│   ├── seed_stores.R        # DFW store data
│   ├── seed_archetypes.R    # Deck archetype data
│   ├── seed_formats.R       # Format/set data
│   ├── seed_mock_data.R     # Test data generator
│   ├── sync_cards.py        # Sync cards from DigimonCard.io API
│   ├── sync_to_motherduck.py# Push local DB to cloud
│   └── sync_from_motherduck.py # Pull cloud DB to local
├── db/
│   └── schema.sql           # Database schema
├── docs/
│   ├── card-sync.md         # Card sync documentation
│   └── solutions/           # Technical solutions & fixes
├── www/
│   └── custom.css           # Custom styles
├── data/
│   └── local.duckdb         # Local database (gitignored)
├── logs/
│   └── dev_log.md           # Development decisions
├── .github/
│   └── workflows/
│       └── sync-cards.yml   # Monthly card sync automation
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
- `formats` - Game formats/sets (BT19, EX08, etc.)
- `cards` - Card database from DigimonCard.io
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

## Python Scripts

The project includes Python scripts for database synchronization:

### Card Sync (`scripts/sync_cards.py`)

Syncs card data from DigimonCard.io API to the database.

```bash
# Regular update (fast - only new cards)
python scripts/sync_cards.py --by-set --incremental

# Full re-sync
python scripts/sync_cards.py --by-set

# Check for new set prefixes
python scripts/sync_cards.py --discover

# Sync specific set
python scripts/sync_cards.py --set BT-25 --by-set
```

See [docs/card-sync.md](docs/card-sync.md) for full documentation.

### Database Sync

```bash
# Push local database to MotherDuck cloud
python scripts/sync_to_motherduck.py

# Pull cloud database to local
python scripts/sync_from_motherduck.py --yes
```

### Prerequisites

```bash
pip install duckdb python-dotenv requests
```

## Data Sources

- **DigimonCard.io API**: Card data and images (4,200+ cards synced)
- **Manual Entry**: Tournament results from Bandai TCG+ app
- **Limitless TCG API**: Online tournament data (future)

## Current Data

### Stores (13 DFW locations)
Common Ground Games, Cloud Collectibles, The Card Haven, Game Nerdz (Mesquite, Allen, Wylie), Andyseous Odyssey, Boardwalk Games, Lone Star Pack Breaks, Eclipse Cards and Hobby, Evolution Games, Primal Cards & Collectables, Tony's DTX Cards, and more

### Archetypes (25+ meta decks)
Deck archetypes are community-maintained and updated as the meta evolves. Includes current competitive decks across all colors.

### Cards (4,200+ cards)
Full card database synced from DigimonCard.io, covering BT-01 through BT-24, EX-01 through EX-11, starter decks, and promo cards. Automated monthly sync via GitHub Actions.

## Roadmap

### UI Polish (Current Priority)
- [ ] Fix menu bar "menu" text and white space issues
- [ ] Comprehensive mobile view review and fixes
- [ ] Correct button alignment throughout the app
- [ ] Improve header design and add Digimon TCG logo
- [ ] Add links to GitHub repo and "Buy Me a Coffee"
- [ ] Replace individual chart spinners with app-wide loading screen

### Future Features
- [ ] Limitless TCG API integration for online tournament data
- [ ] Matchup analysis (deck A vs deck B win rates)
- [ ] Full Elo-style player rating system
- [ ] Discord bot for result reporting
- [ ] Expand to other Texas regions (Houston, Austin, San Antonio)
- [ ] One Piece TCG support (multi-game expansion)
- [ ] Community-submitted archetype suggestions with approval workflow
- [ ] Mobile-first data entry PWA

## Contributing

Contributions welcome! Please open an issue or submit a pull request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [DigimonCard.io](https://digimoncard.io) for card data API
- [DigimonMeta](https://digimonmeta.com) and [Digital Gate Open](https://digitalgateopen.com) for meta research
- [atomtemplates](https://lopezmichael.dev) for the Shiny design system
- The DFW Digimon TCG community
