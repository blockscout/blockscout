<p align="center">
  <a href="https://blockscout.com">
    <img width="200" src="https://blockscout.com/eth/mainnet/android-chrome-192x192.png" \>
  </a>
</p>

<h1 align="center">BlockScout</h1>
<p align="center">Blockchain Explorer for inspecting and analyzing EVM Chains.</p>
<div align="center">

[![CircleCI](https://circleci.com/gh/poanetwork/blockscout.svg?style=svg&circle-token=f8823a3d0090407c11f87028c73015a331dbf604)](https://circleci.com/gh/poanetwork/blockscout) [![Coverage Status](https://coveralls.io/repos/github/poanetwork/blockscout/badge.svg?branch=master)](https://coveralls.io/github/poanetwork/blockscout?branch=master) [![Join the chat at https://gitter.im/poanetwork/blockscout](https://badges.gitter.im/poanetwork/blockscout.svg)](https://gitter.im/poanetwork/blockscout?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

</div>

BlockScout provides a comprehensive, easy-to-use interface for users to view, confirm, and inspect transactions on **all EVM** (Ethereum Virtual Machine) blockchains. This includes the Ethereum main and test networks as well as **Ethereum forks and sidechains**.

See our [project documentation](https://poanetwork.github.io/blockscout) for detailed information and setup instructions.

Visit the [POA BlockScout forum](https://forum.poa.network/c/blockscout) for FAQs, troubleshooting, and other BlockScout related items. You can also post and answer questions here. 

You can also access the dev chatroom on our [Gitter Channel](https://gitter.im/poanetwork/blockscout). 

## About BlockScout

BlockScout is an Elixir application that allows users to search transactions, view accounts and balances, and verify smart contracts on the entire Ethereum network including all forks and sidechains.

Currently available full-featured block explorers (Etherscan, Etherchain, Blockchair) are closed systems which are not independently verifiable.  As Ethereum sidechains continue to proliferate in both private and public settings, transparent, open-source tools are needed to analyze and validate transactions.

## Supported Projects

| **Hosted Mainnets** | **Hosted Testnets** | **Additional Chains using BlockScout** |
|--------------------------------------------------------|-------------------------------------------------------|----------------------------------------------------|
| [Aerum](https://blockscout.com/aerum/mainnet) | [Goerli Testnet](https://blockscout.com/eth/goerli) | [ARTIS](https://explorer.sigma1.artis.network) |
| [Callisto](https://blockscout.com/callisto/mainnet) | [Kovan Testnet](https://blockscout.com/eth/kovan) | [Ether-1](https://blocks.ether1.wattpool.net/) |
| [Ethereum Classic](https://blockscout.com/etc/mainnet) | [POA Sokol Testnet](https://blockscout.com/poa/sokol) | [Fuse Network](https://explorer.fuse.io/) |
| [Ethereum Mainnet](https://blockscout.com/eth/mainnet) | [Rinkeby Testnet](https://blockscout.com/eth/rinkeby) | [Oasis Labs](https://blockexplorer.oasiscloud.io/) |
| [POA Core Network](https://blockscout.com/poa/core) | [Ropsten Testnet](https://blockscout.com/eth/ropsten) | [Petrichor](https://explorer.petrachor.com/) |
| [RSK](https://blockscout.com/rsk/mainnet) |  | [PIRL](http://pirl.es/) |
| [xDai Chain](https://blockscout.com/poa/dai) |  | [SafeChain](https://explorer.safechain.io) |
|  |  | [SpringChain](https://explorer.springrole.com/) |
|  |  | [Kotti Testnet](https://kottiexplorer.ethernode.io/) |
|  |  | [Loom](http://plasma-blockexplorer.dappchains.com/) |
|  |  | [Tenda](https://tenda.network) |


Current BlockScout versions for hosted projects are available [on the forum](https://forum.poa.network/t/deployed-instances-on-blockscout-com/1938). 

## Getting Started

See the [project documentation](https://poanetwork.github.io/blockscout) for instructions:
- [Requirements](https://poanetwork.github.io/blockscout/#/requirements)
- [Ansible deployment](https://poanetwork.github.io/blockscout/#/ansible-deployment)
- [Manual deployment](https://poanetwork.github.io/blockscout/#/manual-deployment)
- [ENV variables](https://poanetwork.github.io/blockscout/#/env-variables)
- [Configuration options](https://poanetwork.github.io/blockscout/#/dev-env)


## Acknowledgements

We would like to thank the [EthPrize foundation](http://ethprize.io/) for their funding support.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and pull request protocol. We expect contributors to follow our [code of conduct](CODE_OF_CONDUCT.md) when submitting code or comments.

## License

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
