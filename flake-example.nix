{
  description = "UFOMap development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        inputs.process-compose-flake.flakeModule
      ];

      perSystem =
        {
          self',
          pkgs,
          lib,
          ...
        }:
        {
          # Development shell
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              bun
              nodejs_22
              clickhouse
            ];

            shellHook = ''
              echo "UFOMap dev environment ready"
              echo ""
              if [ -f .env ]; then
                echo "✓ .env file found (secrets loaded at runtime)"
                if grep -q "^FLIGHTRADAR_API_KEY=.\\+" .env 2>/dev/null; then
                  echo "✓ FLIGHTRADAR_API_KEY configured"
                else
                  echo "⚠ No FLIGHTRADAR_API_KEY in .env (will use test data only)"
                fi
              else
                echo "ℹ️  No .env file (using test data only)"
                echo "   To add live data: cp .env.example .env"
              fi
              echo ""
              echo "Quick Start:"
              echo "  nix run          # Start entire stack (ClickHouse + services)"
              echo "  bun install      # Install dependencies"
              echo "  bun test         # Run tests"
              echo ""
            '';
          };

          # Make ufomap the default package
          packages.default = self'.packages.ufomap;

          # Wipe database package for development
          packages.wipe-database = pkgs.writeShellApplication {
            name = "wipe-database";
            runtimeInputs = [ pkgs.curl ];
            text = ''
              echo "========================================="
              echo "⚠️  WARNING: Database Wipe"
              echo "========================================="
              echo ""
              echo "This will DROP ALL tables and views."
              echo "All flight data will be lost."
              echo ""
              read -r -p "Type 'yes' to continue: " confirm

              if [ "$confirm" != "yes" ]; then
                echo "Aborted."
                exit 0
              fi

              echo ""
              echo "→ Checking if ClickHouse is running..."
              if ! curl -s http://localhost:8123/ping | grep -q "Ok"; then
                echo "✗ ClickHouse not running on localhost:8123"
                echo "  Start it with: nix run"
                exit 1
              fi

              echo "✓ ClickHouse is running"
              echo ""
              echo "→ Dropping materialized views..."
              for res in {0..10}; do
                curl -s 'http://localhost:8123/' --data-binary "DROP VIEW IF EXISTS flight_hex_density_res$res"
              done
              echo "✓ Materialized views dropped"

              echo "→ Dropping tables..."
              curl -s 'http://localhost:8123/' --data-binary "DROP TABLE IF EXISTS flights"
              curl -s 'http://localhost:8123/' --data-binary "DROP TABLE IF EXISTS flight_trails"
              curl -s 'http://localhost:8123/' --data-binary "DROP TABLE IF EXISTS configs"
              curl -s 'http://localhost:8123/' --data-binary "DROP TABLE IF EXISTS configs_latest"
              echo "✓ Tables dropped"

              echo ""
              echo "========================================="
              echo "✓ Database wiped successfully"
              echo "========================================="
              echo ""
              echo "Next steps:"
              echo "  1. Stop process-compose (Ctrl+C)"
              echo "  2. Run: nix run"
              echo "  3. All migrations will be applied fresh"
              echo ""
            '';
          };

          # History scraper convenience commands
          packages.scrape-last-day = pkgs.writeShellScriptBin "scrape-last-day" ''
            echo "=== Scraping Last 24 Hours (Finland) ==="
            echo ""

            # Calculate timestamps (24 hours ago to now)
            FROM_TIME=$(date -u -d '1 day ago' +%Y-%m-%dT%H:00:00Z)
            TO_TIME=$(date -u +%Y-%m-%dT%H:00:00Z)

            echo "Time window: $FROM_TIME → $TO_TIME"
            echo ""

            ${pkgs.bun}/bin/bun run --filter @ufomap/history-scraper start -- \
              --from-time "$FROM_TIME" \
              --to-time "$TO_TIME" \
              --region finland \
              "$@"
          '';

          packages.scrape-last-week = pkgs.writeShellScriptBin "scrape-last-week" ''
            echo "=== Scraping Last 7 Days (Finland) ==="
            echo ""

            # Calculate timestamps (7 days ago to now)
            FROM_TIME=$(date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z)
            TO_TIME=$(date -u +%Y-%m-%dT00:00:00Z)

            echo "Time window: $FROM_TIME → $TO_TIME"
            echo ""

            ${pkgs.bun}/bin/bun run --filter @ufomap/history-scraper start -- \
              --from-time "$FROM_TIME" \
              --to-time "$TO_TIME" \
              --region finland \
              --token-budget 3500 \
              "$@"
          '';

          packages.scrape-last-month = pkgs.writeShellScriptBin "scrape-last-month" ''
            echo "=== Scraping Last 30 Days (Finland) ==="
            echo "This will run 5 sequential 7-day windows (max per run)"
            echo ""

            # Run 5 chunks of 6 days each to cover 30 days
            # (Using 6-day chunks to avoid overlap issues)
            for i in {0..4}; do
              DAYS_AGO=$((30 - i * 6))
              DAYS_AGO_END=$((DAYS_AGO - 6))

              FROM_TIME=$(date -u -d "$DAYS_AGO days ago" +%Y-%m-%dT00:00:00Z)
              TO_TIME=$(date -u -d "$DAYS_AGO_END days ago" +%Y-%m-%dT00:00:00Z)

              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
              echo "Chunk $((i + 1))/5: $FROM_TIME → $TO_TIME"
              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

              ${pkgs.bun}/bin/bun run --filter @ufomap/history-scraper start -- \
                --from-time "$FROM_TIME" \
                --to-time "$TO_TIME" \
                --region finland \
                --token-budget 700 \
                "$@"

              if [ $? -ne 0 ]; then
                echo "✗ Chunk $((i + 1)) failed. Stopping."
                exit 1
              fi

              echo "✓ Chunk $((i + 1))/5 complete"
              echo ""

              # Brief pause between chunks
              sleep 2
            done

            echo "✓ All 30 days scraped successfully!"
          '';

          packages.scrape-last-year = pkgs.writeShellScriptBin "scrape-last-year" ''
            echo "=== Scraping Last 365 Days (Finland) ==="
            echo "⚠️  WARNING: This will run 52 sequential 7-day windows"
            echo "⚠️  Estimated time: 10-30 hours depending on flight density"
            echo "⚠️  OpenSky API credits: ~180,000 (45 days of quota)"
            echo ""
            read -p "Continue? (yes/no): " CONFIRM

            if [ "$CONFIRM" != "yes" ]; then
              echo "Aborted."
              exit 0
            fi

            echo ""
            echo "Starting annual backfill..."

            # Run 52 chunks of 7 days each
            for i in {0..51}; do
              DAYS_AGO=$((365 - i * 7))
              DAYS_AGO_END=$((DAYS_AGO - 7))

              FROM_TIME=$(date -u -d "$DAYS_AGO days ago" +%Y-%m-%dT00:00:00Z)
              TO_TIME=$(date -u -d "$DAYS_AGO_END days ago" +%Y-%m-%dT00:00:00Z)

              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
              echo "Week $((i + 1))/52: $FROM_TIME → $TO_TIME"
              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

              ${pkgs.bun}/bin/bun run --filter @ufomap/history-scraper start -- \
                --from-time "$FROM_TIME" \
                --to-time "$TO_TIME" \
                --region finland \
                --token-budget 3500 \
                "$@"

              if [ $? -ne 0 ]; then
                echo "✗ Week $((i + 1)) failed. Stopping."
                echo "To resume, manually run from: $FROM_TIME"
                exit 1
              fi

              echo "✓ Week $((i + 1))/52 complete ($(( (i + 1) * 100 / 52 ))% done)"
              echo ""

              # Brief pause between chunks to avoid rate limits
              sleep 5
            done

            echo "✓ All 365 days scraped successfully!"
          '';

          # Resumable backfill for November 2025
          packages.backfill-november = pkgs.writeShellScriptBin "backfill-november" ''
            # Change to packages/history-scraper directory
            cd packages/history-scraper

            # Run TypeScript backfill script with .env loaded from repo root
            ${pkgs.bun}/bin/bun --env-file=../../.env run src/backfill/november.ts "$@"
          '';

          # FR24 Smoke Test: Nov 1, 2025 (24 hours, 8 tiles, hourly = 192 requests)
          packages.scrape-25-11-01 = pkgs.writeShellScriptBin "scrape-25-11-01" ''
            echo "=== FR24 Smoke Test: November 1, 2025 ==="
            echo ""
            echo "Plan: docs/plans/2025-11-07-fr24-nov01-smoke.md"
            echo "Strategy: 8 tiles × 24 hours = 192 requests"
            echo "Expected: ~192 credits consumed, <30 min runtime"
            echo ""

            cd packages/history-scraper

            ${pkgs.bun}/bin/bun --env-file=../../.env run src/index.ts \
              --provider fr24 \
              --from-time 2025-11-01T00:00:00Z \
              --to-time 2025-11-02T00:00:00Z \
              --region finland \
              --token-budget 20000 \
              "$@"
          '';

          # FR24 SDK Test: Nov 2, 2025 (testing SDK integration with 1h intervals)
          packages.scrape-25-11-02-sdk = pkgs.writeShellScriptBin "scrape-25-11-02-sdk" ''
            LOG_FILE="scrape-25-11-02-sdk.log"

            echo "=== FR24 SDK Test: November 2, 2025 ===" | tee "$LOG_FILE"
            echo "" | tee -a "$LOG_FILE"
            echo "SDK Integration Test:" | tee -a "$LOG_FILE"
            echo "  ✅ Using @flightradar24/fr24sdk official package" | tee -a "$LOG_FILE"
            echo "  ✅ 1-hour intervals (24 intervals total)" | tee -a "$LOG_FILE"
            echo "  ✅ Configurable sampling with --interval parameter" | tee -a "$LOG_FILE"
            echo "  ✅ Checkpoint-based resume capability" | tee -a "$LOG_FILE"
            echo "" | tee -a "$LOG_FILE"
            echo "Expected: 192 API calls (24 hours × 8 tiles)" | tee -a "$LOG_FILE"
            echo "Comparison: vs 2025-11-01 REST API baseline" | tee -a "$LOG_FILE"
            echo "" | tee -a "$LOG_FILE"

            # Run scraper with SDK
            echo "=== Starting Scraper (SDK Mode) ===" | tee -a "$LOG_FILE"
            cd packages/history-scraper
            FR24_USE_SDK=true ${pkgs.bun}/bin/bun --env-file=../../.env run src/index.ts \
              --provider fr24 \
              --interval 3600 \
              --from-time 2025-11-02T00:00:00Z \
              --to-time 2025-11-03T00:00:00Z \
              --region finland \
              --token-budget 20000 \
              2>&1 | tee -a "../../$LOG_FILE"

            # Post-test reminder
            echo "" | tee -a "../../$LOG_FILE"
            echo "⚠️  Manually verify FR24 usage on dashboard after test completes" | tee -a "../../$LOG_FILE"
            echo "" | tee -a "../../$LOG_FILE"

            # Verify results
            echo "=== Verifying Results ===" | tee -a "../../$LOG_FILE"
            echo "" | tee -a "../../$LOG_FILE"

            # Trail points data
            echo "--- Trail Points (flight_trails table) ---" | tee -a "../../$LOG_FILE"
            nix develop --command clickhouse-client --query "
            SELECT
              COUNT(*) as total_points,
              COUNT(DISTINCT flight_id) as unique_flights,
              MIN(timestamp) as earliest,
              MAX(timestamp) as latest
            FROM flight_trails
            WHERE timestamp >= '2025-11-02 00:00:00'
              AND timestamp < '2025-11-03 00:00:00'
            FORMAT Pretty" 2>&1 | tee -a "../../$LOG_FILE"

            # UI layer: FLIGHTS
            echo "" | tee -a "../../$LOG_FILE"
            echo "--- UI Layer: FLIGHTS (latest positions for map markers) ---" | tee -a "../../$LOG_FILE"
            nix develop --command clickhouse-client --query "
            SELECT
              COUNT(*) as flights_layer_count
            FROM flights
            WHERE timestamp >= '2025-11-02 00:00:00'
              AND timestamp < '2025-11-03 00:00:00'
            FORMAT Pretty" 2>&1 | tee -a "../../$LOG_FILE"

            # Job manifest
            echo "" | tee -a "../../$LOG_FILE"
            echo "--- Job Manifest ---" | tee -a "../../$LOG_FILE"
            nix develop --command clickhouse-client --query "
            SELECT
              provider,
              status,
              flights_found,
              points_written,
              opensky_requests as api_calls,
              opensky_credits_used as credits_used,
              started_at,
              finished_at
            FROM history_scraper_jobs
            WHERE from_time >= '2025-11-02 00:00:00'
            ORDER BY started_at DESC
            LIMIT 1
            FORMAT Pretty" 2>&1 | tee -a "../../$LOG_FILE"

            # Compare with 2025-11-01 baseline
            echo "" | tee -a "../../$LOG_FILE"
            echo "--- Comparison: 2025-11-01 (REST) vs 2025-11-02 (SDK) ---" | tee -a "../../$LOG_FILE"
            nix develop --command clickhouse-client --query "
            SELECT
              toDate(timestamp) AS day,
              count() AS track_points,
              uniqExact(flight_id) AS flights,
              round(count() / uniqExact(flight_id), 2) AS avg_points_per_flight
            FROM flight_trails
            WHERE day IN ('2025-11-01', '2025-11-02')
            GROUP BY day
            ORDER BY day
            FORMAT Pretty" 2>&1 | tee -a "../../$LOG_FILE"

            echo "" | tee -a "../../$LOG_FILE"
            echo "✓ Results saved to $LOG_FILE" | tee -a "../../$LOG_FILE"
            echo "" | tee -a "../../$LOG_FILE"

            cd ../..
          '';

          # Database setup with migration 011
          packages.setup-history-db = pkgs.writeShellScriptBin "setup-history-db" ''
            echo "=== Setting Up History Scraper Database ==="
            echo ""

            # Wait for ClickHouse
            echo "→ Waiting for ClickHouse..."
            for i in {1..30}; do
              if ${pkgs.curl}/bin/curl -s http://localhost:8123/ping | grep -q "Ok"; then
                echo "✓ ClickHouse ready"
                break
              fi
              sleep 1
            done

            # Apply base schema
            echo "→ Applying base schema..."
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/001_initial.sql}

            # Apply migrations
            echo "→ Applying migrations..."
            ${pkgs.clickhouse}/bin/clickhouse-client --query "ALTER TABLE flights ADD COLUMN IF NOT EXISTS country String"
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/003_scraper_config.sql}
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/005_flight_positions_hex_columns.sql}
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/006_backfill_hex_ids.sql}
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/007_hex_indices.sql}
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/008_h3_views.sql}
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/009_flights_hex_columns.sql}
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/010_flights_hex_indices.sql}

            # Apply history scraper migration
            echo "→ Applying history scraper migration (011)..."
            ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/011_history_scraper_jobs.sql}

            echo "✓ Database setup complete"
            echo ""
            echo "Tables created:"
            ${pkgs.clickhouse}/bin/clickhouse-client --query "SHOW TABLES"
          '';

          # Process-compose services configuration
          process-compose."ufomap" = {
            imports = [
              inputs.services-flake.processComposeModules.default
            ];

            # TUI configuration: Disabled by default for stability
            # The TUI has issues in non-interactive environments
            # Run with PC_DISABLE_TUI=false in your shell if you want the TUI
            cli = {
              environment = {
                PC_DISABLE_TUI = false;
              };
            };

            # ClickHouse database service
            services.clickhouse."ufomap-db" = {
              enable = true;
              extraConfig = {
                # Explicitly set HTTP port (default but making sure)
                http_port = 8123;
                tcp_port = 9000;

                # Log to file for debugging
                logger = {
                  level = "information";
                  log = "./logs/clickhouse.log";
                  errorlog = "./logs/clickhouse-error.log";
                };
              };
            };

            # Custom settings for all processes
            settings = {
              log_location = "./logs/process-compose";
              log_level = "info";

              environment = {
                # ClickHouse connection details (automatically set by services-flake)
                CLICKHOUSE_HOST = "http://localhost:8123";
                CLICKHOUSE_USER = "default";
                CLICKHOUSE_PASSWORD = "";
                CLICKHOUSE_DB = "default";

                # Flight Data Provider
                FLIGHT_PROVIDER = "opensky";

                # OpenSky credentials loaded from .env at runtime
                # DO NOT hardcode credentials in this file!

                # Scraper config (Finland ONLY - matches red boundary)
                SCRAPER_INTERVAL_MS = "300000"; # 5 minutes
                SCRAPER_REGION_NORTH = "70.1"; # Finland northern border
                SCRAPER_REGION_SOUTH = "59.5"; # Finland southern border
                SCRAPER_REGION_EAST = "31.5"; # Finland eastern border
                SCRAPER_REGION_WEST = "19.0"; # Finland western border

                # GraphQL server config
                GRAPHQL_PORT = "4000";
                GRAPHQL_CORS_ORIGIN = "http://localhost:5173,https://*.ngrok-free.app,https://*.ngrok-free.dev,https://*.ngrok.io";
                GRAPHQL_UPDATE_INTERVAL_MS = "300000";

                # Frontend config
                VITE_GRAPHQL_URL = "/graphql";
              };

              processes = {
                # Cleanup any stale processes from previous runs
                cleanup-stale = {
                  command =
                    let
                      cleanupScript = pkgs.writeShellScript "cleanup-stale" ''
                        echo "→ Checking for stale processes..."

                        # Kill processes holding our ports using ss to find PIDs
                        for port in 4000 5173 8123 9000; do
                          # Extract PID from ss output: users:(("name",pid=12345,fd=N))
                          PIDS=$(${pkgs.iproute2}/bin/ss -tlnp 2>/dev/null | grep ":$port" | grep -oP 'pid=\K[0-9]+' || true)
                          for PID in $PIDS; do
                            if [ -n "$PID" ]; then
                              echo "  Killing process $PID on port $port"
                              kill $PID 2>/dev/null || true
                            fi
                          done
                        done

                        # Wait for processes to die and ports to be released
                        sleep 3

                        # Remove ClickHouse status lock file if it exists
                        rm -f ./data/ufomap-db/clickhouse/status 2>/dev/null || true

                        echo "✓ Cleanup complete (all stale processes killed, ports released)"
                        exit 0
                      '';
                    in
                    "${cleanupScript}";
                  availability.restart = "no";
                };

                # Install dependencies first
                install-deps = {
                  command = "${pkgs.bun}/bin/bun install";
                  depends_on."cleanup-stale".condition = "process_completed_successfully";
                  availability.restart = "no";
                };

                # Apply schema after ClickHouse is ready
                setup-database = {
                  command =
                    let
                      setupScript = pkgs.writeShellScript "setup-database" ''
                                                echo "========================================="
                                                echo "UFOMap Database Setup"
                                                echo "========================================="
                                                echo ""
                                                echo "Waiting for ClickHouse to be ready..."
                                                for i in {1..30}; do
                                                  if ${pkgs.curl}/bin/curl -s http://localhost:8123/ping | grep -q "Ok"; then
                                                    echo "✓ ClickHouse ready"
                                                    echo ""

                                                    # Migration 001: Initial schema (flights, flight_trails, configs tables)
                                                    echo "→ [001] Creating initial schema..."
                                                    ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/001_initial.sql}
                                                    echo "✓ [001] Initial schema created"

                                                    # Migration 002: Add country column to flights
                                                    echo "→ [002] Adding country column..."
                                                    ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/002_add_country.sql}
                                                    echo "✓ [002] Country column added"

                                                    # Migration 003: Scraper configuration
                                                    echo "→ [003] Setting up scraper configuration..."
                                                    ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/003_scraper_config.sql}
                                                    echo "✓ [003] Scraper configuration applied"

                                                    # Migration 005: Add hex_id columns to flight_trails
                                                    echo "→ [005] Adding hex columns to flight_trails..."
                                                    ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/005_flight_positions_hex_columns.sql}
                                                    echo "✓ [005] Hex columns added to flight_trails"

                                                    # Migration 007: Create indices on flight_trails hex columns
                                                    echo "→ [007] Creating hex indices on flight_trails..."
                                                    for i in {0..10}; do
                                                      ${pkgs.clickhouse}/bin/clickhouse-client --query "ALTER TABLE flight_trails ADD INDEX IF NOT EXISTS idx_flight_hex_r$i hex_id_r$i TYPE set(0) GRANULARITY 1;" 2>/dev/null || true
                                                    done
                                                    echo "✓ [007] Hex indices created on flight_trails"

                                                    # Migration 009: Add hex_id columns to flights
                                                    echo "→ [009] Adding hex columns to flights..."
                                                    ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./clickhouse/schema/009_flights_hex_columns.sql}
                                                    echo "✓ [009] Hex columns added to flights"

                                                    # Migration 010: Create indices on flights hex columns
                                                    echo "→ [010] Creating hex indices on flights..."
                                                    for i in {0..10}; do
                                                      ${pkgs.clickhouse}/bin/clickhouse-client --query "ALTER TABLE flights ADD INDEX IF NOT EXISTS idx_flights_hex_r$i hex_id_r$i TYPE set(0) GRANULARITY 1;" 2>/dev/null || true
                                                    done
                                                    echo "✓ [010] Hex indices created on flights"

                                                    # Migration 008: Create materialized views (depends on hex columns existing)
                                                    echo "→ [008] Creating hex density materialized views..."
                                                    for res in {0..10}; do
                                                      ${pkgs.clickhouse}/bin/clickhouse-client --query "
                        CREATE MATERIALIZED VIEW IF NOT EXISTS flight_hex_density_res$res
                        ENGINE = SummingMergeTree()
                        PARTITION BY toYYYYMMDD(time_window)
                        ORDER BY (h3_cell, time_window)
                        AS SELECT
                            geoToH3(lon, lat, $res) AS h3_cell,
                            toStartOfHour(timestamp) AS time_window,
                            count() AS flight_count,
                            avg(altitude) AS avg_altitude
                        FROM flight_trails
                        GROUP BY h3_cell, time_window;
                        " 2>/dev/null || true
                                                    done
                                                    echo "✓ [008] Materialized views created"

                                                    echo ""
                                                    echo "========================================="
                                                    echo "✓ Database setup complete!"
                                                    echo "========================================="
                                                    echo ""
                                                    echo "Applied migrations:"
                                                    echo "  001 - Initial schema (flights, flight_trails, configs)"
                                                    echo "  002 - Country column"
                                                    echo "  003 - Scraper configuration"
                                                    echo "  005 - Hex columns on flight_trails"
                                                    echo "  007 - Hex indices on flight_trails"
                                                    echo "  009 - Hex columns on flights"
                                                    echo "  010 - Hex indices on flights"
                                                    echo "  008 - Materialized views (res0-10)"
                                                    echo ""
                                                    echo "Note: Migration 006 (backfill) skipped for fresh installs"
                                                    echo ""

                                                    exit 0
                                                  fi
                                                  sleep 1
                                                done
                                                echo "✗ ClickHouse not ready after 30 seconds"
                                                exit 1
                      '';
                    in
                    "${setupScript}";
                  depends_on = {
                    "cleanup-stale".condition = "process_completed_successfully";
                    "ufomap-db".condition = "process_healthy";
                  };
                  availability.restart = "no";
                };

                # Scraper service
                scraper = {
                  command = "${pkgs.bun}/bin/bun run --filter @ufomap/scraper dev";
                  depends_on = {
                    "ufomap-db".condition = "process_healthy";
                    "install-deps".condition = "process_completed_successfully";
                  };
                };

                # GraphQL server
                graphql = {
                  command = "${pkgs.bun}/bin/bun run --filter @ufomap/graphql dev";
                  depends_on = {
                    "ufomap-db".condition = "process_healthy";
                    "install-deps".condition = "process_completed_successfully";
                  };
                  readiness_probe = {
                    http_get = {
                      host = "localhost";
                      port = 4000;
                      path = "/graphql";
                    };
                    initial_delay_seconds = 15;
                    period_seconds = 2;
                    failure_threshold = 30;
                  };
                };

                # Frontend
                frontend = {
                  command = "${pkgs.bun}/bin/bun run --filter @ufomap/frontend dev";
                  depends_on = {
                    "graphql".condition = "process_healthy";
                    "install-deps".condition = "process_completed_successfully";
                  };
                  readiness_probe = {
                    http_get = {
                      host = "localhost";
                      port = 5173;
                    };
                    initial_delay_seconds = 3;
                    period_seconds = 1;
                  };
                };

                # Open browser once everything is ready
                open-browser = {
                  command =
                    let
                      openBrowserScript = pkgs.writeShellScript "open-browser" ''
                        echo "========================================="
                        echo "✓ UFOMap is running!"
                        echo "========================================="
                        echo ""
                        echo "Services:"
                        echo "  • ClickHouse: http://localhost:8123"
                        echo "  • GraphQL:    http://localhost:4000/graphql"
                        echo "  • Frontend:   http://localhost:5173"
                        echo ""
                        echo "Expected:"
                        echo "  ✅ Map shows real-time flights from Flightradar24"
                        echo "  ✅ Hover over markers shows flight details"
                        echo ""

                        # Open browser
                        if command -v xdg-open &> /dev/null; then
                          ${pkgs.xdg-utils}/bin/xdg-open http://localhost:5173 2>/dev/null || true
                        elif command -v open &> /dev/null; then
                          open http://localhost:5173 2>/dev/null || true
                        fi

                        # Keep process alive
                        tail -f /dev/null
                      '';
                    in
                    "${openBrowserScript}";
                  depends_on = {
                    "frontend".condition = "process_healthy";
                  };
                };
              };
            };
          };
        };
    };
}
