export COIN=VLX
export PORT=4000
export MIX_ENV=dev
export DATABASE_URL=postgresql://postgres:@localhost:5432/explorer?ssl=false
export CHAIN_SPEC_PATH=./docker/spec.json
export BLOCKSCOUT_PROTOCOL=http
export BLOCKSCOUT_HOST=0.0.0.0
export ETHEREUM_JSONRPC_VARIANT=parity
export ETHEREUM_JSONRPC_HTTP_URL=http://127.0.0.1:8545
export ETHEREUM_JSONRPC_WS_URL=ws://127.0.0.1:8546
export ETHEREUM_JSONRPC_TRACE_URL=http://127.0.0.1:8545
export VALIDATORS_CONTRACT=0x1000000000000000000000000000000000000001
export POS_STAKING_CONTRACT=0x1100000000000000000000000000000000000001 
mix do deps.get, local.rebar --force, deps.compile
mix compile
cd apps/block_scout_web/assets/ && npm install && npm run deploy && cd -
cd apps/explorer/ && npm install && cd -
cd apps/block_scout_web; mix phx.gen.cert blockscout blockscout.local; cd -
mix phx.digest