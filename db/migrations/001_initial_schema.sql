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
    source LowCardinality(String) -- Good for repeated strings

) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp) -- Partition by month for efficient time-based queries
ORDER BY (icao24, timestamp); -- The primary index, crucial for performance

