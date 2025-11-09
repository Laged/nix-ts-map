# Sprint Plan Overview

This document outlines the development plan for the new flight tracking application, breaking down the work into manageable sprints. Each sprint builds upon the last, culminating in a fully functional, real-time flight tracking and visualization platform.

## Sprint 1: Project Foundation & Clean Environment

*   **Goal:** Set up a minimalistic, reproducible development environment using Nix. This ensures that all developers and CI/CD systems use the exact same dependencies.
*   **Key Tasks:**
    *   Initialize a new, clean project repository.
    *   Create a `flake.nix` file based on a recent NixOS stable channel (e.g., `nixos-25.11`).
    *   Define a development shell (`nix develop`) providing the latest stable versions of:
        *   Bun (as the primary TypeScript/JavaScript runtime and package manager)
        *   Node.js (for compatibility if needed)
        *   TypeScript
        *   ClickHouse (for local database instances)
    *   Establish a basic monorepo project structure using `packages/` for scoped modules (e.g., `packages/map-shared`, `packages/map-scraper`).

## Sprint 2: Shared Data Interfaces

*   **Goal:** Define the core data structures for the application in a shared package. This enforces type safety and consistency across the scraper, database, API, and frontend.
*   **Key Tasks:**
    *   Create a `map-shared` package for common types.
    *   Define a `FlightEvent` interface with core location and time data: `timestamp`, `latitude`, `longitude`, `altitude`, `source` (e.g., 'fr24', 'opensky'), and a flexible `details` object.
    *   Define a comprehensive `FlightDetails` interface, harmonizing the rich metadata available from both FlightRadar24 and OpenSky Network APIs (e.g., callsign, aircraft model, origin, destination).
    *   Configure TypeScript paths or local package linking to allow seamless imports from `map-shared` in other packages.

## Sprint 3: Data Ingestion Pipeline

*   **Goal:** Implement the end-to-end data flow from external APIs to the ClickHouse database.
*   **Key Tasks:**
    *   **Scraper Service (`map-scraper`):**
        *   Implement provider-specific logic for fetching data from FR24 and OpenSky.
        *   Create a configuration system (e.g., using a config file or environment variables) to manage API keys, scraping intervals, and enabled providers.
        *   Develop a transformation layer to convert raw API data into the shared `FlightEvent` and `FlightDetails` formats.
    *   **ClickHouse Schema:**
        *   Design an `ingest_flight_events` table in ClickHouse optimized for fast writes.
        *   Create materialized views for later data enrichment (e.g., adding H3 indexes).
    *   **Ingestion Logic:**
        *   Implement a writer service that efficiently batch-inserts transformed data into the ClickHouse `ingest_flight_events` table.

## Sprint 4: Geospatial Indexing & Performance Optimization

*   **Goal:** Optimize the database for high-performance geospatial and temporal queries, which are critical for a responsive frontend.
*   **Key Tasks:**
    *   **H3 Indexing:**
        *   Integrate an H3 library (e.g., `h3-js`) into the data pipeline.
        *   Modify the ClickHouse schema to include columns for H3 indexes at various resolutions (e.g., `h3_res4`, `h3_res8`).
        *   Update the ingestion process to calculate and store these H3 indexes for each flight event.
    *   **Database Performance:**
        *   Fine-tune the ClickHouse table engine, `ORDER BY` key, and `PARTITION BY` key for common query patterns (e.g., `ORDER BY (h3_res8, timestamp)`).
    *   **Pre-aggregation:**
        *   Create materialized views to pre-calculate key metrics, such as:
            *   `flights_per_hex_per_hour`: Count of flight events within each H3 hexagon for each hour.
            *   `latest_flight_position`: The most recent known position for every active flight.

## Sprint 5: Type-Safe GraphQL API

*   **Goal:** Expose the flight data through a flexible, performant, and type-safe GraphQL API.
*   **Key Tasks:**
    *   **GraphQL Server (`map-graphql`):**
        *   Set up a GraphQL server (e.g., using Apollo Server with Bun).
    *   **Schema Definition:**
        *   Define a clear GraphQL schema (`typeDefs`) for querying flights, flight paths, and aggregated hexagonal grid data.
        *   Use tools like GraphQL Code Generator to automatically create TypeScript types from the schema, ensuring type safety between the API and its consumers.
    *   **Resolvers:**
        *   Implement resolvers that construct efficient ClickHouse queries based on GraphQL arguments like:
            *   Time range (`from`, `to`).
            *   Geographic bounds (`bbox`).
            *   A list of H3 tile IDs.
            *   Filters on flight details (e.g., aircraft type).

## Sprint 6: Interactive Frontend Visualization

*   **Goal:** Create a dynamic, GPU-accelerated map visualization of the flight data.
*   **Key Tasks:**
    *   **React Application (`map-frontend`):**
        *   Set up a new React application using Vite for a fast development experience.
        *   Integrate Deck.gl for high-performance, WebGL-based data visualization.
    *   **Map Interface:**
        *   Render a base map (e.g., from Mapbox or another provider) centered on a default area (e.g., Finland).
        *   Implement a `H3HexagonLayer` to display the H3 grid, coloring hexagons based on flight density fetched from the GraphQL API.
        *   Implement a `ScatterplotLayer` to show the latest position of individual flights.
    *   **Data-Driven UI:**
        *   Use a GraphQL client (e.g., Apollo Client) to connect the React app to the `map-graphql` service.
        *   Create UI controls (e.g., date pickers, bounding box selectors) that dynamically update the GraphQL query variables to filter and view the data.

## Sprint 7: Real-time Updates with Subscriptions

*   **Goal:** Enable live updates on the frontend, so that new data appears on the map automatically as it is scraped and ingested.
*   **Key Tasks:**
    *   **GraphQL Subscriptions:**
        *   Implement GraphQL subscriptions in the `map-graphql` service to push notifications when new data is available.
    *   **Frontend Integration:**
        *   Update the frontend Apollo Client to handle subscriptions, receiving new flight data in real-time.
        *   Update the Deck.gl layers dynamically with the incoming data, providing a smooth, live-updating user experience.
    *   **End-to-End Automation:**
        *   Verify that the entire pipeline is automated: the scraper runs on its schedule, data is ingested, and the frontend updates without user intervention.

## Sprint 8: Tooling, Testing, and Local Development

*   **Goal:** Finalize the development environment, add comprehensive testing to ensure reliability, and streamline the local development workflow.
*   **Key Tasks:**
    *   **Local Development Workflow:**
        *   Create a `process-compose.yml` (or similar) configuration to orchestrate running all services (`map-scraper`, `map-graphql`, `map-frontend`, `clickhouse`) locally with a single command.
    *   **Automated Testing:**
        *   Configure the `flake.nix` to run tests for all packages via a single `nix test` command.
        *   Implement unit tests for critical business logic (e.g., data transformations, resolver logic).
        *   Create integration tests to verify the data pipeline from end to end.
    *   **CI/CD (Future Planning):**
        *   Outline a plan for setting up a GitHub Actions workflow to automatically run tests on every push.
        *   Begin planning for containerization (e.g., with Docker) and future deployment strategies.
