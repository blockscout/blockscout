#!/bin/sh
export BLOCKSCOUT_VERSION=$(date '+%Y-%m-%d')
export COIN=ASA
export ETHEREUM_JSONRPC_VARIANT=geth
export DB_HOST=localhost
export DB_PASSWORD=
export DB_PORT=5432
export DB_USERNAME=postgres
export DATABASE_URL=postgresql://postgres:@localhost:5432/explorer_dev
export SHOW_PRICE_CHART=true
export SHOW_TXS_CHART=true
export ENABLE_TXS_STATS=true
export ETHEREUM_JSONRPC_HTTP_URL=${HTTP_URL:-http://localhost:8545/}
export ETHEREUM_JSONRPC_WS_URL=${WS_URL:-ws://localhost:8546/}
export ETHEREUM_JSONRPC_TRACE_URL=${HTTP_URL:-http://localhost:8545/}
export INDEXER_DISABLE_BLOCK_REWARD_FETCHER=true
export INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER=true
export INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER=true
export HEART_BEAT_TIMEOUT=30
export LOGO=/images/astra.svg
export LINK_TO_OTHER_EXPLORERS=false
# export ETHEREUM_JSONRPC_HTTP_URL=${HTTP_URL:-http://157.245.150.232:8545/}
# export ETHEREUM_JSONRPC_WS_URL=${WS_URL:-ws://157.245.150.232:8546/}
# export ETHEREUM_JSONRPC_TRACE_URL=${HTTP_URL:-http://157.245.150.232:8545/}
export NETWORK=Devnet
export SHOW_ADDRESS_MARKETCAP_PERCENTAGE=false
export CHAIN_ID=11115
export SECRET_KEY_BASE=oE0xPvfsObZLzg8khncxRy+Zxv1C0ehNvOVrqzijoXO3IWSZ+BdPgf3c2bxbFbXA
export SHOW_ADDRESS_MARKETCAP_PERCENTAGE=false
export HOST_SYSTEM=${HOST_SYSTEM:-$(uname -s)}
echo $HOST_SYSTEM

# cd .. && mix compile \
# && cd apps/block_scout_web/assets; npm install && node_modules/webpack/bin/webpack.js --mode production; cd - \
# && cd apps/explorer && npm install; cd - \
# && mix phx.digest \
# && cd apps/block_scout_web; mix phx.gen.cert blockscout blockscout.local; cd - \
# && mix phx.server

cd .. && mix phx.server
# make build
# make start
