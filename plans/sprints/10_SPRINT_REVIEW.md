# Sprint Review: Project Status & Future Work

## Overview

This document provides a concise summary of the planned sprints for the nix-ts-map project—a real-time flight tracking and visualization platform built with Nix, TypeScript, ClickHouse, GraphQL, and React.

## Planned Sprints (1-8)

### ✅ Sprint 1: Project Foundation
**Status:** Not yet implemented  
**Goal:** Set up clean Nix development environment with Bun, Node.js, TypeScript, and ClickHouse

### ✅ Sprint 2: Shared Data Interfaces
**Status:** Not yet implemented  
**Goal:** Create `@map/shared` package with `FlightEvent` and `FlightDetails` types

### ✅ Sprint 3: Data Ingestion Pipeline
**Status:** Not yet implemented  
**Goal:** Build scraper service for FR24/OpenSky APIs → ClickHouse ingestion

### ✅ Sprint 4: Geospatial Indexing
**Status:** Not yet implemented  
**Goal:** Add H3 indexing and materialized views for performance

### ✅ Sprint 5: Type-Safe GraphQL API
**Status:** Not yet implemented  
**Goal:** Create GraphQL server with type-safe resolvers for flight data

### ✅ Sprint 6: Interactive Frontend
**Status:** Not yet implemented  
**Goal:** Build React + Deck.gl visualization with H3 hexagons and scatterplot layers

### ✅ Sprint 7: Real-time Subscriptions
**Status:** Not yet implemented  
**Goal:** Implement GraphQL subscriptions for live updates

### ✅ Sprint 8: Tooling & Testing
**Status:** Not yet implemented  
**Goal:** Add process-compose orchestration and comprehensive test suite

## Next Steps

All sprints are ready to be implemented sequentially. The project structure and dependencies are defined in the sprint plans. Implementation should begin with Sprint 1 (flake.nix setup) and proceed through each sprint in order.

## Key Technologies

- **Nix/NixOS 25.11**: Reproducible development environment
- **Bun**: TypeScript runtime and package manager
- **ClickHouse**: Time-series database for flight events
- **GraphQL**: Type-safe API layer
- **React + Deck.gl**: GPU-accelerated visualization
- **H3**: Geospatial indexing for efficient queries

