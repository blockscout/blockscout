<p align="center">
  <a href="https://blockscout.com">
    <img width="200" src="https://blockscout.com/poa/core/android-chrome-192x192.png" \>
  </a>
</p>

<h1 align="center">BlockScout</h1>
<p align="center">Blockchain Explorer for inspecting and analyzing EVM Chains.</p>
<div align="center">

[![CircleCI](https://circleci.com/gh/poanetwork/blockscout.svg?style=svg&circle-token=f8823a3d0090407c11f87028c73015a331dbf604)](https://circleci.com/gh/poanetwork/blockscout) [![Coverage Status](https://coveralls.io/repos/github/poanetwork/blockscout/badge.svg?branch=master)](https://coveralls.io/github/poanetwork/blockscout?branch=master) [![Join the chat at https://gitter.im/poanetwork/blockscout](https://badges.gitter.im/poanetwork/blockscout.svg)](https://gitter.im/poanetwork/blockscout?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

</div>

BlockScout provides a comprehensive, easy-to-use interface for users to view, confirm, and inspect transactions on EVM (Ethereum Virtual Machine) blockchains. This includes the POA Network, xDai Chain, Ethereum Classic and other **Ethereum testnets, private networks and sidechains**.

See our [project documentation](https://docs.blockscout.com/) for detailed information and setup instructions.

Visit the [POA BlockScout forum](https://forum.poa.network/c/blockscout) for FAQs, troubleshooting, and other BlockScout related items. You can also post and answer questions here.

You can also access the dev chatroom on our [Gitter Channel](https://gitter.im/poanetwork/blockscout).

## About BlockScout

BlockScout is an Elixir application that allows users to search transactions, view accounts and balances, and verify smart contracts on the Ethereum network including all forks and sidechains.

Currently available full-featured block explorers (Etherscan, Etherchain, Blockchair) are closed systems which are not independently verifiable.  As Ethereum sidechains continue to proliferate in both private and public settings, transparent, open-source tools are needed to analyze and validate transactions.

## Matic 
Matic uses Blockscout explorer for its test networks: Testnetv2, Testnetv3, Alpha and BetaV2.

### Deployment Instructions

1. Clone the repository
2. `cd blockscout`
3. Install Mix dependencies, compile them and compile the application: `mix do deps.get, local.rebar --force, deps.compile, compile`
4. Generate db secret `mix phx.gen.secret`
5. Update `config.env` (add secret key and network specific details)
6. Export variables `source config.env`
7. Create and migrate database `mix do ecto.create, ecto.migrate`
8. Install Node.js dependencies

    - `cd apps/block_scout_web/assets; npm install && node_modules/webpack/bin/webpack.js --mode production; cd -`
    - `cd apps/explorer && npm install; cd -`
9.  (Make relevant directories if not already present)
    - ```bash 
      $ mkdir apps/block_scout_web/priv/static
      $ mkdir apps/ethereum_jsonrpc/priv/static
      $ mkdir apps/explorer/priv/static
      $ mkdir apps/indexer/priv
      $ mkdir apps/indexer/priv/static
      ```
10. Build static assets for deployment `mix phx.digest`
11. Enable HTTPS: `cd apps/block_scout_web; mix phx.gen.cert blockscout blockscout.local; cd -`
12. Return to the root directory and start the Phoenix Server. `mix phx.server`