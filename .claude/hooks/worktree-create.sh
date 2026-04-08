#!/usr/bin/env bash
# WorktreeCreate hook for Claude Code.
# Must be registered in .claude/settings.local.json under hooks.WorktreeCreate:
#
#   "hooks": {
#     "WorktreeCreate": [
#       { "hooks": [{ "type": "command", "command": "bash .claude/hooks/worktree-create.sh" }] }
#     ]
#   }
#
# Reads worktree name from stdin as JSON ({ "name": "..." }), creates a git worktree
# at <repo_root>/../.worktrees/<repo_name>/<name>, and prints its absolute path to stdout.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

AI_TMP_DIR="$PROJECT_ROOT/.ai/tmp"

DEBUG=false

if [ "$DEBUG" = true ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  LOG_FILE="$AI_TMP_DIR/worktree-create-${TIMESTAMP}.log"
  mkdir -p "$AI_TMP_DIR"
  log() { echo "[$(date +%T)] $*" >> "$LOG_FILE"; }
  trap 'log "ERROR: script failed at line $LINENO (exit $?)"' ERR
  log "Script started, cwd=$(pwd)"
else
  log() { :; }
fi

if [ -f /.dockerenv ]; then
  echo "Worktree creation is not allowed inside Docker" >&2
  exit 1
fi

log "Reading name from stdin..."
NAME=$(jq -r .name)
# Workaround: Claude Code hangs when the worktree name contains "/".
# Pass "feat--something" and the script converts "--" → "/" so the branch
# and directory use the intended "feat/something" name.
# NOTE: This intentionally replaces ALL occurrences of "--" in the name,
# so "fix--auth--refactor" becomes "fix/auth/refactor".
NAME="${NAME//--//}"
log "name=$NAME"

# Re-derive repo root via git to handle invocation from inside an existing worktree.
# --git-common-dir always points to the main repo's .git directory.
log "Resolving repo root via git..."
REPO_ROOT=$(cd "$(git rev-parse --git-common-dir)/.." && pwd)
log "repo_root=$REPO_ROOT"

REPO_NAME=$(basename "$REPO_ROOT")
log "repo_name=$REPO_NAME"

REPOS_DIR=$(dirname "$REPO_ROOT")
DIR="$REPOS_DIR/.worktrees/$REPO_NAME/$NAME"
log "dir=$DIR"
mkdir -p "$(dirname "$DIR")"

# Check if the worktree is already registered (e.g. resuming a previous session).
# `git worktree list --porcelain` prints each worktree path prefixed with "worktree ".
if git worktree list --porcelain | grep -qxF "worktree $DIR"; then
  log "Worktree already exists, skipping creation"
  : # worktree already exists, nothing to do
# Check if the branch already exists locally.
# --verify ensures a full ref match (not a prefix), --quiet suppresses output.
elif git show-ref --verify --quiet "refs/heads/$NAME"; then
  log "Branch exists, checking out into new worktree"
  # Branch exists: check it out into the new worktree directory
  git worktree add "$DIR" "$NAME" >&2
else
  log "New branch, creating and checking out into new worktree"
  # Branch is new: create it (-b) and check it out into the new worktree directory
  git worktree add -b "$NAME" "$DIR" >&2
fi

# Create .claude/settings.local.json symlink pointing to the main repo's copy.
# The relative path depth varies with slashes in the branch name (e.g. feat/foo adds
# one extra level), so python3's os.path.relpath computes it correctly for any depth.
# Only create the symlink if the source file exists in the main repo (avoids dangling symlinks)
# and the target is not already a symlink. If a regular file already exists (e.g. from a
# previous session), leave it in place rather than failing.
SYMLINK="$DIR/.claude/settings.local.json"
if [ ! -L "$SYMLINK" ] && [ -f "$REPO_ROOT/.claude/settings.local.json" ]; then
  if [ -e "$SYMLINK" ]; then
    log "Regular file already exists at $SYMLINK, skipping symlink creation"
  else
    mkdir -p "$DIR/.claude"
    REL_TARGET=$(python3 -c "import os; print(os.path.relpath('$REPO_ROOT/.claude/settings.local.json', '$DIR/.claude'))")
    ln -s "$REL_TARGET" "$SYMLINK"
    log "Created symlink: $SYMLINK -> $REL_TARGET"
  fi
elif [ -L "$SYMLINK" ]; then
  log "Symlink already exists: $SYMLINK"
else
  log "No .claude/settings.local.json in main repo, skipping symlink"
fi

log "Done, worktree path: $DIR"
echo "$DIR"
