{
  description = "Flight tracking and visualization platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
  };
  
  # Use the latest Node.js 22.x from nixpkgs
  # nodejs_22 in nixos-24.11 should be 22.12+ or later

  outputs = inputs:
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

      perSystem = { self', pkgs, lib, ... }: {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bun
            nodejs_22
            clickhouse
            process-compose
          ];

          shellHook = ''
            export CLICKHOUSE_CLIENT_PAGER="less -S"
            echo "🚀 nix-ts-map development environment"
            echo ""
            echo "Available tools:"
            echo "  - Bun: $(bun --version)"
            echo "  - Node.js: $(node --version)"
            echo "  - ClickHouse: $(clickhouse-client --version | head -n1)"
            echo ""
            echo "Quick Start:"
            echo "  nix run          # Start entire stack (ClickHouse + services)"
            echo "  bun install      # Install dependencies"
            echo "  bun test         # Run tests"
            echo ""
          '';
        };

        # Make process-compose the default package for nix run
        # The package name matches the process-compose service name
        packages.default = self'.packages.nix-ts-map;

        # Database reset package
        packages.wipe-db = pkgs.writeShellApplication {
          name = "wipe-db";
          runtimeInputs = with pkgs; [
            clickhouse
            bash
            coreutils
          ];
          text = ''
            # Get the project root directory
            # This script should be run from the project root
            PROJECT_ROOT="''${PROJECT_ROOT:-$(pwd)}"
            cd "$PROJECT_ROOT"
            
            # Run the reset database script
            exec bash ${./scripts/reset-database.sh}
          '';
        };

        # Process-compose services configuration
        process-compose."nix-ts-map" = {
          # TUI configuration
          cli = {
            environment = {
              PC_DISABLE_TUI = false;
            };
          };

          # Custom settings for all processes
          settings = {
            log_location = "./logs/process-compose";
            log_level = "info";

            environment = {
              # ClickHouse connection details
              CLICKHOUSE_HOST = "localhost";
              CLICKHOUSE_PORT = "8123";
              CLICKHOUSE_USER = "default";
              CLICKHOUSE_PASSWORD = "";
              CLICKHOUSE_DATABASE = "default";

              # Scraper config (Finland bounds)
              FINLAND_BOUNDS = "60,20,70,30";
              SCRAPE_INTERVAL_SECONDS = "60";

              # GraphQL server config
              PORT = "4000";
              HOST = "0.0.0.0";

              # Frontend config
              VITE_GRAPHQL_URL = "http://localhost:4000/graphql";
            };

            processes = {
              # ClickHouse database service
              "nix-ts-map-db" = {
                command = "${pkgs.bash}/bin/bash -c 'cd $PWD && ${pkgs.clickhouse}/bin/clickhouse-server --config-file=./db/clickhouse-config.xml 2>&1 | ${pkgs.coreutils}/bin/tee ./logs/clickhouse.log'";
                availability.restart = "always";
                readiness_probe = {
                  exec = {
                    command = "${pkgs.clickhouse}/bin/clickhouse-client --query 'SELECT 1'";
                  };
                  initial_delay_seconds = 5;
                  period_seconds = 5;
                  timeout_seconds = 2;
                  success_threshold = 1;
                  failure_threshold = 3;
                };
              };

              # Install dependencies first
              install-deps = {
                command = "${pkgs.bash}/bin/bash -c '${pkgs.bun}/bin/bun install 2>&1 | ${pkgs.coreutils}/bin/tee ./logs/install-deps.log'";
                depends_on = {
                  "nix-ts-map-db".condition = "process_healthy";
                };
                availability.restart = "no";
              };

              # Apply database migrations after ClickHouse is ready
              setup-database = {
                command =
                  let
                    setupScript = pkgs.writeShellScript "setup-database" ''
                      set -e
                      
                      echo "========================================="
                      echo "nix-ts-map Database Setup"
                      echo "========================================="
                      echo ""
                      echo "Waiting for ClickHouse to be ready..."
                      for i in {1..30}; do
                        if ${pkgs.curl}/bin/curl -s http://localhost:8123/ping | grep -q "Ok"; then
                          echo "✓ ClickHouse ready"
                          echo ""

                          # Apply migrations
                          echo "→ Applying migrations..."
                          ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./db/migrations/001_initial_schema.sql} > ./logs/migration-001.log 2>&1 || {
                            echo "✗ Migration 001 failed. Check ./logs/migration-001.log"
                            exit 1
                          }
                          ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./db/migrations/002_h3_enrichment.sql} > ./logs/migration-002.log 2>&1 || {
                            echo "✗ Migration 002 failed. Check ./logs/migration-002.log"
                            exit 1
                          }
                          ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./db/migrations/003_materialized_views.sql} > ./logs/migration-003.log 2>&1 || {
                            echo "✗ Migration 003 failed. Check ./logs/migration-003.log"
                            exit 1
                          }
                          ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./db/migrations/004_multi_resolution_views.sql} > ./logs/migration-004.log 2>&1 || {
                            echo "✗ Migration 004 failed. Check ./logs/migration-004.log"
                            exit 1
                          }
                          echo "✓ Migrations applied"
                          echo ""

                          echo "========================================="
                          echo "✓ Database setup complete!"
                          echo "========================================="
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
                  "nix-ts-map-db".condition = "process_healthy";
                };
                availability.restart = "no";
              };

              # Scraper service
              scraper = {
                command = "${pkgs.bash}/bin/bash -c '${pkgs.bun}/bin/bun run packages/map-scraper/src/index.ts 2>&1 | ${pkgs.coreutils}/bin/tee ./logs/scraper.log'";
                depends_on = {
                  "nix-ts-map-db".condition = "process_healthy";
                  "install-deps".condition = "process_completed_successfully";
                  "setup-database".condition = "process_completed_successfully";
                };
              };

              # GraphQL server
              graphql = {
                command = "${pkgs.bash}/bin/bash -c '${pkgs.bun}/bin/bun run packages/map-graphql/src/index.ts 2>&1 | ${pkgs.coreutils}/bin/tee ./logs/graphql.log'";
                depends_on = {
                  "nix-ts-map-db".condition = "process_healthy";
                  "install-deps".condition = "process_completed_successfully";
                  "setup-database".condition = "process_completed_successfully";
                };
                readiness_probe = {
                  http_get = {
                    host = "localhost";
                    port = 4000;
                    path = "/health";
                  };
                  initial_delay_seconds = 5;
                  period_seconds = 2;
                  failure_threshold = 30;
                };
              };

              # Frontend
              frontend = {
                command = "${pkgs.bash}/bin/bash -c 'cd packages/map-frontend && PATH=\"$PWD/node_modules/.bin:$PATH\" ${pkgs.bun}/bin/bun run dev 2>&1 | ${pkgs.coreutils}/bin/tee ../../logs/frontend.log'";
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
                      echo "✓ nix-ts-map is running!"
                      echo "========================================="
                      echo ""
                      echo "Services:"
                      echo "  • ClickHouse: http://localhost:8123"
                      echo "  • GraphQL:    http://localhost:4000/graphql"
                      echo "  • Frontend:   http://localhost:5173"
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

