#!/usr/bin/env bash
# Generate the public OpenAPI spec YAML from Blockscout's OpenApiSpex annotations.
#
# Environment-aware: if mix is not found on the host, automatically
# re-invokes itself inside the project's devcontainer via exec.sh.
#
# Usage: generate-spec.sh [--chain <type>] [--output <path>]
#   --chain <type>   Set CHAIN_TYPE for chain-specific endpoints (optional).
#   --output <path>  Output file path (default: .ai/tmp/openapi_public.yaml,
#                    or .ai/tmp/openapi_public_<chain>.yaml when --chain is set).
#
# Exit codes:
#   0  spec generated successfully
#   1  script error (bad arguments, missing dependencies)
#   2  spec generation failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

SPEC_MODULE="BlockScoutWeb.Specs.Public"

# --- Parse flags ---
CHAIN_TYPE="${CHAIN_TYPE:-}"
OUTPUT_PATH=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --chain)
      [ "$#" -ge 2 ] || { echo "Error: --chain requires a value" >&2; exit 1; }
      CHAIN_TYPE="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || { echo "Error: --output requires a value" >&2; exit 1; }
      OUTPUT_PATH="$2"
      shift 2
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      echo "Usage: generate-spec.sh [--chain <type>] [--output <path>]" >&2
      exit 1
      ;;
  esac
done

# --- Compute default output path ---
if [ -z "$OUTPUT_PATH" ]; then
  if [ -n "$CHAIN_TYPE" ]; then
    OUTPUT_PATH=".ai/tmp/openapi_public_${CHAIN_TYPE}.yaml"
  else
    OUTPUT_PATH=".ai/tmp/openapi_public.yaml"
  fi
fi

# --- Export CHAIN_TYPE if set ---
if [ -n "$CHAIN_TYPE" ]; then
  export CHAIN_TYPE
fi

# --- If mix is not available, re-invoke inside the devcontainer ---
if ! command -v mix &>/dev/null; then
  # Locate _find-devcontainer-exec.sh
  FIND_EXEC=""
  for agents_dir in "$PROJECT_ROOT/.agents/agents/scripts" "$PROJECT_ROOT/.claude/agents/scripts"; do
    if [ -x "$agents_dir/_find-devcontainer-exec.sh" ]; then
      FIND_EXEC="$agents_dir/_find-devcontainer-exec.sh"
      break
    fi
  done
  if [ -z "$FIND_EXEC" ]; then
    echo "Error: _find-devcontainer-exec.sh not found in .agents/agents/scripts or .claude/agents/scripts" >&2
    exit 1
  fi

  EXEC_SH="$("$FIND_EXEC")" || exit 1

  EXEC_ENV_ARGS=()
  if [ -n "$CHAIN_TYPE" ]; then
    EXEC_ENV_ARGS+=(-e "CHAIN_TYPE=$CHAIN_TYPE")
  fi

  exec "$EXEC_SH" ${EXEC_ENV_ARGS[@]+"${EXEC_ENV_ARGS[@]}"} \
    bash .agents/skills/openapi-spec/scripts/generate-spec.sh \
    ${CHAIN_TYPE:+--chain "$CHAIN_TYPE"} --output "$OUTPUT_PATH"
fi

# --- Ensure output directory exists ---
mkdir -p "$PROJECT_ROOT/.ai/tmp"

# --- Run spec generation ---
cd "$PROJECT_ROOT"

CAPTURE_FILE="$PROJECT_ROOT/.ai/tmp/.generate-spec-output-$$.log"
cleanup() { rm -f "$CAPTURE_FILE"; }
trap cleanup EXIT

RESULT=0
mix openapi.spec.yaml --spec "$SPEC_MODULE" "$OUTPUT_PATH" --start-app=false \
  >"$CAPTURE_FILE" 2>&1 || RESULT=$?

echo "=== SPEC_RESULTS ==="
if [ -n "$CHAIN_TYPE" ]; then
  echo "Chain: $CHAIN_TYPE"
else
  echo "Chain: default"
fi

if [ "$RESULT" -eq 0 ]; then
  echo "Output: $OUTPUT_PATH"
  echo "---"
  echo "SPEC_OK"
  exit 0
else
  echo "---"
  cat "$CAPTURE_FILE"
  echo "---"
  echo "SPEC_FAIL"
  exit 2
fi
