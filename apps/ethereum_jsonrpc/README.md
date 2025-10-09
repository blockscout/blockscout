# EthereumJSONRPC

The EthereumJSONRPC component is an Elixir library that interacts with Ethereum and EVM-compatible blockchains via JSON-RPC APIs. It constructs and sends both single and batch JSON-RPC requests while managing retries, timeouts, and throttling. The component abstracts transport mechanisms using a callback-based behaviour that supports HTTP, IPC, and WebSockets. It adapts to various Ethereum clients by implementing a variant behaviour for each, such as Geth, Nethermind, Erigon, Besu, and others. The library encodes function calls and decodes responses in accordance with ABI specifications. It retrieves diverse blockchain data including blocks, transactions, receipts, logs, and account balances. Additionally, it supports real-time updates through WebSocket subscriptions and monitors endpoint availability to switch to fallback URLs when needed. Request coordination is enhanced by a rolling window mechanism that prevents overwhelming the JSON-RPC node.

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
via `:trace_url`. The trace URL is used for
`fetch_internal_transactions`, which is only a supported method on
tracing nodes. The `:http` option is adapted
to the HTTP library (`HTTPoison` or `Tesla.Mint`).

## Testing

### Nethermind

#### Mox

**This is the default setup.  `mix test` will work on its own, but to be explicit, use the following setup**:

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Nethermind.Mox
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Mox
mix test --exclude no_nethermind
```

#### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Nethermind.HTTPWebSocket
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Nethermind
mix test --exclude no_nethermind
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
