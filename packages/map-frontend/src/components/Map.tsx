import { useQuery } from '@apollo/client';
import { DeckGL } from '@deck.gl/react';
import { H3HexagonLayer, ScatterplotLayer } from '@deck.gl/geo-layers';
import { Map } from 'react-map-gl';
import { GET_LATEST_POSITIONS, GET_HEX_GRID } from '../graphql/queries';
import 'mapbox-gl/dist/mapbox-gl.css';
import { useState } from 'react';

const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN || '';

// Default view centered on Finland
const INITIAL_VIEW_STATE = {
  longitude: 25.0,
  latitude: 64.0,
  zoom: 5,
  pitch: 0,
  bearing: 0,
};

export function FlightMap() {
  const [viewState, setViewState] = useState(INITIAL_VIEW_STATE);

  // Calculate bounding box for Finland (approximately)
  const bbox: [number, number, number, number] = [60, 20, 70, 30];
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
          mapboxAccessToken={MAPBOX_TOKEN}
          mapStyle="mapbox://styles/mapbox/dark-v11"
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

