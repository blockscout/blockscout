# Docker-compose configuration

Runs BlockScout locally in Docker container with usage [docker-compose](https://github.com/docker/compose).

## Prerequisites
- Docker v20.10+
- Docker-compose 2.x.x+
- Running Ethereum JSON RPC client

## Building Docker containers from source
```
docker-compose up --build
```

This command uses by-default `docker-compose.yml`, which build the explorer into Docker image and runs 2 Docker containers:
- one for the database. Postgres 13.x, which will be available at port 7432 on localhost
- and the BlockScout explorer at http://localhost:4000

## Configs for different Ethereum clients
Also, the repo contains built-in configs for different clients without need to build the image
- Ganache: `docker-compose -f docker-compose-no-build-ganache.yml up -d`
- HardHat network: `docker-compose -f docker-compose-no-build-hardhat-network.yml up -d`
- Geth: `docker-compose -f docker-compose-no-build-geth.yml up -d`
- OpenEthereum, Nethermind: `docker-compose -f docker-compose-no-build-open-ethereum-nethermind up -d`
- Running only explorer without DB: `docker-compose -f docker-compose-no-build-no-db-container.yml up -d`. In this case, one container is created - for the explorer itself. And it assumes that the DB credentials are provided through `DATABASE_URL` environment variable.

All of the configs assume, that the Ethereum JSON RPC is running at http://localhost:8545.

In order to stop launched containers, run `docker-compose -d -f config_file.yml down`, where replace `config_file.yml` with the file name of the config, which has been launched before.

You can play with the BlockScout environment variables, which are present at `./envs/common-blockscout.env`. The description of the environment variables are available in [the docs](https://docs.blockscout.com/for-developers/information-and-settings/env-variables).