#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-}"
WORKDIR_REL=""
LOG_FILE_REL=""

usage() {
  cat >&2 <<'EOF'
Usage: with-dotenv.sh [--project-root PATH] [--chdir DIR] [--log-file FILE] -- COMMAND [ARGS...]

Loads environment variables from .env (falling back to .env.example) and then
executes the given command. Paths passed to --chdir and --log-file are resolved
relative to the project root.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      [[ $# -ge 2 ]] || { echo "with-dotenv.sh: --project-root requires a path" >&2; exit 64; }
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --chdir)
      [[ $# -ge 2 ]] || { echo "with-dotenv.sh: --chdir requires a path" >&2; exit 64; }
      WORKDIR_REL="$2"
      shift 2
      ;;
    --log-file)
      [[ $# -ge 2 ]] || { echo "with-dotenv.sh: --log-file requires a path" >&2; exit 64; }
      LOG_FILE_REL="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
    ;;
    -*)
      echo "with-dotenv.sh: unknown option: $1" >&2
      usage
      exit 64
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -eq 0 ]]; then
  echo "with-dotenv.sh: missing command. Use -- COMMAND [ARGS...]" >&2
  usage
  exit 64
fi

if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$(pwd)"
else
  PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
fi

WORKDIR="$PROJECT_ROOT"
if [[ -n "$WORKDIR_REL" ]]; then
  WORKDIR="$PROJECT_ROOT/$WORKDIR_REL"
fi

load_env_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
    return 0
  fi
  return 1
}

if ! load_env_file "$PROJECT_ROOT/.env"; then
  if load_env_file "$PROJECT_ROOT/.env.example"; then
    echo "with-dotenv.sh: .env not found, using .env.example defaults" >&2
  else
    echo "with-dotenv.sh: warning - no .env or .env.example found" >&2
  fi
fi

cd "$WORKDIR"

run_command() {
  if [[ -n "$LOG_FILE_REL" ]]; then
    local log_path
    if [[ "$LOG_FILE_REL" = /* ]]; then
      log_path="$LOG_FILE_REL"
    else
      log_path="$PROJECT_ROOT/$LOG_FILE_REL"
    fi
    mkdir -p "$(dirname "$log_path")"
    "$@" 2>&1 | tee "$log_path"
    exit "${PIPESTATUS[0]}"
  else
    exec "$@"
  fi
}

run_command "$@"
