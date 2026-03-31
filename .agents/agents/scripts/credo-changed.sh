#!/usr/bin/env bash
# Run mix credo and report only issues in Elixir files changed in the current branch.
#
# Runs `mix credo --format json` on the full project (respecting .credo.exs),
# then filters the JSON output to keep only issues in changed files.
#
# Environment-aware: if mix is not found on the host, automatically
# re-invokes itself inside the project's devcontainer via exec.sh.
#
# Usage: credo-changed.sh [-e KEY=VALUE]... [base-branch]
#   -e KEY=VALUE   Export an environment variable (repeatable).
#                  CHAIN_TYPE is required.
#   base-branch    defaults to auto-detected master or main
#
# Exit codes:
#   0  no issues found (or no changed files)
#   1  script error
#   16 credo found issues (same as mix credo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

DEBUG=true

if [ "$DEBUG" = true ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  LOG_FILE="$PROJECT_ROOT/tmp/credo-changed-${TIMESTAMP}.log"
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
  log "exec: $EXEC_SH ${EXEC_ENV_ARGS[*]} bash .agents/agents/scripts/credo-changed.sh $*"
  exec "$EXEC_SH" "${EXEC_ENV_ARGS[@]}" bash .agents/agents/scripts/credo-changed.sh "$@"
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

# --- Run mix credo on the full project, filter to changed files ---
echo "=== CREDO_RESULTS ==="

# Build a jq filter array from the changed file list
FILES_JSON="$(echo "$EXISTING_FILES" | jq -R . | jq -s .)"
log "Files JSON: $FILES_JSON"

# Run credo on the full project (respects .credo.exs included/excluded),
# then keep only issues whose filename matches a changed file.
# Stderr is suppressed — mix compilation warnings would break JSON parsing.
CREDO_JSON="$(mix credo --format json 2>/dev/null)" || true
FILTERED_JSON="$(echo "$CREDO_JSON" | jq --argjson files "$FILES_JSON" \
  '{ issues: [.issues[] | select(.filename as $f | $files | any(. == $f))] }')"

ISSUE_COUNT="$(echo "$FILTERED_JSON" | jq '.issues | length')"
log "Credo issues in changed files: $ISSUE_COUNT"

if [ "$ISSUE_COUNT" -eq 0 ]; then
  echo "=== CREDO_CLEAN ==="
  echo "No credo issues found in changed files."
  log "Credo: CLEAN"
  exit 0
fi

# Pretty-print filtered issues for the agent to parse
echo "$FILTERED_JSON" | jq -r '.issues[] | "\(.filename):\(.line_no):\(.column // 0) \(.category) [\(.check)] \(.message)"'
echo ""
echo "CREDO_ISSUES $ISSUE_COUNT"
log "Credo: $ISSUE_COUNT issues found"

# --- Collect explanations for each issue (limit to 15) ---
echo ""
echo "=== CREDO_EXPLANATIONS ==="
REFS="$(echo "$FILTERED_JSON" | jq -r '.issues[:15][] | "\(.filename):\(.line_no):\(.column // 0)"')"

while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  log "Explaining: $ref"
  echo "--- EXPLAIN: $ref ---"
  mix credo explain "$ref" </dev/null 2>/dev/null || true
  echo ""
done <<< "$REFS"

exit 16
