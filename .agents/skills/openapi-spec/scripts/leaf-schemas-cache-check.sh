#!/usr/bin/env bash
#
# Freshness check for the leaf-schemas catalog cache.
#
# Computes a SHA-256 digest over every `*.ex` under
# `apps/block_scout_web/lib/block_scout_web/schemas/api/v2/general/` and
# compares it to the digest stored alongside the cached catalog.
#
# Output (stdout, three lines, plain text key=value):
#   state=fresh|stale
#   digest=<current-digest>
#   cache_dir=<absolute-path-to-cache-dir>
#
# Exit code is always 0 unless something genuinely broke (missing schemas
# dir, missing hashing tool). The cataloger agent decides what to do based
# on the `state=` line.

set -euo pipefail

# Resolve repo root via git — robust to the script being moved within the
# repo, unlike counting `../..` levels from $0.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
SKILL_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

SCHEMAS_DIR="$REPO_ROOT/apps/block_scout_web/lib/block_scout_web/schemas/api/v2/general"
CACHE_DIR="$SKILL_DIR/references/cache/leaf-schemas"
DIGEST_FILE="$CACHE_DIR/digest"
CATALOG_FILE="$CACHE_DIR/catalog.md"

if [[ ! -d "$SCHEMAS_DIR" ]]; then
  echo "ERROR: schemas dir not found: $SCHEMAS_DIR" >&2
  exit 2
fi

# Pick a hashing tool. macOS has shasum, Linux usually has sha256sum.
hash_tool() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256
  else
    echo "ERROR: no sha256 tool found (need sha256sum or shasum)" >&2
    exit 2
  fi
}

# Compute digest over sorted, NUL-delimited list of leaf files (avoids
# whitespace issues). Hash each file's contents, then hash the concatenation.
CURRENT_DIGEST=$(
  find "$SCHEMAS_DIR" -maxdepth 1 -type f -name '*.ex' -print0 \
    | sort -z \
    | xargs -0 cat \
    | hash_tool \
    | cut -d' ' -f1
)

STATE=stale
if [[ -s "$DIGEST_FILE" && -s "$CATALOG_FILE" ]]; then
  STORED_DIGEST=$(cat "$DIGEST_FILE")
  if [[ "$STORED_DIGEST" == "$CURRENT_DIGEST" ]]; then
    STATE=fresh
  fi
fi

echo "state=$STATE"
echo "digest=$CURRENT_DIGEST"
echo "cache_dir=$CACHE_DIR"
