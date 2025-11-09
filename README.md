# nix-ts-map

A real-time flight tracking and visualization platform built with Nix, TypeScript, ClickHouse, GraphQL, and React. This project provides a complete pipeline from scraping flight data to rendering it on an interactive, GPU-accelerated map.

## Overview

This monorepo contains:
- **`@map/shared`**: Shared TypeScript types for flight data
- **`@map/scraper`**: Service that fetches flight data from FR24/OpenSky APIs
- **`@map/graphql`**: GraphQL API server with type-safe resolvers
- **`@map/frontend`**: React application with Deck.gl visualization
- **`db/`**: ClickHouse migrations and schema definitions

## Prerequisites

- **Nix** with Flakes enabled
  ```bash
  # Enable flakes if not already enabled
  mkdir -p ~/.config/nix
  echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
  ```

## Development Setup

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
   - Node.js 22
   - ClickHouse (server & client)
   - process-compose (service orchestration)

3. **Install dependencies:**
   ```bash
   bun install
   ```

4. **Set up ClickHouse database:**
   ```bash
   # Apply migrations
   cat db/migrations/*.sql | clickhouse-client -m
   ```

5. **Configure environment variables:**
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env and fill in your values:
   # - VITE_MAPBOX_TOKEN: Get from [Mapbox](https://www.mapbox.com/)
   # - OPENSKY_USERNAME/PASSWORD: Optional, for higher rate limits
   #   Register at https://opensky-network.org/accounts/login/
   # - Other values: Use defaults or customize as needed
   ```
   
   **Important:** The `.env` file is already in `.gitignore` and will never be committed to git or included in the Nix store. Bun loads `.env` files at runtime.

## Running the Application

### Option 1: Process Compose (Recommended)

Run all services with a single command:

```bash
nix develop
process-compose up
```

This starts:
- ClickHouse server
- GraphQL API server (port 4000)
- Scraper service
- Frontend dev server (port 5173)

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

## Testing

### Run All Tests

```bash
# Interactive testing
bun test --workspaces

# Full validation in clean Nix environment
nix flake check
# or
nix test
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
│   └── migrations/        # ClickHouse schema migrations
├── plans/                 # Sprint planning documents
└── process-compose.yml    # Service orchestration config
```

## Key Features

- **Real-time Updates**: GraphQL subscriptions push new flight data to the frontend
- **Geospatial Indexing**: H3 hexagon indexing for efficient spatial queries
- **GPU-Accelerated Rendering**: Deck.gl for high-performance visualization
- **Type Safety**: End-to-end TypeScript types from database to frontend
- **Reproducible Environment**: Nix ensures consistent development setup

## Development Workflow

1. Make changes to any package
2. Tests run automatically on save (if configured)
3. Services hot-reload where supported
4. Run `nix flake check` before committing to ensure everything works

## Troubleshooting

### ClickHouse Connection Issues
- Ensure ClickHouse server is running: `clickhouse-server`
- Check connection settings in `.env` files

### Port Conflicts
- GraphQL API: Change port in `packages/map-graphql/src/index.ts`
- Frontend: Change port in `packages/map-frontend/vite.config.ts`

### Nix Issues
- Update flake inputs: `nix flake update`
- Clear Nix store if needed: `nix-collect-garbage`

## License

[Add your license here]

