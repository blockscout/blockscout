#!/usr/bin/env bash
# Locates the devcontainer exec.sh by searching known skill directories.
# Prints the absolute path on stdout. Exits non-zero if not found.
#
# Searches in order:
#   1. $PROJECT_ROOT/.agents/skills/devcontainer/scripts/exec.sh
#   2. $PROJECT_ROOT/.claude/skills/devcontainer/scripts/exec.sh
#
# This covers all layouts:
#   - Only .agents/skills/ exists (agents run from .agents/agents/)
#   - Only .claude/skills/ exists (agents run from .claude/agents/)
#   - .claude/skills is a symlink to .agents/skills (both resolve)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

AI_TMP_DIR="$PROJECT_ROOT/.ai/tmp"

DEBUG=false

if [ "$DEBUG" = true ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  LOG_FILE="$AI_TMP_DIR/find-devcontainer-exec-${TIMESTAMP}.log"
  mkdir -p "$AI_TMP_DIR"
  log() { echo "[$(date +%T)] $*" >> "$LOG_FILE"; }
  trap 'log "ERROR: script failed at line $LINENO (exit $?)"' ERR
  log "Script started, cwd=$(pwd)"
else
  log() { :; }
fi

log "project_root=$PROJECT_ROOT"

for skills_dir in "$PROJECT_ROOT/.agents/skills" "$PROJECT_ROOT/.claude/skills"; do
  candidate="$skills_dir/devcontainer/scripts/exec.sh"
  log "Checking candidate: $candidate"
  if [ -x "$candidate" ]; then
    log "Found exec.sh: $candidate"
    echo "$candidate"
    exit 0
  fi
  log "Not found or not executable"
done

log "ERROR: devcontainer skill not found"
echo "ERROR: devcontainer skill not found in .agents/skills or .claude/skills" >&2
echo "Ensure the devcontainer skill is installed with scripts/exec.sh present." >&2
exit 1
