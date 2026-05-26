#!/usr/bin/env bash
# Run mix dialyzer and return structured output.
#
# Environment-aware: if mix is not found on the host, automatically
# re-invokes itself inside the project's devcontainer via exec.sh.
#
# Usage: dialyzer-check.sh [-e KEY=VALUE]...
#   -e KEY=VALUE   Export an environment variable (repeatable).
#                  CHAIN_TYPE is required.
#
# Exit codes:
#   0  no warnings found
#   1  script error
#   2  dialyzer found warnings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse -e flags and export them into the current environment ---
ENV_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -e)
      [ "$#" -ge 2 ] || { echo "Error: -e requires a KEY=VALUE argument" >&2; exit 1; }
      ENV_ARGS+=("$2")
      export "$2"
      shift 2
      ;;
    *) break ;;
  esac
done

# --- Validate CHAIN_TYPE ---
if [ -z "${CHAIN_TYPE:-}" ]; then
  echo "ERROR: CHAIN_TYPE is required." >&2
  echo "Pass via: -e CHAIN_TYPE=<type>" >&2
  echo "Common values: default, arbitrum, optimism, polygon_zkevm, stability, etc." >&2
  exit 1
fi

# --- If mix is not available, re-invoke inside the devcontainer ---
if ! command -v mix &>/dev/null; then
  EXEC_SH="$("$SCRIPT_DIR/_find-devcontainer-exec.sh")" || exit 1
  EXEC_ENV_ARGS=()
  for v in "${ENV_ARGS[@]}"; do EXEC_ENV_ARGS+=(-e "$v"); done
  exec "$EXEC_SH" "${EXEC_ENV_ARGS[@]}" bash .agents/agents/scripts/dialyzer-check.sh "$@"
fi

# --- Run dialyzer ---
echo "=== DIALYZER_RESULTS ==="
DIALYZER_EXIT=0
mix dialyzer --format short 2>&1 || DIALYZER_EXIT=$?

if [ "$DIALYZER_EXIT" -eq 0 ]; then
  echo ""
  echo "DIALYZER_CLEAN"
  echo "No dialyzer warnings found."
  exit 0
elif [ "$DIALYZER_EXIT" -eq 2 ]; then
  echo ""
  echo "DIALYZER_WARNINGS"
  echo "Dialyzer found warnings."
  exit 2
else
  echo ""
  echo "ERROR"
  echo "Dialyzer exited with unexpected code: $DIALYZER_EXIT"
  exit 1
fi
