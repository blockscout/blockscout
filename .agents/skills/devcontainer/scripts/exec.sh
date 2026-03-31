#!/usr/bin/env bash
# Runs a command inside the project's devcontainer.
# Prefers `devcontainer exec` when available, falls back to `docker exec`.
#
# Usage: exec.sh [--env-file PATH]... [-e KEY=VALUE]... <command> [args...]
#
# Options:
#   --env-file PATH   Source an env file inside the container before running
#                     the command. PATH is relative to the project root.
#                     May be specified multiple times; files are sourced in order.
#   -e KEY=VALUE      Export an environment variable. Applied after env files,
#                     so -e values override env-file values. May be repeated.

set -euo pipefail

# --- Parse --env-file / -e options, collect the rest as the command. ----------
ENV_FILES=()
ENV_VARS=()
HAS_ENV=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-file)
      [ "$#" -ge 2 ] || { echo "Error: --env-file requires a path argument" >&2; exit 1; }
      ENV_FILES+=("$2")
      HAS_ENV=true
      shift 2
      ;;
    -e)
      [ "$#" -ge 2 ] || { echo "Error: -e requires a KEY=VALUE argument" >&2; exit 1; }
      ENV_VARS+=("$2")
      HAS_ENV=true
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  echo "Usage: exec.sh [--env-file PATH]... [-e KEY=VALUE]... <command> [args...]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# Verify a container is running (exits with a friendly message if not)
CONTAINER_ID="$("$SCRIPT_DIR/get-container-id.sh")"

# --- Execution helpers --------------------------------------------------------

run_devcontainer() {
  exec devcontainer exec --workspace-folder "$PROJECT_ROOT" -- "$@"
}

run_docker() {
  # Detect remote workspace folder from the container's bind mount (requires jq).
  # Falls back to /workspaces/<project-basename> convention if jq is absent.
  local workspace_dir=""
  if command -v jq >/dev/null 2>&1; then
    workspace_dir="$(docker inspect "$CONTAINER_ID" \
      | jq -r --arg src "$PROJECT_ROOT" \
        '.[0].Mounts[] | select(.Type == "bind" and .Source == $src) | .Destination')"
  fi
  if [ -z "$workspace_dir" ] || [ "$workspace_dir" = "null" ]; then
    workspace_dir="/workspaces/$(basename "$PROJECT_ROOT")"
  fi

  # Detect remote user from container metadata, default to "vscode".
  local remote_user=""
  if command -v jq >/dev/null 2>&1; then
    remote_user="$(docker inspect "$CONTAINER_ID" \
      | jq -r '
        .[0].Config.Labels["devcontainer.metadata"] // empty
        | fromjson? // []
        | [.[] | select(.remoteUser)] | if length > 0 then last.remoteUser else empty end
      ')" || true
  fi
  if [ -z "$remote_user" ] || [ "$remote_user" = "null" ]; then
    remote_user="vscode"
  fi

  exec docker exec -u "$remote_user" -w "$workspace_dir" "$CONTAINER_ID" "$@"
}

run_in_container() {
  if command -v devcontainer >/dev/null 2>&1; then
    run_devcontainer "$@"
  else
    run_docker "$@"
  fi
}

# --- Build the command to run inside the container ----------------------------

# When env files or vars are specified, wrap the command in a shell that sources
# the files and exports the vars before exec-ing the actual command.
if [ "$HAS_ENV" = true ]; then
  PREAMBLE=""

  for f in ${ENV_FILES[@]+"${ENV_FILES[@]}"}; do
    # Paths are relative to project root → resolved to workspace dir inside the
    # container. Only run_docker needs the absolute container path; devcontainer
    # exec resolves relative paths via --workspace-folder automatically.
    PREAMBLE+="set -a; . \"\${PWD}/${f}\"; set +a; "
  done

  for v in ${ENV_VARS[@]+"${ENV_VARS[@]}"}; do
    PREAMBLE+="export ${v}; "
  done

  run_in_container bash -c "${PREAMBLE}"'exec "$@"' -- "$@"
else
  run_in_container "$@"
fi
