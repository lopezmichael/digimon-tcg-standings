# DFW Digimon TCG Tournament Tracker

A regional tournament tracking application for the Dallas-Fort Worth Digimon Trading Card Game community. Track player performance, store activity, deck meta, and local tournament results.

## Project Status

**Current Phase: 1 Complete (Foundation)**

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Foundation & Database | Complete |
| 2 | Data Collection | Not Started |
| 3 | Dashboard Development | Not Started |
| 4 | Deployment & Polish | Not Started |

## Features (Planned)

- **Store Directory**: Interactive map of DFW stores hosting Digimon TCG events
- **Tournament Tracking**: Record and browse local tournament results
- **Player Profiles**: Track individual player performance across venues
- **Meta Analysis**: Deck archetype breakdown with win rates and trends
- **Cross-Venue Analytics**: Compare store attendance, competition levels, and local meta

## Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | R Shiny / shinydashboard |
| Database | DuckDB (local) / MotherDuck (cloud) |
| Visualization | ggplot2 / plotly / leaflet |
| Card Data | DigimonCard.io API |
| Hosting | Posit Connect Cloud |

## Installation

### Prerequisites

- R 4.3+
- Required R packages:

```r
install.packages(c("DBI", "duckdb", "shiny", "shinydashboard",
                   "httr", "jsonlite", "ggplot2", "plotly", "leaflet"))
```

### Setup

1. Clone the repository:
```bash
git clone https://github.com/YourUsername/digimon-tcg-standings.git
cd digimon-tcg-standings
```

2. Create a `.env` file (copy from example):
```bash
cp .env.example .env
```

3. (Optional) Add your MotherDuck token to `.env` for cloud database:
```
MOTHERDUCK_TOKEN=your_token_here
```

4. Initialize the database:
```r
source("R/init_database.R")
```

5. Seed initial data:
```r
source("R/seed_stores.R")
source("R/seed_archetypes.R")
```

## Project Structure

```
digimon-tcg-standings/
├── R/
│   ├── db_connection.R      # Database connection module
│   ├── digimoncard_api.R    # DigimonCard.io API integration
│   ├── init_database.R      # Schema initialization
│   ├── seed_stores.R        # DFW store data
│   └── seed_archetypes.R    # Deck archetype data
├── db/
│   └── schema.sql           # Database schema
├── data/
│   ├── local.duckdb         # Local database (gitignored)
│   └── archetype_changelog.md
├── logs/
│   └── dev_log.md           # Development decisions
├── scripts/
│   └── sync_to_motherduck.py  # Cloud sync utility
├── tests/                   # Test files (future)
├── .env                     # Environment variables (gitignored)
├── .env.example             # Environment template
├── CHANGELOG.md             # Version history
├── LICENSE                  # MIT License
├── PROJECT_PLAN.md          # Technical specification
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

## Data Sources

- **DigimonCard.io API**: Card data and images
- **Manual Entry**: Tournament results from Bandai TCG+ (no public API)
- **Limitless TCG API**: Online tournament data (optional)

## Current Data

### Stores (13 DFW locations)
Common Ground Games, Cloud Collectibles, The Card Haven, Game Nerdz (Mesquite, Allen, Wylie), Andyseous Odyssey, Boardwalk Games, Lone Star Pack Breaks, Eclipse Cards and Hobby, Evolution Games, Primal Cards & Collectables, Tony's DTX Cards

### Archetypes (25 BT23/BT24 meta decks)
Hudiemon, Mastemon, Machinedramon, Royal Knights, Gallantmon, Beelzemon, Fenriloogamon, Imperialdramon, Blue Flare, MagnaGarurumon, Jesmon, Leviamon, Bloomlordmon, Xros Heart, Miragegaogamon, Belphemon, Sakuyamon, Numemon, Chronicle, Omnimon, Dark Animals, Dark Masters, Eater, Blue Hybrid, Purple Hybrid

## Contributing

This project is currently in early development. Contributions welcome after Phase 2 is complete.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [DigimonCard.io](https://digimoncard.io) for card data API
- [DigimonMeta](https://digimonmeta.com) and [Digital Gate Open](https://digitalgateopen.com) for meta research
- The DFW Digimon TCG community
