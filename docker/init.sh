#!/bin/sh
export BLOCKSCOUT_VERSION=$(date '+%Y-%m-%d')
export COIN=Astra
export ETHEREUM_JSONRPC_VARIANT=geth
export SECRET_KEY_BASE=
export SHOW_PRICE_CHART=true
export SHOW_TXS_CHART=true
export ENABLE_TXS_STATS=true
export ETHEREUM_JSONRPC_HTTP_URL=${HTTP_URL:-http://localhost:8545/}
export ETHEREUM_JSONRPC_WS_URL=${WS_URL:-ws://localhost:8546/}
export ETHEREUM_JSONRPC_TRACE_URL=${HTTP_URL:-http://localhost:8545/}
export LOGO_TEXT=Astra
export LINK_TO_OTHER_EXPLORERS=false
export NETWORK=Devnet
export SHOW_ADDRESS_MARKETCAP_PERCENTAGE=false
export CHAIN_ID=11115

export HOST_SYSTEM=${HOST_SYSTEM:-$(uname -s)}

# cd .. && mix phx.server
make build
make start
