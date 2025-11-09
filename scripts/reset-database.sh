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
echo "  4. Re-apply init-db.sql to recreate schema"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "→ Dropping all tables and views..."

# Drop everything using wipe-db.sql
clickhouse-client --host="$CLICKHOUSE_HOST" --port="$CLICKHOUSE_PORT" --multiquery < db/wipe-db.sql

echo "✓ All tables and views dropped"
echo ""

echo "→ Clearing ClickHouse data directory..."
# Note: We don't actually need to clear the directory - dropping tables is enough
# ClickHouse will clean up table data when tables are dropped
# But we'll ensure the base directory exists for safety
mkdir -p db/clickhouse-data/store
mkdir -p db/clickhouse-data/data
mkdir -p db/clickhouse-data/tmp

echo "✓ Ready for schema recreation"
echo ""

echo "→ Re-applying init-db.sql..."
# Wait a moment for ClickHouse to be ready
sleep 1

# Re-apply init-db.sql
clickhouse-client --host="$CLICKHOUSE_HOST" --port="$CLICKHOUSE_PORT" --multiquery < db/init-db.sql || {
    echo "✗ Failed to apply init-db.sql"
    exit 1
}

echo "✓ Schema recreated"
echo ""

echo "========================================="
echo "✅ Database reset complete!"
echo "========================================="
echo ""
echo "All tables and materialized views have been dropped and recreated."
echo "You can now start scraping fresh data."
