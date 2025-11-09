import { createClient, type ClickHouseClient } from '@clickhouse/client';

export interface Context {
  dbClient: ClickHouseClient;
}

/**
 * Create ClickHouse client for GraphQL context
 */
export function createDbClient(): ClickHouseClient {
  const host = process.env.CLICKHOUSE_HOST || 'localhost';
  const port = Number(process.env.CLICKHOUSE_PORT) || 8123;
  const username = process.env.CLICKHOUSE_USER || 'default';
  const password = process.env.CLICKHOUSE_PASSWORD || '';
  const database = process.env.CLICKHOUSE_DATABASE || 'default';

  return createClient({
    host: `http://${host}:${port}`,
    username,
    password,
    database,
  });
}

