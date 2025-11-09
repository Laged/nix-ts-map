# Sprint 8 Plan: Tooling, Testing, and Local Development

**Goal:** To solidify the project's developer experience, ensure its reliability through automated testing, and create a streamlined workflow for running the entire application stack locally.

**Holistic Perspective:** This final sprint is about maturity and maintainability. A great application is only useful if it's easy to work on and known to be reliable. By introducing `process-compose`, we create a "one-command" method to launch the entire local environment, drastically simplifying the development loop. Integrating testing into the Nix flake (`nix test`) creates a high-quality gate, ensuring that new contributions don't break existing functionality. This sprint doesn't add new features, but it makes all future feature development faster, safer, and more professional.

---

### Key Outcomes

1.  A `process-compose.yml` file at the project root that starts and manages all services (`scraper`, `graphql`, `frontend`, `clickhouse`).
2.  A comprehensive test suite using `bun test`.
3.  Unit tests for critical logic in each package.
4.  The `nix flake check` (aliased to `nix test`) command is configured to run all tests across the monorepo.
5.  Updated `README.md` with clear, final instructions for setup and local development.

---

### Implementation Steps

1.  **Local Development with `process-compose`:**
    *   Create a `process-compose.yml` file in the project root.
    *   Define the services required to run the application:
        *   **`clickhouse`:**
            *   Command: `clickhouse-server -- --config-file=/path/to/config.xml` (if a custom config is needed).
            *   Health check: A command that uses `clickhouse-client` to ping the server.
        *   **`graphql`:**
            *   Command: `bun run packages/map-graphql/src/index.ts`.
            *   Depends on: `clickhouse` being healthy.
        *   **`scraper`:**
            *   Command: `bun run packages/map-scraper/src/index.ts`.
            *   Depends on: `graphql` (for the notification mutation) and `clickhouse` being healthy.
        *   **`frontend`:**
            *   Command: `cd packages/map-frontend && bun dev`.
            *   Depends on: `graphql`.
    *   Document the new workflow: `nix develop`, then `process-compose up`.

2.  **Testing Strategy and Implementation:**
    *   **Setup:** `bun test` is built-in, so no extra test runner setup is needed.
    *   **Unit Tests (`*.test.ts`):**
        *   **`@map/shared`:** If there are any utility functions (e.g., for data conversion), add tests for them.
        *   **`@map/scraper`:** This is a key area for testing.
            *   Mock the `fetch` call to return sample API data.
            *   Test the transformation logic: does it correctly convert the raw data into a `FlightEvent` object?
            *   Test the H3 index calculation.
        *   **`@map/graphql`:**
            *   Test individual resolver functions.
            *   Mock the database client to return predefined data.
            *   Call a resolver function with mock arguments and context, and assert that it returns the expected result.
        *   **`@map/frontend`:**
            *   Use a library like `@testing-library/react` to test individual components.
            *   Mock the Apollo Client to provide data to components and test that they render correctly.

3.  **`nix test` Integration:**
    *   Modify the `flake.nix` file to add a `checks` output.
    *   The `checks` attribute will define a derivation that runs the full test suite.
        ```nix
        # In flake.nix
        outputs = { self, nixpkgs, flake-utils }:
          flake-utils.lib.eachDefaultSystem (system:
            let
              pkgs = import nixpkgs { inherit system; };
              devShell = pkgs.mkShell { ... };
            in
            {
              devShells.default = devShell;

              # Add the checks output
              checks.default = pkgs.runCommand "mapmap-tests" {
                src = ./.;
                buildInputs = [ pkgs.bun ]; # Make bun available in the test environment
              } ''
                # Copy source to a writable location
                cp -r $src $out
                cd $out
                
                # Run install and then the tests
                bun install
                bun test --workspaces
              '';
            });
        ```
    *   This allows any developer (or a CI server) to run `nix flake check` or `nix test` to validate the entire codebase in a clean, sandboxed environment.

4.  **Final Documentation:**
    *   Perform a full review of the root `README.md`.
    *   Update it to reflect the final, streamlined development process.
    *   **Key Sections to Include:**
        *   **Prerequisites:** Nix with Flakes enabled.
        *   **First-Time Setup:** `git clone ...`, `nix develop`, `bun install`.
        *   **Running the Application:** `process-compose up`.
        *   **Running Tests:** `bun test` (for interactive testing) and `nix test` (for full validation).
        *   **Project Structure:** A brief overview of what each package in `packages/` does.

5.  **Verification:**
    *   Run `process-compose up` from a fresh shell. Verify that all services start in the correct order and the application is fully functional.
    *   Run `bun test --workspaces` and ensure all unit tests pass.
    *   Run `nix flake check` and ensure it completes successfully. This is the ultimate verification of the reproducible build and test process.
    *   Ask a colleague (or do it yourself in a clean directory) to follow the `README.md` instructions from scratch and confirm they can get the project running.
