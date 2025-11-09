import { createClient, type ClickHouseClient } from '@clickhouse/client';
import type { FlightEventWithH3 } from '@map/shared';
import { config } from './config';

/**
 * Initialize ClickHouse client
 */
export function createClickHouseClient(): ClickHouseClient {
  return createClient({
    host: `http://${config.clickhouse.host}:${config.clickhouse.port}`,
    username: config.clickhouse.username,
    password: config.clickhouse.password,
    database: config.clickhouse.database,
  });
}

/**
 * Insert flight events into ClickHouse database
 * 
 * @param client ClickHouse client instance
 * @param events Array of FlightEventWithH3 objects to insert
 */
export async function insertFlightEvents(
  client: ClickHouseClient,
  events: FlightEventWithH3[]
): Promise<void> {
  if (events.length === 0) {
    return;
  }
  
  try {
    // Format timestamp as 'YYYY-MM-DD HH:MM:SS' string for ClickHouse DateTime
    // ClickHouse DateTime can parse this format from JSONEachRow
    const formatTimestamp = (unixSeconds: number): string => {
      const date = new Date(unixSeconds * 1000);
      const year = date.getUTCFullYear();
      const month = String(date.getUTCMonth() + 1).padStart(2, '0');
      const day = String(date.getUTCDate()).padStart(2, '0');
      const hours = String(date.getUTCHours()).padStart(2, '0');
      const minutes = String(date.getUTCMinutes()).padStart(2, '0');
      const seconds = String(date.getUTCSeconds()).padStart(2, '0');
      return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
    };

    await client.insert({
      table: 'flight_events',
      values: events.map((event) => ({
        icao24: event.icao24,
        // ClickHouse DateTime expects format 'YYYY-MM-DD HH:MM:SS' when using JSONEachRow
        timestamp: formatTimestamp(event.timestamp),
        latitude: event.latitude,
        longitude: event.longitude,
        altitude: event.altitude,
        heading: event.heading,
        groundSpeed: event.groundSpeed,
        verticalRate: event.verticalRate,
        source: event.source,
        h3_res4: event.h3_res4,
        h3_res6: event.h3_res6,
        h3_res8: event.h3_res8,
      })),
      format: 'JSONEachRow',
    });
  } catch (error) {
    console.error('Error inserting flight events:', error);
    throw error;
  }
}

