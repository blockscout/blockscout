#!/bin/bash

# Runs the indexer application on it's own
# Implies there is a postgreSQL database accessible at localhost

mix compile

NETWORK=Celo \
    PORT=4000 \
    ETHEREUM_JSONRPC_VARIANT=geth \
    ETHEREUM_JSONRPC_HTTP_URL=http://localhost:8545 \
    ETHEREUM_JSONRPC_WS_URL=ws://localhost:8546 \
    COIN=CELO \
    DATABASE_URL=postgresql://postgres:@localhost:5432/explorer \
    mix cmd --app indexer "iex -e 'IEx.configure(default_prompt: \"\", alive_prompt: \"\")' -S mix"