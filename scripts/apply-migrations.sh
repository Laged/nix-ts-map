#!/usr/bin/env bash
# Apply ClickHouse migrations
# Usage: ./scripts/apply-migrations.sh

set -e

if [ -z "$CLICKHOUSE_HOST" ]; then
    CLICKHOUSE_HOST="localhost"
fi

if [ -z "$CLICKHOUSE_PORT" ]; then
    CLICKHOUSE_PORT="9000"
fi

echo "Applying ClickHouse migrations..."
cat db/migrations/*.sql | clickhouse-client --host="$CLICKHOUSE_HOST" --port="$CLICKHOUSE_PORT" -m

echo "✅ Migrations applied successfully!"

