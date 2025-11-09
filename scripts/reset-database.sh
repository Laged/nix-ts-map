#!/usr/bin/env bash
# Reset ClickHouse database - drops all tables and materialized views
# Usage: ./scripts/reset-database.sh
#
# WARNING: This will delete ALL flight data and materialized views!
# Use this to start scraping from scratch.

set -e

if [ -z "$CLICKHOUSE_HOST" ]; then
    CLICKHOUSE_HOST="localhost"
fi

if [ -z "$CLICKHOUSE_PORT" ]; then
    CLICKHOUSE_PORT="9000"
fi

echo "========================================="
echo "⚠️  WARNING: This will delete ALL data!"
echo "========================================="
echo ""
echo "This script will:"
echo "  1. Drop all materialized views"
echo "  2. Drop all tables"
echo "  3. Clear ClickHouse data directory"
echo "  4. Re-apply all migrations"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "→ Dropping materialized views..."

# Drop all materialized views (must be dropped before tables)
clickhouse-client --host="$CLICKHOUSE_HOST" --port="$CLICKHOUSE_PORT" --multiquery <<EOF
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
EOF

echo "✓ Materialized views dropped"
echo ""

echo "→ Dropping tables..."

# Drop all tables
clickhouse-client --host="$CLICKHOUSE_HOST" --port="$CLICKHOUSE_PORT" --multiquery <<EOF
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
EOF

echo "✓ Tables dropped"
echo ""

echo "→ Clearing ClickHouse data directory..."
# Remove ClickHouse data directory (will be recreated on next start)
if [ -d "db/clickhouse-data" ]; then
    rm -rf db/clickhouse-data/*
    echo "✓ Data directory cleared"
else
    echo "⚠ Data directory not found (may not exist yet)"
fi
echo ""

echo "→ Re-applying migrations..."
# Re-apply all migrations
for migration in db/migrations/*.sql; do
    echo "  Applying $(basename $migration)..."
    clickhouse-client --host="$CLICKHOUSE_HOST" --port="$CLICKHOUSE_PORT" --multiquery < "$migration" || {
        echo "✗ Migration $(basename $migration) failed"
        exit 1
    }
done

echo ""
echo "========================================="
echo "✅ Database reset complete!"
echo "========================================="
echo ""
echo "All tables and materialized views have been dropped and recreated."
echo "You can now start scraping fresh data."

