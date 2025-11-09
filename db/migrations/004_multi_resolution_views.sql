-- Materialized views for multiple H3 resolutions
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

-- Resolution 6 (already exists in flight_events, but create view)
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

-- Resolution 8 (rename existing table/view to match pattern)
-- Note: The existing flights_per_hex_per_minute uses h3_res8, so we'll keep it
-- but we can also create r8-specific views if needed

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

