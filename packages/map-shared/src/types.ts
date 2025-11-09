/**
 * Data source identifier for flight data.
 * Used to track the origin of data for debugging and source-specific logic.
 */
export type DataSource = 'fr24' | 'opensky' | 'adsbexchange' | 'unknown';

/**
 * H3 geospatial index type alias.
 * H3 indexes are strings representing hexagonal cells at various resolutions.
 */
export type H3Index = string;

/**
 * FlightEvent represents a single point-in-time snapshot of a flight's position and state.
 * 
 * This interface is designed to harmonize data from multiple sources:
 * - OpenSky Network API: State vectors from /api/states/all
 * - FlightRadar24 API: Flight positions from their API
 * 
 * All fields are normalized to common units and formats regardless of source.
 */
export interface FlightEvent {
  /** ICAO 24-bit address, the most reliable aircraft identifier */
  icao24: string;
  
  /** Unix timestamp in seconds */
  timestamp: number;
  
  /** Latitude in decimal degrees (-90 to 90) */
  latitude: number;
  
  /** Longitude in decimal degrees (-180 to 180) */
  longitude: number;
  
  /** Altitude in meters above sea level */
  altitude: number;
  
  /** Heading in degrees (0-360, where 0 is North) */
  heading: number;
  
  /** Ground speed in meters per second */
  groundSpeed: number;
  
  /** Vertical rate in meters per second (positive = climbing, negative = descending) */
  verticalRate: number;
  
  /** Source of the data */
  source: DataSource;
}

/**
 * Base flight details interface containing common metadata across all sources.
 * This structure is extensible with source-specific extensions.
 */
export interface BaseFlightDetails {
  /** ICAO 24-bit address */
  icao24: string;
  
  /** Aircraft callsign (e.g., "DLH123") */
  callsign: string | null;
  
  /** Aircraft registration (e.g., "D-ABCE") */
  registration: string | null;
  
  /** Aircraft model/type (e.g., "Boeing 737-800") */
  aircraftModel: string | null;
  
  /** Origin airport IATA code (e.g., "JFK") */
  originAirportIATA: string | null;
  
  /** Destination airport IATA code (e.g., "LAX") */
  destinationAirportIATA: string | null;
}

/**
 * FlightRadar24-specific flight details extension.
 * Contains additional metadata available from the FR24 API.
 */
export interface Fr24FlightDetails extends BaseFlightDetails {
  /** Flight number (e.g., "DL123") */
  flightNumber: string | null;
  
  /** Airline name */
  airline: string | null;
  
  /** Aircraft age in years */
  aircraftAge: number | null;
}

/**
 * OpenSky Network-specific flight details extension.
 * Contains additional metadata available from the OpenSky API.
 */
export interface OpenSkyFlightDetails extends BaseFlightDetails {
  /** Whether the aircraft is on ground */
  onGround: boolean;
  
  /** Squawk code */
  squawk: string | null;
  
  /** Whether the position was obtained from a surface position report */
  spi: boolean;
  
  /** Position source (0 = ADS-B, 1 = ASTERIX, 2 = MLAT) */
  positionSource: number | null;
}

/**
 * Union type of all possible flight details.
 * Allows type-safe handling of source-specific extensions.
 */
export type FlightDetails = BaseFlightDetails | Fr24FlightDetails | OpenSkyFlightDetails;

/**
 * FlightEvent enriched with H3 geospatial indexes at all resolutions (r0-r10).
 * Used for efficient spatial queries and aggregations.
 * All resolutions are calculated at write-time by the scraper.
 */
export interface FlightEventWithH3 extends FlightEvent {
  /** H3 index at resolution 0 (coarsest, ~1107km hexagons) */
  h3_res0: H3Index;
  /** H3 index at resolution 1 (~418km hexagons) */
  h3_res1: H3Index;
  /** H3 index at resolution 2 (~158km hexagons) */
  h3_res2: H3Index;
  /** H3 index at resolution 3 (~59km hexagons) */
  h3_res3: H3Index;
  /** H3 index at resolution 4 (~22km hexagons) */
  h3_res4: H3Index;
  /** H3 index at resolution 5 (~8km hexagons) */
  h3_res5: H3Index;
  /** H3 index at resolution 6 (~3km hexagons) */
  h3_res6: H3Index;
  /** H3 index at resolution 7 (~1km hexagons) */
  h3_res7: H3Index;
  /** H3 index at resolution 8 (~0.5km hexagons) */
  h3_res8: H3Index;
  /** H3 index at resolution 9 (~0.2km hexagons) */
  h3_res9: H3Index;
  /** H3 index at resolution 10 (finest, ~0.07km hexagons) */
  h3_res10: H3Index;
}

