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

1. Install Erlang and Elixir

    1. Install asdf

       ```shell
       brew install asdf
       ```

    2. Add it to your `.zshrc`:

       ```shell
       echo -e '\n. $(brew --prefix asdf)/asdf.sh' >> ~/.zshrc
       ```

    3. Test that it worked

       ```shell
       asdf --version
       ```

    4. Install Erlang and Elixir plugins

       ```shell
       asdf plugin-add erlang
       asdf plugin-add elixir
       ```

    5. Install correct versions of Erlang and Elixir (see `.tool-versions`)

       ```shell
       asdf install erlang 22.0.7
       asdf install elixir 1.9.1
       ```

    6. Restart your terminal and check that it worked

       ```shell
       elixir -v
       ```

2. Install remaining requirements

    For a complete list of requirements, see the [blockscout docs](https://docs.blockscout.com/for-developers/information-and-settings/requirements).

3. Set up some default configuration

    ```shell
    cp apps/explorer/config/dev.secret.exs.example apps/explorer/config/dev.secret.exs
    cp apps/block_scout_web/config/dev.secret.exs.example apps/block_scout_web/config/dev.secret.exs
    ```

4. Install Deps and Compile

    ```shell
    mix local.hex --force
    mix local.rebar --force
    mix deps.get
    cd apps/block_scout_web/assets/ && \
      npm install && \
      npm run build && \
      cd -
    cd apps/explorer/ && \
      npm install && \
      cd -
    mix compile
    ```

5. Add SSL Certs

   ```shell
   cd apps/block_scout_web
   mix phx.gen.cert blockscout blockscout.local
   ```

   Add blockscout and blockscout.local to your /etc/hosts:

   ```shell
   sudo vim /etc/hosts
   ```

   ```shell
   127.0.0.1       localhost blockscout blockscout.local
   255.255.255.255 broadcasthost
   ::1             localhost blockscout blockscout.local
   ```

   If using Chrome, enable chrome://flags/#allow-insecure-localhost.

6. Add env variables and start blockscout in a docker container

     > If you do not already have docker installed, you can get it here:  
     >   - [Mac](https://hub.docker.com/editions/community/docker-ce-desktop-mac)
     >   - [Windows](https://hub.docker.com/editions/community/docker-ce-desktop-windows)

    ```shell
    cd docker
    NETWORK=Celo
    ETHEREUM_JSONRPC_VARIANT=geth
    ETHEREUM_JSONRPC_HTTP_URL=http://104.198.100.15:8545
    ETHEREUM_JSONRPC_WS_URL=ws://104.198.100.15:8546 COIN=cGLD
    make start
    ```

     > Note that the values for `ETHEREUM_JSONRPC_HTTP_URL` and `ETHEREUM_JSONRPC_WS_URL` may vary and should point to a running archive node.

    This will create the database container, run migrations and start the indexer.  You can now view blockscout on `localhost:4000`!

### Additional documentation

See the [project documentation](https://docs.blockscout.com/) for instructions:
- [Ansible deployment](https://docs.blockscout.com/for-developers/ansible-deployment)
- [Manual deployment](https://docs.blockscout.com/for-developers/manual-deployment)
- [ENV variables](https://docs.blockscout.com/for-developers/information-and-settings/env-variables)
- [Configuration options](https://docs.blockscout.com/for-developers/configuration-options)

## Troubleshooting

Delete the `build` and `deps` folders and reinstall.

## Acknowledgements

We would like to thank the [EthPrize foundation](http://ethprize.io/) for their funding support.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and pull request protocol. We expect contributors to follow our [code of conduct](CODE_OF_CONDUCT.md) when submitting code or comments.

## License

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
