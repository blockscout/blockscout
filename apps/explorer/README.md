# BlockScout

This is a tool for inspecting and analyzing the POA Network blockchain.


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
