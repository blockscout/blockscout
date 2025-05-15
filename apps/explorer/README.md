# Explorer

The Explorer component of Blockscout stores, processes, and serves blockchain data ingested by the Indexer. It provides a high-level data access layer through modules like Explorer.Chain and Explorer.Repo that interface with a PostgreSQL database, with schema migrations managed in `apps/explorer/priv/repo/migrations`. It features a structured multi-stage ETL pipeline used by the Indexer to import and transform blockchain data. The system includes chain-specific modules and configurations tailored for various EVM networks. It supports smart contract verification by managing compilation, versioning, and detecting proxy patterns. On-demand data fetching is available and is invoked by the BlockScoutWeb API server to support features such as contract verification. Release tasks are incorporated for database setup and migrations. Additional modules handle account management, market data processing, and event subscriptions to keep clients updated on blockchain data changes. Specialized modules manage both schema and long-running data migrations, including backfilling and index optimizations.

## Machine Requirements

* Erlang/OTP 21+
* Elixir 1.9+
* Postgres 10.3

## Required Accounts

* Github for code storage

## Setup Instructions

### Development

To get BlockScout up and running locally:

* Install dependencies with `$ mix do deps.get, local.rebar, deps.compile, compile`
* Create and migrate your database with `$ mix ecto.create && mix ecto.migrate`
* Run IEx (Interactive Elixir) to access the index and explore: `$ iex -S mix`

### Testing

* Format the Elixir code: `$ mix format`
* Lint the Elixir code: `$ mix credo --strict`
* Run the dialyzer: `mix dialyzer --halt-exit-status`
* Check the Elixir code for vulnerabilities: `$ mix sobelow --config`

### Benchmarking

#### `Explorer.Chain.recent_collated_transactions/0`

* Reset the test database: `MIX_ENV=test mix do ecto.drop, ecto.create, ecto.migrate`
* Change `tag` in `benchmarks/explorer/chain/recent_collated_transactions.exs` to a new value, so that it will compare against the old values saved in `benchmarks/explorer/chain/recent_collated_transactions.benchee`
* Run the benchmark: `MIX_ENV=test mix run benchmarks/explorer/chain/recent_collated_transactions.exs`
