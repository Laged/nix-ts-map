# Sprint 5 Plan: Type-Safe GraphQL API

**Goal:** To create a GraphQL API server that exposes the flight data stored in ClickHouse, providing a flexible and efficient data-fetching layer for the frontend.

**Holistic Perspective:** The GraphQL API acts as the crucial intermediary between the database and the frontend. It decouples them, allowing the frontend to request exactly the data it needs without knowing the underlying database schema. We will use `graphql-codegen` to automatically generate TypeScript types from our GraphQL schema. This creates a strong, type-safe contract, ensuring that the resolvers (server-side) and the queries (client-side) are always in sync. This sprint lays the groundwork for a powerful and maintainable API.

---

### Key Outcomes

1.  A new `@map/graphql` package containing a runnable Apollo Server.
2.  A GraphQL schema defining queries for flight events and hexagonal grid data.
3.  Automatically generated TypeScript types for the schema, ensuring type safety in resolvers.
4.  Resolvers that connect to ClickHouse, execute efficient queries, and return data to the client.
5.  The API is runnable and testable via a GraphQL playground.

---

### Implementation Steps

1.  **Package Setup (`packages/map-graphql`):**
    *   Create the `packages/map-graphql` directory and initialize a Bun project (`bun init`). Name it `@map/graphql`.
    *   Add dependencies:
        *   `@apollo/server`: The core GraphQL server library.
        *   `graphql`: Peer dependency for Apollo Server.
        *   `@map/shared`: To reference our core types if needed.
        *   `@clickhouse/client`: To connect to the database.
    *   Add dev dependencies for code generation:
        *   `@graphql-codegen/cli`
        *   `@graphql-codegen/typescript`
        *   `@graphql-codegen/typescript-resolvers`

2.  **GraphQL Schema Definition (`src/schema.graphql`):**
    *   Create a dedicated `.graphql` file to define the schema. This is cleaner than embedding it in TypeScript strings.
    *   Define the core types and queries. The queries should reflect the needs of the planned frontend.
        ```graphql
        # In src/schema.graphql

        scalar DateTime # Custom scalar for timestamp

        type Query {
          """
          Fetches the most recent known position for all aircraft within a given time window and bounding box.
          """
          latestAircraftPositions(bbox: [Float!]!, since: DateTime!): [AircraftPosition!]

          """
          Fetches aggregated flight density for a hexagonal grid.
          """
          hexGrid(resolution: Int!, bbox: [Float!]!, from: DateTime!, to: DateTime!): [HexGridCell!]
        }

        type AircraftPosition {
          icao24: String!
          latitude: Float!
          longitude: Float!
          altitude: Float!
          lastSeen: DateTime!
        }

        type HexGridCell {
          h3Index: String!
          aircraftCount: Int!
        }
        ```

3.  **Code Generation Setup:**
    *   Create a `codegen.ts` (or `.yml`) file at the package root.
    *   Configure it to:
        *   Read the `src/schema.graphql` file.
        *   Generate TypeScript types into `src/generated/graphql.ts`.
        *   Use the `typescript` and `typescript-resolvers` plugins.
    *   Add a script to `package.json`: `"codegen": "graphql-codegen"`.
    *   Run `bun run codegen` to generate the types for the first time.

4.  **Resolver Implementation (`src/resolvers.ts`):**
    *   Import the generated `Resolvers` type: `import { Resolvers } from './generated/graphql.ts'`.
    *   Create the resolver map, which will now be fully typed.
        ```typescript
        export const resolvers: Resolvers = {
          Query: {
            latestAircraftPositions: async (_, { bbox, since }, { dbClient }) => {
              // Use the 'latest_flight_positions' materialized view
              const query = `
                SELECT icao24, latest_lat, latest_lon, latest_alt, last_seen
                FROM latest_flight_positions FINAL
                WHERE last_seen >= toDateTime(${since}) AND ... (bbox logic)
              `;
              // Execute query and return data mapped to the GraphQL type
            },
            hexGrid: async (_, { resolution, bbox, from, to }, { dbClient }) => {
              // Use the 'flights_per_hex_per_minute' materialized view
              const h3ResColumn = `h3_res${resolution}`;
              const query = `
                SELECT ${h3ResColumn} as h3Index, uniqMerge(aircraft_count) as aircraftCount
                FROM flights_per_hex_per_minute FINAL
                WHERE minute BETWEEN ... AND ... (bbox logic)
                GROUP BY h3Index
              `;
              // Execute query and return data
            },
          },
          // ... other resolvers for custom scalars like DateTime
        };
        ```

5.  **Server Entrypoint (`src/index.ts`):**
    *   Import `ApolloServer` and your schema and resolvers.
    *   Create a context function that initializes a ClickHouse client and passes it to the resolvers. This allows for efficient connection management.
    *   Initialize and start the Apollo Server.
        ```typescript
        import { ApolloServer } from '@apollo/server';
        import { startStandaloneServer } from '@apollo/server/standalone';
        // ...
        const server = new ApolloServer({
          typeDefs, // from schema.graphql
          resolvers,
        });

        const { url } = await startStandaloneServer(server, {
          listen: { port: 4000 },
          context: async () => ({
            dbClient: getDbClient(), // Your function to get a DB client
          }),
        });
        console.log(`🚀 Server ready at ${url}`);
        ```

6.  **Verification:**
    *   Run the code generator: `bun run codegen`.
    *   Start the GraphQL server: `bun run src/index.ts`.
    *   Open the browser to `http://localhost:4000`. Apollo Server's sandbox should load.
    *   Execute the `latestAircraftPositions` and `hexGrid` queries with appropriate variables.
    *   Verify that the server responds with JSON data fetched from your local ClickHouse database. Check for any errors in the server console.
