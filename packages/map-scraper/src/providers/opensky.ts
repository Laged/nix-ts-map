import type { FlightEvent, DataSource } from '@map/shared';
import type { BoundingBox } from '../config';

/**
 * OpenSky Network API response structure
 * See: https://openskynetwork.github.io/opensky-api/rest.html#all-state-vectors
 */
interface OpenSkyStateVector {
  0: string;  // icao24
  1: string;  // callsign (can be null)
  2: string;  // origin_country
  3: number;  // time_position (Unix timestamp, can be null)
  4: number;  // last_contact (Unix timestamp)
  5: number;  // longitude (can be null)
  6: number;  // latitude (can be null)
  7: number;  // baro_altitude (can be null)
  8: boolean; // on_ground
  9: number;  // velocity (m/s, can be null)
  10: number; // true_track (degrees, can be null)
  11: number; // vertical_rate (m/s, can be null)
  12: number; // sensors (array of sensor IDs, can be null)
  13: number; // geo_altitude (can be null)
  14: string; // squawk (can be null)
  15: boolean; // spi (special position indicator)
  16: number; // position_source (0=ADS-B, 1=ASTERIX, 2=MLAT)
}

interface OpenSkyResponse {
  time: number;
  states: OpenSkyStateVector[] | null;
}

/**
 * Fetch flight data from OpenSky Network API
 * 
 * API Documentation: https://openskynetwork.github.io/opensky-api/rest.html#all-state-vectors
 * 
 * @param bbox Bounding box [minLat, minLon, maxLat, maxLon]
 * @returns Array of FlightEventWithH3 objects (enriched with H3 indexes)
 */
export async function fetchOpenSkyData(bbox: BoundingBox): Promise<FlightEventWithH3[]> {
  const [minLat, minLon, maxLat, maxLon] = bbox;
  
  // OpenSky API expects: lamin, lomin, lamax, lomax
  const url = `https://opensky-network.org/api/states/all?lamin=${minLat}&lomin=${minLon}&lamax=${maxLat}&lomax=${maxLon}`;
  
  try {
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`OpenSky API error: ${response.status} ${response.statusText}`);
    }
    
    const data: OpenSkyResponse = await response.json();
    
    if (!data.states || data.states.length === 0) {
      return [];
    }
    
    // Transform OpenSky state vectors to FlightEventWithH3 objects
    const events: FlightEventWithH3[] = data.states
      .filter((state) => {
        // Filter out invalid states (missing position data)
        return (
          state[5] !== null && // longitude
          state[6] !== null && // latitude
          state[3] !== null    // time_position
        );
      })
      .map((state): FlightEventWithH3 => {
        const icao24 = state[0];
        const timestamp = state[3] || state[4]; // Use time_position or fallback to last_contact
        const longitude = state[5]!;
        const latitude = state[6]!;
        const altitude = state[13] ?? state[7] ?? 0; // Prefer geo_altitude, fallback to baro_altitude
        const heading = state[10] ?? 0; // true_track
        const groundSpeed = state[9] ?? 0; // velocity in m/s
        const verticalRate = state[11] ?? 0; // vertical_rate in m/s
        
        // Calculate H3 indexes at multiple resolutions
        const h3_res4 = h3.latLngToCell(latitude, longitude, 4);
        const h3_res6 = h3.latLngToCell(latitude, longitude, 6);
        const h3_res8 = h3.latLngToCell(latitude, longitude, 8);
        
        return {
          icao24,
          timestamp,
          latitude,
          longitude,
          altitude,
          heading,
          groundSpeed,
          verticalRate,
          source: 'opensky' as DataSource,
          h3_res4,
          h3_res6,
          h3_res8,
        };
      });
    
    return events;
  } catch (error) {
    console.error('Error fetching OpenSky data:', error);
    throw error;
  }
}

