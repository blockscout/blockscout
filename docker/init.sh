#!/bin/sh
export COIN=ASTRA
export ETHEREUM_JSONRPC_VARIANT=geth
export ETHEREUM_JSONRPC_HTTP_URL=${HTTP_URL:-http://host.docker.internal:8545/}
export ETHEREUM_JSONRPC_WS_URL=${WS_URL:-ws://host.docker.internal:8546/}
export ETHEREUM_JSONRPC_TRACE_URL=${WS_URL:-ws://host.docker.internal:8545/}
export NETWORK=Testnet
export SHOW_ADDRESS_MARKETCAP_PERCENTAGE=false
export HOST_SYSTEM=${HOST_SYSTEM:-$(uname -s)}
echo $HOST_SYSTEM
make build
make start