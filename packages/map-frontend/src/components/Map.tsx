import { useQuery } from '@apollo/client';
import { DeckGL } from '@deck.gl/react';
import { H3HexagonLayer } from '@deck.gl/geo-layers';
import { ScatterplotLayer } from '@deck.gl/layers';
import { Map as MapLibreMap } from 'react-map-gl/maplibre';
import { GET_LATEST_POSITIONS, GET_HEX_GRID, GET_FLIGHT_STATS } from '../graphql/queries';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useState, useMemo, useEffect } from 'react';

// Finland bounds from shared constants
const FINLAND_BOUNDS = {
  minLat: 59.5,
  maxLat: 70.1,
  minLon: 19.0,
  maxLon: 31.5,
};

// Calculate center and zoom to show all of Finland
const calculateFinlandViewState = () => {
  const centerLon = (FINLAND_BOUNDS.minLon + FINLAND_BOUNDS.maxLon) / 2;
  const centerLat = (FINLAND_BOUNDS.minLat + FINLAND_BOUNDS.maxLat) / 2;
  
  // Calculate zoom level to fit Finland bounds
  // Approximate calculation: zoom level based on bounding box size
  const latDiff = FINLAND_BOUNDS.maxLat - FINLAND_BOUNDS.minLat;
  const lonDiff = FINLAND_BOUNDS.maxLon - FINLAND_BOUNDS.minLon;
  const maxDiff = Math.max(latDiff, lonDiff);
  
  // Rough zoom calculation: smaller area = higher zoom
  // Finland spans about 10.6 degrees lat and 12.5 degrees lon
  // For a good fit, we want zoom around 5-6
  const zoom = Math.max(4, Math.min(7, 8 - Math.log2(maxDiff)));
  
  return {
    longitude: centerLon,
    latitude: centerLat,
    zoom: zoom,
    pitch: 0,
    bearing: 0,
  };
};

const INITIAL_VIEW_STATE = calculateFinlandViewState();

