#!/bin/bash

# Compiles and runs the blockscout web application on it's own
# Implies there is a postgreSQL database accessible at localhost:5432

# Environment variables being set for this command are repsentative
# and are not the complete list of variables available

    PORT=4001 \
    NETWORK=Celo \
    ETHEREUM_JSONRPC_VARIANT=geth \
    ETHEREUM_JSONRPC_HTTP_URL=http://localhost:8545 \
    ETHEREUM_JSONRPC_WS_URL=ws://localhost:8546 \
    COIN=CELO \
    DATABASE_URL=postgresql://postgres:1234@localhost:5432/blockscout \
    ENABLE_SOURCIFY_INTEGRATION=true \
    SOURCIFY_SERVER_URL=https://sourcify.dev/server \
    SOURCIFY_REPO_URL=https://repo.sourcify.dev/contracts/full_match/ \
    CHAIN_ID=44787 \
    mix compile \
    mix cmd --app block_scout_web "mix phx.server"