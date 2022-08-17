#!/bin/sh
export BLOCKSCOUT_VERSION=$(date '+%Y-%m-%d')
export COIN=ASA
export ETHEREUM_JSONRPC_VARIANT=geth
export NETWORK=Testnet
export SECRET_KEY_BASE=
export HOST_SYSTEM=${HOST_SYSTEM:-$(uname -s)}

make build
make start