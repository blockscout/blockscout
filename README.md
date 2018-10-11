# BlockScout [![CircleCI](https://circleci.com/gh/poanetwork/blockscout.svg?style=svg&circle-token=f8823a3d0090407c11f87028c73015a331dbf604)](https://circleci.com/gh/poanetwork/blockscout) [![Coverage Status](https://coveralls.io/repos/github/poanetwork/blockscout/badge.svg?branch=master)](https://coveralls.io/github/poanetwork/blockscout?branch=master) [![Join the chat at https://gitter.im/poanetwork/blockscout](https://badges.gitter.im/poanetwork/blockscout.svg)](https://gitter.im/poanetwork/blockscout?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

BlockScout provides a comprehensive, easy-to-use interface for users to view, confirm, and inspect transactions on **all EVM** (Ethereum Virtual Machine) blockchains. This includes the Ethereum main and test networks as well as **Ethereum forks and sidechains**.

Following is an overview of the project and instructions for [getting started](#getting-started).

## About BlockScout

BlockScout is an Elixir application that allows users to search transactions, view accounts and balances, and verify smart contracts on the entire Ethereum network including all forks and sidechains.

Currently available block explorers (i.e. Etherscan and Etherchain) are closed systems which are not independently verifiable.  As Ethereum sidechains continue to proliferate in both private and public settings, transparent tools are needed to analyze and validate transactions.

The first release will include a block explorer for the POA core and Sokol test networks. Additional networks will be added in upcoming versions.


### Features

Development is ongoing. Please see the [project timeline](https://github.com/poanetwork/blockscout/wiki/Timeline-for-POA-Block-Explorer) for projected milestones.

- [x] **Open source development**: The code is community driven and available for anyone to use, explore and improve.

- [x] **Real time transaction tracking**: Transactions are updated in real time - no page refresh required. Infinite scrolling is also enabled.

- [x] **Smart contract interaction**: Users can read and verify Solidity smart contracts and access pre-existing contracts to fast-track development. Support for Vyper, LLL, and Web Assembly contracts is in progress.

- [x] **Token support**: Version 1 supports ERC20 and ERC721 tokens. Future releases will support additional token types including ERC223 and ERC1155.

- [x] **User customization**: Users can easily deploy on a network and customize the Bootstrap interface.

- [x] **Ethereum sidechain networks**: Version 1 supports the POA main network and Sokol test network. Future iterations will support Ethereum mainnet, Ethereum testnets, forks like Ethereum Classic, sidechains, and private EVM networks.

## Getting Started

We use [Terraform](https://www.terraform.io/intro/getting-started/install.html) to build the correct infrastructure to run BlockScout. See [https://github.com/poanetwork/blockscout-terraform](https://github.com/poanetwork/blockscout-terraform) for details.

### Requirements

The [development stack page](https://github.com/poanetwork/blockscout/wiki/Development-Stack) contains more information about these frameworks.

* [Erlang/OTP 21.0.4](https://github.com/erlang/otp)
* [Elixir 1.7.1](https://elixir-lang.org/)
* [Postgres 10.3](https://www.postgresql.org/)
* [Node.js 10.5.0](https://nodejs.org/en/)
* [Automake](https://www.gnu.org/software/automake/)
  * For Mac OSX users: `brew install automake`
* [Libtool](https://www.gnu.org/software/libtool/)
  * For Mac OSX users: `brew install libtool`
* GitHub for code storage
* [Inotify-tools](https://github.com/rvoicilas/inotify-tools/wiki) for Linux users only

### Build and Run

  1. Clone the repository.  
  `git clone https://github.com/poanetwork/blockscout`

  2. Go to the explorer subdirectory.  
  `cd blockscout`

  3. Set up default configurations.  
  `cp apps/explorer/config/dev.secret.exs.example apps/explorer/config/dev.secret.exs`  
  `cp apps/block_scout_web/config/dev.secret.exs.example apps/block_scout_web/config/dev.secret.exs`
  <br />Linux: Update the database username and password configuration in `apps/explorer/config/dev.secret.exs`
  <br />Mac: Remove the `username` and `password` fields from `apps/explorer/config/dev.secret.exs`  
  <br />Optional: Set up default configuration for testing.  
  `cp apps/explorer/config/test.secret.exs.example apps/explorer/config/test.secret.exs`  
  Example usage: Changing the default Postgres port from localhost:15432 if [Boxen](https://github.com/boxen/boxen) is installed.

  4. Install dependencies.  
  `mix do deps.get, local.rebar --force, deps.compile, compile`

  5. Create and migrate database.  
  `mix ecto.create && mix ecto.migrate`  
  <br />_Note:_ If you have run previously, drop the previous database  
  `mix do ecto.drop, ecto.create, ecto.migrate`

  6. Install Node.js dependencies.  
  `cd apps/block_scout_web/assets && npm install; cd -`  
  `cd apps/explorer && npm install; cd -`

  7. Start Phoenix Server.  
  `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

_Additional runtime options:_

*  Run Phoenix Server with IEx (Interactive Elixer)  
`iex -S mix phx.server`

*  Run Phoenix Server with real time indexer
`iex -S mix phx.server`

### BlockScout Visual Interface

![BlockScout Example](explorer_example.gif)

### Configuring Ethereum Classic and other EVM Chains
**Note: Most of these modifications will be consolidated into a single file in the future.**

  1. Update the import file in `apps/block_scout_web/assets/css/theme/_variables.scss`. There are several preset css files for our supported chains which include Ethereum Classic, Ethereum Mainnet, Ropsten Testnet, Kovan Testnet, POA Core, and POA Sokol. To deploy Ethereum Classic, change the import to `ethereum_classic_variables`.

  2. Update the logo file in `apps/block_scout_web/config/config.exs`. To deploy Ethereum Classic, change this file to `classic_ethereum_logo.svg`.

  3. Update the `check_origin` configuration in `apps/block_scout_web/config/prod.exs`. This allows realtime events to occur on your endpoint.

  4. Update the node configuration. You will need a full tracing node with WebSockets enabled. Make the changes in the following files (dev/prod):

   * `apps/explorer/config/dev/parity.exs`
   * `apps/explorer/config/prod/parity.exs`
   * `apps/indexer/config/dev/parity.exs`
   * `apps/indexer/config/prod/parity.exs`

  5. Update the dropdown menu in the main navigation `apps/block_scout_web/lib/block_scout_web/templates/layout/_topnav.html.eex`

  6. Update the coin in `apps/explorer/config/config.exs`. This will pull relevant information from Coinmarketcap.com.

### Umbrella Project Organization

This repository is an [umbrella project](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html). Each directory under `apps/` is a separate [Mix](https://hexdocs.pm/mix/Mix.html) project and [OTP application](https://hexdocs.pm/elixir/Application.html), but the projects can use each other as a dependency in their `mix.exs`.

Each OTP application has a restricted domain.

| Directory               | OTP Application     | Namespace         | Purpose                                                                                                                                                                                                                                                                                                                                                                         |
|:------------------------|:--------------------|:------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `apps/ethereum_jsonrpc` | `:ethereum_jsonrpc` | `EthereumJSONRPC` | Ethereum JSONRPC client.  It is allowed to know `Explorer`'s param format, but it cannot directly depend on `:explorer`                                                                                                                                                                                                                                                         |
| `apps/explorer`         | `:explorer`         | `Explorer`        | Storage for the indexed chain.  Can read and write to the backing storage.  MUST be able to boot in a read-only mode when run independently from `:indexer`, so cannot depend on `:indexer` as that would start `:indexer` indexing.                                                                                                                                            |
| `apps/block_scout_web`     | `:block_scout_web`     | `BlockScoutWeb`     | Phoenix interface to `:explorer`.  The minimum interface to allow web access should go in `:block_scout_web`.  Any business rules or interface not tied directly to `Phoenix` or `Plug` should go in `:explorer`. MUST be able to boot in a read-only mode when run independently from `:indexer`, so cannot depend on `:indexer` as that would start `:indexer` indexing. |
| `apps/indexer`          | `:indexer`          | `Indexer`         | Uses `:ethereum_jsonrpc` to index chain and batch import data into `:explorer`.  Any process, `Task`, or `GenServer` that automatically reads from the chain and writes to `:explorer` should be in `:indexer`. This restricts automatic writes to `:indexer` and read-only mode can be achieved by not running `:indexer`.                                             |


### CircleCI Updates

To monitor build status, configure your local [CCMenu](http://ccmenu.org/) with the following url: [`https://circleci.com/gh/poanetwork/blockscout.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604`](https://circleci.com/gh/poanetwork/blockscout.cc.xml?circle-token=f8823a3d0090407c11f87028c73015a331dbf604)


### Testing

#### Requirements

  * PhantomJS (for wallaby)

#### Running the tests

  1. Build the assets.  
  `cd apps/block_scout_web/assets && npm run build; cd -`

  2. Format the Elixir code.  
  `mix format`

  3. Run the test suite with coverage for whole umbrella project.  This step can be run with different configuration outlined below.
  `mix coveralls.html --umbrella`

  4. Lint the Elixir code.  
  `mix credo --strict`

  5. Run the dialyzer.  
  `mix dialyzer --halt-exit-status`

  6. Check the Elixir code for vulnerabilities.  
  `cd apps/explorer && mix sobelow --config; cd -`  
  `cd apps/block_scout_web && mix sobelow --config; cd -`

  7. Lint the JavaScript code.  
  `cd apps/block_scout_web/assets && npm run eslint; cd -`

  8. Test the JavaScript code.  
  `cd apps/block_scout_web/assets && npm run test; cd -`

##### Parity

###### Mox

**This is the default setup.  `mix coveralls.html --umbrella` will work on its own, but to be explicit, use the following setup**:

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Parity.Mox
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Mox
mix coveralls.html --umbrella --exclude no_parity
```

###### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Parity.HTTPWebSocket
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Parity
mix coveralls.html --umbrella --exclude no_parity
```

| Protocol  | URL                                |
|:----------|:-----------------------------------|
| HTTP      | `https://sokol-trace.poa.network`  |
| WebSocket | `wss://sokol-ws.poa.network/ws`    |

##### Geth

###### Mox

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Geth.Mox
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Mox
mix coveralls.html --umbrella --exclude no_geth
```

###### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Geth.HTTPWebSocket
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Geth
mix coveralls.html --umbrella --exclude no_geth
```

| Protocol  | URL                                               |
|:----------|:--------------------------------------------------|
| HTTP      | `https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY`  |
| WebSocket | `wss://mainnet.infura.io/ws/8lTvJTKmHPCHazkneJsY` |

### API Documentation

To view Modules and API Reference documentation:

1. Generate documentation.  
`mix docs`
2. View the generated docs.  
`open doc/index.html`


## Internationalization

The app is currently internationalized. It is only localized to U.S. English. To translate new strings.

1. To setup translation file.  
`cd apps/block_scout_web; mix gettext.extract --merge; cd -`
2. To edit the new strings, go to `apps/block_scout_web/priv/gettext/en/LC_MESSAGES/default.po`.

## Metrics

BlockScout is setup to export [Prometheus](https://prometheus.io/) metrics at `/metrics`.

### Prometheus

1. Install prometheus: `brew install prometheus`
2. Start the web server `iex -S mix phx.server`
3. Start prometheus: `prometheus --config.file=prometheus.yml`

### Grafana

1. Install grafana: `brew install grafana`
2. Install Pie Chart panel plugin: `grafana-cli plugins install grafana-piechart-panel`
3. Start grafana: `brew services start grafana`
4. Add Prometheus as a Data Source
   1. `open http://localhost:3000/datasources`
   2. Click "+ Add data source"
   3. Put "Prometheus" for "Name"
   4. Change "Type" to "Prometheus"
   5. Set "URL" to "http://localhost:9090"
   6. Set "Scrape Interval" to "10s"
5. Add the dashboards from https://github.com/deadtrickster/beam-dashboards:
   For each `*.json` file in the repo.
   1. `open http://localhost:3000/dashboard/import`
   2. Copy the contents of the JSON file in the "Or paste JSON" entry
   3. Click "Load"
6. View the dashboards.  (You will need to click-around and use BlockScout for the web-related metrics to show up.)

## Acknowledgements

We would like to thank the [EthPrize foundation](http://ethprize.io/) for their funding support.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and pull request protocol. We expect contributors to follow our [code of conduct](CODE_OF_CONDUCT.md) when submitting code or comments.


## License

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
