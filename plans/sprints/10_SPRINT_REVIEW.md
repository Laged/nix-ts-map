# Sprint Review: Project Status & Future Work

## Overview

This document provides a concise summary of completed and planned sprints for the nix-ts-map project—a real-time flight tracking and visualization platform built with Nix, TypeScript, ClickHouse, GraphQL, and React.

## Completed Sprints (1-6)

### ✅ Sprint 1: Project Foundation
**Status:** ✅ **COMPLETED**  
**Goal:** Set up clean Nix development environment with Bun, Node.js, TypeScript, and ClickHouse

**What was done:**
- Created `flake.nix` with NixOS 24.11 stable channel
- Set up development shell with Bun, Node.js 22, ClickHouse, and process-compose
- Established monorepo structure with `packages/` directory
- Configured `nix run` to orchestrate all services via process-compose
- Added comprehensive logging to all services

### ✅ Sprint 2: Shared Data Interfaces
**Status:** ✅ **COMPLETED**  
**Goal:** Create `@map/shared` package with `FlightEvent` and `FlightDetails` types

**What was done:**
- Created `@map/shared` package with TypeScript types
- Defined `FlightEvent` interface harmonizing data from multiple sources
- Defined `FlightDetails` interfaces with source-specific extensions (FR24, OpenSky)
- Created `FlightEventWithH3` interface with all H3 resolutions (r0-r10)
- Configured workspace package linking

### ✅ Sprint 3: Data Ingestion Pipeline
**Status:** ✅ **COMPLETED**  
**Goal:** Build scraper service for FR24/OpenSky APIs → ClickHouse ingestion

**What was done:**
- Implemented OpenSky Network API provider (`packages/map-scraper/src/providers/opensky.ts`)
- Created configuration system with environment variable validation using Zod
- Implemented ClickHouse writer with batch insertion
- Set up ClickHouse schema with `flight_events` table
- Added secure environment variable handling (never committed to Git or Nix store)
- Created `.env.example` file with all required variables

### ✅ Sprint 4: Geospatial Indexing
**Status:** ✅ **COMPLETED**  
**Goal:** Add H3 indexing and materialized views for performance

**What was done:**
- Added H3 columns for all resolutions (r0-r10) to `flight_events` table
- Integrated `h3-js` library into scraper to calculate all resolutions at write-time
- Created materialized views for all resolutions (r0-r10)
- Each resolution has its own materialized view table for efficient querying
- All H3 calculations happen at write-time, no runtime conversion needed

### ✅ Sprint 5: Type-Safe GraphQL API
**Status:** ✅ **COMPLETED**  
**Goal:** Create GraphQL server with type-safe resolvers for flight data

**What was done:**
- Created GraphQL server using Apollo Server with Fastify
- Defined GraphQL schema with `hexGrid`, `latestAircraftPositions`, and `flightStats` queries
- Implemented type-safe resolvers with TypeScript code generation
- Added CORS support for frontend communication
- Resolvers query the correct resolution table directly (no H3 conversion needed)
- All aggregation happens at write-time in ClickHouse

### ✅ Sprint 6: Interactive Frontend
**Status:** ✅ **COMPLETED**  
**Goal:** Build React + Deck.gl visualization with H3 hexagons and scatterplot layers

**What was done:**
- Created React application with Vite
- Integrated Deck.gl with H3HexagonLayer and ScatterplotLayer
- Switched from Mapbox to MapLibre for open-source map rendering
- Implemented resolution slider (r0-r10) with dynamic hex polyfill loading
- Added blue heatmap visualization for flight trails
- Added white scatterplot layer for latest flight positions
- Implemented flight statistics display (Flights, Trails, Hexes)
- Centered map on Finland with proper bounds
- Added WebGL error handling for Firefox compatibility
- Removed all debug console logs for production readiness

## Future Sprints (7-8)

### ⏳ Sprint 7: Real-time Subscriptions
**Status:** Not yet implemented  
**Goal:** Implement GraphQL subscriptions for live updates

**What needs to be done:**
- Add GraphQL subscription support to Apollo Server
- Create subscription resolvers for real-time flight position updates
- Update frontend to use subscriptions instead of polling
- Handle connection management and reconnection logic

### ⏳ Sprint 8: Tooling & Testing
**Status:** Partially implemented  
**Goal:** Add process-compose orchestration and comprehensive test suite

**What was done:**
- ✅ Process-compose orchestration via `nix run`
- ✅ Service dependency management
- ✅ Comprehensive logging setup

**What needs to be done:**
- Add comprehensive test suite using `bun test`
- Unit tests for critical logic in each package
- Integration tests for GraphQL API
- End-to-end tests for frontend
- Configure `nix flake check` to run all tests

## Key Technologies

- **Nix/NixOS 24.11**: Reproducible development environment
- **Bun**: TypeScript runtime and package manager
- **ClickHouse**: Time-series database for flight events
- **GraphQL**: Type-safe API layer
- **React + Deck.gl**: GPU-accelerated visualization
- **H3**: Geospatial indexing for efficient queries (all resolutions r0-r10 precomputed)
- **MapLibre**: Open-source map rendering

## Current Architecture

1. **Scraper** (`@map/scraper`): Fetches data from OpenSky API, calculates all H3 resolutions at write-time, inserts into ClickHouse
2. **Database** (`db/migrations/`): ClickHouse schema with `flight_events` table and materialized views for all resolutions
3. **GraphQL API** (`@map/graphql`): Type-safe API that queries the correct resolution table directly
4. **Frontend** (`@map/frontend`): React app with Deck.gl visualization, resolution slider, and real-time updates via polling

## Next Steps

1. Implement GraphQL subscriptions (Sprint 7) for true real-time updates
2. Add comprehensive test suite (Sprint 8)
3. Consider adding FlightRadar24 API provider
4. Add historical data scraping capabilities
5. Implement time-based filtering in frontend
6. Add flight detail popups on click
