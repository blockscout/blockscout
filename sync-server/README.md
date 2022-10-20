# @mantlenetworkio/mantle-explorer-sync-server

## What is this?

The Mantle Explorer Sync Server is a service (written in TypeScript) designed to sync transaction data from Layer 1 and Layer 2. 


## Getting started

### Configuration

See an example config at [.env.example](.env.example); copy into a `.env` file before running.

`L1_TRANSPORT__L1_RPC_ENDPOINT` can be the JSON RPC endpoint of any L1 node. 
`L1_TRANSPORT__ADDRESS_MANAGER` should be the contract addresss of the Address Manager on the corresponding network; find their values in the [contracts package](https://github.com/mantlenetworkio/mantle/tree/main/packages/contracts/deployments).

### Building and usage

After cloning and switching to the repository, install dependencies:

```bash
$ yarn
```

Use the following commands to build, use, test, and lint:

```bash
$ yarn build
$ yarn start
$ yarn test
$ yarn lint
```

## Configuration

We're using `dotenv` for our configuration.
Copy `.env.example` into `.env`, feel free to modify it.
Here's the list of environment variables you can change:

| Variable                                                | Default     | Description                                                                                                                                                   |
| ------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| PGHOST                           | 'localhost'       | Path to the PostgreSQL for this service.    
| PGPORT                           | 5432        | Port to the PostgreSQL for this service.  
| PGUSER                           | 'postgres'        | Username to the PostgreSQL for this service.  
| PGPASSWORD                           | -        | Password to the PostgreSQL for this service.  
| PGDATABASE                           | -        | Database name to the PostgreSQL for this service.  
| DATA_TRANSPORT_LAYER__DB_PATH                           | ./db        | Path to the database for this service.                                                                                                                      |
| DATA_TRANSPORT_LAYER__ADDRESS_MANAGER                   | -           | Address of the AddressManager contract on L1. See [contracts](https://github.com/mantlenetworkio/mantle/tree/main/packages/contracts/deployments) package to find this address for mainnet or kovan. |
| DATA_TRANSPORT_LAYER__POLLING_INTERVAL                  | 5000        | Period of time between execution loops.                                                                                                                       |
| DATA_TRANSPORT_LAYER__DANGEROUSLY_CATCH_ALL_ERRORS      | false       | If true, will catch all errors without throwing.                                                                                                              |
| DATA_TRANSPORT_LAYER__CONFIRMATIONS                     | 12          | Number of confirmations to wait before accepting transactions as "canonical".                                                                                 |
| DATA_TRANSPORT_LAYER__SERVER_HOSTNAME                   | localhost   | Host to run the API on.                                                                                                                                       |
| DATA_TRANSPORT_LAYER__SERVER_PORT                       | 7878        | Port to run the API on.                                                                                                                                       |
| DATA_TRANSPORT_LAYER__SYNC_FROM_L1                      | true        | Whether or not to sync from L1.                                                                                                                               |
| DATA_TRANSPORT_LAYER__L1_RPC_ENDPOINT                   | -           | RPC endpoint for an L1 node.                                                                                                                                  |
| DATA_TRANSPORT_LAYER__L1_RPC_USER                       | -           | Basic Authentication user for the L1 node endpoint.                                                                                                           |
| DATA_TRANSPORT_LAYER__L1_RPC_PASSWORD                   | -           | Basic Authentication password for the L1 node endpoint.                                                                                                       |
| DATA_TRANSPORT_LAYER__LOGS_PER_POLLING_INTERVAL         | 2000        | Logs to sync per polling interval.                                                                                                                            |
| DATA_TRANSPORT_LAYER__SYNC_FROM_L2                      | false       | Whether or not to sync from L2.                                                                                                                               |
| DATA_TRANSPORT_LAYER__L2_RPC_ENDPOINT                   | -           | RPC endpoint for an L2 node.                                                                                                                                  |
| DATA_TRANSPORT_LAYER__L2_RPC_USER                       | -           | Basic Authentication user for the L2 node endpoint.                                                                                                           |
| DATA_TRANSPORT_LAYER__L2_RPC_PASSWORD                   | -           | Basic Authentication password for the L2 node endpoint.                                                                                                       |
| DATA_TRANSPORT_LAYER__TRANSACTIONS_PER_POLLING_INTERVAL | 1000        | Number of L2 transactions to query per polling interval.                                                                                                      |
| DATA_TRANSPORT_LAYER__L2_CHAIN_ID                       | -           | L2 chain ID.                                                                                                                                                  |
| DATA_TRANSPORT_LAYER__LEGACY_SEQUENCER_COMPATIBILITY    | false       | Whether or not to enable "legacy" sequencer sync (without the custom `eth_getBlockRange` endpoint)                                                            |
| DATA_TRANSPORT_LAYER__NODE_ENV                          | development | Environment the service is running in: production, development, or test.                                                                                      |
| DATA_TRANSPORT_LAYER__ETH_NETWORK_NAME                  | -           | L1 Ethereum network the service is deployed to: mainnet, kovan, goerli.                                                                                  |
| DATA_TRANSPORT_LAYER__L1_GAS_PRICE_BACKEND                  | l1           | Where to pull the l1 gas price from (l1 or l2)                                                                                  |
| DATA_TRANSPORT_LAYER__DEFAULT_BACKEND                  | l1           | Where to sync transactions from (l1 or l2)                                                                                  |

To enable proper error tracking via Sentry on deployed instances, make sure `NODE_ENV` and `ETH_NETWORK_NAME` are set in addition to [`SENTRY_DSN`](https://docs.sentry.io/platforms/node/).

