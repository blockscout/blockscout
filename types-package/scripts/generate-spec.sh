#!/usr/bin/env bash
# Generate OpenAPI YAML specs from Elixir annotations (public, private, chain-specific).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PACKAGE_ROOT/.." && pwd)"

# shellcheck source=chain-types.sh
source "$SCRIPT_DIR/chain-types.sh"

cd "$REPO_ROOT"
mkdir -p "$PACKAGE_ROOT/openapi/chains"

export MUD_INDEXER_ENABLED=false

generate_public() {
  local chain_type="${1:-}"
  local output_path="$2"

  if [ -n "$chain_type" ]; then
    export CHAIN_TYPE="$chain_type"
  else
    unset CHAIN_TYPE
  fi

  mix openapi.spec.yaml --spec BlockScoutWeb.Specs.Public "$output_path" --start-app=false
  echo "Wrote $output_path"
}

generate_private() {
  unset CHAIN_TYPE

  mix openapi.spec.yaml --spec BlockScoutWeb.Specs.Private "$PACKAGE_ROOT/openapi/private.yaml" --start-app=false
  echo "Wrote $PACKAGE_ROOT/openapi/private.yaml"
}

generate_public "" "$PACKAGE_ROOT/openapi/public.yaml"
generate_private

for chain_type in "${CHAIN_TYPES[@]}"; do
  generate_public "$chain_type" "$PACKAGE_ROOT/openapi/chains/${chain_type}.yaml"
done
