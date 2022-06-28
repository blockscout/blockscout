#!/bin/sh
export BLOCKSCOUT_VERSION=$(date '+%Y-%m-%d')
export COIN=ASTRA
export ETHEREUM_JSONRPC_VARIANT=geth
export ETHEREUM_JSONRPC_HTTP_URL=${HTTP_URL:-http://localhost:8545/}
export ETHEREUM_JSONRPC_WS_URL=${WS_URL:-ws://localhost:8546/}
export ETHEREUM_JSONRPC_TRACE_URL=${HTTP_URL:-http://localhost:8545/}
export NETWORK=Testnet
export SECRET_KEY_BASE=
export SHOW_ADDRESS_MARKETCAP_PERCENTAGE=false
export HOST_SYSTEM=${HOST_SYSTEM:-$(uname -s)}
# echo $HOST_SYSTEM
make build
make start