export function FlightMap() {
  const [viewState, setViewState] = useState(INITIAL_VIEW_STATE);
  const [baseHexGrid, setBaseHexGrid] = useState<Array<{ h3Index: string; aircraftCount: number }>>([]);
  const [resolution, setResolution] = useState(3); // Default to r3

  // Load cached hex polyfill data based on selected resolution
  useEffect(() => {
    fetch(`/hex_polyfill_r${resolution}.json`)
      .then((res) => {
        if (!res.ok) {
          throw new Error(`HTTP error! status: ${res.status}`);
        }
        return res.json();
      })
      .then((data: Array<{ hex_id: string; resolution: number; center_lat: number; center_lon: number }>) => {
        console.log('[FlightMap] Loaded hex polyfill data:', data.length, 'hexes');
        setBaseHexGrid(
          data.map((hex) => ({
            h3Index: hex.hex_id,
            aircraftCount: 0, // Will be updated when data is available
          }))
        );
      })
      .catch((err) => {
        console.error(`[FlightMap] Failed to load hex polyfill cache for resolution ${resolution}:`, err);
        // Set empty array on error to prevent rendering issues
        setBaseHexGrid([]);
      });
  }, [resolution]);

  // Calculate bounding box for Finland
  const bbox: [number, number, number, number] = [
    FINLAND_BOUNDS.minLat,
    FINLAND_BOUNDS.minLon,
    FINLAND_BOUNDS.maxLat,
    FINLAND_BOUNDS.maxLon,
  ];
  const now = Math.floor(Date.now() / 1000);
  const oneHourAgo = now - 3600;

  // Fetch latest positions
  const { data: positionsData, loading: positionsLoading, error: positionsError } = useQuery(GET_LATEST_POSITIONS, {
    variables: {
      bbox,
      since: oneHourAgo,
    },
    pollInterval: 60000, // Poll every 60 seconds
    errorPolicy: 'all', // Continue even if there's an error
  });

  // Fetch hex grid data
  const { data: hexGridData, loading: hexGridLoading, error: hexGridError } = useQuery(GET_HEX_GRID, {
    variables: {
      resolution: resolution,
      bbox,
      from: oneHourAgo,
      to: now,
    },
    pollInterval: 60000,
    errorPolicy: 'all',
  });

  // Debug logging for query results (using useEffect instead of deprecated callbacks)
  useEffect(() => {
    if (positionsData) {
      console.log('[FlightMap] Latest positions query completed:', positionsData?.latestAircraftPositions?.length || 0, 'positions');
    }
    if (positionsError) {
      console.error('[FlightMap] Latest positions query error:', positionsError);
    }
  }, [positionsData, positionsError]);

  useEffect(() => {
    if (hexGridData) {
      console.log('[FlightMap] Hex grid query completed:', hexGridData?.hexGrid?.length || 0, 'hexes');
    }
    if (hexGridError) {
      console.error('[FlightMap] Hex grid query error:', hexGridError);
    }
  }, [hexGridData, hexGridError]);

  // Fetch flight statistics
  const { data: statsData, loading: statsLoading } = useQuery(GET_FLIGHT_STATS, {
    pollInterval: 30000, // Poll every 30 seconds
    errorPolicy: 'all',
  });

  const stats = statsData?.flightStats;

  // Filter out invalid H3 indexes and prepare hex grid data
  const hexGridDataFiltered = (hexGridData?.hexGrid || []).filter(
    (d: { h3Index: string; aircraftCount: number }) => d.h3Index && d.h3Index !== 'test' && d.h3Index.length > 0
  );

  // Debug logging
  useEffect(() => {
    console.log('[FlightMap] Resolution:', resolution);
    console.log('[FlightMap] Base hex grid count:', baseHexGrid.length);
    console.log('[FlightMap] Hex grid data filtered count:', hexGridDataFiltered.length);
    console.log('[FlightMap] Latest positions count:', positionsData?.latestAircraftPositions?.length || 0);
    if (hexGridDataFiltered.length > 0) {
      const maxCount = Math.max(...hexGridDataFiltered.map((d: { h3Index: string; aircraftCount: number }) => d.aircraftCount));
      const minCount = Math.min(...hexGridDataFiltered.map((d: { h3Index: string; aircraftCount: number }) => d.aircraftCount));
      console.log('[FlightMap] Aircraft count range:', { min: minCount, max: maxCount });
    }
  }, [resolution, baseHexGrid.length, hexGridDataFiltered.length, positionsData?.latestAircraftPositions?.length]);

  // Create a map of h3Index to aircraftCount for quick lookup
  const dataMap = useMemo(() => {
    const map = new Map<string, number>();
    hexGridDataFiltered.forEach((d: { h3Index: string; aircraftCount: number }) => {
      map.set(d.h3Index, d.aircraftCount);
    });
    console.log('[FlightMap] Data map size:', map.size);
    return map;
  }, [hexGridDataFiltered]);

  // Calculate max aircraft count for heatmap normalization
  const maxAircraftCount = useMemo(() => {
    if (hexGridDataFiltered.length === 0) return 1;
    const max = Math.max(...hexGridDataFiltered.map((d: { h3Index: string; aircraftCount: number }) => d.aircraftCount));
    console.log('[FlightMap] Max aircraft count for heatmap:', max);
    return max || 1;
  }, [hexGridDataFiltered]);

  // Merge base hex grid with data
  const mergedHexGrid = useMemo(() => {
    const merged = baseHexGrid.map((hex: { h3Index: string; aircraftCount: number }) => ({
      ...hex,
      aircraftCount: dataMap.get(hex.h3Index) || 0,
    }));
    console.log('[FlightMap] Merged hex grid count:', merged.length);
    return merged;
  }, [baseHexGrid, dataMap]);

  const layers = [
    // Base H3 Hexagon Layer (gray, almost transparent) - shows all hexes even without data
    new H3HexagonLayer({
      id: 'h3-hexagon-base-layer',
      data: mergedHexGrid,
      getHexagon: (d) => d.h3Index,
      getFillColor: (d: { h3Index: string; aircraftCount: number }) => {
        const count = d.aircraftCount || 0;
        if (count > 0) {
          // Blue heatmap: gray (no data) to increasingly blue and opaque (max flights)
          // Normalize count to 0-1 range based on max count
          const intensity = Math.min(count / maxAircraftCount, 1);
          // Blue gradient: from light gray-blue to deep blue
          // R: decreases from 128 to 0 (darker blue)
          // G: decreases from 128 to 100 (darker blue)
          // B: increases from 128 to 255 (more blue)
          // A: increases from 80 to 255 (more opaque)
          return [
            Math.floor(128 * (1 - intensity)), // Red: 128 -> 0
            Math.floor(128 * (1 - intensity) + 100 * intensity), // Green: 128 -> 100
            Math.floor(128 + 127 * intensity), // Blue: 128 -> 255
            Math.floor(80 + 175 * intensity), // Alpha: 80 -> 255 (more opaque)
          ];
        } else {
          // Gray, almost invisible for hexes without data
          return [128, 128, 128, 20];
        }
      },
      getElevation: (d) => (d.aircraftCount || 0) * 100,
      elevationScale: 1,
      extruded: true,
      pickable: true,
      coverage: 1,
      opacity: 0.6,
      wireframe: false,
    }),

    // Scatterplot Layer for individual aircraft - latest positions as white circles
    new ScatterplotLayer({
      id: 'scatterplot-layer',
      data: positionsData?.latestAircraftPositions || [],
      getPosition: (d: { longitude: number; latitude: number }) => {
        console.log('[FlightMap] Scatterplot position:', { longitude: d.longitude, latitude: d.latitude });
        return [d.longitude, d.latitude];
      },
      getRadius: 150,
      getFillColor: [255, 255, 255, 255], // White, fully opaque
      radiusMinPixels: 3,
      radiusMaxPixels: 8,
      pickable: true,
      stroked: true,
      getLineColor: [200, 200, 200, 200], // Light gray border
      lineWidthMinPixels: 1,
    }),
  ];

  return (
    <div style={{ width: '100vw', height: '100vh', position: 'relative' }}>
      <DeckGL
        viewState={viewState}
        onViewStateChange={(e) => {
          const newViewState = 'viewState' in e ? e.viewState : e;
          if (newViewState && typeof newViewState === 'object' && 'longitude' in newViewState) {
            setViewState({
              longitude: newViewState.longitude ?? viewState.longitude,
              latitude: newViewState.latitude ?? viewState.latitude,
              zoom: newViewState.zoom ?? viewState.zoom,
              pitch: newViewState.pitch ?? viewState.pitch,
              bearing: newViewState.bearing ?? viewState.bearing,
            });
          }
        }}
        controller={true}
        layers={layers}
      >
        <MapLibreMap
          mapStyle="https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json"
          reuseMaps
        />
      </DeckGL>
      {/* Resolution Slider */}
      <div
        style={{
          position: 'absolute',
          top: 10,
          right: 10,
          background: 'rgba(0,0,0,0.8)',
          color: 'white',
          padding: '12px 16px',
          borderRadius: '8px',
          fontFamily: 'monospace',
          fontSize: '14px',
          boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
          minWidth: '200px',
        }}
      >
        <div style={{ marginBottom: '8px' }}>
          <label htmlFor="resolution-slider" style={{ display: 'block', marginBottom: '4px' }}>
            Resolution: r{resolution}
          </label>
          <input
            id="resolution-slider"
            type="range"
            min="0"
            max="10"
            value={resolution}
            onChange={(e) => setResolution(parseInt(e.target.value))}
            style={{ width: '100%' }}
          />
        </div>
      </div>
      {(positionsLoading || hexGridLoading) && (
        <div
          style={{
            position: 'absolute',
            top: 70,
            right: 10,
            background: 'rgba(0,0,0,0.7)',
            color: 'white',
            padding: '10px',
            borderRadius: '5px',
          }}
        >
          Loading...
        </div>
      )}
      {(positionsError || hexGridError) && (
        <div
          style={{
            position: 'absolute',
            top: 10,
            left: 10,
            background: 'rgba(255,0,0,0.7)',
            color: 'white',
            padding: '10px',
            borderRadius: '5px',
            maxWidth: '300px',
          }}
        >
          <strong>Error:</strong> {positionsError?.message || hexGridError?.message}
        </div>
      )}
      {/* Flight Statistics */}
      <div
        style={{
          position: 'absolute',
          top: 10,
          left: 10,
          background: 'rgba(0,0,0,0.8)',
          color: 'white',
          padding: '12px 16px',
          borderRadius: '8px',
          fontFamily: 'monospace',
          fontSize: '14px',
          boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
        }}
      >
        {statsLoading ? (
          <div>Loading stats...</div>
        ) : stats ? (
          <div>
            <div style={{ marginBottom: '4px' }}>
              <strong>Flights:</strong> {stats.uniqueFlights.toLocaleString()}
            </div>
            <div style={{ marginBottom: '4px' }}>
              <strong>Trails:</strong> {stats.totalEvents.toLocaleString()}
            </div>
            <div>
              <strong>Hexes:</strong> {mergedHexGrid.length.toLocaleString()}
            </div>
            {hexGridDataFiltered.length > 0 && (
              <div style={{ marginTop: '4px', fontSize: '12px', opacity: 0.7 }}>
                With data: {hexGridDataFiltered.length}
              </div>
            )}
          </div>
        ) : (
          <div>No stats available</div>
        )}
      </div>
    </div>
  );
}

