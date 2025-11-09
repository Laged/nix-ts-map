import { gql } from '@apollo/client';

export const GET_LATEST_POSITIONS = gql`
  query GetLatestPositions($bbox: [Float!]!, $since: DateTime!) {
    latestAircraftPositions(bbox: $bbox, since: $since) {
      icao24
      latitude
      longitude
      altitude
      lastSeen
    }
  }
`;

export const GET_HEX_GRID = gql`
  query GetHexGrid($resolution: Int!, $bbox: [Float!]!, $from: DateTime!, $to: DateTime!) {
    hexGrid(resolution: $resolution, bbox: $bbox, from: $from, to: $to) {
      h3Index
      aircraftCount
    }
  }
`;

