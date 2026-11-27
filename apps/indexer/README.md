# Indexer

The Indexer component of Blockscout is a backend process built in Elixir using supervised `GenServers`. It fetches blockchain data from Ethereum-based networks using an ETL pipeline that supports both real-time and catch-up indexing. The component buffers and batches incoming data to manage concurrency and memory usage. It transforms raw data such as blocks, transactions, receipts, and logs into structured formats, orchestrating both synchronous and asynchronous processing. The Indexer does not write to PostgreSQL directly; instead, it passes prepared data to the Explorer component through `Explorer.Chain.import/1`. Chain-specific fetchers and transformers handle data of networks such as Optimism, Arbitrum, zkSync, Scroll, Shibarium, Celo, Filecoin, Zilliqa, Stability, Blackfort, and Rootstock. Failed requests are retried and the work queues are restored from the database after a restart, so no data is lost.

## Structure

The indexer is split into multiple fetchers. Each fetcher has its own supervision tree with a separate `TaskSupervisor` for better detection of memory, message or blocking problems.

Most fetchers have their `Supervisor` module generated automatically with the `use Indexer.Fetcher` macro.

`Indexer.Application` always starts the memory monitor and the on-demand fetchers, which the API relies on. The rest of the fetchers live under `Indexer.Supervisor`, which is started only when the application runs in `indexer` or `all` mode (`APPLICATION_MODE`) and the indexer is not disabled (`DISABLE_INDEXER`).

