# Sprint 6 Plan: Interactive Frontend Visualization

**Goal:** To build a single-page web application that visualizes the flight data on an interactive map, consuming data from the GraphQL API created in the previous sprint.

**Holistic Perspective:** This sprint is where the project becomes tangible and visual. We are building the primary user interface. The choice of React, Vite, and Deck.gl is deliberate: React for component-based UI, Vite for a fast development experience, and Deck.gl for high-performance, GPU-accelerated rendering of large datasets. The frontend is architected to be a pure consumer of the GraphQL API, which keeps it decoupled from the backend logic and database schema.

---

### Key Outcomes

1.  A new `@map/frontend` package set up as a Vite React-TS project.
2.  A full-screen map interface using `react-map-gl` and a base map provider like Mapbox.
3.  An `H3HexagonLayer` that visualizes flight density, colored based on data from the `hexGrid` GraphQL query.
4.  A `ScatterplotLayer` that displays the latest position of individual aircraft, fetched via the `latestAircraftPositions` query.
5.  Basic UI controls to filter the data (e.g., by time), which trigger new GraphQL queries.

---

### Implementation Steps

1.  **Package Setup (`packages/map-frontend`):**
    *   Use Vite to scaffold a new React with TypeScript project: `bun create vite packages/map-frontend --template react-ts`.
    *   Navigate into the new `packages/map-frontend` directory.
    *   Add dependencies:
        *   `deck.gl`: The core visualization library.
        *   `react-map-gl`: For the base map and Deck.gl integration with React.
        *   `@apollo/client`: The premier GraphQL client for React.
        *   `graphql`: Peer dependency for Apollo Client.
        *   `mapbox-gl`: Required by `react-map-gl` for the map rendering.
    *   Follow the instructions to set up a Mapbox account and get a public access token. Store this token in a `.env` file.

2.  **Apollo Client Configuration (`src/graphql/client.ts`):**
    *   Create a new file to configure the Apollo Client.
    *   Initialize `ApolloClient`, pointing it to the `map-graphql` server's endpoint (`http://localhost:4000`).
    *   Set up an in-memory cache.
        ```typescript
        import { ApolloClient, InMemoryCache } from '@apollo/client';

        export const client = new ApolloClient({
          uri: 'http://localhost:4000',
          cache: new InMemoryCache(),
        });
        ```
    *   Wrap the root `App` component in `App.tsx` with the `<ApolloProvider client={client}>`.

3.  **GraphQL Queries and Code Generation:**
    *   Create a `src/graphql/queries.ts` file.
    *   Define the `GET_HEX_GRID` and `GET_LATEST_POSITIONS` queries using the `gql` tag.
    *   Set up `graphql-codegen` for the frontend package, similar to the backend. This time, it will generate TypeScript types for the query results and React hooks (`useQuery`, `useSubscription`). This provides end-to-end type safety.

4.  **Main Map Component (`src/components/Map.tsx`):**
    *   This will be the main component of the application.
    *   Set up the `Map` component from `react-map-gl`, configuring its initial state (latitude, longitude, zoom) to be centered on Finland.
    *   Embed the `DeckGL` component as a child of the `Map` component to overlay the data layers.

5.  **Data Layers Implementation:**
    *   **Hexagon Layer:**
        *   In the `Map` component, use the generated `useGetHexGridQuery` hook to fetch density data.
        *   Create an instance of Deck.gl's `H3HexagonLayer`.
        *   Pass the fetched data to the layer's `data` prop.
        *   Use accessors like `getHexagon` (to get the `h3Index`) and `getFillColor` (to color the hex based on `aircraftCount`).
    *   **Scatterplot Layer:**
        *   Use the `useGetLatestPositionsQuery` hook.
        *   Create an instance of `ScatterplotLayer`.
        *   Pass the fetched data to its `data` prop.
        *   Use accessors like `getPosition` (to get `[longitude, latitude]`) and `getFillColor`.

6.  **UI Controls and Interactivity:**
    *   Add a simple component for filtering, e.g., a date range picker or a slider.
    *   Store the filter state (e.g., `from` and `to` dates) in React state.
    *   Pass this state as variables to the `useQuery` hooks.
    *   When the filter state changes, Apollo Client will automatically re-fetch the data with the new variables, and the map will update.

7.  **Putting It All Together (`src/App.tsx`):**
    *   Clear out the default Vite boilerplate.
    *   Render the `Map` component as the main element.
    *   Add the filter components.
    *   Apply some basic full-screen styling to make the map take up the entire viewport.

8.  **Verification:**
    *   Ensure the `map-graphql` and `clickhouse-server` are running.
    *   Run the frontend development server: `cd packages/map-frontend && bun dev`.
    *   Open the browser to the provided URL (e.g., `http://localhost:5173`).
    *   You should see a map of Finland with two layers of data: a hexagonal grid showing flight density and individual points for each aircraft.
    *   Interact with the filter controls and verify that the data on the map updates accordingly. Check the browser's network tab to see the GraphQL queries being made.
