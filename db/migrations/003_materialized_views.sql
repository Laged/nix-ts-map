-- Materialized views for pre-aggregated data
-- These views automatically update as new data is inserted

-- Latest Flight Position View
-- Provides the most recent position for every aircraft
CREATE TABLE IF NOT EXISTS latest_flight_positions (
    icao24 String,
    last_seen DateTime,
    latest_lat Float64,
    latest_lon Float64,
    latest_alt Float64
) ENGINE = AggregatingMergeTree()
ORDER BY icao24;

CREATE MATERIALIZED VIEW IF NOT EXISTS latest_flight_position_mv 
TO latest_flight_positions 
AS
SELECT
    icao24,
    max(timestamp) as last_seen,
    argMax(latitude, timestamp) as latest_lat,
    argMax(longitude, timestamp) as latest_lon,
    argMax(altitude, timestamp) as latest_alt
FROM flight_events
WHERE h3_res6 != '' -- Only process events with H3 indexes
GROUP BY icao24;

-- Flights Per Hex Per Minute View
-- Aggregates flight counts per H3 hexagon per minute
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute (
    h3_res8 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res8, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_mv 
TO flights_per_hex_per_minute 
AS
SELECT
    h3_res8,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res8 != '' -- Only process events with H3 indexes
GROUP BY h3_res8, minute;

