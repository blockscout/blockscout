# EthereumJSONRPC

Ethereum JSONRPC client.

## Configuration

Configuration for parity URLs can be provided with the following mix
config:

```elixir
config :ethereum_jsonrpc,
  url: "http://localhost:8545",
  trace_url: "http://localhost:8545",
  http: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
```

Note: the tracing node URL is provided separately from `:url`,
via `:trace_url`. The trace URL and is used for
`fetch_internal_transactions`, which is only a supported method on
tracing nodes. The `:http` option is passed directly to the HTTP
library (`HTTPoison`), which forwards the options down to `:hackney`.

## Testing

### Parity

#### Mox

**This is the default setup.  `mix test` will work on its own, but to be explicit, use the following setup**:

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Parity.Mox
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Mox
mix test --exclude no_parity
```

#### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Parity.HTTPWebSocket
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Parity
mix test --exclude no_parity
```

| Protocol  | URL                                |
|:----------|:-----------------------------------|
| HTTP      | `http://localhost:8545`  |
| WebSocket | `ws://localhost:8546`    |

### Geth

#### Mox

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Geth.Mox
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Mox
mix test --exclude no_geth
```

#### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Geth.HTTPWebSocket
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Geth
mix test --exclude no_geth
```

| Protocol  | URL                                               |
|:----------|:--------------------------------------------------|
| HTTP      | `https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY`  |
| WebSocket | `wss://mainnet.infura.io/ws/8lTvJTKmHPCHazkneJsY` |

## Installation

The OTP application `:ethereum_jsonrpc` can be used in other umbrella
OTP applications by adding `ethereum_jsonrpc` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ethereum_jsonrpc, in_umbrella: true}
  ]
end
```

