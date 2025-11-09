# Sprint 2 Plan: Shared Data Interfaces

**Goal:** To define and create a central, version-controlled package for all shared TypeScript types. This is a critical step for ensuring type safety and data consistency across the entire application stack, from data scraping to frontend rendering.

**Holistic Perspective:** This sprint establishes the "single source of truth" for our data contracts. By creating a dedicated `@map/shared` package, we ensure that the scraper, GraphQL API, and frontend all agree on the shape of the data. The types defined here are designed with the full data pipeline in mind, harmonizing fields from multiple potential data sources (FR24, OpenSky) and including placeholders for future enrichment (like H3 indexes).

---

### Key Outcomes

1.  A new `packages/map-shared` directory containing a Bun project.
2.  A `types.ts` file defining the core interfaces: `FlightEvent`, `FlightDetails`, `DataSource`, etc.
3.  The `@map/shared` package is successfully linked into the monorepo, making its types importable by other packages.

---

### Implementation Steps

1.  **Package Scaffolding:**
    *   Create the directory `packages/map-shared`.
    *   Navigate into the new directory and run `bun init` to create its `package.json`.
    *   Edit the `package.json`:
        *   Set the name to `"@map/shared"`.
        *   Set the version to `"1.0.0"`.
        *   Ensure `"main": "src/index.ts"` is present.
    *   Create a `src/` directory and add two files: `index.ts` and `types.ts`.
    *   Create a `tsconfig.json` in this package, extending the root `tsconfig.json` if one exists.

2.  **Core Type Definitions (`src/types.ts`):**
    *   Define a `DataSource` enum-like type to clearly identify the origin of data. This is crucial for debugging and potential source-specific logic.
        ```typescript
        export type DataSource = 'fr24' | 'opensky' | 'adsbexchange' | 'unknown';
        ```
    *   Define the `FlightEvent` interface. This represents a single point-in-time snapshot of a flight's position and state. Make sure to compare the data from FR24 and OpenSKY APIs before planning this. Document the API calls made to parse this event from.
        ```typescript
        export interface FlightEvent {
          icao24: string;       // ICAO 24-bit address, the most reliable aircraft identifier.
          timestamp: number;    // Unix timestamp in seconds.
          latitude: number;
          longitude: number;
          altitude: number;     // Altitude in meters.
          heading: number;      // Heading in degrees (0-360).
          groundSpeed: number;  // Speed in meters/second.
          verticalRate: number; // Vertical speed in meters/second.
          source: DataSource;
        }
        ```
    *   Define the `FlightDetails` interfaces. This structure is designed to be extensible, with a base interface and source-specific extensions. This allows us to capture all available data while maintaining a common structure. Make sure to compare the data from FR24 and OpenSKY APIs before planning this. Document the API calls made to parse this event from.
        ```typescript
        export interface BaseFlightDetails {
          icao24: string;
          callsign: string | null;
          registration: string | null;
          aircraftModel: string | null;
          originAirportIATA: string | null;
          destinationAirportIATA: string | null;
        }

        // Example of a source-specific extension
        export interface Fr24FlightDetails extends BaseFlightDetails {
          flightNumber: string | null;
          // any other fr24-specific details...
        }
        
        // The final type can be a union of all possible details
        export type FlightDetails = BaseFlightDetails | Fr24FlightDetails;
        ```
    *   Define a type alias for H3 indexes for clarity.
        ```typescript
        export type H3Index = string;
        ```

3.  **Package Exports (`src/index.ts`):**
    *   Export all the newly created types from the main `index.ts` file to make them available to other packages.
        ```typescript
        export * from './types';
        ```

4.  **Monorepo Integration and Verification:**
    *   Navigate to the project root.
    *   Run `bun install`. Bun's workspace feature will automatically link `@map/shared` so it can be imported by other packages in the `packages/` directory.
    *   To verify, create a temporary directory for the next sprint's package, e.g., `packages/map-scraper`.
    *   Inside this temporary package, create a `test.ts` file and add an import:
        ```typescript
        import type { FlightEvent } from '@map/shared';

        const event: FlightEvent = { /* ... */ }; // The IDE should provide autocompletion.
        console.log('Successfully imported FlightEvent type.');
        ```
    *   The TypeScript language server in your editor should resolve the import without errors, and you should get autocompletion for the `FlightEvent` properties. This confirms the workspace linking is successful.
