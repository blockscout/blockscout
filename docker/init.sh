#!/bin/sh
export BLOCKSCOUT_VERSION=$(date '+%Y-%m-%d')
export COIN=ASA
export ETHEREUM_JSONRPC_VARIANT=geth
export ETHEREUM_JSONRPC_HTTP_URL=${HTTP_URL:-http://localhost:8545/}
export ETHEREUM_JSONRPC_WS_URL=${WS_URL:-ws://localhost:8546/}
export ETHEREUM_JSONRPC_TRACE_URL=${HTTP_URL:-http://localhost:8545/}
export NETWORK=Testnet
export SECRET_KEY_BASE=
#export DATABASE_URL=postgresql://postgres:123456@localhost:5432/explorer_dev
export HOST_SYSTEM=${HOST_SYSTEM:-$(uname -s)}

make build
make start