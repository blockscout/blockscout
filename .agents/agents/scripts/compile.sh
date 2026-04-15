#!/usr/bin/env bash
# Compile the Blockscout Elixir project with auto-detected environment settings.
#
# Environment-aware: if mix is not found on the host, automatically
# re-invokes itself inside the project's devcontainer via exec.sh.
#
# Usage: compile.sh --chain <type> [--mode standard|full|init]
#   --chain <type>  Set CHAIN_TYPE (required).
#   --mode <mode>   Compilation mode (default: standard).
#                     standard — deps.get + compile (after code edits)
#                     full     — deps.clean + forced recompile (after CHAIN_TYPE/branch switch)
#                     init     — first-time setup (includes phx.gen.cert)
#
# Exit codes:
#   0  compilation succeeded
#   1  script error
#   2  compilation failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# --- Parse flags ---
CHAIN_TYPE="${CHAIN_TYPE:-}"
MODE="standard"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --chain)
      [ "$#" -ge 2 ] || { echo "Error: --chain requires a value" >&2; exit 1; }
      CHAIN_TYPE="$2"
      shift 2
      ;;
    --mode)
      [ "$#" -ge 2 ] || { echo "Error: --mode requires a value" >&2; exit 1; }
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      echo "Usage: compile.sh --chain <type> [--mode standard|full|init]" >&2
      exit 1
      ;;
  esac
done

# --- Validate arguments ---
if [ -z "$CHAIN_TYPE" ]; then
  echo "Error: --chain is required" >&2
  echo "Usage: compile.sh --chain <type> [--mode standard|full|init]" >&2
  exit 1
fi

case "$MODE" in
  standard|full|init) ;;
  *)
    echo "Error: invalid mode: $MODE (must be standard, full, or init)" >&2
    exit 1
    ;;
esac

export CHAIN_TYPE

# --- If mix is not available, re-invoke inside the devcontainer ---
if ! command -v mix &>/dev/null; then
  EXEC_SH="$("$SCRIPT_DIR/_find-devcontainer-exec.sh")" || exit 1
  exec "$EXEC_SH" -e "CHAIN_TYPE=$CHAIN_TYPE" \
    bash .agents/agents/scripts/compile.sh --chain "$CHAIN_TYPE" --mode "$MODE"
fi

# --- Standard Blockscout app names (for deps.clean in full mode) ---
BLOCKSCOUT_APPS="block_scout_web ethereum_jsonrpc explorer indexer utils nft_media_handler"

# --- Run compilation ---
cd "$PROJECT_ROOT"

echo "=== COMPILE_RESULTS ==="
echo "Mode: $MODE"
echo "Chain: $CHAIN_TYPE"
echo "---"

RESULT=0

case "$MODE" in
  standard)
    mix do deps.get, local.hex --force, local.rebar --force, deps.compile, compile 2>&1 || RESULT=$?
    ;;

  full)
    # shellcheck disable=SC2086
    mix deps.clean $BLOCKSCOUT_APPS 2>&1 || RESULT=$?
    if [ "$RESULT" -eq 0 ]; then
      mix do deps.get, local.hex --force, local.rebar --force, deps.compile --force, compile 2>&1 || RESULT=$?
    fi
    ;;

  init)
    mix do local.hex --force, local.rebar --force, deps.get, deps.compile, compile 2>&1 || RESULT=$?
    if [ "$RESULT" -eq 0 ]; then
      if [ ! -d "$PROJECT_ROOT/apps/block_scout_web/priv/cert" ]; then
        (cd apps/block_scout_web && mix phx.gen.cert blockscout blockscout.local) 2>&1 || RESULT=$?
      fi
    fi
    ;;
esac

echo ""
echo "---"

if [ "$RESULT" -eq 0 ]; then
  echo "COMPILE_OK"
  exit 0
else
  echo "COMPILE_FAIL"
  exit 2
fi
