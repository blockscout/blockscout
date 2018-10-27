# BlockScout Docker integration

For now this integration is not production ready. It made only for local usage only !

## How to use ?

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
| `ETHEREUM_JSONRPC_HTTP_URL` | HTTP JSON RPC URL Only for `geth` or `ganache` variant | `http://localhost:7545` |
| `ETHEREUM_JSONRPC_WEB_SOCKET_URL` | WS JSON RPC url **Only for `geth` or `ganache` variant** | `ws://localhost:7545` |

