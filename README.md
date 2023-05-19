<h1 align="center">BlockScout</h1>
<p align="center">Blockchain Explorer for inspecting and analyzing EVM Chains.</p>
<div align="center">

[![Blockscout](https://github.com/blockscout/blockscout/workflows/Blockscout/badge.svg?branch=master)](https://github.com/blockscout/blockscout/actions)
[![](https://dcbadge.vercel.app/api/server/blockscout?style=flat)](https://discord.gg/blockscout)

</div>


BlockScout provides a comprehensive, easy-to-use interface for users to view, confirm, and inspect transactions on EVM (Ethereum Virtual Machine) blockchains. This includes the POA Network, Gnosis Chain, Ethereum Classic and other **Ethereum testnets, private networks and sidechains**.

See our [project documentation](https://docs.blockscout.com/) for detailed information and setup instructions.

For questions, comments and feature requests see the [discussions section](https://github.com/blockscout/blockscout/discussions).

## About BlockScout

BlockScout is an Elixir application that allows users to search transactions, view accounts and balances, and verify smart contracts on the Ethereum network including all forks and sidechains.

Currently available full-featured block explorers (Etherscan, Etherchain, Blockchair) are closed systems which are not independently verifiable.  As Ethereum sidechains continue to proliferate in both private and public settings, transparent, open-source tools are needed to analyze and validate transactions.

## Supported Projects

BlockScout supports a number of projects. Hosted instances include POA Network, Gnosis Chain, Ethereum Classic, Sokol & Kovan testnets, and other EVM chains.

- [List of hosted mainnets, testnets, and additional chains using BlockScout](https://docs.blockscout.com/for-projects/supported-projects)
- [Hosted instance versions](https://docs.blockscout.com/about/use-cases/hosted-blockscout)

## Getting Started

See the [project documentation](https://docs.blockscout.com/) for instructions:

- [Requirements](https://docs.blockscout.com/for-developers/information-and-settings/requirements)
- [Ansible deployment](https://docs.blockscout.com/for-developers/ansible-deployment)
- [Manual deployment](https://docs.blockscout.com/for-developers/manual-deployment)
- [ENV variables](https://docs.blockscout.com/for-developers/information-and-settings/env-variables)
- [Configuration options](https://docs.blockscout.com/for-developers/configuration-options)

---

## Local Setup

To set up the project locally, follow these steps:

1. Clone the repository:

```sh
git clone git@github.com:haven1network/haven1-block-explorer-v2.git
cd haven1-block-explorer-v2
```

2. Navigate to the Docker Compose directory:

```sh
cd docker-compose
```

3. Start the containers using Docker Compose:

```sh
docker compose up -d
```

4. Generate SSL certificates:

```sh
docker exec -it webserver sh -c "certbot --nginx -m {{email}} -n --agree-tos -d {{domain}}"
```

Replace `{{email}}` with your email address for Let's Encrypt notifications, and `{{domain}}` with the domain name for which you want to generate the SSL certificate. Note that the `domain` value should match the `NGINX_DOMAIN` build argument specified for the `webserver` service in `docker-compose/docker-compose.yml` file.

This command will execute Certbot within the `webserver` container and generate the SSL certificate using the Nginx server block configuration provided in the Docker Compose file.

---

## Acknowledgements

We would like to thank the [EthPrize foundation](http://ethprize.io/) for their funding support.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and pull request protocol. We expect contributors to follow our [code of conduct](CODE_OF_CONDUCT.md) when submitting code or comments.

## License

[![License: GPL v3.0](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.
