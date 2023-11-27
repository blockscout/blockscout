# Docker-compose configuration

Runs Blockscout locally in Docker containers with [docker-compose](https://github.com/docker/compose).

## Prerequisites

- Docker v20.10+
- Docker-compose 2.x.x+
- Running Ethereum JSON RPC client

## Building Docker containers from source

```bash
cd ./docker-compose
docker-compose up --build
```

**Note**: if you don't need to make backend customizations, you can run `docker-compose up` in order to launch from pre-build backend Docker image. This will be much faster.

This command uses `docker-compose.yml` by-default, which builds the backend of the explorer into the Docker image and runs 9 Docker containers:

- Postgres 14.x database, which will be available at port 7432 on the host machine.
- Redis database of the latest version.
- Blockscout backend with api at /api path.
- Nginx proxy to bind backend, frontend and microservices.
- Blockscout explorer at http://localhost.

and 4 containers for microservices (written in Rust):

- [Stats](https://github.com/blockscout/blockscout-rs/tree/main/stats) service with a separate Postgres 14 DB.
- [Sol2UML visualizer](https://github.com/blockscout/blockscout-rs/tree/main/visualizer) service.
- [Sig-provider](https://github.com/blockscout/blockscout-rs/tree/main/sig-provider) service.

**Note for Linux users**: Linux users need to run the local node on http://0.0.0.0/ rather than http://127.0.0.1/

## Configs for different Ethereum clients

The repo contains built-in configs for different JSON RPC clients without need to build the image.

**Note**: in all below examples, you can use `docker compose` instead of `docker-compose`, if compose v2 plugin is installed in Docker.

- Erigon: `docker-compose -f docker-compose-no-build-erigon.yml up -d`
- Geth (suitable for Reth as well): `docker-compose -f docker-compose-no-build-geth.yml up -d`
- Geth Clique: `docker-compose -f docker-compose-no-build-geth-clique-consensus.yml up -d`
- Nethermind, OpenEthereum: `docker-compose -f docker-compose-no-build-nethermind up -d`
- Ganache: `docker-compose -f docker-compose-no-build-ganache.yml up -d`
- HardHat network: `docker-compose -f docker-compose-no-build-hardhat-network.yml up -d`
- Running only explorer without DB: `docker-compose -f docker-compose-no-build-no-db-container.yml up -d`. In this case, one container is created - for the explorer itself. And it assumes that the DB credentials are provided through `DATABASE_URL` environment variable.
- Running explorer with external backend: `docker-compose -f docker-compose-no-build-external-backend.yml up -d`
- Running explorer with external frontend: `docker-compose -f docker-compose-no-build-external-frontend.yml up -d`

All of the configs assume the Ethereum JSON RPC is running at http://localhost:8545.

In order to stop launched containers, run `docker-compose -d -f config_file.yml down`, replacing `config_file.yml` with the file name of the config which was previously launched.

You can adjust BlockScout environment variables:

- for backend in `./envs/common-blockscout.env`
- for frontend in `./envs/common-frontend.env`
- for stats service in `./envs/common-stats.env`
- for visualizer in `./envs/common-visualizer.env`

Descriptions of the ENVs are available

- for [backend](https://docs.blockscout.com/for-developers/information-and-settings/env-variables)
- for [frontend](https://github.com/blockscout/frontend/blob/main/docs/ENVS.md).

## Running Docker containers via Makefile

Prerequisites are the same, as for docker-compose setup.

Start all containers:

```bash
cd ./docker
make start
```

Stop all containers:

```bash
cd ./docker
make stop
```

***Note***: Makefile uses the same .env files since it is running docker-compose services inside.
