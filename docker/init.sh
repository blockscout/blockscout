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
export DATABASE_URL=postgresql://postgres:password@localhost:5432/blockscout
export LOGO_TEXT=Astra
export LINK_TO_OTHER_EXPLORERS=false
export NETWORK=Devnet
export SHOW_ADDRESS_MARKETCAP_PERCENTAGE=false
export CHAIN_ID=astra_11115-1
export INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER=true
export INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER=true
export INDEXER_DISABLE_BLOCK_REWARD_FETCHER=true
export ECTO_USE_SSL=true
export MIX_ENV=prod
export HOST_SYSTEM=${HOST_SYSTEM:-$(uname -s)}
export API_NODE_URL=
export DISABLE_INDEXER=false
export FIRST_BLOCK=1
export PING_PUB_URL=

make build
make start
