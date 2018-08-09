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

By default, [`mox`](https://github.com/plataformatec/mox) will be used to mock the `EthereumJSONRPC.Transport` and `EthereumJSONRPC.HTTP` behaviours.  They mocked behaviours returns differ based on the `EthereumJSONRPC.Variant`.

| `EthereumJSONRPC.Variant` | `EthereumJSONRPC.Transport` | `EthereumJSONRPC.HTTP`           | `url`                                             | Command                                                                                                                                                                                                                                                  | Usage(s)                                           |
|:--------------------------|:----------------------------|:---------------------------------|:--------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------|
| `EthereumJSONRPC.Parity`  | `EthereumJSONRPC.Mox`       | `EthereumJSONRPC.HTTP.Mox`       | N/A                                               | `mix test`                                                                                                                                                                                                                                               | Local, `circleci/config.yml` `test_parity_mox` job |
| `EthereumJSONRPC.Parity`  | `EthereumJSONRPC.HTTP`      | `EthereumJSONRPC.HTTP.HTTPoison` | `https://trace-sokol.poa.network`                 | `ETHEREUM_JSONRPC_VARIANT=EthereumJSONRPC.Parity ETHEREUM_JSONRPC_TRANSPORT=EthereumJSONRPC.HTTP ETHEREUM_JSONRPC_HTTP=EthereumJSONRPC.HTTP.HTTPoison ETHEREUM_JSONRPC_HTTP_URL=https://sokol-trace.poa.network mix test --exclude no_parity`            | `.circleci/config.yml` `test_parity_http` job      |
| `EthereumJSONRPC.Geth`    | `EthereumJSONRPC.Mox`       | `EthereumJSONRPC.HTTP.Mox`       | N/A                                               | `ETHEREUM_JSONRPC_VARIANT=EthereumJSONRPC.Geth mix test --exclude no_geth`                                                                                                                                                                               | `.circleci/config.yml` `test_geth_http` job        |
| `EthereumJSONRPC.Geth`    | `EthereumJSONRPC.HTTP`      | `EthereumJSONRPC.HTTP.HTTPoison` | `https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY`  | `ETHEREUM_JSONRPC_VARIANT=EthereumJSONRPC.Geth ETHEREUM_JSONRPC_TRANSPORT=EthereumJSONRPC.HTTP ETHEREUM_JSONRPC_HTTP=EthereumJSONRPC.HTTP.HTTPoison ETHEREUM_JSONRPC_HTTP_URL=https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY mix test --exclude no_geth` | `.circleci/config.yml` `test_geth_http` job        |
