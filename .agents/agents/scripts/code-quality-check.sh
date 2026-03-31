#!/usr/bin/env bash
# Run fast code quality checks (format, credo, spell check) on changed Elixir files.
#
# Environment-aware: if mix is not found on the host, automatically
# re-invokes itself inside the project's devcontainer via exec.sh.
#
# Usage: code-quality-check.sh [-e KEY=VALUE]... [base-branch]
#   -e KEY=VALUE   Export an environment variable (repeatable).
#                  CHAIN_TYPE is required.
#   base-branch    defaults to auto-detected master or main
#
# Exit codes:
#   0  all checks pass (or no changed files)
#   1  script error
#   2  one or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

DEBUG=true

if [ "$DEBUG" = true ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  LOG_FILE="$PROJECT_ROOT/tmp/code-quality-check-${TIMESTAMP}.log"
  mkdir -p "$PROJECT_ROOT/tmp"
  log() { echo "[$(date +%T)] $*" >> "$LOG_FILE"; }
  trap 'log "ERROR: script failed at line $LINENO (exit $?)"' ERR
  log "Script started, cwd=$(pwd), args=$*"
else
  log() { :; }
fi

# --- Parse -e flags and export them into the current environment ---
ENV_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -e)
      [ "$#" -ge 2 ] || { echo "Error: -e requires a KEY=VALUE argument" >&2; exit 1; }
      ENV_ARGS+=("$2")
      export "$2"
      log "Parsed env: $2"
      shift 2
      ;;
    *) break ;;
  esac
done

log "CHAIN_TYPE=${CHAIN_TYPE:-<unset>}"

# --- Validate CHAIN_TYPE ---
if [ -z "${CHAIN_TYPE:-}" ]; then
  echo "ERROR: CHAIN_TYPE is required." >&2
  echo "Pass via: -e CHAIN_TYPE=<type>" >&2
  echo "Common values: default, arbitrum, optimism, polygon_zkevm, stability, etc." >&2
  exit 1
fi

# --- If mix is not available, re-invoke inside the devcontainer ---
if ! command -v mix &>/dev/null; then
  log "mix not found on host, delegating to devcontainer"
  EXEC_SH="$("$SCRIPT_DIR/_find-devcontainer-exec.sh")" || exit 1
  EXEC_ENV_ARGS=()
  for v in "${ENV_ARGS[@]}"; do EXEC_ENV_ARGS+=(-e "$v"); done
  log "exec: $EXEC_SH ${EXEC_ENV_ARGS[*]} bash .agents/agents/scripts/code-quality-check.sh $*"
  exec "$EXEC_SH" "${EXEC_ENV_ARGS[@]}" bash .agents/agents/scripts/code-quality-check.sh "$@"
fi

log "mix found, running locally"

BASE_BRANCH="${1:-}"

# --- Auto-detect base branch ---
if [ -z "$BASE_BRANCH" ]; then
  for candidate in master main; do
    if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      BASE_BRANCH="$candidate"
      break
    fi
  done
fi

if [ -z "$BASE_BRANCH" ]; then
  echo "ERROR: Could not find master or main branch" >&2
  exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
log "branch=$CURRENT_BRANCH, base=$BASE_BRANCH"

# --- Collect changed Elixir files (deduplicated, existing only) ---
collect_files() {
  {
    # Untracked files (new files not yet git-added)
    git ls-files --others --exclude-standard 2>/dev/null || true
    # Unstaged changes
    git diff --name-only 2>/dev/null || true
    # Staged changes
    git diff --cached --name-only 2>/dev/null || true
    # Committed changes vs base (skip if on the base branch itself)
    if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
      MERGE_BASE="$(git merge-base "$BASE_BRANCH" HEAD 2>/dev/null || true)"
      if [ -n "$MERGE_BASE" ]; then
        git diff --name-only "$MERGE_BASE"..HEAD 2>/dev/null || true
      fi
    fi
  } | sort -u | grep -E '\.exs?$' || true
}

CHANGED_FILES="$(collect_files)"

# Filter to files that actually exist (skip deleted files)
EXISTING_FILES=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] && EXISTING_FILES="${EXISTING_FILES:+$EXISTING_FILES$'\n'}$f"
done <<< "$CHANGED_FILES"

if [ -z "$EXISTING_FILES" ]; then
  echo "NO_FILES"
  echo "No changed Elixir files found (branch: $CURRENT_BRANCH, base: $BASE_BRANCH)."
  log "No changed files found"
  exit 0
fi

FILE_COUNT="$(echo "$EXISTING_FILES" | wc -l | tr -d ' ')"
log "Changed files: $FILE_COUNT"

echo "CHANGED_FILES $FILE_COUNT"
echo "$EXISTING_FILES"
echo ""

FAILED=0

# --- Check 1: Formatting ---
echo "=== FORMAT_RESULTS ==="
FORMAT_EXIT=0
# shellcheck disable=SC2086
mix format --check-formatted $EXISTING_FILES 2>&1 || FORMAT_EXIT=$?

if [ "$FORMAT_EXIT" -eq 0 ]; then
  echo "FORMAT_PASS"
  log "Format: PASS"
else
  echo "FORMAT_FAIL"
  log "Format: FAIL (exit=$FORMAT_EXIT)"
  FAILED=1
fi
echo ""

# --- Check 2: Credo (delegate to existing script) ---
echo "=== CREDO_RESULTS ==="
CREDO_EXIT=0
# CHAIN_TYPE is already exported; credo-changed.sh inherits it.
bash "$PROJECT_ROOT/.agents/agents/scripts/credo-changed.sh" "$BASE_BRANCH" 2>&1 || CREDO_EXIT=$?

if [ "$CREDO_EXIT" -eq 0 ]; then
  echo "CREDO_PASS"
  log "Credo: PASS"
else
  echo "CREDO_FAIL"
  log "Credo: FAIL (exit=$CREDO_EXIT)"
  FAILED=1
fi
echo ""

# --- Check 3: Spell check ---
echo "=== CSPELL_RESULTS ==="
if ! command -v cspell &>/dev/null; then
  echo "CSPELL_SKIP"
  echo "cspell is not installed — skipping spell check."
  log "cspell: SKIP (not installed)"
else
  CSPELL_EXIT=0
  # shellcheck disable=SC2086
  cspell --gitignore --config cspell.json $EXISTING_FILES 2>&1 || CSPELL_EXIT=$?

  if [ "$CSPELL_EXIT" -eq 0 ]; then
    echo "CSPELL_PASS"
    log "cspell: PASS"
  else
    echo "CSPELL_FAIL"
    log "cspell: FAIL (exit=$CSPELL_EXIT)"
    FAILED=1
  fi
fi
echo ""

# --- Final status ---
if [ "$FAILED" -eq 0 ]; then
  echo "=== ALL_PASS ==="
  log "Overall: ALL_PASS"
  exit 0
else
  echo "=== CHECKS_FAILED ==="
  log "Overall: CHECKS_FAILED"
  exit 2
fi
