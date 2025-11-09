# Sprint 1 Plan: Project Foundation & Clean Environment

**Goal:** To establish a clean, minimalistic, and reproducible development environment using Nix. This foundational sprint ensures that all future development is built on a stable and consistent base.

**Holistic Perspective:** The `flake.nix` created in this sprint is the cornerstone of the entire project. It will define the exact versions of all core technologies (Bun, Node.js, ClickHouse), guaranteeing that every developer and every CI/CD run operates in an identical environment. This eliminates "works on my machine" issues and simplifies onboarding. We will include `process-compose` from the start, anticipating the multi-service architecture of the final application.

---

### Key Outcomes

1.  A new Git repository for the project.
2.  A `flake.nix` file providing a development shell with all necessary dependencies.
3.  A root `package.json` configured for monorepo workspaces.
4.  A basic directory structure (`packages/`, `db/`).

---

### Implementation Steps

1.  **Repository Initialization:**
    *   Start from a new top-level directory for the project (e.g., `nix-ts-map`).
    *   Initialize a Git repository: `git init`.
    *   Create a comprehensive `.gitignore` file. It should include entries for `node_modules/`, `.env`, `dist/`, `build/`, `*.log`, and Nix/direnv artifacts like `result*` and `.direnv/`.

2.  **`flake.nix` Definition:**
    *   Create the `flake.nix` file at the project root.
    *   **Inputs:**
        *   `nixpkgs`: Pin to a recent, stable channel (e.g., `github:NixOS/nixpkgs/nixos-25.11`). This ensures reproducibility.
        *   `flake-utils`: Use `flake-utils.lib.eachDefaultSystem` to make the shell compatible across different architectures (e.g., x86_64-linux, aarch64-darwin).
    *   **Outputs (`devShells`):**
        *   Define a default development shell (`devShells.default`).
        *   **`packages`:** Include the following from `nixpkgs`:
            *   `bun`: The primary toolkit for JavaScript/TypeScript runtime, package management, and testing.
            *   `nodejs_22`: The latest Node.js LTS, for any tools that may require it.
            *   `clickhouse`: Provides both the `clickhouse-server` and `clickhouse-client` for local database work.
            *   `process-compose`: For orchestrating the multi-service local environment in later sprints.
        *   **`shellHook` (Optional but Recommended):**
            *   Add `export CLICKHOUSE_CLIENT_PAGER="less -S"` for better client usability.
            *   Include an echo command to display a welcome message with basic instructions when a developer enters the shell.

3.  **Monorepo Scaffolding:**
    *   At the project root, run `bun init` to generate a `package.json`.
    *   Edit this `package.json` to be private (`"private": true`) and define the workspace configuration:
        ```json
        "workspaces": [
          "packages/*"
        ]
        ```
    *   Create the `packages/` directory. This will house all the individual modules of the application.
    *   Create a `db/migrations` directory to hold SQL migration files.

4.  **Verification:**
    *   Run `nix develop` to enter the development shell.
    *   Execute `bun --version`, `node --version`, and `clickhouse-client --version` to confirm that the tools specified in the flake are available and at the expected versions.
    *   Run `bun install` at the root. Although there are no packages yet, this confirms the workspace setup is correct.
    *   Add a `README.md` file with initial setup instructions:
        1.  Install Nix.
        2.  Enable Flakes.
        3.  Run `nix develop` to enter the shell.
        4.  Run `bun install`.
