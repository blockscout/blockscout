set -e

: "${SCHAIN_NAME?Need to set SCHAIN_NAME}"
: "${ENDPOINT?Need to set ENDPOINT}"
: "${PORT?Need to set PORT}"
: "${DB_PORT?Need to set DB_PORT}"

export LOGO=/images/skale_logo.png
export SUBNETWORK=${SCHAIN_NAME}
export ETHEREUM_JSONRPC_VARIANT=geth
export ETHEREUM_JSONRPC_HTTP_URL=${ENDPOINT}
export ETHEREUM_JSONRPC_WS_URL=${WS_ENDPOINT}
export NETWORK=SKALE

export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
make start -C $DIR