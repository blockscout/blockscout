# POA Explorer [![CircleCI](https://circleci.com/gh/poanetwork/poa-explorer.svg?style=svg&circle-token=f8823a3d0090407c11f87028c73015a331dbf604)](https://circleci.com/gh/poanetwork/poa-explorer) [![Coverage Status](https://coveralls.io/repos/github/poanetwork/poa-explorer/badge.svg?branch=master)](https://coveralls.io/github/poanetwork/poa-explorer?branch=master)

POA Explorer provides a comprehensive, easy-to-use interface for users to view, confirm, and inspect transactions on **all EVM** (Ethereum Virtual Machine) blockchains. This includes the Ethereum main and test networks as well as **Ethereum forks and sidechains**. 

Following is an overview of the project and instructions for [getting started](#getting-started).

## About POA Explorer

POA Explorer is an Elixir application that allows users to search transactions, view accounts and balances, and verify smart contracts on the entire Ethereum network including all forks and sidechains.

Currently available block explorers (i.e. Etherscan and Etherchain) are closed systems which are not independently verifiable.  As Ethereum sidechains continue to proliferate in both private and public settings, transparent tools are needed to analyze and validate transactions.

The first release will include a block explorer for the POA core and Sokol test networks. Additional networks will be added in upcoming versions.
 

### Features

Development is ongoing. Please see the [project timeline](https://github.com/poanetwork/poa-explorer/wiki/Timeline-for-POA-Block-Explorer) for projected milestones.

- [x] **Open source development**: The code is community driven and available for anyone to use, explore and improve.

- [x] **Real time transaction tracking**: Transactions are updated in real time - no page refresh required. Infinite scrolling is also enabled.

- [x] **Smart contract interaction**: Users can read and verify Solidity smart contracts and access pre-existing contracts to fast-track development. Support for Vyper, LLL, and Web Assembly contracts is in progress.  

- [x] **ERC20 token support**: Version 1 will support ERC20 token ecosystem. Future releases will support additional token types including ERC223, ERC721, and ERC1155. 

- [x] **User customization**: Users can easily deploy on a network and customize the Bootstrap interface. 

- [x] **Ethereum sidechain networks**: Version 1 supports the POA main network and Sokol test network. Future iterations will support Ethereum mainnet, Ethereum testnets, forks like Ethereum Classic, sidechains, and private EVM networks.

## Getting Started

We use [Terraform](https://www.terraform.io/intro/getting-started/install.html) to build the correct infrastructure to run POA Explorer. See [https://github.com/poanetwork/poa-explorer-infra](https://github.com/poanetwork/poa-explorer-infra) for details.

### Requirements

The [development stack page](https://github.com/poanetwork/poa-explorer/wiki/Development-Stack) contains more information about these frameworks.

* [Erlang/OTP 20.2+](https://github.com/erlang/otp)
* [Elixir 1.6+](https://elixir-lang.org/)
* [Postgres 10.0](https://www.postgresql.org/)
* [Node.js 10.5+](https://nodejs.org/en/)
* [Solidity](http://solidity.readthedocs.io/en/v0.4.24/installing-solidity.html)
* GitHub for code storage

### Setup Instructions

  1. Fork and clone repository.  
  [`https://github.com/poanetwork/poa-explorer/fork`](https://github.com/poanetwork/poa-explorer/fork)  

  2. Set up default configurations.  
`cp apps/explorer/config/dev.secret.exs.example apps/explorer/config/dev.secret.exs`  
`cp apps/explorer_web/config/dev.secret.exs.example apps/explorer_web/config/dev.secret.exs`

  3. Install dependencies.  
`mix do deps.get, local.rebar, deps.compile, compile`

  4. Create and migrate database.  
  `mix ecto.create && mix ecto.migrate`

  5. Install Node.js dependencies.  
  `cd apps/explorer_web/assets && npm install; cd -`
  `cd apps/explorer && npm install; cd -`

  6. Start Phoenix Server.  
  `mix phx.server`   

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

_Additional runtime options:_

*  Run Phoenix Server with IEx (Interactive Elixer)  
`iex -S mix phx.server`

*  Run Phoenix Server with real time indexer  
`DEBUG_INDEXER=1 iex -S mix phx.server`


### Umbrella Project Organization

This repository is an [umbrella project](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html). Each directory under `apps/` is a separate [Mix](https://hexdocs.pm/mix/Mix.html) project and [OTP application](https://hexdocs.pm/elixir/Application.html), but the projects can use each other as a dependency in their `mix.exs`.

Each OTP application has a restricted domain.

| Directory               | OTP Application     | Namespace         | Purpose                                                                                                                                                                                                                                                                                                                                                                         |
|:------------------------|:--------------------|:------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `apps/ethereum_jsonrpc` | `:ethereum_jsonrpc` | `EthereumJSONRPC` | Ethereum JSONRPC client.  It is allowed to know `Explorer`'s param format, but it cannot directly depend on `:explorer`                                                                                                                                                                                                                                                         |
| `apps/explorer`         | `:explorer`         | `Explorer`        | Storage for the indexed chain.  Can read and write to the backing storage.  MUST be able to boot in a read-only mode when run independently from `:indexer`, so cannot depend on `:indexer` as that would start `:indexer` indexing.                                                                                                                                            |
| `apps/explorer_web`     | `:explorer_web`     | `ExplorerWeb`     | Phoenix interface to `:explorer`.  The minimum interface to allow web access should go in `:explorer_web`.  Any business rules or interface not tied directly to `Phoenix` or `Plug` should go in `:explorer`. MUST be able to boot in a read-only mode when run independently from `:indexer`, so cannot depend on `:indexer` as that would start `:indexer` indexing. |
| `apps/indexer`          | `:indexer`          | `Indexer`         | Uses `:ethereum_jsonrpc` to index chain and batch import data into `:explorer`.  Any process, `Task`, or `GenServer` that automatically reads from the chain and writes to `:explorer` should be in `:indexer`. This restricts automatic writes to `:indexer` and read-only mode can be achieved by not running `:indexer`.                                             |



### CircleCI Updates

To monitor build status, configure your local [CCMenu](http://ccmenu.org/) with the following url: [`https://circleci.com/gh/poanetwork/poa-explorer.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604`](https://circleci.com/gh/poanetwork/poa-explorer.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604)


### Testing

#### Requirements

  * PhantomJS (for wallaby)

#### Running the tests

  1. Build the assets.  
  `cd apps/explorer_web/assets && npm run build; cd -`
  
  2. Format the Elixir code.  
  `mix format`
  
  3. Run the test suite with coverage for whole umbrella project.  
  `mix coveralls.html --umbrella`
  
  4. Lint the Elixir code.  
  `mix credo --strict`
  
  5. Run the dialyzer.  
  `mix dialyzer --halt-exit-status`
  
  6. Check the Elixir code for vulnerabilities.  
  `cd apps/explorer && mix sobelow --config; cd -`  
  `cd apps/explorer_web && mix sobelow --config; cd -`

  7. Lint the JavaScript code.  
  `cd apps/explorer_web/assets && npm run eslint; cd -`

  8. Test the JavaScript code.  
  `cd apps/explorer_web/assets && npm run test; cd -`


### API Documentation

To view Modules and API Reference documentation:

1. `mix docs` generates documentation
2. `open doc/index.html` to view


## Internationalization

The app is currently internationalized. It is only localized to U.S. English.

To translate new strings, run `cd apps/explorer_web; mix gettext.extract --merge` and edit the new strings in `apps/explorer_web/priv/gettext/en/LC_MESSAGES/default.po`.

## Acknowledgements

We would like to thank the [EthPrize foundation](http://ethprize.io/) for their funding support.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and pull request protocol. We expect contributors to follow our [code of conduct](CODE_OF_CONDUCT.md) when submitting code or comments.


## License

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
