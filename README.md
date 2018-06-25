# POA Explorer [![CircleCI](https://circleci.com/gh/poanetwork/poa-explorer.svg?style=svg&circle-token=f8823a3d0090407c11f87028c73015a331dbf604)](https://circleci.com/gh/poanetwork/poa-explorer) [![Coverage Status](https://coveralls.io/repos/github/poanetwork/poa-explorer/badge.svg?branch=master)](https://coveralls.io/github/poanetwork/poa-explorer?branch=master)

This is a tool for inspecting and analyzing the POA Network blockchain.


## Machine Requirements

* Erlang/OTP 20.2+
* Elixir 1.6+
* Postgres 10.0
* Node.js 9.10+


## Required Accounts

* GitHub for code storage


## Setup Instructions

### Development

To get POA Explorer up and running locally:

  * Set up some default configuration with: `cp apps/explorer/config/dev.secret.exs.example apps/explorer/config/dev.secret.exs`
  * Set up some default configuration with: `cp apps/explorer_web/config/dev.secret.exs.example apps/explorer_web/config/dev.secret.exs`
  * Install dependencies with `mix do deps.get, local.rebar, deps.compile, compile`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd apps/explorer_web/assets && npm install; cd -`
  * Start Phoenix with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

You can also run IEx (Interactive Elixir): `iex -S mix phx.server`

#### Umbrella Project Organization

This repository is an [umbrella project](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html): each directory under `apps/` is a separate [Mix](https://hexdocs.pm/mix/Mix.html) project and [OTP application](https://hexdocs.pm/elixir/Application.html), but the projects can use each other as a dependency in their `mix.exs`.

Each OTP application has a restricted domain

| Directory               | OTP Application     | Namespace         | Purpose                                                                                                                                                                                                                                                                                                                                                                         |
|:------------------------|:--------------------|:------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `apps/ethereum_jsonrpc` | `:ethereum_jsonrpc` | `EthereumJSONRPC` | Ethereum JSONRPC client.  It is allowed to know `Explorer`'s param format, but it cannot directly depend on `:explorer`                                                                                                                                                                                                                                                         |
| `apps/explorer`         | `:explorer`         | `Explorer`        | Storage for the indexed chain.  Can read and write to the backing storage.  MUST be able to boot in a read-only mode when run independently from `:indexer`, so cannot depend on `:indexer` as that would start `:indexer` indexing.                                                                                                                                            |
| `apps/explorer_web`     | `:explorer_web`     | `ExplorerWeb`     | Phoenix interface to `:explorer`.  The minimum interface to allow web access should go in `:explorer_web`.  Any business rules or interface that is not tied directly to `Phoenix` or `Plug` should go in `:explorer`. MUST be able to boot in a read-only mode when run independently from `:indexer`, so cannot depend on `:indexer` as that would start `:indexer` indexing. |
| `apps/indexer`          | `:indexer`          | `Indexer`         | Uses `:ethereum_jsonrpc` to index chain and batch import data into `:explorer`.  Any process, `Task`, or `GenServer` that automatically reads from the chain and writes to `:explorer` should be in `:indexer`, so that automatic writes are restricted to `:indexer` and read-only mode can be achieved by not running `:indexer`.                                             |

### CircleCI Updates

Configure your local CCMenu with the following url: [`https://circleci.com/gh/poanetwork/poa-explorer.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604`](https://circleci.com/gh/poanetwork/poa-explorer.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604)

### Documentation

* `mix docs`
* `open doc/index.html`

### Testing

#### Prerequisites

  * PhantomJS (for wallaby)
  * `Solidity` - http://solidity.readthedocs.io/en/v0.4.24/installing-solidity.html

#### Running the tests

  * Build the assets: `cd apps/explorer_web/assets && npm run build; cd -`
  * Format the Elixir code: `mix format`
  * Run the test suite with coverage for whole umbrella project: `mix coveralls.html --umbrella`
  * Lint the Elixir code: `mix credo --strict`
  * Run the dialyzer: `mix dialyzer --halt-exit-status`
  * Check the Elixir code for vulnerabilities:
    * `cd apps/explorer && mix sobelow --config; cd -`
    * `cd apps/explorer_web && mix sobelow --config; cd -`
  * Lint the JavaScript code: `cd apps/explorer_web/assets && npm run eslint; cd -`


## Internationalization

The app is currently internationalized. It is only localized to U.S. English.

To translate new strings, run `cd apps/explorer_web; mix gettext.extract --merge` and edit the new strings in `apps/explorer_web/priv/gettext/en/LC_MESSAGES/default.po`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)
