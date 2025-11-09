#!/usr/bin/env bash
# Apply ClickHouse database initialization
# Usage: ./scripts/apply-migrations.sh

set -e

if [ -z "$CLICKHOUSE_HOST" ]; then
    CLICKHOUSE_HOST="localhost"
fi

if [ -z "$CLICKHOUSE_PORT" ]; then
    CLICKHOUSE_PORT="9000"
fi

echo "Applying database initialization..."
clickhouse-client --host="$CLICKHOUSE_HOST" --port="$CLICKHOUSE_PORT" --multiquery < db/init-db.sql

echo "✅ Database initialized successfully!"
