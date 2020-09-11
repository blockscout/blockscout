<p align="center">
  <a href="https://blockscout.com">
    <img width="200" src="https://blockscout.com/poa/core/android-chrome-192x192.png" \>
  </a>
</p>

<h1 align="center">BlockScout</h1>
<p align="center">Blockchain Explorer for inspecting and analyzing EVM Chains.</p>
<div align="center">

[![CircleCI](https://circleci.com/gh/celo-org/blockscout/tree/master.svg?style=svg)](https://circleci.com/gh/celo-org/blockscout/tree/master)

</div>

BlockScout provides a comprehensive, easy-to-use interface for users to view, confirm, and inspect transactions on EVM (Ethereum Virtual Machine) blockchains. This includes the POA Network, xDai Chain, Ethereum Classic and other **Ethereum testnets, private networks and sidechains**.

See our [project documentation](https://docs.blockscout.com/) for detailed information and setup instructions.

Visit the [POA BlockScout forum](https://forum.poa.network/c/blockscout) for FAQs, troubleshooting, and other BlockScout related items. You can also post and answer questions here.

You can also access the dev chatroom on our [Gitter Channel](https://gitter.im/poanetwork/blockscout).

## About BlockScout

BlockScout is an Elixir application that allows users to search transactions, view accounts and balances, and verify smart contracts on the Ethereum network including all forks and sidechains.

Currently available full-featured block explorers (Etherscan, Etherchain, Blockchair) are closed systems which are not independently verifiable.  As Ethereum sidechains continue to proliferate in both private and public settings, transparent, open-source tools are needed to analyze and validate transactions.

## Supported Projects

BlockScout supports a number of projects. Hosted instances include POA Network, xDai Chain, Ethereum Classic, Sokol & Kovan testnets, and other EVM chains. 

- [List of hosted mainnets, testnets, and additional chains using BlockScout](https://docs.blockscout.com/for-projects/supported-projects)
- [Hosted instance versions](https://docs.blockscout.com/about/use-cases/hosted-blockscout)

## Getting Started

1. Install requirements

    For a complete list of requirements, see the [blockscout docs](https://docs.blockscout.com/for-developers/information-and-settings/requirements).
     > Note that we use older versions of Elixir and Erlang (see `.tool-versions`).  For help installing and managing these versions, you can follow the instructions in this article [here](https://medium.com/juq/how-to-manage-elixir-versions-on-mac-or-linux-getting-started-with-elixir-12308e7b6451).

2. Set up some default configuration

    ```shell
    cp apps/explorer/config/dev.secret.exs.example apps/explorer/config/dev.secret.exs
    cp apps/block_scout_web/config/dev.secret.exs.example apps/block_scout_web/config/dev.secret.exs
    ```

3. Add Env Variables

4. Install Deps and Compile

    ```shell
    mix local.hex --force
    mix local.rebar --force
    mix deps.get
    cd apps/block_scout_web/assets/ && \
      npm install && \
      npm run deploy && \
      cd -
    cd apps/explorer/ && \
      npm install && \
      cd -
    mix compile
    ```

5. Start blockscout in a docker container

    ```shell
    cd docker
    make start
    ```

6. If not already running, start postgres

    ```shell
    docker run -d \
      --name postgres \
      -e POSTGRES_PASSWORD=mysecretpassword \
      -p 5432:5432 \
      postgres
    ```

    ```shell
    docker exec -it postgres /bin/sh
    ```

7. Create and migrate database

    ```shell
    mix do ecto.create, ecto.migrate
    ```

8. Build static assets for deployment

    If you have deployed previously, remove static assets from the previous build:
    ```shell
    mix phx.digest.clean
    ```

    ```shell
    mix phx.digest
    ```

9. Launch blockscout and view on `localhost:4000`

    ```shell
    mix phx.server
    ```

### Additional documentation

See the [project documentation](https://docs.blockscout.com/) for instructions:
- [Ansible deployment](https://docs.blockscout.com/for-developers/ansible-deployment)
- [Manual deployment](https://docs.blockscout.com/for-developers/manual-deployment)
- [ENV variables](https://docs.blockscout.com/for-developers/information-and-settings/env-variables)
- [Configuration options](https://docs.blockscout.com/for-developers/configuration-options)


## Acknowledgements

We would like to thank the [EthPrize foundation](http://ethprize.io/) for their funding support.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and pull request protocol. We expect contributors to follow our [code of conduct](CODE_OF_CONDUCT.md) when submitting code or comments.

## License

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
