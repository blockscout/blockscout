# Docker-compose configuration

Runs Blockscout in Docker containers with [docker-compose](https://github.com/docker/compose).

## Prerequisites

- Docker v20.10+
- Docker-compose 2.x.x+
- A Running Hoku network

## Running the block explorer

**Note**: in all below examples, you need compose v2 plugin is installed in Docker such that `docker compose` is enabled.

Starting
```bash
./start.sh <NETWORK NAME>
```

Stopping
```bash
./stop.sh <NETWORK NAME>
```

Currently `<NETWORK NAME>` can be one of `localnet` or `testnet`.

You can also reset all existing state in the explorer.  This is useful if you are restarting the Hoku network from scratch, i.e. a new localnet or a testnet reset.
```bash
./reset.sh
```

There is an optional `--start` flag that starts the explorer after reseting state.
```bash
./reset.sh --start localnet
```

Starting an explorer runs 10 Docker containers (plus [`caddy`](https://hub.docker.com/_/caddy) if the explorer is connecting to a public net):

- Postgres 14.x database, which will be available at port 5432 on the host machine.
- Redis database of the latest version.
- Blockscout backend with api at /api path.
- Nginx proxy to bind backend, frontend and microservices.
- Blockscout explorer at http://localhost:5000.

and 5 containers for microservices:

- [Stats](https://github.com/blockscout/blockscout-rs/tree/main/stats) service
- [Stats DB] Postgres 14 DB for stats.
- [Sol2UML visualizer](https://github.com/blockscout/blockscout-rs/tree/main/visualizer) service.
- [Sig-provider](https://github.com/blockscout/blockscout-rs/tree/main/sig-provider) service.
- [User-ops-indexer](https://github.com/blockscout/blockscout-rs/tree/main/user-ops-indexer) service.

Descriptions of the ENVs are available

- for [backend](https://docs.blockscout.com/setup/env-variables)
- for [frontend](https://github.com/blockscout/frontend/blob/main/docs/ENVS.md).
