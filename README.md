# nix-ts-map

A real-time flight tracking and visualization platform built with Nix, TypeScript, ClickHouse, GraphQL, and React. This project provides a complete pipeline from scraping flight data to rendering it on an interactive, GPU-accelerated map.

## TLDR

```bash
nix develop && nix run
```

That's it! This will:
1. Enter the development environment
2. Install dependencies
3. Apply database migrations
4. Start all services (ClickHouse, GraphQL API, Scraper, Frontend)
5. Open the frontend in your browser

The frontend will be available at `http://localhost:5173`

## Prerequisites

- **Nix** with Flakes enabled
  ```bash
  # Enable flakes if not already enabled
  mkdir -p ~/.config/nix
  echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
  ```

## Detailed Installation

### First-Time Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd nix-ts-map
   ```

2. **Enter the development shell:**
   ```bash
   nix develop
   ```
   This provides:
   - Bun (TypeScript runtime & package manager)
   - Node.js 22.16.0
   - ClickHouse (server & client)
   - process-compose (service orchestration)

3. **Install dependencies:**
   ```bash
   bun install
   ```

4. **Configure environment variables:**
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env and fill in your values (see OpenSky API section below)
   ```

5. **Run the application:**
   ```bash
   nix run
   ```

   Or manually:
   ```bash
   # Apply migrations (first time only)
   bash scripts/apply-migrations.sh
   
   # Start all services
   process-compose up
   ```

## OpenSky API

