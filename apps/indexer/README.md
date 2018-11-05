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

## Memory Usage

The work queues for building the index of all blocks, balances (coin and token), and internal transactions can grow quite large.   By default, the soft-limit is 1 GiB, which can be changed in `config/config.exs`:

```
config :indexer, memory_limit: 1 <<< 30
```

Memory usage is checked once per minute.  If the soft-limit is reached, the shrinkable work queues will shed half their load.  The shed load will be restored from the database, the same as when a restart of the server occurs, so rebuilding the work queue will be slower, but use less memory.

If all queues are at their minimum size, then no more memory can be reclaimed and an error will be logged.

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

