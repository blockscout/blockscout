#!/usr/bin/env bash
# Run mix test (or ecto commands) with auto-detected environment settings.
#
# Environment-aware: if mix is not found on the host, automatically
# re-invokes itself inside the project's devcontainer via exec.sh.
#
# Usage: run-tests.sh [--chain <type>] [--] <mix_command...>
#   --chain <type>  Set CHAIN_TYPE. Overrides the CHAIN_TYPE env var.
#                   If neither --chain nor CHAIN_TYPE env var is set,
#                   CHAIN_TYPE is left unset (chain-agnostic tests).
#   <mix_command>   Full mix command, e.g.:
#                     mix test apps/explorer/test/explorer/chain_test.exs
#                     mix test apps/block_scout_web/test/.../some_test.exs:42
#                     mix ecto.create
#                     mix ecto.migrate
#
# Exit codes:
#   0  tests pass (or ecto command succeeds)
#   1  script error
#   2  tests fail or compilation error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

# --- Parse --chain flag (also honors CHAIN_TYPE env var) ---
CHAIN_TYPE="${CHAIN_TYPE:-}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --chain)
      [ "$#" -ge 2 ] || { echo "Error: --chain requires a value" >&2; exit 1; }
      CHAIN_TYPE="$2"
      shift 2
      ;;
    --)
      shift; break
      ;;
    *)
      break
      ;;
  esac
done

# Remaining args are the mix command
if [ "$#" -eq 0 ]; then
  echo "Error: no mix command provided" >&2
  echo "Usage: run-tests.sh [--chain <type>] [--] <mix_command...>" >&2
  exit 1
fi

MIX_CMD=("$@")

# --- Hardcoded env vars ---
export MIX_ENV=test
export TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5432/explorer_test"
if [ -n "$CHAIN_TYPE" ]; then
  export CHAIN_TYPE
fi

# --- If mix is not available, re-invoke inside the devcontainer ---
if ! command -v mix &>/dev/null; then
  EXEC_SH="$("$SCRIPT_DIR/_find-devcontainer-exec.sh")" || exit 1
  EXEC_ENV_ARGS=(-e "MIX_ENV=test" -e "TEST_DATABASE_URL=$TEST_DATABASE_URL")
  if [ -n "$CHAIN_TYPE" ]; then
    EXEC_ENV_ARGS+=(-e "CHAIN_TYPE=$CHAIN_TYPE")
  fi
  exec "$EXEC_SH" "${EXEC_ENV_ARGS[@]}" bash .agents/agents/scripts/run-tests.sh \
    ${CHAIN_TYPE:+--chain "$CHAIN_TYPE"} -- "${MIX_CMD[@]}"
fi

# --- Detect command type ---
# Join MIX_CMD into a string for pattern matching
MIX_CMD_STR="${MIX_CMD[*]}"

# Check if this is an ecto command (ecto.create, ecto.migrate, etc.)
if [[ "$MIX_CMD_STR" =~ mix\ ecto\. ]]; then
  echo "=== TEST_RESULTS ==="
  echo "Command: ${MIX_CMD[*]}"
  echo "---"
  cd "$PROJECT_ROOT"
  RESULT=0
  "${MIX_CMD[@]}" 2>&1 || RESULT=$?
  echo ""
  echo "---"
  if [ "$RESULT" -eq 0 ]; then
    echo "ECTO_OK"
    exit 0
  else
    echo "ECTO_FAIL"
    exit 2
  fi
fi

# --- For mix test commands: detect app and adjust paths ---
# Extract the test path argument (the arg that starts with apps/ or test/)
# and collect any extra flags (--only, --exclude, etc.)
TEST_PATH=""
EXTRA_ARGS=()
for arg in "${MIX_CMD[@]}"; do
  case "$arg" in
    mix|test) continue ;;
    apps/*|test/*) TEST_PATH="$arg" ;;
    *) EXTRA_ARGS+=("$arg") ;;
  esac
done

# Determine app and execution strategy from TEST_PATH
APP=""
RUN_DIR="$PROJECT_ROOT"
ADD_NO_START=false
ADJUSTED_PATH="$TEST_PATH"

if [[ "$TEST_PATH" == apps/block_scout_web/* ]]; then
  # block_scout_web: run from umbrella root WITH --no-start
  APP="block_scout_web"
  ADD_NO_START=true
  # Path stays as-is (apps/block_scout_web/test/...)

elif [[ "$TEST_PATH" == apps/* ]]; then
  # Other apps (explorer, indexer, ethereum_jsonrpc, etc.):
  # cd into apps/<app> and strip the apps/<app>/ prefix
  APP=$(echo "$TEST_PATH" | cut -d'/' -f2)
  RUN_DIR="$PROJECT_ROOT/apps/$APP"
  ADJUSTED_PATH="${TEST_PATH#apps/$APP/}"

elif [[ "$TEST_PATH" == test/* ]]; then
  # Already a relative path — run as-is
  APP="umbrella"
  ADJUSTED_PATH="$TEST_PATH"
fi

# Build the final command
FINAL_CMD=(mix test "$ADJUSTED_PATH")
if [ "$ADD_NO_START" = true ]; then
  FINAL_CMD+=(--no-start)
fi
if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
  FINAL_CMD+=("${EXTRA_ARGS[@]}")
fi

# --- Run tests ---
echo "=== TEST_RESULTS ==="
echo "App: ${APP:-umbrella}"
echo "Cmd: ${FINAL_CMD[*]}"
echo "---"

cd "$RUN_DIR"
RESULT=0
"${FINAL_CMD[@]}" 2>&1 || RESULT=$?

echo ""
echo "---"

if [ "$RESULT" -eq 0 ]; then
  echo "TEST_PASS"
  exit 0
else
  echo "TEST_FAIL"
  exit 2
fi
