# Set of ENVs for SPC Network Mainnet
# https://explore.spc.network

# Chain specific settings
CHAIN_NAME=spc
CHAIN_ID=36911
NETWORK_NAME="SPC Network"
NETWORK_SHORT_NAME="SPC"

# Ports
BACKEND_PORT=4002
FRONTEND_PORT=3002
NFT_HANDLER_PORT=8170
VISUALIZER_PORT=8171
SIG_PROVIDER_PORT=8172
STATS_PORT=8173
USER_OPS_PORT=8174
VERIFIER_PORT=8175

# RPC Configuration
ETHEREUM_JSONRPC_HTTP_URL=http://k8s-host:9650/ext/bc/QFAFyn1hh59mh7kokA55dJq5ywskF5A1yn8dDpLhmKApS6FP1/rpc
ETHEREUM_JSONRPC_TRACE_URL=http://k8s-host:9650/ext/bc/QFAFyn1hh59mh7kokA55dJq5ywskF5A1yn8dDpLhmKApS6FP1/rpc
ETHEREUM_JSONRPC_WS_URL=ws://k8s-host:9650/ext/bc/QFAFyn1hh59mh7kokA55dJq5ywskF5A1yn8dDpLhmKApS6FP1/ws

# Database Configuration
DATABASE_URL=postgresql://blockscout:ceWb1MeLBEeOIfk65gU8EjF8@host-postgres:5432/explorer_spcnet?sslmode=disable
STATS__DB_URL=postgresql://blockscout:ceWb1MeLBEeOIfk65gU8EjF8@host-postgres:5432/stats_spcnet?sslmode=disable
STATS__BLOCKSCOUT_DB_URL=postgresql://blockscout:ceWb1MeLBEeOIfk65gU8EjF8@host-postgres:5432/explorer_spcnet?sslmode=disable
USER_OPS_INDEXER__DATABASE__CONNECT__URL=postgresql://blockscout:ceWb1MeLBEeOIfk65gU8EjF8@host-postgres:5432/user_ops_spcnet?sslmode=disable

# Frontend Configuration
NEXT_PUBLIC_NETWORK_NAME=SPC Network
NEXT_PUBLIC_NETWORK_SHORT_NAME=SPC
NEXT_PUBLIC_NETWORK_ID=36911
NEXT_PUBLIC_NETWORK_CURRENCY_NAME=SPC
NEXT_PUBLIC_NETWORK_CURRENCY_SYMBOL=SPC
NEXT_PUBLIC_NETWORK_CURRENCY_DECIMALS=18
NEXT_PUBLIC_API_HOST=localhost:4002
NEXT_PUBLIC_STATS_API_HOST=http://localhost:8173
NEXT_PUBLIC_NETWORK_LOGO=https://explore.spc.network/images/spc_logo.svg
NEXT_PUBLIC_NETWORK_LOGO_DARK=https://explore.spc.network/images/spc_logo_dark.svg
NEXT_PUBLIC_NETWORK_ICON=https://explore.spc.network/images/spc_logo.svg
NEXT_PUBLIC_NETWORK_ICON_DARK=https://explore.spc.network/images/spc_logo_dark.svg
NEXT_PUBLIC_HOMEPAGE_HERO_BANNER_CONFIG={'background':['linear-gradient(136.9deg, rgb(255, 107, 0) 1.5%, rgb(255, 163, 77) 56.84%, rgb(255, 107, 0) 98.54%)']}
NEXT_PUBLIC_HOMEPAGE_CHARTS=['daily_txs']
NEXT_PUBLIC_HOMEPAGE_STATS=['total_blocks','total_txs','total_accounts','coin_price','market_cap']

# Currency
COIN=SPC
COIN_NAME=SPC

# Disable features not ready yet
DISABLE_INDEXER=true
DISABLE_REALTIME_INDEXER=true
DISABLE_CATCHUP_INDEXER=true
INDEXER_DISABLE_TOKEN_INSTANCE_FETCHER=true
INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER=true
INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER=true