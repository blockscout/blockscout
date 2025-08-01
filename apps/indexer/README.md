# Indexer

The Indexer component of Blockscout is a backend process built in Elixir using supervised `GenServers`. It fetches blockchain data from Ethereum-based networks using an ETL pipeline that supports both real-time and catch-up indexing. The component buffers and batches incoming data to effectively manage concurrency and memory usage. It transforms raw data such as blocks, transactions, receipts, and logs into structured formats, orchestrating both synchronous and asynchronous processing. The Indexer does not directly interact with the PostgreSQL database via `Ecto`; instead, it passes prepared data to the Explorer component using the Chain.import function. Its design includes specialized fetchers and transformers that support multi-chain environments, handling data from networks like Optimism, Arbitrum, Polygon Edge, zkSync, and others. The component integrates robust error handling and retry mechanisms to ensure data integrity during processing. Multi-chain support is further emphasized through dedicated modules that process chain-specific data and transform it into database-ready structures.

## Structure

The indexer is split into multiple fetchers. Each fetcher has its own supervising tree with a separate `TaskSupervisor` for better detecting of memory, message or blocking problems.

Most fetchers have their `Supervisor` module generated automatically using `use Indexer.Fetcher` macro.

There are different fetchers described below, but the final step of almost all of them is importing data into database.
A map of lists of different entities is constructed and fed to `Explorer.Chain.import` method.
This method assigns different runners from `Explorer.Chain.Import.Runner` namespace, matching key in map to `option_key` attribute of a runner.
The runners are then performing according to the order specified in stages in `Explorer.Chain.Import.Stage`.

### Transformers

Some data has to be extracted from already fetched data, and there're several transformers in `lib/indexer/transform` to do just that. They normally accept a part of the `Chain.import`-able map and return another part of it.

- `addresses`: extracts all encountered addresses from different entities
- `address_coin_balances`: detects coin balance-changing entities (transactions, minted blocks, etc) to create coin balance entities for further fetching
- `token_transfers`: parses logs to extract token transfers
- `mint_transfers`: parses logs to extract token mint transfers
- `transaction_actions`: parses logs to extract transaction actions
- `address_token_balances`: creates token balance entities for further fetching, based on detected token transfers
- `blocks`: extracts block signer hash from additional data for Clique chains
- `optimism_withdrawals`: parses logs to extract L2 withdrawal messages

### Root fetchers

- `pending_transaction`: fetches pending transactions (i.e. not yet collated into a block) every second (`pending_transaction_interval`)
- `block/realtime`: listens for new blocks from websocket and polls node for new blocks, imports new ones one by one
- `block/catchup`: gets unfetched ranges of blocks, imports them in batches
- `transaction_action`: optionally fetches/rewrites transaction actions for old blocks (in a given range of blocks for given protocols)
- `optimism/txn_batch`: fetches transaction batches of Optimism chain
- `optimism/output_root`: fetches output roots of Optimism chain
- `optimism/deposit`: fetches deposits to Optimism chain
- `optimism/withdrawal`: fetches withdrawals from Optimism chain
- `optimism/withdrawal_event`: fetches withdrawal events on L1 chain
- `withdrawals`: optionally fetches withdrawals for old blocks (in the given from boundary of block numbers)

Both block fetchers retrieve/extract the blocks themselves and the following additional data:

- `block_second_degree_relations`
- `transactions`
- `logs`
- `token_transfers`
- `transaction_actions`
- `addresses`
- `withdrawals`

The following stubs for further async fetching are inserted as well:

- `block_rewards`
- `address_coin_balances`
- `address_token_balances`
- `tokens`

Realtime fetcher also immediately fetches from the node:

- current balances for `addresses`
- `address_coin_balances`

The following async fetchers are launched for importing missing data:

- `replaced_transaction`
- `block_reward`
- `uncle_block`
- `internal_transaction`
- `coin_balance` (only in catchup fetcher)
- `token_balance`
- `token`
- `contract_code`

### Async fetchers