Most fetchers can be switched off with an `INDEXER_DISABLE_*` environment variable, and chain-specific fetchers start only for the matching `CHAIN_TYPE`. See the [ENV variables docs](https://docs.blockscout.com/setup/env-variables) and `config/runtime.exs` for the full list.

The final step of almost every fetcher is importing data into the database.
A map of lists of different entities is constructed and fed to the `Explorer.Chain.import/1` function.
This function assigns runners from the `Explorer.Chain.Import.Runner` namespace, matching each key in the map to the `option_key` of a runner.
The runners then run in the order of the stages defined in `Explorer.Chain.Import.Stage`.

### Transformers

Some data has to be extracted from already fetched data, and there are several transformers in `lib/indexer/transform` to do just that. They normally accept a part of the `Chain.import`-able map and return another part of it.

- `addresses`: extracts all encountered addresses from different entities
- `address_coin_balances`: detects coin balance-changing entities (transactions, minted blocks, etc.) to create coin balance entities for further fetching
- `address_token_balances`: creates token balance entities for further fetching, based on detected token transfers
- `token_transfers`: parses logs to extract token transfers and the tokens involved
- `mint_transfers`: parses logs to extract bridge mint transfers
- `token_instances`: creates NFT token instance entities from token transfers
- `signed_authorizations`: extracts EIP-7702 signed authorizations from transactions
- `fhe_operations`: parses logs to extract FHE (fully homomorphic encryption) operations
- `blocks`: extracts the block signer hash from additional data for Clique chains
- chain-specific transformers in `arbitrum`, `celo`, `optimism`, `scroll`, `shibarium`, and `stability` subdirectories (cross-level messages, epochs, withdrawals, L1 fee parameters, bridge operations, validators)

### Root fetchers

- `block/realtime`: subscribes to new heads over WebSocket (`ETHEREUM_JSONRPC_WS_URL`) and polls the node for the latest block number, importing new blocks one by one and handling reorgs
- `block/catchup`: gets unfetched ranges of blocks (collected by `Indexer.Block.Catchup.MissingRangesCollector`) and imports them in batches; `massive_blocks_fetcher` handles blocks that are too big to be fetched in a regular batch
- `pending_transaction`: fetches pending transactions (i.e. not yet included into a block)
- `withdrawal`: optionally fetches withdrawals for blocks indexed before withdrawals support was added
- `rootstock_data`: refetches Rootstock-specific block fields for blocks indexed before they were supported
- L2 and sidechain fetchers, each started only for its chain type:
  - `optimism/*`: transaction batches, output roots, dispute games, deposits, withdrawals, withdrawal events on L1, EIP-1559 config updates, and operator fee
  - `arbitrum/*`: batches and their statuses, messages between L1 and L2, data backfill
  - `zksync/*`: transaction batches and their statuses
  - `scroll/*`: batches, L1 and L2 bridge operations, L1 fee parameters
  - `shibarium/*`: L1 and L2 bridge operations
  - `celo/*`: epoch block operations, validator group votes, legacy accounts
  - `rollup_l1_reorg_monitor`: watches L1 for reorgs on behalf of the rollup fetchers

Both block fetchers retrieve the blocks and their receipts, and extract the following additional data:

- `block_second_degree_relations`
- `transactions`
- `logs`
- `token_transfers`
- `addresses`
- `withdrawals`
- `signed_authorizations`

The following stubs for further async fetching are inserted as well:

- `address_coin_balances`
- `address_token_balances`
- `address_current_token_balances`
- `tokens`
- `token_instances`

When `INDEXER_ENABLE_PARTIAL_ASYNC_IMPORT` is set, current token balances and token instances are not imported together with the block but handed to `current_token_balance_importer` and `token_instance_importer`, which import them separately.

After import, the block fetchers hand the following to async fetchers:

- block rewards (`block_reward`)
- uncles (`uncle_block`)
- created contract codes (`contract_code`)
- internal transactions (`internal_transaction`)
- coin balances (`coin_balance/catchup` for catchup blocks, `coin_balance/realtime` for realtime blocks)
- tokens (`token`)
- token balances (`token_balance/historical`, `token_balance/current`)
- token instances (`token_instance/realtime`)
- replaced transactions (`replaced_transaction`)
- blobs (`beacon/blob`)
- signed authorization statuses (`signed_authorization_status`)
- chain-specific data (Celo epochs and accounts, Filecoin address info)

### Async fetchers

These are responsible for fetching additional block data not retrieved in root fetchers.
Most of them are based on `Indexer.BufferedTask`, and the basic algorithm goes like this:

1. Make an initial streaming request to the database to fetch identifiers of all existing unfetched items.
2. Accept new identifiers for fetching via the `async_fetch` function.
3. Split identifiers into batches and run tasks on `TaskSupervisor` according to the `max_batch_size` and `max_concurrency` settings.
4. Make requests using `EthereumJSONRPC` (or another data source, such as the beacon node or a third-party API).
5. Optionally post-process results using transformers.
6. Optionally pass new identifiers to other async fetchers using `async_fetch`.
7. Run `Chain.import` with fetched data.

- `replaced_transaction`: not a fetcher per se, but rather an async worker, which discards previously pending transactions after they are replaced with new pending transactions with the same nonce, or are included in a block
- `block_reward`: missing `block_rewards` for consensus blocks
- `uncle_block`: blocks for `block_second_degree_relations` with null `uncle_fetched_at`
- `internal_transaction`: blocks from `pending_block_operations` or transactions from `pending_transaction_operations`, depending on whether the node traces by block or by transaction
- `internal_transaction/delete_queue`: deletes internal transactions of reorged blocks and schedules them for refetch
- `coin_balance/catchup` and `coin_balance/realtime`: `address_coin_balances` with null `value_fetched_at`; also update `addresses.fetched_coin_balance`
- `token_balance/historical`: `address_token_balances` with null `value_fetched_at`
- `token_balance/current`: `address_current_token_balances` with null `value_fetched_at`
- `token`: `tokens` with `cataloged` not set to `true`
- `token_instance/realtime`, `token_instance/retry`, `token_instance/refetch`: NFT metadata of new, failed, and marked-for-refetch token instances
- `token_instance/sanitize`, `token_instance/sanitize_erc721`, `token_instance/sanitize_erc1155`: token instances that were never created or never had metadata fetched
- `token_instance/media_type`: missing MIME types of NFT images and animations
- `contract_code`: contract code of created contract addresses
- `signed_authorization_status`: status of EIP-7702 signed authorizations
- `beacon/blob`: blob data for blob transactions, from the beacon node
- `beacon/deposit`: beacon chain deposits and their statuses
- `multichain_search_db/*`: export of addresses, blocks, transactions, balances, token info, and counters to the Multichain Search service
- `filecoin/address_info`, `zilliqa/*`, `stability/validator`, `blackfort/validator`: chain-specific data

### Periodic workers

- `token_updater`: refreshes metadata of cataloged tokens
- `token_total_supply_updater`: refreshes token total supply
- `token_ui_multiplier_updater`: records ERC-8056 UI multiplier changes
- `token_counters_updater`: exports token counters to the Multichain Search service
- `coin_balance/compactor`: deletes coin balance rows that carry no balance change
- `empty_blocks_sanitizer`: marks empty blocks for refetch when the node reports transactions for them
- `pending_transactions_sanitizer`: marks blocks for refetch when a transaction stored as pending is found included in a block
- `pending_ops_cleaner` and `pending_block_operations_sanitizer`: keep the internal transactions queue consistent
- `token_transfer_block_consensus_sanitizer`: marks blocks for refetch when token transfers carry a wrong `block_consensus` (Rootstock only)
- `stats/hot_smart_contracts`: aggregates the most active smart contracts (disabled by default)
- `bridged_tokens/*`: metadata of tokens bridged through OmniBridge and AMB bridges (when bridged tokens are enabled)

### On-demand fetchers

These are triggered by the API to make the requested data as up to date as possible. Most of them are started by `Indexer.Application` in every application mode, including `api`; `on_demand/internal_transaction` is a plain module called directly by the API.

- `on_demand/coin_balance`: address coin balance
- `on_demand/token_balance`: address token balances
- `on_demand/token_total_supply`: token total supply
- `on_demand/contract_code`: contract code of an address
- `on_demand/contract_creator`: creator of a contract
- `on_demand/first_trace`: internal transactions of a transaction
- `on_demand/internal_transaction`: internal transactions when they are not stored in the database
- `on_demand/token_instance_metadata_refetch` and `on_demand/nft_collection_metadata_refetch`: NFT metadata refetch requested by a user

### Temporary workers and migrators

These workers fetch information that previously wasn't fetched by existing fetchers, or was fetched incorrectly.
After all deployed instances get all needed data, these workers should be deprecated and removed.

- `temporary/uncles_without_index`: adds the previously unfetched `index` field for unfetched blocks in `block_second_degree_relations`
- `migrator/recovery_weth_token_transfers`: restores WETH token transfers deleted by an earlier version of the `SanitizeIncorrectWETHTokenTransfers` migration

Most background data migrations live in the Explorer app, under `Explorer.Migrator`.

## Memory Usage

The work queues for building the index of all blocks, balances (coin and token), and internal transactions can grow quite large. The soft limit is set with the `INDEXER_MEMORY_LIMIT` environment variable (for example, `10g` or `512m`, see the [docs](https://docs.blockscout.com/for-developers/developer-faqs/how-do-i-update-memory-consumption-to-fix-indexer-memory-errors#updating-memory-consumption)). If it is not set, the limit is derived from the container (cgroup) or system memory: all of it in `indexer` mode, or `INDEXER_SYSTEM_MEMORY_PERCENTAGE` (60% by default) in `all` mode. If the total memory can't be determined, the limit falls back to 1 GiB.

Memory usage is checked once per minute. If the soft limit is reached, the shrinkable work queues shed half their load. The shed load is restored from the database, the same as when the server restarts, so rebuilding the work queue is slower but uses less memory.

If all queues are at their minimum size, then no more memory can be reclaimed and an error is logged.

## Realtime Polling

If the WebSocket subscription is not configured or fails, the realtime fetcher keeps going by polling the node for the latest block number. The polling period is set with `INDEXER_REALTIME_FETCHER_POLLING_PERIOD`; by default it is half of the average block time, capped at 30 seconds (2 seconds when the average block time is unavailable).

## Testing

Run the tests from the app directory:

```shell
cd apps/indexer
mix test
```

The JSON-RPC backend used by the tests is selected with the `ETHEREUM_JSONRPC_CASE` environment variable.

### Nethermind

#### Mox

**This is the default setup. `mix test` works on its own, but to be explicit, use the following setup**:

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Nethermind.Mox
mix test --exclude no_nethermind
```

#### HTTP / WebSocket

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Nethermind.HTTPWebSocket
mix test --exclude no_nethermind
```

The node URLs are defined in `apps/ethereum_jsonrpc/test/support/ethereum_jsonrpc/case/nethermind/http_websocket.ex` (HTTP)
and `apps/ethereum_jsonrpc/test/support/ethereum_jsonrpc/web_socket/case/nethermind.ex` (WebSocket).

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

The node URLs are defined in `apps/ethereum_jsonrpc/test/support/ethereum_jsonrpc/case/geth/http_websocket.ex` (HTTP)
and `apps/ethereum_jsonrpc/test/support/ethereum_jsonrpc/web_socket/case/geth.ex` (WebSocket).
