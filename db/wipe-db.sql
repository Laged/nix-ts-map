-- Wipe all ClickHouse tables and materialized views
-- This script drops everything to start fresh

-- Drop all materialized views (must be dropped before tables)
DROP VIEW IF EXISTS latest_flight_position_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r0_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r1_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r2_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r3_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r4_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r5_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r6_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r7_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r8_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r9_mv;
DROP VIEW IF EXISTS flights_per_hex_per_minute_r10_mv;

-- Drop all tables
DROP TABLE IF EXISTS flight_events;
DROP TABLE IF EXISTS latest_flight_positions;
DROP TABLE IF EXISTS flights_per_hex_per_minute;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r0;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r1;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r2;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r3;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r4;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r5;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r6;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r7;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r8;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r9;
DROP TABLE IF EXISTS flights_per_hex_per_minute_r10;

