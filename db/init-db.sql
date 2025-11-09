-- Initialize ClickHouse database schema
-- This script creates all tables and materialized views

-- Initial schema for flight_events table
-- This table stores point-in-time snapshots of flight positions and states
CREATE TABLE IF NOT EXISTS flight_events (
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
    source LowCardinality(String), -- Good for repeated strings

    -- H3 geospatial indexes at all resolutions (r0-r10)
    -- All resolutions are calculated at write-time by the scraper
    h3_res0 String,
    h3_res1 String,
    h3_res2 String,
    h3_res3 String,
    h3_res4 String,
    h3_res5 String,
    h3_res6 String,
    h3_res7 String,
    h3_res8 String,
    h3_res9 String,
    h3_res10 String

) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp) -- Partition by month for efficient time-based queries
ORDER BY (icao24, timestamp); -- The primary index, crucial for performance

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

-- Flights Per Hex Per Minute View (legacy, using r8)
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

-- Materialized views for multiple H3 resolutions (r0-r10)
-- These views aggregate flight counts per hexagon per minute at different resolutions
-- Data is aggregated at write-time, so queries are fast

-- Resolution 0 (coarsest)
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r0 (
    h3_res0 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res0, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r0_mv 
TO flights_per_hex_per_minute_r0 
AS
SELECT
    h3_res0,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res0 != '' AND h3_res0 != 'test'
GROUP BY h3_res0, minute;

-- Resolution 1
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r1 (
    h3_res1 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res1, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r1_mv 
TO flights_per_hex_per_minute_r1 
AS
SELECT
    h3_res1,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res1 != '' AND h3_res1 != 'test'
GROUP BY h3_res1, minute;

-- Resolution 2
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r2 (
    h3_res2 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res2, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r2_mv 
TO flights_per_hex_per_minute_r2 
AS
SELECT
    h3_res2,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res2 != '' AND h3_res2 != 'test'
GROUP BY h3_res2, minute;

-- Resolution 3
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r3 (
    h3_res3 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res3, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r3_mv 
TO flights_per_hex_per_minute_r3 
AS
SELECT
    h3_res3,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res3 != '' AND h3_res3 != 'test'
GROUP BY h3_res3, minute;

-- Resolution 4
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r4 (
    h3_res4 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res4, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r4_mv 
TO flights_per_hex_per_minute_r4 
AS
SELECT
    h3_res4,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res4 != '' AND h3_res4 != 'test'
GROUP BY h3_res4, minute;

-- Resolution 5
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r5 (
    h3_res5 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res5, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r5_mv 
TO flights_per_hex_per_minute_r5 
AS
SELECT
    h3_res5,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res5 != '' AND h3_res5 != 'test'
GROUP BY h3_res5, minute;

-- Resolution 6
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r6 (
    h3_res6 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res6, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r6_mv 
TO flights_per_hex_per_minute_r6 
AS
SELECT
    h3_res6,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res6 != '' AND h3_res6 != 'test'
GROUP BY h3_res6, minute;

-- Resolution 7
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r7 (
    h3_res7 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res7, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r7_mv 
TO flights_per_hex_per_minute_r7 
AS
SELECT
    h3_res7,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res7 != '' AND h3_res7 != 'test'
GROUP BY h3_res7, minute;

-- Resolution 8
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r8 (
    h3_res8 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res8, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r8_mv 
TO flights_per_hex_per_minute_r8 
AS
SELECT
    h3_res8,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res8 != '' AND h3_res8 != 'test'
GROUP BY h3_res8, minute;

-- Resolution 9
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r9 (
    h3_res9 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res9, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r9_mv 
TO flights_per_hex_per_minute_r9 
AS
SELECT
    h3_res9,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res9 != '' AND h3_res9 != 'test'
GROUP BY h3_res9, minute;

-- Resolution 10
CREATE TABLE IF NOT EXISTS flights_per_hex_per_minute_r10 (
    h3_res10 String,
    minute DateTime,
    aircraft_count AggregateFunction(uniq, String)
) ENGINE = AggregatingMergeTree()
ORDER BY (h3_res10, minute);

CREATE MATERIALIZED VIEW IF NOT EXISTS flights_per_hex_per_minute_r10_mv 
TO flights_per_hex_per_minute_r10 
AS
SELECT
    h3_res10,
    toStartOfMinute(timestamp) AS minute,
    uniqState(icao24) as aircraft_count
FROM flight_events
WHERE h3_res10 != '' AND h3_res10 != 'test'
GROUP BY h3_res10, minute;

