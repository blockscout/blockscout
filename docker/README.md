# BlockScout Docker integration

For now this integration is not production ready. It made only for local usage only !

## How to use ?
First of all blockscout requires `PostgreSQL` server for working. 
It will be provided by starting script (new docker image will be created named `postgres`)

**Starting command**
`make start` - will set everything up and start blockscout in container.
To connect it to your local environment you will have to configure it using [env variables](#env-variables)

Exmaple connecting to local `ganache` instance running on port `2000` on Mac/Windows:
```bash
COIN=DAI \
ETHEREUM_JSONRPC_VARIANT=ganache \ 
ETHEREUM_JSONRPC_HTTP_URL=http://host.docker.internal:2000 \
ETHEREUM_JSONRPC_WEB_SOCKET_URL=ws://host.docker.internal:2000 \
make start
```

Blockscout will be available on `localhost:4000`

**Note**
On mac/Windows Docker provides with a special URL `host.docker.internal` that will be available into container and routed to your local machine.
On Linux docker is starting using `--network=host` and all services should be available on `localhost`

### Migrations

By default `Makefile` will do migrations for you on `PostgreSQL` creation. 
But you could run migrations manualy using `make migrate` command.

**WARNING** Migrations will clean up your local database !

## Env variables

BlockScout support 3 different JSON RPC Variants.
Vriant could be configured using `ETHEREUM_JSONRPC_VARIANT` environment variable.

Example: 
```bash
ETHEREUM_JSONRPC_VARIANT=ganache make start
```

Available options are:

 * `parity` - Parity JSON RPC (**Default one**)
 * `geth` - Geth JSON RPC
 * `ganache` - Ganache JSON RPC
 

| Variable | Description | Default value |
| -------- | ----------- | ------------- |
| `ETHEREUM_JSONRPC_VARIANT` | Variant of your JSON RPC service: `parity`, `geth` or `ganache` | `parity` |
| `ETHEREUM_JSONRPC_HTTP_URL` | HTTP JSON RPC URL Only for `geth` or `ganache` variant | Different per JSONRPC variant |
| `ETHEREUM_JSONRPC_WS_URL` | WS JSON RPC url | Different per JSONRPC variant |
| `ETHEREUM_JSONRPC_TRACE_URL` | Trace URL **Only for `parity` variant** | `https://explorer-node.fuse.io` |
| `COIN` | Default Coin | `POA` |
| `LOGO` | Coin logo | Empty | 
| `NETWORK` | Network | Empty |
| `SUBNETWORK` | Subnetwork | Empty |
| `NETWORK_ICON` | Network icon | Empty | 
| `NETWORK_PATH` | Network path | `/` |


`ETHEREUM_JSONRPC_HTTP_URL` default values:

 * For `parity` - `http://localhost:8545`
 * For `geth` - `https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY`
 * For `ganache` - `http://localhost:7545`

`ETHEREUM_JSONRPC_WS_URL` default values:

 * For `parity` - `ws://localhost:8546`
 * For `geth` - `wss://mainnet.infura.io/8lTvJTKmHPCHazkneJsY/ws`
 * For `ganache` - `ws://localhost:7545`

