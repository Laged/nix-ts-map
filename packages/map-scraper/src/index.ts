import { fetchOpenSkyData } from './providers/opensky';
import { createClickHouseClient, insertFlightEvents } from './writer';
import { config } from './config';

/**
 * Main scraping function
 * Fetches data from all providers and inserts into ClickHouse
 */
async function scrape(): Promise<void> {
  const startTime = Date.now();
  console.log(`[${new Date().toISOString()}] Starting scraping cycle...`);
  
  try {
    // Fetch data from OpenSky
    console.log('Fetching data from OpenSky Network...');
    const openSkyEvents = await fetchOpenSkyData(config.boundingBox, config.opensky);
    console.log(`Fetched ${openSkyEvents.length} events from OpenSky`);
    
    // Combine all events (in the future, we'll fetch from multiple providers)
    const allEvents = [...openSkyEvents];
    
    if (allEvents.length === 0) {
      console.log('No events to insert.');
      return;
    }
    
    // Insert into ClickHouse
    console.log(`Inserting ${allEvents.length} events into ClickHouse...`);
    const client = createClickHouseClient();
    await insertFlightEvents(client, allEvents);
    await client.close();
    
    const duration = Date.now() - startTime;
    console.log(`[${new Date().toISOString()}] Scraping cycle complete (${duration}ms)`);
  } catch (error) {
    console.error('Error during scraping cycle:', error);
    // Don't throw - we want the scraper to continue running
  }
}

/**
 * Main entry point
 */
async function main() {
  console.log('🚀 Flight Data Scraper');
  console.log(`Configuration:`);
  console.log(`  - ClickHouse: ${config.clickhouse.host}:${config.clickhouse.port}`);
  console.log(`  - Database: ${config.clickhouse.database}`);
  console.log(`  - Bounding Box: ${config.boundingBox.join(', ')}`);
  console.log(`  - Scrape Interval: ${config.scrapeIntervalSeconds}s`);
  console.log('');
  
  // Run initial scrape
  await scrape();
  
  // Schedule periodic scraping
  setInterval(async () => {
    await scrape();
  }, config.scrapeIntervalSeconds * 1000);
  
  console.log(`Scraper running. Will scrape every ${config.scrapeIntervalSeconds} seconds.`);
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down scraper...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\nShutting down scraper...');
  process.exit(0);
});

// Start the scraper
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});

