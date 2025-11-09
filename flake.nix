{
  description = "Flight tracking and visualization platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
  };

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

        # Process-compose services configuration
        process-compose."nix-ts-map" = {
          # TUI configuration
          cli = {
            environment = {
              PC_DISABLE_TUI = false;
            };
            # Use a different port if 8080 is in use
            port = 8081;
          };

          # Custom settings for all processes
          settings = {
            log_location = "./logs/process-compose";
            log_level = "info";
            # Enable file logging for all processes
            log_file = "./logs/process-compose.log";

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
                command = "${pkgs.clickhouse}/bin/clickhouse-server";
                availability.restart = "always";
                # Log to file
                stdout = "./logs/clickhouse-stdout.log";
                stderr = "./logs/clickhouse-stderr.log";
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
                command = "${pkgs.bun}/bin/bun install 2>&1 | tee ./logs/install-deps.log";
                depends_on = {
                  "nix-ts-map-db".condition = "process_healthy";
                };
                availability.restart = "no";
                stdout = "./logs/install-deps-stdout.log";
                stderr = "./logs/install-deps-stderr.log";
              };

              # Apply database migrations after ClickHouse is ready
              setup-database = {
                command =
                  let
                    setupScript = pkgs.writeShellScript "setup-database" ''
                      set -e
                      exec > >(tee -a ./logs/setup-database.log)
                      exec 2>&1
                      
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
                          ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./db/migrations/001_initial_schema.sql} 2>&1 | tee -a ./logs/migration-001.log
                          ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./db/migrations/002_h3_enrichment.sql} 2>&1 | tee -a ./logs/migration-002.log
                          ${pkgs.clickhouse}/bin/clickhouse-client --multiquery < ${./db/migrations/003_materialized_views.sql} 2>&1 | tee -a ./logs/migration-003.log
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
                stdout = "./logs/setup-database-stdout.log";
                stderr = "./logs/setup-database-stderr.log";
              };

              # Scraper service
              scraper = {
                command = "${pkgs.bun}/bin/bun run packages/map-scraper/src/index.ts";
                depends_on = {
                  "nix-ts-map-db".condition = "process_healthy";
                  "install-deps".condition = "process_completed_successfully";
                  "setup-database".condition = "process_completed_successfully";
                };
                stdout = "./logs/scraper-stdout.log";
                stderr = "./logs/scraper-stderr.log";
              };

              # GraphQL server
              graphql = {
                command = "${pkgs.bun}/bin/bun run packages/map-graphql/src/index.ts";
                depends_on = {
                  "nix-ts-map-db".condition = "process_healthy";
                  "install-deps".condition = "process_completed_successfully";
                  "setup-database".condition = "process_completed_successfully";
                };
                stdout = "./logs/graphql-stdout.log";
                stderr = "./logs/graphql-stderr.log";
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
                command = "${pkgs.bun}/bin/bun run --cwd packages/map-frontend dev";
                depends_on = {
                  "graphql".condition = "process_healthy";
                  "install-deps".condition = "process_completed_successfully";
                };
                stdout = "./logs/frontend-stdout.log";
                stderr = "./logs/frontend-stderr.log";
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

