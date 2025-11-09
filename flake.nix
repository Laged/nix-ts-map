{
  description = "Flight tracking and visualization platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
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
            echo "Next steps:"
            echo "  1. Run 'bun install' to install dependencies"
            echo "  2. Run 'process-compose up' to start all services"
            echo ""
          '';
        };
      }
    );
}

