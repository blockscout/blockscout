git pull

rm -r apps/block_scout_web/priv/static

mix do deps.get, local.rebar --force, deps.compile, compile

cd apps/block_scout_web/assets; npm install && node_modules/webpack/bin/webpack.js --mode production; cd -

cd apps/explorer && npm install; cd -

cd apps/block_scout_web; cd -

export 'COIN=ETH'
echo 'COIN=ETH'

export 'ETHEREUM_JSONRPC_VARIANT=geth'
echo 'ETHEREUM_JSONRPC_VARIANT=geth'

export 'ETHEREUM_JSONRPC_HTTP_URL=https://127.0.0.1:8547'
echo 'ETHEREUM_JSONRPC_HTTP_URL=https://127.0.0.1:8547'

export 'ETHEREUM_JSONRPC_WS_URL=ws://127.0.0.1:8548'
echo 'ETHEREUM_JSONRPC_WS_URL=ws://127.0.0.1:8548'

export "BLOCKSCOUT_VERSION=V1.0.0 - ENIX"
echo "BLOCKSCOUT_VERSION=V1.1.0 - ENIX"

export 'LINK_TO_OTHER_EXPLORERS=false'
echo 'LINK_TO_OTHER_EXPLORERS=false'

export 'RELEASE_LINK=https://github.com/poanetwork/blockscout/releases/tag/${BLOCKSCOUT_VERSION}  '
echo 'RELEASE_LINK=https://github.com/poanetwork/blockscout/releases/tag/${BLOCKSCOUT_VERSION}  '

export 'SUBNETWORK=ENIX'
echo 'SUBNETWORK=ENIX'

export 'NETWORK=Mainnet'
echo 'NETWORK=Mainnet'

export 'ADDRESS_WITH_BALANCES_UPDATE_INTERVAL=0.3'
echo 'ADDRESS_WITH_BALANCES_UPDATE_INTERVAL=0.3'

export 'TXS_COUNT_CACHE_PERIOD=1'
echo 'TXS_COUNT_CACHE_PERIOD=1 * 1 * 1'

mix phx.server

echo 'Make sure you start get with the following flags'

echo './geth --rpc --rpcaddr "127.0.0.1" --port "30303" --rpcport "8547" --rpccorsdomain "*" --nat "any" --rpcapi "debug,net,eth,shh,web3,txpool,eth,web3,personal" --wsapi "debug,net,eth,shh,web3,txpool,eth,web3,personal" --ws --wsaddr 127.0.0.1 --wsport 8548 --wsorigins "*" --syncmode=full --gcmode=archive --rpcvhosts=*'
