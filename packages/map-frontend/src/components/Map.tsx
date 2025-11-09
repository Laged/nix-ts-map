import { useQuery } from '@apollo/client';
import { DeckGL } from '@deck.gl/react';
import { H3HexagonLayer, ScatterplotLayer } from '@deck.gl/geo-layers';
import Map from 'react-map-gl';
import { GET_LATEST_POSITIONS, GET_HEX_GRID } from '../graphql/queries';
import 'mapbox-gl/dist/mapbox-gl.css';

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
  // Calculate bounding box for Finland (approximately)
  const bbox: [number, number, number, number] = [60, 20, 70, 30];
  const now = Math.floor(Date.now() / 1000);
  const oneHourAgo = now - 3600;

  // Fetch latest positions
  const { data: positionsData, loading: positionsLoading } = useQuery(GET_LATEST_POSITIONS, {
    variables: {
      bbox,
      since: oneHourAgo,
    },
    pollInterval: 60000, // Poll every 60 seconds
  });

  // Fetch hex grid data
  const { data: hexGridData, loading: hexGridLoading } = useQuery(GET_HEX_GRID, {
    variables: {
      resolution: 6,
      bbox,
      from: oneHourAgo,
      to: now,
    },
    pollInterval: 60000,
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

  return (
    <div style={{ width: '100vw', height: '100vh', position: 'relative' }}>
      <DeckGL
        initialViewState={INITIAL_VIEW_STATE}
        controller={true}
        layers={layers}
      >
        <Map
          mapboxAccessToken={MAPBOX_TOKEN}
          mapStyle="mapbox://styles/mapbox/dark-v11"
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
    </div>
  );
}

