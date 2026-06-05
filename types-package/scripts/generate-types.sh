#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=chain-types.sh
source "$SCRIPT_DIR/chain-types.sh"

cd "$PACKAGE_ROOT"
mkdir -p dist/chains

run_openapi_ts() {
  local input_path="$1"
  local output_path="$2"

  openapi-typescript "$input_path" -o "$output_path" --export-type --alphabetize=true
  echo "Wrote $output_path"
}

if [ "${NODE_ENV:-}" = "development" ]; then
  run_openapi_ts openapi/public.yaml dist/public.schema.ts
else
  run_openapi_ts openapi/public.yaml dist/public.schema.ts
  run_openapi_ts openapi/private.yaml dist/private.schema.ts
  run_openapi_ts openapi/merged.yaml dist/merged.schema.ts

  for chain_type in "${CHAIN_TYPES[@]}"; do
    run_openapi_ts "openapi/chains/${chain_type}.yaml" "dist/chains/${chain_type}.schema.ts"
  done
fi