# POA Explorer

This is a tool for inspecting and analyzing the POA Network blockchain.


## Machine Requirements

* Erlang/OTP 20.2+
* Elixir 1.5+
* Postgres 10.0


## Required Accounts

* Github for code storage


## Setup Instructions

### Development

To get POA Explorer up and running locally:

  * Set up some default configuration with: `$ cp config/dev.secret.exs.example config/dev.secret.exs`
  * Install dependencies with `$ mix do deps.get, local.rebar, deps.compile, compile`
  * Create and migrate your database with `$ mix ecto.create && mix ecto.migrate`
  * Run IEx (Interactive Elixir) to access the index and explore: `$ iex -S mix`

### Testing

  * Format the Elixir code: `$ mix format`
  * Run the test suite with coverage: `$ mix coveralls.html`
  * Lint the Elixir code: `$ mix credo --strict`
  * Run the dialyzer: `mix dialyzer --halt-exit-status`
  * Check the Elixir code for vulnerabilities: `$ mix sobelow --config`

#### Variant and Chain

By default, [`mox`](https://github.com/plataformatec/mox) will be used to mock the `EthereumJSONRPC.Transport` and `EthereumJSONRPC.HTTP` behaviours.  They mocked behaviours returns differ based on the `EthereumJSONRPC.Variant`.

| `EthereumJSONRPC.Variant` | `EthereumJSONRPC.Transport` | `EthereumJSONRPC.HTTP`           | `url`                                             | Command                                                                                                                                                                                                                                                  | Usage(s)                                           |
|:--------------------------|:----------------------------|:---------------------------------|:--------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:---------------------------------------------------|
| `EthereumJSONRPC.Parity`  | `EthereumJSONRPC.Mox`       | `EthereumJSONRPC.HTTP.Mox`       | N/A                                               | `mix test`                                                                                                                                                                                                                                               | Local, `circleci/config.yml` `test_parity_mox` job |
| `EthereumJSONRPC.Parity`  | `EthereumJSONRPC.HTTP`      | `EthereumJSONRPC.HTTP.HTTPoison` | `https://trace-sokol.poa.network`                 | `ETHEREUM_JSONRPC_VARIANT=EthereumJSONRPC.Parity ETHEREUM_JSONRPC_TRANSPORT=EthereumJSONRPC.HTTP ETHEREUM_JSONRPC_HTTP=EthereumJSONRPC.HTTP.HTTPoison ETHEREUM_JSONRPC_HTTP_URL=https://sokol-trace.poa.network mix test --exclude no_parity`            | `.circleci/config.yml` `test_parity_http` job      |
| `EthereumJSONRPC.Geth`    | `EthereumJSONRPC.Mox`       | `EthereumJSONRPC.HTTP.Mox`       | N/A                                               | `ETHEREUM_JSONRPC_VARIANT=EthereumJSONRPC.Geth mix test --exclude no_geth`                                                                                                                                                                               | `.circleci/config.yml` `test_geth_http` job        |
| `EthereumJSONRPC.Geth`    | `EthereumJSONRPC.HTTP`      | `EthereumJSONRPC.HTTP.HTTPoison` | `https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY`  | `ETHEREUM_JSONRPC_VARIANT=EthereumJSONRPC.Geth ETHEREUM_JSONRPC_TRANSPORT=EthereumJSONRPC.HTTP ETHEREUM_JSONRPC_HTTP=EthereumJSONRPC.HTTP.HTTPoison ETHEREUM_JSONRPC_HTTP_URL=https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY mix test --exclude no_geth` | `.circleci/config.yml` `test_geth_http` job        |

### Benchmarking

#### `Explorer.Chain.recent_collated_transactions/0`

* Reset the test database: `MIX_ENV=test mix do ecto.drop, ecto.create, ecto.migrate`
* Change `tag` in `benchmarks/explorer/chain/recent_collated_transactions.exs` to a new value, so that it will compare against the old values saved in `benchmarks/explorer/chain/recent_collated_transactions.benchee`
* Run the benchmark: `MIX_ENV=test mix run benchmarks/explorer/chain/recent_collated_transactions.exs`
