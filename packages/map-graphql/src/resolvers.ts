import { readFileSync } from 'fs';
import { join } from 'path';
import { GraphQLScalarType, Kind } from 'graphql';
import type { Resolvers } from './generated/graphql';
import type { Context } from './context';

/**
 * DateTime scalar resolver
 */
const DateTimeScalar = new GraphQLScalarType({
  name: 'DateTime',
  description: 'DateTime scalar type',
  serialize(value: unknown): number {
    if (value instanceof Date) {
      return Math.floor(value.getTime() / 1000);
    }
    if (typeof value === 'number') {
      return value;
    }
    throw new Error('DateTime cannot represent value: ' + value);
  },
  parseValue(value: unknown): Date {
    if (typeof value === 'number') {
      return new Date(value * 1000);
    }
    throw new Error('DateTime cannot parse value: ' + value);
  },
  parseLiteral(ast): Date {
    if (ast.kind === Kind.INT) {
      return new Date(parseInt(ast.value, 10) * 1000);
    }
    throw new Error('DateTime cannot parse literal: ' + ast);
  },
});

/**
 * GraphQL resolvers
 */
export const resolvers: Resolvers<Context> = {
  DateTime: DateTimeScalar,

  Query: {
    latestAircraftPositions: async (_, { bbox, since }, { dbClient }) => {
      const [minLat, minLon, maxLat, maxLon] = bbox;

      // Query ALL data without time filter for now
      const query = `
        SELECT 
          icao24,
          latest_lat as latitude,
          latest_lon as longitude,
          latest_alt as altitude,
          last_seen
        FROM latest_flight_positions FINAL
        WHERE latest_lat >= ${minLat}
          AND latest_lat <= ${maxLat}
          AND latest_lon >= ${minLon}
          AND latest_lon <= ${maxLon}
        ORDER BY last_seen DESC
      `;

      console.log('[GraphQL] Latest positions query:', query);

      const result = await dbClient.query({
        query,
        format: 'JSONEachRow',
      });

      const data = await result.json<Array<{
        icao24: string;
        latitude: number;
        longitude: number;
        altitude: number;
        last_seen: string;
      }>>();

      console.log('[GraphQL] Latest positions query result:', data.length, 'positions');
      if (data.length > 0) {
        console.log('[GraphQL] Sample position data:', data.slice(0, 3));
      }

      return data.map((row) => ({
        icao24: row.icao24,
        latitude: row.latitude,
        longitude: row.longitude,
        altitude: row.altitude,
        lastSeen: Math.floor(new Date(row.last_seen).getTime() / 1000),
      }));
    },

    hexGrid: async (_, { resolution, bbox, from, to }, { dbClient }) => {
      const [minLat, minLon, maxLat, maxLon] = bbox;
      
      // Map resolution to available H3 column
      // The materialized view uses h3_res8, so we'll use that for now
      // In the future, we could create separate views for different resolutions
      const h3ResColumn = 'h3_res8'; // Materialized view only has h3_res8

      // Query ALL data without time filters for now
      // Filter out invalid H3 indexes (like 'test' or empty strings)
      const query = `
        SELECT 
          ${h3ResColumn} as h3Index,
          uniqMerge(aircraft_count) as aircraftCount
        FROM flights_per_hex_per_minute FINAL
        WHERE ${h3ResColumn} != ''
          AND ${h3ResColumn} != 'test'
          AND length(${h3ResColumn}) > 0
        GROUP BY h3Index
        HAVING aircraftCount > 0
      `;

      console.log('[GraphQL] Hex grid query:', query);

      const result = await dbClient.query({
        query,
        format: 'JSONEachRow',
      });

      const data = await result.json<Array<{
        h3Index: string;
        aircraftCount: number;
      }>>();

      console.log('[GraphQL] Hex grid query result:', data.length, 'hexes');
      if (data.length > 0) {
        console.log('[GraphQL] Sample hex data:', data.slice(0, 3));
      }

      return data.map((row) => ({
        h3Index: row.h3Index,
        aircraftCount: row.aircraftCount,
      }));
    },

    flightStats: async (_, __, { dbClient }) => {
      const query = `
        SELECT 
          count() as totalEvents,
          uniq(icao24) as uniqueFlights
        FROM flight_events
      `;

      const result = await dbClient.query({
        query,
        format: 'JSONEachRow',
      });

      const data = await result.json<Array<{
        totalEvents: number;
        uniqueFlights: number;
      }>>();

      return {
        totalEvents: data[0]?.totalEvents || 0,
        uniqueFlights: data[0]?.uniqueFlights || 0,
      };
    },
  },
};

