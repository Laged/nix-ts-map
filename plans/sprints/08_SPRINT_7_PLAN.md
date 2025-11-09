# Sprint 7 Plan: Real-time Updates & Subscriptions

**Goal:** To transform the application from a request-response model to a real-time platform by implementing GraphQL subscriptions. New flight data will appear on the map automatically as it's ingested.

**Holistic Perspective:** This sprint delivers the "wow" factor and completes the core vision of a live flight tracker. Implementing subscriptions requires coordination across the stack. The scraper needs a way to notify the backend that new data has arrived. The GraphQL server needs to handle WebSocket connections and push updates to clients. The frontend needs to listen for these pushes and update the UI without full reloads. We will start with a simple notification system and in-memory pub/sub for simplicity, which can be scaled up later if needed.

---

### Key Outcomes

1.  The GraphQL server supports subscriptions over WebSockets.
2.  A new `onAircraftPositionsUpdate` subscription is added to the GraphQL schema.
3.  The scraper service triggers this subscription after successfully ingesting new data.
4.  The frontend uses the `useSubscription` hook to listen for updates.
5.  The Deck.gl layers on the map update dynamically as new data arrives, without requiring a manual refresh.

---

### Implementation Steps

1.  **GraphQL Server Enhancements (`@map/graphql`):**
    *   **Add Dependencies:** Install libraries for WebSocket handling: `graphql-ws` and `ws`.
    *   **Create a PubSub Engine:** For this sprint, a simple in-memory engine is sufficient.
        ```typescript
        // In a new file, e.g., src/pubsub.ts
        import { PubSub } from 'graphql-subscriptions';
        export const pubsub = new PubSub();
        export const NEW_DATA_TOPIC = 'NEW_AIRCRAFT_DATA';
        ```
    *   **Update Schema:** Add a `Subscription` type to `src/schema.graphql`.
        ```graphql
        type Subscription {
          onAircraftPositionsUpdate: [AircraftPosition!]
        }
        ```
        Run the `codegen` script to update the generated types.
    *   **Update Resolvers:** Add the subscription resolver.
        ```typescript
        // In src/resolvers.ts
        import { pubsub, NEW_DATA_TOPIC } from './pubsub';

        export const resolvers: Resolvers = {
          Query: { /* ... */ },
          Subscription: {
            onAircraftPositionsUpdate: {
              subscribe: () => pubsub.asyncIterator([NEW_DATA_TOPIC]),
            },
          },
          // ...
        };
        ```
    *   **Enable WebSockets on the Server:** Modify `src/index.ts` to create both an HTTP server and a WebSocket server, and have them work together with Apollo Server. The `graphql-ws` documentation provides a clear recipe for this.

2.  **Scraper-to-API Notification:**
    *   The simplest way to trigger the subscription is for the scraper to notify the GraphQL server after a successful database write.
    *   **Add a Mutation (Recommended):** Add a simple mutation to the GraphQL schema.
        ```graphql
        type Mutation {
          _triggerDataUpdate: Boolean
        }
        ```
    *   The resolver for this mutation will fetch the latest data from the DB and then publish it.
        ```typescript
        // In resolvers.ts
        Mutation: {
          _triggerDataUpdate: async (_, __, { dbClient }) => {
            // 1. Fetch the latest data that was just ingested
            const latestData = await dbClient.query(...);
            // 2. Publish it to the subscription topic
            pubsub.publish(NEW_DATA_TOPIC, { onAircraftPositionsUpdate: latestData });
            return true;
          }
        }
        ```
    *   **Update Scraper:** In `@map/scraper`, after the `insertFlightEvents` function completes successfully, make an HTTP POST request to the GraphQL endpoint to execute the `_triggerDataUpdate` mutation.

3.  **Frontend Subscription Integration (`@map/frontend`):**
    *   **Add Dependencies:** Install libraries for WebSocket link in Apollo Client: `@apollo/client/link/ws` and `graphql-ws`.
    *   **Update Apollo Client:** Modify `src/graphql/client.ts` to create a "split" link. This link will direct queries and mutations over HTTP, but subscriptions over WebSockets. The Apollo Client documentation has a standard recipe for this.
    *   **Update GraphQL Queries:** Add the `ON_AIRCRAFT_UPDATE` subscription to `src/graphql/queries.ts`. Run codegen to get the `useOnAircraftUpdateSubscription` hook.
    *   **Implement in Component:** In the `Map.tsx` component:
        *   Call the `useOnAircraftUpdateSubscription` hook.
        *   Provide an `onData` callback. When the subscription pushes new data, this callback will fire.
        *   Inside the callback, you need to merge the new data with the existing data. The most robust way is to use the Apollo Client cache's `updateQuery` function to intelligently merge the new positions into the cache, which will cause the `useQuery` hook to return the updated list and re-render the layer.

4.  **Verification:**
    *   Run the entire stack: `clickhouse-server`, `map-graphql`, `map-scraper`, and `map-frontend`.
    *   Open the application in your browser. You should see the initial data load.
    *   Wait for the scraper's next cycle to complete (e.g., 60 seconds).
    *   **Observe the map:** When the scraper finishes its run, you should see new points appear on the map, or existing points move, without any user interaction or page reload.
    *   Check the browser's network tab to confirm the WebSocket connection is active.
    *   Check the server logs to see the subscription trigger and data push.
