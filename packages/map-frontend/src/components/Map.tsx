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

  // Load cached hex polyfill data
  useEffect(() => {
    fetch('/hex_polyfill_r6.json')
      .then((res) => res.json())
      .then((data: Array<{ hex_id: string; resolution: number; center_lat: number; center_lon: number }>) => {
        setBaseHexGrid(
          data.map((hex) => ({
            h3Index: hex.hex_id,
            aircraftCount: 0, // Will be updated when data is available
          }))
        );
      })
      .catch((err) => {
        console.error('Failed to load hex polyfill cache:', err);
      });
  }, []);

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
      resolution: 6,
      bbox,
      from: oneHourAgo,
      to: now,
    },
    pollInterval: 60000,
    errorPolicy: 'all',
  });

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

  // Create a map of h3Index to aircraftCount for quick lookup
  const dataMap = useMemo(() => {
    const map = new Map<string, number>();
    hexGridDataFiltered.forEach((d: { h3Index: string; aircraftCount: number }) => {
      map.set(d.h3Index, d.aircraftCount);
    });
    return map;
  }, [hexGridDataFiltered]);

  // Merge base hex grid with data
  const mergedHexGrid = useMemo(() => {
    return baseHexGrid.map((hex: { h3Index: string; aircraftCount: number }) => ({
      ...hex,
      aircraftCount: dataMap.get(hex.h3Index) || 0,
    }));
  }, [baseHexGrid, dataMap]);

  const layers = [
    // Base H3 Hexagon Layer (gray, almost transparent) - shows all hexes even without data
    new H3HexagonLayer({
      id: 'h3-hexagon-base-layer',
      data: mergedHexGrid,
      getHexagon: (d) => d.h3Index,
      getFillColor: (d) => {
        const count = d.aircraftCount || 0;
        if (count > 0) {
          // Color based on density: blue (low) to red (high)
          const intensity = Math.min(count / 10, 1);
          return [
            Math.floor(intensity * 255),
            Math.floor((1 - intensity) * 255),
            128,
            Math.floor(intensity * 128 + 127),
          ];
        } else {
          // Gray, almost transparent for hexes without data
          return [128, 128, 128, 20];
        }
      },
      getElevation: (d) => (d.aircraftCount || 0) * 100,
      elevationScale: 1,
      extruded: true,
      pickable: true,
      coverage: 1,
      opacity: 0.3,
      wireframe: false,
    }),

    // Scatterplot Layer for individual aircraft
    new ScatterplotLayer({
      id: 'scatterplot-layer',
      data: positionsData?.latestAircraftPositions || [],
      getPosition: (d) => [d.longitude, d.latitude],
      getRadius: 100,
      getFillColor: [255, 140, 0, 200],
      radiusMinPixels: 2,
      radiusMaxPixels: 10,
      pickable: true,
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
      {(positionsLoading || hexGridLoading) && (
        <div
          style={{
            position: 'absolute',
            top: 10,
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
            <div>
              <strong>Trails:</strong> {stats.totalEvents.toLocaleString()}
            </div>
            {hexGridDataFiltered.length > 0 && (
              <div style={{ marginTop: '4px', fontSize: '12px', opacity: 0.7 }}>
                Hexagons: {hexGridDataFiltered.length}
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

