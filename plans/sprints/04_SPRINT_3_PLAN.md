# Sprint 3 Plan: Data Ingestion Pipeline

**Goal:** To implement the core data pipeline that fetches flight data from external APIs, transforms it into our shared format, and ingests it into a local ClickHouse database.

**Holistic Perspective:** This sprint brings the project to life by establishing the flow of data. The scraper service is designed with modularity in mind, with a clear separation between provider-specific fetching logic and the core transformation/ingestion logic. By using the `@map/shared` types, we ensure the data being ingested is clean and consistent. The ClickHouse schema is designed for time-series data, using partitioning to ensure query performance as the dataset grows.

---

### Key Outcomes

1.  A `db/migrations/001_initial_schema.sql` file defining the first version of our `flight_events` table.
2.  A new `@map/scraper` package that can be run from the command line.
3.  The scraper successfully fetches data from at least one provider (e.g., OpenSky Network, which has a generous free tier).
4.  Data is transformed into the `FlightEvent` type from `@map/shared`.
5.  Transformed data is successfully inserted into the local ClickHouse `flight_events` table.

---

### Implementation Steps

1.  **ClickHouse Schema Definition:**
    *   Create the file `db/migrations/001_initial_schema.sql`.
    *   Define the `flight_events` table. The schema should directly correspond to the `FlightEvent` interface from `@map/shared`.
        ```sql
        CREATE TABLE flight_events (
            -- Core flight data
            icao24 String,
            timestamp DateTime,
            latitude Float64,
            longitude Float64,
            altitude Float64,
            heading Float64,
            groundSpeed Float64,
            verticalRate Float64,

            -- Metadata
            source LowCardinality(String) -- Good for repeated strings

        ) ENGINE = MergeTree()
        PARTITION BY toYYYYMM(timestamp) -- Partition by month for efficient time-based queries
        ORDER BY (icao24, timestamp); -- The primary index, crucial for performance
        ```
    *   Create a script (e.g., `scripts/apply-migrations.sh`) or document the command to apply this schema to the local ClickHouse server: `cat db/migrations/*.sql | clickhouse-client -m`.

2.  **Scraper Package Setup (`packages/map-scraper`):**
    *   Create the `packages/map-scraper` directory and initialize a Bun project (`bun init`). Name it `@map/scraper`.
    *   Add `@map/shared` to its dependencies (it will be linked by Bun workspaces).
    *   Install a ClickHouse client library (e.g., `@clickhouse/client-web` or `@clickhouse/client`).
    *   Install `zod` for environment variable validation.

3.  **Configuration (`src/config.ts`):**
    *   Define a schema using `zod` to parse and validate environment variables. This prevents runtime errors from missing configuration.
    *   Variables to include: `CLICKHOUSE_HOST`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, and a bounding box for the scraping area (e.g., `FINLAND_BOUNDS="60,20,70,30"`).
    *   Export a typed, validated `config` object.

4.  **Provider-Specific Logic (`src/providers/`):**
    *   Create a directory for providers.
    *   Start with `opensky.ts`. The OpenSky Network API is simple and doesn't require an API key for basic state vector fetching.
    *   Create a function `fetchOpenSkyData(bbox: BoundingBox): Promise<FlightEvent[]>`.
    *   Inside this function:
        *   Construct the API request URL using the bounding box.
        *   Use `fetch` to call the API.
        *   Parse the JSON response.
        *   Iterate through the list of states (aircraft).
        *   For each state, transform the raw array of data into a structured `FlightEvent` object, ensuring all fields match the shared type.
        *   Return the array of `FlightEvent` objects.

5.  **ClickHouse Writer (`src/writer.ts`):**
    *   Create a module to handle database interactions.
    *   Initialize a ClickHouse client instance using the validated config.
    *   Create an `insertFlightEvents(events: FlightEvent[]): Promise<void>` function.
    *   This function will take an array of `FlightEvent` objects and use the client's `insert` method to write them to the `flight_events` table in a single batch.

6.  **Main Scraper Loop (`src/index.ts`):**
    *   This is the entry point for the scraper service.
    *   Implement a main `scrape` function that:
        1.  Logs that a new scraping cycle is starting.
        2.  Calls `fetchOpenSkyData` (and other providers in the future).
        3.  Logs how many events were fetched.
        4.  If events were found, calls `insertFlightEvents` to save them to the database.
        5.  Logs that the cycle is complete.
    *   Use `setInterval` to call the `scrape` function at a regular interval (e.g., every 60 seconds).

7.  **Verification:**
    *   Start the local `clickhouse-server` (if not already running).
    *   Apply the initial schema migration.
    *   Run the scraper service: `bun run packages/map-scraper/src/index.ts`.
    *   Check the console logs to ensure it's running without errors.
    *   Open `clickhouse-client` and run `SELECT count() FROM flight_events;`. The count should increase after each scrape cycle.
    *   Run `SELECT * FROM flight_events LIMIT 10;` to inspect the inserted data and confirm it matches the expected format.
