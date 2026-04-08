#!/usr/bin/env bash
set -euo pipefail

PREFIX="chore/openapi-spec-arbitrum"
CMD="${1:-}"
shift || true

usage() {
  echo "Usage: openapi-arbitrum.sh <command> [args]"
  echo "Commands:"
  echo "  init <id>              Create working branches and merge harness"
  echo "  sync                   Cherry-pick commits from -tmp to -<id> branch"
  echo "  deliver <id> <message> Squash-merge -<id> into main spec branch"
  echo "  push                   Push main spec branch to remote"
  exit 1
}

case "$CMD" in
  init)
    ID="${1:?ERROR: init requires <id>}"
    BRANCH="${PREFIX}-${ID}"
    TMP="${BRANCH}-tmp"

    git fetch origin
    git branch "$BRANCH" "origin/${PREFIX}"
    git branch "$TMP" "origin/${BRANCH}"
    git checkout "$TMP"
    if ! git merge --squash "origin/chore/agentic-ide"; then
      git merge --abort
      echo "ERROR: Merge conflicts during init. Phase aborted."
      exit 1
    fi
    git commit -m "HARNESS"
    echo "OK: init complete. On branch ${TMP}"
    ;;

  sync)
    CURRENT=$(git branch --show-current)
    if [[ ! "$CURRENT" =~ ^${PREFIX}-(.+)-tmp$ ]]; then
      echo "ERROR: Current branch '$CURRENT' does not match ${PREFIX}-<id>-tmp"
      exit 1
    fi
    ID="${BASH_REMATCH[1]}"
    TARGET="${PREFIX}-${ID}"

    # Get existing commit subjects in target to skip duplicates
    BASE=$(git merge-base "$TARGET" "$CURRENT")
    mapfile -t EXISTING < <(git log --format="%s" "${BASE}..${TARGET}")

    # Commits on -tmp after BASE, excluding HARNESS, oldest first
    mapfile -t COMMITS < <(git log --reverse --format="%H|%s" "${BASE}..${CURRENT}")

    git checkout "$TARGET"
    for entry in "${COMMITS[@]}"; do
      SHA="${entry%%|*}"
      SUBJECT="${entry#*|}"
      [[ "$SUBJECT" == "HARNESS" ]] && continue

      # Skip if subject already exists in target
      SKIP=false
      for existing in "${EXISTING[@]+"${EXISTING[@]}"}"; do
        if [[ "$existing" == "$SUBJECT" ]]; then
          SKIP=true
          break
        fi
      done
      if $SKIP; then
        echo "SKIP: $SUBJECT (already exists)"
        continue
      fi

      if ! git cherry-pick "$SHA"; then
        echo "ERROR: Cherry-pick failed for $SHA ($SUBJECT). Aborting."
        git cherry-pick --abort 2>/dev/null || true
        exit 1
      fi
      echo "PICK: $SUBJECT"
    done
    echo "OK: sync complete. On branch ${TARGET}"
    ;;

  deliver)
    ID="${1:?ERROR: deliver requires <id>}"
    shift
    MESSAGE="${*:?ERROR: deliver requires <message>}"
    SOURCE="${PREFIX}-${ID}"

    git checkout "$PREFIX"
    if ! git merge --squash "$SOURCE"; then
      git merge --abort
      echo "ERROR: Merge conflicts during deliver. Phase aborted."
      exit 1
    fi
    git commit -m "$MESSAGE"
    echo "OK: deliver complete. On branch ${PREFIX}"
    ;;

  push)
    git push origin "$PREFIX"
    echo "OK: push complete."
    ;;

  *)
    usage
    ;;
esac
