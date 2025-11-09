import { useQuery } from '@apollo/client';
import { DeckGL } from '@deck.gl/react';
import { H3HexagonLayer } from '@deck.gl/geo-layers';
import { ScatterplotLayer } from '@deck.gl/layers';
import { Map } from 'react-map-gl/maplibre';
import { GET_LATEST_POSITIONS, GET_HEX_GRID } from '../graphql/queries';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useState } from 'react';

// MapLibre doesn't require a token, but we can optionally use Mapbox styles if token is provided
const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN || '';

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

  const layers = [
    // H3 Hexagon Layer
    new H3HexagonLayer({
      id: 'h3-hexagon-layer',
      data: hexGridData?.hexGrid || [],
      getHexagon: (d) => d.h3Index,
      getFillColor: (d) => {
        const count = d.aircraftCount || 0;
        // Color based on density: blue (low) to red (high)
        const intensity = Math.min(count / 10, 1);
        return [
          Math.floor(intensity * 255),
          Math.floor((1 - intensity) * 255),
          128,
          Math.floor(intensity * 128 + 127),
        ];
      },
      getElevation: (d) => (d.aircraftCount || 0) * 100,
      elevationScale: 1,
      extruded: true,
      pickable: true,
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

  // Show warning if Mapbox token is missing
  if (!MAPBOX_TOKEN) {
    return (
      <div style={{ 
        width: '100vw', 
        height: '100vh', 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'center',
        background: '#1a1a1a',
        color: 'white',
        flexDirection: 'column',
        gap: '20px'
      }}>
        <h2>Mapbox Token Required</h2>
        <p>Please set VITE_MAPBOX_TOKEN in your .env file</p>
        <p style={{ fontSize: '0.9em', opacity: 0.7 }}>
          Get your token from{' '}
          <a href="https://www.mapbox.com/" target="_blank" rel="noopener noreferrer" style={{ color: '#4CAF50' }}>
            mapbox.com
          </a>
        </p>
      </div>
    );
  }

  return (
    <div style={{ width: '100vw', height: '100vh', position: 'relative' }}>
      <DeckGL
        viewState={viewState}
        onViewStateChange={({ viewState }) => setViewState(viewState)}
        controller={true}
        layers={layers}
      >
        <Map
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
    </div>
  );
}

