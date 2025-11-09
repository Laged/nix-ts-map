-- H3 geospatial indexing migration
-- This migration adds H3 index columns and re-engineers the table for optimal performance

-- For existing databases: Add H3 columns
ALTER TABLE IF EXISTS flight_events
ADD COLUMN IF NOT EXISTS h3_res4 String,
ADD COLUMN IF NOT EXISTS h3_res6 String,
ADD COLUMN IF NOT EXISTS h3_res8 String;

-- Re-engineer the table to optimize ORDER BY key for H3 queries
-- This requires creating a new table and moving data

-- Step 1: Create new table with optimized structure
CREATE TABLE IF NOT EXISTS flight_events_new (
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
    source LowCardinality(String),
    
    -- H3 indexes
    h3_res4 String,
    h3_res6 String,
    h3_res8 String

) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (h3_res6, icao24, timestamp); -- Optimized for H3-based queries

-- Step 2: Move existing data (if any)
-- For fresh databases, this will be empty
INSERT INTO flight_events_new 
SELECT 
    icao24,
    timestamp,
    latitude,
    longitude,
    altitude,
    heading,
    groundSpeed,
    verticalRate,
    source,
    COALESCE(h3_res4, '') as h3_res4,
    COALESCE(h3_res6, '') as h3_res6,
    COALESCE(h3_res8, '') as h3_res8
FROM flight_events;

-- Step 3: Drop old table and rename new one
DROP TABLE IF EXISTS flight_events;
RENAME TABLE flight_events_new TO flight_events;