The scraper uses the [OpenSky Network API](https://openskynetwork.github.io/opensky-api/) to fetch real-time flight data.

### Public API (No Authentication)

The OpenSky API can be used without authentication, but with rate limits:
- **Anonymous users**: ~10 requests per minute
- **Registered users**: ~10,000 requests per day

### Optional: Register for Higher Rate Limits

1. Create an account at https://opensky-network.org/accounts/login/
2. Get your username and password
3. Add them to your `.env` file:
   ```bash
   OPENSKY_USERNAME=your_username
   OPENSKY_PASSWORD=your_password
   ```

### API Endpoint Used

The scraper uses the `/api/states/all` endpoint with bounding box filtering:
- **URL**: `https://opensky-network.org/api/states/all?lamin={minLat}&lomin={minLon}&lamax={maxLat}&lomax={maxLon}`
- **Returns**: Array of state vectors (flight positions) within the bounding box
- **Rate**: Configured via `SCRAPE_INTERVAL_SECONDS` in `.env` (default: 60 seconds)

### Data Retrieved

Each state vector includes:
- `icao24`: Aircraft identifier
- `latitude`, `longitude`: Position
- `geo_altitude` or `baro_altitude`: Altitude
- `velocity`: Ground speed (m/s)
- `true_track`: Heading (degrees)
- `vertical_rate`: Vertical speed (m/s)
- `time_position`: Unix timestamp
- And more metadata (callsign, squawk, etc.)

## Shared Types

The `@map/shared` package defines the core data structures used throughout the application:

### FlightEvent

Represents a single point-in-time snapshot of a flight's position and state:

```typescript
interface FlightEvent {
  icao24: string;           // ICAO 24-bit address
  timestamp: number;        // Unix timestamp (seconds)
  latitude: number;         // Decimal degrees (-90 to 90)
  longitude: number;        // Decimal degrees (-180 to 180)
  altitude: number;         // Meters above sea level
  heading: number;          // Degrees (0-360, 0 = North)
  groundSpeed: number;     // Meters per second
  verticalRate: number;     // Meters per second (positive = climbing)
  source: DataSource;      // 'opensky' | 'fr24' | 'adsbexchange' | 'unknown'
}
```

### FlightEventWithH3

Extends `FlightEvent` with H3 geospatial indexes at all resolutions (r0-r10):

```typescript
interface FlightEventWithH3 extends FlightEvent {
  h3_res0: H3Index;   // ~1107km hexagons
  h3_res1: H3Index;   // ~418km hexagons
  h3_res2: H3Index;   // ~158km hexagons
  h3_res3: H3Index;   // ~59km hexagons
  h3_res4: H3Index;   // ~22km hexagons
  h3_res5: H3Index;   // ~8km hexagons
  h3_res6: H3Index;   // ~3km hexagons
  h3_res7: H3Index;   // ~1km hexagons
  h3_res8: H3Index;   // ~0.5km hexagons
  h3_res9: H3Index;   // ~0.2km hexagons
  h3_res10: H3Index;  // ~0.07km hexagons
}
```

All resolutions are calculated at write-time by the scraper, enabling efficient querying at any resolution without runtime conversion.

### FlightDetails

Base interface for flight metadata:

```typescript
interface BaseFlightDetails {
  icao24: string;
  callsign: string | null;
  registration: string | null;
  aircraftModel: string | null;
  originAirportIATA: string | null;
  destinationAirportIATA: string | null;
}
```

Extended with source-specific fields:
- `Fr24FlightDetails`: Adds `flightNumber`, `airline`, `aircraftAge`
- `OpenSkyFlightDetails`: Adds `onGround`, `squawk`, `spi`, `positionSource`

## ClickHouse Tables

### flight_events

The main table storing all flight position snapshots:

```sql
CREATE TABLE flight_events (
    icao24 String,
    timestamp DateTime,
    latitude Float64,
    longitude Float64,
    altitude Float64,
    heading Float64,
    groundSpeed Float64,
    verticalRate Float64,
    source LowCardinality(String),
    -- H3 indexes at all resolutions (r0-r10)
    h3_res0 String,
    h3_res1 String,
    ...
    h3_res10 String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (icao24, timestamp);
```

**Key features:**
- Partitioned by month for efficient time-based queries
- Ordered by `(icao24, timestamp)` for fast per-flight lookups
- All H3 resolutions precomputed at write-time

### Materialized Views

For each resolution (r0-r10), there's a materialized view that aggregates flight counts per hexagon per minute:

```sql
CREATE TABLE flights_per_hex_per_minute_r3 (
    h3_res3 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res3, minute);
```

**Benefits:**
- Pre-aggregated data for fast queries
- Automatic updates as new data is inserted
- No runtime H3 conversion needed
- Query the correct resolution table directly

### latest_flight_positions

Materialized view providing the most recent position for every aircraft:

```sql
CREATE TABLE latest_flight_positions (
    icao24 String,
    last_seen DateTime,
    latest_lat Float64,
    latest_lon Float64,
    latest_alt Float64
) ENGINE = AggregatingMergeTree()
ORDER BY icao24;
```

Used by the frontend to display current aircraft positions as white dots on the map.

## Running the Application

### Option 1: Nix Run (Recommended)

```bash
nix run
```

This single command:
1. Enters the development environment
2. Installs dependencies (`bun install`)
3. Applies database migrations
4. Starts all services via process-compose:
   - ClickHouse server (port 8123)
   - GraphQL API server (port 4000)
   - Scraper service (runs every 60 seconds)
   - Frontend dev server (port 5173)
5. Opens the frontend in your browser

### Option 2: Manual Service Management

Start services individually:

```bash
# Terminal 1: ClickHouse
clickhouse-server

# Terminal 2: GraphQL API
bun run packages/map-graphql/src/index.ts

# Terminal 3: Scraper
bun run packages/map-scraper/src/index.ts

# Terminal 4: Frontend
cd packages/map-frontend && bun dev
```

## Database Management

### Reset Database (Start Fresh)

To wipe all data and start scraping from scratch:

```bash
# Option 1: Using nix run (recommended)
# Make sure ClickHouse is running first
nix run .#wipe-db

# Option 2: Using the script directly
nix develop
bash scripts/reset-database.sh
```

**⚠️ WARNING:** This will:
- Drop all tables and materialized views
- Delete all flight data
- Clear all aggregated hex data
- Re-apply all migrations to recreate empty schema

This is useful when you want to:
- Start scraping from scratch
- Clear old test data
- Reset after schema changes

The script will prompt for confirmation before proceeding.

### Initialize Database Manually

If you need to initialize the database manually:

```bash
nix develop
bash scripts/apply-migrations.sh
```

This applies `db/init-db.sql` which creates all tables and materialized views.

## Testing

### Run All Tests

```bash
# Interactive testing
bun test --workspaces

# Full validation in clean Nix environment
nix flake check
```

### Run Tests for Specific Package

```bash
cd packages/map-scraper
bun test
```

## Project Structure

```
nix-ts-map/
├── flake.nix              # Nix development environment
├── package.json           # Root workspace configuration
├── packages/
│   ├── map-shared/        # Shared TypeScript types
│   ├── map-scraper/       # Flight data scraper service
│   ├── map-graphql/       # GraphQL API server
│   └── map-frontend/      # React visualization app
├── db/
│   ├── clickhouse-config.xml  # ClickHouse server configuration
│   ├── clickhouse-data/        # ClickHouse runtime data (created at runtime, gitignored)
│   ├── init-db.sql             # Database initialization script (creates all tables/views)
│   └── wipe-db.sql             # Database wipe script (drops all tables/views)
├── plans/                 # Sprint planning documents
├── scripts/
│   ├── apply-migrations.sh    # Apply database migrations
│   └── reset-database.sh      # Wipe all data and reset database
└── process-compose.yml    # Service orchestration config
```

## Key Features

- **Real-time Updates**: Frontend polls GraphQL API every 60 seconds for new data
- **Geospatial Indexing**: H3 hexagon indexing at all resolutions (r0-r10) for efficient spatial queries
- **GPU-Accelerated Rendering**: Deck.gl for high-performance visualization
- **Type Safety**: End-to-end TypeScript types from database to frontend
- **Reproducible Environment**: Nix ensures consistent development setup
- **Precomputed Resolutions**: All H3 resolutions calculated at write-time, no runtime conversion

## Development Workflow

1. Make changes to any package
2. Services hot-reload where supported (frontend, GraphQL)
3. Run `nix flake check` before committing to ensure everything works
4. Check logs in `logs/` directory for debugging

## Troubleshooting

### ClickHouse Connection Issues
- Ensure ClickHouse server is running: `clickhouse-server`
- Check connection settings in `.env` files
- Check logs: `logs/clickhouse.log`

### Port Conflicts
- GraphQL API: Change port in `packages/map-graphql/src/index.ts`
- Frontend: Change port in `packages/map-frontend/vite.config.ts`
- ClickHouse: Change port in `.env` (default: 8123 for HTTP, 9000 for native)

### Nix Issues
- Update flake inputs: `nix flake update`
- Clear Nix store if needed: `nix-collect-garbage`

### Migration Issues
- Ensure ClickHouse is running before applying migrations
- Use `--multiquery` flag: `clickhouse-client --multiquery < migration.sql`
- Check migration logs in `logs/` directory

## Environment Variables

See `.env.example` for all available configuration options:

- `CLICKHOUSE_HOST`: ClickHouse server host (default: localhost)
- `CLICKHOUSE_PORT`: ClickHouse native port (default: 9000)
- `CLICKHOUSE_USER`: ClickHouse username (default: default)
- `CLICKHOUSE_PASSWORD`: ClickHouse password (default: empty)
- `CLICKHOUSE_DATABASE`: Database name (default: default)
- `FINLAND_BOUNDS`: Bounding box for Finland (default: "59.5,19.0,70.1,31.5")
- `SCRAPE_INTERVAL_SECONDS`: Scraping interval (default: 60)
- `OPENSKY_USERNAME`: Optional OpenSky username for higher rate limits
- `OPENSKY_PASSWORD`: Optional OpenSky password
- `PORT`: GraphQL server port (default: 4000)
- `HOST`: GraphQL server host (default: localhost)
- `VITE_GRAPHQL_URL`: GraphQL API URL for frontend (default: http://localhost:4000/graphql)

**Important:** The `.env` file is in `.gitignore` and will never be committed to Git or included in the Nix store. Bun loads `.env` files at runtime.

## License

[Add your license here]
