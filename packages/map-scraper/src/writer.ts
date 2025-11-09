import { createClient, type ClickHouseClient } from '@clickhouse/client';
import type { FlightEvent } from '@map/shared';
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
 * @param events Array of FlightEvent objects to insert
 */
export async function insertFlightEvents(
  client: ClickHouseClient,
  events: FlightEvent[]
): Promise<void> {
  if (events.length === 0) {
    return;
  }
  
  try {
    await client.insert({
      table: 'flight_events',
      values: events.map((event) => ({
        icao24: event.icao24,
        timestamp: new Date(event.timestamp * 1000), // Convert Unix timestamp to Date
        latitude: event.latitude,
        longitude: event.longitude,
        altitude: event.altitude,
        heading: event.heading,
        groundSpeed: event.groundSpeed,
        verticalRate: event.verticalRate,
        source: event.source,
      })),
      format: 'JSONEachRow',
    });
  } catch (error) {
    console.error('Error inserting flight events:', error);
    throw error;
  }
}

