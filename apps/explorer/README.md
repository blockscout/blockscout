# BlockScout

This is a tool for inspecting and analyzing the POA Network blockchain.

## Machine Requirements

* Erlang/OTP 20.2+
* Elixir 1.5+
* Postgres 10.0

## Required Accounts

* Github for code storage

## Setup Instructions

### Development

To get BlockScout up and running locally:

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

### Benchmarking

#### `Explorer.Chain.recent_collated_transactions/0`

* Reset the test database: `MIX_ENV=test mix do ecto.drop, ecto.create, ecto.migrate`
* Change `tag` in `benchmarks/explorer/chain/recent_collated_transactions.exs` to a new value, so that it will compare against the old values saved in `benchmarks/explorer/chain/recent_collated_transactions.benchee`
* Run the benchmark: `MIX_ENV=test mix run benchmarks/explorer/chain/recent_collated_transactions.exs`