These are responsible for fetching additional block data not retrieved in root fetchers.
Most of them are based off `BufferedTask`, and the basic algorithm goes like this:

1. Make an initial streaming request to database to fetch identifiers of all existing unfetched items.
2. Accept new identifiers for fetching via `async_fetch()` method.
3. Split identifier in batches and run tasks on `TaskSupervisor` according to `max_batch_size` and `max_concurrency` settings.
4. Make requests using `EthereumJSONRPC`.
5. Optionally post-process results using transformers.
6. Optionally pass new identifiers to other async fetchers using `async_fetch`.
7. Run `Chain.import` with fetched data.

- `replaced_transaction`: not a fetcher per se, but rather an async worker, which discards previously pending transactions after they are replaced with new pending transactions with the same nonce, or are collated in a block.
- `block_reward`: missing `block_rewards` for consensus blocks
- `uncle_block`: blocks for `block_second_degree_relations` with null `uncle_fetched_at`
- `internal_transaction`: for either `blocks` (Nethermind) or `transactions` with null `internal_transactions_indexed_at`
- `coin_balance`: for `address_coin_balances` with null `value_fetched_at`
- `token_balance`: for `address_token_balances` with null `value_fetched_at`. Also upserts `address_current_token_balances`
- `token`: for `tokens` with `cataloged == false`
- `contract_code`: for `transactions` with non-null `created_contract_address_hash` and null `created_contract_code_indexed_at`

Additionally:

- `token_updater` is run every 2 days to update token metadata
- `coin_balance_on_demand` is triggered from web UI to ensure address balance is as up-to-date as possible

### Temporary workers

These workers are created for fetching information, which previously wasn't fetched in existing fetchers, or was fetched incorrectly.
After all deployed instances get all needed data, these fetchers should be deprecated and removed.

- `uncataloged_token_transfers`: extracts token transfers from logs, which weren't parsed due to an unknown format
- `uncles_without_index`: adds previously unfetched `index` field for unfetched blocks in `block_second_degree_relations`
- `blocks_transactions_mismatch`: refetches each block once and revokes consensus for those whose transaction number mismatches with the number currently stored. This is meant to force the correction of a race condition that caused successfully fetched transactions to be overwritten by a following non-consensus block: [#1911](https://github.com/blockscout/blockscout/issues/1911).

## Memory Usage

The work queues for building the index of all blocks, balances (coin and token), and internal transactions can grow quite large.   By default, the soft-limit is 1 GiB, which can be changed by setting `INDEXER_MEMORY_LIMIT` environment variable https://docs.blockscout.com/for-developers/developer-faqs/how-do-i-update-memory-consumption-to-fix-indexer-memory-errors#updating-memory-consumption.

Memory usage is checked once per minute.  If the soft-limit is reached, the shrinkable work queues will shed half their load.  The shed load will be restored from the database, the same as when a restart of the server occurs, so rebuilding the work queue will be slower, but use less memory.

If all queues are at their minimum size, then no more memory can be reclaimed and an error will be logged.

## Websocket Keepalive

This defaults to 150 seconds, but it can be set via adding a configuration to `subscribe_named_arguments` in the appropriate config file (indexer/config/<env>/<variant>.exs) called `:keep_alive`. The value is an integer representing milliseconds.

## Testing

### Nethermind

#### Mox

**This is the default setup.  `mix test` will work on its own, but to be explicit, use the following setup**:

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Nethermind.Mox
mix test --exclude no_nethermind
```

#### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Nethermind.HTTPWebSocket
mix test --exclude no_nethermind
```

| Protocol  | URL                                |
|:----------|:-----------------------------------|
| HTTP      | `http://localhost:8545`  |
| WebSocket | `ws://localhost:8546`    |

### Geth

#### Mox

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Geth.Mox
mix test --exclude no_geth
```

#### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Geth.HTTPWebSocket
mix test --exclude no_geth
```

| Protocol  | URL                                               |
|:----------|:--------------------------------------------------|
| HTTP      | `https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY`  |
| WebSocket | `wss://mainnet.infura.io/ws/8lTvJTKmHPCHazkneJsY` |
