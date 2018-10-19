# Indexer

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `indexer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:indexer, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/indexer](https://hexdocs.pm/indexer).

## Testing

### Parity

#### Mox

**This is the default setup.  `mix test` will work on its own, but to be explicit, use the following setup**:

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Parity.Mox
mix test --exclude no_parity
```

#### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Parity.HTTPWebSocket
mix test --exclude no_parity
```

| Protocol  | URL                                |
|:----------|:-----------------------------------|
| HTTP      | `https://foundation-trace-fn4v7.poa.network`  |
| WebSocket | `wss://foundation-trace-fn4v7.poa.network/ws`    |

### Geth

#### Mox

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Geth.Mox
mix test --exclude no_geth
```

#### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Geth.HTTPWebSocket
mix test --exclude no_geth
```

| Protocol  | URL                                               |
|:----------|:--------------------------------------------------|
| HTTP      | `https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY`  |
| WebSocket | `wss://mainnet.infura.io/ws/8lTvJTKmHPCHazkneJsY` |

