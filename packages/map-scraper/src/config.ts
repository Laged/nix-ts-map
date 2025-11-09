import { z } from 'zod';

// Load environment variables using Bun's built-in .env support
// This loads from .env file at runtime, not at build time
// Bun automatically loads .env files from the project root
if (typeof Bun !== 'undefined') {
  // Bun automatically loads .env, but we can explicitly load it
  // The .env file is loaded at runtime and never committed to git
}

/**
 * Bounding box coordinates: [minLat, minLon, maxLat, maxLon]
 */
export type BoundingBox = [number, number, number, number];

/**
 * Configuration schema for the scraper service
 * Uses zod for runtime validation of environment variables
 */
const configSchema = z.object({
  // ClickHouse connection settings
  CLICKHOUSE_HOST: z.string().default('localhost'),
  CLICKHOUSE_PORT: z.coerce.number().default(8123),
  CLICKHOUSE_USER: z.string().default('default'),
  CLICKHOUSE_PASSWORD: z.string().default(''),
  CLICKHOUSE_DATABASE: z.string().default('default'),
  
  // Bounding box for scraping area: "minLat,minLon,maxLat,maxLon"
  // Default: Finland area (approximately)
  FINLAND_BOUNDS: z.string().default('60,20,70,30'),
  
  // Scraping interval in seconds
  SCRAPE_INTERVAL_SECONDS: z.coerce.number().default(60),
  
  // OpenSky API credentials (optional for basic usage)
  // OpenSky allows anonymous access but authenticated users get higher rate limits
  OPENSKY_USERNAME: z.string().optional(),
  OPENSKY_PASSWORD: z.string().optional(),
});

/**
 * Parse and validate environment variables
 */
function parseBoundingBox(boundsStr: string): BoundingBox {
  const parts = boundsStr.split(',').map(Number);
  if (parts.length !== 4 || parts.some(isNaN)) {
    throw new Error(`Invalid bounding box format: ${boundsStr}. Expected "minLat,minLon,maxLat,maxLon"`);
  }
  const [minLat, minLon, maxLat, maxLon] = parts;
  
  // Validate bounds
  if (minLat >= maxLat || minLon >= maxLon) {
    throw new Error(`Invalid bounding box: min must be less than max`);
  }
  if (minLat < -90 || maxLat > 90 || minLon < -180 || maxLon > 180) {
    throw new Error(`Invalid bounding box: coordinates out of range`);
  }
  
  return [minLat, minLon, maxLat, maxLon];
}

/**
 * Validated configuration object
 * This validates all environment variables at runtime using zod
 * Missing required variables will throw an error
 */
export const config = (() => {
  try {
    const raw = configSchema.parse(process.env);
    return {
      clickhouse: {
        host: raw.CLICKHOUSE_HOST,
        port: raw.CLICKHOUSE_PORT,
        username: raw.CLICKHOUSE_USER,
        password: raw.CLICKHOUSE_PASSWORD,
        database: raw.CLICKHOUSE_DATABASE,
      },
      boundingBox: parseBoundingBox(raw.FINLAND_BOUNDS),
      scrapeIntervalSeconds: raw.SCRAPE_INTERVAL_SECONDS,
      opensky: {
        username: raw.OPENSKY_USERNAME,
        password: raw.OPENSKY_PASSWORD,
      },
    };
  } catch (error) {
    if (error instanceof z.ZodError) {
      console.error('❌ Configuration validation failed:');
      error.errors.forEach((err) => {
        console.error(`  - ${err.path.join('.')}: ${err.message}`);
      });
      console.error('\nPlease check your .env file or environment variables.');
      console.error('See .env.example for required configuration.');
    }
    throw error;
  }
})();

