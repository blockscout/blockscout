#!/usr/bin/env bash
set -euo pipefail

PREFIX="chore/openapi-spec-arbitrum"
CMD="${1:-}"
shift || true

log() { echo ">>> $*"; }

usage() {
  echo "Usage: openapi-arbitrum.sh <command> [args]"
  echo "Commands:"
  echo "  init <id>              Create working branches and merge harness"
  echo "  sync [id]              Cherry-pick commits from -tmp to -<id> branch"
  echo "  deliver <id> <message> Squash-merge -<id> into main spec branch"
  echo "  clean <id>             Remove -<id> and -<id>-tmp branches and worktrees"
  echo "  push                   Push main spec branch to remote"
  exit 1
}

case "$CMD" in
  init)
    ID="${1:?ERROR: init requires <id>}"
    BRANCH="${PREFIX}-${ID}"
    TMP="${BRANCH}-tmp"

    log "Fetching origin..."
    git fetch origin

    log "Creating branch ${BRANCH} from origin/${PREFIX}"
    git branch "$BRANCH" "origin/${PREFIX}"

    log "Creating branch ${TMP} from ${BRANCH}"
    git branch "$TMP" "$BRANCH"

    TMPDIR=$(mktemp -d)
    trap 'git worktree remove --force "$TMPDIR" 2>/dev/null; rm -rf "$TMPDIR"' EXIT

    log "Creating temporary worktree at ${TMPDIR}"
    git worktree add "$TMPDIR" "$TMP"

    cd "$TMPDIR"
    log "Squash-merging origin/chore/agentic-ide into ${TMP}"
    if ! git merge --squash "origin/chore/agentic-ide"; then
      git merge --abort
      echo "ERROR: Merge conflicts during init. Phase aborted."
      exit 1
    fi

    log "Committing HARNESS"
    git commit -m "HARNESS"

    cd - >/dev/null
    log "Removing temporary worktree"
    git worktree remove "$TMPDIR"
    trap - EXIT

    log "OK: init complete. Branch ${TMP} ready. Run: git checkout ${TMP}"
    ;;

  sync)
    if [[ -n "${1:-}" ]]; then
      ID="$1"
      log "Using provided id=${ID}"
    else
      CURRENT=$(git branch --show-current)
      log "Current branch: ${CURRENT}"
      if [[ ! "$CURRENT" =~ ^${PREFIX}-(.+)-tmp$ ]]; then
        echo "ERROR: Current branch '$CURRENT' does not match ${PREFIX}-<id>-tmp. Provide id as argument."
        exit 1
      fi
      ID="${BASH_REMATCH[1]}"
      log "Discovered id=${ID} from branch name"
    fi
    TMP="${PREFIX}-${ID}-tmp"
    TARGET="${PREFIX}-${ID}"
    log "Source branch: ${TMP}, target branch: ${TARGET}"

    BASE=$(git merge-base "$TARGET" "$TMP")
    log "Merge base: ${BASE}"

    EXISTING=""
    while IFS= read -r line; do
      EXISTING="${EXISTING}${line}"$'\n'
    done < <(git log --format="%s" "${BASE}..${TARGET}")
    EXISTING_COUNT=$(echo -n "$EXISTING" | grep -c . || true)
    log "Existing commits in ${TARGET}: ${EXISTING_COUNT}"

    COMMITS=""
    while IFS= read -r line; do
      COMMITS="${COMMITS}${line}"$'\n'
    done < <(git log --reverse --format="%H|%s" "${BASE}..${TMP}")
    COMMITS_COUNT=$(echo -n "$COMMITS" | grep -c . || true)
    log "Commits in ${TMP} since base: ${COMMITS_COUNT}"

    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
    log "Getting or creating worktree for ${TARGET}"
    WTDIR=$(echo "{\"name\": \"${TARGET}\"}" | bash "${PROJECT_ROOT}/.claude/hooks/worktree-create.sh")
    log "Worktree path: ${WTDIR}"

    cd "$WTDIR"
    PICKED=0
    SKIPPED=0
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      SHA="${entry%%|*}"
      SUBJECT="${entry#*|}"

      if [[ "$SUBJECT" == "HARNESS" ]]; then
        log "SKIP: HARNESS commit ${SHA:0:8}"
        ((SKIPPED++)) || true
        continue
      fi

      if echo -n "$EXISTING" | grep -qxF "$SUBJECT"; then
        log "SKIP: ${SHA:0:8} — ${SUBJECT} (already exists)"
        ((SKIPPED++)) || true
        continue
      fi

      if ! git cherry-pick "$SHA"; then
        echo "ERROR: Cherry-pick failed for ${SHA:0:8} (${SUBJECT}). Aborting."
        git cherry-pick --abort 2>/dev/null || true
        exit 1
      fi
      log "PICK: ${SHA:0:8} — ${SUBJECT}"
      ((PICKED++)) || true
    done <<< "$COMMITS"
    log "OK: sync complete. Picked: ${PICKED}, skipped: ${SKIPPED}. Worktree: ${WTDIR}"
    ;;

  deliver)
    ID="${1:?ERROR: deliver requires <id>}"
    shift
    MESSAGE="${*:?ERROR: deliver requires <message>}"
    SOURCE="${PREFIX}-${ID}"

    log "Source branch: ${SOURCE}"
    log "Target branch: ${PREFIX}"
    log "Commit message: ${MESSAGE}"

    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
    log "Getting or creating worktree for ${PREFIX}"
    WTDIR=$(echo "{\"name\": \"${PREFIX}\"}" | bash "${PROJECT_ROOT}/.claude/hooks/worktree-create.sh")
    log "Worktree path: ${WTDIR}"

    cd "$WTDIR"
    log "Squash-merging ${SOURCE} into ${PREFIX}"
    if ! git merge --squash "$SOURCE"; then
      git merge --abort
      echo "ERROR: Merge conflicts during deliver. Phase aborted."
      exit 1
    fi

    log "Committing..."
    git commit -m "$MESSAGE"
    log "OK: deliver complete. Worktree: ${WTDIR}"
    ;;

  clean)
    ID="${1:?ERROR: clean requires <id>}"
    BRANCH="${PREFIX}-${ID}"
    TMP="${BRANCH}-tmp"

    for BR in "$TMP" "$BRANCH"; do
      # Remove worktree if it exists
      WT_PATH=$(git worktree list --porcelain | grep -A1 "^worktree " | paste - - | grep "branch refs/heads/${BR}$" | awk '{print $2}' || true)
      if [[ -n "$WT_PATH" ]]; then
        log "Removing worktree for ${BR} at ${WT_PATH}"
        git worktree remove "$WT_PATH"
      fi

      # Delete branch if it exists
      if git show-ref --verify --quiet "refs/heads/${BR}"; then
        log "Deleting branch ${BR}"
        git branch -D "$BR"
      else
        log "Branch ${BR} does not exist, skipping"
      fi
    done
    log "OK: clean complete."
    ;;

  push)
    log "Pushing ${PREFIX} to origin"
    git push origin "$PREFIX"
    log "OK: push complete."
    ;;

  *)
    usage
    ;;
esac
