-- H3 geospatial indexing migration
-- This migration adds H3 index columns to the flight_events table
-- Note: ClickHouse doesn't support ALTER TABLE IF EXISTS, so we just use ALTER TABLE

-- Step 1: Add H3 columns for all resolutions (r0-r10) if they don't exist
-- IF NOT EXISTS is supported for ADD COLUMN
-- All resolutions are calculated at write-time by the scraper
ALTER TABLE flight_events
ADD COLUMN IF NOT EXISTS h3_res0 String,
ADD COLUMN IF NOT EXISTS h3_res1 String,
ADD COLUMN IF NOT EXISTS h3_res2 String,
ADD COLUMN IF NOT EXISTS h3_res3 String,
ADD COLUMN IF NOT EXISTS h3_res4 String,
ADD COLUMN IF NOT EXISTS h3_res5 String,
ADD COLUMN IF NOT EXISTS h3_res6 String,
ADD COLUMN IF NOT EXISTS h3_res7 String,
ADD COLUMN IF NOT EXISTS h3_res8 String,
ADD COLUMN IF NOT EXISTS h3_res9 String,
ADD COLUMN IF NOT EXISTS h3_res10 String;

