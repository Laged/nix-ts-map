/**
 * Generate hex polyfill files for Finland using H3
 *
 * This script generates hex_polyfill_r*.json files for resolutions 0-10.
 * Only generates files that don't already exist (to avoid regenerating large files).
 *
 * Usage: bun run scripts/generate-hex-polyfill.ts
 * Or: nix run .#gen-hexes
 */

import { cellToLatLng, polygonToCells, latLngToCell } from 'h3-js';
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';

// Finland polygon coordinates [lon, lat] pairs
// This is a simplified polygon covering Finland's bounding box
const FINLAND_POLYGON: [number, number][] = [
  [19.0, 59.5],  // Southwest
  [31.5, 59.5],  // Southeast
  [31.5, 70.1],  // Northeast
  [19.0, 70.1],  // Northwest
  [19.0, 59.5],  // Close polygon
];

// Finland centroid (approximate)
const FINLAND_CENTROID: [number, number] = [25.0, 64.5]; // [lon, lat]

interface HexCell {
  hex_id: string;
  resolution: number;
  center_lat: number;
  center_lon: number;
}

function generatePolyfillForResolution(resolution: number): HexCell[] {
  console.log(`Generating resolution ${resolution}...`);

  // Convert polygon to h3-js format [lat, lon] pairs
  // FINLAND_POLYGON is [lon, lat], so we need to swap to [lat, lon]
  const h3Polygon = FINLAND_POLYGON.map(([lon, lat]) => [lat, lon]);

  // Get cells using polyfill
  let hexIds: Set<string>;
  try {
    const cells = polygonToCells([h3Polygon], resolution);
    hexIds = new Set(cells);
  } catch (error) {
    console.warn(`  Polyfill returned 0 cells for r${resolution}, using fallback`);
    hexIds = new Set();
  }

  // Fallback for coarse resolutions: add centroid + vertices
  if (hexIds.size === 0 || resolution <= 2) {
    // Add centroid (FINLAND_CENTROID is [lon, lat], so swap to [lat, lon])
    const centroidHex = latLngToCell(FINLAND_CENTROID[1], FINLAND_CENTROID[0], resolution);
    hexIds.add(centroidHex);

    // Add vertices (skip last point as it's duplicate of first)
    for (const [lon, lat] of FINLAND_POLYGON.slice(0, -1)) {
      const vertexHex = latLngToCell(lat, lon, resolution);
      hexIds.add(vertexHex);
    }
  }

  // Convert to HexCell objects with centers
  const hexCells: HexCell[] = Array.from(hexIds).map((hexId) => {
    // Use cellToLatLng to get the actual center point
    // cellToLatLng returns [lat, lng] tuple
    const [lat, lng] = cellToLatLng(hexId);
    return {
      hex_id: hexId,
      resolution,
      center_lat: lat,
      center_lon: lng,
    };
  });

  console.log(`  Generated ${hexCells.length} hexes`);
  return hexCells;
}

async function main() {
  console.log('Generating Finland hex polyfill for resolutions 0-10...\n');

  // Output directory
  const outputDir = join(process.cwd(), 'packages/map-frontend/public');
  mkdirSync(outputDir, { recursive: true });

  let generatedCount = 0;
  let skippedCount = 0;

  // Generate for each resolution
  for (let resolution = 0; resolution <= 10; resolution++) {
    const outputPath = join(outputDir, `hex_polyfill_r${resolution}.json`);

    // Skip if file already exists (especially for large r8, r9, r10)
    if (existsSync(outputPath)) {
      console.log(`Resolution ${resolution}: File already exists, skipping...`);
      skippedCount++;
      continue;
    }

    const hexCells = generatePolyfillForResolution(resolution);

    // Write to JSON file
    writeFileSync(outputPath, JSON.stringify(hexCells, null, 2));
    console.log(`  Saved to ${outputPath}\n`);
    generatedCount++;
  }

  console.log('✓ Polyfill generation complete!');
  console.log(`  Generated: ${generatedCount} files`);
  console.log(`  Skipped: ${skippedCount} files (already exist)`);
  console.log('\nNote: r8, r9, and r10 files are large (>100MB) and excluded from git.');
  console.log('      They can be generated locally if needed for higher resolution visualization.');
}

main().catch((error) => {
  console.error('Error generating hex polyfill:', error);
  process.exit(1);
});

