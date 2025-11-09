# Sprint 4 Plan: Geospatial Indexing & Performance Optimization

**Goal:** To significantly enhance database query performance by enriching the data with H3 geospatial indexes and creating pre-aggregated materialized views for common query patterns.

**Holistic Perspective:** This sprint is purely focused on performance and scalability. While the application works without this, geospatial indexing is what will make it fast and interactive. By calculating H3 indexes during data ingestion, we offload the computational cost from query time to write time. The new table `ORDER BY` key will physically co-locate data for specific regions on disk, making queries that filter by area extremely fast. Materialized views act as automatic caches for aggregated data (like flight counts per hex), which is exactly what the frontend will need.

---

### Key Outcomes

1.  The `flight_events` table is augmented with columns for H3 indexes.
2.  The scraper is updated to calculate and insert H3 indexes for every event.
3.  The table's primary index (`ORDER BY` key) is updated to leverage H3 for performance.
4.  At least two materialized views (`flights_per_hex_mv`, `latest_flight_position_mv`) are created to pre-compute aggregations.
5.  Queries filtering by H3 index are demonstrably faster.

---

### Implementation Steps

1.  **H3 Library Integration:**
    *   In the `@map/scraper` package, add the `h3-js` library: `bun add h3-js`.
    *   In the `@map/shared` package, add the `H3Index` type alias if not already present, and consider adding a new interface for H3-enriched events.
        ```typescript
        // In @map/shared/types.ts
        export interface FlightEventWithH3 extends FlightEvent {
          h3_res4: H3Index;
          h3_res6: H3Index;
          h3_res8: H3Index;
        }
        ```

2.  **ClickHouse Schema Migration:**
    *   Create a new migration file: `db/migrations/002_h3_enrichment.sql`.
    *   **Add H3 Columns:** Alter the `flight_events` table to add string columns for the H3 indexes.
        ```sql
        ALTER TABLE flight_events
        ADD COLUMN h3_res4 String,
        ADD COLUMN h3_res6 String,
        ADD COLUMN h3_res8 String;
        ```
    *   **Re-engineer the Table (Important!):** To change the `ORDER BY` key, we must create a new table and move the data. This is a standard ClickHouse workflow.
        ```sql
        -- 1. Create a new table with the desired structure and order key
        CREATE TABLE flight_events_new (
            -- ... all columns from before ...
            h3_res4 String,
            h3_res6 String,
            h3_res8 String
        ) ENGINE = MergeTree()
        PARTITION BY toYYYYMM(timestamp)
        ORDER BY (h3_res6, icao24, timestamp); -- New, optimized order key!

        -- 2. Move the data
        INSERT INTO flight_events_new SELECT *, '', '', '' FROM flight_events;

        -- 3. Drop the old table and rename the new one
        DROP TABLE flight_events;
        RENAME TABLE flight_events_new TO flight_events;
        ```
    *   Update the migration script/documentation to handle this multi-step migration. For a fresh database, only the final `CREATE TABLE` statement is needed.

3.  **Update Scraper Logic:**
    *   In the `@map/scraper`'s data transformation logic (e.g., in `src/providers/opensky.ts`), import the `h3-js` library.
    *   After creating a `FlightEvent` object, use the latitude and longitude to calculate the H3 indexes for the chosen resolutions.
        ```typescript
        import * as h3 from 'h3-js';
        // ...
        const event: FlightEvent = { /* ... */ };
        const enrichedEvent: FlightEventWithH3 = {
          ...event,
          h3_res4: h3.latLngToCell(event.latitude, event.longitude, 4),
          h3_res6: h3.latLngToCell(event.latitude, event.longitude, 6),
          h3_res8: h3.latLngToCell(event.latitude, event.longitude, 8),
        };
        ```
    *   Update the ClickHouse writer function (`src/writer.ts`) to insert the new `FlightEventWithH3` objects, including the H3 columns.

4.  **Create Materialized Views:**
    *   Create a new migration file: `db/migrations/003_materialized_views.sql`.
    *   **Latest Flight Position:** This view provides the most recent update for every aircraft, perfect for the scatterplot layer.
        ```sql
        -- 1. Create the target table that will store the aggregated state
        CREATE TABLE latest_flight_positions (
            icao24 String,
            last_seen DateTime,
            latest_lat Float64,
            latest_lon Float64,
            latest_alt Float64
        ) ENGINE = AggregatingMergeTree();

        -- 2. Create the materialized view that feeds the table
        CREATE MATERIALIZED VIEW latest_flight_position_mv TO latest_flight_positions AS
        SELECT
            icao24,
            max(timestamp) as last_seen,
            argMax(latitude, timestamp) as latest_lat,
            argMax(longitude, timestamp) as latest_lon,
            argMax(altitude, timestamp) as latest_alt
        FROM flight_events
        GROUP BY icao24;
        ```
    *   **Flights Per Hex:** This view will power the H3 hexagon layer, showing flight density.
        ```sql
        CREATE TABLE flights_per_hex_per_minute (
            h3_res8 String,
            minute DateTime,
            aircraft_count AggregateFunction(uniq, String)
        ) ENGINE = AggregatingMergeTree()
        ORDER BY (h3_res8, minute);

        CREATE MATERIALIZED VIEW flights_per_hex_per_minute_mv TO flights_per_hex_per_minute AS
        SELECT
            h3_res8,
            toStartOfMinute(timestamp) AS minute,
            uniqState(icao24) as aircraft_count
        FROM flight_events
        GROUP BY h3_res8, minute;
        ```

5.  **Verification:**
    *   Clear the database and apply all migrations from scratch to ensure the process works.
    *   Run the scraper for a few minutes to populate the data.
    *   **Check Data:** `SELECT * FROM flight_events LIMIT 5;` to confirm H3 columns are filled.
    *   **Query Views:**
        *   `SELECT icao24, latest_lat, latest_lon FROM latest_flight_positions FINAL LIMIT 5;`
        *   `SELECT h3_res8, uniqMerge(aircraft_count) FROM flights_per_hex_per_minute FINAL GROUP BY h3_res8 LIMIT 10;`
    *   **Performance Test:** Run an `EXPLAIN` statement on a query that filters by a specific H3 index (e.g., `SELECT count() FROM flight_events WHERE h3_res6 = 'some_index'`). The query plan should show that it's using the primary index and reading a small number of granules.
