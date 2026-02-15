# Changelog

## 10.0.0

### 🚀 Features

- ERC-7984 Confidential Tokens ([#13593](https://github.com/blockscout/blockscout/pull/13593))
- Move current token balances into a separate fetcher ([#13923](https://github.com/blockscout/blockscout/issues/13923))
- Re-architect internal transaction format with call-type enum, error dictionary, and normalization ([#13893](https://github.com/blockscout/blockscout/issues/13893))
- Add audit-reports import endpoint ([#13884](https://github.com/blockscout/blockscout/issues/13884))
- Solady smart-contract proxy with immutable arguments support ([#13794](https://github.com/blockscout/blockscout/issues/13794))
- Optionally accrue burnt fees to the block miner ([#13894](https://github.com/blockscout/blockscout/issues/13894))
- Allow adding EOA with code to watchlist ([#13885](https://github.com/blockscout/blockscout/issues/13885))
- Add Dynamic provider for account ([#13786](https://github.com/blockscout/blockscout/issues/13786))
- Distributed cache ([#13698](https://github.com/blockscout/blockscout/issues/13698))
- Return timestamps in the event logs list API endpoints ([#13779](https://github.com/blockscout/blockscout/issues/13779))
- Support EigenDA blobs by Optimism batch indexer ([#13709](https://github.com/blockscout/blockscout/issues/13709))
- `txlistinternal` API endpoint pending item status ([#13758](https://github.com/blockscout/blockscout/issues/13758))
- Setup universal proxy config from the JSON content in ENV variable ([#13787](https://github.com/blockscout/blockscout/issues/13787))
- Missed L1-to-L2 messages catchup on Arbitrum rollups ([#13792](https://github.com/blockscout/blockscout/issues/13792))
- Expose CHAIN_TYPE in the REST API ([#13805](https://github.com/blockscout/blockscout/issues/13805))
- REST API endpoint to list uncompleted DB migrations ([#13835](https://github.com/blockscout/blockscout/issues/13835))
- Show ENS domains without resolved address in search ([#13638](https://github.com/blockscout/blockscout/issues/13638))
- Mark contract addresses in search results ([#13636](https://github.com/blockscout/blockscout/issues/13636))

### 🐛 Bug Fixes

- `HttpClient.get` usage in genesis data module ([#13945](https://github.com/blockscout/blockscout/pull/13945))
- Multichain counter starting time and small fixes ([#13920](https://github.com/blockscout/blockscout/pull/13920))
- Fix 500 on empty ens domain search ([#13928](https://github.com/blockscout/blockscout/pull/13928))
- Limit `getlogs` after filtering consensus ([#13934](https://github.com/blockscout/blockscout/pull/13934))
- Handle nil in update_transactions_cache/2 ([#13911](https://github.com/blockscout/blockscout/pull/13911))
- Fix token balances broadcasting function ([#13902](https://github.com/blockscout/blockscout/issues/13902))
- Wrong `next_page_params` in OP Deposits ([#13870](https://github.com/blockscout/blockscout/issues/13870))
- Fix error on loading thumbnails when public_r2_url is missed ([#13895](https://github.com/blockscout/blockscout/issues/13895))
- Check token presence in address current token balance ([#13892](https://github.com/blockscout/blockscout/issues/13892))
- Fix swagger generation for Mud chain
- Fix error in Indexer.Fetcher.OnDemand.TokenBalance module ([#13890](https://github.com/blockscout/blockscout/issues/13890))
- Actualize indexer tests ([#13887](https://github.com/blockscout/blockscout/issues/13887))
- Clear bytecode for smart-contracts self destructed in a separate transaction ([#13834](https://github.com/blockscout/blockscout/issues/13834))
- Skip hot contracts fetching if last 30 days not indexed ([#13873](https://github.com/blockscout/blockscout/issues/13873))
- Add block range filtering to TokenBalance fetcher ([#13874](https://github.com/blockscout/blockscout/issues/13874))
- Filter traceable data in InternalTransaction.async_fetch ([#13872](https://github.com/blockscout/blockscout/issues/13872))
- Take into account empty arrays in Explorer.Migrator.SanitizeIncorrectNFTTokenTransfers ([#13852](https://github.com/blockscout/blockscout/issues/13852))
- Fix search for ERC-1155 with null symbol ([#13632](https://github.com/blockscout/blockscout/issues/13632))
- Return date to logs ([#13858](https://github.com/blockscout/blockscout/issues/13858))
- Convert token id to string from refetch metadata in the socket ([#13762](https://github.com/blockscout/blockscout/issues/13762))
- Prevent DeleteZeroValueInternalTransactions from running while ShrinkInternalTransactions is in progress ([#13847](https://github.com/blockscout/blockscout/issues/13847))
- Remove contract code and verified data on lose consensus ([#13829](https://github.com/blockscout/blockscout/issues/13829), [#13905](https://github.com/blockscout/blockscout/pull/13905))
- Exclude 0 index internal transactions from /api/v2/internal-transactions endpoint ([#13841](https://github.com/blockscout/blockscout/issues/13841))
- Fix NaN gas limit for `selfdestruct` internal transaction in the REST API ([#13827](https://github.com/blockscout/blockscout/issues/13827))
- Handle normal termination of Indexer.Fetcher.OnDemand.ContractCode process ([#13828](https://github.com/blockscout/blockscout/issues/13828))
- Validate block number in the api/v2/blocks/:block_number API endpoint ([#13795](https://github.com/blockscout/blockscout/issues/13795))
- Fix methodId detection ([#13811](https://github.com/blockscout/blockscout/issues/13811))
- Improve Arbitrum L1->L2 message discovery for reorg and RPC consistency ([#13770](https://github.com/blockscout/blockscout/issues/13770))

### 🚜 Refactor

- Improve error handling in `EthereumJSONRPC.execute_contract_function/3` ([#13764](https://github.com/blockscout/blockscout/issues/13764))

### ⚙️ Miscellaneous Tasks

- Enhance indexer metrics calculation ([#13985](https://github.com/blockscout/blockscout/pull/13985))
- Don't send historic rate for recent txs ([#13960](https://github.com/blockscout/blockscout/pull/13960))
- Increase default for MIGRATION_EMPTY_INTERNAL_TRANSACTIONS_DATA_BATCH_SIZE to 1000 ([#13953](https://github.com/blockscout/blockscout/pull/13953))
- Improve EmptyInternalTransactionsData migration ([#13918](https://github.com/blockscout/blockscout/pull/13918))
- Disable Auth0 when Dynamic enabled ([#13912](https://github.com/blockscout/blockscout/pull/13912))
- Add swagger spec for account abstraction endpoints ([#13897](https://github.com/blockscout/blockscout/issues/13897))
- Clear token "skip_metadata" property ([#13891](https://github.com/blockscout/blockscout/issues/13891))
- Refactor internal transaction logic from "block_index" to "transaction_index" and "index" ([#12474](https://github.com/blockscout/blockscout/issues/12474))
- Cover Optimism API endpoints with swagger docs ([#13672](https://github.com/blockscout/blockscout/issues/13672))
- Duplicate internal transaction created_contract_address_hash to to_address_hash ([#13846](https://github.com/blockscout/blockscout/issues/13846))
- Add "openapi_spec_folder_name" to the response of api/v2/config/backend endpoint ([#13845](https://github.com/blockscout/blockscout/issues/13845))
- Re-use parse_url_env_var/3 function for all *_URL env variables ([#13800](https://github.com/blockscout/blockscout/issues/13800))
- Add swagger spec for MUD endpoints ([#13793](https://github.com/blockscout/blockscout/issues/13793))
- Set unique block numbers in handle_partially_imported_blocks/1 ([#13657](https://github.com/blockscout/blockscout/issues/13657))
- Disband 37% of Explorer.Chain module ([#13755](https://github.com/blockscout/blockscout/issues/13755))
- Disable MissingRangesManipulator ([#13359](https://github.com/blockscout/blockscout/issues/13359))
- Improve replica usage ([#13344](https://github.com/blockscout/blockscout/issues/13344))
- Make "jsonrpc" field in response optional ([#13724](https://github.com/blockscout/blockscout/issues/13724))

### New ENV variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `BLOCK_MINER_GETS_BURNT_FEES`                           | If `true`, the Burnt fees are added to block miner profit and displayed in UI as zero. Implemented in [#13894](https://github.com/blockscout/blockscout/pull/13894).                                                                                                                                                                                                                                                                               | Version: v10.0.0\+ <br />Default: `false` <br />Applications: API                                                                                                                                                                                                                                                                                                                  |
| `UNIVERSAL_PROXY_CONFIG`                               | JSON-encoded configuration string used to define settings for the universal proxy. Implemented in [#13787](https://github.com/blockscout/blockscout/pull/13787).                                                                                                                                                                                                                                                                                   | Version: v10.0.0\+ <br />Default: (empty) <br />Applications: API                                                                                                                                                                                                                                                                                                                  |
| `MIGRATION_EMPTY_INTERNAL_TRANSACTIONS_DATA_BATCH_SIZE`  | Number of internal transactions to clear their data in the batch. Implemented in [#13893](https://github.com/blockscout/blockscout/pull/13893).                                                                                                                                                                                                                                | Version: v10.0.0\+ <br />Default: `1000` <br />Applications: Indexer        |
| `MIGRATION_EMPTY_INTERNAL_TRANSACTIONS_DATA_CONCURRENCY` | Number of parallel clearing internal transaction data batches processing. Implemented in [#13893](https://github.com/blockscout/blockscout/pull/13893).                                                                                                                                                                                                                        | Version: v10.0.0\+ <br />Default: `1` <br />Applications: Indexer          |
| `MIGRATION_EMPTY_INTERNAL_TRANSACTIONS_DATA_TIMEOUT`     | Timeout between clearing internal transaction data batches processing. Implemented in [#13893](https://github.com/blockscout/blockscout/pull/13893).                                                                                                                                                                                                                           | Version: v10.0.0\+ <br />Default: `0` <br />Applications: Indexer          |
| `CACHE_PENDING_OPERATIONS_COUNT_PERIOD`               | Time interval to restart the task which calculates the total pending operations count.  Introduced in [#12474](https://github.com/blockscout/blockscout/pull/12474).                                                                                                                                                                                          | Version: v10.0.0\+ <br />Default: `5m` <br />Applications: API, Indexer    |
| `ACCOUNT_DYNAMIC_ENV_ID`                            | Dynamic Environment ID, can be found here https://app.dynamic.xyz/dashboard/developer/api. Implemented in [#13786](https://github.com/blockscout/blockscout/pull/13786).                                 | Version: v10.0.0\+ <br />Default: (empty) <br />Applications: API                              |
| `INDEXER_OPTIMISM_L1_BATCH_EIGENDA_BLOBS_API_URL`    | Defines a URL to DA indexer supporting EigenDA layer to retrieve L1 blobs from that. Example: `https://da-indexer-dev.k8s-prod-3.blockscout.com/api/v1/eigenda/v2/blobs`. Implemented in [#13709](https://github.com/blockscout/blockscout/pull/13709).                                                                                                                                                                                                                                                                                                                       | Version: v10.0.0+ <br />Default: (empty) <br />Applications: Indexer                                       |
| `INDEXER_OPTIMISM_L1_BATCH_EIGENDA_PROXY_BASE_URL`   | Defines a URL to EigenDA proxy node which is used by the DA indexer (planned to be optional in the future). Example for MegaETH: `http://megaeth-eigenda-proxy.node.blockscout.com:3100`. Implemented in [#13709](https://github.com/blockscout/blockscout/pull/13709).                                                                                                                                                                                                                                                                                                       | Version: v10.0.0+ <br />Default: (empty) <br />Applications: Indexer                                       |
| `INDEXER_ARBITRUM_MESSAGES_TRACKING_FAILURE_THRESHOLD`             | The time threshold for L1 message tracking tasks. If a task has not run successfully within this threshold, it is marked as failed and enters a cooldown period before retrying. Implemented in [#13792](https://github.com/blockscout/blockscout/pull/13792).                                                                                                                                                 | Version: v10.0.0+ <br />Default: `10m` <br />Applications: Indexer                                      |
| `INDEXER_ARBITRUM_MISSED_MESSAGE_IDS_RANGE`                        | Size of each message ID range inspected when discovering L1-to-L2 messages with missing L1 origination information. Implemented in [#13792](https://github.com/blockscout/blockscout/pull/13792).                                                                                                                                                                                                              | Version: v10.0.0+ <br />Default: `10000` <br />Applications: Indexer                                      |
| `INDEXER_CURRENT_TOKEN_BALANCES_BATCH_SIZE`                        | Batch size for current token balances fetcher. Implemented in [#13923](https://github.com/blockscout/blockscout/pull/13923).                                                                                                                                                                                                              | Version: v10.0.0+ <br />Default: `100` <br />Applications: Indexer      |
| `INDEXER_CURRENT_TOKEN_BALANCES_CONCURRENCY`                        | Concurrency for current token balances fetcher. Implemented in [#13923](https://github.com/blockscout/blockscout/pull/13923).                                                                                                                                                                                                              | Version: v10.0.0+ <br />Default: `10` <br />Applications: Indexer    |


### Deprecated ENV variables

| Variable                                              | Description                                                                                                                                                                                                                                                                                                                                        | Default                                                                                       | Version  | Deprecated in Version |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------------- | --------------------- |
| `CACHE_PBO_COUNT_PERIOD`  | Time interval to restart the task which calculates the total pending_block_operations count.  | `20m` | v5.2.0+ |  | v10.0.0 |


## 9.3.5

### 🐛 Bug Fixes

- Fix block reindex condition in ContractCreator on-demand ([#13831](https://github.com/blockscout/blockscout/issues/13831))


## 9.3.4

### ⚡ Performance

- Fix /token-transfers timeout when filtering scam tokens enabled ([#13973](https://github.com/blockscout/blockscout/pull/13973))


## 9.3.3

### ⚙️ Miscellaneous Tasks

- Replace ZeroValueDeleteQueue with filtering on import ([#13921](https://github.com/blockscout/blockscout/pull/13921), [#13947](https://github.com/blockscout/blockscout/pull/13947))
- Allow to set IT storage period not only in days ([#13932](https://github.com/blockscout/blockscout/pull/13932))

### New ENV variables

| Variable                                                            | Description                                                                                                                                                                                     | Parameters                                                          |
|---------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| `MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_STORAGE_PERIOD`  | Specifies the period for which recent zero-value calls won't be deleted in delete zero-value calls migration. Implemented in [#13932](https://github.com/blockscout/blockscout/pull/13932).     | Version: v9.3.3\+ <br />Default: `30d` <br />Applications: Indexer  |

### Deprecated ENV variables

| Variable                                                                 | Description                                                                                                    | Default | Version   | Deprecated in Version |
|--------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------|---------|-----------|-----------------------|
| `MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_STORAGE_PERIOD_DAYS`  | Specifies the period for which recent zero-value calls won't be deleted in delete zero-value calls migration.  | `30`    | v9.3.0+   | v9.3.3                |


## 9.3.2

### 🐛 Bug Fixes

- Handle_continue bad return value ([#13769](https://github.com/blockscout/blockscout/issues/13769))
- Make `find_history_and_token_fetchers` public ([#13768](https://github.com/blockscout/blockscout/issues/13768))
- Resolve TLS version issue on application startup ([#13767](https://github.com/blockscout/blockscout/issues/13767))

## 9.3.1

### 🐛 Bug Fixes

- Fix blob transactions list API endpoint ([#13756](https://github.com/blockscout/blockscout/issues/13756))

## 9.3.0

### 🚀 Features

- Update InternalTransactionsAddressPlaceholder upserts ([#13696](https://github.com/blockscout/blockscout/pull/13696))
- Internal transactions on demand fetcher ([#13604](https://github.com/blockscout/blockscout/pull/13604))
- Indexer config API endpoint ([#13679](https://github.com/blockscout/blockscout/pull/13679))
- Add DIA market source ([#12678](https://github.com/blockscout/blockscout/issues/12678))
- Add metadata to eth bytecode DB lookup request ([#13625](https://github.com/blockscout/blockscout/issues/13625))
- Support ZRC-2 tokens for `zilliqa` chain type ([#13443](https://github.com/blockscout/blockscout/issues/13443))
- Indexer monitor Prometheus metrics ([#13539](https://github.com/blockscout/blockscout/issues/13539), [#13668](https://github.com/blockscout/blockscout/pull/13668), [#13670](https://github.com/blockscout/blockscout/pull/13670))
- Hot smart-contracts ([#13471](https://github.com/blockscout/blockscout/issues/13471), [#13669](https://github.com/blockscout/blockscout/pull/13669))
- Support OP Jovian upgrade, other enhancements ([#13538](https://github.com/blockscout/blockscout/issues/13538))
- Scope celo under optimism chain type ([#13375](https://github.com/blockscout/blockscout/issues/13375))

### 🐛 Bug Fixes

- Fix tests for on-demand internal transaction fetcher ([#13744](https://github.com/blockscout/blockscout/pull/13744))
- `batch_number` input param is now integer for OP and Scroll API endpoints ([#13727](https://github.com/blockscout/blockscout/pull/13727))
- Set timeout: :infinity for delete zero value migration ([#13708](https://github.com/blockscout/blockscout/pull/13708))
- Limit batch size for placeholders insertion ([#13699](https://github.com/blockscout/blockscout/pull/13699))
- Add missed reputation fetch ([#13695](https://github.com/blockscout/blockscout/pull/13695))
- Fix NFTMediaHandler postgres parameters overflow error ([#13694](https://github.com/blockscout/blockscout/pull/13694))
- Add smart contract preload to hot contracts query ([#13691](https://github.com/blockscout/blockscout/pull/13691))
- Restore fetcher name to dev console output ([#13681](https://github.com/blockscout/blockscout/pull/13681))
- JSON RPC encoding for signed authorizations ([#13678](https://github.com/blockscout/blockscout/pull/13678))
- Fix 500 for pending tx in tokentx RPC API endpoint ([#13666](https://github.com/blockscout/blockscout/pull/13666))
- Fix 500 for pending tx in gettxinfo RPC API endpoint([#13665](https://github.com/blockscout/blockscout/pull/13665))
- `Mix.env()` in `runtime.exs` ([#13641](https://github.com/blockscout/blockscout/issues/13641))
- Celo aggregated election rewards migrator test ([#13639](https://github.com/blockscout/blockscout/issues/13639))
- Fix filecoin web tests ([#13634](https://github.com/blockscout/blockscout/issues/13634))
- Fix dialyzer test for filecoin chain type ([#13623](https://github.com/blockscout/blockscout/issues/13623))
- Handle deposit status statement too complex ([#13588](https://github.com/blockscout/blockscout/issues/13588))
- Beacon deposits: fallback to node ([#13425](https://github.com/blockscout/blockscout/issues/13425), [#13656](https://github.com/blockscout/blockscout/pull/13656))
- Fix logic of disable token exchange rate ([#13414](https://github.com/blockscout/blockscout/issues/13414))
- Null-checks for distribution field in celo epochs api ([#13457](https://github.com/blockscout/blockscout/issues/13457))
- Reset ResetSanitizeDuplicatedLogsMigration status ([#13556](https://github.com/blockscout/blockscout/issues/13556))
- Duplicated block numbers in int txs queue ([#13554](https://github.com/blockscout/blockscout/issues/13554))
- Fix coin balance history - related normalize_balances_by_day/2 function ([#13515](https://github.com/blockscout/blockscout/issues/13515))

### 📚 Documentation

- Update API endpoints descriptions in OpenAPI ([#13647](https://github.com/blockscout/blockscout/issues/13647))

### ⚡ Performance

- Improve performance of api/v2/main-page/indexing-status endpoint ([#13730](https://github.com/blockscout/blockscout/pull/13730))
- Implement celo aggregated election rewards ([#13418](https://github.com/blockscout/blockscout/issues/13418))

### ⚙️ Miscellaneous Tasks

- GitHub Actions workflows: stop using ELIXIR_VERSION & OTP_VERSION from org/repo variables ([#13718](https://github.com/blockscout/blockscout/pull/13718))
- Refactoring of the application mode config ([#13715](https://github.com/blockscout/blockscout/pull/13715))
- Eliminate warnings in the Swagger file ([#13714](https://github.com/blockscout/blockscout/pull/13714))
- Change URL to Solidity binaries list ([#13711](https://github.com/blockscout/blockscout/pull/13711))
- Add osaka to the default list of supported EVM versions ([#13680](https://github.com/blockscout/blockscout/pull/13680))
- Filter out empty addresses from multichain export ([#13674](https://github.com/blockscout/blockscout/pull/13674))
- Validate NFT_MEDIA_HANDLER_BUCKET_FOLDER env ([#13671](https://github.com/blockscout/blockscout/pull/13671))
- Enhance RPC API errors logging ([#13664](https://github.com/blockscout/blockscout/pull/13664))
- Use chain id `31337` for `anvil` ([#13644](https://github.com/blockscout/blockscout/issues/13644))
- Update devcontainer image to use Elixir 1.19.4 ([#13645](https://github.com/blockscout/blockscout/issues/13645))
- Elixir 1.19.3 -> 1.19.4 ([#13643](https://github.com/blockscout/blockscout/issues/13643))
- Update devcontainer image to use Elixir 1.19 ([#13637](https://github.com/blockscout/blockscout/issues/13637))
- Internal transaction, Token transfer, Withdrawal, Smart-contracts, Main Page, Stats, Config and Search controllers OpenAPI specs ([#13557](https://github.com/blockscout/blockscout/issues/13557))
- Using own runner for build ([#13624](https://github.com/blockscout/blockscout/issues/13624))
- Drop token_instances_token_id_index index ([#13598](https://github.com/blockscout/blockscout/issues/13598))
- Add migration to drop unique tokens_contract_address_hash_index index ([#13596](https://github.com/blockscout/blockscout/issues/13596), [#13655](https://github.com/blockscout/blockscout/pull/13655))
- Elixir 1.17 -> 1.19 ([#13566](https://github.com/blockscout/blockscout/issues/13566))
- Handle `NativeCoin*ed` events on Arc chain to make dual token balances synced ([#13452](https://github.com/blockscout/blockscout/issues/13452))
- Improve DeleteZeroValueInternalTransactions migration ([#13569](https://github.com/blockscout/blockscout/issues/13569))
- Remove address-related props from sending to multichain service ([#13584](https://github.com/blockscout/blockscout/issues/13584))
- Move not auth cookies to headers ([#13478](https://github.com/blockscout/blockscout/issues/13478))
- Transaction controller OpenAPI spec ([#13419](https://github.com/blockscout/blockscout/issues/13419))
- Increase genesis file content fetch timeout ([#13527](https://github.com/blockscout/blockscout/issues/13527))

### New ENV variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `INDEXER_DISABLE_HOT_SMART_CONTRACTS_FETCHER`                 | If `true`, `Indexer.Fetcher.Stats.HotSmartContracts` won't be started. Implemented in [#13471](https://github.com/blockscout/blockscout/pull/13471).                                                                                                                                                                                                                                                                                                                                                                             | Version: v9.3.0\+ <br />Default: `false` <br />Applications: Indexer                                        |
| `MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_ENABLED`      | Enable of delete zero-value calls migration. Implemented in [#13305](https://github.com/blockscout/blockscout/pull/13305). | Version: v9.3.0\+ <br />Default: `false` <br />Applications: Indexer |
| `MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_BATCH_SIZE`   | Specifies the block batch size selected for the delete zero-value calls migration. Implemented in [#13305](https://github.com/blockscout/blockscout/pull/13305). | Version: v9.3.0\+ <br />Default: `100` <br />Applications: Indexer |
| `MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_STORAGE_PERIOD_DAYS` | Specifies the period for which recent zero-value calls won't be deleted in delete zero-value calls migration. Implemented in [#13305](https://github.com/blockscout/blockscout/pull/13305). | Version: v9.3.0\+ <br />Default: `30` <br />Applications: Indexer |
| `MIGRATION_DELETE_ZERO_VALUE_INTERNAL_TRANSACTIONS_CHECK_INTERVAL` | Specifies the interval between checking of new zero-value calls to be deleted in delete zero-value calls migration. Implemented in [#13305](https://github.com/blockscout/blockscout/pull/13305). | Version: v9.3.0\+ <br />Default: `1m` <br />Applications: Indexer |
| `MARKET_DIA_BLOCKCHAIN`                      | Sets DIA platform from https://www.diadata.org/docs/reference/apis/token-prices/api-endpoints/blockchains. Implemented in [#12678](https://github.com/blockscout/blockscout/pull/12678).                                                                                                                             | Version: v9.3.0\+ <br />Default: (empty) <br />Applications: Indexer                                     |
| `MARKET_DIA_BASE_URL`                        | If set, overrides the DIA API url. Implemented in [#12678](https://github.com/blockscout/blockscout/pull/12678).                                                                                                                                                                                                     | Version: v9.3.0\+ <br />Default: `https://api.diadata.org/v1` <br />Applications: API, Indexer           |
| `MARKET_DIA_COIN_ADDRESS_HASH`               | Sets address hash for native coin in DIA. Implemented in [#12678](https://github.com/blockscout/blockscout/pull/12678).                                                                                                                                                                                              | Version: v9.3.0\+ <br />Default: (empty) <br />Applications: API                                         |
| `MARKET_DIA_SECONDARY_COIN_ADDRESS_HASH`     | Sets address hash for secondary coin in DIA. Implemented in [#12678](https://github.com/blockscout/blockscout/pull/12678).                                                                                                                                                                                           | Version: v9.3.0\+ <br />Default: (empty) <br />Applications: API                                         |
| `INDEXER_METRICS_ENABLED`                                           | Flag to enable base indexer metrics. Implemented in [#13539](https://github.com/blockscout/blockscout/pull/13539).                                                      | Version: v9.3.0\+ <br />Default: true <br />Applications: Indexer   |
| `INDEXER_METRICS_ENABLED_TOKEN_INSTANCES_NOT_UPLOADED_TO_CDN_COUNT` | Flag to enable indexer metric: the count of token instances not uploaded to CDN. Implemented in [#13539](https://github.com/blockscout/blockscout/pull/13539).          | Version: v9.3.0\+ <br />Default: false <br />Applications: Indexer  |
| `INDEXER_METRICS_ENABLED_FAILED_TOKEN_INSTANCES_METADATA_COUNT`     | Flag to enable indexer metric: the count of token instances with failed metadata fetches. Implemented in [#13539](https://github.com/blockscout/blockscout/pull/13539). | Version: v9.3.0\+ <br />Default: true <br />Applications: Indexer   |
| `INDEXER_METRICS_ENABLED_UNFETCHED_TOKEN_INSTANCES_COUNT`           | Flag to enable indexer metric: the count of token instances pending to fetch. Implemented in [#13539](https://github.com/blockscout/blockscout/pull/13539).             | Version: v9.3.0\+ <br />Default: true <br />Applications: Indexer   |
| `INDEXER_METRICS_ENABLED_MISSING_CURRENT_TOKEN_BALANCES_COUNT`      | Flag to enable indexer metric: the count of current token balances with missing values. Implemented in [#13539](https://github.com/blockscout/blockscout/pull/13539).   | Version: v9.3.0\+ <br />Default: true <br />Applications: Indexer   |
| `INDEXER_METRICS_ENABLED_MISSING_ARCHIVAL_TOKEN_BALANCES_COUNT`     | Flag to enable indexer metric: the count of archival token balances with missing values. Implemented in [#13539](https://github.com/blockscout/blockscout/pull/13539).  | Version: v9.3.0\+ <br />Default: true <br />Applications: Indexer   |
| `INDEXER_OPTIMISM_L2_JOVIAN_TIMESTAMP`               | Jovian upgrade L2 block timestamp. If set to `0`, the Jovian is assumed to be active from genesis block. Implemented in [#13538](https://github.com/blockscout/blockscout/pull/13538).                                                                                                                                                                                                                                                                                                                                                                                        | Version: v9.3.0+ <br />Default: (empty) <br />Applications: API, Indexer                                 |
| `INDEXER_ARC_NATIVE_TOKEN_DECIMALS`        | Defines the number of decimals for Arc chain native token (e.g. USDC). Implemented in [#13452](https://github.com/blockscout/blockscout/pull/13452).    | Version: v9.3.0+ <br />Default: `6` <br />Applications: Indexer                                          |
| `INDEXER_ARC_NATIVE_TOKEN_CONTRACT`        | Arc chain native token contract address. Implemented in [#13452](https://github.com/blockscout/blockscout/pull/13452).                                  | Version: v9.3.0+ <br />Default: `0x3600000000000000000000000000000000000000` <br />Applications: Indexer |
| `INDEXER_ARC_NATIVE_TOKEN_SYSTEM_CONTRACT` | Arc chain system contract address emitting `NativeCoinTransferred` event. Implemented in [#13452](https://github.com/blockscout/blockscout/pull/13452). | Version: v9.3.0+ <br />Default: `0x1800000000000000000000000000000000000000` <br />Applications: Indexer |


## 9.2.2

### 🐛 Bug Fixes

- Fix next page params for tokens list API endpoint ([#13520](https://github.com/blockscout/blockscout/issues/13520))

## 9.2.1

### 🐛 Bug Fixes

- Fix REST API token holders pagination ([#13500](https://github.com/blockscout/blockscout/issues/13500))
- Add missing query binding to txlistinternal query ([#13479](https://github.com/blockscout/blockscout/issues/13479))
- API v2 errors logging to the proper log file ([#13133](https://github.com/blockscout/blockscout/issues/13133))

### ⚙️ Miscellaneous Tasks

- Silence multiple cspell complaints ([#13424](https://github.com/blockscout/blockscout/issues/13424))


## 9.2.0

### 🚀 Features

- distributed elixir runtime ([#13080](https://github.com/blockscout/blockscout/pull/13080))
- Delete internal transactions on reorgs ([#13121](https://github.com/blockscout/blockscout/issues/13121))
- Implement websocket endpoints support in the Universal Proxy config ([#13167](https://github.com/blockscout/blockscout/issues/13167))
- Celo accounts api ([#12982](https://github.com/blockscout/blockscout/issues/12982))
- Celo accounts indexing ([#12893](https://github.com/blockscout/blockscout/issues/12893))
- OP operator fee indexing ([#13139](https://github.com/blockscout/blockscout/issues/13139))
- Fields for OP Withdrawal Claim button ([#13272](https://github.com/blockscout/blockscout/issues/13272))
- OP Alt-DA support for batch indexer ([#13179](https://github.com/blockscout/blockscout/issues/13179))
- Add ci:core label ([#13249](https://github.com/blockscout/blockscout/issues/13249))
- Initial support of indexing EigenDA-grounded Arbitrum batches ([#12915](https://github.com/blockscout/blockscout/issues/12915))

### 🐛 Bug Fixes

- Fix token holders CSV export ([#13485](https://github.com/blockscout/blockscout/pull/13485))
- ERC-1155 value in advanced filters csv ([#13474](https://github.com/blockscout/blockscout/pull/13474))
- Fix /api/v2/tokens endpoints: allow back limit param ([#13473](https://github.com/blockscout/blockscout/pull/13473))
- Incorrect average block time for sub-second blocks ([#13469](https://github.com/blockscout/blockscout/issues/13469))
- Remove transaction_has_multiple_internal_transactions filter ([#13453](https://github.com/blockscout/blockscout/pull/13453))
- celo accounts transformer ([#13423](https://github.com/blockscout/blockscout/pull/13423))
- Fix broken txn batch blocks API endpoint ([#13438](https://github.com/blockscout/blockscout/pull/13438), [#13483](https://github.com/blockscout/blockscout/pull/13483))
- Set timeout: :infinity for DeleteZeroValueInternalTransactions ([#13434](https://github.com/blockscout/blockscout/pull/13434))
- Fix DeleteZeroValueInternalTransactions state keys ([#13431](https://github.com/blockscout/blockscout/pull/13431))
- dump block_hash to binary when querying celo epoch distributions ([#13410](https://github.com/blockscout/blockscout/pull/13410))
- Fix flaky indexer, web tests, refactoring ([#13392](https://github.com/blockscout/blockscout/issues/13392))
- Advanced filters: ERC-20 value in CSV ([#13326](https://github.com/blockscout/blockscout/issues/13326))
- Ignore old reorgs in beacon deposits fetcher ([#13372](https://github.com/blockscout/blockscout/issues/13372))
- Update FUNDING.json ([#13399](https://github.com/blockscout/blockscout/issues/13399))
- Add `log_index` field to celo validator group votes table ([#13391](https://github.com/blockscout/blockscout/issues/13391))
- Add fallback to cached token counters in corresponding async tasks ([#13348](https://github.com/blockscout/blockscout/issues/13348))
- Sanitize internal transaction error before insertion ([#13362](https://github.com/blockscout/blockscout/issues/13362))
- Set skip metadata only on contract errors ([#12858](https://github.com/blockscout/blockscout/issues/12858))
- Check if CoinBalance Realtime fetcher is disabled ([#13223](https://github.com/blockscout/blockscout/issues/13223))
- Improve timeout exception definition ([#13286](https://github.com/blockscout/blockscout/issues/13286))
- Enforce legacy query usage when sort by id ([#13323](https://github.com/blockscout/blockscout/issues/13323))
- Fix web tests after hiding compile-time chain types routes ([#13324](https://github.com/blockscout/blockscout/issues/13324))
- Hide compile-time chain type API routes in other chain type swaggers ([#13309](https://github.com/blockscout/blockscout/issues/13309))
- Fix SanitizeDuplicatedLogIndexLogs migration completion check ([#13308](https://github.com/blockscout/blockscout/issues/13308))

### ⚡ Performance

- Remove BENS preload from the main page API endpoints ([#13442](https://github.com/blockscout/blockscout/pull/13442), [#13449](https://github.com/blockscout/blockscout/pull/13449))
- Batch preload token transfers in `/api/v2/celo/epochs` ([#13398](https://github.com/blockscout/blockscout/issues/13398))
- Optimize token balance synchronous import steps ([#13217](https://github.com/blockscout/blockscout/issues/13217))
- Optimize `EmptyBlocksSanitizer` queries ([#13132](https://github.com/blockscout/blockscout/issues/13132))

### ⚙️ Miscellaneous Tasks

- add `CACHE_AVERAGE_BLOCK_TIME_WINDOW` ([#13470](https://github.com/blockscout/blockscout/pull/13470))
- Improve DeleteZeroValueInternalTransactions future updating ([#13437](https://github.com/blockscout/blockscout/pull/13437))
- advanced filters improvements ([#11909](https://github.com/blockscout/blockscout/pull/11909))
- Allow api_key in the query string for api/v2/tokens/:address_hash/instances/refetch-metadata endpoint ([#13412](https://github.com/blockscout/blockscout/pull/13412))
- *(ReindexDuplicatedInternalTransactions)* Optimize migration performance ([#13363](https://github.com/blockscout/blockscout/issues/13363))
- OpenAPI spec for the REST API endpoints in  token and CSV export controllers ([#13311](https://github.com/blockscout/blockscout/issues/13311))
- Edited the broken Discord badge ([#13115](https://github.com/blockscout/blockscout/issues/13115))
- OpenAPI spec for the REST API block controller ([#13274](https://github.com/blockscout/blockscout/issues/13274))
- Add PR title conventional commit check workflow ([#13238](https://github.com/blockscout/blockscout/issues/13238))
- Add label for running tests with enabled bridged tokens ([#13263](https://github.com/blockscout/blockscout/issues/13263))
- Phoenix update ([#13147](https://github.com/blockscout/blockscout/issues/13147))

### New ENV variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `INDEXER_EMPTY_BLOCKS_SANITIZER_HEAD_OFFSET`                  | Minimal age for block to be processed by empty block sanitizer. Implemented in [#13132](https://github.com/blockscout/blockscout/pull/13132)                                                                                                                                                                                                                                                                                                                                                                                     | Version: v9.2.0\+ <br />Default: `1000` <br />Applications: Indexer                                      |
| `INDEXER_INTERNAL_TRANSACTIONS_DELETE_QUEUE_BATCH_SIZE`        | Batch size for internal transactions delete queue handler. Implemented in [#13121](https://github.com/blockscout/blockscout/pull/13121).                                                                                                                                                                                                                                                                                                                                                                                         | Version: v9.2.0\+ <br />Default: `100` <br />Applications: Indexer                                        |
| `INDEXER_INTERNAL_TRANSACTIONS_DELETE_QUEUE_CONCURRENCY`       | Concurrency for internal transactions delete queue handler. Implemented in [#13121](https://github.com/blockscout/blockscout/pull/13121).                                                                                                                                                                                                                                                                                                                                                                                        | Version: v9.2.0\+ <br />Default: `1` <br />Applications: Indexer                                         |
| `INDEXER_INTERNAL_TRANSACTIONS_DELETE_QUEUE_THRESHOLD`         | Threshold for internal transactions delete queue handler. Implemented in [#13121](https://github.com/blockscout/blockscout/pull/13121).                                                                                                                                                                                                                                                                                                                                                                                          | Version: v9.2.0\+ <br />Default: `10m` <br />Applications: Indexer                                         |
| `INDEXER_OPTIMISM_L1_BATCH_ALT_DA_SERVER_URL`        | Defines a URL to Alt-DA server to retrieve L1 data from that. Example for Redstone: `https://da.redstonechain.com/get`. Implemented in [#13179](https://github.com/blockscout/blockscout/pull/13179).                                                                                                                                                                                                                                                                                                                                                                         | Version: v9.2.0+ <br />Default: (empty) <br />Applications: Indexer                                       |
| `INDEXER_OPTIMISM_L2_ISTHMUS_TIMESTAMP`              | Isthmus upgrade L2 block timestamp. Needed for operator fee determining. If set to `0`, the Isthmus is assumed to be active from genesis block. Implemented in [#13139](https://github.com/blockscout/blockscout/pull/13139).                                                                                                                                                                                                                                                                                                                                                 | Version: v9.2.0+ <br />Default: (empty) <br />Applications: API, Indexer                                  |
| `INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_BATCH_SIZE`     | Batch size for OP operator fee fetcher. Defines max number of transactions handled per batch. Implemented in [#13139](https://github.com/blockscout/blockscout/pull/13139).                                                                                                                                                                                                                                                                                                                                                                                                   | Version: v9.2.0\+ <br />Default: `100`<br />Applications: Indexer                                          |
| `INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_CONCURRENCY`    | Concurrency for OP operator fee fetcher. Implemented in [#13139](https://github.com/blockscout/blockscout/pull/13139).                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Version: v9.2.0\+ <br />Default: `3`<br />Applications: Indexer                                            |
| `INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT` | Timeout before new attempt to append item to OP operator fee fetcher queue if it's full. [Time format](backend-env-variables.md#time-format). Implemented in [#13139](https://github.com/blockscout/blockscout/pull/13139).                                                                                                                                                                                                                                                                                                                                     | Version: v9.2.0\+ <br />Default: `1s`<br />Applications: Indexer                                           |
| `INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_MAX_QUEUE_SIZE` | Maximum size of OP operator fee fetcher queue. Implemented in [#13139](https://github.com/blockscout/blockscout/pull/13139).                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Version: v9.2.0\+ <br />Default: `1000`<br />Applications: Indexer                                         |
| `INDEXER_OPTIMISM_OPERATOR_FEE_QUEUE_INIT_QUERY_LIMIT` | Limit of the init query for processing the OP operator fee fetcher queue. Implemented in [#13139](https://github.com/blockscout/blockscout/pull/13139).                                                                                                                                                                                                                                                                                                                                                                                                                     | Version: v9.2.0\+ <br />Default: `1000`<br />Applications: Indexer                                         |
| `CELO_LOCKED_GOLD_CONTRACT`                          | The address of the `LockedGold` core contract. Implemented in [#12893](https://github.com/blockscout/blockscout/pull/12893).                                                                                                                              | Version: v9.2.0+ <br />Default: (empty)<br />Applications: Indexer        |
| `CELO_ACCOUNTS_CONTRACT`                             | The address of the `Accounts` core contract. Implemented in [#12893](https://github.com/blockscout/blockscout/pull/12893).                                                                                                                                | Version: v9.2.0+ <br />Default: (empty)<br />Applications: Indexer        |
| `INDEXER_CELO_ACCOUNTS_CONCURRENCY`                  | Sets the maximum number of concurrent requests for fetching Celo accounts.                                                                                                                                                                                | Version: v9.2.0+ <br />Default: `1`<br />Applications: Indexer            |
| `INDEXER_CELO_ACCOUNTS_BATCH_SIZE`                   | Specifies the number of account addresses processed per batch during fetching.                                                                                                                                                                            | Version: v9.2.0+ <br />Default: `100`<br />Applications: Indexer          |
| `K8S_SERVICE`                                           | Kubernetes service name for Elixir nodes clusterization, more info on how to configure it can be found here https://hexdocs.pm/libcluster/Cluster.Strategy.Kubernetes.DNS.html. Implemented in [#13080](https://github.com/blockscout/blockscout/pull/13080).                                                                                                                                                                                      | Version: v9.2.0\+ <br />Default: (empty) <br />Applications: API, Indexer                                                                                                                                                                                                                                                                         |
| `CACHE_AVERAGE_BLOCK_TIME_WINDOW`                     | The number of blocks to be taken into account in the calculations. Introduced in [#13470](https://github.com/blockscout/blockscout/pull/13470).                                                                                                                                                                                                               | Version: v9.2.0\+ <br />Default: `100` <br />Applications: API, Indexer   |

### Deprecated ENV variables

| Variable                                              | Description                                                                                                                                                                                                                                                                                                                                        | Default                                                                                       | Version  | Deprecated in Version |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------------- | --------------------- |
| `NFT_MEDIA_HANDLER_NODES_MAP` | String in json map format, where key is erlang node and value is folder in R2/S3 bucket, example: `"{\"producer@172.18.0.4\": \"/folder_1\"}"`. If nft_media_handler runs in one pod with indexer, map should contain `self` key | | v6.10.0+ | v9.2.0+ |


## 9.1.1

### 🚀 Features

- Auto assert_schema in tests ([#13029](https://github.com/blockscout/blockscout/issues/13029))

### 🐛 Bug Fixes

- Fix token transfer test for celo ([#13250](https://github.com/blockscout/blockscout/pull/13250))
- Add reputation preload to celo base fee ([#13248](https://github.com/blockscout/blockscout/pull/13248))
- Add reputation preload for user op body for transaction interpreter ([#13241](https://github.com/blockscout/blockscout/pull/13241))
- Fix condition in Indexer.Fetcher.OnDemand.TokenTotalSupply fetcher ([#13240](https://github.com/blockscout/blockscout/pull/13240))
- Add reputation preload to state changes and bridged tokens ([#13235](https://github.com/blockscout/blockscout/pull/13235))
- Soften deposits deletion condition ([#13234](https://github.com/blockscout/blockscout/pull/13234))
- Fix logic of checking finishing of heavy DB index operation ([#13231](https://github.com/blockscout/blockscout/pull/13231))
- some flapping explorer/indexer tests ([#13230](https://github.com/blockscout/blockscout/pull/13230))
- Remove requirement for beacon deposit indexes to be sequential ([#13228](https://github.com/blockscout/blockscout/pull/13228))

### ⚡ Performance

- Improve perf of internal transactions retrieval from the DB ([#13232](https://github.com/blockscout/blockscout/pull/13232))

### ⚙️ Miscellaneous Tasks

- Fix tests ([#13244](https://github.com/blockscout/blockscout/pull/13244))
- Do not modify deposit indexer state on reorgs ([#13236](https://github.com/blockscout/blockscout/pull/13236))
- Refactoring reputation ([#13221](https://github.com/blockscout/blockscout/issues/13221))

## 9.1.0

### 🚀 Features

- beacon deposits ([#12985](https://github.com/blockscout/blockscout/pull/12985))
- on-demand bytecode fetching on smart contract verification requests ([#10724](https://github.com/blockscout/blockscout/issues/10724))
- Improved proxy detection ([#12846](https://github.com/blockscout/blockscout/issues/12846))
- Add `reputation` property where applicable ([#13070](https://github.com/blockscout/blockscout/issues/13070))
- Add envs to configure RemoteIp lib usage ([#13082](https://github.com/blockscout/blockscout/issues/13082))
- Add possibility to forward event notification to another DB ([#13064](https://github.com/blockscout/blockscout/issues/13064))
- Add x-api-key header ([#13076](https://github.com/blockscout/blockscout/issues/13076))
- Add token_type to token transfer API response ([#13038](https://github.com/blockscout/blockscout/issues/13038))
- Export main page counters to Multichain service ([#13007](https://github.com/blockscout/blockscout/issues/13007))
- Add methodId to txlist rpc method ([#13043](https://github.com/blockscout/blockscout/issues/13043))
- Runtime config option to disable file logging ([#12805](https://github.com/blockscout/blockscout/issues/12805))
- Add celo-specific APIv1 `getepoch` action ([#12853](https://github.com/blockscout/blockscout/issues/12853))

### 🐛 Bug Fixes

- Fix errors in celo epochs endpoints([#13201](https://github.com/blockscout/blockscout/pull/13201))
- Fix api/v2/addresses/{hash}/celo/election-rewards pagination ([#13215](https://github.com/blockscout/blockscout/pull/13215))
- Add reputation preload for celo gas_token ([#13200](https://github.com/blockscout/blockscout/pull/13200))
- Mark completed deposits in batches ([#13210](https://github.com/blockscout/blockscout/pull/13210))
- Adjustments in address nft and collections endpoints ([#13192](https://github.com/blockscout/blockscout/pull/13192))
- Fix batch's number processing from the socket event ([#13181](https://github.com/blockscout/blockscout/pull/13181))
- Delete PTOs for forked transactions ([#13145](https://github.com/blockscout/blockscout/pull/13145))
- Pagination and filtering issues in `/addresses/:hash/nft` ([#13175](https://github.com/blockscout/blockscout/pull/13175))
- Fix reputation preload for ERC-404 collections ([#13174](https://github.com/blockscout/blockscout/pull/13174))
- Add reputation to token, rework reputation preload ([#13149](https://github.com/blockscout/blockscout/pull/13149))
- Replace get_constant_by_key with get_constant_value in get_last_processed_token_address_hash ([#13118](https://github.com/blockscout/blockscout/issues/13118))
- Duplicates of smart contracts additional sources ([#13018](https://github.com/blockscout/blockscout/issues/13018))
- Set  for read ops in NFT backfillers ([#13116](https://github.com/blockscout/blockscout/issues/13116))
- Return internal transactions for consensus blocks only in /api/v2/internal-transactions ([#13041](https://github.com/blockscout/blockscout/issues/13041))
- Fix recv timeout option in Universal proxy config ([#13046](https://github.com/blockscout/blockscout/issues/13046))
- Fix failing ETH RPC tests ([#13099](https://github.com/blockscout/blockscout/issues/13099))
- Escape only significant characters in tokens ([#13078](https://github.com/blockscout/blockscout/issues/13078))
- `/api/v2/addresses/:hash/token-transfers` returns 500 on celo ([#13050](https://github.com/blockscout/blockscout/issues/13050))
- RuntimeEnvHelper usage in Auth0.Migrated ([#13075](https://github.com/blockscout/blockscout/issues/13075))
- Fix no function clause matching in Explorer.Chain.Transaction.decoded_input_data/5 ([#13055](https://github.com/blockscout/blockscout/issues/13055))
- Fix Postgres errors in Explorer.Migrator.BackfillMetadataURL ([#13063](https://github.com/blockscout/blockscout/issues/13063))
- Fix multichain search queue export bug processing ([#13049](https://github.com/blockscout/blockscout/issues/13049))
- Csv export for celo l2 epoch rewards on address ([#12815](https://github.com/blockscout/blockscout/issues/12815))
- Change signed_authorizations chain_id type to numeric ([#13042](https://github.com/blockscout/blockscout/issues/13042))
- Address api spec for `filecoin` and `zilliqa` chain types ([#12996](https://github.com/blockscout/blockscout/issues/12996))
- Token type filtering to support multiple types with OR logic ([#13008](https://github.com/blockscout/blockscout/issues/13008))
- Don't validate address hash for common blocks channels ([#13020](https://github.com/blockscout/blockscout/issues/13020))
- Fix matching in current token balances import filter ([#12930](https://github.com/blockscout/blockscout/issues/12930))
- Expand indexer timeout exception definition ([#12748](https://github.com/blockscout/blockscout/issues/12748))

### 🚜 Refactor

- Remove public tags request functionality ([#13006](https://github.com/blockscout/blockscout/issues/13006))

### ⚡ Performance

- Optimize maybe_hide_scam_addresses/3 query ([#12927](https://github.com/blockscout/blockscout/issues/12927))
- Fix perf of finding non pending block in internal transactions related queries ([#13189](https://github.com/blockscout/blockscout/pull/13189))
- Internal transactions REST API endpoint perf tradeoff ([#13191](https://github.com/blockscout/blockscout/pull/13191))

### ⚙️ Miscellaneous Tasks

- Remove quantile_estimator dep ([#13190](https://github.com/blockscout/blockscout/pull/13190))
- Add support of Scroll codecv8 ([#13090](https://github.com/blockscout/blockscout/pull/13090))
- Change release workflow ([#13087](https://github.com/blockscout/blockscout/issues/13087))
- Add INDEXER_DISABLE_OPTIMISM_INTEROP_MULTICHAIN_EXPORT env variable ([#13051](https://github.com/blockscout/blockscout/pull/13051))
- Update and format pull request template ([#13028](https://github.com/blockscout/blockscout/issues/13028))
- Add final check for ReindexDuplicatedInternalTransactions ([#13091](https://github.com/blockscout/blockscout/issues/13091))
- Remove obsolete circleci config ([#13097](https://github.com/blockscout/blockscout/issues/13097))
- Replace ReindexDuplicatedInternalTransactions grouping field ([#13084](https://github.com/blockscout/blockscout/issues/13084))
- Bump default rps to 5 ([#13089](https://github.com/blockscout/blockscout/issues/13089))
- Add `is_pending_update` flag to block and transaction API endpoints ([#13013](https://github.com/blockscout/blockscout/issues/13013))
- Bump actions major versions ([#13077](https://github.com/blockscout/blockscout/issues/13077))
- Move token transfers to a separate event handler ([#13068](https://github.com/blockscout/blockscout/issues/13068))
- Remove Polygon Edge modules and chain type ([#13056](https://github.com/blockscout/blockscout/issues/13056))
- Cover token info export to Multichain service by unit tests ([#12899](https://github.com/blockscout/blockscout/issues/12899))
- Route left API DB requests from master to read DB replica ([#12896](https://github.com/blockscout/blockscout/issues/12896))
- Refactor usage of delete_parameters_from_next_page_params/1 ([#13005](https://github.com/blockscout/blockscout/issues/13005))
- Move address nonce updating to a separate process ([#12941](https://github.com/blockscout/blockscout/issues/12941))
- Catchup fetcher various improvements ([#12866](https://github.com/blockscout/blockscout/issues/12866))
- Add disconnect_on_error_codes param to repo config ([#12800](https://github.com/blockscout/blockscout/issues/12800))
- Move addresses to a separate import stage ([#12857](https://github.com/blockscout/blockscout/issues/12857))

### New ENV variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `DISABLE_FILE_LOGGING`                                  | Disables file-based logging when set to `true`. When enabled, application logs will only be written to stdout/stderr.                                                                                                                                                                                                                                                                                                                              | Version: v9.1.0\+ <br />Default: `false` <br/>Applications: API, Indexer                                                                                                                                                                                                                                                                            |
| `API_RATE_LIMIT_REMOTE_IP_HEADERS`                | Comma separated list of HTTP headers to extract the real client IP address when Blockscout is behind a proxy for rate limiting purposes. Implemented in [#12386](https://github.com/blockscout/blockscout/pull/13082)                                 | Version: v9.1.0\+ <br />Default: `x-forwarded-for` <br />Applications: API               |
| `API_RATE_LIMIT_REMOTE_IP_KNOWN_PROXIES`          | Comma separated list of trusted proxy IP addresses or CIDR ranges that are allowed to set the client IP headers for rate limiting. Implemented in [#12386](https://github.com/blockscout/blockscout/pull/13082)                                       | Version: v9.1.0\+ <br />Default: `(empty)` <br />Applications: API                       |
| `INDEXER_DISABLE_OPTIMISM_INTEROP_MULTICHAIN_EXPORT` | Disables exporting of interop messages to Multichain service. Implemented in [#13051](https://github.com/blockscout/blockscout/pull/13051).                                                                                                                                                                                                                                                                                                                                                                                                                                   | Version: v9.1.0\+ <br />Default: `true` <br />Applications: Indexer                                        |
| `MICROSERVICE_MULTICHAIN_SEARCH_COUNTERS_CHUNK_SIZE`                              | Chunk size of counters while exporting to Multichain Search DB. Implemented in [#13007](https://github.com/blockscout/blockscout/pull/13007).                                                                                                                   | Version: v9.1.0\+ <br />Default: `1000`<br />Applications: Indexer            |
| `INDEXER_DISABLE_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_FETCHER`              | If `true`, multichain DB counters export fetcher doesn't run. Implemented in [#13007](https://github.com/blockscout/blockscout/pull/13007).                                                                                                                     | Version: v9.1.0\+ <br />Default: `false`<br />Applications: Indexer           |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_BATCH_SIZE`                   | Batch size for multichain DB counters export fetcher. Implemented in [#13007](https://github.com/blockscout/blockscout/pull/13007).                                                                                                                             | Version: v9.1.0\+ <br />Default: `1000`<br />Applications: Indexer            |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_CONCURRENCY`                  | Concurrency for multichain DB counters export fetcher. Implemented in [#13007](https://github.com/blockscout/blockscout/pull/13007).                                                                                                                            | Version: v9.1.0\+ <br />Default: `10`<br />Applications: Indexer              |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT` | Timeout before new attempt to append item to multichain DB counters export queue if it's full. [Time format](backend-env-variables.md#time-format). Implemented in [#13007](https://github.com/blockscout/blockscout/pull/13007).                               | Version: v9.1.0\+ <br />Default: `1s`<br />Applications: Indexer              |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_MAX_QUEUE_SIZE`               | Maximum size of multichain DB counters export queue. Implemented in [#13007](https://github.com/blockscout/blockscout/pull/13007).                                                                                                                              | Version: v9.1.0\+ <br />Default: `1000`<br />Applications: Indexer            |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_COUNTERS_QUEUE_INIT_QUERY_LIMIT`             | Limit of the init query for processing the counters export queue to the Multichain DB. Implemented in [#13007](https://github.com/blockscout/blockscout/pull/13007).                                                                                            | Version: v9.1.0\+ <br />Default: `1000` <br />Applications: Indexer           |
| `INDEXER_DISABLE_BEACON_DEPOSIT_FETCHER`                      | If `true`, the Beacon deposit fetcher won't be started. Implemented in [#12985](https://github.com/blockscout/blockscout/pull/12985).                                                                                                                                                                                           | Version: v9.1.0+ <br />Default: `false` <br />Applications: Indexer                  |
| `INDEXER_BEACON_DEPOSIT_FETCHER_INTERVAL`                     | The interval indicating how often deposit events should be queried. [Time format](/setup/env-variables/backend-envs-chain-specific#time-format). Implemented in [#12985](https://github.com/blockscout/blockscout/pull/12985).                                                                                                  | Version: v9.1.0+ <br />Default: `6s` <br />Applications: Indexer                     |
| `INDEXER_BEACON_DEPOSIT_FETCHER_BATCH_SIZE`                   | The batch size specifies how many events are retrieved in a single database query. Implemented in [#12985](https://github.com/blockscout/blockscout/pull/12985).                                                                                                                                                                | Version: v9.1.0+ <br />Default: `1000` <br />Applications: Indexer                   |
| `INDEXER_DISABLE_BEACON_DEPOSIT_STATUS_FETCHER`               | If `true`, the Beacon deposit status fetcher won't be started. Implemented in [#12985](https://github.com/blockscout/blockscout/pull/12985).                                                                                                                                                                                    | Version: v9.1.0+ <br />Default: `false` <br />Applications: Indexer                  |
| `INDEXER_BEACON_DEPOSIT_STATUS_FETCHER_EPOCH_DURATION`        | Epoch duration in the Beacon chain in seconds. Implemented in [#12985](https://github.com/blockscout/blockscout/pull/12985).                                                                                                                                                                                                    | Version: v9.1.0+ <br />Default: `384` <br />Applications: Indexer                    |
| `INDEXER_BEACON_DEPOSIT_STATUS_FETCHER_REFERENCE_TIMESTAMP`   | Any past finalized Beacon Chain epoch UTC timestamp. Used as reference for status fetcher scheduling. Implemented in [#12985](https://github.com/blockscout/blockscout/pull/12985).                                                                                                                                             | Version: v9.1.0+ <br />Default: `1722024023` <br />Applications: Indexer             |


### Deprecated ENV variables

| Variable                                              | Required | Description                                                                                                                                                                                                                                                                                                                                        | Default                                                                                       | Version  | Need recompile | Deprecated in Version |
| ----------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------- | -------------- | --------------------- |
| `INDEXER_POLYGON_EDGE_L1_RPC` | The RPC endpoint for L1 used to fetch deposit or withdrawal events. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_L1_EXIT_HELPER_CONTRACT` | The address of ExitHelper contract on L1 (root chain) used to fetch withdrawal exits. Required for withdrawal events indexing. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_L1_WITHDRAWALS_START_BLOCK` | The number of start block on L1 (root chain) to index withdrawal exits. If the table of withdrawal exits is not empty, the process will continue indexing from the last indexed message. If empty or not defined, the withdrawal exits are not indexed. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_L1_STATE_SENDER_CONTRACT` | The address of StateSender contract on L1 (root chain) used to fetch deposits. Required for deposit events indexing. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_L1_DEPOSITS_START_BLOCK` | The number of start block on L1 (root chain) to index deposits. If the table of deposits is not empty, the process will continue indexing from the last indexed message. If empty or not defined, the deposits are not indexed. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_L2_STATE_SENDER_CONTRACT` | The address of L2StateSender contract on L2 (child chain) used to fetch withdrawals. Required for withdrawal events indexing. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_L2_WITHDRAWALS_START_BLOCK` | The number of start block on L2 (child chain) to index withdrawals. If the table of withdrawals is not empty, the process will fill gaps and then continue indexing from the last indexed message. If empty or not defined, the withdrawals are not indexed. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_L2_STATE_RECEIVER_CONTRACT` | The address of StateReceiver contract on L2 (child chain) used to fetch deposit executes. Required for deposit events indexing. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_L2_DEPOSITS_START_BLOCK` | The number of start block on L2 (child chain) to index deposit executes. If the table of deposit executes is not empty, the process will fill gaps and then continue indexing from the last indexed message. If empty or not defined, the deposit executes are not indexed. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `INDEXER_POLYGON_EDGE_ETH_GET_LOGS_RANGE_SIZE` | Block range size for eth\_getLogs request in Polygon Edge indexer modules. Implemented in [#8180](https://github.com/blockscout/blockscout/pull/8180). |  | v5.3.0+ |  | v9.1.0 |
| `ACCOUNT_PUBLIC_TAGS_AIRTABLE_URL` | Airtable URL for public tag requests functionality |  | v5.0.0+ |  | v9.1.0 |
| `ACCOUNT_PUBLIC_TAGS_AIRTABLE_API_KEY` | Airtable API key for public tag requests functionality |  | v5.0.0+ |  | v9.1.0 |


## 9.0.2

### 🐛 Bug Fixes

- atoms in token_transfers_next_page_params ([#12992](https://github.com/blockscout/blockscout/pull/12992))
- Fix Mud worlds API endpoint ([#12991](https://github.com/blockscout/blockscout/pull/12991))
- Set 5 RPS for api/health/* ([#12990]https://github.com/blockscout/blockscout/pull/12990)
- Pagination with atoms in paging_params ([#12986](https://github.com/blockscout/blockscout/issues/12986))
- Fix RangesHelper.sanitize_ranges for empty list ([#12946](https://github.com/blockscout/blockscout/issues/12946))
- Remove apikey from next_page_params ([#12972](https://github.com/blockscout/blockscout/issues/12972))

## 9.0.1

### ⚙️ Miscellaneous Tasks

- Restore `getblocknobytime` response format to use `blockNumber` key ([#12955](https://github.com/blockscout/blockscout/issues/12955))

## 9.0.0

### 🚀 Features

- Export token info to Multichain service ([#12867](https://github.com/blockscout/blockscout/pull/12867))
- Export balances to Multichain DB([#12726](https://github.com/blockscout/blockscout/pull/12726))
- Add eip7702 authorization status fetcher ([#12451](https://github.com/blockscout/blockscout/issues/12451))
- Add token1155tx token404tx api v1 endpoints ([#12720](https://github.com/blockscout/blockscout/issues/12720))
- Async multichain data export ([#12490](https://github.com/blockscout/blockscout/issues/12490))
- Rate limits refactoring ([#12386](https://github.com/blockscout/blockscout/issues/12386))
- Integrate Open API Spex lib ([#11886](https://github.com/blockscout/blockscout/issues/11886))
- Update CodeQL action to v3 ([#12697](https://github.com/blockscout/blockscout/issues/12697)) ([#12703](https://github.com/blockscout/blockscout/issues/12703))
- Support merged tenants ([#12109](https://github.com/blockscout/blockscout/issues/12109))
- Support ethereum pre-deploy contracts ([#12579](https://github.com/blockscout/blockscout/issues/12579))
- Add `creation_status` field to address response ([#12660](https://github.com/blockscout/blockscout/issues/12660))
- Decode OP interop message payload, store cross-chain transfer data, display message page, send messages to Multichain ([#12387](https://github.com/blockscout/blockscout/issues/12387))
- Celo l2 epochs ([#12373](https://github.com/blockscout/blockscout/issues/12373))
- Add `/api/v2/config/celo` convenience endpoint ([#12238](https://github.com/blockscout/blockscout/issues/12238))

### 🐛 Bug Fixes

- Ignore rate limit for api/v2/import/token-info and api/v2/import/smart-contracts/:param ([#12917](https://github.com/blockscout/blockscout/pull/12917))
- Mitigate deadlocks while exporting balances and the main queue to the Multichain DB ([#12898](https://github.com/blockscout/blockscout/pull/12898), [#12928](https://github.com/blockscout/blockscout/pull/12928))
- Balances export queue: replace replace_all with replace only value and updated_at ([#12892](https://github.com/blockscout/blockscout/pull/12892))
- Fix naming for apikey param in OpenAPI spec ([#12891](https://github.com/blockscout/blockscout/pull/12891))
- Don't send coin balances with zero delta via ws ([#12890](https://github.com/blockscout/blockscout/pull/12890))
- Balances export queue to multichain replace do_nothing with replace_all on insertion to the queue ([#12888](https://github.com/blockscout/blockscout/pull/12888))
- Allow using temporary token for api/account/v2 by default ([#12869](https://github.com/blockscout/blockscout/pull/12869))
- Fix increment of retries_number in exporting data to Multichain DB ([#12847](https://github.com/blockscout/blockscout/pull/12847))
- Fix various errors on export of balances to Multichain DB ([#12837](https://github.com/blockscout/blockscout/pull/12837))
- Reject empty token_id and value in export of token balances to the Multichain DB ([#12829](https://github.com/blockscout/blockscout/pull/12829))
- Fix multichain export queues processing ([#12822](https://github.com/blockscout/blockscout/pull/12822))
- Remove token_id parameter from coin balance payload to Multichain service API endpoint ([#12817](https://github.com/blockscout/blockscout/pull/12817))
- Sanitize empty block_ranges payload before sending HTTP request to Multichain service([#12816](https://github.com/blockscout/blockscout/pull/12816))
- Disable Indexer.Fetcher.Optimism.Interop.MultichainExport for non-OP chains ([#12814](https://github.com/blockscout/blockscout/pull/12814))
- Fix flaky test for exporting balances to Multichain DB ([#12813](https://github.com/blockscout/blockscout/pull/12813))
- Filter out creation internal transaction with `index == 0` ([#12777](https://github.com/blockscout/blockscout/issues/12777))
- Filter out scilla transactions in internal transactions fetcher ([#12793](https://github.com/blockscout/blockscout/issues/12793))
- Change default ordering in `/api/v2/smart-contracts` ([#12767](https://github.com/blockscout/blockscout/issues/12767))
- Filter scilla transactions by status ([#12756](https://github.com/blockscout/blockscout/issues/12756))
- Fix timeout on cache update ([#12773](https://github.com/blockscout/blockscout/issues/12773))
- Error on too big block numbers in APIv1 `txlist` method ([#12727](https://github.com/blockscout/blockscout/issues/12727))
- Fix CSV export tests ([#12744](https://github.com/blockscout/blockscout/issues/12744))
- Fix race condition for EventNotification ([#12738](https://github.com/blockscout/blockscout/issues/12738))
- Multichain retry hex decoding ([#12742](https://github.com/blockscout/blockscout/issues/12742))
- Internal transactions balance extraction ([#12654](https://github.com/blockscout/blockscout/issues/12654))
- Multichain search export: retry only on failed chunks ([#12459](https://github.com/blockscout/blockscout/issues/12459))
- Display correct OP Deposit origin address ([#12672](https://github.com/blockscout/blockscout/issues/12672))
- Store blocks_validated in DB for Stability Validators ([#12540](https://github.com/blockscout/blockscout/issues/12540))
- `MarketHistory` on conflict clause ([#12541](https://github.com/blockscout/blockscout/issues/12541))
- Flaky 404 in `/api/v2/internal-transactions` ([#12701](https://github.com/blockscout/blockscout/issues/12701))
- CryptoRank integration ([#12523](https://github.com/blockscout/blockscout/issues/12523))
- Fix timeout on fetching address internal transactions ([#12570](https://github.com/blockscout/blockscout/issues/12570))
- Coin balance history with internal tx changes ([#12631](https://github.com/blockscout/blockscout/issues/12631))
- Update all block fields on conflict ([#12418](https://github.com/blockscout/blockscout/issues/12418))
- Fix pending transactions sanitizer ([#12559](https://github.com/blockscout/blockscout/issues/12559))
- Don't send logs without topic to sig provider ([#12620](https://github.com/blockscout/blockscout/issues/12620))
- Add missing fields to Celo Epochs-related endpoints ([#12589](https://github.com/blockscout/blockscout/issues/12589))
- Correctly use Geth importer for Besu genesis file. ([#12466](https://github.com/blockscout/blockscout/issues/12466)) ([#12686](https://github.com/blockscout/blockscout/issues/12686))
- Ignore unknown type txs in gas price oracle ([#12613](https://github.com/blockscout/blockscout/issues/12613))
- Resolve timeouts on Celo epoch reward contract reads ([#12229](https://github.com/blockscout/blockscout/issues/12229))
- Prevent constant refetching of celo epoch blocks ([#12498](https://github.com/blockscout/blockscout/issues/12498))
- Fix typo in ondemand token balance request ([#12495](https://github.com/blockscout/blockscout/issues/12495))
- Fix for `add_0x_prefix` function ([#12514](https://github.com/blockscout/blockscout/issues/12514))

### ⚡ Performance

- Api v1 `txlist`& `txlistinternal` endpoints ([#12774](https://github.com/blockscout/blockscout/issues/12774))
- Optimize Explorer.Chain.Cache.Blocks ([#12402](https://github.com/blockscout/blockscout/issues/12402))

### ⚙️ Miscellaneous Tasks

- Remove obsolete API response props ([#12931](https://github.com/blockscout/blockscout/pull/12931))
- Balances Multichain export: Refactor rows acquisition for deletion query ([#12839](https://github.com/blockscout/blockscout/pull/12839))
- Change name of Swagger generation workflow ([#12840](https://github.com/blockscout/blockscout/pull/12840))
- migrate Auth0 to mint as well ([#12807](https://github.com/blockscout/blockscout/pull/12807))
- Migrate from HTTPoison to Tesla.Mint ([#12699](https://github.com/blockscout/blockscout/pull/12699))
- Merge adjacent missing block ranges ([#12778](https://github.com/blockscout/blockscout/issues/12778))
- Optimize missing block ranges operations ([#12705](https://github.com/blockscout/blockscout/issues/12705))
- Hold parity with Etherscan APIv1 for `getcontractcreation` and `getblocknobytime` endpoints ([#12721](https://github.com/blockscout/blockscout/issues/12721))
- Allow resending reindexed OP interop messages to Multichain service ([#12626](https://github.com/blockscout/blockscout/issues/12626))
- Duplicate block countdown endpoint in API v2 ([#12704](https://github.com/blockscout/blockscout/issues/12704))
- Revise Explorer.Helper.add_0x_prefix usage ([#12543](https://github.com/blockscout/blockscout/issues/12543))
- New tac microservice endpoint for search ([#12448](https://github.com/blockscout/blockscout/issues/12448))
- Add filter for value > 0 to txlistinternal ([#12679](https://github.com/blockscout/blockscout/issues/12679))
- Optimize realtime events notifier ([#12494](https://github.com/blockscout/blockscout/issues/12494))
- Drop address_coin_balances value_fetched_at index ([#12598](https://github.com/blockscout/blockscout/issues/12598))
- Update deprecated address to address_hash in tx summary response ([#12617](https://github.com/blockscout/blockscout/issues/12617))
- Remove redundant word in comment ([#12603](https://github.com/blockscout/blockscout/issues/12603))
- Move background migrations under indexer mode ([#12480](https://github.com/blockscout/blockscout/issues/12480))
- Support multiple interop messages view on transaction page ([#12455](https://github.com/blockscout/blockscout/issues/12455))
- Remove `is_self_destructed` field in `/api/v2/smart-contracts/{address_hash}` response ([#12239](https://github.com/blockscout/blockscout/issues/12239))
- Set home directory for blockscout user ([#12337](https://github.com/blockscout/blockscout/issues/12337))

### New ENV variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `INDEXER_DB_EVENT_NOTIFICATIONS_CLEANUP_ENABLED`                       | If `true`, `Indexer.Utils.EventNotificationsCleaner` process starts. Implemented in [#12738](https://github.com/blockscout/blockscout/pull/12738)                                                                                                                                                                                                                                                                                                                                                                                     | <p>Version: v9.0.0+<br>Default: <code>true</code><br>Applications: Indexer</p>                                        |
| `INDEXER_DB_EVENT_NOTIFICATIONS_CLEANUP_INTERVAL`                      | Interval between DB event notifications cleanup. [Time format](backend-env-variables.md#time-format). Implemented in [#12738](https://github.com/blockscout/blockscout/pull/12738)                                                                                                                                                                                                                                                                                                                                                        | <p>Version: v9.0.0+<br>Default: <code>2m</code><br>Applications: Indexer</p>                                          |
| `INDEXER_DB_EVENT_NOTIFICATIONS_CLEANUP_MAX_AGE`                       | Max age of DB event notifications before they are cleaned up. [Time format](backend-env-variables.md#time-format). Implemented in [#12738](https://github.com/blockscout/blockscout/pull/12738)                                                                                                                                                                                                                                                                                                                                           | <p>Version: v9.0.0+<br>Default: <code>5m</code><br>Applications: Indexer</p>                                          |
| `INDEXER_SIGNED_AUTHORIZATION_STATUS_BATCH_SIZE`              | Batch size (number of blocks) for EIP7702 authorizations status fetcher. Implemented in [#12451](https://github.com/blockscout/blockscout/pull/12451).                                                                                                                                                                                                                                                                                                                                                                           | <p>Version: v9.0.0+<br>Default: <code>10</code><br>Applications: Indexer</p>                                          |
| `MIGRATION_REINDEX_BLOCKS_WITH_MISSING_TRANSACTIONS_BATCH_SIZE`  | Number of blocks to reindex in the batch. Implemented in [#12559](https://github.com/blockscout/blockscout/pull/12559).                                                                                                                                                                                                                                                | <p>Version: v9.0.0+<br>Default: <code>10</code><br>Applications: Indexer</p>          |
| `MIGRATION_REINDEX_BLOCKS_WITH_MISSING_TRANSACTIONS_CONCURRENCY` | Number of parallel reindexing block batches processing. Implemented in [#12559](https://github.com/blockscout/blockscout/pull/12559).                                                                                                                                                                                                                                  | <p>Version: v9.0.0+<br>Default: <code>1</code><br>Applications: Indexer</p>           |
| `MIGRATION_REINDEX_BLOCKS_WITH_MISSING_TRANSACTIONS_TIMEOUT`     | Timeout between reindexing block batches processing. Implemented in [#12559](https://github.com/blockscout/blockscout/pull/12559).                                                                                                                                                                                                                                     | <p>Version: v9.0.0+<br>Default: <code>0</code><br>Applications: Indexer</p>           |
| `MIGRATION_REINDEX_BLOCKS_WITH_MISSING_TRANSACTIONS_ENABLED`     | Enable reindex blocks with missing transactions migration. Implemented in [#12559](https://github.com/blockscout/blockscout/pull/12559).                                                                                                                                                                                                                               | <p>Version: v9.0.0+<br>Default: <code>false</code><br>Applications: Indexer</p>       |
| `MIGRATION_MERGE_ADJACENT_MISSING_BLOCK_RANGES_BATCH_SIZE`         | Specifies the missing block range batch size selected for the merge migration. Implemented in [#12778](https://github.com/blockscout/blockscout/pull/12778).                                                                                                                                                                                                           | <p>Version: v9.0.0+<br>Default: <code>100</code><br>Applications: Indexer</p>         |
| `API_RATE_LIMIT_CONFIG_URL`                       | URL to fetch API rate limit configuration from external source. Implemented in [#12386](https://github.com/blockscout/blockscout/pull/12386)                                                                                                          | <p>Version: v9.0.0+<br>Default: (empty)<br>Applications: API</p>                         |
| `API_RATE_LIMIT_BY_KEY_TIME_INTERVAL`             | Time interval for API rate limit by key. [Time format](backend-env-variables.md#time-format). Implemented in [#12386](https://github.com/blockscout/blockscout/pull/12386)                                                                            | <p>Version: v9.0.0+<br>Default: <code>1s</code><br>Applications: API</p>                 |
| `API_RATE_LIMIT_BY_WHITELISTED_IP_TIME_INTERVAL`  | Time interval for API rate limit by whitelisted IP. [Time format](backend-env-variables.md#time-format). Implemented in [#12386](https://github.com/blockscout/blockscout/pull/12386)                                                                 | <p>Version: v9.0.0+<br>Default: <code>1s</code><br>Applications: API</p>                 |
| `API_RATE_LIMIT_UI_V2_WITH_TOKEN_TIME_INTERVAL`   | Time interval for API rate limit for UI v2 with token. [Time format](backend-env-variables.md#time-format). Implemented in [#12386](https://github.com/blockscout/blockscout/pull/12386)                                                              | <p>Version: v9.0.0+<br>Default: <code>1s</code><br>Applications: API</p>                 |
| `API_RATE_LIMIT_BY_ACCOUNT_API_KEY_TIME_INTERVAL` | Time interval for API rate limit by account API key. [Time format](backend-env-variables.md#time-format). Implemented in [#12386](https://github.com/blockscout/blockscout/pull/12386)                                                                | <p>Version: v9.0.0+<br>Default: <code>1s</code><br>Applications: API</p>                 |
| `INDEXER_DISABLE_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_FETCHER`             | If `true`, multichain DB main (blocks, transactions, addresses) export fetcher doesn't run. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).                  | <p>Version: v9.0.0+<br>Default: <code>false</code><br>Applications: Indexer</p>                                      |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_BATCH_SIZE`                                 | Batch size for multichain DB main (blocks, transactions, addresses) export fetcher. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).                       | <p>Version: v9.0.0+<br>Default: <code>1000</code><br>Applications: Indexer</p>                                        |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_CONCURRENCY`                                | Concurrency for multichain DB main (blocks, transactions, addresses) export fetcher. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).     | <p>Version: v9.0.0+<br>Default: <code>10</code><br>Applications: Indexer</p>                                         |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT`                                | Timeout before new attempt to append item to multichain DB main (blocks, transactions, addresses) export queue if it's full. [Time format](backend-env-variables.md#time-format). Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).     | <p>Version: v9.0.0+<br>Default: <code>1s</code><br>Applications: Indexer</p>   |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_MAIN_QUEUE_MAX_QUEUE_SIZE`                                | Maximum size of multichain DB main (blocks, transactions, addresses) export queue. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).     | <p>Version: v9.0.0+<br>Default: <code>1000</code><br>Applications: Indexer</p>   |
| `INDEXER_DISABLE_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_FETCHER`             | If `true`, multichain DB balances export fetcher doesn't run. Implemented in [#12580](https://github.com/blockscout/blockscout/pull/12580).                  | <p>Version: v9.0.0+<br>Default: <code>false</code><br>Applications: Indexer</p>                                      |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_BATCH_SIZE`                                 | Batch size for multichain DB balances export fetcher. Implemented in [#12580](https://github.com/blockscout/blockscout/pull/12580).                       | <p>Version: v9.0.0+<br>Default: <code>1000</code><br>Applications: Indexer</p>                                        |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_CONCURRENCY`                                | Concurrency for multichain DB balances export fetcher. Implemented in [#12580](https://github.com/blockscout/blockscout/pull/12580).     | <p>Version: v9.0.0+<br>Default: <code>10</code><br>Applications: Indexer</p>                                         |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_ENQUEUE_BUSY_WAITING_TIMEOUT`                                | Timeout before new attempt to append item to multichain DB balances export queue if it's full. [Time format](backend-env-variables.md#time-format). Implemented in [#12580](https://github.com/blockscout/blockscout/pull/12580).     | <p>Version: v9.0.0+<br>Default: <code>1s</code><br>Applications: Indexer</p>   |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_BALANCES_QUEUE_MAX_QUEUE_SIZE`                                | Maximum size of multichain DB balances export queue. Implemented in [#12580](https://github.com/blockscout/blockscout/pull/12580).     | <p>Version: v9.0.0+<br>Default: <code>1000</code><br>Applications: Indexer</p>   |
| `INDEXER_POLYGON_ZKEVM_BATCHES_IGNORE`            | Comma-separated list of batch numbers that should be ignored by the fetcher. Implemented in [#12387](https://github.com/blockscout/blockscout/pull/12387).                                                                                                                                                                                                            | <p>Version: v9.0.0+<br>Default: (empty)<br>Applications: Indexer</p>             |
| `INDEXER_OPTIMISM_MULTICHAIN_BATCH_SIZE`             | Max number of items sent to the Multichain service in one batch. Implemented in [#12387](https://github.com/blockscout/blockscout/pull/12387).                                                                                                                                                                                                                                                                                                                                                                                                                                | <p>Version: v9.0.0+<br>Default: <code>100</code><br>Applications: Indexer</p>                                         |
| `CELO_UNRELEASED_TREASURY_CONTRACT` | The address[^1] of the `CeloUnreleasedTreasury` core contract. Implemented in [#12373](https://github.com/blockscout/blockscout/pull/12373). | <p>Version: v9.0.0+<br>Default: (empty)<br>Applications: Indexer</p> |
| `CELO_VALIDATORS_CONTRACT`          | The address[^1] of the `Validators` core contract. Implemented in [#12373](https://github.com/blockscout/blockscout/pull/12373).             | <p>Version: v9.0.0+<br>Default: (empty)<br>Applications: Indexer</p> |
| `CELO_EPOCH_MANAGER_CONTRACT`       | The address[^1] of the `EpochManager` core contract. Implemented in [#12373](https://github.com/blockscout/blockscout/pull/12373).           | <p>Version: v9.0.0+<br>Default: (empty)<br>Applications: Indexer</p> |

## 8.1.2

### ⚙️ Miscellaneous Tasks

- Parsing L2 block number of OP Dispute Game on BOB chain ([#12831](https://github.com/blockscout/blockscout/pull/12831))

## 8.1.1

### 🐛 Bug Fixes

- Add missing preload for logs in /api/v2/transactions/:transaction_hash_param/summary ([#12491](https://github.com/blockscout/blockscout/issues/12491))

## 8.1.0

### 🚀 Features

- Add lower bound for base fee ([#12370](https://github.com/blockscout/blockscout/pull/12370))
- Multichain Search DB export retry queue ([#12377](https://github.com/blockscout/blockscout/issues/12377))
- Add TAC operation search ([#12367](https://github.com/blockscout/blockscout/issues/12367))
- Add `internal_transactions_count` prop in api/v2/blocks/:block endpoint ([#12405](https://github.com/blockscout/blockscout/issues/12405))

### 🐛 Bug Fixes

- Handle mismatched 0x prefixed bytes ([#12453](https://github.com/blockscout/blockscout/pull/12453))
- Fix logs decoding issue for proxies ([#12414](https://github.com/blockscout/blockscout/issues/12414))
- Refactor TokenInstanceMetadataRefetch on demand fetcher ([#12419](https://github.com/blockscout/blockscout/issues/12419))
- Fix for type output in ETH RPC API transaction by hash endpoint
- Frozen confirmations discovery on Arbitrum Nova ([#12385](https://github.com/blockscout/blockscout/issues/12385))
- Add prague Solidity EVM version ([#12115](https://github.com/blockscout/blockscout/issues/12115))
- Fix :checkout_timeout error ([#12406](https://github.com/blockscout/blockscout/issues/12406))
- Force index usage on select current token balances ([#12390](https://github.com/blockscout/blockscout/issues/12390))
- Fix retrieving max block number in MissingRangesCollector ([#12333](https://github.com/blockscout/blockscout/issues/12333))
- Start PubSub before Endpoint ([#12274](https://github.com/blockscout/blockscout/issues/12274))
- Fix FunctionClauseError on internal transactions indexing ([#12246](https://github.com/blockscout/blockscout/issues/12246))
- Support updated zkSync calldata format in batch proof tracking ([#12234](https://github.com/blockscout/blockscout/issues/12234))
- On demand bytecode fetcher for eip7702 addresses ([#12330](https://github.com/blockscout/blockscout/issues/12330))
- Handle pending operations for empty blocks as well ([#12349](https://github.com/blockscout/blockscout/issues/12349))

### 🚜 Refactor

- Eliminate join with internal_transactions table to get list logs in API v1 ([#12352](https://github.com/blockscout/blockscout/issues/12352))
- Define pending block operations by set of block hashes query ([#12375](https://github.com/blockscout/blockscout/issues/12375))
- Move `address_to_internal_transactions/2` to `Explorer.Chain.InternalTransaction` module ([#12346](https://github.com/blockscout/blockscout/issues/12346))
- Single definition of smart-contract internal creation transaction query ([#12335](https://github.com/blockscout/blockscout/issues/12335))

### ⚡ Performance

- Force index usage in `api/v2/addresses/:hash/transactions` ([#12415](https://github.com/blockscout/blockscout/issues/12415))

### ⚙️ Miscellaneous Tasks

- Add updated-gas-oracle to Access-Control-Allow-Headers ([#12473](https://github.com/blockscout/blockscout/pull/12473))
- Add additional test for Universal proxy, duplicate all proxy endpoints at /3rdparty ([#12442](https://github.com/blockscout/blockscout/pull/12442))
- Improve logic behind emerging of custom fields in the response of `eth_getTransactionByHash` ETH RPC API endpoint ([#12416](https://github.com/blockscout/blockscout/issues/12416))
- Internal transactions unique index ([#12394](https://github.com/blockscout/blockscout/issues/12394))
- Update blocks consensus in case of import failure ([#12243](https://github.com/blockscout/blockscout/issues/12243))
- Sanitize ERC-1155 token balances without token ids ([#12305](https://github.com/blockscout/blockscout/issues/12305))
- Support Celestia Alt-DA in OP batches indexer and Super Roots in OP withdrawals indexer ([#12332](https://github.com/blockscout/blockscout/issues/12332))
- Send DB read queries to replica in on-demand fetchers ([#12383](https://github.com/blockscout/blockscout/issues/12383))

### New ENV variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `HACKNEY_DEFAULT_POOL_SIZE`                             | Size of `default` hackney pool. Implemented in [#12406](https://github.com/blockscout/blockscout/pull/12406).                                                                                                                                                                                                                                                                                                                                      | <p>Version: v8.1.0+<br>Default: <code>1000</code><br>Applications: API, Indexer</p>                                                                                         |
| `MIGRATION_REINDEX_DUPLICATED_INTERNAL_TRANSACTIONS_BATCH_SIZE`   | Number of internal transactions to reindex in the batch. Implemented in [#12394](https://github.com/blockscout/blockscout/pull/12394).                                                                                                                                                                                                                                 | <p>Version: v8.1.0+<br>Default: <code>100</code><br>Applications: Indexer</p>         |
| `MIGRATION_REINDEX_DUPLICATED_INTERNAL_TRANSACTIONS_CONCURRENCY`  | Number of parallel reindexing internal transaction batches processing. Implemented in [#12394](https://github.com/blockscout/blockscout/pull/12394).                                                                                                                                                                                                                   | <p>Version: v8.1.0+<br>Default: <code>1</code><br>Applications: Indexer</p>           |
| `MIGRATION_REINDEX_DUPLICATED_INTERNAL_TRANSACTIONS_TIMEOUT`      | Timeout between reindexing internal transaction batches processing. Implemented in [#12394](https://github.com/blockscout/blockscout/pull/12394).                                                                                                                                                                                                                      | <p>Version: v8.1.0+<br>Default: <code>0</code><br>Applications: Indexer</p>           |
| `INDEXER_SCROLL_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL` | Defines a URL to Blockscout Blobs API to retrieve L1 blobs from that. Example for Sepolia: `https://eth-sepolia.blockscout.com/api/v2/blobs`. Implemented in [#12294](https://github.com/blockscout/blockscout/pull/12294).                                | <p>Version: v8.1.0+<br>Default: (empty)<br>Applications: Indexer</p>                   |
| `MICROSERVICE_MULTICHAIN_SEARCH_ADDRESSES_CHUNK_SIZE`          | Chunk size of addresses while exporting to Multichain Search DB. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377)                                                                    | <p>Version: v8.1.0+<br>Default: (empty)<br>Applications: API, Indexer</p> |
| `INDEXER_DISABLE_MULTICHAIN_SEARCH_DB_EXPORT_RETRY_FETCHER`             | If `true`, `retry` multichain search export fetcher doesn't run. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).                  | <p>Version: v8.1.0+<br>Default: <code>false</code><br>Applications: Indexer</p>                                      |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_RETRY_BATCH_SIZE`                                 | Batch size for `retry` multichain search export fetcher. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).                       | <p>Version: v8.1.0+<br>Default: <code>10</code><br>Applications: Indexer</p>                                        |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_RETRY_CONCURRENCY`                                | Concurrency for `retry` multichain search export fetcher. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).     | <p>Version: v8.1.0+<br>Default: <code>10</code><br>Applications: Indexer</p>                                         |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_RETRY_ENQUEUE_BUSY_WAITING_TIMEOUT`                                | Timeout before new attempt to append item to `retry` multichain search export queue if it's full. [Time format](backend-env-variables.md#time-format). Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).     | <p>Version: v8.1.0+<br>Default: <code>1s</code><br>Applications: Indexer</p>   |
| `INDEXER_MULTICHAIN_SEARCH_DB_EXPORT_RETRY_MAX_QUEUE_SIZE`                                | Maximum size of `retry` multichain search export queue. Implemented in [#12377](https://github.com/blockscout/blockscout/pull/12377).     | <p>Version: v8.1.0+<br>Default: <code>1000</code><br>Applications: Indexer</p>   |


## 8.0.2

### 🚀 Features

- Rate limiter for on-demand fetchers ([#12218](https://github.com/blockscout/blockscout/issues/12218))
- Add average batch time (L2) to prometheus metrics ([#12217](https://github.com/blockscout/blockscout/issues/12217))
- Contract creation tx block number binary search ([#10530](https://github.com/blockscout/blockscout/issues/10530))
- Enhance health endpoint logic: track L2-rollup batches health ([#11888](https://github.com/blockscout/blockscout/issues/11888))
- Universal API Proxy ([#12119](https://github.com/blockscout/blockscout/issues/12119))
- Add sorting by tx count and balance to `/api/v2/addresses` ([#12168](https://github.com/blockscout/blockscout/issues/12168))
- Support OP interop messages ([#11903](https://github.com/blockscout/blockscout/issues/11903))
- Store and validate metadata_url ([#12102](https://github.com/blockscout/blockscout/issues/12102))
- Captcha scoped bypass token for token instance metadata refetch ([#12147](https://github.com/blockscout/blockscout/issues/12147))
- Add filter by `type` and `call_type` to `/api/v2/blocks/{:block_hash}/internal-transactions` ([#11968](https://github.com/blockscout/blockscout/issues/11968))
- ERC-7760 proxy type support ([#12057](https://github.com/blockscout/blockscout/issues/12057))
- Extend scam tokens feature on other endpoints ([#11975](https://github.com/blockscout/blockscout/issues/11975))
- JSON RPC metrics ([#12070](https://github.com/blockscout/blockscout/issues/12070))
- Add search by transaction hash capability at api/v2/internal-transactions endpoint ([#12025](https://github.com/blockscout/blockscout/issues/12025))
- Add ENS and metadata preload to /api/v2/proxy/metadata/addresses ([#11962](https://github.com/blockscout/blockscout/issues/11962))
- Zilliqa stakers API ([#11615](https://github.com/blockscout/blockscout/issues/11615))
- Refine setting of certified flag on smart-contracts ([#11855](https://github.com/blockscout/blockscout/issues/11855))
- Add PendingTransactionOperation ([#11157](https://github.com/blockscout/blockscout/issues/11157))
- Allow from_period and to_period to be timestamps in CSV export functionality ([#11862](https://github.com/blockscout/blockscout/issues/11862))
- Add support of ResolvedDelegateProxy proxy pattern ([#11720](https://github.com/blockscout/blockscout/issues/11720))

### 🐛 Bug Fixes

- Fix Indexer.Helper.http_get_request function ([#12317](https://github.com/blockscout/blockscout/pull/12317))
- Rename left props in API v2 with new naming convention ([#12314](https://github.com/blockscout/blockscout/issues/12314))
- Temporary disable PendingTransactionOperation ([#12312](https://github.com/blockscout/blockscout/issues/12312))
- Add `bash` to `builder-deps` build stage ([#12316](https://github.com/blockscout/blockscout/issues/12316))
- Build on macos ([#12308](https://github.com/blockscout/blockscout/issues/12308))
- Fix MissingBlockRange.fill_ranges_between/3 for empty range ([#12319](https://github.com/blockscout/blockscout/pull/12319))
- Fix CSV export "to" range to include the whole day in all cases ([#12286](https://github.com/blockscout/blockscout/pull/12286))
- Return compatibility with previous version of health endpoint([#12280](https://github.com/blockscout/blockscout/pull/12280))
- Unbind import from compile-time chain_type ([#12277](https://github.com/blockscout/blockscout/pull/12277))
- Read `CHAIN_TYPE` and `MUD_INDEXER_ENABLED` envs in runtime config ([#12270](https://github.com/blockscout/blockscout/issues/12270))
- Limit max import concurrency ([#12261](https://github.com/blockscout/blockscout/pull/12261))
- CSV export: download items for the given day if from / to period are equal ([#12260](https://github.com/blockscout/blockscout/pull/12260))
- Upgrade missing balanceOf token condition ([#12254](https://github.com/blockscout/blockscout/pull/12254))
- Add missing load of health_latest_batch_average_time_from_db ([#12240](https://github.com/blockscout/blockscout/pull/12240))
- Handle unconfigured coin fetcher ETS access ([#12228](https://github.com/blockscout/blockscout/pull/12228))
- Negate condition for language check in solidityscan controller ([#12222](https://github.com/blockscout/blockscout/pull/12222))
- Look up sources for partially verified smart contracts ([#12221](https://github.com/blockscout/blockscout/pull/12221))
- BufferedTask-based approach for fetching Arbitrum-specific settlement info ([#12192](https://github.com/blockscout/blockscout/pull/12192))
- Contract creation transaction associations and bytecode twin detection ([#12086](https://github.com/blockscout/blockscout/issues/12086))
- Improve background migrations + new `Indexer.Migrator.RecoveryWETHTokenTransfers` ([#12065](https://github.com/blockscout/blockscout/issues/12065))
- Update docker cache references to use ghcr.io ([#12178](https://github.com/blockscout/blockscout/issues/12178))
- Add blob and authorization list info to ETH RPC API ([#12150](https://github.com/blockscout/blockscout/issues/12150))
- Fix Stability web test ([#12171](https://github.com/blockscout/blockscout/issues/12171))
- Fix Rootstock failed tests ([#12169](https://github.com/blockscout/blockscout/issues/12169))
- Unify Block Range Collector behavior for undefined and single range ([#12153](https://github.com/blockscout/blockscout/issues/12153))
- Signed_authorizations table migrate nonce to numeric(20,0) ([#12157](https://github.com/blockscout/blockscout/issues/12157))
- Refactor smart-contract API v2 endpoint output ([#12076](https://github.com/blockscout/blockscout/issues/12076))
- Managing gas usage sum cache and address count cache ([#12149](https://github.com/blockscout/blockscout/issues/12149))
- Web3 wallet login on Rootstock ([#12121](https://github.com/blockscout/blockscout/issues/12121))
- Refactor a query to get missing confirmation for Arbitrum blocks ([#11914](https://github.com/blockscout/blockscout/issues/11914))
- Fix error in old UI ([#12112](https://github.com/blockscout/blockscout/issues/12112))
- OnDemand fetchers memory consumption for api mode ([#12082](https://github.com/blockscout/blockscout/issues/12082))
- Implement DA record deduplication for Arbitrum batch processing ([#12095](https://github.com/blockscout/blockscout/issues/12095))
- Empty contract code addresses ([#12023](https://github.com/blockscout/blockscout/issues/12023))
- Unify response for single and batch 1155 transfer in RPC API ([#12083](https://github.com/blockscout/blockscout/issues/12083))
- Is_verified for verified eip7702 proxies ([#12033](https://github.com/blockscout/blockscout/issues/12033))
- Recovered functionality of Arbitrum batch fetcher ([#12059](https://github.com/blockscout/blockscout/issues/12059))
- Fix flaking test ([#12013](https://github.com/blockscout/blockscout/issues/12013))
- Confirmations of Arbitrum blocks near genesis ([#11790](https://github.com/blockscout/blockscout/issues/11790))
- Fix finding of first block to index ([#11875](https://github.com/blockscout/blockscout/issues/11875))
- Async fetch internal transactions from reindex migration ([#11959](https://github.com/blockscout/blockscout/issues/11959))
- Fix Indexer.Fetcher.ContractCode unhandled error ([#11873](https://github.com/blockscout/blockscout/issues/11873))

### 🚜 Refactor

- Consistency with the core application in properties namings in rollups-related API endpoints ([#12055](https://github.com/blockscout/blockscout/issues/12055))
- Refactor market related code ([#11844](https://github.com/blockscout/blockscout/pull/11844))

### ⚡ Performance

- Optimize watchlist query ([#12264](https://github.com/blockscout/blockscout/pull/12264))
- Add index for slow `/api/v2/addresses?sort=transactions_count&order=asc` ([#12230](https://github.com/blockscout/blockscout/pull/12230))
- `/api/v2/smart-contracts` endpoint ([#12060](https://github.com/blockscout/blockscout/issues/12060))
- Optimize query for user token transfers list filtered by token ([#12039](https://github.com/blockscout/blockscout/issues/12039))
- Improve watchlist rendering performance ([#11999](https://github.com/blockscout/blockscout/issues/11999))

### ⚙️ Miscellaneous Tasks

- Add Scroll Euclid upgrade support ([#12294](https://github.com/blockscout/blockscout/issues/12294))
- Decrease PBO to PTO migration batch size ([#12279](https://github.com/blockscout/blockscout/pull/12279))
- Decrease PendingOperationsHelper blocks_batch_size ([#12276](https://github.com/blockscout/blockscout/pull/12276))
- Update docker compose to use ghcr.io images ([#12177](https://github.com/blockscout/blockscout/issues/12177))
- Add typed_ecto_schema to release ([#12255](https://github.com/blockscout/blockscout/pull/12255))
- Suppress logging for expected 404 errors in account abstraction ([#12242](https://github.com/blockscout/blockscout/pull/12242))
- Upgrade on demand balances fetchers ([#12104](https://github.com/blockscout/blockscout/pull/12104))
- Migrate images to ghcr.io ([#12128](https://github.com/blockscout/blockscout/issues/12128))
- Don't send transaction interpretation request for failed tx ([#12164](https://github.com/blockscout/blockscout/issues/12164))
- Move `redstone` chain type to runtime ([#12124](https://github.com/blockscout/blockscout/issues/12124))
- Move `DISABLE_INDEXER` option to runtime ([#12139](https://github.com/blockscout/blockscout/issues/12139))
- Drop transactions index duplicates ([#12144](https://github.com/blockscout/blockscout/issues/12144))
- CDN improvement: batch DB upsert ([#11918](https://github.com/blockscout/blockscout/issues/11918))
- Partially move chain types to runtime ([#12114](https://github.com/blockscout/blockscout/issues/12114))
- Chain counters refactoring and setup persistency for global counters in the DB ([#11849](https://github.com/blockscout/blockscout/issues/11849))
- Remove legacy decompiled contracts API ([#11998](https://github.com/blockscout/blockscout/issues/11998))
- Eliminate intercept for V2 socket channels ([#12003](https://github.com/blockscout/blockscout/issues/12003))
- Treat `SHRINK_INTERNAL_TRANSACTIONS_ENABLED` as runtime env ([#12110](https://github.com/blockscout/blockscout/issues/12110))
- Docker compose reduce env output ([#12111](https://github.com/blockscout/blockscout/issues/12111))
- Replaced the link to the blockscout badge ([#12106](https://github.com/blockscout/blockscout/issues/12106))
- Remove default JSON RPC endpoint ([#12071](https://github.com/blockscout/blockscout/issues/12071))
- Remove token object from API v2 api/v2/tokens/:hash/holders endpoint ([#12022](https://github.com/blockscout/blockscout/issues/12022))
- Remove Read/Write smart-contract API v2 endpoints ([#12026](https://github.com/blockscout/blockscout/issues/12026))
- Use DB replica, if it's enabled, for proxy-related queries ([#12020](https://github.com/blockscout/blockscout/issues/12020))
- Ganache -> Anvil JSON RPC Variant ([#12066](https://github.com/blockscout/blockscout/issues/12066))
- Remove `is_vyper_contract` from the `/api/v2/smart-contracts/{address_hash}` endpoint response ([#11823](https://github.com/blockscout/blockscout/issues/11823))
- Eliminate warnings in `epoch_logs.ex` ([#12027](https://github.com/blockscout/blockscout/issues/12027))
- Migrate to `language` enum field in `smart_contracts` table ([#11813](https://github.com/blockscout/blockscout/issues/11813))
- Fetch epoch logs and rewards until `CELO_L2_MIGRATION_BLOCK` ([#11949](https://github.com/blockscout/blockscout/issues/11949))
- GraphQL introspection plug ([#11843](https://github.com/blockscout/blockscout/issues/11843))
- Remove duplicate endpoints for 3d party proxies ([#11940](https://github.com/blockscout/blockscout/issues/11940))
- Limit number of implementations proxy before insertion into the DB ([#11882](https://github.com/blockscout/blockscout/issues/11882))

### New ENV variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `HEALTH_MONITOR_CHECK_INTERVAL`                                 | Interval between health stats collection. [Time format](backend-env-variables.md#time-format). Implemented in [#11888](https://github.com/blockscout/blockscout/pull/11888/)                                                                                                                                                                                                                                                                                                     | <p>Version: v8.0.0+<br>Default: <code>1m</code><br>Applications: API, Indexer</p>                                                                                          |
| `HEALTH_MONITOR_BLOCKS_PERIOD`                                 | New blocks indexed max delay in /health API endpoint. [Time format](backend-env-variables.md#time-format). Implemented in [#11888](https://github.com/blockscout/blockscout/pull/11888/)                                                                                                                                                                                                                                                                                                     | <p>Version: v8.0.0+<br>Default: <code>5m</code><br>Applications: API, Indexer</p>                                                                                          |
| `HEALTH_MONITOR_BATCHES_PERIOD`                                 | New batches indexed max delay in /health API endpoint. [Time format](backend-env-variables.md#time-format). Implemented in [#11888](https://github.com/blockscout/blockscout/pull/11888/)                                                                                                                                                                                                                                                                                                     | <p>Version: v8.0.0+<br>Default: <code>4h</code><br>Applications: API, Indexer</p>                                                                                          |
| `INDEXER_TOKEN_INSTANCE_CIDR_BLACKLIST`                       | List of IP addresses in CIDR format to block when fetching token instance metadata. Example: `"0.0.0.0/32,192.168.0.0/16"`. Implemented in [#12102](https://github.com/blockscout/blockscout/pull/12102).                                                                                                                                                                                                                                                                                                                        | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: Indexer</p>                                                  |
| `INDEXER_TOKEN_INSTANCE_HOST_FILTERING_ENABLED`               | If `false`, the URL from which metadata is fetched will not be resolved to an IP address, and the IP address will not be checked against the blacklist. Implemented in [#12102](https://github.com/blockscout/blockscout/pull/12102).                                                                                                                                                                                                                                                                                           | <p>Version: v8.0.0+<br>Default: <code>true</code><br>Applications: Indexer</p>                                        |
| `INDEXER_TOKEN_INSTANCE_ALLOWED_URI_PROTOCOLS`                | List of allowed URI protocols (schemes) for requests when fetching token instance metadata. Implemented in [#12102](https://github.com/blockscout/blockscout/pull/12102).                                                                                                                                                                                                                                                                                                                                                        | <p>Version: v8.0.0+<br>Default: <code>http,https</code><br>Applications: Indexer</p>                                  |
| `MIGRATION_SMART_CONTRACT_LANGUAGE_DISABLED`                  | If set to `true`, the migration to the `language` field in the `smart_contracts` table will not start. If set to `false`, the migration proceeds as normal. Implemented in [#11813](https://github.com/blockscout/blockscout/pull/11813).                                                                                                                              | <p>Version: v8.0.0+<br>Default: <code>false</code><br>Applications: Indexer</p>       |
| `MIGRATION_SMART_CONTRACT_LANGUAGE_BATCH_SIZE`                | Defines the number of records to be processed in each batch when migrating the `language` field in the `smart_contracts` table. Implemented in [#11813](https://github.com/blockscout/blockscout/pull/11813).                                                                                                                                                          | <p>Version: v8.0.0+<br>Default: <code>100</code><br>Applications: Indexer</p>         |
| `MIGRATION_SMART_CONTRACT_LANGUAGE_CONCURRENCY`               | Specifies how many concurrent processes can handle the `language` field migration. Implemented in [#11813](https://github.com/blockscout/blockscout/pull/11813).                                                                                                                                                                                                       | <p>Version: v8.0.0+<br>Default: <code>1</code><br>Applications: Indexer</p>           |
| `MIGRATION_BACKFILL_METADATA_URL_DISABLED`                    | If set to `true`, the backfiller of `metadata_url` field in the `token_instances` table will not start. If set to `false`, the migration proceeds as normal. Implemented in [#12102](https://github.com/blockscout/blockscout/pull/12102).                                                                                                                               | <p>Version: v8.0.0+<br>Default: <code>false</code><br>Applications: Indexer</p>       |
| `MIGRATION_BACKFILL_METADATA_URL_BATCH_SIZE`                  | Defines the number of records to be processed in each batch when backfilling the `metadata_url` field in the `token_instances` table. Implemented in [#12102](https://github.com/blockscout/blockscout/pull/12102).                                                                                                                                                      | <p>Version: v8.0.0+<br>Default: <code>100</code><br>Applications: Indexer</p>         |
| `MIGRATION_BACKFILL_METADATA_URL_CONCURRENCY`                 | Specifies how many concurrent processes can handle the `metadata_url` field backfilling. Implemented in [#12102](https://github.com/blockscout/blockscout/pull/12102).                                                                                                                                                                                                   | <p>Version: v8.0.0+<br>Default: <code>5</code><br>Applications: Indexer</p>           |
| `MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_CONCURRENCY`         | Specifies how many concurrent processes can handle the recovery WETH token transfers migration. Implemented in [#12065](https://github.com/blockscout/blockscout/pull/12065).                                                                                                                                                                                          | <p>Version: v8.0.0+<br>Default: <code>5</code><br>Applications: Indexer</p>           |
| `MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_BATCH_SIZE`          | Defines the number of records to be processed in each batch when recovery WETH token transfers. Implemented in [#12065](https://github.com/blockscout/blockscout/pull/12065).                                                                                                                                                                                          | <p>Version: v8.0.0+<br>Default: <code>50</code><br>Applications: Indexer</p>          |
| `MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_TIMEOUT`             | Defines the timeout between processing each batch (`batch_size` * `concurrency`) in the recovery WETH token transfers migration. Follows the [time format](backend-env-variables.md#time-format). Implemented in [#12065](https://github.com/blockscout/blockscout/pull/12065).                                                                                        | <p>Version: v8.0.0+<br>Default: <code>0s</code><br>Applications: Indexer</p>          |
| `MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_BLOCKS_BATCH_SIZE`   | Specifies the block range size selected for the recovery of WETH token transfer migration. Implemented in [#12065](https://github.com/blockscout/blockscout/pull/12065).                                                                                                                                                                                               | <p>Version: v8.0.0+<br>Default: <code>100000</code><br>Applications: Indexer</p>      |
| `MIGRATION_RECOVERY_WETH_TOKEN_TRANSFERS_HIGH_VERBOSITY`      | If set to `true`, enables high verbosity logging (logs each transaction hash, where missed transfers were restored) during the recovery of WETH token transfer migration. Implemented in [#12065](https://github.com/blockscout/blockscout/pull/12065).                                                                                                                | <p>Version: v8.0.0+<br>Default: <code>true</code><br>Applications: Indexer</p>        |
| `CACHE_ADDRESS_COUNT_PERIOD`         | Interval for restarting the task that calculates the total number of addresses.                                                                                                                                                                                                                                                                     | <p>Version: v8.0.0+<br>Default: <code>30m</code><br>Applications: API, Indexer</p>   |
| `RE_CAPTCHA_TOKEN_INSTANCE_REFETCH_METADATA_SCOPED_BYPASS_TOKEN`    | API key that allows to skip reCAPTCHA check for requests to `/api/v2/tokens/{token_hash}/instances/{token_id}/refetch-metadata` endpoint. Implemented in [#12147](https://github.com/blockscout/blockscout/pull/12147)                                                                                   | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API</p>            |
| `INDEXER_ARBITRUM_BATCHES_TRACKING_FAILURE_THRESHOLD`             | The time threshold for transaction batch monitoring tasks. If a task has not run successfully within this threshold, it is marked as failed and enters a cooldown period before retrying. Implemented in [#12192](https://github.com/blockscout/blockscout/pull/12192). | <p>Version: v8.0.0+<br>Default: <code>10m</code><br>Applications: Indexer</p> |
| `RATE_LIMITER_REDIS_URL`                           | Redis DB URL for rate limiter. Implemented in [#12218](https://github.com/blockscout/blockscout/pull/12218)                                                                                                                               | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API</p>          |
| `RATE_LIMITER_ON_DEMAND_TIME_INTERVAL`             | Time interval of rate limit for on-demand fetchers. Implemented in [#12218](https://github.com/blockscout/blockscout/pull/12218)                                                                                                          | <p>Version: v8.0.0+<br>Default: <code>5s</code><br>Applications: API</p>  |
| `RATE_LIMITER_ON_DEMAND_LIMIT_BY_IP`               | Rate limit for an IP address for on-demand fetcher call. Implemented in [#12218](https://github.com/blockscout/blockscout/pull/12218)                                                                                                     | <p>Version: v8.0.0+<br>Default: <code>100</code><br>Applications: API</p> |
| `RATE_LIMITER_ON_DEMAND_EXPONENTIAL_TIMEOUT_COEFF` | Coefficient to calculate exponential timeout for on-demand rate limit. Implemented in [#12218](https://github.com/blockscout/blockscout/pull/12218)                                                                                       | <p>Version: v8.0.0+<br>Default: <code>100</code><br>Applications: API</p> |
| `RATE_LIMITER_ON_DEMAND_MAX_BAN_INTERVAL`          | Max time an IP address can be banned from on-demand fetcher calls. Implemented in [#12218](https://github.com/blockscout/blockscout/pull/12218)                                                                                           | <p>Version: v8.0.0+<br>Default: <code>1h</code><br>Applications: API</p>  |
| `RATE_LIMITER_ON_DEMAND_LIMITATION_PERIOD`         | Time after which the number of bans for the IP address will be reset. Implemented in [#12218](https://github.com/blockscout/blockscout/pull/12218)                                                                                        | <p>Version: v8.0.0+<br>Default: <code>1h</code><br>Applications: API</p>  |
| `DISABLE_MARKET`                            | Disables all fetchers and any market data displaying. Setting this to `true` will disable all market-related functionality. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                      | <p>Version: v8.0.0+<br>Default: <code>false</code><br>Applications: API, Indexer</p>                                |
| `MARKET_NATIVE_COIN_SOURCE`                 | Source for realtime native coin price fetching. Possible values are: `coin_gecko`, `coin_market_cap`, `crypto_rank`, or `mobula`. Useful when multiple coin IDs are configured and you want to explicitly select the source. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                     | <p>Version: v8.0.0+<br>Default: <code>coin_gecko</code><br>Applications: API</p>                                    |
| `MARKET_SECONDARY_COIN_SOURCE`              | Source for realtime secondary coin fetching. Possible values are: `coin_gecko`, `coin_market_cap`, `crypto_rank`, or `mobula`. Useful when multiple secondary coin IDs are configured. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                           | <p>Version: v8.0.0+<br>Default: <code>coin_gecko</code><br>Applications: API</p>                                    |
| `MARKET_TOKENS_SOURCE`                      | Sets the source for tokens price fetching. Available values are `coin_gecko`, `crypto_rank`, `mobula`. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                           | <p>Version: v8.0.0+<br>Default: <code>coin_gecko</code><br>Applications: Indexer</p>                                |
| `MARKET_NATIVE_COIN_HISTORY_SOURCE`         | Sets the source for price history fetching. Available values are `crypto_compare`, `coin_gecko`, `mobula`, `coin_market_cap` and `crypto_rank`. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                  | <p>Version: v8.0.0+<br>Default: <code>crypto_compare</code><br>Applications: Indexer</p>                            |
| `MARKET_SECONDARY_COIN_HISTORY_SOURCE`      | Sets the source for secondary coin price history fetching. Available values are `crypto_compare`, `coin_gecko`, `mobula`, `coin_market_cap` and `crypto_rank`. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                   | <p>Version: v8.0.0+<br>Default: <code>crypto_compare</code><br>Applications: Indexer</p>                            |
| `MARKET_MARKET_CAP_HISTORY_SOURCE`          | Sets the source for market cap history fetching. Available values are `coin_gecko` and `coin_market_cap`. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                        | <p>Version: v8.0.0+<br>Default: <code>coin_gecko</code><br>Applications: Indexer</p>                                |
| `MARKET_TVL_HISTORY_SOURCE`                 | Sets the source for TVL history fetching. Available value is `defillama`. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                        | <p>Version: v8.0.0+<br>Default: <code>defillama</code><br>Applications: Indexer</p>                                 |
| `MARKET_COINGECKO_PLATFORM_ID`              | [CoinGecko](https://www.coingecko.com/) platform id for which token prices are fetched, see full list in [`/asset_platforms`](https://api.coingecko.com/api/v3/asset_platforms) endpoint. Examples: "ethereum", "optimistic-ethereum". Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).           | <p>Version: v8.0.0+<br>Default: <code>ethereum</code><br>Applications: Indexer</p>                                  |
| `MARKET_COINGECKO_BASE_URL`                 | If set, overrides the Coingecko base URL. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                        | <p>Version: v8.0.0+<br>Default: <code>https://api.coingecko.com/api/v3</code><br>Applications: API, Indexer</p>     |
| `MARKET_COINGECKO_BASE_PRO_URL`             | If set, overrides the Coingecko Pro base URL. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                    | <p>Version: v8.0.0+<br>Default: <code>https://pro-api.coingecko.com/api/v3</code><br>Applications: API, Indexer</p> |
| `MARKET_COINGECKO_API_KEY`                  | CoinGecko API key. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                               | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_COINGECKO_COIN_ID`                  | Sets CoinGecko coin ID. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                          | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_COINGECKO_SECONDARY_COIN_ID`        | Sets CoinGecko coin ID for secondary coin market chart. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                          | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_COINMARKETCAP_BASE_URL`             | If set, overrides the CoinMarketCap base URL (Free and Pro). Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                     | <p>Version: v8.0.0+<br>Default: <code>https://pro-api.coinmarketcap.com/v2</code><br>Applications: API, Indexer</p> |
| `MARKET_COINMARKETCAP_API_KEY`              | CoinMarketCap API key. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                           | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_COINMARKETCAP_COIN_ID`              | CoinMarketCap coin id. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                           | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_COINMARKETCAP_SECONDARY_COIN_ID`    | CoinMarketCap coin id for secondary coin. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                        | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_CRYPTOCOMPARE_BASE_URL`             | If set, overrides the CryptoCompare base URL. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                    | <p>Version: v8.0.0+<br>Default: <code>https://min-api.cryptocompare.com</code><br>Applications: API, Indexer</p>    |
| `MARKET_CRYPTOCOMPARE_COIN_SYMBOL`          | CryptoCompare coin symbol for native coin (e.g., "OP" for Optimism). CryptoCompare uses symbols instead of IDs. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                  | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: Indexer</p>                                                |
| `MARKET_CRYPTOCOMPARE_SECONDARY_COIN_SYMBOL`| CryptoCompare coin symbol for secondary coin market chart. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                       | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: Indexer</p>                                                |
| `MARKET_CRYPTORANK_PLATFORM_ID`             | Sets Cryptorank platform ID. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                     | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: Indexer</p>                                                |
| `MARKET_CRYPTORANK_BASE_URL`                | If set, overrides the Cryptorank API url. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                        | <p>Version: v8.0.0+<br>Default: <code>https://api.cryptorank.io/v1/</code><br>Applications: API, Indexer</p>        |
| `MARKET_CRYPTORANK_API_KEY`                 | Cryptorank API key. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                              | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_CRYPTORANK_COIN_ID`                 | Sets Cryptorank coin ID. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                         | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_CRYPTORANK_SECONDARY_COIN_ID`       | Sets Cryptorank coin ID for secondary coin. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                      | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_DEFILLAMA_COIN_ID`                  | DefiLlama coin id. Use the `name` field from the `/v2/chains` endpoint response (e.g., "OP Mainnet" for Optimism). Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                               | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: Indexer</p>                                                |
| `MARKET_MOBULA_PLATFORM_ID`                 | Mobula platform ID. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                              | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: Indexer</p>                                                |
| `MARKET_MOBULA_BASE_URL`                    | If set, overrides the Mobula API base URL. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                       | <p>Version: v8.0.0+<br>Default: <code>https://api.mobula.io/api/1</code><br>Applications: API, Indexer</p>          |
| `MARKET_MOBULA_API_KEY`                     | Mobula API key. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                                  | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_MOBULA_COIN_ID`                     | Set Mobula coin ID. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                                              | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_MOBULA_SECONDARY_COIN_ID`           | Set Mobula coin ID for secondary coin. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                           | <p>Version: v8.0.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                           |
| `MARKET_COIN_FETCHER_ENABLED`               | If `false` disables fetching of realtime native coin price. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                      | <p>Version: v8.0.0+<br>Default: <code>true</code><br>Applications: API</p>                                          |
| `MARKET_COIN_CACHE_PERIOD`                  | Cache period for coin exchange rates. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                            | <p>Version: v8.0.0+<br>Default: <code>10m</code><br>Applications: API</p>                                           |
| `MARKET_TOKENS_FETCHER_ENABLED`             | If `false` disables fetching of token prices. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                    | <p>Version: v8.0.0+<br>Default: <code>true</code><br>Applications: Indexer</p>                                      |
| `MARKET_TOKENS_INTERVAL`                    | Interval between batch requests of token prices. Can be decreased in order to fetch prices faster if you have pro rate limit. [Time format](backend-env-variables.md#time-format). Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                               | <p>Version: v8.0.0+<br>Default: <code>10s</code><br>Applications: Indexer</p>                                       |
| `MARKET_TOKENS_REFETCH_INTERVAL`            | Interval between refetching token prices, responsible for the relevance of prices. [Time format](backend-env-variables.md#time-format). Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                          | <p>Version: v8.0.0+<br>Default: <code>1h</code><br>Applications: Indexer</p>                                        |
| `MARKET_TOKENS_MAX_BATCH_SIZE`              | Batch size of a single token price request. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                                      | <p>Version: v8.0.0+<br>Default: <code>500</code><br>Applications: Indexer</p>                                       |
| `MARKET_HISTORY_FETCHER_ENABLED`            | If `false` disables fetching of marked data history. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                             | <p>Version: v8.0.0+<br>Default: <code>true</code><br>Applications: Indexer</p>                                      |
| `MARKET_HISTORY_FIRST_FETCH_DAY_COUNT`      | Initial number of days to fetch for market history. Implemented in [#11844](https://github.com/blockscout/blockscout/pull/11844).                                                                                                                                                                                              | <p>Version: v8.0.0+<br>Default: <code>365</code><br>Applications: Indexer</p>                                       |

### Deprecated ENV variables

| Variable                                              | Required | Description                                                                                                                                                                                                                                                                                                                                        | Default                                                                                       | Version  | Need recompile | Deprecated in Version |
| ----------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------- | -------------- | --------------------- |
| `CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL`         | | Interval to restart the task which calculates addresses with balances.                                                                                                                                                                                                                                                                     | 30m  | v4.1.3+ | | v8.0.0
| `HEALTHY_BLOCKS_PERIOD`                                 |          | New blocks indexed max delay in /health API endpoint. [Time format](env-variables.md#time-format). Implemented in [#2294](https://github.com/blockscout/blockscout/pull/2294/)                                                                                                                                                                                                                                                                    | 5m                                                                                | v2.0.2+ |                | v8.0.0 |

## 7.0.2

### ⚡ Performance

- Logs list decoding: Accumulate ABI for unique address hashes ([#11967](https://github.com/blockscout/blockscout/pull/11967))
- Logs list decoding: Use Sig provider microservice batched request ([#11956](https://github.com/blockscout/blockscout/issues/11956), [#11963](https://github.com/blockscout/blockscout/issues/11963))
- Transactions list: Don't fetch revert reason for txs list ([#11935](https://github.com/blockscout/blockscout/issues/11935))

## 7.0.1

### 🐛 Bug Fixes

- Show scam ENS in search ([#11933](https://github.com/blockscout/blockscout/issues/11933))
- Show scam EOA in search ([#11932](https://github.com/blockscout/blockscout/issues/11932))
- Replace unique filecoin addresses indexes with not unique ([#11905](https://github.com/blockscout/blockscout/issues/11905))
- Render token transfers from celo epoch logs ([#11915](https://github.com/blockscout/blockscout/issues/11915))

## 7.0.0

### 🚀 Features

- NFT collection trigger refetch Admin API endpoint ([#10263](https://github.com/blockscout/blockscout/issues/10263))
- Improve NFT sanitizers ([#11543](https://github.com/blockscout/blockscout/issues/11543))
- Add new endpoint /api/v2/proxy/account-abstraction/status ([#11784](https://github.com/blockscout/blockscout/issues/11784))
- Adds support for NeonVM linked Solana transactions ([#11667](https://github.com/blockscout/blockscout/issues/11667)) ([#11736](https://github.com/blockscout/blockscout/issues/11736))
- Enable /api/v2/internal-transactions endpoint ([#11792](https://github.com/blockscout/blockscout/issues/11792))
- Integrate metadata tags to search ([#11719](https://github.com/blockscout/blockscout/issues/11719))
- Add Arweave NFT image link parsing support ([#11565](https://github.com/blockscout/blockscout/issues/11565))
- Disable re-verification from partial to partial match by default ([#11737](https://github.com/blockscout/blockscout/issues/11737))
- DB Index heavy operations processing module ([#11604](https://github.com/blockscout/blockscout/issues/11604))
- Multiple strategies for filecoin address info fetching ([#11412](https://github.com/blockscout/blockscout/issues/11412))
- Preload NFT to token transfers ([#11756](https://github.com/blockscout/blockscout/issues/11756))
- Add show_scam_tokens cookie ([#11747](https://github.com/blockscout/blockscout/issues/11747))
- Add ENS and metadata preload to /api/v2/tokens/{hash}/instances ([#11760](https://github.com/blockscout/blockscout/issues/11760))
- Return 200 on addresses which are not present in DB ([#11506](https://github.com/blockscout/blockscout/issues/11506))
- Enhance txlistinternal API v1: make transaction hash and address hash not mandatory ([#11717](https://github.com/blockscout/blockscout/issues/11717))
- Backfill for Arbitrum-specific information in blocks and transactions ([#11163](https://github.com/blockscout/blockscout/issues/11163))
- Ignore events older than 24 hours in Explorer.Account.Notifier.… ([#11654](https://github.com/blockscout/blockscout/issues/11654))
- Add timeout env for proxy metadata requests ([#11656](https://github.com/blockscout/blockscout/issues/11656))
- Support filecoin addresses in search ([#11499](https://github.com/blockscout/blockscout/issues/11499))
- Return error on verification if address is not a smart contract ([#11504](https://github.com/blockscout/blockscout/issues/11504))

### 🐛 Bug Fixes

- Add BRIDGED_TOKENS_ENABLED to custom Gnosis chain docker images ([#11895](https://github.com/blockscout/blockscout/pull/11895))
- Fix /verified-contracts in old UI ([#11854](https://github.com/blockscout/blockscout/pull/11854))
- Cleanup token instance metadata on nft collection metadata refetch ([#11848](https://github.com/blockscout/blockscout/pull/11848))
- Allow skip fiat_value in /api/v2/addresses/{hash}/tokens endpoint ([#11837](https://github.com/blockscout/blockscout/pull/11837))
- Handle invalid BLACKFORT_VALIDATOR_API_URL ([#11812](https://github.com/blockscout/blockscout/issues/11812))
- Fix scam addresses ban in quick search ([#11810](https://github.com/blockscout/blockscout/issues/11810))
- Handle case when `epoch_distribution` is `nil` ([#11807](https://github.com/blockscout/blockscout/issues/11807))
- Strict mode for timestamp to block number conversion ([#11633](https://github.com/blockscout/blockscout/issues/11633))
- Don't store ipfs gateway in metadata ([#11673](https://github.com/blockscout/blockscout/issues/11673))
- Use 0 as a default for v field in transactions ([#11800](https://github.com/blockscout/blockscout/issues/11800))
- Fix tests ([#11805](https://github.com/blockscout/blockscout/issues/11805))
- Use safe field access in CurrentTokenBalances.should_update?/2 ([#11804](https://github.com/blockscout/blockscout/issues/11804))
- Run Neon tests on neon chain type only ([#11802](https://github.com/blockscout/blockscout/issues/11802))
- Sanitize addresses of smart contracts having `verified` set to `false`  ([#11727](https://github.com/blockscout/blockscout/issues/11727))
- Celestia info parsing ([#11678](https://github.com/blockscout/blockscout/issues/11678))
- `EIP1559ConfigUpdate` and `Indexer.Block.Realtime.Fetcher` fetchers were unstable for L2 reorgs, `brotli` lib was replaced ([#11714](https://github.com/blockscout/blockscout/issues/11714))
- Add traceable blocks filtering to contract code fetcher ([#11700](https://github.com/blockscout/blockscout/issues/11700))
- Improve token metadata update process ([#11710](https://github.com/blockscout/blockscout/issues/11710))
- Add typeless handler for call_tracer ([#11766](https://github.com/blockscout/blockscout/issues/11766))
- Add consensus filter to reindex internal transactions migration ([#11732](https://github.com/blockscout/blockscout/issues/11732))
- Add error handling to chunked json rpc decode json ([#11734](https://github.com/blockscout/blockscout/issues/11734))
- New methods submitting Arbitrum batches supported ([#11731](https://github.com/blockscout/blockscout/issues/11731))
- Don't fail on pending transactions in Explorer.Account.Notifier.Notify ([#11724](https://github.com/blockscout/blockscout/issues/11724))
- Add flat value to BoundInterval increase/decrease ([#11708](https://github.com/blockscout/blockscout/issues/11708))
- Add missing condition to reindex internal transactions migration ([#11709](https://github.com/blockscout/blockscout/issues/11709))
- Add 'yParity' alias ([#11642](https://github.com/blockscout/blockscout/issues/11642))
- Fix address coin balances transformer ([#11627](https://github.com/blockscout/blockscout/issues/11627))
- Improve session handling in account v2 ([#11420](https://github.com/blockscout/blockscout/issues/11420))
- Add /metrics handler for indexer mode ([#11672](https://github.com/blockscout/blockscout/issues/11672))
- Ease SQL query for EIP1559ConfigUpdate fetcher ([#11659](https://github.com/blockscout/blockscout/issues/11659))
- Fix enoent in Indexer.NFTMediaHandler.Queue ([#11653](https://github.com/blockscout/blockscout/issues/11653))
- Add function clause for wrong first trace result format ([#11655](https://github.com/blockscout/blockscout/issues/11655))
- Intercept error during DB drop ([#11618](https://github.com/blockscout/blockscout/issues/11618))
- Update EmptyBlocksSanitizer logic due to refetch_needed field ([#11660](https://github.com/blockscout/blockscout/issues/11660))

### 🚜 Refactor

- All env variables related to DB migration processes now have "MIGRATION_" prefix ([#11798](https://github.com/blockscout/blockscout/issues/11798))

### ⚡ Performance

- Smart contracts list query ([#11733](https://github.com/blockscout/blockscout/issues/11733))

### ⚙️ Miscellaneous Tasks

- Runtime variable to manage chain spec processing delay ([#11874](https://github.com/blockscout/blockscout/pull/11874))
- Replace composite id types usage ([#11861](https://github.com/blockscout/blockscout/pull/11861))
- Correct the docker compose command for running an external frontend in README.md ([#11838](https://github.com/blockscout/blockscout/pull/11838))
- Update link to the list of chains in README.md ([#11829](https://github.com/blockscout/blockscout/pull/11829))
- Create /api/v2/proxy/3dparty/ root path for 3dparty proxy API endpoints ([#11808](https://github.com/blockscout/blockscout/issues/11808))
- Mention WC Project ID in common-frontend.env ([#11799](https://github.com/blockscout/blockscout/issues/11799))
- Remove api v1 health endpoints ([#11573](https://github.com/blockscout/blockscout/issues/11573))
- Add env var for realtime fetcher polling period ([#11783](https://github.com/blockscout/blockscout/issues/11783))
- Refactor composite keys filtering ([#11473](https://github.com/blockscout/blockscout/issues/11473))
- Upsert token instances by batches ([#11685](https://github.com/blockscout/blockscout/issues/11685))
- Fix spelling in some modules ([#11791](https://github.com/blockscout/blockscout/issues/11791))
- Update Twitter URL to x.com format ([#11761](https://github.com/blockscout/blockscout/issues/11761))
- Reduce the number of queries for token type ([#11674](https://github.com/blockscout/blockscout/issues/11674))
- Increase verbosity of error logs in TokenInstanceMetadataRefetch ([#11758](https://github.com/blockscout/blockscout/issues/11758))
- Support snake case in ImportController ([#11501](https://github.com/blockscout/blockscout/issues/11501))
- Pass chain id to Transaction Interpretation service ([#11745](https://github.com/blockscout/blockscout/issues/11745))
- Deprecating of CHECKSUM_FUNCTION variable ([#10480](https://github.com/blockscout/blockscout/issues/10480))
- Arbitrum claiming enhancements ([#11552](https://github.com/blockscout/blockscout/issues/11552))
- Fix text in the template and update localization files ([#11715](https://github.com/blockscout/blockscout/issues/11715))
- Decrease catchup interval ([#11626](https://github.com/blockscout/blockscout/issues/11626))

### New ENV variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `INDEXER_DISABLE_TOKEN_INSTANCE_REFETCH_FETCHER`             | If `true`, the Token instance fetcher, which re-fetches NFT collections marked to refetch, doesn't run. Implemented in [#10263](https://github.com/blockscout/blockscout/pull/10263).                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | <p>Version: v7.0.0+<br>Default: <code>false</code><br>Applications: Indexer</p>                                      |
| `INDEXER_REALTIME_FETCHER_POLLING_PERIOD`                     | Period between polling the `latest` block in realtime fetcher. [Time format](backend-env-variables.md#time-format). Implemented in [#11783](https://github.com/blockscout/blockscout/pull/11783)                                                                                                                                                                                                                                                                                                                                                                                      | <p>Version: v7.0.0+<br>Default: (empty)<br>Applications: Indexer</p>                                                  |
| `MIGRATION_SHRINK_INTERNAL_TRANSACTIONS_BATCH_SIZE`               | Batch size of the shrink internal transactions migration. _Note_: before release "v6.8.0", the default value was 1000. Implemented in [#10567](https://github.com/blockscout/blockscout/pull/10567), changed default value in [#10689](https://github.com/blockscout/blockscout/pull/10689). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                       | <p>Version: v7.0.0+<br>Default: 100<br>Applications: API, Indexer</p>                                                                                                      |
| `MIGRATION_SHRINK_INTERNAL_TRANSACTIONS_CONCURRENCY`              | Concurrency of the shrink internal transactions migration. Implemented in [#10567](https://github.com/blockscout/blockscout/pull/10567). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                                                                                                                                                                           | <p>Version: v7.0.0+<br>Default: 10<br>Applications: API, Indexer</p>                                                                                                       |
| `MIGRATION_TOKEN_INSTANCE_OWNER_CONCURRENCY`            | Concurrency of new fields backfiller implemented in [#8386](https://github.com/blockscout/blockscout/pull/8386). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                                                                                                                                                                                                    | <p>Version: v7.0.0+<br>Default: <code>5</code><br>Applications: API, Indexer</p>                                                                                           |
| `MIGRATION_TOKEN_INSTANCE_OWNER_BATCH_SIZE`             | Batch size of new fields backfiller implemented in [#8386](https://github.com/blockscout/blockscout/pull/8386). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                                                                                                                                                                                                     | <p>Version: v7.0.0+<br>Default: <code>50</code><br>Applications: API, Indexer</p>                                                                                          |
| `MIGRATION_TOKEN_INSTANCE_OWNER_ENABLED`                | Enable of backfiller from [#8386](https://github.com/blockscout/blockscout/pull/8386) implemented in [#8752](https://github.com/blockscout/blockscout/pull/8752). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                                                                                                                                                   | <p>Version: v7.0.0+<br>Default: <code>false</code><br>Applications: API, Indexer</p>                                                                                       |
| `MIGRATION_TRANSACTIONS_TABLE_DENORMALIZATION_BATCH_SIZE`                       | Number of transactions to denormalize (add block timestamp and consensus) in the batch. Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                        | <p>Version: v7.0.0+<br>Default: <code>500</code><br>Applications: API, Indexer</p> |
| `MIGRATION_TRANSACTIONS_TABLE_DENORMALIZATION_CONCURRENCY`                      | Number of parallel denormalization transaction batches processing. Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                            | <p>Version: v7.0.0+<br>Default: <code>10</code><br>Applications: API, Indexer</p>  |
| `MIGRATION_TOKEN_TRANSFER_TOKEN_TYPE_BATCH_SIZE`             | Number of token transfers to denormalize (add token\_type) in the batch. Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                       | <p>Version: v7.0.0+<br>Default: <code>100</code><br>Applications: API, Indexer</p>     |
| `MIGRATION_TOKEN_TRANSFER_TOKEN_TYPE_CONCURRENCY`            | Number of parallel denormalization token transfer batches processing. Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                          | <p>Version: v7.0.0+<br>Default: <code>1</code><br>Applications: API, Indexer</p>       |
| `MIGRATION_SANITIZE_INCORRECT_NFT_BATCH_SIZE`                          | Number of token transfers to sanitize in the batch. Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                            | <p>Version: v7.0.0+<br>Default: <code>100</code><br>Applications: API, Indexer</p>     |
| `MIGRATION_SANITIZE_INCORRECT_NFT_CONCURRENCY`                         | Number of parallel sanitizing token transfer batches processing. Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                               | <p>Version: v7.0.0+<br>Default: <code>1</code><br>Applications: API, Indexer</p>       |
| `MIGRATION_SANITIZE_INCORRECT_NFT_TIMEOUT`                             | Timeout between sanitizing token transfer batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                     | <p>Version: v7.0.0+<br>Default: <code>0</code><br>Applications: API, Indexer</p>      |
| `MIGRATION_SANITIZE_INCORRECT_WETH_BATCH_SIZE`                         | Number of token transfers to sanitize in the batch. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                               | <p>Version: v7.0.0+<br>Default: <code>100</code><br>Applications: API, Indexer</p>     |
| `MIGRATION_SANITIZE_INCORRECT_WETH_CONCURRENCY`                        | Number of parallel sanitizing token transfer batches processing. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                  | <p>Version: v7.0.0+<br>Default: <code>1</code><br>Applications: API, Indexer</p>       |
| `MIGRATION_SANITIZE_INCORRECT_WETH_TIMEOUT`                            | Timeout between sanitizing token transfer batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                     | <p>Version: v7.0.0+<br>Default: <code>0</code><br>Applications: API, Indexer</p>      |
| `MIGRATION_REINDEX_INTERNAL_TRANSACTIONS_STATUS_BATCH_SIZE`            | Number of internal transactions to reindex in the batch. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                          | <p>Version: v7.0.0+<br>Default: <code>100</code><br>Applications: API, Indexer</p>    |
| `MIGRATION_REINDEX_INTERNAL_TRANSACTIONS_STATUS_CONCURRENCY`           | Number of parallel reindexing internal transaction batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                            | <p>Version: v7.0.0+<br>Default: <code>1</code><br>Applications: API, Indexer</p>      |
| `MIGRATION_REINDEX_INTERNAL_TRANSACTIONS_STATUS_TIMEOUT`               | Timeout between reindexing internal transaction batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358). Renamed in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                               | <p>Version: v7.0.0+<br>Default: <code>0</code><br>Applications: API, Indexer</p>      |
| `MIGRATION_SANITIZE_VERIFIED_ADDRESSES_DISABLED`              | Concurrency of the sanitize verified addresses migration. Implemented in [#11727](https://github.com/blockscout/blockscout/pull/11727).                                                                                                                                                                                                                                                                                                           | <p>Version: v7.0.0+<br>Default: <code>false</code><br>Applications: API, Indexer</p>                                                                                                       |
| `MIGRATION_SANITIZE_VERIFIED_ADDRESSES_BATCH_SIZE`              | Concurrency of the sanitize verified addresses migration. Implemented in [#11727](https://github.com/blockscout/blockscout/pull/11727).                                                                                                                                                                                                                                                                                                           | <p>Version: v7.0.0+<br>Default: 500<br>Applications: API, Indexer</p>                                                                                                       |
| `MIGRATION_SANITIZE_VERIFIED_ADDRESSES_CONCURRENCY`              | Concurrency of the sanitize verified addresses migration. Implemented in [#11727](https://github.com/blockscout/blockscout/pull/11727).                                                                                                                                                                                                                                                                                                           | <p>Version: v7.0.0+<br>Default: 1<br>Applications: API, Indexer</p>                                                                                                       |
| `MIGRATION_SANITIZE_VERIFIED_ADDRESSES_TIMEOUT`              | Timeout between batches processing in sanitize verified addresses migration. [Time format](backend-env-variables.md#time-format). Implemented in [#11727](https://github.com/blockscout/blockscout/pull/11727).                                                                                                                                                                                                                                                                                                           | <p>Version: v7.0.0+<br>Default: <code>0s</code><br>Applications: API, Indexer</p>                                                                                                       |
| `MIGRATION_HEAVY_INDEX_OPERATIONS_CHECK_INTERVAL`               | Interval between status checks of heavy db operation like index creation or dropping. [Time format](backend-env-variables.md#time-format). Implemented in [#11604](https://github.com/blockscout/blockscout/pull/11604)                                                                                  | <p>Version: v7.0.0+<br>Default: <code>10m</code><br>Applications: API, Indexer</p>       |
| `MIGRATION_TOKEN_INSTANCE_ERC_1155_SANITIZE_CONCURRENCY`     | Concurrency for `erc-1155-sanitize` token instance fetcher. Implemented in [#9226](https://github.com/blockscout/blockscout/pull/9226). Default value and name changed in [#11543](https://github.com/blockscout/blockscout/pull/11543) | <p>Version: v7.0.0+<br>Default: <code>1</code><br>Applications: Indexer</p>             |
| `MIGRATION_TOKEN_INSTANCE_ERC_721_SANITIZE_CONCURRENCY`      | Concurrency for `erc-721-sanitize` token instance fetcher. Implemented in [#9226](https://github.com/blockscout/blockscout/pull/9226). Name changed in [#11543](https://github.com/blockscout/blockscout/pull/11543)                    | <p>Version: v7.0.0+<br>Default: <code>2</code><br>Applications: Indexer</p>             |
| `MIGRATION_TOKEN_INSTANCE_ERC_1155_SANITIZE_BATCH_SIZE`      | Batch size for `erc-1155-sanitize` token instance fetcher. Implemented in [#9226](https://github.com/blockscout/blockscout/pull/9226). Default value and name changed in [#11543](https://github.com/blockscout/blockscout/pull/11543)  | <p>Version: v7.0.0+<br>Default: <code>500</code><br>Applications: Indexer</p>           |
| `MIGRATION_TOKEN_INSTANCE_ERC_721_SANITIZE_BATCH_SIZE`       | Batch size for `erc-721-sanitize` token instance fetcher. Implemented in [#9226](https://github.com/blockscout/blockscout/pull/9226). Default value and name changed in [#11543](https://github.com/blockscout/blockscout/pull/11543)   | <p>Version: v7.0.0+<br>Default: <code>50</code><br>Applications: Indexer</p>            |
| `MIGRATION_TOKEN_INSTANCE_ERC_721_SANITIZE_TOKENS_BATCH_SIZE`| Tokens batch size for `erc-721-sanitize` token instance fetcher. Implemented in [#9226](https://github.com/blockscout/blockscout/pull/9226). Name changed in [#11543](https://github.com/blockscout/blockscout/pull/11543)              | <p>Version: v7.0.0+<br>Default: <code>100</code><br>Applications: Indexer</p>          |
| `CONTRACT_ENABLE_PARTIAL_REVERIFICATION`               | Toggle for enabling re-verification from partial to partial match. Implemented in [#11737](https://github.com/blockscout/blockscout/pull/11737)                                                                                                  | <p>Version: v7.0.0+<br>Default: <code>false</code><br>Applications: API</p>                                                                                                               |
| `INDEXER_ARBITRUM_DATA_BACKFILL_ENABLED`                          | Enables a process to backfill the blocks and transaction with Arbitrum specific data. This should only be enabled for Arbitrum chains where blocks were indexed before upgrading to a version that includes Arbitrum-specific data indexing features. Implemented in [#11163](https://github.com/blockscout/blockscout/pull/11163).                                                                            | <p>Version: v7.0.0+<br>Default: <code>false</code><br>Applications: Indexer</p>                                       |
| `INDEXER_ARBITRUM_DATA_BACKFILL_UNINDEXED_BLOCKS_RECHECK_INTERVAL` | The number of L2 blocks to look back in one iteration of the backfill process. Implemented in [#11163](https://github.com/blockscout/blockscout/pull/11163).                                                                                                                                                                                                                                                  | <p>Version: v7.0.0+<br>Default: <code>120s</code><br>Applications: Indexer</p>                                        |
| `INDEXER_ARBITRUM_DATA_BACKFILL_BLOCKS_DEPTH`                     | Interval to retry the backfill task for unindexed blocks. Implemented in [#11163](https://github.com/blockscout/blockscout/pull/11163).                                                                                                                                                                                                                                                                        | <p>Version: v7.0.0+<br>Default: <code>500</code><br>Applications: Indexer</p>                                          |
| `MIGRATION_ARBITRUM_DA_RECORDS_NORMALIZATION_BATCH_SIZE`  | Specifies the number of address records processed per batch during normalization of batch-to-blob associations by moving them from arbitrum_da_multi_purpose to a dedicated arbitrum_batches_to_da_blobs table. Implemented in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                           | <p>Version: v7.0.0+<br>Default: <code>500</code><br>Applications: Indexer</p>                               |
| `MIGRATION_ARBITRUM_DA_RECORDS_NORMALIZATION_CONCURRENCY` | Specifies the number of concurrent processes used during normalization of batch-to-blob associations by moving them from arbitrum_da_multi_purpose to a dedicated arbitrum_batches_to_da_blobs table. Implemented in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                     | <p>Version: v7.0.0+<br>Default: <code>1</code><br>Applications: Indexer</p>                                 |
| `FILFOX_API_BASE_URL`                                        | [Filfox API](https://filfox.info/api/v1/docs/static/index.html) base URL. Implemented in [#11412](https://github.com/blockscout/blockscout/pull/11412).                                                                                                                                                                                                        | <p>Version: v7.0.0+<br>Default: <code>https://filfox.info/api/v1</code><br>Applications: Indexer</p> |
| `MIGRATION_FILECOIN_PENDING_ADDRESS_OPERATIONS_BATCH_SIZE`  | Specifies the number of address records processed per batch during the backfill of pending address fetch operations. Implemented in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                           | <p>Version: v7.0.0+<br>Default: <code>100</code><br>Applications: Indexer</p>                               |
| `MIGRATION_FILECOIN_PENDING_ADDRESS_OPERATIONS_CONCURRENCY` | Specifies the number of concurrent processes used during the backfill of pending address fetch operations. Implemented in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                     | <p>Version: v7.0.0+<br>Default: <code>1</code><br>Applications: Indexer</p>                                 |
| `MICROSERVICE_METADATA_PROXY_REQUESTS_TIMEOUT` | Timeout for request forwarding from `/api/v2/proxy/metadata/`. Implemented in [#11656](https://github.com/blockscout/blockscout/pull/11656) | <p>Version: v7.0.0+<br>Default: <code>30s</code><br>Applications: API</p> |
| `CHAIN_SPEC_PROCESSING_DELAY`                           | Chain specification path processing delay. [Time format](backend-env-variables.md#time-format). Implemented in [#11874](https://github.com/blockscout/blockscout/pull/11874).                                                                                                                                                                                                                           | <p>Version: v7.0.0+<br>Default: 15s<br>Applications: API, Indexer</p>                                                                                                  |

### Deprecated ENV variables

| Variable                                              | Required | Description                                                                                                                                                                                                                                                                                                                                        | Default                                                                                       | Version  | Need recompile | Deprecated in Version |
| ----------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------- | -------------- | --------------------- |
| `CHECKSUM_FUNCTION`   | | Defines checksum address function. 2 available values: `rsk`, `eth` | `eth`                                                                                       | v2.0.1+  |                | v7.0.0                |
| `TOKEN_ID_MIGRATION_FIRST_BLOCK`                        | | Bottom block for token id migration. Implemented in [#6391](https://github.com/blockscout/blockscout/pull/6391)                                                                                                                                                                                                                                                                                                                                    | 0       | v5.0.0+ | | v7.0.0
| `TOKEN_ID_MIGRATION_CONCURRENCY`                        | | Number of workers performing the token id migration. Implemented in [#6391](https://github.com/blockscout/blockscout/pull/6391)                                                                                                                                                                                                                                                                                                                    | 1     | v5.0.0+ | | v7.0.0
| `TOKEN_ID_MIGRATION_BATCH_SIZE`                         | | Interval of token transfer block numbers processed by a token id migration worker at a time. Implemented in [#6391](https://github.com/blockscout/blockscout/pull/6391)                                                                                                                                                                                                                                                                            | 500   | v5.0.0+ | | v7.0.0
| `SHRINK_INTERNAL_TRANSACTIONS_BATCH_SIZE`               | | Batch size of the shrink internal transactions migration. _Note_: before release "v6.8.0", the default value was 1000. Implemented in [#10567](https://github.com/blockscout/blockscout/pull/10567), changed default value in [#10689](https://github.com/blockscout/blockscout/pull/10689).                                                                                                                                                       | 100  | v6.8.0+ | | v7.0.0
| `SHRINK_INTERNAL_TRANSACTIONS_CONCURRENCY`              | | Concurrency of the shrink internal transactions migration. Implemented in [#10567](https://github.com/blockscout/blockscout/pull/10567).                                                                                                                                                                                                                                                                                                           | 10       | v6.8.0+ | | v7.0.0
| `TOKEN_INSTANCE_OWNER_MIGRATION_CONCURRENCY`            | | Concurrency of new fields backfiller implemented in [#8386](https://github.com/blockscout/blockscout/pull/8386)                                                                                                                                                                                                                                                                                                                                    | 5    | v5.3.0+ | | v7.0.0
| `TOKEN_INSTANCE_OWNER_MIGRATION_BATCH_SIZE`             | | Batch size of new fields backfiller implemented in [#8386](https://github.com/blockscout/blockscout/pull/8386)                                                                                                                                                                                                                                                                                                                                     | 50      | v5.3.0+ | | v7.0.0
| `TOKEN_INSTANCE_OWNER_MIGRATION_ENABLED`                | | Enable of backfiller from [#8386](https://github.com/blockscout/blockscout/pull/8386) implemented in [#8752](https://github.com/blockscout/blockscout/pull/8752)                                                                                                                                                                                                                                                                                   | false      | v5.3.2+ | | v7.0.0
| `DENORMALIZATION_MIGRATION_BATCH_SIZE`                       | | Number of transactions to denormalize (add block timestamp and consensus) in the batch.                                                                                                                        | 500 | v6.0.0+ | | v7.0.0
| `DENORMALIZATION_MIGRATION_CONCURRENCY`                      | | Number of parallel denormalization transaction batches processing.                                                                                                                                             | 10  | v6.0.0+ | | v7.0.0
| `TOKEN_TRANSFER_TOKEN_TYPE_MIGRATION_BATCH_SIZE`             | | Number of token transfers to denormalize (add token\_type) in the batch.                                                                                                                                       | 100     | v6.3.0+ | | v7.0.0
| `TOKEN_TRANSFER_TOKEN_TYPE_MIGRATION_CONCURRENCY`            | | Number of parallel denormalization token transfer batches processing.                                                                                                                                          | 1       | v6.3.0+ | | v7.0.0
| `SANITIZE_INCORRECT_NFT_BATCH_SIZE`                          | | Number of token transfers to sanitize in the batch.                                                                                                                                                            | 100     | v6.3.0+ | | v7.0.0
| `SANITIZE_INCORRECT_NFT_CONCURRENCY`                         | | Number of parallel sanitizing token transfer batches processing.                                                                                                                                               | 1       | v6.3.0+ | | v7.0.0
| `SANITIZE_INCORRECT_NFT_TIMEOUT`                             | | Timeout between sanitizing token transfer batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                                     | 0      | v6.10.0+ | | v7.0.0
| `SANITIZE_INCORRECT_WETH_BATCH_SIZE`                         | | Number of token transfers to sanitize in the batch. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134)                                                                               | 100     | v6.8.0+ | | v7.0.0
| `SANITIZE_INCORRECT_WETH_CONCURRENCY`                        | | Number of parallel sanitizing token transfer batches processing. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134)                                                                  | 1       | v6.8.0+ | | v7.0.0
| `SANITIZE_INCORRECT_WETH_TIMEOUT`                            | | Timeout between sanitizing token transfer batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                                     | 0      | v6.10.0+ | | v7.0.0
| `REINDEX_INTERNAL_TRANSACTIONS_STATUS_BATCH_SIZE`            | | Number of internal transactions to reindex in the batch. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                                          | 100    | v6.10.0+ | | v7.0.0
| `REINDEX_INTERNAL_TRANSACTIONS_STATUS_CONCURRENCY`           | | Number of parallel reindexing internal transaction batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                            | 1      | v6.10.0+ | | v7.0.0
| `REINDEX_INTERNAL_TRANSACTIONS_STATUS_TIMEOUT`               | | Timeout between reindexing internal transaction batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                               | 0      | v6.10.0+ | | v7.0.0
| `FILECOIN_PENDING_ADDRESS_OPERATIONS_MIGRATION_BATCH_SIZE`  | | Specifies the number of address records processed per batch during the backfill of pending address fetch operations. Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468).                                                                                                                                           | 100                               | v6.9.0+ | | v7.0.0
| `FILECOIN_PENDING_ADDRESS_OPERATIONS_MIGRATION_CONCURRENCY` | | Specifies the number of concurrent processes used during the backfill of pending address fetch operations. Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468).                                                                                                                                                     | 1                                 | v6.9.0+ | | v7.0.0
| `ARBITRUM_DA_RECORDS_NORMALIZATION_MIGRATION_BATCH_SIZE`  | | Specifies the number of address records processed per batch during normalization of batch-to-blob associations by moving them from arbitrum_da_multi_purpose to a dedicated arbitrum_batches_to_da_blobs table. Implemented in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                           | 500                               | v6.10.1+ | | v7.0.0
| `ARBITRUM_DA_RECORDS_NORMALIZATION_MIGRATION_CONCURRENCY` | | Specifies the number of concurrent processes used during normalization of batch-to-blob associations by moving them from arbitrum_da_multi_purpose to a dedicated arbitrum_batches_to_da_blobs table. Implemented in [#11798](https://github.com/blockscout/blockscout/pull/11798).                                                                                                                                                     | 1                                 | v6.10.1+ | | v7.0.0


## 6.10.2

### ⚙️ Miscellaneous Tasks

- Add captcha to account wallet login as well ([#11682](https://github.com/blockscout/blockscout/issues/11682))

### New ENV Variables

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `RE_CAPTCHA_BYPASS_TOKEN` | Bypass token that allows to skip reCAPTCHA check. Implemented in [#11682](https://github.com/blockscout/blockscout/pull/11682) | <p>Version: v6.10.2+<br>Default: (empty)<br>Applications: API</p>

## 6.10.1

### 🚀 Features

- Support OP Holocene upgrade ([#11355](https://github.com/blockscout/blockscout/issues/11355))
- Add active DB connections metric ([#11321](https://github.com/blockscout/blockscout/issues/11321))
- Add protocol icon to the search result ([#11478](https://github.com/blockscout/blockscout/issues/11478))

### 🐛 Bug Fixes

- Remove unnecessary internal transactions preload ([#11643](https://github.com/blockscout/blockscout/issues/11643))
- Fix bug in Indexer.Fetcher.EmptyBlocksSanitizer module ([#11636](https://github.com/blockscout/blockscout/pull/11636))
- Multichain search: process address in chunks ([#11632](https://github.com/blockscout/blockscout/issues/11632))
- Fix transactions deadlock ([#11623](https://github.com/blockscout/blockscout/issues/11623))
- Fix tokens and transactions deadlocks ([#11620](https://github.com/blockscout/blockscout/issues/11620))
- Order address names to return the latest non-primary ([#11612](https://github.com/blockscout/blockscout/issues/11612))
- Rename tx_burnt_fee prop in API v2 endpoint ([#11563](https://github.com/blockscout/blockscout/issues/11563))
- Celo fee handler ([#11387](https://github.com/blockscout/blockscout/issues/11387))
- Fix addresses deadlock ([#11616](https://github.com/blockscout/blockscout/issues/11616))
- Besu raw trace ([#11413](https://github.com/blockscout/blockscout/issues/11413))
- Fix tokens deadlock ([#11603](https://github.com/blockscout/blockscout/issues/11603))
- Set timeout: :infinity for PendingTransactionsSanitizer delete ([#11600](https://github.com/blockscout/blockscout/issues/11600))
- Fixed Missing Closing Quotation Marks in sed Expressions Update version_bump.sh ([#11574](https://github.com/blockscout/blockscout/issues/11574))
- The same DA blobs for different Arbitrum batches ([#11485](https://github.com/blockscout/blockscout/issues/11485))
- Extended list of apps in the devcontainer helper script ([#11396](https://github.com/blockscout/blockscout/issues/11396))
- Fix MarketHistory test ([#11547](https://github.com/blockscout/blockscout/issues/11547))
- Advanced-filters csv format ([#11494](https://github.com/blockscout/blockscout/issues/11494))
- Fix verifyproxycontract endpoint ([#11523](https://github.com/blockscout/blockscout/issues/11523))
- Fix minor grammatical issue Update README.md ([#11544](https://github.com/blockscout/blockscout/issues/11544))

### 📚 Documentation

- Typo fix Update README.md ([#11595](https://github.com/blockscout/blockscout/issues/11595))
- Typo fix Update CODE_OF_CONDUCT.md ([#11572](https://github.com/blockscout/blockscout/issues/11572))
- Fix minor grammar and phrasing inconsistencies Update README.md ([#11548](https://github.com/blockscout/blockscout/issues/11548))
- Fixed incorrect usage of -d flag in stop containers command Update README.md ([#11522](https://github.com/blockscout/blockscout/issues/11522))

### ⚡ Performance

- Implement batched requests and DB upsert operations Indexer.Fetcher.EmptyBlocksSanitizer module ([#11555](https://github.com/blockscout/blockscout/issues/11555))

### ⚙️ Miscellaneous Tasks

- Remove unused Explorer.Token.InstanceOwnerReader module ([#11570](https://github.com/blockscout/blockscout/issues/11570))
- Optimize coin balances deriving ([#11613](https://github.com/blockscout/blockscout/issues/11613))
- Fix typo Update CHANGELOG.md ([#11607](https://github.com/blockscout/blockscout/issues/11607))
- Add env variable for PendingTransactionsSanitizer interval ([#11601](https://github.com/blockscout/blockscout/issues/11601))
- Documentation for Explorer.Chain.Transaction.History.Historian ([#11397](https://github.com/blockscout/blockscout/issues/11397))
- Extend error message on updating token balance with token id ([#11524](https://github.com/blockscout/blockscout/issues/11524))

### New ENV Variables

| Variable                                    | Description                                                                                                                                                                                                                                            | Parameters                                                                              |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| `INDEXER_PENDING_TRANSACTIONS_SANITIZER_INTERVAL`             | Interval between pending transactions sanitizing. Implemented in [#11601](https://github.com/blockscout/blockscout/pull/11601).                                                                                                                                                                                                                                                                                                                                                                                                  | <p>Version: v6.10.1<br>Default: <code>1h</code><br>Applications: Indexer</p>                                          |

## 6.10.0

### 🚀 Features

- Addresses blacklist support ([#11417](https://github.com/blockscout/blockscout/issues/11417))
- Multichain search DB filling ([#11139](https://github.com/blockscout/blockscout/issues/11139))
- Zilliqa scilla transactions and smart contracts ([#11069](https://github.com/blockscout/blockscout/issues/11069))
- CDN ([#10675](https://github.com/blockscout/blockscout/issues/10675))
- Arbitrum L2->L1 message claiming ([#10804](https://github.com/blockscout/blockscout/issues/10804))
- Add is_banned to token_instances table ([#11235](https://github.com/blockscout/blockscout/issues/11235))
- Add CSV export of epoch transactions for address ([#11195](https://github.com/blockscout/blockscout/issues/11195))
- Add request to /cache/{tx_hash} of transaction interpreter ([#11279](https://github.com/blockscout/blockscout/issues/11279))
- Switch DB requests from replica to master in case of replica inaccessibility ([#11020](https://github.com/blockscout/blockscout/issues/11020))
- Add gzip encoding option ([#11292](https://github.com/blockscout/blockscout/issues/11292))
- Add Stylus verification support ([#11183](https://github.com/blockscout/blockscout/issues/11183))
- Multiple json rpc urls ([#10934](https://github.com/blockscout/blockscout/issues/10934))
- Gas prices with base fee if no transactions ([#11132](https://github.com/blockscout/blockscout/issues/11132))
- Zilliqa consensus data related to block  ([#10699](https://github.com/blockscout/blockscout/issues/10699))
- Add filecoin robust addresses to proxy implementations ([#11102](https://github.com/blockscout/blockscout/issues/11102))

### 🐛 Bug Fixes

- Limit max decimals value ([#11493](https://github.com/blockscout/blockscout/issues/11493))
- Ignore unknown transaction receipt fields ([#11492](https://github.com/blockscout/blockscout/issues/11492))
- Fixed issue in db request (l2_to_l1_message_by_id/2) ([#11481](https://github.com/blockscout/blockscout/issues/11481))
- Handle float time in compose_gas_price/5 ([#11476](https://github.com/blockscout/blockscout/issues/11476))
- Fix 500 on disabled metadata service ([#11443](https://github.com/blockscout/blockscout/issues/11443))
- Fix get_media_url_from_metadata_for_nft_media_handler/1 ([#11437](https://github.com/blockscout/blockscout/issues/11437))
- Fix check-redirect for ENS ([#11435](https://github.com/blockscout/blockscout/issues/11435))
- Refactor CDN upload functions, prevent saving partially uploaded thumbnails ([#11400](https://github.com/blockscout/blockscout/issues/11400))
- Take into account several proofs in OP Withdrawals ([#11399](https://github.com/blockscout/blockscout/issues/11399))
- Handle "null" in paging options ([#11388](https://github.com/blockscout/blockscout/issues/11388))
- Fix search timeout ([#11277](https://github.com/blockscout/blockscout/issues/11277))
- Fix Noves.fi endpoints for bulk transactions ([#11375](https://github.com/blockscout/blockscout/issues/11375))
- Fix docker container build after adding NFT media handler ([#11373](https://github.com/blockscout/blockscout/issues/11373))
- Handle simultaneous account entities creation ([#11341](https://github.com/blockscout/blockscout/issues/11341))
- Websocket configuration ([#11357](https://github.com/blockscout/blockscout/issues/11357))
- 403 instead of 404 on wrong captcha in api/v1 ([#11348](https://github.com/blockscout/blockscout/issues/11348))
- Upgrade fallback urls propagation ([#11331](https://github.com/blockscout/blockscout/issues/11331))
- Add utils to dockerfile ([#11345](https://github.com/blockscout/blockscout/issues/11345))
- Fix log decoding bug ([#11266](https://github.com/blockscout/blockscout/issues/11266))
- Return 404 instead of 200 for nonexistent NFT ([#11280](https://github.com/blockscout/blockscout/issues/11280))
- Fix metrics modules warnings ([#11340](https://github.com/blockscout/blockscout/issues/11340))
- Handle entries with not specified `retries_count` ([#11206](https://github.com/blockscout/blockscout/issues/11206))
- Get rid of scientific notation in CSV token holders export ([#11281](https://github.com/blockscout/blockscout/issues/11281))
- Wrong usage of env in TokenInstanceMetadataRefetch ([#11317](https://github.com/blockscout/blockscout/issues/11317))
- Rework initialization of the `RollupL1ReorgMonitor` and fix `read_system_config` for fallback cases ([#11275](https://github.com/blockscout/blockscout/issues/11275))
- Eth_getLogs paging ([#11248](https://github.com/blockscout/blockscout/issues/11248))
- Handle excessive otp confirmations ([#11244](https://github.com/blockscout/blockscout/issues/11244))
- Check if flash is fetched before getting it in app.html ([#11270](https://github.com/blockscout/blockscout/issues/11270))
- Multiple json rpc urls fixes ([#11264](https://github.com/blockscout/blockscout/issues/11264))
- Handle eth rpc request without params ([#11269](https://github.com/blockscout/blockscout/issues/11269))
- Fixate 6.9.2 as the latest release ([#11265](https://github.com/blockscout/blockscout/issues/11265))
- Fix ETH JSON RPC deriving for Stylus verification ([#11247](https://github.com/blockscout/blockscout/issues/11247))
- Fix fake json_rpc_named_arguments for multiple urls usage ([#11243](https://github.com/blockscout/blockscout/issues/11243))
- Handle simultaneous api key creation ([#11233](https://github.com/blockscout/blockscout/issues/11233))
- Fixate 6.9.1 as the latest release in master branch
- Invalid metadata requests ([#11210](https://github.com/blockscout/blockscout/issues/11210))
- *(nginx-conf)* Redirect `/api-docs` to frontend. ([#11202](https://github.com/blockscout/blockscout/issues/11202))
- Fix failed filecoin tests ([#11187](https://github.com/blockscout/blockscout/issues/11187))
- Fix missing `signers` field in nested quorum certificate ([#11185](https://github.com/blockscout/blockscout/issues/11185))
- Return `l1_tx_hashes` in the response of /batches/da/celestia/... API endpoint ([#11184](https://github.com/blockscout/blockscout/issues/11184))
- Omit pbo for blocks lower than trace first block for indexing status ([#11053](https://github.com/blockscout/blockscout/issues/11053))
- Update overview.html.eex ([#11094](https://github.com/blockscout/blockscout/issues/11094))
- Fix sitemap timeout; optimize OrderedCache preloads ([#11131](https://github.com/blockscout/blockscout/issues/11131))

### 🚜 Refactor

- Cspell configuration ([#11146](https://github.com/blockscout/blockscout/issues/11146))

### ⚡ Performance

- Advanced filters optimization ([#11186](https://github.com/blockscout/blockscout/issues/11186))

### ⚙️ Miscellaneous Tasks

- Return old response format in /api/v1/health endpoint ([#11511](https://github.com/blockscout/blockscout/issues/11511))
- Rename blob_tx_count per naming conventions ([#11438](https://github.com/blockscout/blockscout/issues/11438))
- Follow updated response schema in interpreter microservice ([#11402](https://github.com/blockscout/blockscout/issues/11402))
- Remove raise in case if ETHEREUM_JSONRPC_HTTP_URL is not provided ([#11392](https://github.com/blockscout/blockscout/issues/11392))
- Optimize tokens import ([#11389](https://github.com/blockscout/blockscout/issues/11389))
- Remove beta suffix from releases ([#11376](https://github.com/blockscout/blockscout/issues/11376))
- Background migrations timeout ([#11358](https://github.com/blockscout/blockscout/issues/11358))
- Remove obsolete compile-time vars ([#11336](https://github.com/blockscout/blockscout/issues/11336))
- Fixate Postgres 17 version in Docker compose and Github Actions workflows ([#11334](https://github.com/blockscout/blockscout/issues/11334))
- Remove shorthands-duplicates from API responses ([#11319](https://github.com/blockscout/blockscout/issues/11319))
- Refactor compile time envs usage ([#11148](https://github.com/blockscout/blockscout/issues/11148))
- Refactor Dockerfile ([#11130](https://github.com/blockscout/blockscout/issues/11130))
- Refactor import stages ([#11013](https://github.com/blockscout/blockscout/issues/11013))
- Optimize CurrentTokenBalances import runner ([#11191](https://github.com/blockscout/blockscout/issues/11191))
- Fix watchlist address flaking test ([#11242](https://github.com/blockscout/blockscout/issues/11242))
- OP modules improvements ([#11073](https://github.com/blockscout/blockscout/issues/11073))
- Invalid association `token_transfers` ([#11204](https://github.com/blockscout/blockscout/issues/11204))
- Update Github Actions packages versions ([#11144](https://github.com/blockscout/blockscout/issues/11144))
- Convenient way to manage known_hosts within devcontainer ([#11091](https://github.com/blockscout/blockscout/issues/11091))
- Add docker compose file without microservices ([#11097](https://github.com/blockscout/blockscout/issues/11097))

### New ENV Variables

| Variable                                    | Description                                                                                                                                                                                                                                            | Parameters                                                                              |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| `ETHEREUM_JSONRPC_HTTP_URLS`                            | Analogue of `ETHEREUM_JSONRPC_HTTP_URL` for multiple values. Implemented in [#10934](https://github.com/blockscout/blockscout/pull/10934)                                                                                                                                                                                                                                                                                                          | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                                                   |
| `ETHEREUM_JSONRPC_FALLBACK_HTTP_URLS`                   | Analogue of `ETHEREUM_JSONRPC_FALLBACK_HTTP_URL` for multiple values. Implemented in [#10934](https://github.com/blockscout/blockscout/pull/10934)                                                                                                                                                                                                                                                                                                                                             | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                                                                                  |
| `ETHEREUM_JSONRPC_TRACE_URLS`                           | Analogue of `ETHEREUM_JSONRPC_TRACE_URL` for multiple values. Implemented in [#10934](https://github.com/blockscout/blockscout/pull/10934)                                                                                                                                                                                                                                                                        | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                                                                  |
| `ETHEREUM_JSONRPC_FALLBACK_TRACE_URLS`                  | Analogue of `ETHEREUM_JSONRPC_FALLBACK_TRACE_URL` for multiple values. Implemented in [#10934](https://github.com/blockscout/blockscout/pull/10934)                                                                                                                                                                                                                                                                                                                                            | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                                                                                  |
| `ETHEREUM_JSONRPC_ETH_CALL_URLS`                        | Analogue of `ETHEREUM_JSONRPC_ETH_CALL_URL` for multiple values. Implemented in [#10934](https://github.com/blockscout/blockscout/pull/10934)                                                                                                                                                                                                                                                                                                                                     | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                                                                                  |
| `ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URLS`               | Analogue of `ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URL` for multiple values. Implemented in [#10934](https://github.com/blockscout/blockscout/pull/10934)                                                                                                                                                                                                                                                                                                                                       | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                                                                                  |
| `ETHEREUM_JSONRPC_HTTP_GZIP_ENABLED`              | If `true`, then send gzip encoding header and expect encoding in response. Implemented in [#11292](https://github.com/blockscout/blockscout/pull/11292).                                                                                                                                                                                                                                                                                                           | <p>Version: v6.10.0+<br>Default: <code>false</code><br>Applications: API, Indexer</p>                                                                                                       |
| `REPLICA_MAX_LAG`                                       | Defines the max lag for read-only replica. If the actual lag is higher than this, replica is considered unavailable and all requests to it are redirected to main DB. Implemented in [#11020](https://github.com/blockscout/blockscout/pull/11020)                                                                                                                                                                                                 | <p>Version: v6.10.0+<br>Default: 5m<br>Applications: API</p>                                                                                                                 |
| `SANITIZE_INCORRECT_NFT_TIMEOUT`                             | Timeout between sanitizing token transfer batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                                     | <p>Version: v6.10.0+<br>Default: <code>0</code><br>Applications: API, Indexer</p>        |
| `SANITIZE_INCORRECT_WETH_TIMEOUT`                            | Timeout between sanitizing token transfer batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                                     | <p>Version: v6.10.0+<br>Default: <code>0</code><br>Applications: API, Indexer</p>        |
| `REINDEX_INTERNAL_TRANSACTIONS_STATUS_BATCH_SIZE`            | Number of internal transactions to reindex in the batch. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                                          | <p>Version: v6.10.0+<br>Default: <code>100</code><br>Applications: API, Indexer</p>      |
| `REINDEX_INTERNAL_TRANSACTIONS_STATUS_CONCURRENCY`           | Number of parallel reindexing internal transaction batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                            | <p>Version: v6.10.0+<br>Default: <code>1</code><br>Applications: API, Indexer</p>        |
| `REINDEX_INTERNAL_TRANSACTIONS_STATUS_TIMEOUT`               | Timeout between reindexing internal transaction batches processing. Implemented in [#11358](https://github.com/blockscout/blockscout/pull/11358)                                                               | <p>Version: v6.10.0+<br>Default: <code>0</code><br>Applications: API, Indexer</p>        |
| `NFT_MEDIA_HANDLER_AWS_ACCESS_KEY_ID`                     | S3 API Access Key ID                                                                                                                                                                                                             | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: NFT_MEDIA_HANDLER</p> |
| `NFT_MEDIA_HANDLER_AWS_SECRET_ACCESS_KEY`                 | S3 API Secret Access Key                                                                                                                                                                                                         | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: NFT_MEDIA_HANDLER</p> |
| `NFT_MEDIA_HANDLER_AWS_BUCKET_HOST`                       | S3 API URL                                                                                                                                                                                                                       | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: NFT_MEDIA_HANDLER</p> |
| `NFT_MEDIA_HANDLER_AWS_BUCKET_NAME`                       | S3 bucket name                                                                                                                                                                                                                   | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: NFT_MEDIA_HANDLER</p> |
| `NFT_MEDIA_HANDLER_AWS_PUBLIC_BUCKET_URL`                 | Public S3 bucket URL                                                                                                                                                                                                             | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API</p>               |
| `NFT_MEDIA_HANDLER_ENABLED`                               | if `true`, CDN feature enabled                                                                                                                                                                                                   | <p>Version: v6.10.0+<br>Default: <code>false</code><br>Applications: Indexer, NFT_MEDIA_HANDLER</p>    |
| `NFT_MEDIA_HANDLER_REMOTE_DISPATCHER_NODE_MODE_ENABLED`   | if `true`, nft media handler is supposed to run separately.                                                                                                                                                                      | <p>Version: v6.10.0+<br>Default: <code>false</code><br>Applications: Indexer, NFT_MEDIA_HANDLER</p>    |
| `NFT_MEDIA_HANDLER_IS_WORKER`                             | if `true`, and `NFT_MEDIA_HANDLER_REMOTE_DISPATCHER_NODE_MODE_ENABLED=true` will be started only nft_media_handler app                                                                                                           | <p>Version: v6.10.0+<br>Default: <code>false</code><br>Applications: Indexer, NFT_MEDIA_HANDLER</p>    |
| `NFT_MEDIA_HANDLER_NODES_MAP`                             | String in json map format, where key is erlang node and value is folder in R2/S3 bucket, example: `"{\"producer@172.18.0.4\": \"/folder_1\"}"`. If nft_media_handler runs in one pod with indexer, map should contain `self` key | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: NFT_MEDIA_HANDLER</p>               |
| `NFT_MEDIA_HANDLER_WORKER_CONCURRENCY`                    | Concurrency of media handling (resizing/uploading)                                                                                                                                                                               | <p>Version: v6.10.0+<br>Default: <code>10</code><br>Applications: NFT_MEDIA_HANDLER</p>       |
| `NFT_MEDIA_HANDLER_WORKER_BATCH_SIZE`                     | Number of url processed by one async task                                                                                                                                                                                        | <p>Version: v6.10.0+<br>Default: <code>10</code><br>Applications: NFT_MEDIA_HANDLER</p>       |
| `NFT_MEDIA_HANDLER_WORKER_SPAWN_TASKS_TIMEOUT`            | Timeout before spawn new task                                                                                                                                                                                                    | <p>Version: v6.10.0+<br>Default: <code>100ms</code><br>Applications: NFT_MEDIA_HANDLER</p>    |
| `NFT_MEDIA_HANDLER_BACKFILL_ENABLED`                      | If `true`, unprocessed token instances from DB will be processed via nft_media_handler                                                                                                                                           | <p>Version: v6.10.0+<br>Default: <code>false</code><br>Applications: Indexer</p>    |
| `NFT_MEDIA_HANDLER_BACKFILL_QUEUE_SIZE`                   | Max size of backfill queue                                                                                                                                                                                                       | <p>Version: v6.10.0+<br>Default: <code>1000</code><br>Applications: Indexer</p>     |
| `NFT_MEDIA_HANDLER_BACKFILL_ENQUEUE_BUSY_WAITING_TIMEOUT` | Timeout before new attempt to append item to backfill queue if it's full                                                                                                                                                         | <p>Version: v6.10.0+<br>Default: <code>1s</code><br>Applications: Indexer</p>       |
| `NFT_MEDIA_HANDLER_CACHE_UNIQUENESS_MAX_SIZE`             | Max size of cache, where stored already uploaded token instances media                                                                                                                                                           | <p>Version: v6.10.0+<br>Default: <code>100_000</code><br>Applications: Indexer</p>  |
| `ADDRESSES_BLACKLIST`                 | A comma-separated list of addresses to enable restricted access to them.                                                                                      | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API</p>               |
| `ADDRESSES_BLACKLIST_KEY`             | A key to access blacklisted addresses (either by `ADDRESSES_BLACKLIST` or by blacklist provider). Can be passed via query param to the page's URL: `?key=...` | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API</p>               |
| `ADDRESSES_BLACKLIST_PROVIDER`        | Blacklist provider type, available options: `blockaid`                                                                                                        | <p>Version: v6.10.0+<br>Default: <code>blockaid</code><br>Applications: API</p> |
| `ADDRESSES_BLACKLIST_URL`             | URL to fetch blacklist from                                                                                                                                   | <p>Version: v6.10.0+<br>Default: (empty)<br>Applications: API</p>               |
| `ADDRESSES_BLACKLIST_UPDATE_INTERVAL` | Interval between scheduled updates of blacklist                                                                                                               | <p>Version: v6.10.0+<br>Default: <code>15m</code><br>Applications: API</p>      |
| `ADDRESSES_BLACKLIST_RETRY_INTERVAL`  | Time to wait before new attempt of blacklist fetching, after abnormal termination of fetching task                                                            | <p>Version: v6.10.0+<br>Default: <code>5s</code><br>Applications: API</p>       |
| `MICROSERVICE_MULTICHAIN_SEARCH_URL`     | Multichain Search Service API URL. Integration is enabled, if this variable value contains valid URL. Implemented in [#11139](https://github.com/blockscout/blockscout/pull/11139)                                                                                                             | <p>Version: master<br>Default: (empty)<br>Applications: API, Indexer</p> |
| `MICROSERVICE_MULTICHAIN_SEARCH_API_KEY`     | Multichain Search Service API key. Implemented in [#11139](https://github.com/blockscout/blockscout/pull/11139)                                                                                                             | <p>Version: master<br>Default: (empty)<br>Applications: API, Indexer</p> |
| `MIGRATION_BACKFILL_MULTICHAIN_SEARCH_BATCH_SIZE`     | Batch size of backfilling Multichain Search Service DB. Implemented in [#11139](https://github.com/blockscout/blockscout/pull/11139)                                                                                                             | <p>Version: master<br>Default: (empty)<br>Applications: Indexer</p> |

### Deprecated ENV Variables


| Variable                                              | Required | Description                                                                                                                                                                                                                                                                                                                                        | Default                                                                                       | Version  | Need recompile | Deprecated in Version |
| ----------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------- | -------------- | --------------------- |
| `RESTRICTED_LIST`                                       |          | A comma-separated list of addresses to enable restricted access to them.                                                                                                                                                                                                                                                                                                                                                                        | (empty)                                                                            | v3.3.3+ |                | v6.10.0          |
| `RESTRICTED_LIST_KEY`                                   |          | A key to access addresses listed in`RESTRICTED_LIST` variable. Can be passed via query param to the page's URL: `?key=...`                                                                                                                                                                                                                                                                                                                      | (empty)                                                                            | v3.3.3+ |                | v6.10.0          |

## 6.9.2

### 🚀 Features

- Xname app proxy ([#11010](https://github.com/blockscout/blockscout/issues/11010))

| Variable              | Description                                                                                                                                                      | Parameters                                                                                      |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `XNAME_BASE_API_URL` | [Xname API](https://xname.app/) base URL. Implemented in [#11010](https://github.com/blockscout/blockscout/pull/11010). | <p>Version: v6.9.2+<br>Default: <code>https://gateway.xname.app</code><br>Applications: API</p> |
| `XNAME_API_TOKEN`    | [Xname API](https://xname.app/) token. Implemented in [#11010](https://github.com/blockscout/blockscout/pull/11010).    | <p>Version: v6.9.2+<br>Default: (empty)<br>Applications: API</p>

## 6.9.1

### 🐛 Bug Fixes

- Add `auth0-forwarded-for` header in auth0 ([#11178](https://github.com/blockscout/blockscout/issues/11178))

### ⚙️ Miscellaneous Tasks

- Extend recaptcha logging ([#11182](https://github.com/blockscout/blockscout/issues/11182))


| Variable                                    | Description                                                                                                                                                                                                                                            | Parameters                                                                              |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| `RE_CAPTCHA_SCORE_THRESHOLD`| Changes reCAPTCHA score threshold. Implemented in [#11182](https://github.com/blockscout/blockscout/pull/11182)                                                                                                   | <p>Version: v6.9.1+<br>Default: <code>0.5</code><br>Applications: API</p>    |

## 6.9.0

### 🚀 Features

- Support zksync foundry verification ([#11037](https://github.com/blockscout/blockscout/issues/11037))
- Address transactions block number sorting ([#11035](https://github.com/blockscout/blockscout/issues/11035))
- Scroll rollup: L1 fee parameters in API, `queueIndex` for L2 transactions, and L1 <->L2 messages ([#10484](https://github.com/blockscout/blockscout/issues/10484))
- Account V2 ([#10706](https://github.com/blockscout/blockscout/issues/10706))
- Allow to provide DB schema other than public ([#10946](https://github.com/blockscout/blockscout/issues/10946))
- Add missing filecoin robust addresses ([#10935](https://github.com/blockscout/blockscout/issues/10935))
- EIP-7702 support ([#10870](https://github.com/blockscout/blockscout/issues/10870))
- Open access to re-fetch metadata button for token instances without metadata initially fetched ([#10878](https://github.com/blockscout/blockscout/issues/10878))
- Support snake_case in metadata service ([#10722](https://github.com/blockscout/blockscout/issues/10722))
- Token transfers list API v2 endpoint ([#10801](https://github.com/blockscout/blockscout/issues/10801))
- Send archive balances requests to trace url ([#10820](https://github.com/blockscout/blockscout/issues/10820))
- Add metadata info to tx interpreter request ([#10823](https://github.com/blockscout/blockscout/issues/10823))
- Api for querying mud systems abi ([#10829](https://github.com/blockscout/blockscout/issues/10829))
- Arbitrum L1-to-L2 messages with hashed message id ([#10751](https://github.com/blockscout/blockscout/issues/10751))
- Support CoinMarketCap format in token supply stats ([#10853](https://github.com/blockscout/blockscout/issues/10853))
- Address scam badge flag ([#10763](https://github.com/blockscout/blockscout/issues/10763))
- Add verbosity to GraphQL token transfers query ([#10770](https://github.com/blockscout/blockscout/issues/10770))
- (celo) include token information in API response for address epoch rewards ([#10831](https://github.com/blockscout/blockscout/issues/10831))
- Add Blackfort validators ([#10744](https://github.com/blockscout/blockscout/issues/10744))
- Retry ERC-1155 token instance metadata fetch from baseURI + tokenID ([#10766](https://github.com/blockscout/blockscout/issues/10766))

### 🐛 Bug Fixes

- Fix tokennfttx API v1 endpoint ([#11083](https://github.com/blockscout/blockscout/issues/11083))
- Fix contract codes fetching for zksync chain type ([#11055](https://github.com/blockscout/blockscout/issues/11055))
- Filter non-traceable blocks before inserting them to internal txs fetcher queue ([#11074](https://github.com/blockscout/blockscout/issues/11074))
- Import blocks before coin balances ([#11049](https://github.com/blockscout/blockscout/issues/11049))
- Abi cache for non-proxied addresses ([#11065](https://github.com/blockscout/blockscout/issues/11065))
- Celo collated gas price issue ([#11067](https://github.com/blockscout/blockscout/issues/11067))
- Indexer memory limit for api instance ([#11066](https://github.com/blockscout/blockscout/issues/11066))
- Fix scam badge value in some API endpoints ([#11054](https://github.com/blockscout/blockscout/issues/11054))
- Divide by `10^decimals` when calculating token supply in CMC format ([#11036](https://github.com/blockscout/blockscout/issues/11036))
- Rename zksync l1/l2 _tx_count columns ([#11051](https://github.com/blockscout/blockscout/issues/11051))
- Bugs introduced in calldata decoding optimizations  ([#11025](https://github.com/blockscout/blockscout/issues/11025))
- Handle stalled async task in MapCache ([#11015](https://github.com/blockscout/blockscout/issues/11015))
- Add tx_count, tx_types props in the response of address API v2 endpoints for compatibility with current version of the frontend ([#11012](https://github.com/blockscout/blockscout/issues/11012))
- Chart API: add compatibility with the current frontend ([#11008](https://github.com/blockscout/blockscout/issues/11008))
- Fix failed tests ([#11000](https://github.com/blockscout/blockscout/issues/11000))
- Add compatibility with current frontend for some public props ([#10998](https://github.com/blockscout/blockscout/issues/10998))
- Process foreign key violation in scam addresses assigning functionality ([#10977](https://github.com/blockscout/blockscout/issues/10977))
- Handle import exceptions in MassiveBlocksFetcher ([#10993](https://github.com/blockscout/blockscout/issues/10993))
- Workaround for repeating logIndex ([#10880](https://github.com/blockscout/blockscout/issues/10880))
- Filter out nil implementations from combine_proxy_implementation_addresses_map function result ([#10943](https://github.com/blockscout/blockscout/issues/10943))
- Delete incorrect coin balances on reorg ([#10879](https://github.com/blockscout/blockscout/issues/10879))
- Handle delegatecall in state changes ([#10906](https://github.com/blockscout/blockscout/issues/10906))
- Fix env. variables link in README.md ([#10898](https://github.com/blockscout/blockscout/issues/10898))
- Add missing block timestamp in election rewards for address response ([#10907](https://github.com/blockscout/blockscout/issues/10907))
- Add missing build arg to celo workflow ([#10895](https://github.com/blockscout/blockscout/issues/10895))
- Do not include unrelated token transfers in `tokenTransferTxs` ([#10889](https://github.com/blockscout/blockscout/issues/10889))
- Fix get current user in app template ([#10844](https://github.com/blockscout/blockscout/issues/10844))
- Set `API_GRAPHQL_MAX_COMPLEXITY` in build action ([#10843](https://github.com/blockscout/blockscout/issues/10843))
- Disable archive balances only if latest block is available ([#10851](https://github.com/blockscout/blockscout/issues/10851))
- Dialyzer warning ([#10845](https://github.com/blockscout/blockscout/issues/10845))
- Decode revert reason by decoding candidates from the DB ([#10827](https://github.com/blockscout/blockscout/issues/10827))
- Filecoin stuck pending address operations ([#10832](https://github.com/blockscout/blockscout/issues/10832))
- Sanitize replaced transactions migration ([#10784](https://github.com/blockscout/blockscout/issues/10784))
- Repair /metrics endpoint ([#10813](https://github.com/blockscout/blockscout/issues/10813))
- Revert the deletion of deriving current token balances ([#10811](https://github.com/blockscout/blockscout/issues/10811))
- Clear null round blocks from missing block ranges ([#10805](https://github.com/blockscout/blockscout/issues/10805))
- Decode addresses as checksummed ([#10777](https://github.com/blockscout/blockscout/issues/10777))
- Preload additional sources for bytecode twin smart-contract ([#10692](https://github.com/blockscout/blockscout/issues/10692))
- Set min query length in the search API endpoints ([#10698](https://github.com/blockscout/blockscout/issues/10698))
- Proper handling of old batches on Arbitrum Nova ([#10786](https://github.com/blockscout/blockscout/issues/10786))
- Get rid of heavy DB query to start Arbitrum missed messages discovery process ([#10767](https://github.com/blockscout/blockscout/issues/10767))
- Revisited approach to choose L1 blocks to discover missing Arbitrum batches ([#10757](https://github.com/blockscout/blockscout/issues/10757))
- Fix account db repo definition ([#10714](https://github.com/blockscout/blockscout/issues/10714))
- Allow string IDs in JSON RPC requests ([#10759](https://github.com/blockscout/blockscout/issues/10759))
- Filter out tokens with skip_metadata: true from token fetcher ([#10736](https://github.com/blockscout/blockscout/issues/10736))

### 🚜 Refactor

- Fixate naming convention for "transaction" and "block number" entities ([#10913](https://github.com/blockscout/blockscout/issues/10913))
- Use middleware to check if GraphQL API is enabled ([#10772](https://github.com/blockscout/blockscout/issues/10772))

### ⚡ Performance

- Fix performance of Explorer.Counters.Transactions24hStats.consolidate/0 function ([#11082](https://github.com/blockscout/blockscout/issues/11082))
- Optimize advanced filters ([#10463](https://github.com/blockscout/blockscout/issues/10463))
- Refactor tx data decoding with fewer DB queries ([#10842](https://github.com/blockscout/blockscout/issues/10842))

### ⚙️ Miscellaneous Tasks

- Update version bump script
- Remove deprecated single implementation property of the smart-contract from the API response ([#10715](https://github.com/blockscout/blockscout/issues/10715))
- Set indexer memory limit based on system info as a fallback ([#10697](https://github.com/blockscout/blockscout/issues/10697))
- Set user agent to metadata requests ([#10834](https://github.com/blockscout/blockscout/issues/10834))
- Reverse internal transactions fetching order ([#10912](https://github.com/blockscout/blockscout/issues/10912))
- Remove unused fetch_and_lock_by_hashes/1 public function
- Add shrink int txs docker image build for Celo chain type ([#10894](https://github.com/blockscout/blockscout/issues/10894))
- Ability to work with Blockscout code base within a VSCode devcontainer ([#10838](https://github.com/blockscout/blockscout/issues/10838))
- Add version bump script ([#10871](https://github.com/blockscout/blockscout/issues/10871))
- Bump elixir to 1.17.3 and Erlang OTP to 27.1 ([#10284](https://github.com/blockscout/blockscout/issues/10284))
- Reindex incorrect internal transactions migration ([#10654](https://github.com/blockscout/blockscout/issues/10654))
- Remove old UI from base Docker image ([#10828](https://github.com/blockscout/blockscout/issues/10828))
- Add primary key to address_tags table ([#10818](https://github.com/blockscout/blockscout/issues/10818))
- Refactor OrderedCache preloads ([#10803](https://github.com/blockscout/blockscout/issues/10803))
- Support non-unique log index for rsk chain type ([#10807](https://github.com/blockscout/blockscout/issues/10807))
- Add missing symbols ([#10749](https://github.com/blockscout/blockscout/issues/10749))

### New ENV Variables

| Variable                                    | Description                                                                                                                                                                                                                                            | Parameters                                                                              |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| `INDEXER_SYSTEM_MEMORY_PERCENTAGE`                            | Percentage of total memory available to the VM that an application can use if `INDEXER_MEMORY_LIMIT` is not set. Implemented in [#10697](https://github.com/blockscout/blockscout/pull/10697).                                                                                                                                                                                                                                                                                                                                   | <p>Version: v6.9.0+<br>Default: <code>60</code><br>Applications: Indexer</p>                                          |
| `INDEXER_TOKEN_BALANCES_EXPONENTIAL_TIMEOUT_COEFF`            | Coefficient to calculate exponential timeout. Implemented in [#10694](https://github.com/blockscout/blockscout/pull/10694).                                                                                                                                                                                                                                                                                                                                                                                                      | <p>Version: v6.9.0+<br>Default: <code>100</code><br>Applications: Indexer</p>                                         |
| `INDEXER_INTERNAL_TRANSACTIONS_FETCH_ORDER`                   | Order of fetching internal transactions from node. Possible values: `asc`, `desc`. Implemented in [#10912](https://github.com/blockscout/blockscout/pull/10912)                                                                                                                                                                                                                                                                                                                                                                  | <p>Version: v6.9.0+<br>Default: <code>asc</code><br>Applications: Indexer</p>                                         |
| `HIDE_SCAM_ADDRESSES`               | Hides address of EOA/smart-contract/token from search results if the value is `true` and "scam" badge is assigned to that address. Implemented in [#10763](https://github.com/blockscout/blockscout/pull/10763) | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: API</p>                         |
| `RE_CAPTCHA_CHECK_HOSTNAME` | Disable reCAPTCHA hostname check. More details on [reCaptcha docs](https://developers.google.com/recaptcha/docs/domain\_validation). Implemented in [#10706](https://github.com/blockscout/blockscout/pull/10706) | <p>Version: v6.9.0+<br>Default: <code>false</code><br>Applications: API</p>  |
| `ACCOUNT_OTP_RESEND_INTERVAL`                       | Time before resending otp email. Implemented in [#10706](https://github.com/blockscout/blockscout/pull/10706).                                        | <p>Version: v6.9.0+<br>Default: <code>1m</code><br>Applications: API</p>                       |
| `INDEXER_SCROLL_L1_RPC`                        | The RPC endpoint for L1 used to fetch Deposit and Withdrawal messages. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                   | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: Indexer</p>   |
| `INDEXER_SCROLL_L1_CHAIN_CONTRACT`             | The address of ScrollChain contract on L1. Used to fetch batch and bundle events. Implemented in [#10819](https://github.com/blockscout/blockscout/pull/10819).                                                                                                        | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: Indexer</p>   |
| `INDEXER_SCROLL_L1_BATCH_START_BLOCK`          | The number of a start block on L1 to index L1 batches and bundles. If the table of batches is not empty, the process will continue indexing from the last indexed batch. Implemented in [#10819](https://github.com/blockscout/blockscout/pull/10819).                 | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: Indexer</p>   |
| `INDEXER_SCROLL_L1_MESSENGER_CONTRACT`         | The address of L1 Scroll Messenger contract on L1 used to fetch Deposit and Withdrawal messages. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                         | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: Indexer</p>   |
| `INDEXER_SCROLL_L1_MESSENGER_START_BLOCK`      | The number of a start block on L1 to index L1 bridge messages. If the table of bridge operations is not empty, the process will continue indexing from the last indexed L1 message. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).      | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: Indexer</p>   |
| `INDEXER_SCROLL_L2_MESSENGER_CONTRACT`         | The address of L2 Scroll Messenger contract on L2 used to fetch Deposit and Withdrawal messages. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                         | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: Indexer</p>   |
| `INDEXER_SCROLL_L2_MESSENGER_START_BLOCK`      | The number of a start block on L2 to index L2 bridge messages. If the table of bridge operations is not empty, the process will continue indexing from the last indexed L2 message. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).      | <p>Version: v6.9.0+<br>Default: `FIRST_BLOCK`<br>Applications: Indexer</p> |
| `INDEXER_SCROLL_L2_GAS_ORACLE_CONTRACT`        | The address of L1 Gas Oracle contract on L2. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                                             | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: Indexer</p>   |
| `INDEXER_SCROLL_L1_ETH_GET_LOGS_RANGE_SIZE`    | Block range size for eth\_getLogs request in Scroll indexer modules for Layer 1. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                         | <p>Version: v6.9.0+<br>Default: `250`<br>Applications: Indexer</p>     |
| `INDEXER_SCROLL_L2_ETH_GET_LOGS_RANGE_SIZE`    | Block range size for eth\_getLogs request in Scroll indexer modules for Layer 2. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                         | <p>Version: v6.9.0+<br>Default: `1000`<br>Applications: Indexer</p>     |
| `SCROLL_L2_CURIE_UPGRADE_BLOCK`                | L2 block number of the Curie upgrade. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                                                    | <p>Version: v6.9.0+<br>Default: `0`<br>Applications: API</p>           |
| `SCROLL_L1_SCALAR_INIT`                        | Initial value for `scalar` parameter. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                                                    | <p>Version: v6.9.0+<br>Default: `0`<br>Applications: API</p>           |
| `SCROLL_L1_OVERHEAD_INIT`                      | Initial value for `overhead` parameter. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                                                  | <p>Version: v6.9.0+<br>Default: `0`<br>Applications: API</p>           |
| `SCROLL_L1_COMMIT_SCALAR_INIT`                 | Initial value for `commit_scalar` parameter. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                                             | <p>Version: v6.9.0+<br>Default: `0`<br>Applications: API</p>           |
| `SCROLL_L1_BLOB_SCALAR_INIT`                   | Initial value for `blob_scalar` parameter. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                                               | <p>Version: v6.9.0+<br>Default: `0`<br>Applications: API</p>           |
| `SCROLL_L1_BASE_FEE_INIT`                      | Initial value for `l1_base_fee` parameter. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                                               | <p>Version: v6.9.0+<br>Default: `0`<br>Applications: API</p>           |
| `SCROLL_L1_BLOB_BASE_FEE_INIT`                 | Initial value for `l1_blob_base_fee` parameter. Implemented in [#10484](https://github.com/blockscout/blockscout/pull/10484).                                                                                                                                          | <p>Version: v6.9.0+<br>Default: `0`<br>Applications: API</p>           |
| `INDEXER_OPTIMISM_L1_DEPOSITS_TRANSACTION_TYPE`      | Defines OP Deposit transaction type (numeric value) which is needed for correct L2 transaction hash calculation by the Deposits indexing module. Implemented in [#10674](https://github.com/blockscout/blockscout/pull/10674).                                                                                                                                                                                                                                                         | <p>Version: v6.9.0+<br>Default: <code>126</code><br>Applications: Indexer</p>                                         |
| `INDEXER_DISABLE_CELO_VALIDATOR_GROUP_VOTES_FETCHER` | If set to `true`, the validator group votes fetcher will not be started. Implemented in [#10673](https://github.com/blockscout/blockscout/pull/10673).                                                                        | <p>Version: v6.9.0+<br>Default: <code>false</code><br>Applications: Indexer</p>   |
| `FILECOIN_NETWORK_PREFIX`                                   | Specifies the expected network prefix for Filecoin addresses. For more details, refer to the [Filecoin Spec](https://spec.filecoin.io/appendix/address/#section-appendix.address.network-prefix). Available values: `f` (for the mainnet), `t` (for testnets). Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468). | <p>Version: v6.9.0+<br>Default: <code>f</code><br>Applications: API, Indexer</p>                            |
| `BERYX_API_TOKEN`                                           | [Beryx API](https://docs.zondax.ch/beryx-api) token, used for retrieving Filecoin native addressing information. Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468).                                                                                                                                               | <p>Required: ✅<br>Version: v6.9.0+<br>Default: (empty)<br>Applications: Indexer</p>                         |
| `BERYX_API_BASE_URL`                                        | [Beryx API](https://docs.zondax.ch/beryx-api) base URL. Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468).                                                                                                                                                                                                        | <p>Version: v6.9.0+<br>Default: <code>https://api.zondax.ch/fil/data/v3/mainnet</code><br>Applications: Indexer</p> |
| `INDEXER_DISABLE_FILECOIN_ADDRESS_INFO_FETCHER`             | When set to `true`, Filecoin native addressing information will not be fetched, but addresses pending fetch will still be recorded in the database. Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468).                                                                                                            | <p>Version: v6.9.0+<br>Default: <code>false</code><br>Applications: Indexer</p>                             |
| `INDEXER_FILECOIN_ADDRESS_INFO_CONCURRENCY`                 | Sets the maximum number of concurrent requests made to fetch Filecoin native addressing information. Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468).                                                                                                                                                           | <p>Version: v6.9.0+<br>Default: <code>1</code><br>Applications: Indexer</p>                                 |
| `FILECOIN_PENDING_ADDRESS_OPERATIONS_MIGRATION_BATCH_SIZE`  | Specifies the number of address records processed per batch during the backfill of pending address fetch operations. Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468).                                                                                                                                           | <p>Version: v6.9.0+<br>Default: <code>100</code><br>Applications: Indexer</p>                               |
| `FILECOIN_PENDING_ADDRESS_OPERATIONS_MIGRATION_CONCURRENCY` | Specifies the number of concurrent processes used during the backfill of pending address fetch operations. Implemented in [#10468](https://github.com/blockscout/blockscout/pull/10468).                                                                                                                                                     | <p>Version: v6.9.0+<br>Default: <code>1</code><br>Applications: Indexer</p>                                 |
| `BLACKFORT_VALIDATOR_API_URL` | Variable to define the URL of the Blackfort Validator API. Implemented in [#10744](https://github.com/blockscout/blockscout/pull/10744). | <p>Version: v6.9.0+<br>Default: (empty)<br>Applications: API, Indexer</p> |

## 6.8.1

### 🚀 Features

- Add `INDEXER_OPTIMISM_L1_DEPOSITS_TRANSACTION_TYPE` env variable ([#10674](https://github.com/blockscout/blockscout/issues/10674))
- Support for filecoin native addresses ([#10468](https://github.com/blockscout/blockscout/issues/10468))

### 🐛 Bug Fixes

- Decoding of zero fields in mud ([#10764](https://github.com/blockscout/blockscout/issues/10764))
- Insert coin balances placeholders in internal transactions fetcher ([#10603](https://github.com/blockscout/blockscout/issues/10603))
- Avoid key violation error in `Indexer.Fetcher.Optimism.TxnBatch` ([#10752](https://github.com/blockscout/blockscout/issues/10752))
- Fix empty current token balances ([#10745](https://github.com/blockscout/blockscout/issues/10745))
- Allow disabling group votes fetcher independently of epoch block fetcher ([#10673](https://github.com/blockscout/blockscout/issues/10673))
- Fix gettext usage warning ([#10693](https://github.com/blockscout/blockscout/issues/10693))
- Truncate token symbol in Explorer.Chain.PolygonZkevm.BridgeL1Token ([#10688](https://github.com/blockscout/blockscout/issues/10688))

### ⚡ Performance

- Improve performance of transactions list page ([#10734](https://github.com/blockscout/blockscout/issues/10734))

### ⚙️ Miscellaneous Tasks

- Add meta to migrations_status ([#10678](https://github.com/blockscout/blockscout/issues/10678))
- Token balances fetcher slow queue ([#10694](https://github.com/blockscout/blockscout/issues/10694))
- Shrink sample response for the trace in Filecoin chain type
- Extend missing balanceOf function with :unable_to_decode error ([#10713](https://github.com/blockscout/blockscout/issues/10713))
- Fix flaking explorer tests ([#10676](https://github.com/blockscout/blockscout/issues/10676))
- Change shrink internal transactions migration default batch_size ([#10689](https://github.com/blockscout/blockscout/issues/10689))

## 6.8.0

### 🚀 Features

- Detect Diamond proxy pattern on unverified proxy smart-contract ([#10665](https://github.com/blockscout/blockscout/pull/10665))
- Support smart-contract verification in zkSync ([#10500](https://github.com/blockscout/blockscout/issues/10500))
- Add icon for secondary coin ([#10241](https://github.com/blockscout/blockscout/issues/10241))
- Integrate Cryptorank API ([#10550](https://github.com/blockscout/blockscout/issues/10550))
- Enhance /api/v2/smart-contracts/:hash API endpoint ([#10558](https://github.com/blockscout/blockscout/issues/10558))
- Add method name to transactions CSV export ([#10579](https://github.com/blockscout/blockscout/issues/10579))
- Add /api/v2/proxy/metadata/addresses endpoint ([#10585](https://github.com/blockscout/blockscout/issues/10585))
- More descriptive status for Arbitrum message for the transaction view ([#10593](https://github.com/blockscout/blockscout/issues/10593))
- Add internal_transactions to Tx interpreter request ([#10347](https://github.com/blockscout/blockscout/issues/10347))
- Add token decimals to token transfers CSV export ([#10589](https://github.com/blockscout/blockscout/issues/10589))
- Add DELETE /api/v2/import/token-info method ([#10580](https://github.com/blockscout/blockscout/issues/10580))
- Add block number to token transfer object in API v2 endpoint ([#10591](https://github.com/blockscout/blockscout/issues/10591))
- L1 tx associated with Arbitrum message in /api/v2/transactions/{txHash} ([#10590](https://github.com/blockscout/blockscout/issues/10590))
- No rate limit API key ([#10515](https://github.com/blockscout/blockscout/issues/10515))
- Support for `:celo` chain type ([#10564](https://github.com/blockscout/blockscout/issues/10564))
- Public IPFS gateway URL ([#10511](https://github.com/blockscout/blockscout/issues/10511))
- Add CSV_EXPORT_LIMIT env ([#10497](https://github.com/blockscout/blockscout/issues/10497))
- Backfiller for omitted WETH transfers ([#10466](https://github.com/blockscout/blockscout/issues/10466))
- Add INDEXER_DISABLE_REPLACED_TRANSACTION_FETCHER env ([#10485](https://github.com/blockscout/blockscout/issues/10485))
- Revisited approach to catchup missed Arbitrum messages ([#10374](https://github.com/blockscout/blockscout/issues/10374))
- Missing Arbitrum batches re-discovery ([#10446](https://github.com/blockscout/blockscout/issues/10446))
- Add memory metrics for OnDemand fetchers ([#10425](https://github.com/blockscout/blockscout/issues/10425))
- Add Celestia blobs support to Optimism batches fetcher ([#10199](https://github.com/blockscout/blockscout/issues/10199))
- AnyTrust and Celestia support as DA for Arbitrum batches ([#10144](https://github.com/blockscout/blockscout/issues/10144))
- Broadcast updates about new Arbitrum batches and L1-L2 messages through WebSocket ([#10272](https://github.com/blockscout/blockscout/issues/10272))

### 🐛 Bug Fixes

- Logs list serialization ([#10565](https://github.com/blockscout/blockscout/issues/10565))
- nil in OrderedCache ([#10647](https://github.com/blockscout/blockscout/pull/10647))
- Fix for metadata detection at ipfs protocol([#10646](https://github.com/blockscout/blockscout/pull/10646))
- Fix bug in update_replaced_transactions query ([#10634](https://github.com/blockscout/blockscout/issues/10634))
- Fix mode dependent processes starting ([#10641](https://github.com/blockscout/blockscout/issues/10641))
- Better detection IPFS links in NFT metadata fetcher ([#10638](https://github.com/blockscout/blockscout/issues/10638))
- Change mode env name ([#10636](https://github.com/blockscout/blockscout/issues/10636))
- Proper default value of gas used for dropped Arbitrum transactions ([#10619](https://github.com/blockscout/blockscout/issues/10619))
- Fix fetch_first_trace tests ([#10618](https://github.com/blockscout/blockscout/issues/10618))
- Add SHRINK_INTERNAL_TRANSACTIONS_ENABLED arg to Dockerfile ([#10616](https://github.com/blockscout/blockscout/issues/10616))
- Fix raw-trace test ([#10606](https://github.com/blockscout/blockscout/issues/10606))
- Fix internal transaction validation ([#10443](https://github.com/blockscout/blockscout/issues/10443))
- Fix internal transactions runner test for zetachain ([#10576](https://github.com/blockscout/blockscout/issues/10576))
- Filter out incorrect L1-to-L2 Arbitrum messages ([#10570](https://github.com/blockscout/blockscout/issues/10570))
- Fetch contract methods decoding candidates sorted by inserted_at ([#10529](https://github.com/blockscout/blockscout/issues/10529))
- Sanitize topic value before making db query ([#10481](https://github.com/blockscout/blockscout/issues/10481))
- Fix :checkout_timeout error on NFT fetching ([#10429](https://github.com/blockscout/blockscout/issues/10429))
- Proper handling confirmations for Arbitrum rollup block in the middle of a batch ([#10482](https://github.com/blockscout/blockscout/issues/10482))
- Sanitize contractURI response ([#10479](https://github.com/blockscout/blockscout/issues/10479))
- Use token_type from tt instead of token ([#10555](https://github.com/blockscout/blockscout/issues/10555))
- Non-consensus logs in JSON RPC and ETH RPC APIs ([#10545](https://github.com/blockscout/blockscout/issues/10545))
- Fix address_to_logs consensus filtering ([#10528](https://github.com/blockscout/blockscout/issues/10528))
- Error on internal transactions CSV export ([#10495](https://github.com/blockscout/blockscout/issues/10495))
- Extend block search range for `getblocknobytime` method ([#10475](https://github.com/blockscout/blockscout/issues/10475))
- Move recon dep to explorer mix.exs ([#10487](https://github.com/blockscout/blockscout/issues/10487))
- Add missing condition to fetch_min_missing_block_cache ([#10478](https://github.com/blockscout/blockscout/issues/10478))
- Mud api format fixes ([#10362](https://github.com/blockscout/blockscout/issues/10362))
- Add no overlapping constraint to missing_block_ranges ([#10449](https://github.com/blockscout/blockscout/issues/10449))
- Avoid infinite loop during batch block range binary search ([#10436](https://github.com/blockscout/blockscout/issues/10436))
- Fix "key :bytes not found in: nil" issue ([#10435](https://github.com/blockscout/blockscout/issues/10435))
- Missing clauses in MetadataPreloader functions ([#10439](https://github.com/blockscout/blockscout/issues/10439))
- Code compiler test ([#10454](https://github.com/blockscout/blockscout/issues/10454))
- Include internal transactions in state change ([#10210](https://github.com/blockscout/blockscout/issues/10210))
- Race condition in cache tests ([#10441](https://github.com/blockscout/blockscout/issues/10441))
- Fix on-demand fetchers metrics ([#10431](https://github.com/blockscout/blockscout/issues/10431))
- Transactions and token transfers block_consensus ([#10285](https://github.com/blockscout/blockscout/issues/10285))
- Allow fetching image from properties -> image prop in token instance metadata ([#10380](https://github.com/blockscout/blockscout/issues/10380))
- Filter out internal transactions belonging to reorg ([#10330](https://github.com/blockscout/blockscout/issues/10330))
- Fix logs sorting in API v1 ([#10405](https://github.com/blockscout/blockscout/issues/10405))
- Fix flickering transaction_estimated_count/1 test ([#10403](https://github.com/blockscout/blockscout/issues/10403))
- Fix flickering "updates cache if initial value is zero" tests ([#10402](https://github.com/blockscout/blockscout/issues/10402))
- /addresses empty list flickering test fix ([#10400](https://github.com/blockscout/blockscout/issues/10400))
- Fix missing expectation in mock_beacon_storage_pointer_request ([#10399](https://github.com/blockscout/blockscout/issues/10399))
- Fix /stats/charts/market test ([#10392](https://github.com/blockscout/blockscout/issues/10392))
- Alternative way to detect blocks range for ArbitrumOne batches ([#10295](https://github.com/blockscout/blockscout/issues/10295))
- Fix exchange rate flickering test ([#10383](https://github.com/blockscout/blockscout/issues/10383))
- Fix gas price oracle flickering test ([#10381](https://github.com/blockscout/blockscout/issues/10381))
- Fix address controller flickering test ([#10382](https://github.com/blockscout/blockscout/issues/10382))
- Empty revert reasons in geth variant ([#10243](https://github.com/blockscout/blockscout/issues/10243))
- Proper handling for re-discovered Arbitrum batches ([#10326](https://github.com/blockscout/blockscout/issues/10326))
- Proper lookup of confirmed Arbitrum cross-chain messages ([#10322](https://github.com/blockscout/blockscout/issues/10322))
- Indexer first block usage to halt Arbitrum missed messages discovery ([#10280](https://github.com/blockscout/blockscout/issues/10280))

### 📚 Documentation

- Refine PR template
- Move note in README.md higher for visibility ([#10450](https://github.com/blockscout/blockscout/issues/10450))

### ⚡ Performance

- Speed up worlds list query ([#10556](https://github.com/blockscout/blockscout/issues/10556))
- Reduce LookUpSmartContractSourcesOnDemand fetcher footprint ([#10457](https://github.com/blockscout/blockscout/issues/10457))

### ⚙️ Miscellaneous Tasks

- Make Dockerfile use specified user with uid/gid ([#10070](https://github.com/blockscout/blockscout/pull/10070))
- Run shrink internal transactions migration for indexer instance only ([#10631](https://github.com/blockscout/blockscout/issues/10631))
- Shrink internal transactions ([#10567](https://github.com/blockscout/blockscout/issues/10567))
- Upgrade WS client ([#10407](https://github.com/blockscout/blockscout/issues/10407))
- Add API endpoint for OP batch blocks ([#10566](https://github.com/blockscout/blockscout/issues/10566))
- Public metrics config API endpoint ([#10568](https://github.com/blockscout/blockscout/issues/10568))
- Add workflow to generate separate pre-release indexer/API images for Arbitrum
- Fix some comments ([#10519](https://github.com/blockscout/blockscout/issues/10519))
- Set Geth as default JSON RPC Variant ([#10509](https://github.com/blockscout/blockscout/issues/10509))
- Return ex_abi core lib dependency ([#10470](https://github.com/blockscout/blockscout/issues/10470))
- Add recon dependency ([#10486](https://github.com/blockscout/blockscout/issues/10486))
- Manage Solidityscan platform id via runtime variable ([#10473](https://github.com/blockscout/blockscout/issues/10473))
- Add test for broadcasting fetched_bytecode message ([#10244](https://github.com/blockscout/blockscout/issues/10244))
- Disable public metrics by default, set 1 day as default period of update ([#10469](https://github.com/blockscout/blockscout/issues/10469))
- Move eth_bytecode_db_lookup_started event to smart contract related event handler ([#10462](https://github.com/blockscout/blockscout/issues/10462))
- Token transfers broadcast optimization ([#10465](https://github.com/blockscout/blockscout/issues/10465))
- Remove catchup sequence logic ([#10415](https://github.com/blockscout/blockscout/issues/10415))
- Remove single implementation name, address from API v2 response ([#10390](https://github.com/blockscout/blockscout/issues/10390))
- Refactor init functions to use continue if needed ([#10300](https://github.com/blockscout/blockscout/issues/10300))
- Update buildkit builders ([#10377](https://github.com/blockscout/blockscout/issues/10377))

### New ENV Variables

| Variable                                    | Description                                                                                                                                                                                                                                            | Parameters                                                                              |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| `ETHEREUM_JSONRPC_FALLBACK_WS_URL`                      | The fallback WebSockets RPC endpoint used to subscribe to the `newHeads` subscription alerting the indexer to fetch new blocks. Implemented in [#10407](https://github.com/blockscout/blockscout/pull/10407).                                                                                                                                                                                                                                      | <p>Version: v6.8.0+<br>Default: (empty)<br>Applications: Indexer</p>                                                                                                        |
| `ETHEREUM_JSONRPC_WS_RETRY_INTERVAL`                      | The interval between retries of connecting to WebSocket RPC endpoint after the previous attempt is failed. Implemented in [#10407](https://github.com/blockscout/blockscout/pull/10407).                                                                                                                                                                                                                                                           | <p>Version: v6.8.0+<br>Default: 1m<br>Applications: Indexer</p>                                                                                                              |
| `DATABASE_EVENT_URL`                                    | Variable to define the Postgres Database endpoint that will be used by event listener process. Applicable for separate indexer and API setup. More info in related PR. Implemented in [#10164](https://github.com/blockscout/blockscout/pull/10164).                                                                                                                                                                                               | <p>Version: v6.8.0+<br>Default: (empty)<br>Applications: API</p>                                                                                                          |
| `PUBLIC_METRICS_ENABLED`                                    | Variable to enable running queries at /public-metrics endpoint. Implemented in [#10469](https://github.com/blockscout/blockscout/pull/10469).                                                                                                                                                                                               | <p>Version: v6.8.0+<br>Default: false<br>Applications: API</p>                                                                                                          |
| `PUBLIC_METRICS_UPDATE_PERIOD_HOURS`                                    | Public metrics update period in hours at /public-metrics endpoint. Implemented in [#10469](https://github.com/blockscout/blockscout/pull/10469).                                                                                                                                                                                               | <p>Version: v6.8.0+<br>Default: 24<br>Applications: API</p>                                                                                                          | 
| `SHRINK_INTERNAL_TRANSACTIONS_ENABLED`                                    | Variable to enable internal transactions shrinking logic. Implemented in [#10567](https://github.com/blockscout/blockscout/pull/10567).                                                                                                                                                                                                                                                                                                            | <p>Version: v6.8.0+<br>Default: <code>false</code><br>Applications: API, Indexer</p>                                                                                     | 
| `SHRINK_INTERNAL_TRANSACTIONS_BATCH_SIZE`                                    | Batch size of the shrink internal transactions migration. Implemented in [#10567](https://github.com/blockscout/blockscout/pull/10567).                                                                                                                                                                                                                                                                                                            | <p>Version: v6.8.0+<br>Default: 1000<br>Applications: API, Indexer</p>                                                                                                   | 
| `SHRINK_INTERNAL_TRANSACTIONS_CONCURRENCY`                                    | Concurrency of the shrink internal transactions migration. Implemented in [#10567](https://github.com/blockscout/blockscout/pull/10567).                                                                                                                                                                                                                                                                                                           | <p>Version: v6.8.0+<br>Default: 1<br>Applications: API, Indexer</p>                                                                                                      | 
| `IPFS_PUBLIC_GATEWAY_URL`                                            | IPFS public gateway url which is used by frontend to display IPFS resources such as token instance image.                                                                                                                                                                                                                                                                                                                                                                                                                                   | <p>Version: v6.8.0+<br>Default: <code>https://ipfs.io/ipfs</code><br>Applications: API</p>                       |
| `INDEXER_TOKEN_INSTANCE_RETRY_MAX_REFETCH_INTERVAL`           | Maximum interval between attempts to fetch token instance metadata. [Time format](backend-env-variables.md#time-format). Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                           | <p>Version: v6.8.0+<br>Default: <code>168h</code><br>Applications: Indexer</p>                                        |
| `INDEXER_TOKEN_INSTANCE_RETRY_EXPONENTIAL_TIMEOUT_BASE`       | Base to calculate exponential timeout. Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                                                                                                             | <p>Version: v6.8.0+<br>Default: <code>2</code><br>Applications: Indexer</p>                                           |
| `INDEXER_TOKEN_INSTANCE_RETRY_EXPONENTIAL_TIMEOUT_COEFF`      | Coefficient to calculate exponential timeout. Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                                                                                                      | <p>Version: v6.8.0+<br>Default: <code>100</code><br>Applications: Indexer</p>                                         |
| `MISSING_BALANCE_OF_TOKENS_WINDOW_SIZE`                       | Minimal blocks count until the next token balance request will be executed for tokens that doesn't implement `balanceOf` function. Implemented in [#10142](https://github.com/blockscout/blockscout/pull/10142)                                                                                                                                                                                                                                                                                                                  | <p>Version: v6.8.0+<br>Default: <code>100</code><br>Applications: Indexer</p>                                         |
| `ETHEREUM_JSONRPC_GETH_ALLOW_EMPTY_TRACES`                    | Allow transactions to not have internal transactions. Implemented in [#10200](https://github.com/blockscout/blockscout/pull/10200)                                                                                                                                                                                                                                                                                                                                                                                               | <p>Version: v6.8.0+<br>Default: <code>false</code><br>Applications: Indexer</p>                                       |
| `INDEXER_DISABLE_REPLACED_TRANSACTION_FETCHER`                | If `true`, `Indexer.Fetcher.ReplacedTransaction` fetcher doesn't run                                                                                                                                                                                                                                                                                                                                                                                                                                                             | <p>Version: v6.8.0+<br>Default: <code>false</code><br>Applications: Indexer</p>                                       |
| `SANITIZE_INCORRECT_WETH_BATCH_SIZE`              | Number of token transfers to sanitize in the batch. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134)              | <p>Version: v6.8.0+<br>Default: <code>100</code><br>Applications: API, Indexer</p>       |
| `SANITIZE_INCORRECT_WETH_CONCURRENCY`             | Number of parallel sanitizing token transfer batches processing. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134) | <p>Version: v6.8.0+<br>Default: <code>1</code><br>Applications: API, Indexer</p>         |
| `MIGRATION_RESTORE_OMITTED_WETH_TOKEN_TRANSFERS_BATCH_SIZE` | Number of logs to process in the batch. Implemented in [#10466](https://github.com/blockscout/blockscout/pull/10466)              | <p>Version: v6.8.0+<br>Default: <code>50</code><br>Applications: API, Indexer</p>       |
| `MIGRATION_RESTORE_OMITTED_WETH_TOKEN_TRANSFERS_CONCURRENCY`| Number of parallel logs batches processing. Implemented in [#10466](https://github.com/blockscout/blockscout/pull/10466) | <p>Version: v6.8.0+<br>Default: <code>5</code><br>Applications: API, Indexer</p>         |
| `MIGRATION_RESTORE_OMITTED_WETH_TOKEN_TRANSFERS_TIMEOUT`    | Time interval between checks if queue is not empty. The same timeout multiplied by 2 used between checks if queue is not full. Implemented in [#10466](https://github.com/blockscout/blockscout/pull/10466) | <p>Version: v6.8.0+<br>Default: <code>250ms</code><br>Applications: API, Indexer</p>         |
| `EXCHANGE_RATES_SOURCE`                              | Source for native coin and tokens price fetching. Possible values are: `coin_gecko`, `coin_market_cap` or `mobula`.                                                                                                                                                    | <p>Version: v6.8.0+<br>Default: <code>coin_gecko</code><br>Applications: API, Indexer</p>       |
| `EXCHANGE_RATES_SECONDARY_COIN_SOURCE`               | Source for secondary coin fetching. Possible values are: `coin_gecko`, `coin_market_cap` or `mobula`.                                                                                                                                                                  | <p>Version: v6.8.0+<br>Default: <code>coin_gecko</code><br>Applications: API, Indexer</p>       |
| `TOKEN_EXCHANGE_RATES_SOURCE`                        | Sets the source for tokens price fetching. Available values are `coin_gecko`, `cryptorank`. Implemented in [#10550](https://github.com/blockscout/blockscout/pull/10550).                                                                                                                               | <p>Version: v6.8.0+<br>Default: <code>coin_gecko</code><br>Applications: API, Indexer</p>            |
| `EXCHANGE_RATES_CRYPTORANK_SECONDARY_COIN_ID`        | Sets Cryptorank coin ID for secondary coin market chart. Implemented in [#10550](https://github.com/blockscout/blockscout/pull/10550).                                                                                                                               | <p>Version: v6.8.0+<br>Default: (empty)<br>Applications: API, Indexer</p>            |
| `EXCHANGE_RATES_CRYPTORANK_PLATFORM_ID`              | Sets Cryptorank platform ID. Implemented in [#10550](https://github.com/blockscout/blockscout/pull/10550).                                                                                                                               | <p>Version: v6.8.0+<br>Default: (empty)<br>Applications: API, Indexer</p>            |
| `EXCHANGE_RATES_CRYPTORANK_BASE_URL`                 | If set, overrides the Cryptorank API url. Implemented in [#10550](https://github.com/blockscout/blockscout/pull/10550).                                                                                                                               | <p>Version: v6.8.0+<br>Default: <code>https://api.cryptorank.io/v1/</code><br>Applications: API, Indexer</p>            |
| `EXCHANGE_RATES_CRYPTORANK_API_KEY`                  | Cryptorank API key. Current implementation uses dedicated beta Cryptorank API endpoint. If you want to integrate Cryptorank price fetching you should contact Cryptorank to receive an API key. Implemented in [#10550](https://github.com/blockscout/blockscout/pull/10550).                                                                                                                               | <p>Version: v6.8.0+<br>Default: (empty)<br>Applications: API, Indexer</p>            |
| `EXCHANGE_RATES_CRYPTORANK_COIN_ID`                  | Sets Cryptorank coin ID. Implemented in [#10550](https://github.com/blockscout/blockscout/pull/10550).                                                                                                                               | <p>Version: v6.8.0+<br>Default: (empty)<br>Applications: API, Indexer</p>            |
| `EXCHANGE_RATES_CRYPTORANK_LIMIT`                    | Sets the maximum number of token prices returned in a single request. Implemented in [#10550](https://github.com/blockscout/blockscout/pull/10550).                                                                                                                               | <p>Version: v6.8.0+<br>Default: <code>1000</code><br>Applications: API, Indexer</p>            |
| `WHITELISTED_WETH_CONTRACTS`                           | Comma-separated list of smart-contract address hashes of WETH-like tokens which deposit and withdrawal events you'd like to index. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134)                                  | <p>Version: v6.8.0+<br>Default: (empty)<br>Applications: API, Indexer</p>                                                                                                                           |
| `API_NO_RATE_LIMIT_API_KEY`             | API key with no rate limit. Implemented in [#10515](https://github.com/blockscout/blockscout/pull/10515)                     | <p>Version: v6.8.0+<br>Default: (empty)<br>Applications: API</p>                       |

## 6.7.2

### 🐛 Bug Fixes

- Apply Ecto set explicit ssl_opts: [verify: :verify_none] to all prod repos ([#10369](https://github.com/blockscout/blockscout/issues/10369))
- Fix slow internal transactions query ([#10346](https://github.com/blockscout/blockscout/issues/10346))
- Don't execute update query for empty list ([#10344](https://github.com/blockscout/blockscout/issues/10344))
- Add rescue on tx revert reason fetching ([#10366](https://github.com/blockscout/blockscout/issues/10366))
- Reth compatibility ([#10335](https://github.com/blockscout/blockscout/issues/10335))
- Public metrics enabling ([#10365](https://github.com/blockscout/blockscout/issues/10365))
- Flaky market test ([#10262](https://github.com/blockscout/blockscout/issues/10262))

### ⚙️ Miscellaneous Tasks

- Bump elixir to 1.16.3 and Erlang OTP to 26.2.5.1 ([#9256](https://github.com/blockscout/blockscout/issues/9256))

## 6.7.1

### 🐛 Bug Fixes

- Fix to_string error ([#10319](https://github.com/blockscout/blockscout/issues/10319))
- Fix bridged tokens ([#10318](https://github.com/blockscout/blockscout/issues/10318))
- Missing onlyTopCall option on some geth networks ([#10309](https://github.com/blockscout/blockscout/issues/10309))

## 6.7.0

### 🚀 Features

- Public metrics toggler ([#10279](https://github.com/blockscout/blockscout/issues/10279))
- Chain & explorer Prometheus metrics ([#10063](https://github.com/blockscout/blockscout/issues/10063))
- API endpoint to re-fetch token instance metadata ([#10097](https://github.com/blockscout/blockscout/issues/10097))
- *(ci)* Use remote arm64 builder ([#9468](https://github.com/blockscout/blockscout/issues/9468))
- Adding Mobula price source ([#9971](https://github.com/blockscout/blockscout/issues/9971))
- Get ERC-1155 token name from contractURI getter fallback ([#10187](https://github.com/blockscout/blockscout/issues/10187))
- Push relevant entries to the front of bound queue ([#10193](https://github.com/blockscout/blockscout/issues/10193))
- Add feature toggle for WETH filtering ([#10208](https://github.com/blockscout/blockscout/issues/10208))
- Batch read methods requests ([#10192](https://github.com/blockscout/blockscout/issues/10192))
- Set dynamic ttl of cache modules derived from MapCache ([#10109](https://github.com/blockscout/blockscout/issues/10109))
- Add Fee column to Internal transactions CSV export ([#10204](https://github.com/blockscout/blockscout/issues/10204))
- Add window between balance fetch retries for missing balanceOf tokens ([#10142](https://github.com/blockscout/blockscout/issues/10142))
- Indexer for cross level messages on Arbitrum ([#9312](https://github.com/blockscout/blockscout/issues/9312))

### 🐛 Bug Fixes

- Add token instances preloads ([#10288](https://github.com/blockscout/blockscout/issues/10288))
- Set timeout in seconds ([#10283](https://github.com/blockscout/blockscout/issues/10283))
- Fix ci setup repo error ([#10277](https://github.com/blockscout/blockscout/issues/10277))
- `getsourcecode` in API v1 for verified proxy ([#10273](https://github.com/blockscout/blockscout/issues/10273))
- Add preloads for tx summary endpoint ([#10261](https://github.com/blockscout/blockscout/issues/10261))
- Add preloads to summary and tokens endpoints ([#10259](https://github.com/blockscout/blockscout/issues/10259))
- Advanced filter contract creation transaction ([#10257](https://github.com/blockscout/blockscout/issues/10257))
- Proper hex-encoded transaction hash recognition in ZkSync batches status checker ([#10255](https://github.com/blockscout/blockscout/issues/10255))
- Pipe through  api_v2_no_forgery_protect POST requests in SmartContractsApiV2Router
- Fix possible unknown UID bug ([#10240](https://github.com/blockscout/blockscout/issues/10240))
- Batch transactions view recovered and support of proofs through ZkSync Hyperchain ([#10234](https://github.com/blockscout/blockscout/issues/10234))
- Fix nil abi issue in get_naive_implementation_abi and get_master_copy_pattern methods ([#10239](https://github.com/blockscout/blockscout/issues/10239))
- Add smart contracts preloads to from_address ([#10236](https://github.com/blockscout/blockscout/issues/10236))
- Add proxy_implementations preloads ([#10225](https://github.com/blockscout/blockscout/issues/10225))
- Cannot truncate chardata ([#10227](https://github.com/blockscout/blockscout/issues/10227))
- ERC-1155 tokens metadata retrieve ([#10231](https://github.com/blockscout/blockscout/issues/10231))
- Replace empty arg names with argN ([#9748](https://github.com/blockscout/blockscout/issues/9748))
- Fix unknown UID bug ([#10226](https://github.com/blockscout/blockscout/issues/10226))
- Fixed the field name ([#10216](https://github.com/blockscout/blockscout/issues/10216))
- Excessive logging for Arbitrum batches confirmations ([#10205](https://github.com/blockscout/blockscout/issues/10205))
- Filter WETH transfers in indexer + migration to delete historical incorrect WETH transfers ([#10134](https://github.com/blockscout/blockscout/issues/10134))
- Fix flaky test
- Resolve flaky address_controller test for web
- Add the ability to allow empty traces ([#10200](https://github.com/blockscout/blockscout/issues/10200))
- Move auth routes to general router ([#10153](https://github.com/blockscout/blockscout/issues/10153))
- Add a separate db url for events listener ([#10164](https://github.com/blockscout/blockscout/issues/10164))
- Fix Retry NFT fetcher ([#10146](https://github.com/blockscout/blockscout/issues/10146))
- Add missing preloads to tokens endpoints ([#10072](https://github.com/blockscout/blockscout/issues/10072))
- Missing nil case for revert reason ([#10136](https://github.com/blockscout/blockscout/issues/10136))
- Hotfix for Indexer.Fetcher.Optimism.WithdrawalEvent and EthereumJSONRPC.Receipt ([#10130](https://github.com/blockscout/blockscout/issues/10130))

### 🚜 Refactor

- Remove hardcoded numResults from fetch_pending_transactions_besu ([#10117](https://github.com/blockscout/blockscout/issues/10117))

### ⚡ Performance

- Replace individual queries with ecto preload ([#10203](https://github.com/blockscout/blockscout/issues/10203))

### ⚙️ Miscellaneous Tasks

- Refactor PendingTransactionsSanitizer to use batched requests ([#10101](https://github.com/blockscout/blockscout/issues/10101))
- Exclude write methods from read tabs ([#10111](https://github.com/blockscout/blockscout/issues/10111))
- Return is verified=true for verified minimal proxy pattern ([#10132](https://github.com/blockscout/blockscout/issues/10132))
- Bump ecto_sql from 3.11.1 to 3.11.2

### New ENV Variables

| Variable                                     | Required | Description                                                                                                                                                                                                                                 | Default                                                | Version | Need recompile | Application  |
| -------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------- | -------------- | --- |
| `DATABASE_EVENT_URL`                                    |          | Variable to define the Postgres Database endpoint that will be used by event listener process. Applicable for separate indexer and API setup. More info in related PR. Implemented in [#10164](https://github.com/blockscout/blockscout/pull/10164).                                                                                                                                                                                              | (empty)                                                                            | v6.7.0+  |                | API          |
| `INDEXER_TOKEN_INSTANCE_RETRY_MAX_REFETCH_INTERVAL`            |          | Maximum interval between attempts to fetch token instance metadata. [Time format](env-variables.md#time-format). Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                                | `168h`                                     | v6.7.0+ | | Indexer      |
| `INDEXER_TOKEN_INSTANCE_RETRY_EXPONENTIAL_TIMEOUT_BASE`        |          | Base to calculate exponential timeout. Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                                                                                                          | `2`                                        | v6.7.0+ | | Indexer      |
| `INDEXER_TOKEN_INSTANCE_RETRY_EXPONENTIAL_TIMEOUT_COEFF`       |          | Coefficient to calculate exponential timeout. Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                                                                                                   | `100`                                      | v6.7.0+ | | Indexer      |
| `MISSING_BALANCE_OF_TOKENS_WINDOW_SIZE`                        |          | Minimal blocks count until the next token balance request will be executed for tokens that doesn't implement `balanceOf` function. Implemented in [#10142](https://github.com/blockscout/blockscout/pull/10142)                                                                                                                                                                                                                                                                                                               | 100                                        | v6.7.0+ | | Indexer      |
| `ETHEREUM_JSONRPC_GETH_ALLOW_EMPTY_TRACES`                     |          | Allow transactions to not have internal transactions. Implemented in [#10200](https://github.com/blockscout/blockscout/pull/10200)                                                                                                                                                                                                                                                                                                                                                                                            | `false`                                    | v6.7.0+ | | Indexer      |
| `SANITIZE_INCORRECT_WETH_BATCH_SIZE`  |          | Number of token transfers to sanitize in the batch. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134)              | 100     | v6.7.0+ | | API, Indexer |
| `SANITIZE_INCORRECT_WETH_CONCURRENCY` |          | Number of parallel sanitizing token transfer batches processing. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134) | 1       | v6.7.0+ | | API, Indexer |
| `EXCHANGE_RATES_MOBULA_SECONDARY_COIN_ID`            |          | Explicitly set Mobula coin ID for secondary coin market chart.                                                                                                                          | (empty)          | v6.7.0+  | | API, Indexer |
| `EXCHANGE_RATES_MOBULA_API_KEY`                      |          | Mobula API key.                                                                                                                                                                                                                                                     | (empty)          | v6.7.0+ | | API, Indexer |
| `EXCHANGE_RATES_MOBULA_CHAIN_ID`                     |          | [Mobula](https://www.mobula.io/) chain id for which token prices are fetched, see full list in the [`Documentation`](https://docs.mobula.io/blockchains/intro-blockchains). | ethereum         | v6.7.0+ | | API, Indexer |
| `TOKEN_INSTANCE_METADATA_REFETCH_ON_DEMAND_FETCHER_THRESHOLD`           |          | An initial threshold (for exponential backoff) to re-fetch token instance's metadata on-demand. [Time format](env-variables.md#time-format). Implemented in [#10097](https://github.com/blockscout/blockscout/pull/10097).   | 5s       | v6.7.0+ |                | API, Indexer  |
| `WHITELISTED_WETH_CONTRACTS`                            |          | Comma-separated list of smart-contract addresses hashes of WETH-like tokens which deposit and withdrawal events you'd like to index. Implemented in [#10134](https://github.com/blockscout/blockscout/pull/10134)                                     | (empty)                                                                                                                        | v6.7.0+ | | API, Indexer|
| `WETH_TOKEN_TRANSFERS_FILTERING_ENABLED`                |          | Toggle for WETH token transfers filtering which was introduced in [#10134](https://github.com/blockscout/blockscout/pull/10134). Implemented in [#10208](https://github.com/blockscout/blockscout/pull/10208)                                         | false                                                                                                                          | v6.7.0+ |  | API, Indexer|

## 6.6.0

### 🚀 Features

- Implement fetch_first_trace for Geth ([#10087](https://github.com/blockscout/blockscout/issues/10087))
- Add optional retry of NFT metadata fetch in Indexer.Fetcher.Tok… ([#10036](https://github.com/blockscout/blockscout/issues/10036))
- Blueprint contracts support ([#10058](https://github.com/blockscout/blockscout/issues/10058))
- Clone with immutable arguments proxy pattern ([#10039](https://github.com/blockscout/blockscout/issues/10039))
- Improve retry NFT fetcher ([#10027](https://github.com/blockscout/blockscout/issues/10027))
- MUD API support ([#9869](https://github.com/blockscout/blockscout/issues/9869))
- Diamond proxy (EIP-2535) support ([#10034](https://github.com/blockscout/blockscout/issues/10034))
- Add user ops indexer to docker compose configs ([#10010](https://github.com/blockscout/blockscout/issues/10010))
- Save smart-contract proxy type in the DB ([#10033](https://github.com/blockscout/blockscout/issues/10033))
- Detect EIP-1967 proxy pattern on unverified smart-contracts ([#9864](https://github.com/blockscout/blockscout/issues/9864))
- Omit balanceOf requests for tokens that doesn't support it ([#10018](https://github.com/blockscout/blockscout/issues/10018))
- Precompiled contracts ABI import ([#9899](https://github.com/blockscout/blockscout/issues/9899))
- Add ENS category to search result; Add ENS to check-redirect ([#9779](https://github.com/blockscout/blockscout/issues/9779))

### 🐛 Bug Fixes

- Fix certified flag in the search API v2 endpoint ([#10094](https://github.com/blockscout/blockscout/issues/10094))
- Update Vyper inner compilers list to support all compilers ([#10091](https://github.com/blockscout/blockscout/issues/10091))
- Add healthcheck endpoints for indexer-only setup ([#10076](https://github.com/blockscout/blockscout/issues/10076))
- Rework revert_reason ([#9212](https://github.com/blockscout/blockscout/issues/9212))
- Eliminate from_address_hash == #{address_hash} clause for transactions query in case of smart-contracts ([#9469](https://github.com/blockscout/blockscout/issues/9469))
- Separate indexer setup ([#10032](https://github.com/blockscout/blockscout/issues/10032))
- Disallow batched queries in GraphQL endpoint ([#10050](https://github.com/blockscout/blockscout/issues/10050))
- Vyper contracts re-verification ([#10053](https://github.com/blockscout/blockscout/issues/10053))
- Fix Unknown UID bug at smart-contract verification ([#9986](https://github.com/blockscout/blockscout/issues/9986))
- Search for long integers ([#9651](https://github.com/blockscout/blockscout/issues/9651))
- Don't put error to NFT metadata ([#9940](https://github.com/blockscout/blockscout/issues/9940))
- Handle DB unavailability by PolygonZkevm.TransactionBatch fetcher ([#10031](https://github.com/blockscout/blockscout/issues/10031))
- Fix WebSocketClient reconnect ([#9937](https://github.com/blockscout/blockscout/issues/9937))
- Fix incorrect image_url parsing from NFT meta ([#9956](https://github.com/blockscout/blockscout/issues/9956))

### 🚜 Refactor

- Improve response of address API to return multiple implementations for Diamond proxy ([#10113](https://github.com/blockscout/blockscout/pull/10113))
- Refactor get_additional_sources/4 -> get_additional_sources/3 ([#10046](https://github.com/blockscout/blockscout/issues/10046))
- Test database config ([#9662](https://github.com/blockscout/blockscout/issues/9662))

### ⚙️ Miscellaneous Tasks

- Update hackney pool size: add new fetchers accounting ([#9941](https://github.com/blockscout/blockscout/issues/9941))
- Bump credo from 1.7.5 to 1.7.6 ([#10060](https://github.com/blockscout/blockscout/issues/10060))
- Bump redix from 1.5.0 to 1.5.1 ([#10059](https://github.com/blockscout/blockscout/issues/10059))
- Bump ex_doc from 0.32.1 to 0.32.2 ([#10061](https://github.com/blockscout/blockscout/issues/10061))
- Remove `has_methods` from `/addresses` ([#10051](https://github.com/blockscout/blockscout/issues/10051))
- Add support of Blast-specific L1 OP withdrawal events ([#10049](https://github.com/blockscout/blockscout/issues/10049))
- Update outdated links to ETH JSON RPC Specification in docstrings ([#10041](https://github.com/blockscout/blockscout/issues/10041))
- Migrate to GET variant of {{metadata_url}}/api/v1/metadata ([#9994](https://github.com/blockscout/blockscout/issues/9994))
- Bump ex_cldr_numbers from 2.32.4 to 2.33.1 ([#9978](https://github.com/blockscout/blockscout/issues/9978))
- Bump ex_cldr from 2.38.0 to 2.38.1 ([#10009](https://github.com/blockscout/blockscout/issues/10009))
- Bump ex_cldr_units from 3.16.5 to 3.17.0 ([#9931](https://github.com/blockscout/blockscout/issues/9931))
- Bump style-loader in /apps/block_scout_web/assets ([#9995](https://github.com/blockscout/blockscout/issues/9995))
- Bump mini-css-extract-plugin in /apps/block_scout_web/assets ([#9997](https://github.com/blockscout/blockscout/issues/9997))
- Bump @babel/preset-env in /apps/block_scout_web/assets ([#9999](https://github.com/blockscout/blockscout/issues/9999))
- Bump @amplitude/analytics-browser in /apps/block_scout_web/assets ([#10001](https://github.com/blockscout/blockscout/issues/10001))
- Bump css-loader in /apps/block_scout_web/assets ([#10003](https://github.com/blockscout/blockscout/issues/10003))
- Bump sweetalert2 in /apps/block_scout_web/assets ([#9998](https://github.com/blockscout/blockscout/issues/9998))
- Bump mixpanel-browser in /apps/block_scout_web/assets ([#10000](https://github.com/blockscout/blockscout/issues/10000))
- Bump @fortawesome/fontawesome-free ([#10002](https://github.com/blockscout/blockscout/issues/10002))
- Bump @babel/core in /apps/block_scout_web/assets ([#9996](https://github.com/blockscout/blockscout/issues/9996))
- Enhance indexer memory metrics ([#9984](https://github.com/blockscout/blockscout/issues/9984))
- Bump redix from 1.4.1 to 1.5.0 ([#9977](https://github.com/blockscout/blockscout/issues/9977))
- Bump floki from 0.36.1 to 0.36.2 ([#9979](https://github.com/blockscout/blockscout/issues/9979))
- (old UI) Replace old Twitter icon with new 'X' ([#9641](https://github.com/blockscout/blockscout/issues/9641))

### New ENV Variables

| Variable                                     | Required | Description                                                                                                                                                                                                                                 | Default                                                | Version | Need recompile |
| -------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ | ------- | -------------- |
| `DISABLE_API`                                |          | If `true`, endpoint is not started. Set this if you want to use an indexer-only setup. Implemented in [#10032](https://github.com/blockscout/blockscout/pull/10032)                                                                           | `false`                                                                            | v6.6.0+  |                |
| `INDEXER_TOKEN_INSTANCE_RETRY_MAX_REFETCH_INTERVAL`               |          | Maximum interval between attempts to fetch token instance metadata. [Time format](env-variables.md#time-format). Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                                          | `168h`                                      | v6.6.0+ |
| `INDEXER_TOKEN_INSTANCE_RETRY_EXPONENTIAL_TIMEOUT_BASE`               |          | Base to calculate exponential timeout. Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                                          | `2`                                      | v6.6.0+ |
| `INDEXER_TOKEN_INSTANCE_RETRY_EXPONENTIAL_TIMEOUT_COEFF`               |          | Coefficient to calculate exponential timeout. Implemented in [#10027](https://github.com/blockscout/blockscout/pull/10027).                                                                                                                                                                                                                                                                                                                                          | `100`                                      | v6.6.0+ |
| `INDEXER_TOKEN_INSTANCE_REALTIME_RETRY_ENABLED`                       |          | If `true`, `realtime` token instance fetcher will retry once on 404 and 500 error. Implemented in [#10036](https://github.com/blockscout/blockscout/pull/10036). | `false`                                    | v6.6.0+ |
| `INDEXER_TOKEN_INSTANCE_REALTIME_RETRY_TIMEOUT`               |          | Timeout for retry set by `INDEXER_TOKEN_INSTANCE_REALTIME_RETRY_ENABLED`. [Time format](env-variables.md#time-format). Implemented in [#10036](https://github.com/blockscout/blockscout/pull/10036). | `5s`                                    | v6.6.0+ |
| `TEST_DATABASE_URL`                               |          | Variable to define the endpoint of the Postgres Database that is used during testing. Implemented in [#9662](https://github.com/blockscout/blockscout/pull/9662).                                                                                                                                                                                          | (empty)                                                | v6.6.0+     |                |
| `TEST_DATABASE_READ_ONLY_API_URL`                 |          | Variable to define the endpoint of the Postgres Database read-only replica that is used during testing. If it is provided, most of the read queries from API v2 and UI would go through this endpoint. Implemented in [#9662](https://github.com/blockscout/blockscout/pull/9662).                                                                         | (empty)                                                | v6.6.0+     |                |
| `MUD_INDEXER_ENABLED` |          | If `true`, integration with [MUD](https://mud.dev/services/indexer#schemaless-indexing-with-postgresql-via-docker) is enabled. Implemented in [#9869](https://github.com/blockscout/blockscout/pull/9869) | (empty)                   | v6.6.0+  | |
| `MUD_DATABASE_URL`    |          | MUD indexer DB connection URL.                                                                                                                                                                            | value from `DATABASE_URL` | v6.6.0+  | |
| `MUD_POOL_SIZE`       |          | MUD indexer DB `pool_size`                                                                                                                                                                                | 50                        | v6.6.0+  | |

### Deprecated ENV Variables

| Variable                                              | Required | Description                                                                                                                                                                                                                                                                                                                                        | Default                                                                                       | Version  | Need recompile | Deprecated in Version |
| ----------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | -------- | -------------- | --------------------- |
| `INDEXER_TOKEN_INSTANCE_RETRY_REFETCH_INTERVAL`               |          | Interval between attempts to fetch token instance metadata. [Time format](env-variables.md#time-format). Implemented in [#7286](https://github.com/blockscout/blockscout/pull/7286).   | `24h`                                      | v5.1.4+ | | v6.6.0 |
| `INDEXER_INTERNAL_TRANSACTIONS_INDEXING_FINISHED_THRESHOLD` | | In the case when the 1st tx in the chain already has internal transactions, If the number of blocks in pending\_block\_operations is less than the value in this env var, Blockscout will consider, that indexing of internal transactions finished, otherwise, it will consider, that indexing is still taking place and the indexing banner will appear at the top. Implemented in [#7576](https://github.com/blockscout/blockscout/pull/7576). | 1000 | v5.2.0+ | | v6.6.0 |

## 6.5.0

### 🚀 Features

- Certified smart contracts ([#9910](https://github.com/blockscout/blockscout/issues/9910))
- Exit on provided invalid CHAIN_TYPE ([#9904](https://github.com/blockscout/blockscout/issues/9904))
- IPFS gateway URL extra params ([#9898](https://github.com/blockscout/blockscout/issues/9898))
- Zerion API proxy ([#9896](https://github.com/blockscout/blockscout/issues/9896))
- Support Optimism Fault Proofs ([#9892](https://github.com/blockscout/blockscout/issues/9892))
- Return number of days in address's coin-balance-history-by-day API v2 endpoint ([#9806](https://github.com/blockscout/blockscout/issues/9806))
- Allow the use of Coingecko demo account ([#9835](https://github.com/blockscout/blockscout/issues/9835))

### 🐛 Bug Fixes

- Set refetch_needed: false on block import ([#9953](https://github.com/blockscout/blockscout/issues/9953))
- `GAS_PRICE_ORACLE_NUM_OF_BLOCKS` calculation ([#9943](https://github.com/blockscout/blockscout/issues/9943))
- Handle "null" filter in api/v1/logs-csv ([#9933](https://github.com/blockscout/blockscout/issues/9933))
- Fix metadata preload ([#9925](https://github.com/blockscout/blockscout/issues/9925))
- `coin_price_change_percentage` calculation ([#9774](https://github.com/blockscout/blockscout/issues/9774))
- Remove backend dependency in microservices.yml ([#9905](https://github.com/blockscout/blockscout/issues/9905))
- Expand memory only if it was shrunk ([#9907](https://github.com/blockscout/blockscout/issues/9907))
- Coin balances fetcher error logging ([#9902](https://github.com/blockscout/blockscout/issues/9902))
- Refactor catchup rudimentaries + fix graceful shutdown ([#9729](https://github.com/blockscout/blockscout/issues/9729))
- Handle transactions with `gas_price` set to `nil` in `transaction_revert_reason/2` ([#9647](https://github.com/blockscout/blockscout/issues/9647))
- Correct processing of sized array to view in API v2 ([#9854](https://github.com/blockscout/blockscout/issues/9854))
- Broadcast realtime coin balances ([#9804](https://github.com/blockscout/blockscout/issues/9804))
- Disable BlockReward fetcher for unsupported variants ([#9859](https://github.com/blockscout/blockscout/issues/9859))
- Add non-unique log_index support in update_token_instances_owner ([#9862](https://github.com/blockscout/blockscout/issues/9862))

### ⚡ Performance

- Paging function edge cases fix ([#9820](https://github.com/blockscout/blockscout/issues/9820))
- Adjust unfetched_address_token_balances_index to fit all bound query conditions ([#9912](https://github.com/blockscout/blockscout/issues/9912))
- Enhance index for token holders list ([#9816](https://github.com/blockscout/blockscout/issues/9816))
- Improve performance of token page transfers tab ([#9809](https://github.com/blockscout/blockscout/issues/9809))

### ⚙️ Miscellaneous Tasks

- Fix some typos in comments ([#9900](https://github.com/blockscout/blockscout/issues/9900))
- Add queue expanding logic to memory monitor ([#9870](https://github.com/blockscout/blockscout/issues/9870))
- Bump ex_doc from 0.31.2 to 0.32.1 ([#9889](https://github.com/blockscout/blockscout/issues/9889))
- Separate reorgs from blocks that just need refetch ([#9674](https://github.com/blockscout/blockscout/issues/9674))
- Unknown token in email template ([#9883](https://github.com/blockscout/blockscout/issues/9883))
- Bump tesla from 1.8.0 to 1.9.0 ([#9886](https://github.com/blockscout/blockscout/issues/9886))
- Bump logger_file_backend from 0.0.13 to 0.0.14 ([#9885](https://github.com/blockscout/blockscout/issues/9885))
- Bump cloak_ecto from 1.2.0 to 1.3.0 ([#9890](https://github.com/blockscout/blockscout/issues/9890))
- Bump ex_secp256k1 from 0.7.2 to 0.7.3 ([#9888](https://github.com/blockscout/blockscout/issues/9888))
- Bump ex_cldr_units from 3.16.4 to 3.16.5 ([#9884](https://github.com/blockscout/blockscout/issues/9884))
- Move `has_methods_*` fields to `/smart-contracts` endpoint response ([#9599](https://github.com/blockscout/blockscout/issues/9599))
- Add metrics for realtime event handlers queue length ([#9822](https://github.com/blockscout/blockscout/issues/9822))
- Increase MissingRangesCollector past check interval after the first cycle ([#9872](https://github.com/blockscout/blockscout/issues/9872))
- Reduce number of warnings in web tests ([#9851](https://github.com/blockscout/blockscout/issues/9851))
- Fix some typos in comments ([#9838](https://github.com/blockscout/blockscout/issues/9838))
- Bump ex_abi from 0.7.1 to 0.7.2 ([#9841](https://github.com/blockscout/blockscout/issues/9841))
- Remove /config/json-rpc-url API endpoint ([#9798](https://github.com/blockscout/blockscout/issues/9798))
- Bump junit_formatter from 3.3.1 to 3.4.0 ([#9842](https://github.com/blockscout/blockscout/issues/9842))
- Bump number from 1.0.4 to 1.0.5 ([#9843](https://github.com/blockscout/blockscout/issues/9843))
- Bump absinthe_phoenix from 2.0.2 to 2.0.3 ([#9840](https://github.com/blockscout/blockscout/issues/9840))
- Bump plug_cowboy from 2.7.0 to 2.7.1 ([#9844](https://github.com/blockscout/blockscout/issues/9844))

## 6.4.0

### 🚀 Features

- Secondary coin price in `api/v2/stats` ([#9777](https://github.com/blockscout/blockscout/issues/9777))
- Add /api/v2/blocks/{hash_or_number}/internal-transactions endpoint ([#9668](https://github.com/blockscout/blockscout/issues/9668))
- Integrate Metadata microservice ([#9706](https://github.com/blockscout/blockscout/issues/9706))
- Support verifier alliance and eth-bytecode-db v1.7.0 changes ([#9724](https://github.com/blockscout/blockscout/issues/9724))
- Add rate limits to graphQL API ([#9771](https://github.com/blockscout/blockscout/issues/9771))
- Support for internal user operation calldata decoded by microservice ([#9776](https://github.com/blockscout/blockscout/issues/9776))
- Internal txs fetching for Arbitrum ([#9737](https://github.com/blockscout/blockscout/issues/9737))
- Allow for custom base_url for fetching prices ([#9679](https://github.com/blockscout/blockscout/issues/9679))
- Contract code on-demand fetcher ([#9708](https://github.com/blockscout/blockscout/issues/9708))
- Add /api/v2/tokens/:address_hash_param/holders/csv endpoint ([#9722](https://github.com/blockscout/blockscout/issues/9722))
- Support the 2nd version of L2<->L1 Polygon zkEVM Bridge ([#9637](https://github.com/blockscout/blockscout/issues/9637))
- GraphQL management env vars ([#9751](https://github.com/blockscout/blockscout/issues/9751))
- Improvements in zksync batch related transactions requests ([#9680](https://github.com/blockscout/blockscout/issues/9680))
- Add trying to decode internal calldata for user ops ([#9675](https://github.com/blockscout/blockscout/issues/9675))

### 🐛 Bug Fixes

- Apply quantity_to_integer/1 to effectiveGasPrice ([#9812](https://github.com/blockscout/blockscout/issues/9812))
- Replace tx gas_price with effectiveGasPrice from receipt ([#9733](https://github.com/blockscout/blockscout/issues/9733))
- Fetching GraphQL schema by GraphiQL IDE ([#9630](https://github.com/blockscout/blockscout/issues/9630))
- Add block range check into OP Withdrawals fetcher ([#9770](https://github.com/blockscout/blockscout/issues/9770))
- Update token's holder_count in the db from ETS module ([#9623](https://github.com/blockscout/blockscout/issues/9623))
- Fix UTF-8 json handling in NFT metadata fetching ([#9707](https://github.com/blockscout/blockscout/issues/9707))
- Separate ZkSync and ZkEvm readers in API controller ([#9749](https://github.com/blockscout/blockscout/issues/9749))
- Add missing preloads ([#9520](https://github.com/blockscout/blockscout/issues/9520))
- Change CoinGecko token image attribute priority ([#9671](https://github.com/blockscout/blockscout/issues/9671))
- Fix Geth block tracing errors handling ([#9672](https://github.com/blockscout/blockscout/issues/9672))
- Erc-404 token transfers null value ([#9698](https://github.com/blockscout/blockscout/issues/9698))
- Erc-404 type stored in token balances tables ([#9700](https://github.com/blockscout/blockscout/issues/9700))

### 🚜 Refactor

- `Enum.count` to `Enum.empty?` ([#9666](https://github.com/blockscout/blockscout/issues/9666))

### ⚡ Performance

- Add EIP4844 blob transactions index ([#9661](https://github.com/blockscout/blockscout/issues/9661))

### ⚙️ Miscellaneous Tasks

- Rework chain type matrix in CI runs ([#9704](https://github.com/blockscout/blockscout/issues/9704))
- Exclude latest tag update from alpha releases ([#9800](https://github.com/blockscout/blockscout/issues/9800))
- Reduce default API v1 limit by key 50 -> 10 ([#9799](https://github.com/blockscout/blockscout/issues/9799))
- Bump autoprefixer in /apps/block_scout_web/assets ([#9786](https://github.com/blockscout/blockscout/issues/9786))
- Remove /api/account/v1 path ([#9660](https://github.com/blockscout/blockscout/issues/9660))
- Bump sass from 1.71.1 to 1.72.0 in /apps/block_scout_web/assets ([#9780](https://github.com/blockscout/blockscout/issues/9780))
- Bump @babel/core in /apps/block_scout_web/assets ([#9782](https://github.com/blockscout/blockscout/issues/9782))
- Bump webpack in /apps/block_scout_web/assets ([#9787](https://github.com/blockscout/blockscout/issues/9787))
- Bump postcss in /apps/block_scout_web/assets ([#9785](https://github.com/blockscout/blockscout/issues/9785))
- Bump @amplitude/analytics-browser in /apps/block_scout_web/assets ([#9788](https://github.com/blockscout/blockscout/issues/9788))
- Bump solc from 0.8.24 to 0.8.25 in /apps/explorer ([#9789](https://github.com/blockscout/blockscout/issues/9789))
- Bump sweetalert2 in /apps/block_scout_web/assets ([#9783](https://github.com/blockscout/blockscout/issues/9783))
- Bump @babel/preset-env in /apps/block_scout_web/assets ([#9784](https://github.com/blockscout/blockscout/issues/9784))
- Bump core-js in /apps/block_scout_web/assets ([#9781](https://github.com/blockscout/blockscout/issues/9781))
- Enable Rust sc-verifier microservice by default ([#9752](https://github.com/blockscout/blockscout/issues/9752))
- Temporarily ignore OP batches written to Celestia ([#9734](https://github.com/blockscout/blockscout/issues/9734))
- Bump cldr_utils from 2.24.2 to 2.25.0 ([#9723](https://github.com/blockscout/blockscout/issues/9723))
- Bump express in /apps/block_scout_web/assets ([#9725](https://github.com/blockscout/blockscout/issues/9725))
- Bump bureaucrat from 0.2.9 to 0.2.10 ([#9669](https://github.com/blockscout/blockscout/issues/9669))
- Fix typos ([#9693](https://github.com/blockscout/blockscout/issues/9693))
- Bump follow-redirects from 1.15.4 to 1.15.6 in /apps/explorer ([#9648](https://github.com/blockscout/blockscout/issues/9648))
- Bump floki from 0.36.0 to 0.36.1 ([#9670](https://github.com/blockscout/blockscout/issues/9670))
- Use git-cliff changelog generator ([#9687](https://github.com/blockscout/blockscout/issues/9687))

## 6.3.0

### Features

- [#9631](https://github.com/blockscout/blockscout/pull/9631) - Initial support of zksync chain type
- [#9532](https://github.com/blockscout/blockscout/pull/9532) - Add last output root size counter
- [#9511](https://github.com/blockscout/blockscout/pull/9511) - Separate errors by type in EndpointAvailabilityObserver
- [#9490](https://github.com/blockscout/blockscout/pull/9490), [#9644](https://github.com/blockscout/blockscout/pull/9644) - Add blob transaction counter and filter in block view
- [#9486](https://github.com/blockscout/blockscout/pull/9486) - Massive blocks fetcher
- [#9483](https://github.com/blockscout/blockscout/pull/9483) - Add secondary coin and transaction stats
- [#9473](https://github.com/blockscout/blockscout/pull/9473) - Add user_op interpretation
- [#9461](https://github.com/blockscout/blockscout/pull/9461) - Fetch blocks without internal transactions backwards
- [#9460](https://github.com/blockscout/blockscout/pull/9460) - Optimism chain type
- [#9409](https://github.com/blockscout/blockscout/pull/9409) - ETH JSON RPC extension
- [#9390](https://github.com/blockscout/blockscout/pull/9390) - Add stability validators
- [#8702](https://github.com/blockscout/blockscout/pull/8702) - Add OP withdrawal status to transaction page in API
- [#7200](https://github.com/blockscout/blockscout/pull/7200) - Add Optimism BedRock Deposits to the main page in API
- [#6980](https://github.com/blockscout/blockscout/pull/6980) - Add Optimism BedRock support (Txn Batches, Output Roots, Deposits, Withdrawals)

### Fixes

- [#9654](https://github.com/blockscout/blockscout/pull/9654) - Send timeout param in debug_traceBlockByNumber request
- [#9653](https://github.com/blockscout/blockscout/pull/9653) - Tokens import improvements
- [#9652](https://github.com/blockscout/blockscout/pull/9652) - Remove duplicated tx hashes while indexing OP batches
- [#9646](https://github.com/blockscout/blockscout/pull/9646) - Hotfix for Optimism Ecotone batch blobs indexing
- [#9640](https://github.com/blockscout/blockscout/pull/9640) - Fix no function clause matching in `BENS.item_to_address_hash_strings/1`
- [#9638](https://github.com/blockscout/blockscout/pull/9638) - Do not broadcast coin balance changes with empty value/delta
- [#9635](https://github.com/blockscout/blockscout/pull/9635) - Reset missing ranges collector to max number after the cycle is done
- [#9629](https://github.com/blockscout/blockscout/pull/9629) - Don't insert pbo for not inserted blocks
- [#9620](https://github.com/blockscout/blockscout/pull/9620) - Fix infinite retries for orphaned blobs
- [#9601](https://github.com/blockscout/blockscout/pull/9601) - Fix token instance transform for some unconventional tokens
- [#9597](https://github.com/blockscout/blockscout/pull/9597) - Update token transfers block_consensus by block_number
- [#9596](https://github.com/blockscout/blockscout/pull/9596) - Fix logging
- [#9585](https://github.com/blockscout/blockscout/pull/9585) - Fix Geth block internal transactions fetching
- [#9576](https://github.com/blockscout/blockscout/pull/9576) - Rewrite query for token transfers on address to eliminate "or"
- [#9572](https://github.com/blockscout/blockscout/pull/9572) - Fix Shibarium L1 fetcher
- [#9563](https://github.com/blockscout/blockscout/pull/9563) - Fix timestamp handler for unfinalized zkEVM batches
- [#9560](https://github.com/blockscout/blockscout/pull/9560) - Fix fetch pending transaction for hyperledger besu client
- [#9555](https://github.com/blockscout/blockscout/pull/9555) - Fix EIP-1967 beacon proxy pattern detection
- [#9529](https://github.com/blockscout/blockscout/pull/9529) - Fix `MAX_SAFE_INTEGER` frontend bug
- [#9518](https://github.com/blockscout/blockscout/pull/9518), [#9628](https://github.com/blockscout/blockscout/pull/9628) - Fix MultipleResultsError in `smart_contract_creation_tx_bytecode/1`
- [#9514](https://github.com/blockscout/blockscout/pull/9514) - Fix missing `0x` prefix for `blockNumber`, `logIndex`, `transactionIndex` and remove `transactionLogIndex` in `eth_getLogs` response.
- [#9510](https://github.com/blockscout/blockscout/pull/9510) - Fix WS false 0 token balances
- [#9512](https://github.com/blockscout/blockscout/pull/9512) - Docker-compose 2.24.6 compatibility
- [#9407](https://github.com/blockscout/blockscout/pull/9407) - ERC-404 basic support
- [#9262](https://github.com/blockscout/blockscout/pull/9262) - Fix withdrawal status
- [#9123](https://github.com/blockscout/blockscout/pull/9123) - Fixes in Optimism due to changed log topics type
- [#8831](https://github.com/blockscout/blockscout/pull/8831) - Return all OP Withdrawals bound to L2 transaction
- [#8822](https://github.com/blockscout/blockscout/pull/8822) - Hotfix for optimism_withdrawal_transaction_status function
- [#8811](https://github.com/blockscout/blockscout/pull/8811) - Consider consensus block only when retrieving OP withdrawal transaction status
- [#8364](https://github.com/blockscout/blockscout/pull/8364) - Fix API v2 for OP Withdrawals
- [#8229](https://github.com/blockscout/blockscout/pull/8229) - Fix Indexer.Fetcher.OptimismTxnBatch
- [#8208](https://github.com/blockscout/blockscout/pull/8208) - Ignore invalid frame by OP transaction batches module
- [#8122](https://github.com/blockscout/blockscout/pull/8122) - Ignore previously handled frame by OP transaction batches module
- [#7827](https://github.com/blockscout/blockscout/pull/7827) - Fix transaction batches module for L2 OP stack
- [#7776](https://github.com/blockscout/blockscout/pull/7776) - Fix transactions ordering in Indexer.Fetcher.OptimismTxnBatch
- [#7219](https://github.com/blockscout/blockscout/pull/7219) - Output L1 fields in API v2 for transaction page and fix transaction fee calculation
- [#6699](https://github.com/blockscout/blockscout/pull/6699) - L1 tx fields fix for Goerli Optimism BedRock update

### Chore

- [#9622](https://github.com/blockscout/blockscout/pull/9622) - Add alternative `hex.pm` mirrors
- [#9571](https://github.com/blockscout/blockscout/pull/9571) - Support Optimism Ecotone upgrade by Indexer.Fetcher.Optimism.TxnBatch module
- [#9562](https://github.com/blockscout/blockscout/pull/9562) - Add cancun evm version
- [#9506](https://github.com/blockscout/blockscout/pull/9506) - API v1 bridgedtokenlist endpoint
- [#9260](https://github.com/blockscout/blockscout/pull/9260) - Optimism Delta upgrade support by Indexer.Fetcher.OptimismTxnBatch module
- [#8740](https://github.com/blockscout/blockscout/pull/8740) - Add delay to Indexer.Fetcher.OptimismTxnBatch module initialization

<details>
  <summary>Dependencies version bumps</summary>

- [#9544](https://github.com/blockscout/blockscout/pull/9544) - Bump @babel/core from 7.23.9 to 7.24.0 in /apps/block_scout_web/assets
- [#9537](https://github.com/blockscout/blockscout/pull/9537) - Bump logger_json from 5.1.3 to 5.1.4
- [#9550](https://github.com/blockscout/blockscout/pull/9550) - Bump xss from 1.0.14 to 1.0.15 in /apps/block_scout_web/assets
- [#9539](https://github.com/blockscout/blockscout/pull/9539) - Bump floki from 0.35.4 to 0.36.0
- [#9551](https://github.com/blockscout/blockscout/pull/9551) - Bump @amplitude/analytics-browser from 2.5.1 to 2.5.2 in /apps/block_scout_web/assets
- [#9547](https://github.com/blockscout/blockscout/pull/9547) - Bump @babel/preset-env from 7.23.9 to 7.24.0 in /apps/block_scout_web/assets
- [#9549](https://github.com/blockscout/blockscout/pull/9549) - Bump postcss-loader from 8.1.0 to 8.1.1 in /apps/block_scout_web/assets
- [#9542](https://github.com/blockscout/blockscout/pull/9542) - Bump phoenix_ecto from 4.4.3 to 4.5.0
- [#9546](https://github.com/blockscout/blockscout/pull/9546) - https://github.com/blockscout/blockscout/pull/9546
- [#9545](https://github.com/blockscout/blockscout/pull/9545) - Bump chart.js from 4.4.1 to 4.4.2 in /apps/block_scout_web/assets
- [#9540](https://github.com/blockscout/blockscout/pull/9540) - Bump postgrex from 0.17.4 to 0.17.5
- [#9543](https://github.com/blockscout/blockscout/pull/9543) - Bump ueberauth from 0.10.7 to 0.10.8
- [#9538](https://github.com/blockscout/blockscout/pull/9538) - Bump credo from 1.7.4 to 1.7.5
- [#9607](https://github.com/blockscout/blockscout/pull/9607) - Bump redix from 1.3.0 to 1.4.1
- [#9606](https://github.com/blockscout/blockscout/pull/9606) - Bump ecto from 3.11.1 to 3.11.2
- [#9605](https://github.com/blockscout/blockscout/pull/9605) - Bump ex_doc from 0.31.1 to 0.31.2
- [#9604](https://github.com/blockscout/blockscout/pull/9604) - Bump phoenix_ecto from 4.5.0 to 4.5.1

</details>

## 6.2.2

### Features

### Fixes

- [#9505](https://github.com/blockscout/blockscout/pull/9505) - Add env vars for NFT sanitize migration

### Chore

- [#9487](https://github.com/blockscout/blockscout/pull/9487) - Add tsvector index on smart_contracts.name

<details>
  <summary>Dependencies version bumps</summary>

</details>

## 6.2.1

### Features

### Fixes

- [#9591](https://github.com/blockscout/blockscout/pull/9591) - Fix duplicated results in `methods-read` endpoint
- [#9502](https://github.com/blockscout/blockscout/pull/9502) - Add batch_size and concurrency envs for tt token type migration
- [#9493](https://github.com/blockscout/blockscout/pull/9493) - Fix API response for unknown blob hashes
- [#9484](https://github.com/blockscout/blockscout/pull/9484) - Fix read contract error
- [#9426](https://github.com/blockscout/blockscout/pull/9426) - Fix tabs counter cache bug

### Chore

<details>
  <summary>Dependencies version bumps</summary>

- [#9478](https://github.com/blockscout/blockscout/pull/9478) - Bump floki from 0.35.3 to 0.35.4
- [#9477](https://github.com/blockscout/blockscout/pull/9477) - Bump hammer from 6.2.0 to 6.2.1
- [#9476](https://github.com/blockscout/blockscout/pull/9476) - Bump eslint from 8.56.0 to 8.57.0 in /apps/block_scout_web/assets
- [#9475](https://github.com/blockscout/blockscout/pull/9475) - Bump @amplitude/analytics-browser from 2.4.1 to 2.5.1 in /apps/block_scout_web/assets
- [#9474](https://github.com/blockscout/blockscout/pull/9474) - Bump sass from 1.71.0 to 1.71.1 in /apps/block_scout_web/assets
- [#9492](https://github.com/blockscout/blockscout/pull/9492) - Bump es5-ext from 0.10.62 to 0.10.64 in /apps/block_scout_web/assets

</details>

## 6.2.0

### Features

- [#9441](https://github.com/blockscout/blockscout/pull/9441) - Update BENS integration: change endpoint for resolving address in search
- [#9437](https://github.com/blockscout/blockscout/pull/9437) - Add Enum.uniq before sanitizing token transfers
- [#9403](https://github.com/blockscout/blockscout/pull/9403) - Null round handling
- [#9401](https://github.com/blockscout/blockscout/pull/9401) - Eliminate incorrect token transfers with empty token_ids
- [#9396](https://github.com/blockscout/blockscout/pull/9396) - More-Minimal Proxy support
- [#9386](https://github.com/blockscout/blockscout/pull/9386) - Filecoin JSON RPC variant
- [#9379](https://github.com/blockscout/blockscout/pull/9379) - Filter non-traceable transactions for zetachain
- [#9364](https://github.com/blockscout/blockscout/pull/9364) - Fix using of startblock/endblock in API v1 list endpoints: txlist, txlistinternal, tokentx
- [#9360](https://github.com/blockscout/blockscout/pull/9360) - Move missing ranges sanitize to a separate background migration
- [#9351](https://github.com/blockscout/blockscout/pull/9351) - Noves.fi: add proxy endpoint for describeTxs endpoint
- [#9282](https://github.com/blockscout/blockscout/pull/9282) - Add `license_type` to smart contracts
- [#9202](https://github.com/blockscout/blockscout/pull/9202) - Add base and priority fee to gas oracle response
- [#9182](https://github.com/blockscout/blockscout/pull/9182) - Fetch coin balances in async mode in realtime fetcher
- [#9168](https://github.com/blockscout/blockscout/pull/9168) - Support EIP4844 blobs indexing & API
- [#9098](https://github.com/blockscout/blockscout/pull/9098) - Polygon zkEVM Bridge indexer and API v2 extension

### Fixes

- [#9444](https://github.com/blockscout/blockscout/pull/9444) - Fix quick search bug
- [#9440](https://github.com/blockscout/blockscout/pull/9440) - Add `debug_traceBlockByNumber` to `method_to_url`
- [#9387](https://github.com/blockscout/blockscout/pull/9387) - Filter out Vyper contracts in Solidityscan API endpoint
- [#9377](https://github.com/blockscout/blockscout/pull/9377) - Speed up account abstraction proxy
- [#9371](https://github.com/blockscout/blockscout/pull/9371) - Filter empty values before token update
- [#9356](https://github.com/blockscout/blockscout/pull/9356) - Remove ERC-1155 logs params from coin balances params
- [#9346](https://github.com/blockscout/blockscout/pull/9346) - Process integer balance in genesis.json
- [#9317](https://github.com/blockscout/blockscout/pull/9317) - Include null gas price txs in fee calculations
- [#9315](https://github.com/blockscout/blockscout/pull/9315) - Fix manual uncle reward calculation
- [#9306](https://github.com/blockscout/blockscout/pull/9306) - Improve marking of failed internal transactions
- [#9305](https://github.com/blockscout/blockscout/pull/9305) - Add effective gas price calculation as fallback
- [#9300](https://github.com/blockscout/blockscout/pull/9300) - Fix read contract bug
- [#9226](https://github.com/blockscout/blockscout/pull/9226) - Split Indexer.Fetcher.TokenInstance.LegacySanitize

### Chore

- [#9439](https://github.com/blockscout/blockscout/pull/9439) - Solidityscan integration enhancements
- [#9398](https://github.com/blockscout/blockscout/pull/9398) - Improve elixir dependencies caching in CI
- [#9393](https://github.com/blockscout/blockscout/pull/9393) - Bump actions/cache to v4
- [#9389](https://github.com/blockscout/blockscout/pull/9389) - Output user address as an object in API v2 for Shibarium
- [#9361](https://github.com/blockscout/blockscout/pull/9361) - Define BRIDGED_TOKENS_ENABLED env in Dockerfile
- [#9257](https://github.com/blockscout/blockscout/pull/9257) - Retry token instance metadata fetch from baseURI + tokenID
- [#8851](https://github.com/blockscout/blockscout/pull/8851) - Fix dialyzer and add TypedEctoSchema

<details>
  <summary>Dependencies version bumps</summary>

- [#9335](https://github.com/blockscout/blockscout/pull/9335) - Bump mini-css-extract-plugin from 2.7.7 to 2.8.0 in /apps/block_scout_web/assets
- [#9333](https://github.com/blockscout/blockscout/pull/9333) - Bump sweetalert2 from 11.10.3 to 11.10.5 in /apps/block_scout_web/assets
- [#9288](https://github.com/blockscout/blockscout/pull/9288) - Bump solc from 0.8.23 to 0.8.24 in /apps/explorer
- [#9287](https://github.com/blockscout/blockscout/pull/9287) - Bump @babel/preset-env from 7.23.8 to 7.23.9 in /apps/block_scout_web/assets
- [#9331](https://github.com/blockscout/blockscout/pull/9331) - Bump logger_json from 5.1.2 to 5.1.3
- [#9330](https://github.com/blockscout/blockscout/pull/9330) - Bump hammer from 6.1.0 to 6.2.0
- [#9294](https://github.com/blockscout/blockscout/pull/9294) - Bump exvcr from 0.15.0 to 0.15.1
- [#9293](https://github.com/blockscout/blockscout/pull/9293) - Bump floki from 0.35.2 to 0.35.3
- [#9338](https://github.com/blockscout/blockscout/pull/9338) - Bump postcss-loader from 8.0.0 to 8.1.0 in /apps/block_scout_web/assets
- [#9336](https://github.com/blockscout/blockscout/pull/9336) - Bump web3 from 1.10.3 to 1.10.4 in /apps/block_scout_web/assets
- [#9290](https://github.com/blockscout/blockscout/pull/9290) - Bump ex_doc from 0.31.0 to 0.31.1
- [#9285](https://github.com/blockscout/blockscout/pull/9285) - Bump @amplitude/analytics-browser from 2.3.8 to 2.4.0 in /apps/block_scout_web/assets
- [#9283](https://github.com/blockscout/blockscout/pull/9283) - Bump @babel/core from 7.23.7 to 7.23.9 in /apps/block_scout_web/assets
- [#9337](https://github.com/blockscout/blockscout/pull/9337) - Bump css-loader from 6.9.1 to 6.10.0 in /apps/block_scout_web/assets
- [#9334](https://github.com/blockscout/blockscout/pull/9334) - Bump sass-loader from 14.0.0 to 14.1.0 in /apps/block_scout_web/assets
- [#9339](https://github.com/blockscout/blockscout/pull/9339) - Bump webpack from 5.89.0 to 5.90.1 in /apps/block_scout_web/assets
- [#9383](https://github.com/blockscout/blockscout/pull/9383) - Bump credo from 1.7.3 to 1.7.4
- [#9384](https://github.com/blockscout/blockscout/pull/9384) - Bump postcss from 8.4.33 to 8.4.35 in /apps/block_scout_web/assets
- [#9385](https://github.com/blockscout/blockscout/pull/9385) - Bump mixpanel-browser from 2.48.1 to 2.49.0 in /apps/block_scout_web/assets
- [#9423](https://github.com/blockscout/blockscout/pull/9423) - Bump @amplitude/analytics-browser from 2.4.0 to 2.4.1 in /apps/block_scout_web/assets
- [#9422](https://github.com/blockscout/blockscout/pull/9422) - Bump core-js from 3.35.1 to 3.36.0 in /apps/block_scout_web/assets
- [#9424](https://github.com/blockscout/blockscout/pull/9424) - Bump webpack from 5.90.1 to 5.90.3 in /apps/block_scout_web/assets
- [#9425](https://github.com/blockscout/blockscout/pull/9425) - Bump sass-loader from 14.1.0 to 14.1.1 in /apps/block_scout_web/assets
- [#9421](https://github.com/blockscout/blockscout/pull/9421) - Bump sass from 1.70.0 to 1.71.0 in /apps/block_scout_web/assets

</details>

## 6.1.0

### Features

- [#9189](https://github.com/blockscout/blockscout/pull/9189) - User operations in the search
- [#9169](https://github.com/blockscout/blockscout/pull/9169) - Add bridged tokens functionality to master branch
- [#9158](https://github.com/blockscout/blockscout/pull/9158) - Increase shared memory for PostgreSQL containers
- [#9155](https://github.com/blockscout/blockscout/pull/9155) - Allow bypassing avg block time in proxy implementation re-fetch ttl calculation
- [#9148](https://github.com/blockscout/blockscout/pull/9148) - Add `/api/v2/utils/decode-calldata`
- [#9145](https://github.com/blockscout/blockscout/pull/9145), [#9309](https://github.com/blockscout/blockscout/pull/9309) - Proxy for Account abstraction microservice
- [#9132](https://github.com/blockscout/blockscout/pull/9132) - Fetch token image from CoinGecko
- [#9131](https://github.com/blockscout/blockscout/pull/9131) - Merge addresses stage with address referencing
- [#9120](https://github.com/blockscout/blockscout/pull/9120) - Add GET and POST `/api/v2/smart-contracts/:address_hash/audit-reports`
- [#9072](https://github.com/blockscout/blockscout/pull/9072) - Add tracing by block logic for geth
- [#9185](https://github.com/blockscout/blockscout/pull/9185), [#9068](https://github.com/blockscout/blockscout/pull/9068) - New RPC API v1 endpoints
- [#9056](https://github.com/blockscout/blockscout/pull/9056) - Noves.fi API proxy

### Fixes

- [#9275](https://github.com/blockscout/blockscout/pull/9275) - Tx summary endpoint fixes
- [#9261](https://github.com/blockscout/blockscout/pull/9261) - Fix pending transactions sanitizer
- [#9253](https://github.com/blockscout/blockscout/pull/9253) - Don't fetch first trace for pending transactions
- [#9241](https://github.com/blockscout/blockscout/pull/9241) - Fix log decoding bug
- [#9234](https://github.com/blockscout/blockscout/pull/9234) - Add missing filters by non-pending transactions
- [#9229](https://github.com/blockscout/blockscout/pull/9229) - Add missing filter to txlist query
- [#9195](https://github.com/blockscout/blockscout/pull/9195) - API v1 allow multiple slashes in the path before "api"
- [#9187](https://github.com/blockscout/blockscout/pull/9187) - Fix Internal Server Error on request for nonexistent token instance
- [#9178](https://github.com/blockscout/blockscout/pull/9178) - Change internal txs tracer type to opcode for Hardhat node
- [#9173](https://github.com/blockscout/blockscout/pull/9173) - Exclude genesis block from average block time calculation
- [#9143](https://github.com/blockscout/blockscout/pull/9143) - Handle nil token_ids in token transfers on render
- [#9139](https://github.com/blockscout/blockscout/pull/9139) - TokenBalanceOnDemand fixes
- [#9125](https://github.com/blockscout/blockscout/pull/9125) - Fix Explorer.Chain.Cache.GasPriceOracle.merge_fees
- [#9124](https://github.com/blockscout/blockscout/pull/9124) - EIP-1167 display multiple sources of implementation
- [#9110](https://github.com/blockscout/blockscout/pull/9110) - Improve update_in in gas tracker
- [#9109](https://github.com/blockscout/blockscout/pull/9109) - Return current exchange rate in api/v2/stats
- [#9102](https://github.com/blockscout/blockscout/pull/9102) - Fix some log topics for Suave and Polygon Edge
- [#9075](https://github.com/blockscout/blockscout/pull/9075) - Fix fetching contract codes
- [#9073](https://github.com/blockscout/blockscout/pull/9073) - Allow payable function with output appear in the Read tab
- [#9069](https://github.com/blockscout/blockscout/pull/9069) - Fetch realtime coin balances only for addresses for which it has changed

### Chore

- [#9323](https://github.com/blockscout/blockscout/pull/9323) - Change index creation to concurrent
- [#9322](https://github.com/blockscout/blockscout/pull/9322) - Create repo setup actions
- [#9303](https://github.com/blockscout/blockscout/pull/9303) - Add workflow for Shibarium
- [#9233](https://github.com/blockscout/blockscout/pull/9233) - "cataloged" index on tokens table
- [#9198](https://github.com/blockscout/blockscout/pull/9198) - Make Postgres@15 default option
- [#9197](https://github.com/blockscout/blockscout/pull/9197) - Add `MARKET_HISTORY_FETCH_INTERVAL` env
- [#9196](https://github.com/blockscout/blockscout/pull/9196) - Compatibility with docker-compose 2.24
- [#9193](https://github.com/blockscout/blockscout/pull/9193) - Equalize elixir stack versions
- [#9153](https://github.com/blockscout/blockscout/pull/9153) - Enhanced unfetched token balances index

<details>
  <summary>Dependencies version bumps</summary>

- [#9119](https://github.com/blockscout/blockscout/pull/9119) - Bump sass from 1.69.6 to 1.69.7 in /apps/block_scout_web/assets
- [#9126](https://github.com/blockscout/blockscout/pull/9126) - Bump follow-redirects from 1.14.8 to 1.15.4 in /apps/explorer
- [#9116](https://github.com/blockscout/blockscout/pull/9116) - Bump ueberauth from 0.10.5 to 0.10.7
- [#9118](https://github.com/blockscout/blockscout/pull/9118) - Bump postcss from 8.4.32 to 8.4.33 in /apps/block_scout_web/assets
- [#9161](https://github.com/blockscout/blockscout/pull/9161) - Bump sass-loader from 13.3.3 to 14.0.0 in /apps/block_scout_web/assets
- [#9160](https://github.com/blockscout/blockscout/pull/9160) - Bump copy-webpack-plugin from 11.0.0 to 12.0.1 in /apps/block_scout_web/assets
- [#9165](https://github.com/blockscout/blockscout/pull/9165) - Bump sweetalert2 from 11.10.2 to 11.10.3 in /apps/block_scout_web/assets
- [#9163](https://github.com/blockscout/blockscout/pull/9163) - Bump mini-css-extract-plugin from 2.7.6 to 2.7.7 in /apps/block_scout_web/assets
- [#9159](https://github.com/blockscout/blockscout/pull/9159) - Bump @babel/preset-env from 7.23.7 to 7.23.8 in /apps/block_scout_web/assets
- [#9162](https://github.com/blockscout/blockscout/pull/9162) - Bump style-loader from 3.3.3 to 3.3.4 in /apps/block_scout_web/assets
- [#9164](https://github.com/blockscout/blockscout/pull/9164) - Bump css-loader from 6.8.1 to 6.9.0 in /apps/block_scout_web/assets
- [#8686](https://github.com/blockscout/blockscout/pull/8686) - Bump dialyxir from 1.4.1 to 1.4.2
- [#8861](https://github.com/blockscout/blockscout/pull/8861) - Bump briefly from 51dfe7f to 4836ba3
- [#9117](https://github.com/blockscout/blockscout/pull/9117) - Bump credo from 1.7.1 to 1.7.3
- [#9222](https://github.com/blockscout/blockscout/pull/9222) - Bump dialyxir from 1.4.2 to 1.4.3
- [#9219](https://github.com/blockscout/blockscout/pull/9219) - Bump sass from 1.69.7 to 1.70.0 in /apps/block_scout_web/assets
- [#9224](https://github.com/blockscout/blockscout/pull/9224) - Bump ex_cldr_numbers from 2.32.3 to 2.32.4
- [#9220](https://github.com/blockscout/blockscout/pull/9220) - Bump copy-webpack-plugin from 12.0.1 to 12.0.2 in /apps/block_scout_web/assets
- [#9216](https://github.com/blockscout/blockscout/pull/9216) - Bump core-js from 3.35.0 to 3.35.1 in /apps/block_scout_web/assets
- [#9218](https://github.com/blockscout/blockscout/pull/9218) - Bump postcss-loader from 7.3.4 to 8.0.0 in /apps/block_scout_web/assets
- [#9223](https://github.com/blockscout/blockscout/pull/9223) - Bump plug_cowboy from 2.6.1 to 2.6.2
- [#9217](https://github.com/blockscout/blockscout/pull/9217) - Bump css-loader from 6.9.0 to 6.9.1 in /apps/block_scout_web/assets
- [#9215](https://github.com/blockscout/blockscout/pull/9215) - Bump css-minimizer-webpack-plugin from 5.0.1 to 6.0.0 in /apps/block_scout_web/assets
- [#9221](https://github.com/blockscout/blockscout/pull/9221) - Bump autoprefixer from 10.4.16 to 10.4.17 in /apps/block_scout_web/assets

</details>

## 6.0.0

### Features

- [#9112](https://github.com/blockscout/blockscout/pull/9112) - Add specific url for eth_call
- [#9044](https://github.com/blockscout/blockscout/pull/9044) - Expand gas price oracle functionality

### Fixes

- [#9113](https://github.com/blockscout/blockscout/pull/9113) - Fix migrators cache updating
- [#9101](https://github.com/blockscout/blockscout/pull/9101) - Fix migration_finished? logic
- [#9062](https://github.com/blockscout/blockscout/pull/9062) - Fix blockscout-ens integration
- [#9061](https://github.com/blockscout/blockscout/pull/9061) - Arbitrum allow tx receipt gasUsedForL1 field
- [#8812](https://github.com/blockscout/blockscout/pull/8812) - Update existing tokens type if got transfer with higher type priority

### Chore

- [#9055](https://github.com/blockscout/blockscout/pull/9055) - Add ASC indices for logs, token transfers, transactions
- [#9038](https://github.com/blockscout/blockscout/pull/9038) - Token type filling migrations
- [#9009](https://github.com/blockscout/blockscout/pull/9009) - Index for block refetch_needed
- [#9007](https://github.com/blockscout/blockscout/pull/9007) - Drop logs type index
- [#9006](https://github.com/blockscout/blockscout/pull/9006) - Drop unused indexes on address_current_token_balances table
- [#9005](https://github.com/blockscout/blockscout/pull/9005) - Drop unused token_id column from token_transfers table and indexes based on this column
- [#9000](https://github.com/blockscout/blockscout/pull/9000) - Change log topic type in the DB to bytea
- [#8996](https://github.com/blockscout/blockscout/pull/8996) - Refine token transfers token ids index
- [#8776](https://github.com/blockscout/blockscout/pull/8776) - DB denormalization: block consensus and timestamp in transaction table

<details>
  <summary>Dependencies version bumps</summary>

- [#9059](https://github.com/blockscout/blockscout/pull/9059) - Bump redux from 5.0.0 to 5.0.1 in /apps/block_scout_web/assets
- [#9057](https://github.com/blockscout/blockscout/pull/9057) - Bump benchee from 1.2.0 to 1.3.0
- [#9060](https://github.com/blockscout/blockscout/pull/9060) - Bump @amplitude/analytics-browser from 2.3.7 to 2.3.8 in /apps/block_scout_web/assets
- [#9084](https://github.com/blockscout/blockscout/pull/9084) - Bump @babel/preset-env from 7.23.6 to 7.23.7 in /apps/block_scout_web/assets
- [#9083](https://github.com/blockscout/blockscout/pull/9083) - Bump @babel/core from 7.23.6 to 7.23.7 in /apps/block_scout_web/assets
- [#9086](https://github.com/blockscout/blockscout/pull/9086) - Bump core-js from 3.34.0 to 3.35.0 in /apps/block_scout_web/assets
- [#9081](https://github.com/blockscout/blockscout/pull/9081) - Bump sweetalert2 from 11.10.1 to 11.10.2 in /apps/block_scout_web/assets
- [#9085](https://github.com/blockscout/blockscout/pull/9085) - Bump moment from 2.29.4 to 2.30.1 in /apps/block_scout_web/assets
- [#9087](https://github.com/blockscout/blockscout/pull/9087) - Bump postcss-loader from 7.3.3 to 7.3.4 in /apps/block_scout_web/assets
- [#9082](https://github.com/blockscout/blockscout/pull/9082) - Bump sass-loader from 13.3.2 to 13.3.3 in /apps/block_scout_web/assets
- [#9088](https://github.com/blockscout/blockscout/pull/9088) - Bump sass from 1.69.5 to 1.69.6 in /apps/block_scout_web/assets

</details>

## 5.4.0-beta

### Features

- [#9018](https://github.com/blockscout/blockscout/pull/9018) - Add SmartContractRealtimeEventHandler
- [#8997](https://github.com/blockscout/blockscout/pull/8997) - Isolate throttable error count by request method
- [#8975](https://github.com/blockscout/blockscout/pull/8975) - Add EIP-4844 compatibility (not full support yet)
- [#8972](https://github.com/blockscout/blockscout/pull/8972) - BENS integration
- [#8960](https://github.com/blockscout/blockscout/pull/8960) - TRACE_BLOCK_RANGES env var
- [#8957](https://github.com/blockscout/blockscout/pull/8957) - Add Tx Interpreter Service integration
- [#8929](https://github.com/blockscout/blockscout/pull/8929) - Shibarium Bridge indexer and API v2 extension

### Fixes

- [#9039](https://github.com/blockscout/blockscout/pull/9039) - Fix tx input decoding in tx summary microservice request
- [#9035](https://github.com/blockscout/blockscout/pull/9035) - Handle Postgrex errors on NFT import 
- [#9015](https://github.com/blockscout/blockscout/pull/9015) - Optimize NFT owner preload
- [#9013](https://github.com/blockscout/blockscout/pull/9013) - Speed up `Indexer.Fetcher.TokenInstance.LegacySanitize`
- [#8969](https://github.com/blockscout/blockscout/pull/8969) - Support legacy paging options for address transaction endpoint
- [#8965](https://github.com/blockscout/blockscout/pull/8965) - Set poll: false for internal transactions fetcher
- [#8955](https://github.com/blockscout/blockscout/pull/8955) - Remove daily balances updating from BlockReward fetcher
- [#8846](https://github.com/blockscout/blockscout/pull/8846) - Handle nil gas_price at address view

### Chore

- [#9094](https://github.com/blockscout/blockscout/pull/9094) - Improve exchange rates logging
- [#9014](https://github.com/blockscout/blockscout/pull/9014) - Decrease amount of NFT in address collection: 15 -> 9
- [#8994](https://github.com/blockscout/blockscout/pull/8994) - Refactor transactions event preloads
- [#8991](https://github.com/blockscout/blockscout/pull/8991) - Manage DB queue target via runtime env var

<details>
  <summary>Dependencies version bumps</summary>

- [#8986](https://github.com/blockscout/blockscout/pull/8986) - Bump chart.js from 4.4.0 to 4.4.1 in /apps/block_scout_web/assets
- [#8982](https://github.com/blockscout/blockscout/pull/8982) - Bump ex_doc from 0.30.9 to 0.31.0
- [#8987](https://github.com/blockscout/blockscout/pull/8987) - Bump @babel/preset-env from 7.23.5 to 7.23.6 in /apps/block_scout_web/assets
- [#8984](https://github.com/blockscout/blockscout/pull/8984) - Bump ecto_sql from 3.11.0 to 3.11.1
- [#8988](https://github.com/blockscout/blockscout/pull/8988) - Bump core-js from 3.33.3 to 3.34.0 in /apps/block_scout_web/assets
- [#8980](https://github.com/blockscout/blockscout/pull/8980) - Bump exvcr from 0.14.4 to 0.15.0
- [#8985](https://github.com/blockscout/blockscout/pull/8985) - Bump @babel/core from 7.23.5 to 7.23.6 in /apps/block_scout_web/assets
- [#9020](https://github.com/blockscout/blockscout/pull/9020) - Bump eslint-plugin-import from 2.29.0 to 2.29.1 in /apps/block_scout_web/assets
- [#9021](https://github.com/blockscout/blockscout/pull/9021) - Bump eslint from 8.55.0 to 8.56.0 in /apps/block_scout_web/assets
- [#9019](https://github.com/blockscout/blockscout/pull/9019) - Bump @amplitude/analytics-browser from 2.3.6 to 2.3.7 in /apps/block_scout_web/assets

</details>

## 5.3.3-beta

### Features

- [#8966](https://github.com/blockscout/blockscout/pull/8966) - Add `ACCOUNT_WATCHLIST_NOTIFICATIONS_LIMIT_FOR_30_DAYS`
- [#8908](https://github.com/blockscout/blockscout/pull/8908) - Solidityscan report API endpoint
- [#8900](https://github.com/blockscout/blockscout/pull/8900) - Add Compound proxy contract pattern
- [#8611](https://github.com/blockscout/blockscout/pull/8611) - Implement sorting of smart contracts, address transactions

### Fixes

- [#8959](https://github.com/blockscout/blockscout/pull/8959) - Skip failed instances in Token Instance Owner migrator
- [#8924](https://github.com/blockscout/blockscout/pull/8924) - Delete invalid current token balances in OnDemand fetcher
- [#8922](https://github.com/blockscout/blockscout/pull/8922) - Allow call type to be in lowercase
- [#8917](https://github.com/blockscout/blockscout/pull/8917) - Proxy detection hotfix in API v2
- [#8915](https://github.com/blockscout/blockscout/pull/8915) - smart-contract: delete embeds_many relation on replace
- [#8906](https://github.com/blockscout/blockscout/pull/8906) - Fix abi encoded string argument
- [#8898](https://github.com/blockscout/blockscout/pull/8898) - Enhance method decoding by candidates from DB
- [#8882](https://github.com/blockscout/blockscout/pull/8882) - Change order of proxy contracts patterns detection: existing popular EIPs to the top of the list
- [#8707](https://github.com/blockscout/blockscout/pull/8707) - Fix native coin exchange rate with `EXCHANGE_RATES_COINGECKO_COIN_ID`

### Chore

- [#8956](https://github.com/blockscout/blockscout/pull/8956) - Refine docker-compose config structure
- [#8911](https://github.com/blockscout/blockscout/pull/8911) - Set client_connection_check_interval for main Postgres DB in docker-compose setup

<details>
  <summary>Dependencies version bumps</summary>

- [#8863](https://github.com/blockscout/blockscout/pull/8863) - Bump core-js from 3.33.2 to 3.33.3 in /apps/block_scout_web/assets
- [#8864](https://github.com/blockscout/blockscout/pull/8864) - Bump @amplitude/analytics-browser from 2.3.3 to 2.3.5 in /apps/block_scout_web/assets
- [#8860](https://github.com/blockscout/blockscout/pull/8860) - Bump ecto_sql from 3.10.2 to 3.11.0
- [#8896](https://github.com/blockscout/blockscout/pull/8896) - Bump httpoison from 2.2.0 to 2.2.1
- [#8867](https://github.com/blockscout/blockscout/pull/8867) - Bump mixpanel-browser from 2.47.0 to 2.48.1 in /apps/block_scout_web/assets
- [#8865](https://github.com/blockscout/blockscout/pull/8865) - Bump eslint from 8.53.0 to 8.54.0 in /apps/block_scout_web/assets
- [#8866](https://github.com/blockscout/blockscout/pull/8866) - Bump sweetalert2 from 11.9.0 to 11.10.1 in /apps/block_scout_web/assets
- [#8897](https://github.com/blockscout/blockscout/pull/8897) - Bump prometheus from 4.10.0 to 4.11.0
- [#8859](https://github.com/blockscout/blockscout/pull/8859) - Bump absinthe from 1.7.5 to 1.7.6
- [#8858](https://github.com/blockscout/blockscout/pull/8858) - Bump ex_json_schema from 0.10.1 to 0.10.2
- [#8943](https://github.com/blockscout/blockscout/pull/8943) - Bump postgrex from 0.17.3 to 0.17.4
- [#8939](https://github.com/blockscout/blockscout/pull/8939) - Bump @babel/core from 7.23.3 to 7.23.5 in /apps/block_scout_web/assets
- [#8936](https://github.com/blockscout/blockscout/pull/8936) - Bump eslint from 8.54.0 to 8.55.0 in /apps/block_scout_web/assets
- [#8940](https://github.com/blockscout/blockscout/pull/8940) - Bump photoswipe from 5.4.2 to 5.4.3 in /apps/block_scout_web/assets
- [#8938](https://github.com/blockscout/blockscout/pull/8938) - Bump @babel/preset-env from 7.23.3 to 7.23.5 in /apps/block_scout_web/assets
- [#8935](https://github.com/blockscout/blockscout/pull/8935) - Bump @amplitude/analytics-browser from 2.3.5 to 2.3.6 in /apps/block_scout_web/assets
- [#8937](https://github.com/blockscout/blockscout/pull/8937) - Bump redux from 4.2.1 to 5.0.0 in /apps/block_scout_web/assets
- [#8942](https://github.com/blockscout/blockscout/pull/8942) - Bump gettext from 0.23.1 to 0.24.0
- [#8934](https://github.com/blockscout/blockscout/pull/8934) - Bump @fortawesome/fontawesome-free from 6.4.2 to 6.5.1 in /apps/block_scout_web/assets
- [#8933](https://github.com/blockscout/blockscout/pull/8933) - Bump postcss from 8.4.31 to 8.4.32 in /apps/block_scout_web/assets

</details>

## 5.3.2-beta

### Features

- [#8848](https://github.com/blockscout/blockscout/pull/8848) - Add MainPageRealtimeEventHandler
- [#8821](https://github.com/blockscout/blockscout/pull/8821) - Add new events to addresses channel: `eth_bytecode_db_lookup_started` and `smart_contract_was_not_verified`
- [#8795](https://github.com/blockscout/blockscout/pull/8795) - Disable catchup indexer by env
- [#8768](https://github.com/blockscout/blockscout/pull/8768) - Add possibility to search tokens by address hash
- [#8750](https://github.com/blockscout/blockscout/pull/8750) - Support new eth-bytecode-db request metadata fields
- [#8634](https://github.com/blockscout/blockscout/pull/8634) - API v2: NFT for address
- [#8609](https://github.com/blockscout/blockscout/pull/8609) - Change logs format to JSON; Add endpoint url to the block_scout_web logging
- [#8558](https://github.com/blockscout/blockscout/pull/8558) - Add CoinBalanceDailyUpdater

### Fixes

- [#8891](https://github.com/blockscout/blockscout/pull/8891) - Fix average block time
- [#8869](https://github.com/blockscout/blockscout/pull/8869) - Limit TokenBalance fetcher timeout
- [#8855](https://github.com/blockscout/blockscout/pull/8855) - All transactions count at top addresses page
- [#8836](https://github.com/blockscout/blockscout/pull/8836) - Safe token update
- [#8814](https://github.com/blockscout/blockscout/pull/8814) - Improve performance for EOA addresses in `/api/v2/addresses/{address_hash}`
- [#8813](https://github.com/blockscout/blockscout/pull/8813) - Force verify twin contracts on `/api/v2/import/smart-contracts/{address_hash}`
- [#8784](https://github.com/blockscout/blockscout/pull/8784) - Fix Indexer.Transform.Addresses for non-Suave setup
- [#8770](https://github.com/blockscout/blockscout/pull/8770) - Fix for eth_getbalance API v1 endpoint when requesting latest tag
- [#8765](https://github.com/blockscout/blockscout/pull/8765) - Fix for tvl update in market history when row already exists
- [#8759](https://github.com/blockscout/blockscout/pull/8759) - Gnosis safe proxy via singleton input
- [#8752](https://github.com/blockscout/blockscout/pull/8752) - Add `TOKEN_INSTANCE_OWNER_MIGRATION_ENABLED` env
- [#8724](https://github.com/blockscout/blockscout/pull/8724) - Fix flaky account notifier test

### Chore

- [#8832](https://github.com/blockscout/blockscout/pull/8832) - Log more details in regards 413 error
- [#8807](https://github.com/blockscout/blockscout/pull/8807) - Smart-contract proxy detection refactoring
- [#8802](https://github.com/blockscout/blockscout/pull/8802) - Enable API v2 by default
- [#8742](https://github.com/blockscout/blockscout/pull/8742) - Merge rsk branch into the master branch
- [#8728](https://github.com/blockscout/blockscout/pull/8728) - Remove repos_list (default value for ecto repos) from Explorer.ReleaseTasks

<details>
  <summary>Dependencies version bumps</summary>

- [#8727](https://github.com/blockscout/blockscout/pull/8727) - Bump browserify-sign from 4.2.1 to 4.2.2 in /apps/block_scout_web/assets
- [#8748](https://github.com/blockscout/blockscout/pull/8748) - Bump sweetalert2 from 11.7.32 to 11.9.0 in /apps/block_scout_web/assets
- [#8747](https://github.com/blockscout/blockscout/pull/8747) - Bump core-js from 3.33.1 to 3.33.2 in /apps/block_scout_web/assets
- [#8743](https://github.com/blockscout/blockscout/pull/8743) - Bump solc from 0.8.21 to 0.8.22 in /apps/explorer
- [#8745](https://github.com/blockscout/blockscout/pull/8745) - Bump tesla from 1.7.0 to 1.8.0
- [#8749](https://github.com/blockscout/blockscout/pull/8749) - Bump sass from 1.69.4 to 1.69.5 in /apps/block_scout_web/assets
- [#8744](https://github.com/blockscout/blockscout/pull/8744) - Bump phoenix_ecto from 4.4.2 to 4.4.3
- [#8746](https://github.com/blockscout/blockscout/pull/8746) - Bump floki from 0.35.1 to 0.35.2
- [#8793](https://github.com/blockscout/blockscout/pull/8793) - Bump eslint from 8.52.0 to 8.53.0 in /apps/block_scout_web/assets
- [#8792](https://github.com/blockscout/blockscout/pull/8792) - Bump cldr_utils from 2.24.1 to 2.24.2
- [#8787](https://github.com/blockscout/blockscout/pull/8787) - Bump ex_cldr_numbers from 2.32.2 to 2.32.3
- [#8790](https://github.com/blockscout/blockscout/pull/8790) - Bump ex_abi from 0.6.3 to 0.6.4
- [#8788](https://github.com/blockscout/blockscout/pull/8788) - Bump ex_cldr_units from 3.16.3 to 3.16.4
- [#8827](https://github.com/blockscout/blockscout/pull/8827) - Bump @babel/core from 7.23.2 to 7.23.3 in /apps/block_scout_web/assets
- [#8823](https://github.com/blockscout/blockscout/pull/8823) - Bump benchee from 1.1.0 to 1.2.0
- [#8826](https://github.com/blockscout/blockscout/pull/8826) - Bump luxon from 3.4.3 to 3.4.4 in /apps/block_scout_web/assets
- [#8824](https://github.com/blockscout/blockscout/pull/8824) - Bump httpoison from 2.1.0 to 2.2.0
- [#8828](https://github.com/blockscout/blockscout/pull/8828) - Bump @babel/preset-env from 7.23.2 to 7.23.3 in /apps/block_scout_web/assets
- [#8825](https://github.com/blockscout/blockscout/pull/8825) - Bump solc from 0.8.22 to 0.8.23 in /apps/explorer

</details>

## 5.3.1-beta

### Features

- [#8717](https://github.com/blockscout/blockscout/pull/8717) - Save GasPriceOracle old prices as a fallback
- [#8696](https://github.com/blockscout/blockscout/pull/8696) - Support tokenSymbol and tokenName in `/api/v2/import/token-info`
- [#8673](https://github.com/blockscout/blockscout/pull/8673) - Add a window for balances fetching from non-archive node
- [#8651](https://github.com/blockscout/blockscout/pull/8651) - Add `stability_fee` for CHAIN_TYPE=stability
- [#8556](https://github.com/blockscout/blockscout/pull/8556) - Suave functional
- [#8528](https://github.com/blockscout/blockscout/pull/8528) - Account: add pagination + envs for limits
- [#7584](https://github.com/blockscout/blockscout/pull/7584) - Add Polygon zkEVM batches fetcher

### Fixes

- [#8714](https://github.com/blockscout/blockscout/pull/8714) - Fix sourcify check 
- [#8708](https://github.com/blockscout/blockscout/pull/8708) - CoinBalanceHistory tab: show also tx with gasPrice & gasUsed > 0
- [#8706](https://github.com/blockscout/blockscout/pull/8706) - Add address name updating on contract re-verification
- [#8705](https://github.com/blockscout/blockscout/pull/8705) - Fix sourcify enabled flag
- [#8695](https://github.com/blockscout/blockscout/pull/8695), [#8755](https://github.com/blockscout/blockscout/pull/8755) - Don't override internal transaction error if it's present already
- [#8685](https://github.com/blockscout/blockscout/pull/8685) - Fix db pool size exceeds Postgres max connections
- [#8678](https://github.com/blockscout/blockscout/pull/8678) - Fix `is_verified` for `/addresses` and `/smart-contracts`

### Chore

- [#8715](https://github.com/blockscout/blockscout/pull/8715) - Rename `wrapped` field to `requestRecord` for Suave

<details>
  <summary>Dependencies version bumps</summary>

- [#8683](https://github.com/blockscout/blockscout/pull/8683) - Bump eslint from 8.51.0 to 8.52.0 in /apps/block_scout_web/assets
- [#8689](https://github.com/blockscout/blockscout/pull/8689) - Bump ex_abi from 0.6.2 to 0.6.3
- [#8682](https://github.com/blockscout/blockscout/pull/8682) - Bump core-js from 3.33.0 to 3.33.1 in /apps/block_scout_web/assets
- [#8680](https://github.com/blockscout/blockscout/pull/8680) - Bump web3 from 1.10.2 to 1.10.3 in /apps/block_scout_web/assets
- [#8681](https://github.com/blockscout/blockscout/pull/8681) - Bump eslint-plugin-import from 2.28.1 to 2.29.0 in /apps/block_scout_web/assets
- [#8684](https://github.com/blockscout/blockscout/pull/8684) - Bump @amplitude/analytics-browser from 2.3.2 to 2.3.3 in /apps/block_scout_web/assets
- [#8679](https://github.com/blockscout/blockscout/pull/8679) - Bump sass from 1.69.3 to 1.69.4 in /apps/block_scout_web/assets
- [#8687](https://github.com/blockscout/blockscout/pull/8687) - Bump floki from 0.35.0 to 0.35.1
- [#8693](https://github.com/blockscout/blockscout/pull/8693) - Bump redix from 1.2.3 to 1.3.0
- [#8688](https://github.com/blockscout/blockscout/pull/8688) - Bump ex_doc from 0.30.7 to 0.30.9

</details>

## 5.3.0-beta

### Features

- [#8512](https://github.com/blockscout/blockscout/pull/8512) - Add caching and improve `/tabs-counters` performance
- [#8472](https://github.com/blockscout/blockscout/pull/8472) - Integrate `/api/v2/bytecodes/sources:search-all` of `eth_bytecode_db`
- [#8589](https://github.com/blockscout/blockscout/pull/8589) - DefiLlama TVL source
- [#8544](https://github.com/blockscout/blockscout/pull/8544) - Fix `nil` `"structLogs"`
- [#8583](https://github.com/blockscout/blockscout/pull/8583) - Add stats widget for rootstock
- [#8542](https://github.com/blockscout/blockscout/pull/8542) - Add tracing for rootstock
- [#8561](https://github.com/blockscout/blockscout/pull/8561), [#8564](https://github.com/blockscout/blockscout/pull/8564) - Get historical market cap data from CoinGecko
- [#8543](https://github.com/blockscout/blockscout/pull/8543) - Fix polygon tracer
- [#8386](https://github.com/blockscout/blockscout/pull/8386) - Add `owner_address_hash` to the `token_instances`
- [#8530](https://github.com/blockscout/blockscout/pull/8530) - Add `block_type` to search results
- [#8180](https://github.com/blockscout/blockscout/pull/8180) - Deposits and Withdrawals for Polygon Edge
- [#7996](https://github.com/blockscout/blockscout/pull/7996) - Add CoinBalance fetcher init query limit
- [#8658](https://github.com/blockscout/blockscout/pull/8658) - Remove block consensus on import fail
- [#8575](https://github.com/blockscout/blockscout/pull/8575) - Filter token transfers on coin balances updates

### Fixes

- [#8661](https://github.com/blockscout/blockscout/pull/8661) - arm64-compatible docker image
- [#8649](https://github.com/blockscout/blockscout/pull/8649) - Set max 30sec JSON RPC poll frequency for realtime fetcher when WS is disabled
- [#8614](https://github.com/blockscout/blockscout/pull/8614) - Disable market history cataloger fetcher when exchange rates are disabled
- [#8613](https://github.com/blockscout/blockscout/pull/8613) - Refactor parsing of FIRST_BLOCK, LAST_BLOCK, TRACE_FIRST_BLOCK, TRACE_LAST_BLOCK env variables
- [#8572](https://github.com/blockscout/blockscout/pull/8572) - Refactor docker-compose config
- [#8552](https://github.com/blockscout/blockscout/pull/8552) - Add CHAIN_TYPE build arg to Dockerfile
- [#8550](https://github.com/blockscout/blockscout/pull/8550) - Sanitize paging params
- [#8515](https://github.com/blockscout/blockscout/pull/8515) - Fix `:error.types/0 is undefined` warning
- [#7959](https://github.com/blockscout/blockscout/pull/7959) - Fix empty batch transfers handling
- [#8513](https://github.com/blockscout/blockscout/pull/8513) - Don't override transaction status
- [#8620](https://github.com/blockscout/blockscout/pull/8620) - Fix the display of icons
- [#8594](https://github.com/blockscout/blockscout/pull/8594) - Fix TokenBalance fetcher retry logic

### Chore

- [#8584](https://github.com/blockscout/blockscout/pull/8584) - Store chain together with cookie hash in Redis
- [#8579](https://github.com/blockscout/blockscout/pull/8579), [#8590](https://github.com/blockscout/blockscout/pull/8590) - IPFS gateway URL runtime env variable
- [#8573](https://github.com/blockscout/blockscout/pull/8573) - Update Nginx to proxy all frontend paths
- [#8290](https://github.com/blockscout/blockscout/pull/8290) - Update Chromedriver version
- [#8536](https://github.com/blockscout/blockscout/pull/8536), [#8537](https://github.com/blockscout/blockscout/pull/8537), [#8540](https://github.com/blockscout/blockscout/pull/8540), [#8557](https://github.com/blockscout/blockscout/pull/8557) - New issue template
- [#8529](https://github.com/blockscout/blockscout/pull/8529) - Move PolygonEdge-related migration to the corresponding ecto repository
- [#8504](https://github.com/blockscout/blockscout/pull/8504) - Deploy new UI through Makefile
- [#8501](https://github.com/blockscout/blockscout/pull/8501) - Conceal secondary ports in docker compose setup

<details>
  <summary>Dependencies version bumps</summary>

- [#8508](https://github.com/blockscout/blockscout/pull/8508) - Bump sass from 1.67.0 to 1.68.0 in /apps/block_scout_web/assets
- [#8509](https://github.com/blockscout/blockscout/pull/8509) - Bump autoprefixer from 10.4.15 to 10.4.16 in /apps/block_scout_web/assets
- [#8511](https://github.com/blockscout/blockscout/pull/8511) - Bump mox from 1.0.2 to 1.1.0
- [#8532](https://github.com/blockscout/blockscout/pull/8532) - Bump eslint from 8.49.0 to 8.50.0 in /apps/block_scout_web/assets
- [#8533](https://github.com/blockscout/blockscout/pull/8533) - Bump sweetalert2 from 11.7.28 to 11.7.29 in /apps/block_scout_web/assets
- [#8531](https://github.com/blockscout/blockscout/pull/8531) - Bump ex_cldr_units from 3.16.2 to 3.16.3
- [#8534](https://github.com/blockscout/blockscout/pull/8534) - Bump @babel/core from 7.22.20 to 7.23.0 in /apps/block_scout_web/assets
- [#8546](https://github.com/blockscout/blockscout/pull/8546) - Bump sweetalert2 from 11.7.29 to 11.7.31 in /apps/block_scout_web/assets
- [#8553](https://github.com/blockscout/blockscout/pull/8553) - Bump @amplitude/analytics-browser from 2.3.1 to 2.3.2 in /apps/block_scout_web/assets
- [#8554](https://github.com/blockscout/blockscout/pull/8554) - https://github.com/blockscout/blockscout/pull/8554
- [#8547](https://github.com/blockscout/blockscout/pull/8547) - Bump briefly from 678a376 to 51dfe7f
- [#8567](https://github.com/blockscout/blockscout/pull/8567) - Bump photoswipe from 5.4.1 to 5.4.2 in /apps/block_scout_web/assets
- [#8566](https://github.com/blockscout/blockscout/pull/8566) - Bump postcss from 8.4.30 to 8.4.31 in /apps/block_scout_web/assets
- [#7575](https://github.com/blockscout/blockscout/pull/7575) - Bump css-loader from 5.2.7 to 6.8.1 in /apps/block_scout_web/assets
- [#8569](https://github.com/blockscout/blockscout/pull/8569) - Bump web3 from 1.10.0 to 1.10.2 in /apps/block_scout_web/assets
- [#8570](https://github.com/blockscout/blockscout/pull/8570) - Bump core-js from 3.32.2 to 3.33.0 in /apps/block_scout_web/assets
- [#8581](https://github.com/blockscout/blockscout/pull/8581) - Bump credo from 1.7.0 to 1.7.1
- [#8607](https://github.com/blockscout/blockscout/pull/8607) - Bump sass from 1.68.0 to 1.69.0 in /apps/block_scout_web/assets
- [#8606](https://github.com/blockscout/blockscout/pull/8606) - Bump highlight.js from 11.8.0 to 11.9.0 in /apps/block_scout_web/assets
- [#8605](https://github.com/blockscout/blockscout/pull/8605) - Bump eslint from 8.50.0 to 8.51.0 in /apps/block_scout_web/assets
- [#8608](https://github.com/blockscout/blockscout/pull/8608) - Bump sweetalert2 from 11.7.31 to 11.7.32 in /apps/block_scout_web/assets
- [#8510](https://github.com/blockscout/blockscout/pull/8510) - Bump hackney from 1.18.1 to 1.19.1
- [#8637](https://github.com/blockscout/blockscout/pull/8637) - Bump @babel/preset-env from 7.22.20 to 7.23.2 in /apps/block_scout_web/assets
- [#8639](https://github.com/blockscout/blockscout/pull/8639) - Bump sass from 1.69.0 to 1.69.3 in /apps/block_scout_web/assets
- [#8643](https://github.com/blockscout/blockscout/pull/8643) - Bump floki from 0.34.3 to 0.35.0
- [#8641](https://github.com/blockscout/blockscout/pull/8641) - Bump ex_cldr from 2.37.2 to 2.37.4
- [#8646](https://github.com/blockscout/blockscout/pull/8646) - Bump @babel/traverse from 7.23.0 to 7.23.2 in /apps/block_scout_web/assets
- [#8636](https://github.com/blockscout/blockscout/pull/8636) - Bump @babel/core from 7.23.0 to 7.23.2 in /apps/block_scout_web/assets
- [#8645](https://github.com/blockscout/blockscout/pull/8645) - Bump ex_doc from 0.30.6 to 0.30.7
- [#8638](https://github.com/blockscout/blockscout/pull/8638) - Bump webpack from 5.88.2 to 5.89.0 in /apps/block_scout_web/assets
- [#8640](https://github.com/blockscout/blockscout/pull/8640) - Bump hackney from 1.19.1 to 1.20.1

</details>

## 5.2.3-beta

### Features

- [#8382](https://github.com/blockscout/blockscout/pull/8382) - Add sitemap.xml
- [#8313](https://github.com/blockscout/blockscout/pull/8313) - Add batches to TokenInstance fetchers
- [#8285](https://github.com/blockscout/blockscout/pull/8285), [#8399](https://github.com/blockscout/blockscout/pull/8399) - Add CG/CMC coin price sources
- [#8181](https://github.com/blockscout/blockscout/pull/8181) - Insert current token balances placeholders along with historical
- [#8210](https://github.com/blockscout/blockscout/pull/8210) - Drop address foreign keys
- [#8292](https://github.com/blockscout/blockscout/pull/8292) - Add ETHEREUM_JSONRPC_WAIT_PER_TIMEOUT env var
- [#8269](https://github.com/blockscout/blockscout/pull/8269) - Don't push back to sequence on catchup exception
- [#8362](https://github.com/blockscout/blockscout/pull/8362), [#8398](https://github.com/blockscout/blockscout/pull/8398) - Drop token balances tokens foreign key

### Fixes

- [#8446](https://github.com/blockscout/blockscout/pull/8446) - Fix market cap calculation in case of CMC
- [#8431](https://github.com/blockscout/blockscout/pull/8431) - Fix contracts' output decoding
- [#8354](https://github.com/blockscout/blockscout/pull/8354) - Hotfix for proper addresses' tokens displaying
- [#8350](https://github.com/blockscout/blockscout/pull/8350) - Add Base Mainnet support for tx actions
- [#8282](https://github.com/blockscout/blockscout/pull/8282) - NFT fetcher improvements
- [#8287](https://github.com/blockscout/blockscout/pull/8287) - Add separate hackney pool for TokenInstance fetchers
- [#8293](https://github.com/blockscout/blockscout/pull/8293) - Add ETHEREUM_JSONRPC_TRACE_URL for Geth in docker-compose.yml
- [#8240](https://github.com/blockscout/blockscout/pull/8240) - Refactor and fix paging params in API v2
- [#8242](https://github.com/blockscout/blockscout/pull/8242) - Fixing visualizer service CORS issue when running docker-compose
- [#8355](https://github.com/blockscout/blockscout/pull/8355) - Fix current token balances redefining
- [#8338](https://github.com/blockscout/blockscout/pull/8338) - Fix reorgs query
- [#8413](https://github.com/blockscout/blockscout/pull/8413) - Put error in last call for STOP opcode
- [#8447](https://github.com/blockscout/blockscout/pull/8447) - Fix reorg transactions

### Chore

- [#8494](https://github.com/blockscout/blockscout/pull/8494) - Add release announcement in Slack
- [#8493](https://github.com/blockscout/blockscout/pull/8493) - Fix arm docker image build
- [#8478](https://github.com/blockscout/blockscout/pull/8478) - Set integration with Blockscout's eth bytecode DB endpoint by default and other enhancements
- [#8442](https://github.com/blockscout/blockscout/pull/8442) - Unify burn address definition
- [#8321](https://github.com/blockscout/blockscout/pull/8321) - Add curl into resulting Docker image
- [#8319](https://github.com/blockscout/blockscout/pull/8319) - Add MIX_ENV: 'prod' to docker-compose
- [#8281](https://github.com/blockscout/blockscout/pull/8281) - Planned removal of duplicate API endpoints: for CSV export and GraphQL

<details>
  <summary>Dependencies version bumps</summary>

- [#8244](https://github.com/blockscout/blockscout/pull/8244) - Bump core-js from 3.32.0 to 3.32.1 in /apps/block_scout_web/assets
- [#8243](https://github.com/blockscout/blockscout/pull/8243) - Bump sass from 1.65.1 to 1.66.0 in /apps/block_scout_web/assets
- [#8259](https://github.com/blockscout/blockscout/pull/8259) - Bump sweetalert2 from 11.7.23 to 11.7.27 in /apps/block_scout_web/assets
- [#8258](https://github.com/blockscout/blockscout/pull/8258) - Bump sass from 1.66.0 to 1.66.1 in /apps/block_scout_web/assets
- [#8260](https://github.com/blockscout/blockscout/pull/8260) - Bump jest from 29.6.2 to 29.6.3 in /apps/block_scout_web/assets
- [#8261](https://github.com/blockscout/blockscout/pull/8261) - Bump eslint-plugin-import from 2.28.0 to 2.28.1 in /apps/block_scout_web/assets
- [#8262](https://github.com/blockscout/blockscout/pull/8262) - Bump jest-environment-jsdom from 29.6.2 to 29.6.3 in /apps/block_scout_web/assets
- [#8275](https://github.com/blockscout/blockscout/pull/8275) - Bump ecto_sql from 3.10.1 to 3.10.2
- [#8284](https://github.com/blockscout/blockscout/pull/8284) - Bump luxon from 3.4.0 to 3.4.1 in /apps/block_scout_web/assets
- [#8294](https://github.com/blockscout/blockscout/pull/8294) - Bump chart.js from 4.3.3 to 4.4.0 in /apps/block_scout_web/assets
- [#8295](https://github.com/blockscout/blockscout/pull/8295) - Bump jest from 29.6.3 to 29.6.4 in /apps/block_scout_web/assets
- [#8296](https://github.com/blockscout/blockscout/pull/8296) - Bump jest-environment-jsdom from 29.6.3 to 29.6.4 in /apps/block_scout_web/assets
- [#8297](https://github.com/blockscout/blockscout/pull/8297) - Bump @babel/core from 7.22.10 to 7.22.11 in /apps/block_scout_web/assets
- [#8305](https://github.com/blockscout/blockscout/pull/8305) - Bump @amplitude/analytics-browser from 2.2.0 to 2.2.1 in /apps/block_scout_web/assets
- [#8342](https://github.com/blockscout/blockscout/pull/8342) - Bump postgrex from 0.17.2 to 0.17.3
- [#8341](https://github.com/blockscout/blockscout/pull/8341) - Bump hackney from 1.18.1 to 1.18.2
- [#8343](https://github.com/blockscout/blockscout/pull/8343) - Bump @amplitude/analytics-browser from 2.2.1 to 2.2.2 in /apps/block_scout_web/assets
- [#8344](https://github.com/blockscout/blockscout/pull/8344) - Bump postcss from 8.4.28 to 8.4.29 in /apps/block_scout_web/assets
- [#8330](https://github.com/blockscout/blockscout/pull/8330) - Bump bignumber.js from 9.1.1 to 9.1.2 in /apps/block_scout_web/assets
- [#8332](https://github.com/blockscout/blockscout/pull/8332) - Bump jquery from 3.7.0 to 3.7.1 in /apps/block_scout_web/assets
- [#8329](https://github.com/blockscout/blockscout/pull/8329) - Bump viewerjs from 1.11.4 to 1.11.5 in /apps/block_scout_web/assets
- [#8328](https://github.com/blockscout/blockscout/pull/8328) - Bump eslint from 8.47.0 to 8.48.0 in /apps/block_scout_web/assets
- [#8325](https://github.com/blockscout/blockscout/pull/8325) - Bump exvcr from 0.14.3 to 0.14.4
- [#8323](https://github.com/blockscout/blockscout/pull/8323) - Bump ex_doc from 0.30.5 to 0.30.6
- [#8322](https://github.com/blockscout/blockscout/pull/8322) - Bump dialyxir from 1.3.0 to 1.4.0
- [#8326](https://github.com/blockscout/blockscout/pull/8326) - Bump comeonin from 5.3.3 to 5.4.0
- [#8331](https://github.com/blockscout/blockscout/pull/8331) - Bump luxon from 3.4.1 to 3.4.2 in /apps/block_scout_web/assets
- [#8324](https://github.com/blockscout/blockscout/pull/8324) - Bump spandex_datadog from 1.3.0 to 1.4.0
- [#8327](https://github.com/blockscout/blockscout/pull/8327) - Bump bcrypt_elixir from 3.0.1 to 3.1.0
- [#8358](https://github.com/blockscout/blockscout/pull/8358) - Bump @babel/preset-env from 7.22.10 to 7.22.14 in /apps/block_scout_web/assets
- [#8365](https://github.com/blockscout/blockscout/pull/8365) - Bump dialyxir from 1.4.0 to 1.4.1
- [#8374](https://github.com/blockscout/blockscout/pull/8374) - Bump @amplitude/analytics-browser from 2.2.2 to 2.2.3 in /apps/block_scout_web/assets
- [#8373](https://github.com/blockscout/blockscout/pull/8373) - Bump ex_secp256k1 from 0.7.0 to 0.7.1
- [#8391](https://github.com/blockscout/blockscout/pull/8391) - Bump @babel/preset-env from 7.22.14 to 7.22.15 in /apps/block_scout_web/assets
- [#8390](https://github.com/blockscout/blockscout/pull/8390) - Bump photoswipe from 5.3.8 to 5.3.9 in /apps/block_scout_web/assets
- [#8389](https://github.com/blockscout/blockscout/pull/8389) - Bump @babel/core from 7.22.11 to 7.22.15 in /apps/block_scout_web/assets
- [#8392](https://github.com/blockscout/blockscout/pull/8392) - Bump ex_cldr_numbers from 2.31.3 to 2.32.0
- [#8400](https://github.com/blockscout/blockscout/pull/8400) - Bump ex_secp256k1 from 0.7.1 to 0.7.2
- [#8405](https://github.com/blockscout/blockscout/pull/8405) - Bump luxon from 3.4.2 to 3.4.3 in /apps/block_scout_web/assets
- [#8404](https://github.com/blockscout/blockscout/pull/8404) - Bump ex_abi from 0.6.0 to 0.6.1
- [#8410](https://github.com/blockscout/blockscout/pull/8410) - Bump core-js from 3.32.1 to 3.32.2 in /apps/block_scout_web/assets
- [#8418](https://github.com/blockscout/blockscout/pull/8418) - Bump url from 0.11.1 to 0.11.2 in /apps/block_scout_web/assets
- [#8416](https://github.com/blockscout/blockscout/pull/8416) - Bump @babel/core from 7.22.15 to 7.22.17 in /apps/block_scout_web/assets
- [#8419](https://github.com/blockscout/blockscout/pull/8419) - Bump assert from 2.0.0 to 2.1.0 in /apps/block_scout_web/assets
- [#8417](https://github.com/blockscout/blockscout/pull/8417) - Bump photoswipe from 5.3.9 to 5.4.0 in /apps/block_scout_web/assets
- [#8441](https://github.com/blockscout/blockscout/pull/8441) - Bump eslint from 8.48.0 to 8.49.0 in /apps/block_scout_web/assets
- [#8439](https://github.com/blockscout/blockscout/pull/8439) - Bump ex_cldr_numbers from 2.32.0 to 2.32.1
- [#8444](https://github.com/blockscout/blockscout/pull/8444) - Bump ex_cldr_numbers from 2.32.1 to 2.32.2
- [#8445](https://github.com/blockscout/blockscout/pull/8445) - Bump ex_abi from 0.6.1 to 0.6.2
- [#8450](https://github.com/blockscout/blockscout/pull/8450) - Bump jest-environment-jsdom from 29.6.4 to 29.7.0 in /apps/block_scout_web/assets
- [#8451](https://github.com/blockscout/blockscout/pull/8451) - Bump jest from 29.6.4 to 29.7.0 in /apps/block_scout_web/assets
- [#8463](https://github.com/blockscout/blockscout/pull/8463) - Bump sass from 1.66.1 to 1.67.0 in /apps/block_scout_web/assets
- [#8464](https://github.com/blockscout/blockscout/pull/8464) - Bump @babel/core from 7.22.17 to 7.22.19 in /apps/block_scout_web/assets
- [#8462](https://github.com/blockscout/blockscout/pull/8462) - Bump sweetalert2 from 11.7.27 to 11.7.28 in /apps/block_scout_web/assets
- [#8479](https://github.com/blockscout/blockscout/pull/8479) - Bump photoswipe from 5.4.0 to 5.4.1 in /apps/block_scout_web/assets
- [#8483](https://github.com/blockscout/blockscout/pull/8483) - Bump @amplitude/analytics-browser from 2.2.3 to 2.3.1 in /apps/block_scout_web/assets
- [#8481](https://github.com/blockscout/blockscout/pull/8481) - Bump @babel/preset-env from 7.22.15 to 7.22.20 in /apps/block_scout_web/assets
- [#8480](https://github.com/blockscout/blockscout/pull/8480) - Bump @babel/core from 7.22.19 to 7.22.20 in /apps/block_scout_web/assets
- [#8482](https://github.com/blockscout/blockscout/pull/8482) - Bump viewerjs from 1.11.5 to 1.11.6 in /apps/block_scout_web/assets
- [#8489](https://github.com/blockscout/blockscout/pull/8489) - Bump postcss from 8.4.29 to 8.4.30 in /apps/block_scout_web/assets

</details>

## 5.2.2-beta

### Features

- [#8218](https://github.com/blockscout/blockscout/pull/8218) - Add `/api/v2/search/quick` method
- [#8202](https://github.com/blockscout/blockscout/pull/8202) - Add `/api/v2/addresses/:address_hash/tabs-counters` endpoint
- [#8156](https://github.com/blockscout/blockscout/pull/8156) - Add `is_verified_via_admin_panel` property to tokens table
- [#8165](https://github.com/blockscout/blockscout/pull/8165), [#8201](https://github.com/blockscout/blockscout/pull/8201) - Add broadcast of updated address_current_token_balances
- [#7952](https://github.com/blockscout/blockscout/pull/7952) - Add parsing constructor arguments for sourcify contracts
- [#6190](https://github.com/blockscout/blockscout/pull/6190) - Add EIP-1559 support to gas price oracle
- [#7977](https://github.com/blockscout/blockscout/pull/7977) - GraphQL: extend schema with new field for existing objects
- [#8158](https://github.com/blockscout/blockscout/pull/8158), [#8164](https://github.com/blockscout/blockscout/pull/8164) - Include unfetched balances in TokenBalanceOnDemand fetcher

### Fixes

- [#8233](https://github.com/blockscout/blockscout/pull/8233) - Fix API v2 broken tx response
- [#8147](https://github.com/blockscout/blockscout/pull/8147) - Switch sourcify tests from POA Sokol to Gnosis Chiado
- [#8145](https://github.com/blockscout/blockscout/pull/8145) - Handle negative holders count in API v2
- [#8040](https://github.com/blockscout/blockscout/pull/8040) - Resolve issue with Docker image for Mac M1/M2
- [#8060](https://github.com/blockscout/blockscout/pull/8060) - Fix eth_getLogs API endpoint
- [#8082](https://github.com/blockscout/blockscout/pull/8082), [#8088](https://github.com/blockscout/blockscout/pull/8088) - Fix Rootstock charts API
- [#7992](https://github.com/blockscout/blockscout/pull/7992) - Fix missing range insert
- [#8022](https://github.com/blockscout/blockscout/pull/8022) - Don't add reorg block number to missing blocks

### Chore

- [#8222](https://github.com/blockscout/blockscout/pull/8222) - docker-compose for new UI with external backend
- [#8177](https://github.com/blockscout/blockscout/pull/8177) - Refactor address counter functions
- [#8183](https://github.com/blockscout/blockscout/pull/8183) - Update frontend envs in order to pass their validation
- [#8167](https://github.com/blockscout/blockscout/pull/8167) - Manage concurrency for Token and TokenBalance fetcher
- [#8179](https://github.com/blockscout/blockscout/pull/8179) - Enhance nginx config
- [#8146](https://github.com/blockscout/blockscout/pull/8146) - Add method_id to write methods in API v2 response
- [#8105](https://github.com/blockscout/blockscout/pull/8105) - Extend API v1 with endpoints used by new UI
- [#8104](https://github.com/blockscout/blockscout/pull/8104) - remove "TODO" from API v2 response
- [#8100](https://github.com/blockscout/blockscout/pull/8100), [#8103](https://github.com/blockscout/blockscout/pull/8103) - Extend docker-compose configs with new config when front is running externally
- [#8012](https://github.com/blockscout/blockscout/pull/8012) - API v2 smart-contract verification extended logging

<details>
  <summary>Dependencies version bumps</summary>

- [#7980](https://github.com/blockscout/blockscout/pull/7980) - Bump solc from 0.8.20 to 0.8.21 in /apps/explorer
- [#7986](https://github.com/blockscout/blockscout/pull/7986) - Bump sass from 1.63.6 to 1.64.0 in /apps/block_scout_web/assets
- [#8030](https://github.com/blockscout/blockscout/pull/8030) - Bump sweetalert2 from 11.7.18 to 11.7.20 in /apps/block_scout_web/assets
- [#8029](https://github.com/blockscout/blockscout/pull/8029) - Bump viewerjs from 1.11.3 to 1.11.4 in /apps/block_scout_web/assets
- [#8028](https://github.com/blockscout/blockscout/pull/8028) - Bump sass from 1.64.0 to 1.64.1 in /apps/block_scout_web/assets
- [#8026](https://github.com/blockscout/blockscout/pull/8026) - Bump dataloader from 1.0.10 to 1.0.11
- [#8036](https://github.com/blockscout/blockscout/pull/8036) - Bump ex_cldr_numbers from 2.31.1 to 2.31.3
- [#8027](https://github.com/blockscout/blockscout/pull/8027) - Bump absinthe from 1.7.4 to 1.7.5
- [#8035](https://github.com/blockscout/blockscout/pull/8035) - Bump wallaby from 0.30.4 to 0.30.5
- [#8038](https://github.com/blockscout/blockscout/pull/8038) - Bump chart.js from 4.3.0 to 4.3.1 in /apps/block_scout_web/assets
- [#8047](https://github.com/blockscout/blockscout/pull/8047) - Bump chart.js from 4.3.1 to 4.3.2 in /apps/block_scout_web/assets
- [#8000](https://github.com/blockscout/blockscout/pull/8000) - Bump postcss from 8.4.26 to 8.4.27 in /apps/block_scout_web/assets
- [#8052](https://github.com/blockscout/blockscout/pull/8052) - Bump @amplitude/analytics-browser from 2.1.2 to 2.1.3 in /apps/block_scout_web/assets
- [#8054](https://github.com/blockscout/blockscout/pull/8054) - Bump jest-environment-jsdom from 29.6.1 to 29.6.2 in /apps/block_scout_web/assets
- [#8063](https://github.com/blockscout/blockscout/pull/8063) - Bump eslint from 8.45.0 to 8.46.0 in /apps/block_scout_web/assets
- [#8066](https://github.com/blockscout/blockscout/pull/8066) - Bump ex_json_schema from 0.9.3 to 0.10.1
- [#8064](https://github.com/blockscout/blockscout/pull/8064) - Bump core-js from 3.31.1 to 3.32.0 in /apps/block_scout_web/assets
- [#8053](https://github.com/blockscout/blockscout/pull/8053) - Bump jest from 29.6.1 to 29.6.2 in /apps/block_scout_web/assets
- [#8065](https://github.com/blockscout/blockscout/pull/8065) - Bump eslint-plugin-import from 2.27.5 to 2.28.0 in /apps/block_scout_web/assets
- [#8092](https://github.com/blockscout/blockscout/pull/8092) - Bump exvcr from 0.14.1 to 0.14.2
- [#8091](https://github.com/blockscout/blockscout/pull/8091) - Bump sass from 1.64.1 to 1.64.2 in /apps/block_scout_web/assets
- [#8114](https://github.com/blockscout/blockscout/pull/8114) - Bump ex_doc from 0.30.3 to 0.30.4
- [#8115](https://github.com/blockscout/blockscout/pull/8115) - Bump chart.js from 4.3.2 to 4.3.3 in /apps/block_scout_web/assets
- [#8116](https://github.com/blockscout/blockscout/pull/8116) - Bump @fortawesome/fontawesome-free from 6.4.0 to 6.4.2 in /apps/block_scout_web/assets
- [#8142](https://github.com/blockscout/blockscout/pull/8142) - Bump sobelow from 0.12.2 to 0.13.0
- [#8141](https://github.com/blockscout/blockscout/pull/8141) - Bump @babel/core from 7.22.9 to 7.22.10 in /apps/block_scout_web/assets
- [#8140](https://github.com/blockscout/blockscout/pull/8140) - Bump @babel/preset-env from 7.22.9 to 7.22.10 in /apps/block_scout_web/assets
- [#8160](https://github.com/blockscout/blockscout/pull/8160) - Bump exvcr from 0.14.2 to 0.14.3
- [#8159](https://github.com/blockscout/blockscout/pull/8159) - Bump luxon from 3.3.0 to 3.4.0 in /apps/block_scout_web/assets
- [#8169](https://github.com/blockscout/blockscout/pull/8169) - Bump sass from 1.64.2 to 1.65.1 in /apps/block_scout_web/assets
- [#8170](https://github.com/blockscout/blockscout/pull/8170) - Bump sweetalert2 from 11.7.20 to 11.7.22 in /apps/block_scout_web/assets
- [#8188](https://github.com/blockscout/blockscout/pull/8188) - Bump eslint from 8.46.0 to 8.47.0 in /apps/block_scout_web/assets
- [#8204](https://github.com/blockscout/blockscout/pull/8204) - Bump ex_doc from 0.30.4 to 0.30.5
- [#8207](https://github.com/blockscout/blockscout/pull/8207) - Bump wallaby from 0.30.5 to 0.30.6
- [#8212](https://github.com/blockscout/blockscout/pull/8212) - Bump sweetalert2 from 11.7.22 to 11.7.23 in /apps/block_scout_web/assets
- [#8203](https://github.com/blockscout/blockscout/pull/8203) - Bump autoprefixer from 10.4.14 to 10.4.15 in /apps/block_scout_web/assets
- [#8214](https://github.com/blockscout/blockscout/pull/8214) - Bump @amplitude/analytics-browser from 2.1.3 to 2.2.0 in /apps/block_scout_web/assets
- [#8225](https://github.com/blockscout/blockscout/pull/8225) - Bump postcss from 8.4.27 to 8.4.28 in /apps/block_scout_web/assets
- [#8224](https://github.com/blockscout/blockscout/pull/8224) - Bump gettext from 0.22.3 to 0.23.1

</details>

## 5.2.1-beta

### Features

- [#7970](https://github.com/blockscout/blockscout/pull/7970) - Search improvements: add sorting
- [#7771](https://github.com/blockscout/blockscout/pull/7771) - CSV export: speed up
- [#7962](https://github.com/blockscout/blockscout/pull/7962) - Allow indicate CMC id of the coin through env var
- [#7946](https://github.com/blockscout/blockscout/pull/7946) - API v2 rate limit: Put token to cookies & change /api/v2/key method
- [#7888](https://github.com/blockscout/blockscout/pull/7888) - Add token balances info to watchlist address response
- [#7898](https://github.com/blockscout/blockscout/pull/7898) - Add possibility to add extra headers with JSON RPC URL
- [#7836](https://github.com/blockscout/blockscout/pull/7836) - Improve unverified email flow
- [#7784](https://github.com/blockscout/blockscout/pull/7784) - Search improvements: Add new fields, light refactoring
- [#7811](https://github.com/blockscout/blockscout/pull/7811) - Filter addresses before insertion
- [#7895](https://github.com/blockscout/blockscout/pull/7895) - API v2: Add sorting to tokens page
- [#7859](https://github.com/blockscout/blockscout/pull/7859) - Add TokenTotalSupplyUpdater
- [#7873](https://github.com/blockscout/blockscout/pull/7873) - Chunk realtime balances requests
- [#7927](https://github.com/blockscout/blockscout/pull/7927) - Delete token balances only for blocks that lost consensus
- [#7947](https://github.com/blockscout/blockscout/pull/7947) - Improve locks acquiring

### Fixes

- [#8187](https://github.com/blockscout/blockscout/pull/8187) - API v1 500 error convert to 404, if requested path is incorrect
- [#7852](https://github.com/blockscout/blockscout/pull/7852) - Token balances refactoring & fixes
- [#7872](https://github.com/blockscout/blockscout/pull/7872) - Fix pending gas price in pending tx
- [#7875](https://github.com/blockscout/blockscout/pull/7875) - Fix twin compiler version
- [#7825](https://github.com/blockscout/blockscout/pull/7825) - Fix nginx config for the new frontend websockets
- [#7772](https://github.com/blockscout/blockscout/pull/7772) - Fix parsing of database password period(s)
- [#7803](https://github.com/blockscout/blockscout/pull/7803) - Fix additional sources and interfaces, save names for vyper contracts
- [#7758](https://github.com/blockscout/blockscout/pull/7758) - Remove limit for configurable fetchers
- [#7764](https://github.com/blockscout/blockscout/pull/7764) - Fix missing ranges insertion and deletion logic
- [#7843](https://github.com/blockscout/blockscout/pull/7843) - Fix created_contract_code_indexed_at updating
- [#7855](https://github.com/blockscout/blockscout/pull/7855) - Handle internal transactions unique_violation
- [#7899](https://github.com/blockscout/blockscout/pull/7899) - Fix catchup numbers_to_ranges function
- [#7951](https://github.com/blockscout/blockscout/pull/7951) - Fix TX url in email notifications on mainnet

### Chore

- [#7963](https://github.com/blockscout/blockscout/pull/7963) - Op Stack: ignore depositNonce
- [#7954](https://github.com/blockscout/blockscout/pull/7954) - Enhance Account Explorer.Account.Notifier.Email module tests
- [#7950](https://github.com/blockscout/blockscout/pull/7950) - Add GA CI for Eth Goerli chain
- [#7934](https://github.com/blockscout/blockscout/pull/7934), [#7936](https://github.com/blockscout/blockscout/pull/7936) - Explicitly set consensus == true in queries (convenient for search), remove logger requirements, where it is not used anymore
- [#7901](https://github.com/blockscout/blockscout/pull/7901) - Fix Docker image build
- [#7890](https://github.com/blockscout/blockscout/pull/7890), [#7918](https://github.com/blockscout/blockscout/pull/7918) - Resolve warning: Application.get_env/2 is discouraged in the module body, use Application.compile_env/3 instead
- [#7863](https://github.com/blockscout/blockscout/pull/7863) - Add max_age for account sessions
- [#7841](https://github.com/blockscout/blockscout/pull/7841) - CORS setup for docker-compose config with new frontend
- [#7832](https://github.com/blockscout/blockscout/pull/7832), [#7891](https://github.com/blockscout/blockscout/pull/7891) - API v2: Add block_number, block_hash to logs
- [#7789](https://github.com/blockscout/blockscout/pull/7789) - Fix test warnings; Fix name of `MICROSERVICE_ETH_BYTECODE_DB_INTERVAL_BETWEEN_LOOKUPS` env variable
- [#7819](https://github.com/blockscout/blockscout/pull/7819) - Add logging for unknown error verification result
- [#7781](https://github.com/blockscout/blockscout/pull/7781) - Add `/api/v1/health/liveness` and `/api/v1/health/readiness`

<details>
  <summary>Dependencies version bumps</summary>

- [#7759](https://github.com/blockscout/blockscout/pull/7759) - Bump sass from 1.63.4 to 1.63.5 in /apps/block_scout_web/assets
- [#7760](https://github.com/blockscout/blockscout/pull/7760) - Bump @amplitude/analytics-browser from 2.0.0 to 2.0.1 in /apps/block_scout_web/assets
- [#7762](https://github.com/blockscout/blockscout/pull/7762) - Bump webpack from 5.87.0 to 5.88.0 in /apps/block_scout_web/assets
- [#7769](https://github.com/blockscout/blockscout/pull/7769) - Bump sass from 1.63.5 to 1.63.6 in /apps/block_scout_web/assets
- [#7805](https://github.com/blockscout/blockscout/pull/7805) - Bump ssl_verify_fun from 1.1.6 to 1.1.7
- [#7812](https://github.com/blockscout/blockscout/pull/7812) - Bump webpack from 5.88.0 to 5.88.1 in /apps/block_scout_web/assets
- [#7770](https://github.com/blockscout/blockscout/pull/7770) - Bump @amplitude/analytics-browser from 2.0.1 to 2.1.0 in /apps/block_scout_web/assets
- [#7821](https://github.com/blockscout/blockscout/pull/7821) - Bump absinthe from 1.7.1 to 1.7.3
- [#7823](https://github.com/blockscout/blockscout/pull/7823) - Bump @amplitude/analytics-browser from 2.1.0 to 2.1.1 in /apps/block_scout_web/assets
- [#7838](https://github.com/blockscout/blockscout/pull/7838) - Bump gettext from 0.22.2 to 0.22.3
- [#7840](https://github.com/blockscout/blockscout/pull/7840) - Bump eslint from 8.43.0 to 8.44.0 in /apps/block_scout_web/assets
- [#7839](https://github.com/blockscout/blockscout/pull/7839) - Bump photoswipe from 5.3.7 to 5.3.8 in /apps/block_scout_web/assets
- [#7850](https://github.com/blockscout/blockscout/pull/7850) - Bump jest-environment-jsdom from 29.5.0 to 29.6.0 in /apps/block_scout_web/assets
- [#7848](https://github.com/blockscout/blockscout/pull/7848) - Bump @amplitude/analytics-browser from 2.1.1 to 2.1.2 in /apps/block_scout_web/assets
- [#7847](https://github.com/blockscout/blockscout/pull/7847) - Bump @babel/core from 7.22.5 to 7.22.6 in /apps/block_scout_web/assets
- [#7846](https://github.com/blockscout/blockscout/pull/7846) - Bump @babel/preset-env from 7.22.5 to 7.22.6 in /apps/block_scout_web/assets
- [#7856](https://github.com/blockscout/blockscout/pull/7856) - Bump ex_cldr from 2.37.1 to 2.37.2
- [#7870](https://github.com/blockscout/blockscout/pull/7870) - Bump jest from 29.5.0 to 29.6.1 in /apps/block_scout_web/assets
- [#7867](https://github.com/blockscout/blockscout/pull/7867) - Bump postcss from 8.4.24 to 8.4.25 in /apps/block_scout_web/assets
- [#7871](https://github.com/blockscout/blockscout/pull/7871) - Bump @babel/core from 7.22.6 to 7.22.8 in /apps/block_scout_web/assets
- [#7868](https://github.com/blockscout/blockscout/pull/7868) - Bump jest-environment-jsdom from 29.6.0 to 29.6.1 in /apps/block_scout_web/assets
- [#7866](https://github.com/blockscout/blockscout/pull/7866) - Bump @babel/preset-env from 7.22.6 to 7.22.7 in /apps/block_scout_web/assets
- [#7869](https://github.com/blockscout/blockscout/pull/7869) - Bump core-js from 3.31.0 to 3.31.1 in /apps/block_scout_web/assets
- [#7884](https://github.com/blockscout/blockscout/pull/7884) - Bump ecto from 3.10.2 to 3.10.3
- [#7882](https://github.com/blockscout/blockscout/pull/7882) - Bump jason from 1.4.0 to 1.4.1
- [#7880](https://github.com/blockscout/blockscout/pull/7880) - Bump absinthe from 1.7.3 to 1.7.4
- [#7879](https://github.com/blockscout/blockscout/pull/7879) - Bump babel-loader from 9.1.2 to 9.1.3 in /apps/block_scout_web/assets
- [#7881](https://github.com/blockscout/blockscout/pull/7881) - Bump ex_cldr_numbers from 2.31.1 to 2.31.2
- [#7883](https://github.com/blockscout/blockscout/pull/7883) - Bump ex_doc from 0.29.4 to 0.30.1
- [#7916](https://github.com/blockscout/blockscout/pull/7916) - Bump semver from 5.7.1 to 5.7.2 in /apps/explorer
- [#7912](https://github.com/blockscout/blockscout/pull/7912) - Bump sweetalert2 from 11.7.12 to 11.7.16 in /apps/block_scout_web/assets
- [#7913](https://github.com/blockscout/blockscout/pull/7913) - Bump ex_doc from 0.30.1 to 0.30.2
- [#7923](https://github.com/blockscout/blockscout/pull/7923) - Bump postgrex from 0.17.1 to 0.17.2
- [#7921](https://github.com/blockscout/blockscout/pull/7921) - Bump @babel/preset-env from 7.22.7 to 7.22.9 in /apps/block_scout_web/assets
- [#7922](https://github.com/blockscout/blockscout/pull/7922) - Bump @babel/core from 7.22.8 to 7.22.9 in /apps/block_scout_web/assets
- [#7931](https://github.com/blockscout/blockscout/pull/7931) - Bump wallaby from 0.30.3 to 0.30.4
- [#7940](https://github.com/blockscout/blockscout/pull/7940) - Bump postcss from 8.4.25 to 8.4.26 in /apps/block_scout_web/assets
- [#7939](https://github.com/blockscout/blockscout/pull/7939) - Bump eslint from 8.44.0 to 8.45.0 in /apps/block_scout_web/assets
- [#7955](https://github.com/blockscout/blockscout/pull/7955) - Bump sweetalert2 from 11.7.16 to 11.7.18 in /apps/block_scout_web/assets
- [#7958](https://github.com/blockscout/blockscout/pull/7958) - Bump ex_doc from 0.30.2 to 0.30.3
- [#7965](https://github.com/blockscout/blockscout/pull/7965) - Bump webpack from 5.88.1 to 5.88.2 in /apps/block_scout_web/assets
- [#7972](https://github.com/blockscout/blockscout/pull/7972) - Bump word-wrap from 1.2.3 to 1.2.4 in /apps/block_scout_web/assets

</details>

## 5.2.0-beta

### Features

- [#7502](https://github.com/blockscout/blockscout/pull/7502) - Improve performance of some methods, endpoints and SQL queries
- [#7665](https://github.com/blockscout/blockscout/pull/7665) - Add standard-json vyper verification
- [#7685](https://github.com/blockscout/blockscout/pull/7685) - Add yul filter and "language" field for smart contracts
- [#7653](https://github.com/blockscout/blockscout/pull/7653) - Add support for DEPOSIT and WITHDRAW token transfer event in older contracts
- [#7628](https://github.com/blockscout/blockscout/pull/7628) - Support partially verified property from verifier MS; Add property to track contracts automatically verified via eth-bytecode-db
- [#7603](https://github.com/blockscout/blockscout/pull/7603) - Add Polygon Edge and optimism genesis files support
- [#7585](https://github.com/blockscout/blockscout/pull/7585) - Store and display native coin market cap from the DB
- [#7513](https://github.com/blockscout/blockscout/pull/7513) - Add Polygon Edge support
- [#7532](https://github.com/blockscout/blockscout/pull/7532) - Handle empty id in json rpc responses
- [#7544](https://github.com/blockscout/blockscout/pull/7544) - Add ERC-1155 signatures to uncataloged_token_transfer_block_numbers
- [#7363](https://github.com/blockscout/blockscout/pull/7363) - CSV export filters
- [#7697](https://github.com/blockscout/blockscout/pull/7697) - Limit fetchers init tasks

### Fixes

- [#7712](https://github.com/blockscout/blockscout/pull/7712) - Transaction actions import fix
- [#7709](https://github.com/blockscout/blockscout/pull/7709) - Contract args displaying bug
- [#7654](https://github.com/blockscout/blockscout/pull/7654) - Optimize exchange rates requests rate
- [#7636](https://github.com/blockscout/blockscout/pull/7636) - Remove receive from read methods
- [#7635](https://github.com/blockscout/blockscout/pull/7635) - Fix single 1155 transfer displaying
- [#7629](https://github.com/blockscout/blockscout/pull/7629) - Fix NFT fetcher
- [#7614](https://github.com/blockscout/blockscout/pull/7614) - API and smart-contracts fixes and improvements
- [#7611](https://github.com/blockscout/blockscout/pull/7611) - Fix tokens pagination
- [#7566](https://github.com/blockscout/blockscout/pull/7566) - Account: check composed email before sending
- [#7564](https://github.com/blockscout/blockscout/pull/7564) - Return contract type in address view
- [#7562](https://github.com/blockscout/blockscout/pull/7562) - Remove fallback from Read methods
- [#7537](https://github.com/blockscout/blockscout/pull/7537), [#7553](https://github.com/blockscout/blockscout/pull/7553) - Withdrawals fixes and improvements
- [#7546](https://github.com/blockscout/blockscout/pull/7546) - API v2: fix today coin price (use in-memory or cached in DB value)
- [#7545](https://github.com/blockscout/blockscout/pull/7545) - API v2: Check if cached exchange rate is empty before replacing DB value in stats API
- [#7516](https://github.com/blockscout/blockscout/pull/7516) - Fix shrinking logo in Safari
- [#7590](https://github.com/blockscout/blockscout/pull/7590) - Drop genesis block in internal transactions fetcher
- [#7639](https://github.com/blockscout/blockscout/pull/7639) - Fix contract creation transactions
- [#7724](https://github.com/blockscout/blockscout/pull/7724), [#7753](https://github.com/blockscout/blockscout/pull/7753) - Move MissingRangesCollector init logic to handle_continue
- [#7751](https://github.com/blockscout/blockscout/pull/7751) - Add missing method_to_url params for trace transactions

### Chore

- [#7699](https://github.com/blockscout/blockscout/pull/7699) - Add block_number index for address_coin_balances table
- [#7666](https://github.com/blockscout/blockscout/pull/7666), [#7740](https://github.com/blockscout/blockscout/pull/7740), [#7741](https://github.com/blockscout/blockscout/pull/7741) - Search label query
- [#7644](https://github.com/blockscout/blockscout/pull/7644) - Publish docker images CI for prod/staging branches
- [#7594](https://github.com/blockscout/blockscout/pull/7594) - Stats service support in docker-compose config with new frontend
- [#7576](https://github.com/blockscout/blockscout/pull/7576) - Check left blocks in pending block operations in order to decide, if we need to display indexing int tx banner at the top
- [#7543](https://github.com/blockscout/blockscout/pull/7543) - Allow hyphen in DB username

<details>
  <summary>Dependencies version bumps</summary>

- [#7518](https://github.com/blockscout/blockscout/pull/7518) - Bump mini-css-extract-plugin from 2.7.5 to 2.7.6 in /apps/block_scout_web/assets
- [#7519](https://github.com/blockscout/blockscout/pull/7519) - Bump style-loader from 3.3.2 to 3.3.3 in /apps/block_scout_web/assets
- [#7505](https://github.com/blockscout/blockscout/pull/7505) - Bump webpack from 5.83.0 to 5.83.1 in /apps/block_scout_web/assets
- [#7533](https://github.com/blockscout/blockscout/pull/7533) - Bump sass-loader from 13.2.2 to 13.3.0 in /apps/block_scout_web/assets
- [#7534](https://github.com/blockscout/blockscout/pull/7534) - Bump eslint from 8.40.0 to 8.41.0 in /apps/block_scout_web/assets
- [#7541](https://github.com/blockscout/blockscout/pull/7541) - Bump cldr_utils from 2.23.1 to 2.24.0
- [#7542](https://github.com/blockscout/blockscout/pull/7542) - Bump ex_cldr_units from 3.16.0 to 3.16.1
- [#7548](https://github.com/blockscout/blockscout/pull/7548) - Bump briefly from 20d1318 to 678a376
- [#7547](https://github.com/blockscout/blockscout/pull/7547) - Bump webpack from 5.83.1 to 5.84.0 in /apps/block_scout_web/assets
- [#7554](https://github.com/blockscout/blockscout/pull/7554) - Bump webpack from 5.84.0 to 5.84.1 in /apps/block_scout_web/assets
- [#7568](https://github.com/blockscout/blockscout/pull/7568) - Bump @babel/core from 7.21.8 to 7.22.1 in /apps/block_scout_web/assets
- [#7569](https://github.com/blockscout/blockscout/pull/7569) - Bump postcss-loader from 7.3.0 to 7.3.1 in /apps/block_scout_web/assets
- [#7570](https://github.com/blockscout/blockscout/pull/7570) - Bump number from 1.0.3 to 1.0.4
- [#7567](https://github.com/blockscout/blockscout/pull/7567) - Bump @babel/preset-env from 7.21.5 to 7.22.2 in /apps/block_scout_web/assets
- [#7582](https://github.com/blockscout/blockscout/pull/7582) - Bump eslint-config-standard from 17.0.0 to 17.1.0 in /apps/block_scout_web/assets
- [#7581](https://github.com/blockscout/blockscout/pull/7581) - Bump sass-loader from 13.3.0 to 13.3.1 in /apps/block_scout_web/assets
- [#7578](https://github.com/blockscout/blockscout/pull/7578) - Bump @babel/preset-env from 7.22.2 to 7.22.4 in /apps/block_scout_web/assets
- [#7577](https://github.com/blockscout/blockscout/pull/7577) - Bump postcss-loader from 7.3.1 to 7.3.2 in /apps/block_scout_web/assets
- [#7579](https://github.com/blockscout/blockscout/pull/7579) - Bump sweetalert2 from 11.7.5 to 11.7.8 in /apps/block_scout_web/assets
- [#7591](https://github.com/blockscout/blockscout/pull/7591) - Bump sweetalert2 from 11.7.8 to 11.7.9 in /apps/block_scout_web/assets
- [#7593](https://github.com/blockscout/blockscout/pull/7593) - Bump ex_json_schema from 0.9.2 to 0.9.3
- [#7580](https://github.com/blockscout/blockscout/pull/7580) - Bump postcss from 8.4.23 to 8.4.24 in /apps/block_scout_web/assets
- [#7601](https://github.com/blockscout/blockscout/pull/7601) - Bump sweetalert2 from 11.7.9 to 11.7.10 in /apps/block_scout_web/assets
- [#7602](https://github.com/blockscout/blockscout/pull/7602) - Bump mime from 2.0.3 to 2.0.4
- [#7618](https://github.com/blockscout/blockscout/pull/7618) - Bump gettext from 0.22.1 to 0.22.2
- [#7617](https://github.com/blockscout/blockscout/pull/7617) - Bump @amplitude/analytics-browser from 1.10.3 to 1.10.4 in /apps/block_scout_web/assets
- [#7609](https://github.com/blockscout/blockscout/pull/7609) - Bump webpack from 5.84.1 to 5.85.0 in /apps/block_scout_web/assets
- [#7610](https://github.com/blockscout/blockscout/pull/7610) - Bump mime from 2.0.4 to 2.0.5
- [#7634](https://github.com/blockscout/blockscout/pull/7634) - Bump eslint from 8.41.0 to 8.42.0 in /apps/block_scout_web/assets
- [#7633](https://github.com/blockscout/blockscout/pull/7633) - Bump floki from 0.34.2 to 0.34.3
- [#7631](https://github.com/blockscout/blockscout/pull/7631) - Bump phoenix_ecto from 4.4.1 to 4.4.2
- [#7630](https://github.com/blockscout/blockscout/pull/7630) - Bump webpack-cli from 5.1.1 to 5.1.3 in /apps/block_scout_web/assets
- [#7632](https://github.com/blockscout/blockscout/pull/7632) - Bump webpack from 5.85.0 to 5.85.1 in /apps/block_scout_web/assets
- [#7646](https://github.com/blockscout/blockscout/pull/7646) - Bump sweetalert2 from 11.7.10 to 11.7.11 in /apps/block_scout_web/assets
- [#7647](https://github.com/blockscout/blockscout/pull/7647) - Bump @amplitude/analytics-browser from 1.10.4 to 1.10.6 in /apps/block_scout_web/assets
- [#7659](https://github.com/blockscout/blockscout/pull/7659) - Bump webpack-cli from 5.1.3 to 5.1.4 in /apps/block_scout_web/assets
- [#7658](https://github.com/blockscout/blockscout/pull/7658) - Bump @amplitude/analytics-browser from 1.10.6 to 1.10.7 in /apps/block_scout_web/assets
- [#7657](https://github.com/blockscout/blockscout/pull/7657) - Bump webpack from 5.85.1 to 5.86.0 in /apps/block_scout_web/assets
- [#7672](https://github.com/blockscout/blockscout/pull/7672) - Bump @babel/preset-env from 7.22.4 to 7.22.5 in /apps/block_scout_web/assets
- [#7674](https://github.com/blockscout/blockscout/pull/7674) - Bump ecto from 3.10.1 to 3.10.2
- [#7673](https://github.com/blockscout/blockscout/pull/7673) - Bump @babel/core from 7.22.1 to 7.22.5 in /apps/block_scout_web/assets
- [#7671](https://github.com/blockscout/blockscout/pull/7671) - Bump sass from 1.62.1 to 1.63.2 in /apps/block_scout_web/assets
- [#7681](https://github.com/blockscout/blockscout/pull/7681) - Bump sweetalert2 from 11.7.11 to 11.7.12 in /apps/block_scout_web/assets
- [#7679](https://github.com/blockscout/blockscout/pull/7679) - Bump @amplitude/analytics-browser from 1.10.7 to 1.10.8 in /apps/block_scout_web/assets
- [#7680](https://github.com/blockscout/blockscout/pull/7680) - Bump sass from 1.63.2 to 1.63.3 in /apps/block_scout_web/assets
- [#7693](https://github.com/blockscout/blockscout/pull/7693) - Bump sass-loader from 13.3.1 to 13.3.2 in /apps/block_scout_web/assets
- [#7692](https://github.com/blockscout/blockscout/pull/7692) - Bump postcss-loader from 7.3.2 to 7.3.3 in /apps/block_scout_web/assets
- [#7691](https://github.com/blockscout/blockscout/pull/7691) - Bump url from 0.11.0 to 0.11.1 in /apps/block_scout_web/assets
- [#7690](https://github.com/blockscout/blockscout/pull/7690) - Bump core-js from 3.30.2 to 3.31.0 in /apps/block_scout_web/assets
- [#7701](https://github.com/blockscout/blockscout/pull/7701) - Bump css-minimizer-webpack-plugin from 5.0.0 to 5.0.1 in /apps/block_scout_web/assets
- [#7702](https://github.com/blockscout/blockscout/pull/7702) - Bump @amplitude/analytics-browser from 1.10.8 to 1.11.0 in /apps/block_scout_web/assets
- [#7708](https://github.com/blockscout/blockscout/pull/7708) - Bump phoenix_pubsub from 2.1.2 to 2.1.3
- [#7707](https://github.com/blockscout/blockscout/pull/7707) - Bump @amplitude/analytics-browser from 1.11.0 to 2.0.0 in /apps/block_scout_web/assets
- [#7706](https://github.com/blockscout/blockscout/pull/7706) - Bump webpack from 5.86.0 to 5.87.0 in /apps/block_scout_web/assets
- [#7705](https://github.com/blockscout/blockscout/pull/7705) - Bump sass from 1.63.3 to 1.63.4 in /apps/block_scout_web/assets
- [#7714](https://github.com/blockscout/blockscout/pull/7714) - Bump ex_cldr_units from 3.16.1 to 3.16.2
- [#7748](https://github.com/blockscout/blockscout/pull/7748) - Bump mock from 0.3.7 to 0.3.8
- [#7746](https://github.com/blockscout/blockscout/pull/7746) - Bump eslint from 8.42.0 to 8.43.0 in /apps/block_scout_web/assets
- [#7747](https://github.com/blockscout/blockscout/pull/7747) - Bump cldr_utils from 2.24.0 to 2.24.1

</details>

## 5.1.5-beta

### Features

- [#7439](https://github.com/blockscout/blockscout/pull/7439) - Define batch size for token balance fetcher via runtime env var
- [#7298](https://github.com/blockscout/blockscout/pull/7298) - Add changes to support force email verification
- [#7422](https://github.com/blockscout/blockscout/pull/7422) - Refactor state changes
- [#7416](https://github.com/blockscout/blockscout/pull/7416) - Add option to disable reCAPTCHA
- [#6694](https://github.com/blockscout/blockscout/pull/6694) - Add withdrawals support (EIP-4895)
- [#7355](https://github.com/blockscout/blockscout/pull/7355) - Add endpoint for token info import
- [#7393](https://github.com/blockscout/blockscout/pull/7393) - Realtime fetcher max gap
- [#7436](https://github.com/blockscout/blockscout/pull/7436) - TokenBalanceOnDemand ERC-1155 support
- [#7469](https://github.com/blockscout/blockscout/pull/7469), [#7485](https://github.com/blockscout/blockscout/pull/7485), [#7493](https://github.com/blockscout/blockscout/pull/7493) - Clear missing block ranges after every success import
- [#7489](https://github.com/blockscout/blockscout/pull/7489) - INDEXER_CATCHUP_BLOCK_INTERVAL env var

### Fixes

- [#7490](https://github.com/blockscout/blockscout/pull/7490) - Fix pending txs is not a map
- [#7474](https://github.com/blockscout/blockscout/pull/7474) - Websocket v2 improvements
- [#7472](https://github.com/blockscout/blockscout/pull/7472) - Fix RE_CAPTCHA_DISABLED variable parsing
- [#7391](https://github.com/blockscout/blockscout/pull/7391) - Fix: cannot read properties of null (reading 'value')
- [#7377](https://github.com/blockscout/blockscout/pull/7377), [#7454](https://github.com/blockscout/blockscout/pull/7454) - API v2 improvements

### Chore

- [#7496](https://github.com/blockscout/blockscout/pull/7496) - API v2: Pass backend version to the frontend
- [#7468](https://github.com/blockscout/blockscout/pull/7468) - Refactoring queries with blocks
- [#7435](https://github.com/blockscout/blockscout/pull/7435) - Add `.exs` and `.eex` checking in cspell
- [#7450](https://github.com/blockscout/blockscout/pull/7450) - Resolve unresponsive navbar in verification form page
- [#7449](https://github.com/blockscout/blockscout/pull/7449) - Actualize docker-compose readme and use latest tags instead main
- [#7417](https://github.com/blockscout/blockscout/pull/7417) - Docker compose for frontend
- [#7349](https://github.com/blockscout/blockscout/pull/7349) - Proxy pattern with getImplementation()
- [#7360](https://github.com/blockscout/blockscout/pull/7360) - Manage visibility of indexing progress alert

<details>
  <summary>Dependencies version bumps</summary>

- [#7351](https://github.com/blockscout/blockscout/pull/7351) - Bump decimal from 2.0.0 to 2.1.1
- [#7356](https://github.com/blockscout/blockscout/pull/7356) - Bump @amplitude/analytics-browser from 1.10.0 to 1.10.1 in /apps/block_scout_web/assets
- [#7366](https://github.com/blockscout/blockscout/pull/7366) - Bump mixpanel-browser from 2.46.0 to 2.47.0 in /apps/block_scout_web/assets
- [#7365](https://github.com/blockscout/blockscout/pull/7365) - Bump @amplitude/analytics-browser from 1.10.1 to 1.10.2 in /apps/block_scout_web/assets
- [#7368](https://github.com/blockscout/blockscout/pull/7368) - Bump cowboy from 2.9.0 to 2.10.0
- [#7370](https://github.com/blockscout/blockscout/pull/7370) - Bump ex_cldr_units from 3.15.0 to 3.16.0
- [#7364](https://github.com/blockscout/blockscout/pull/7364) - Bump chart.js from 4.2.1 to 4.3.0 in /apps/block_scout_web/assets
- [#7382](https://github.com/blockscout/blockscout/pull/7382) - Bump @babel/preset-env from 7.21.4 to 7.21.5 in /apps/block_scout_web/assets
- [#7381](https://github.com/blockscout/blockscout/pull/7381) - Bump highlight.js from 11.7.0 to 11.8.0 in /apps/block_scout_web/assets
- [#7379](https://github.com/blockscout/blockscout/pull/7379) - Bump @babel/core from 7.21.4 to 7.21.5 in /apps/block_scout_web/assets
- [#7380](https://github.com/blockscout/blockscout/pull/7380) - Bump postcss-loader from 7.2.4 to 7.3.0 in /apps/block_scout_web/assets
- [#7395](https://github.com/blockscout/blockscout/pull/7395) - Bump @babel/core from 7.21.5 to 7.21.8 in /apps/block_scout_web/assets
- [#7402](https://github.com/blockscout/blockscout/pull/7402) - Bump webpack from 5.81.0 to 5.82.0 in /apps/block_scout_web/assets
- [#7411](https://github.com/blockscout/blockscout/pull/7411) - Bump cldr_utils from 2.22.0 to 2.23.1
- [#7409](https://github.com/blockscout/blockscout/pull/7409) - Bump @amplitude/analytics-browser from 1.10.2 to 1.10.3 in /apps/block_scout_web/assets
- [#7410](https://github.com/blockscout/blockscout/pull/7410) - Bump sweetalert2 from 11.7.3 to 11.7.5 in /apps/block_scout_web/assets
- [#7434](https://github.com/blockscout/blockscout/pull/7434) - Bump ex_cldr from 2.37.0 to 2.37.1
- [#7433](https://github.com/blockscout/blockscout/pull/7433) - Bump eslint from 8.39.0 to 8.40.0 in /apps/block_scout_web/assets
- [#7432](https://github.com/blockscout/blockscout/pull/7432) - Bump tesla from 1.6.0 to 1.6.1
- [#7431](https://github.com/blockscout/blockscout/pull/7431) - Bump webpack-cli from 5.0.2 to 5.1.0 in /apps/block_scout_web/assets
- [#7430](https://github.com/blockscout/blockscout/pull/7430) - Bump core-js from 3.30.1 to 3.30.2 in /apps/block_scout_web/assets
- [#7443](https://github.com/blockscout/blockscout/pull/7443) - Bump webpack-cli from 5.1.0 to 5.1.1 in /apps/block_scout_web/assets
- [#7457](https://github.com/blockscout/blockscout/pull/7457) - Bump web3 from 1.9.0 to 1.10.0 in /apps/block_scout_web/assets
- [#7456](https://github.com/blockscout/blockscout/pull/7456) - Bump webpack from 5.82.0 to 5.82.1 in /apps/block_scout_web/assets
- [#7458](https://github.com/blockscout/blockscout/pull/7458) - Bump phoenix_ecto from 4.4.0 to 4.4.1
- [#7455](https://github.com/blockscout/blockscout/pull/7455) - Bump solc from 0.8.19 to 0.8.20 in /apps/explorer
- [#7460](https://github.com/blockscout/blockscout/pull/7460) - Bump jquery from 3.6.4 to 3.7.0 in /apps/block_scout_web/assets
- [#7488](https://github.com/blockscout/blockscout/pull/7488) - Bump exvcr from 0.13.5 to 0.14.1
- [#7486](https://github.com/blockscout/blockscout/pull/7486) - Bump redix from 1.2.2 to 1.2.3
- [#7487](https://github.com/blockscout/blockscout/pull/7487) - Bump tesla from 1.6.1 to 1.7.0
- [#7494](https://github.com/blockscout/blockscout/pull/7494) - Bump webpack from 5.82.1 to 5.83.0 in /apps/block_scout_web/assets
- [#7495](https://github.com/blockscout/blockscout/pull/7495) - Bump ex_cldr_numbers from 2.31.0 to 2.31.1

</details>

## 5.1.4-beta

### Features

- [#7273](https://github.com/blockscout/blockscout/pull/7273) - Support reCAPTCHA v3 in CSV export page
- [#7345](https://github.com/blockscout/blockscout/pull/7345) - Manage telegram link and its visibility in the footer
- [#7313](https://github.com/blockscout/blockscout/pull/7313) - API v2 new endpoints: watchlist transactions
- [#7286](https://github.com/blockscout/blockscout/pull/7286) - Split token instance fetcher
- [#7246](https://github.com/blockscout/blockscout/pull/7246) - Fallback JSON RPC option
- [#7329](https://github.com/blockscout/blockscout/pull/7329) - Delete pending block operations for empty blocks

### Fixes

- [#7317](https://github.com/blockscout/blockscout/pull/7317) - Fix tokensupply API v1 endpoint: handle nil total_supply
- [#7290](https://github.com/blockscout/blockscout/pull/7290) - Allow nil gas price for pending tx (Erigon node case)
- [#7288](https://github.com/blockscout/blockscout/pull/7288) - API v2 improvements: Fix tx type for pending contract creation; Remove owner for not unique ERC-1155 token instances
- [#7283](https://github.com/blockscout/blockscout/pull/7283) - Fix status for dropped/replaced tx
- [#7270](https://github.com/blockscout/blockscout/pull/7270) - Fix default `TOKEN_EXCHANGE_RATE_REFETCH_INTERVAL`
- [#7276](https://github.com/blockscout/blockscout/pull/7276) - Convert 99+% of int txs indexing into 100% in order to hide top indexing banner
- [#7282](https://github.com/blockscout/blockscout/pull/7282) - Add not found transaction error case
- [#7305](https://github.com/blockscout/blockscout/pull/7305) - Reset MissingRangesCollector min_fetched_block_number

### Chore

- [#7343](https://github.com/blockscout/blockscout/pull/7343) - Management flexibility of charts dashboard on the main page
- [#7337](https://github.com/blockscout/blockscout/pull/7337) - Account: derive Auth0 logout urls from existing envs
- [#7332](https://github.com/blockscout/blockscout/pull/7332) - Add volume for Postgres Docker containers DB
- [#7328](https://github.com/blockscout/blockscout/pull/7328) - Update Docker image tag latest with release only
- [#7312](https://github.com/blockscout/blockscout/pull/7312) - Add configs for Uniswap v3 transaction actions to index them on Base Goerli
- [#7310](https://github.com/blockscout/blockscout/pull/7310) - Reducing resource consumption on bs-indexer-eth-goerli environment
- [#7297](https://github.com/blockscout/blockscout/pull/7297) - Use tracing JSONRPC URL in case of debug_traceTransaction method
- [#7292](https://github.com/blockscout/blockscout/pull/7292) - Allow Node 16+ version

<details>
  <summary>Dependencies version bumps</summary>

- [#7257](https://github.com/blockscout/blockscout/pull/7257) - Bump ecto_sql from 3.10.0 to 3.10.1
- [#7265](https://github.com/blockscout/blockscout/pull/7265) - Bump ecto from 3.10.0 to 3.10.1
- [#7263](https://github.com/blockscout/blockscout/pull/7263) - Bump sass from 1.61.0 to 1.62.0 in /apps/block_scout_web/assets
- [#7264](https://github.com/blockscout/blockscout/pull/7264) - Bump webpack from 5.78.0 to 5.79.0 in /apps/block_scout_web/assets
- [#7274](https://github.com/blockscout/blockscout/pull/7274) - Bump postgrex from 0.17.0 to 0.17.1
- [#7277](https://github.com/blockscout/blockscout/pull/7277) - Bump core-js from 3.30.0 to 3.30.1 in /apps/block_scout_web/assets
- [#7295](https://github.com/blockscout/blockscout/pull/7295) - Bump postcss from 8.4.21 to 8.4.22 in /apps/block_scout_web/assets
- [#7303](https://github.com/blockscout/blockscout/pull/7303) - Bump redix from 1.2.1 to 1.2.2
- [#7302](https://github.com/blockscout/blockscout/pull/7302) - Bump webpack from 5.79.0 to 5.80.0 in /apps/block_scout_web/assets
- [#7307](https://github.com/blockscout/blockscout/pull/7307) - Bump postcss from 8.4.22 to 8.4.23 in /apps/block_scout_web/assets
- [#7321](https://github.com/blockscout/blockscout/pull/7321) - Bump webpack-cli from 5.0.1 to 5.0.2 in /apps/block_scout_web/assets
- [#7320](https://github.com/blockscout/blockscout/pull/7320) - Bump js-cookie from 3.0.1 to 3.0.4 in /apps/block_scout_web/assets
- [#7333](https://github.com/blockscout/blockscout/pull/7333) - Bump js-cookie from 3.0.4 to 3.0.5 in /apps/block_scout_web/assets
- [#7334](https://github.com/blockscout/blockscout/pull/7334) - Bump eslint from 8.38.0 to 8.39.0 in /apps/block_scout_web/assets
- [#7344](https://github.com/blockscout/blockscout/pull/7344) - Bump @amplitude/analytics-browser from 1.9.4 to 1.10.0 in /apps/block_scout_web/assets
- [#7347](https://github.com/blockscout/blockscout/pull/7347) - Bump webpack from 5.80.0 to 5.81.0 in /apps/block_scout_web/assets
- [#7348](https://github.com/blockscout/blockscout/pull/7348) - Bump sass from 1.62.0 to 1.62.1 in /apps/block_scout_web/assets

</details>

## 5.1.3-beta

### Features

- [#7253](https://github.com/blockscout/blockscout/pull/7253) - Add `EIP_1559_ELASTICITY_MULTIPLIER` env variable
- [#7187](https://github.com/blockscout/blockscout/pull/7187) - Integrate [Eth Bytecode DB](https://github.com/blockscout/blockscout-rs/tree/main/eth-bytecode-db/eth-bytecode-db)
- [#7185](https://github.com/blockscout/blockscout/pull/7185) - Aave v3 transaction actions indexer
- [#7148](https://github.com/blockscout/blockscout/pull/7148), [#7244](https://github.com/blockscout/blockscout/pull/7244) - API v2 improvements: API rate limiting, `/tokens/{address_hash}/instances/{token_id}/holders` and other changes

### Fixes

- [#7242](https://github.com/blockscout/blockscout/pull/7242) - Fix daily txs chart
- [#7210](https://github.com/blockscout/blockscout/pull/7210) - Fix Makefile docker image build
- [#7203](https://github.com/blockscout/blockscout/pull/7203) - Fix write contract functionality for multidimensional arrays case
- [#7186](https://github.com/blockscout/blockscout/pull/7186) - Fix build from Dockerfile
- [#7255](https://github.com/blockscout/blockscout/pull/7255) - Fix MissingRangesCollector max block number fetching

### Chore

- [#7254](https://github.com/blockscout/blockscout/pull/7254) - Rename env vars related for the integration with microservices
- [#7107](https://github.com/blockscout/blockscout/pull/7107) - Tx actions: remove excess delete_all calls and remake a cache
- [#7201](https://github.com/blockscout/blockscout/pull/7201) - Remove rust, cargo from dependencies since the latest version of ex_keccak is using precompiled rust

<details>
  <summary>Dependencies version bumps</summary>

- [#7183](https://github.com/blockscout/blockscout/pull/7183) - Bump sobelow from 0.11.1 to 0.12.1
- [#7188](https://github.com/blockscout/blockscout/pull/7188) - Bump @babel/preset-env from 7.20.2 to 7.21.4 in /apps/block_scout_web/assets
- [#7190](https://github.com/blockscout/blockscout/pull/7190) - Bump @amplitude/analytics-browser from 1.9.1 to 1.9.2 in /apps/block_scout_web/assets
- [#7189](https://github.com/blockscout/blockscout/pull/7189) - Bump @babel/core from 7.21.3 to 7.21.4 in /apps/block_scout_web/assets
- [#7206](https://github.com/blockscout/blockscout/pull/7206) - Bump tesla from 1.5.1 to 1.6.0
- [#7207](https://github.com/blockscout/blockscout/pull/7207) - Bump sobelow from 0.12.1 to 0.12.2
- [#7205](https://github.com/blockscout/blockscout/pull/7205) - Bump @amplitude/analytics-browser from 1.9.2 to 1.9.3 in /apps/block_scout_web/assets
- [#7204](https://github.com/blockscout/blockscout/pull/7204) - Bump postcss-loader from 7.1.0 to 7.2.1 in /apps/block_scout_web/assets
- [#7214](https://github.com/blockscout/blockscout/pull/7214) - Bump core-js from 3.29.1 to 3.30.0 in /apps/block_scout_web/assets
- [#7215](https://github.com/blockscout/blockscout/pull/7215) - Bump postcss-loader from 7.2.1 to 7.2.4 in /apps/block_scout_web/assets
- [#7220](https://github.com/blockscout/blockscout/pull/7220) - Bump wallaby from 0.30.2 to 0.30.3
- [#7236](https://github.com/blockscout/blockscout/pull/7236) - Bump sass from 1.60.0 to 1.61.0 in /apps/block_scout_web/assets
- [#7235](https://github.com/blockscout/blockscout/pull/7235) - Bump @amplitude/analytics-browser from 1.9.3 to 1.9.4 in /apps/block_scout_web/assets
- [#7224](https://github.com/blockscout/blockscout/pull/7224) - Bump webpack from 5.77.0 to 5.78.0 in /apps/block_scout_web/assets
- [#7245](https://github.com/blockscout/blockscout/pull/7245) - Bump eslint from 8.37.0 to 8.38.0 in /apps/block_scout_web/assets
- [#7250](https://github.com/blockscout/blockscout/pull/7250) - Bump dialyxir from 1.2.0 to 1.3.0

</details>

## 5.1.2-beta

### Features

- [#6925](https://github.com/blockscout/blockscout/pull/6925) - Rework token price fetching mechanism and sort token balances by fiat value
- [#7068](https://github.com/blockscout/blockscout/pull/7068) - Add authenticate endpoint
- [#6990](https://github.com/blockscout/blockscout/pull/6990) - Improved http requests logging, batch transfers pagination; New API v2 endpoint `/smart-contracts/counters`; And some refactoring
- [#7089](https://github.com/blockscout/blockscout/pull/7089) - ETHEREUM_JSONRPC_HTTP_TIMEOUT env variable

### Fixes

- [#7243](https://github.com/blockscout/blockscout/pull/7243) - Fix Elixir tracer to work with polygon edge
- [#7162](https://github.com/blockscout/blockscout/pull/7162) - Hide indexing alert, if internal transactions indexer disabled
- [#7096](https://github.com/blockscout/blockscout/pull/7096) - Hide indexing alert, if indexer disabled
- [#7102](https://github.com/blockscout/blockscout/pull/7102) - Set infinity timeout timestamp_to_block_number query
- [#7091](https://github.com/blockscout/blockscout/pull/7091) - Fix custom ABI
- [#7087](https://github.com/blockscout/blockscout/pull/7087) - Allow URI special symbols in `DATABASE_URL`
- [#7062](https://github.com/blockscout/blockscout/pull/7062) - Save block count in the DB when calculated in Cache module
- [#7008](https://github.com/blockscout/blockscout/pull/7008) - Fetch image/video content from IPFS link
- [#7007](https://github.com/blockscout/blockscout/pull/7007), [#7031](https://github.com/blockscout/blockscout/pull/7031), [#7058](https://github.com/blockscout/blockscout/pull/7058), [#7061](https://github.com/blockscout/blockscout/pull/7061), [#7067](https://github.com/blockscout/blockscout/pull/7067) - Token instance fetcher fixes
- [#7009](https://github.com/blockscout/blockscout/pull/7009) - Fix updating coin balances with empty value
- [#7055](https://github.com/blockscout/blockscout/pull/7055) - Set updated_at on token update even if there are no changes
- [#7080](https://github.com/blockscout/blockscout/pull/7080) - Deduplicate second degree relations before insert
- [#7161](https://github.com/blockscout/blockscout/pull/7161) - Treat "" as empty value while parsing env vars
- [#7135](https://github.com/blockscout/blockscout/pull/7135) - Block reorg fixes

### Chore

- [#7147](https://github.com/blockscout/blockscout/pull/7147) - Add missing GAS_PRICE_ORACLE_ vars to Makefile
- [#7144](https://github.com/blockscout/blockscout/pull/7144) - Update Blockscout logo
- [#7136](https://github.com/blockscout/blockscout/pull/7136) - Add release link or commit hash to docker images
- [#7097](https://github.com/blockscout/blockscout/pull/7097) - Force display token instance page
- [#7119](https://github.com/blockscout/blockscout/pull/7119), [#7149](https://github.com/blockscout/blockscout/pull/7149) - Refactor runtime config
- [#7072](https://github.com/blockscout/blockscout/pull/7072) - Add a separate docker compose for geth with clique consensus
- [#7056](https://github.com/blockscout/blockscout/pull/7056) - Add path_helper in interact.js
- [#7040](https://github.com/blockscout/blockscout/pull/7040) - Use alias BlockScoutWeb.Cldr.Number
- [#7037](https://github.com/blockscout/blockscout/pull/7037) - Define common function for "reltuples" query
- [#7034](https://github.com/blockscout/blockscout/pull/7034) - Resolve "Unexpected var, use let or const instead"
- [#7014](https://github.com/blockscout/blockscout/pull/7014), [#7036](https://github.com/blockscout/blockscout/pull/7036), [7041](https://github.com/blockscout/blockscout/pull/7041) - Fix spell in namings, add spell checking in CI
- [#7012](https://github.com/blockscout/blockscout/pull/7012) - Refactor socket.js
- [#6960](https://github.com/blockscout/blockscout/pull/6960) - Add deploy + workflow for testing (bs-indexers-ethereum-goerli)
- [#6989](https://github.com/blockscout/blockscout/pull/6989) - Update bitwalker/alpine-elixir-phoenix: 1.13 -> 1.14
- [#6987](https://github.com/blockscout/blockscout/pull/6987) - Change tx actions warning importance

<details>
  <summary>Dependencies version bumps</summary>

- [6997](https://github.com/blockscout/blockscout/pull/6997) - Bump sweetalert2 from 11.7.2 to 11.7.3 in /apps/block_scout_web/assets
- [6999](https://github.com/blockscout/blockscout/pull/6999) - Bump @amplitude/analytics-browser from 1.8.0 to 1.9.0 in /apps/block_scout_web/assets
- [7000](https://github.com/blockscout/blockscout/pull/7000) - Bump eslint from 8.34.0 to 8.35.0 in /apps/block_scout_web/assets
- [7001](https://github.com/blockscout/blockscout/pull/7001) - Bump core-js from 3.28.0 to 3.29.0 in /apps/block_scout_web/assets
- [7002](https://github.com/blockscout/blockscout/pull/7002) - Bump floki from 0.34.1 to 0.34.2
- [7004](https://github.com/blockscout/blockscout/pull/7004) - Bump ex_cldr from 2.34.1 to 2.34.2
- [7011](https://github.com/blockscout/blockscout/pull/7011) - Bump ex_doc from 0.29.1 to 0.29.2
- [7026](https://github.com/blockscout/blockscout/pull/7026) - Bump @amplitude/analytics-browser from 1.9.0 to 1.9.1 in /apps/block_scout_web/assets
- [7029](https://github.com/blockscout/blockscout/pull/7029) - Bump jest from 29.4.3 to 29.5.0 in /apps/block_scout_web/assets
- [7028](https://github.com/blockscout/blockscout/pull/7028) - Bump luxon from 3.2.1 to 3.3.0 in /apps/block_scout_web/assets
- [7027](https://github.com/blockscout/blockscout/pull/7027) - Bump jest-environment-jsdom from 29.4.3 to 29.5.0 in /apps/block_scout_web/assets
- [7030](https://github.com/blockscout/blockscout/pull/7030) - Bump viewerjs from 1.11.2 to 1.11.3 in /apps/block_scout_web/assets
- [7042](https://github.com/blockscout/blockscout/pull/7042) - Bump ex_cldr_numbers from 2.29.0 to 2.30.0
- [7048](https://github.com/blockscout/blockscout/pull/7048) - Bump webpack from 5.75.0 to 5.76.0 in /apps/block_scout_web/assets
- [7049](https://github.com/blockscout/blockscout/pull/7049) - Bump jquery from 3.6.3 to 3.6.4 in /apps/block_scout_web/assets
- [7050](https://github.com/blockscout/blockscout/pull/7050) - Bump mini-css-extract-plugin from 2.7.2 to 2.7.3 in /apps/block_scout_web/assets
- [7063](https://github.com/blockscout/blockscout/pull/7063) - Bump autoprefixer from 10.4.13 to 10.4.14 in /apps/block_scout_web/assets
- [7064](https://github.com/blockscout/blockscout/pull/7064) - Bump ueberauth from 0.10.3 to 0.10.5
- [7074](https://github.com/blockscout/blockscout/pull/7074) - Bump core-js from 3.29.0 to 3.29.1 in /apps/block_scout_web/assets
- [7078](https://github.com/blockscout/blockscout/pull/7078) - Bump ex_cldr from 2.35.1 to 2.36.0
- [7075](https://github.com/blockscout/blockscout/pull/7075) - Bump webpack from 5.76.0 to 5.76.1 in /apps/block_scout_web/assets
- [7077](https://github.com/blockscout/blockscout/pull/7077) - Bump wallaby from 0.30.1 to 0.30.2
- [7073](https://github.com/blockscout/blockscout/pull/7073) - Bump sass from 1.58.3 to 1.59.2 in /apps/block_scout_web/assets
- [7076](https://github.com/blockscout/blockscout/pull/7076) - Bump eslint from 8.35.0 to 8.36.0 in /apps/block_scout_web/assets
- [7082](https://github.com/blockscout/blockscout/pull/7082) - Bump @babel/core from 7.21.0 to 7.21.3 in /apps/block_scout_web/assets
- [7083](https://github.com/blockscout/blockscout/pull/7083) - Bump style-loader from 3.3.1 to 3.3.2 in /apps/block_scout_web/assets
- [7086](https://github.com/blockscout/blockscout/pull/7086) - Bump sass from 1.59.2 to 1.59.3 in /apps/block_scout_web/assets
- [7092](https://github.com/blockscout/blockscout/pull/7092) - Bump mini-css-extract-plugin from 2.7.3 to 2.7.4 in /apps/block_scout_web/assets
- [7094](https://github.com/blockscout/blockscout/pull/7094) - Bump webpack from 5.76.1 to 5.76.2 in /apps/block_scout_web/assets
- [7095](https://github.com/blockscout/blockscout/pull/7095) - Bump plug_cowboy from 2.6.0 to 2.6.1
- [7093](https://github.com/blockscout/blockscout/pull/7093) - Bump postcss-loader from 7.0.2 to 7.1.0 in /apps/block_scout_web/assets
- [7100](https://github.com/blockscout/blockscout/pull/7100) - Bump mini-css-extract-plugin from 2.7.4 to 2.7.5 in /apps/block_scout_web/assets
- [7101](https://github.com/blockscout/blockscout/pull/7101) - Bump ex_doc from 0.29.2 to 0.29.3
- [7113](https://github.com/blockscout/blockscout/pull/7113) - Bump sass-loader from 13.2.0 to 13.2.1 in /apps/block_scout_web/assets
- [7114](https://github.com/blockscout/blockscout/pull/7114) - Bump web3 from 1.8.2 to 1.9.0 in /apps/block_scout_web/assets
- [7117](https://github.com/blockscout/blockscout/pull/7117) - Bump flow from 1.2.3 to 1.2.4
- [7127](https://github.com/blockscout/blockscout/pull/7127) - Bump webpack from 5.76.2 to 5.76.3 in /apps/block_scout_web/assets
- [7128](https://github.com/blockscout/blockscout/pull/7128) - Bump ecto from 3.9.4 to 3.9.5
- [7129](https://github.com/blockscout/blockscout/pull/7129) - Bump ex_abi from 0.5.16 to 0.6.0
- [7118](https://github.com/blockscout/blockscout/pull/7118) - Bump credo from 1.6.7 to 1.7.0
- [7151](https://github.com/blockscout/blockscout/pull/7151) - Bump mixpanel-browser from 2.45.0 to 2.46.0 in /apps/block_scout_web/assets
- [7156](https://github.com/blockscout/blockscout/pull/7156) - Bump cldr_utils from 2.21.0 to 2.22.0
- [7155](https://github.com/blockscout/blockscout/pull/7155) - Bump timex from 3.7.9 to 3.7.11
- [7154](https://github.com/blockscout/blockscout/pull/7154) - Bump sass-loader from 13.2.1 to 13.2.2 in /apps/block_scout_web/assets
- [7152](https://github.com/blockscout/blockscout/pull/7152) - Bump @fortawesome/fontawesome-free from 6.3.0 to 6.4.0 in /apps/block_scout_web/assets
- [7153](https://github.com/blockscout/blockscout/pull/7153) - Bump sass from 1.59.3 to 1.60.0 in /apps/block_scout_web/assets
- [7159](https://github.com/blockscout/blockscout/pull/7159) - Bump ex_cldr_numbers from 2.30.0 to 2.30.1
- [7158](https://github.com/blockscout/blockscout/pull/7158) - Bump css-minimizer-webpack-plugin from 4.2.2 to 5.0.0 in /apps/block_scout_web/assets
- [7165](https://github.com/blockscout/blockscout/pull/7165) - Bump ex_doc from 0.29.3 to 0.29.4
- [7164](https://github.com/blockscout/blockscout/pull/7164) - Bump photoswipe from 5.3.6 to 5.3.7 in /apps/block_scout_web/assets
- [7167](https://github.com/blockscout/blockscout/pull/7167) - Bump webpack from 5.76.3 to 5.77.0 in /apps/block_scout_web/assets
- [7166](https://github.com/blockscout/blockscout/pull/7166) - Bump eslint from 8.36.0 to 8.37.0 in /apps/block_scout_web/assets

</details>

## 5.1.1-beta

### Features

- [#6973](https://github.com/blockscout/blockscout/pull/6973) - API v2: `/smart-contracts` and `/state-changes` endpoints
- [#6897](https://github.com/blockscout/blockscout/pull/6897) - Support basic auth in JSON RPC endpoint
- [#6908](https://github.com/blockscout/blockscout/pull/6908) - Allow disable API rate limit
- [#6951](https://github.com/blockscout/blockscout/pull/6951), [#6958](https://github.com/blockscout/blockscout/pull/6958), [#6991](https://github.com/blockscout/blockscout/pull/6991) - Set poll: true for TokenInstance fetcher
- [#5720](https://github.com/blockscout/blockscout/pull/5720) - Fetchers graceful shutdown

### Fixes

- [#6933](https://github.com/blockscout/blockscout/pull/6933) - Extract blocking UI requests to separate GenServers
- [#6953](https://github.com/blockscout/blockscout/pull/6953) - reCAPTCHA dark mode
- [#6940](https://github.com/blockscout/blockscout/pull/6940) - Reduce ttl_check_interval for cache module
- [#6941](https://github.com/blockscout/blockscout/pull/6941) - Sanitize search query before displaying
- [#6912](https://github.com/blockscout/blockscout/pull/6912) - Docker compose fix exposed ports
- [#6913](https://github.com/blockscout/blockscout/pull/6913) - Fix an error occurred when decoding base64 encoded json
- [#6911](https://github.com/blockscout/blockscout/pull/6911) - Fix bugs in verification API v2
- [#6903](https://github.com/blockscout/blockscout/pull/6903), [#6937](https://github.com/blockscout/blockscout/pull/6937), [#6961](https://github.com/blockscout/blockscout/pull/6961) - Fix indexed blocks value in "Indexing tokens" banner
- [#6891](https://github.com/blockscout/blockscout/pull/6891) - Fix read contract for geth
- [#6889](https://github.com/blockscout/blockscout/pull/6889) - Fix Internal Server Error on tx input decoding
- [#6893](https://github.com/blockscout/blockscout/pull/6893) - Fix token type definition for multiple interface tokens
- [#6922](https://github.com/blockscout/blockscout/pull/6922) - Fix WebSocketClient
- [#6501](https://github.com/blockscout/blockscout/pull/6501) - Fix wss connect

### Chore

- [#6981](https://github.com/blockscout/blockscout/pull/6981) - Token instance fetcher batch size and concurrency env vars
- [#6954](https://github.com/blockscout/blockscout/pull/6954), [#6979](https://github.com/blockscout/blockscout/pull/6979) - Move some compile time vars to runtime
- [#6952](https://github.com/blockscout/blockscout/pull/6952) - Manage BlockReward fetcher params
- [#6929](https://github.com/blockscout/blockscout/pull/6929) - Extend `INDEXER_MEMORY_LIMIT` env parsing
- [#6902](https://github.com/blockscout/blockscout/pull/6902) - Increase verification timeout to 120 seconds for microservice verification

<details>
  <summary>Dependencies version bumps</summary>

- [#6882](https://github.com/blockscout/blockscout/pull/6882) - Bump exvcr from 0.13.4 to 0.13.5
- [#6883](https://github.com/blockscout/blockscout/pull/6883) - Bump floki from 0.34.0 to 0.34.1
- [#6884](https://github.com/blockscout/blockscout/pull/6884) - Bump eslint from 8.33.0 to 8.34.0 in /apps/block_scout_web/assets
- [#6894](https://github.com/blockscout/blockscout/pull/6894) - Bump core-js from 3.27.2 to 3.28.0 in /apps/block_scout_web/assets
- [#6895](https://github.com/blockscout/blockscout/pull/6895) - Bump sass from 1.58.0 to 1.58.1 in /apps/block_scout_web/assets
- [#6905](https://github.com/blockscout/blockscout/pull/6905) - Bump jest-environment-jsdom from 29.4.2 to 29.4.3 in /apps/block_scout_web/assets
- [#6907](https://github.com/blockscout/blockscout/pull/6907) - Bump cbor from 1.0.0 to 1.0.1
- [#6906](https://github.com/blockscout/blockscout/pull/6906) - Bump jest from 29.4.2 to 29.4.3 in /apps/block_scout_web/assets
- [#6917](https://github.com/blockscout/blockscout/pull/6917) - Bump tesla from 1.5.0 to 1.5.1
- [#6930](https://github.com/blockscout/blockscout/pull/6930) - Bump sweetalert2 from 11.7.1 to 11.7.2 in /apps/block_scout_web/assets
- [#6942](https://github.com/blockscout/blockscout/pull/6942) - Bump @babel/core from 7.20.12 to 7.21.0 in /apps/block_scout_web/assets
- [#6943](https://github.com/blockscout/blockscout/pull/6943) - Bump gettext from 0.22.0 to 0.22.1
- [#6944](https://github.com/blockscout/blockscout/pull/6944) - Bump sass from 1.58.1 to 1.58.3 in /apps/block_scout_web/assets
- [#6966](https://github.com/blockscout/blockscout/pull/6966) - Bump solc from 0.8.18 to 0.8.19 in /apps/explorer
- [#6967](https://github.com/blockscout/blockscout/pull/6967) - Bump photoswipe from 5.3.5 to 5.3.6 in /apps/block_scout_web/assets
- [#6968](https://github.com/blockscout/blockscout/pull/6968) - Bump ex_rlp from 0.5.5 to 0.6.0

</details>

## 5.1.0-beta

### Features

- [#6871](https://github.com/blockscout/blockscout/pull/6871) - Integrate new smart contract verifier version
- [#6838](https://github.com/blockscout/blockscout/pull/6838) - Disable dark mode env var
- [#6843](https://github.com/blockscout/blockscout/pull/6843) - Add env variable to hide Add to MM button
- [#6744](https://github.com/blockscout/blockscout/pull/6744) - API v2: smart contracts verification
- [#6763](https://github.com/blockscout/blockscout/pull/6763) - Permanent UI dark mode
- [#6721](https://github.com/blockscout/blockscout/pull/6721) - Implement fetching internal transactions from callTracer
- [#6541](https://github.com/blockscout/blockscout/pull/6541) - Integrate sig provider
- [#6712](https://github.com/blockscout/blockscout/pull/6712), [#6798](https://github.com/blockscout/blockscout/pull/6798) - API v2 update
- [#6582](https://github.com/blockscout/blockscout/pull/6582) - Transaction actions indexer
- [#6863](https://github.com/blockscout/blockscout/pull/6863) - Move OnDemand fetchers from indexer supervisor

### Fixes

- [#6864](https://github.com/blockscout/blockscout/pull/6864) - Fix pool checker in tx actions fetcher
- [#6860](https://github.com/blockscout/blockscout/pull/6860) - JSON RPC to CSP header
- [#6859](https://github.com/blockscout/blockscout/pull/6859) - Fix task restart in transaction actions fetcher
- [#6840](https://github.com/blockscout/blockscout/pull/6840) - Fix realtime block fetcher
- [#6831](https://github.com/blockscout/blockscout/pull/6831) - Copy of [#6028](https://github.com/blockscout/blockscout/pull/6028)
- [#6832](https://github.com/blockscout/blockscout/pull/6832) - Transaction actions fix
- [#6827](https://github.com/blockscout/blockscout/pull/6827) - Fix handling unknown calls from `callTracer`
- [#6793](https://github.com/blockscout/blockscout/pull/6793) - Change sig-provider default image tag to main
- [#6777](https://github.com/blockscout/blockscout/pull/6777) - Fix -1 transaction counter
- [#6746](https://github.com/blockscout/blockscout/pull/6746) - Fix -1 address counter
- [#6736](https://github.com/blockscout/blockscout/pull/6736) - Fix `/tokens` in old UI
- [#6705](https://github.com/blockscout/blockscout/pull/6705) - Fix `/smart-contracts` bugs in API v2
- [#6740](https://github.com/blockscout/blockscout/pull/6740) - Fix tokens deadlock
- [#6759](https://github.com/blockscout/blockscout/pull/6759) - Add `jq` in docker image
- [#6779](https://github.com/blockscout/blockscout/pull/6779) - Fix missing ranges bounds clearing
- [#6652](https://github.com/blockscout/blockscout/pull/6652) - Fix geth transaction tracer

### Chore

- [#6877](https://github.com/blockscout/blockscout/pull/6877) - Docker-compose: increase default max connections and db pool size
- [#6853](https://github.com/blockscout/blockscout/pull/6853) - Fix 503 page
- [#6845](https://github.com/blockscout/blockscout/pull/6845) - Extract Docker-compose services into separate files
- [#6839](https://github.com/blockscout/blockscout/pull/6839) - Add cache to transaction actions parser
- [#6834](https://github.com/blockscout/blockscout/pull/6834) - Take into account FIRST_BLOCK in "Total blocks" counter on the main page
- [#6340](https://github.com/blockscout/blockscout/pull/6340) - Rollback to websocket_client 1.3.0
- [#6786](https://github.com/blockscout/blockscout/pull/6786) - Refactor `try rescue` statements to keep stacktrace
- [#6695](https://github.com/blockscout/blockscout/pull/6695) - Process errors and warnings with enables check-js feature in VS code

<details>
  <summary>Dependencies version bumps</summary>

- [#6703](https://github.com/blockscout/blockscout/pull/6703) - Bump @amplitude/analytics-browser from 1.6.7 to 1.6.8 in /apps/block_scout_web/assets
- [#6716](https://github.com/blockscout/blockscout/pull/6716) - Bump prometheus from 4.9.1 to 4.10.0
- [#6717](https://github.com/blockscout/blockscout/pull/6717) - Bump briefly from 13a9790 to 20d1318
- [#6715](https://github.com/blockscout/blockscout/pull/6715) - Bump eslint-plugin-import from 2.26.0 to 2.27.4 in /apps/block_scout_web/assets
- [#6702](https://github.com/blockscout/blockscout/pull/6702) - Bump sweetalert2 from 11.6.16 to 11.7.0 in /apps/block_scout_web/assets
- [#6722](https://github.com/blockscout/blockscout/pull/6722) - Bump eslint from 8.31.0 to 8.32.0 in /apps/block_scout_web/assets
- [#6727](https://github.com/blockscout/blockscout/pull/6727) - Bump eslint-plugin-import from 2.27.4 to 2.27.5 in /apps/block_scout_web/assets
- [#6728](https://github.com/blockscout/blockscout/pull/6728) - Bump ex_cldr_numbers from 2.28.0 to 2.29.0
- [#6732](https://github.com/blockscout/blockscout/pull/6732) - Bump chart.js from 4.1.2 to 4.2.0 in /apps/block_scout_web/assets
- [#6739](https://github.com/blockscout/blockscout/pull/6739) - Bump core-js from 3.27.1 to 3.27.2 in /apps/block_scout_web/assets
- [#6753](https://github.com/blockscout/blockscout/pull/6753) - Bump gettext from 0.21.0 to 0.22.0
- [#6754](https://github.com/blockscout/blockscout/pull/6754) - Bump cookiejar from 2.1.3 to 2.1.4 in /apps/block_scout_web/assets
- [#6756](https://github.com/blockscout/blockscout/pull/6756) - Bump jest from 29.3.1 to 29.4.0 in /apps/block_scout_web/assets
- [#6757](https://github.com/blockscout/blockscout/pull/6757) - Bump jest-environment-jsdom from 29.3.1 to 29.4.0 in /apps/block_scout_web/assets
- [#6764](https://github.com/blockscout/blockscout/pull/6764) - Bump sweetalert2 from 11.7.0 to 11.7.1 in /apps/block_scout_web/assets
- [#6770](https://github.com/blockscout/blockscout/pull/6770) - Bump jest-environment-jsdom from 29.4.0 to 29.4.1 in /apps/block_scout_web/assets
- [#6773](https://github.com/blockscout/blockscout/pull/6773) - Bump ex_cldr from 2.34.0 to 2.34.1
- [#6772](https://github.com/blockscout/blockscout/pull/6772) - Bump jest from 29.4.0 to 29.4.1 in /apps/block_scout_web/assets
- [#6771](https://github.com/blockscout/blockscout/pull/6771) - Bump web3modal from 1.9.11 to 1.9.12 in /apps/block_scout_web/assets
- [#6781](https://github.com/blockscout/blockscout/pull/6781) - Bump cldr_utils from 2.19.2 to 2.20.0
- [#6789](https://github.com/blockscout/blockscout/pull/6789) - Bump eslint from 8.32.0 to 8.33.0 in /apps/block_scout_web/assets
- [#6790](https://github.com/blockscout/blockscout/pull/6790) - Bump redux from 4.2.0 to 4.2.1 in /apps/block_scout_web/assets
- [#6792](https://github.com/blockscout/blockscout/pull/6792) - Bump cldr_utils from 2.20.0 to 2.21.0
- [#6788](https://github.com/blockscout/blockscout/pull/6788) - Bump web3 from 1.8.1 to 1.8.2 in /apps/block_scout_web/assets
- [#6802](https://github.com/blockscout/blockscout/pull/6802) - Bump @amplitude/analytics-browser from 1.6.8 to 1.7.0 in /apps/block_scout_web/assets
- [#6803](https://github.com/blockscout/blockscout/pull/6803) - Bump photoswipe from 5.3.4 to 5.3.5 in /apps/block_scout_web/assets
- [#6804](https://github.com/blockscout/blockscout/pull/6804) - Bump sass from 1.57.1 to 1.58.0 in /apps/block_scout_web/assets
- [#6807](https://github.com/blockscout/blockscout/pull/6807) - Bump absinthe from 1.7.0 to 1.7.1
- [#6806](https://github.com/blockscout/blockscout/pull/6806) - Bump solc from 0.8.16 to 0.8.18 in /apps/explorer
- [#6814](https://github.com/blockscout/blockscout/pull/6814) - Bump @amplitude/analytics-browser from 1.7.0 to 1.7.1 in /apps/block_scout_web/assets
- [#6813](https://github.com/blockscout/blockscout/pull/6813) - Bump chartjs-adapter-luxon from 1.3.0 to 1.3.1 in /apps/block_scout_web/assets
- [#6846](https://github.com/blockscout/blockscout/pull/6846) - Bump jest from 29.4.1 to 29.4.2 in /apps/block_scout_web/assets
- [#6850](https://github.com/blockscout/blockscout/pull/6850) - Bump redix from 1.2.0 to 1.2.1
- [#6849](https://github.com/blockscout/blockscout/pull/6849) - Bump jest-environment-jsdom from 29.4.1 to 29.4.2 in /apps/block_scout_web/assets
- [#6857](https://github.com/blockscout/blockscout/pull/6857) - Bump @amplitude/analytics-browser from 1.7.1 to 1.8.0 in /apps/block_scout_web/assets
- [#6847](https://github.com/blockscout/blockscout/pull/6847) - Bump @fortawesome/fontawesome-free from 6.2.1 to 6.3.0 in /apps/block_scout_web/assets
- [#6866](https://github.com/blockscout/blockscout/pull/6866) - Bump chart.js from 4.2.0 to 4.2.1 in /apps/block_scout_web/assets

</details>

## 5.0.0-beta

### Features

- [#6092](https://github.com/blockscout/blockscout/pull/6092) - Blockscout Account functionality
- [#6324](https://github.com/blockscout/blockscout/pull/6324) - Add verified contracts list page
- [#6316](https://github.com/blockscout/blockscout/pull/6316) - Public tags functionality
- [#6444](https://github.com/blockscout/blockscout/pull/6444) - Add support for yul verification via rust microservice
- [#6073](https://github.com/blockscout/blockscout/pull/6073) - Add vyper support for rust verifier microservice integration
- [#6401](https://github.com/blockscout/blockscout/pull/6401) - Add Sol2Uml contract visualization
- [#6583](https://github.com/blockscout/blockscout/pull/6583), [#6687](https://github.com/blockscout/blockscout/pull/6687) - Missing ranges collector
- [#6574](https://github.com/blockscout/blockscout/pull/6574), [#6601](https://github.com/blockscout/blockscout/pull/6601) - Allow and manage insecure HTTP connection to the archive node
- [#6433](https://github.com/blockscout/blockscout/pull/6433), [#6698](https://github.com/blockscout/blockscout/pull/6698) - Update error pages
- [#6544](https://github.com/blockscout/blockscout/pull/6544) - API improvements
- [#5561](https://github.com/blockscout/blockscout/pull/5561), [#6523](https://github.com/blockscout/blockscout/pull/6523), [#6549](https://github.com/blockscout/blockscout/pull/6549) - Improve working with contracts implementations
- [#6481](https://github.com/blockscout/blockscout/pull/6481) - Smart contract verification improvements
- [#6440](https://github.com/blockscout/blockscout/pull/6440) - Add support for base64 encoded NFT metadata
- [#6407](https://github.com/blockscout/blockscout/pull/6407) - Indexed ratio for int txs fetching stage
- [#6379](https://github.com/blockscout/blockscout/pull/6379), [#6429](https://github.com/blockscout/blockscout/pull/6429), [#6642](https://github.com/blockscout/blockscout/pull/6642), [#6677](https://github.com/blockscout/blockscout/pull/6677) - API v2 for frontend
- [#6351](https://github.com/blockscout/blockscout/pull/6351) - Enable forum link env var
- [#6196](https://github.com/blockscout/blockscout/pull/6196) - INDEXER_CATCHUP_BLOCKS_BATCH_SIZE and INDEXER_CATCHUP_BLOCKS_CONCURRENCY env variables
- [#6187](https://github.com/blockscout/blockscout/pull/6187) - Filter by created time of verified contracts in listcontracts API endpoint
- [#6111](https://github.com/blockscout/blockscout/pull/6111) - Add Prometheus metrics to indexer
- [#6168](https://github.com/blockscout/blockscout/pull/6168) - Token instance fetcher checks instance owner and updates current token balance
- [#6209](https://github.com/blockscout/blockscout/pull/6209) - Add metrics for block import stages, runners, steps
- [#6257](https://github.com/blockscout/blockscout/pull/6257), [#6276](https://github.com/blockscout/blockscout/pull/6276) - DISABLE_TOKEN_INSTANCE_FETCHER env variable
- [#6391](https://github.com/blockscout/blockscout/pull/6391), [#6427](https://github.com/blockscout/blockscout/pull/6427) - TokenTransfer token_id -> token_ids migration
- [#6443](https://github.com/blockscout/blockscout/pull/6443) - Drop internal transactions order index
- [#6450](https://github.com/blockscout/blockscout/pull/6450) - INDEXER_INTERNAL_TRANSACTIONS_BATCH_SIZE and INDEXER_INTERNAL_TRANSACTIONS_CONCURRENCY env variables
- [#6454](https://github.com/blockscout/blockscout/pull/6454) - INDEXER_RECEIPTS_BATCH_SIZE, INDEXER_RECEIPTS_CONCURRENCY, INDEXER_COIN_BALANCES_BATCH_SIZE, INDEXER_COIN_BALANCES_CONCURRENCY env variables
- [#6476](https://github.com/blockscout/blockscout/pull/6476), [#6484](https://github.com/blockscout/blockscout/pull/6484) - Update token balances indexes
- [#6510](https://github.com/blockscout/blockscout/pull/6510) - Set consensus: false for blocks on int transaction foreign_key_violation
- [#6565](https://github.com/blockscout/blockscout/pull/6565) - Set restart: :permanent for permanent fetchers
- [#6568](https://github.com/blockscout/blockscout/pull/6568) - Drop unfetched_token_balances index
- [#6647](https://github.com/blockscout/blockscout/pull/6647) - Pending block operations update
- [#6542](https://github.com/blockscout/blockscout/pull/6542) - Init mixpanel and amplitude analytics
- [#6713](https://github.com/blockscout/blockscout/pull/6713) - Remove internal transactions deletion

### Fixes

- [#6676](https://github.com/blockscout/blockscout/pull/6676) - Fix `/smart-contracts` bugs in API v2
- [#6603](https://github.com/blockscout/blockscout/pull/6603) - Add to MM button explorer URL fix
- [#6512](https://github.com/blockscout/blockscout/pull/6512) - Allow gasUsed in failed internal txs; Leave error field for staticcall
- [#6532](https://github.com/blockscout/blockscout/pull/6532) - Fix index creation migration
- [#6473](https://github.com/blockscout/blockscout/pull/6473) - Fix state changes for contract creation transactions
- [#6475](https://github.com/blockscout/blockscout/pull/6475) - Fix token name with unicode graphemes shortening
- [#6420](https://github.com/blockscout/blockscout/pull/6420) - Fix address logs search
- [#6390](https://github.com/blockscout/blockscout/pull/6390), [#6502](https://github.com/blockscout/blockscout/pull/6502), [#6511](https://github.com/blockscout/blockscout/pull/6511) - Fix transactions responses in API v2
- [#6357](https://github.com/blockscout/blockscout/pull/6357), [#6409](https://github.com/blockscout/blockscout/pull/6409), [#6428](https://github.com/blockscout/blockscout/pull/6428) - Fix definitions of NETWORK_PATH, API_PATH, SOCKET_ROOT: process trailing slash
- [#6338](https://github.com/blockscout/blockscout/pull/6338) - Fix token search with space
- [#6329](https://github.com/blockscout/blockscout/pull/6329) - Prevent logger from truncating response from rust verifier service in case of an error
- [#6309](https://github.com/blockscout/blockscout/pull/6309) - Fix read contract bug and change address tx count
- [#6303](https://github.com/blockscout/blockscout/pull/6303) - Fix some UI bugs
- [#6243](https://github.com/blockscout/blockscout/pull/6243) - Fix freezes on `/blocks` page
- [#6162](https://github.com/blockscout/blockscout/pull/6162) - Extend token symbol type varchar(255) -> text
- [#6158](https://github.com/blockscout/blockscout/pull/6158) - Add missing clause for merge_twin_vyper_contract_with_changeset function
- [#6090](https://github.com/blockscout/blockscout/pull/6090) - Fix metadata fetching for ERC-1155 tokens instances
- [#6091](https://github.com/blockscout/blockscout/pull/6091) - Improve fetching media type for NFT
- [#6094](https://github.com/blockscout/blockscout/pull/6094) - Fix inconsistent behavior of `getsourcecode` method
- [#6105](https://github.com/blockscout/blockscout/pull/6105) - Fix some token transfers broadcasting
- [#6106](https://github.com/blockscout/blockscout/pull/6106) - Fix 500 response on `/coin-balance` for empty address
- [#6118](https://github.com/blockscout/blockscout/pull/6118) - Fix unfetched token balances
- [#6163](https://github.com/blockscout/blockscout/pull/6163) - Fix rate limit logs
- [#6223](https://github.com/blockscout/blockscout/pull/6223) - Fix coin_id test
- [#6336](https://github.com/blockscout/blockscout/pull/6336) - Fix sending request on each key in token search
- [#6327](https://github.com/blockscout/blockscout/pull/6327) - Fix and refactor address logs page and search
- [#6449](https://github.com/blockscout/blockscout/pull/6449) - Search min_missing_block_number from zero
- [#6492](https://github.com/blockscout/blockscout/pull/6492) - Remove token instance owner fetching
- [#6536](https://github.com/blockscout/blockscout/pull/6536) - Fix internal transactions query
- [#6550](https://github.com/blockscout/blockscout/pull/6550) - Query token transfers before updating
- [#6599](https://github.com/blockscout/blockscout/pull/6599) - unhandled division by zero
- [#6590](https://github.com/blockscout/blockscout/pull/6590) - ignore some receipt fields for metis

### Chore

- [#6607](https://github.com/blockscout/blockscout/pull/6607) - Run e2e tests after PR review
- [#6606](https://github.com/blockscout/blockscout/pull/6606) - Add ARG SESSION_COOKIE_DOMAIN to Dockerfile
- [#6600](https://github.com/blockscout/blockscout/pull/6600) - Token stub icon
- [#6588](https://github.com/blockscout/blockscout/pull/6588) - Add latest image build for frontend-main with specific build-args
- [#6584](https://github.com/blockscout/blockscout/pull/6584) - Vacuum package-lock.json
- [#6581](https://github.com/blockscout/blockscout/pull/6581) - Dark mode switcher localStorage to cookie in order to support new UI
- [#6572](https://github.com/blockscout/blockscout/pull/6572) - pending_block_operations table: remove fetch_internal_transactions column
- [#6387](https://github.com/blockscout/blockscout/pull/6387) - Fix errors in docker-build and e2e-tests workflows
- [#6325](https://github.com/blockscout/blockscout/pull/6325) - Set http_only attribute of account authorization cookie to false
- [#6343](https://github.com/blockscout/blockscout/pull/6343) - Docker-compose persistent logs
- [#6240](https://github.com/blockscout/blockscout/pull/6240) - Elixir 1.14 support
- [#6204](https://github.com/blockscout/blockscout/pull/6204) - Refactor contract libs render, CONTRACT_VERIFICATION_MAX_LIBRARIES, refactor parsing integer env vars in config
- [#6195](https://github.com/blockscout/blockscout/pull/6195) - Docker compose configs improvements: Redis container name and persistent storage
- [#6192](https://github.com/blockscout/blockscout/pull/6192), [#6207](https://github.com/blockscout/blockscout/pull/6207) - Hide Indexing Internal Transactions message, if INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER=true
- [#6183](https://github.com/blockscout/blockscout/pull/6183) - Transparent coin name definition
- [#6155](https://github.com/blockscout/blockscout/pull/6155), [#6189](https://github.com/blockscout/blockscout/pull/6189) - Refactor Ethereum JSON RPC variants
- [#6125](https://github.com/blockscout/blockscout/pull/6125) - Rename obsolete "parity" EthereumJSONRPC.Variant to "nethermind"
- [#6124](https://github.com/blockscout/blockscout/pull/6124) - Docker compose: add config for Erigon
- [#6061](https://github.com/blockscout/blockscout/pull/6061) - Discord badge and updated permalink

<details>
  <summary>Dependencies version bumps</summary>

- [#6585](https://github.com/blockscout/blockscout/pull/6585) - Bump jquery from 3.6.1 to 3.6.2 in /apps/block_scout_web/assets
- [#6610](https://github.com/blockscout/blockscout/pull/6610) - Bump tesla from 1.4.4 to 1.5.0
- [#6611](https://github.com/blockscout/blockscout/pull/6611) - Bump chart.js from 4.0.1 to 4.1.0 in /apps/block_scout_web/assets
- [#6618](https://github.com/blockscout/blockscout/pull/6618) - Bump chart.js from 4.1.0 to 4.1.1 in /apps/block_scout_web/assets
- [#6619](https://github.com/blockscout/blockscout/pull/6619) - Bump eslint from 8.29.0 to 8.30.0 in /apps/block_scout_web/assets
- [#6620](https://github.com/blockscout/blockscout/pull/6620) - Bump sass from 1.56.2 to 1.57.0 in /apps/block_scout_web/assets
- [#6626](https://github.com/blockscout/blockscout/pull/6626) - Bump @amplitude/analytics-browser from 1.6.1 to 1.6.6 in /apps/block_scout_web/assets
- [#6627](https://github.com/blockscout/blockscout/pull/6627) - Bump sass from 1.57.0 to 1.57.1 in /apps/block_scout_web/assets
- [#6628](https://github.com/blockscout/blockscout/pull/6628) - Bump sweetalert2 from 11.6.15 to 11.6.16 in /apps/block_scout_web/assets
- [#6631](https://github.com/blockscout/blockscout/pull/6631) - Bump jquery from 3.6.2 to 3.6.3 in /apps/block_scout_web/assets
- [#6633](https://github.com/blockscout/blockscout/pull/6633) - Bump ecto_sql from 3.9.1 to 3.9.2
- [#6636](https://github.com/blockscout/blockscout/pull/6636) - Bump ecto from 3.9.3 to 3.9.4
- [#6639](https://github.com/blockscout/blockscout/pull/6639) - Bump @amplitude/analytics-browser from 1.6.6 to 1.6.7 in /apps/block_scout_web/assets
- [#6640](https://github.com/blockscout/blockscout/pull/6640) - Bump @babel/core from 7.20.5 to 7.20.7 in /apps/block_scout_web/assets
- [#6653](https://github.com/blockscout/blockscout/pull/6653) - Bump luxon from 3.1.1 to 3.2.0 in /apps/block_scout_web/assets
- [#6654](https://github.com/blockscout/blockscout/pull/6654) - Bump flow from 1.2.0 to 1.2.1
- [#6669](https://github.com/blockscout/blockscout/pull/6669) - Bump @babel/core from 7.20.7 to 7.20.12 in /apps/block_scout_web/assets
- [#6663](https://github.com/blockscout/blockscout/pull/6663) - Bump eslint from 8.30.0 to 8.31.0 in /apps/block_scout_web/assets
- [#6662](https://github.com/blockscout/blockscout/pull/6662) - Bump viewerjs from 1.11.1 to 1.11.2 in /apps/block_scout_web/assets
- [#6668](https://github.com/blockscout/blockscout/pull/6668) - Bump babel-loader from 9.1.0 to 9.1.2 in /apps/block_scout_web/assets
- [#6670](https://github.com/blockscout/blockscout/pull/6670) - Bump json5 from 1.0.1 to 1.0.2 in /apps/block_scout_web/assets
- [#6673](https://github.com/blockscout/blockscout/pull/6673) - Bump chart.js from 4.1.1 to 4.1.2 in /apps/block_scout_web/assets
- [#6674](https://github.com/blockscout/blockscout/pull/6674) - Bump luxon from 3.2.0 to 3.2.1 in /apps/block_scout_web/assets
- [#6675](https://github.com/blockscout/blockscout/pull/6675) - Bump web3modal from 1.9.10 to 1.9.11 in /apps/block_scout_web/assets
- [#6679](https://github.com/blockscout/blockscout/pull/6679) - Bump gettext from 0.20.0 to 0.21.0
- [#6680](https://github.com/blockscout/blockscout/pull/6680) - Bump flow from 1.2.1 to 1.2.2
- [#6689](https://github.com/blockscout/blockscout/pull/6689) - Bump postcss from 8.4.20 to 8.4.21 in /apps/block_scout_web/assets
- [#6690](https://github.com/blockscout/blockscout/pull/6690) - Bump bamboo from 2.2.0 to 2.3.0
- [#6691](https://github.com/blockscout/blockscout/pull/6691) - Bump flow from 1.2.2 to 1.2.3
- [#6696](https://github.com/blockscout/blockscout/pull/6696) - Bump briefly from 1dd66ee to 13a9790
- [#6697](https://github.com/blockscout/blockscout/pull/6697) - Bump mime from 1.6.0 to 2.0.3
- [#6053](https://github.com/blockscout/blockscout/pull/6053) - Bump jest-environment-jsdom from 29.0.1 to 29.0.2 in /apps/block_scout_web/assets
- [#6055](https://github.com/blockscout/blockscout/pull/6055) - Bump @babel/core from 7.18.13 to 7.19.0 in /apps/block_scout_web/assets
- [#6054](https://github.com/blockscout/blockscout/pull/6054) - Bump jest from 29.0.1 to 29.0.2 in /apps/block_scout_web/assets
- [#6056](https://github.com/blockscout/blockscout/pull/6056) - Bump @babel/preset-env from 7.18.10 to 7.19.0 in /apps/block_scout_web/assets
- [#6064](https://github.com/blockscout/blockscout/pull/6064) - Bump sweetalert2 from 11.4.29 to 11.4.31 in /apps/block_scout_web/assets
- [#6075](https://github.com/blockscout/blockscout/pull/6075) - Bump sweetalert2 from 11.4.31 to 11.4.32 in /apps/block_scout_web/assets
- [#6082](https://github.com/blockscout/blockscout/pull/6082) - Bump core-js from 3.25.0 to 3.25.1 in /apps/block_scout_web/assets
- [#6083](https://github.com/blockscout/blockscout/pull/6083) - Bump sass from 1.54.8 to 1.54.9 in /apps/block_scout_web/assets
- [#6095](https://github.com/blockscout/blockscout/pull/6095) - Bump jest-environment-jsdom from 29.0.2 to 29.0.3 in /apps/block_scout_web/assets
- [#6096](https://github.com/blockscout/blockscout/pull/6096) - Bump exvcr from 0.13.3 to 0.13.4
- [#6101](https://github.com/blockscout/blockscout/pull/6101) - Bump ueberauth from 0.10.1 to 0.10.2
- [#6102](https://github.com/blockscout/blockscout/pull/6102) - Bump eslint from 8.23.0 to 8.23.1 in /apps/block_scout_web/assets
- [#6098](https://github.com/blockscout/blockscout/pull/6098) - Bump ex_json_schema from 0.9.1 to 0.9.2
- [#6097](https://github.com/blockscout/blockscout/pull/6097) - Bump autoprefixer from 10.4.8 to 10.4.9 in /apps/block_scout_web/assets
- [#6099](https://github.com/blockscout/blockscout/pull/6099) - Bump jest from 29.0.2 to 29.0.3 in /apps/block_scout_web/assets
- [#6103](https://github.com/blockscout/blockscout/pull/6103) - Bump css-minimizer-webpack-plugin from 4.0.0 to 4.1.0 in /apps/block_scout_web/assets
- [#6108](https://github.com/blockscout/blockscout/pull/6108) - Bump autoprefixer from 10.4.9 to 10.4.10 in /apps/block_scout_web/assets
- [#6116](https://github.com/blockscout/blockscout/pull/6116) - Bump autoprefixer from 10.4.10 to 10.4.11 in /apps/block_scout_web/assets
- [#6114](https://github.com/blockscout/blockscout/pull/6114) - Bump @babel/core from 7.19.0 to 7.19.1 in /apps/block_scout_web/assets
- [#6113](https://github.com/blockscout/blockscout/pull/6113) - Bump ueberauth from 0.10.2 to 0.10.3
- [#6112](https://github.com/blockscout/blockscout/pull/6112) - Bump @babel/preset-env from 7.19.0 to 7.19.1 in /apps/block_scout_web/assets
- [#6115](https://github.com/blockscout/blockscout/pull/6115) - Bump web3 from 1.7.5 to 1.8.0 in /apps/block_scout_web/assets
- [#6117](https://github.com/blockscout/blockscout/pull/6117) - Bump sweetalert2 from 11.4.32 to 11.4.33 in /apps/block_scout_web/assets
- [#6119](https://github.com/blockscout/blockscout/pull/6119) - Bump scss-tokenizer from 0.3.0 to 0.4.3 in /apps/block_scout_web/assets
- [#6138](https://github.com/blockscout/blockscout/pull/6138) - Bump core-js from 3.25.1 to 3.25.2 in /apps/block_scout_web/assets
- [#6147](https://github.com/blockscout/blockscout/pull/6147) - Bump autoprefixer from 10.4.11 to 10.4.12 in /apps/block_scout_web/assets
- [#6151](https://github.com/blockscout/blockscout/pull/6151) - Bump sass from 1.54.9 to 1.55.0 in /apps/block_scout_web/assets
- [#6173](https://github.com/blockscout/blockscout/pull/6173) - Bump core-js from 3.25.2 to 3.25.3 in /apps/block_scout_web/assets
- [#6174](https://github.com/blockscout/blockscout/pull/6174) - Bump sweetalert2 from 11.4.33 to 11.4.34 in /apps/block_scout_web/assets
- [#6175](https://github.com/blockscout/blockscout/pull/6175) - Bump luxon from 3.0.3 to 3.0.4 in /apps/block_scout_web/assets
- [#6176](https://github.com/blockscout/blockscout/pull/6176) - Bump @babel/preset-env from 7.19.1 to 7.19.3 in /apps/block_scout_web/assets
- [#6177](https://github.com/blockscout/blockscout/pull/6177) - Bump @babel/core from 7.19.1 to 7.19.3 in /apps/block_scout_web/assets
- [#6178](https://github.com/blockscout/blockscout/pull/6178) - Bump eslint from 8.23.1 to 8.24.0 in /apps/block_scout_web/assets
- [#6184](https://github.com/blockscout/blockscout/pull/6184) - Bump jest from 29.0.3 to 29.1.1 in /apps/block_scout_web/assets
- [#6186](https://github.com/blockscout/blockscout/pull/6186) - Bump jest-environment-jsdom from 29.0.3 to 29.1.1 in /apps/block_scout_web/assets
- [#6185](https://github.com/blockscout/blockscout/pull/6185) - Bump sweetalert2 from 11.4.34 to 11.4.35 in /apps/block_scout_web/assets
- [#6146](https://github.com/blockscout/blockscout/pull/6146) - Bump websocket_client from 1.3.0 to 1.5.0
- [#6191](https://github.com/blockscout/blockscout/pull/6191) - Bump css-minimizer-webpack-plugin from 4.1.0 to 4.2.0 in /apps/block_scout_web/assets
- [#6199](https://github.com/blockscout/blockscout/pull/6199) - Bump redix from 1.1.5 to 1.2.0
- [#6213](https://github.com/blockscout/blockscout/pull/6213) - Bump sweetalert2 from 11.4.35 to 11.4.37 in /apps/block_scout_web/assets
- [#6214](https://github.com/blockscout/blockscout/pull/6214) - Bump jest-environment-jsdom from 29.1.1 to 29.1.2 in /apps/block_scout_web/assets
- [#6215](https://github.com/blockscout/blockscout/pull/6215) - Bump postcss from 8.4.16 to 8.4.17 in /apps/block_scout_web/assets
- [#6216](https://github.com/blockscout/blockscout/pull/6216) - Bump core-js from 3.25.3 to 3.25.5 in /apps/block_scout_web/assets
- [#6217](https://github.com/blockscout/blockscout/pull/6217) - Bump jest from 29.1.1 to 29.1.2 in /apps/block_scout_web/assets
- [#6229](https://github.com/blockscout/blockscout/pull/6229) - Bump sweetalert2 from 11.4.37 to 11.4.38 in /apps/block_scout_web/assets
- [#6232](https://github.com/blockscout/blockscout/pull/6232) - Bump css-minimizer-webpack-plugin from 4.2.0 to 4.2.1 in /apps/block_scout_web/assets
- [#6230](https://github.com/blockscout/blockscout/pull/6230) - Bump sass-loader from 13.0.2 to 13.1.0 in /apps/block_scout_web/assets
- [#6251](https://github.com/blockscout/blockscout/pull/6251) - Bump sweetalert2 from 11.4.38 to 11.5.1 in /apps/block_scout_web/assets
- [#6246](https://github.com/blockscout/blockscout/pull/6246) - Bump @babel/preset-env from 7.19.3 to 7.19.4 in /apps/block_scout_web/assets
- [#6247](https://github.com/blockscout/blockscout/pull/6247) - Bump ex_abi from 0.5.14 to 0.5.15
- [#6248](https://github.com/blockscout/blockscout/pull/6248) - Bump eslint from 8.24.0 to 8.25.0 in /apps/block_scout_web/assets
- [#6255](https://github.com/blockscout/blockscout/pull/6255) - Bump postcss from 8.4.17 to 8.4.18 in /apps/block_scout_web/assets
- [#6256](https://github.com/blockscout/blockscout/pull/6256) - Bump css-minimizer-webpack-plugin from 4.2.1 to 4.2.2 in /apps/block_scout_web/assets
- [#6258](https://github.com/blockscout/blockscout/pull/6258) - Bump jest from 29.1.2 to 29.2.0 in /apps/block_scout_web/assets
- [#6259](https://github.com/blockscout/blockscout/pull/6259) - Bump jest-environment-jsdom from 29.1.2 to 29.2.0 in /apps/block_scout_web/assets
- [#6253](https://github.com/blockscout/blockscout/pull/6253) - Bump eslint-plugin-promise from 6.0.1 to 6.1.0 in /apps/block_scout_web/assets
- [#6279](https://github.com/blockscout/blockscout/pull/6279) - Bump util from 0.12.4 to 0.12.5 in /apps/block_scout_web/assets
- [#6280](https://github.com/blockscout/blockscout/pull/6280) - Bump ex_rlp from 0.5.4 to 0.5.5
- [#6281](https://github.com/blockscout/blockscout/pull/6281) - Bump ex_abi from 0.5.15 to 0.5.16
- [#6283](https://github.com/blockscout/blockscout/pull/6283) - Bump spandex_datadog from 1.2.0 to 1.3.0
- [#6282](https://github.com/blockscout/blockscout/pull/6282) - Bump sweetalert2 from 11.5.1 to 11.5.2 in /apps/block_scout_web/assets
- [#6284](https://github.com/blockscout/blockscout/pull/6284) - Bump spandex_phoenix from 1.0.6 to 1.1.0
- [#6298](https://github.com/blockscout/blockscout/pull/6298) - Bump jest-environment-jsdom from 29.2.0 to 29.2.1 in /apps/block_scout_web/assets
- [#6297](https://github.com/blockscout/blockscout/pull/6297) - Bump jest from 29.2.0 to 29.2.1 in /apps/block_scout_web/assets
- [#6254](https://github.com/blockscout/blockscout/pull/6254) - Bump ex_doc from 0.28.5 to 0.28.6
- [#6314](https://github.com/blockscout/blockscout/pull/6314) - Bump @babel/core from 7.19.3 to 7.19.6 in /apps/block_scout_web/assets
- [#6313](https://github.com/blockscout/blockscout/pull/6313) - Bump ex_doc from 0.28.6 to 0.29.0
- [#6305](https://github.com/blockscout/blockscout/pull/6305) - Bump sweetalert2 from 11.5.2 to 11.6.0 in /apps/block_scout_web/assets
- [#6312](https://github.com/blockscout/blockscout/pull/6312) - Bump eslint-plugin-promise from 6.1.0 to 6.1.1 in /apps/block_scout_web/assets
- [#6318](https://github.com/blockscout/blockscout/pull/6318) - Bump spandex from 3.1.0 to 3.2.0
- [#6335](https://github.com/blockscout/blockscout/pull/6335) - Bump eslint from 8.25.0 to 8.26.0 in /apps/block_scout_web/assets
- [#6334](https://github.com/blockscout/blockscout/pull/6334) - Bump ex_cldr_numbers from 2.27.3 to 2.28.0
- [#6333](https://github.com/blockscout/blockscout/pull/6333) - Bump core-js from 3.25.5 to 3.26.0 in /apps/block_scout_web/assets
- [#6332](https://github.com/blockscout/blockscout/pull/6332) - Bump ex_cldr from 2.33.2 to 2.34.0
- [#6339](https://github.com/blockscout/blockscout/pull/6339) - Bump sweetalert2 from 11.6.0 to 11.6.2 in /apps/block_scout_web/assets
- [#6330](https://github.com/blockscout/blockscout/pull/6330) - Bump ex_cldr_units from 3.14.0 to 3.15.0
- [#6341](https://github.com/blockscout/blockscout/pull/6341) - Bump jest-environment-jsdom from 29.2.1 to 29.2.2 in /apps/block_scout_web/assets
- [#6342](https://github.com/blockscout/blockscout/pull/6342) - Bump jest from 29.2.1 to 29.2.2 in /apps/block_scout_web/assets
- [#6359](https://github.com/blockscout/blockscout/pull/6359) - Bump babel-loader from 8.2.5 to 9.0.0 in /apps/block_scout_web/assets
- [#6360](https://github.com/blockscout/blockscout/pull/6360) - Bump sweetalert2 from 11.6.2 to 11.6.4 in /apps/block_scout_web/assets
- [#6363](https://github.com/blockscout/blockscout/pull/6363) - Bump autoprefixer from 10.4.12 to 10.4.13 in /apps/block_scout_web/assets
- [#6364](https://github.com/blockscout/blockscout/pull/6364) - Bump ueberauth_auth0 from 2.0.0 to 2.1.0
- [#6372](https://github.com/blockscout/blockscout/pull/6372) - Bump babel-loader from 9.0.0 to 9.0.1 in /apps/block_scout_web/assets
- [#6374](https://github.com/blockscout/blockscout/pull/6374) - Bump plug_cowboy from 2.5.2 to 2.6.0
- [#6373](https://github.com/blockscout/blockscout/pull/6373) - Bump luxon from 3.0.4 to 3.1.0 in /apps/block_scout_web/assets
- [#6375](https://github.com/blockscout/blockscout/pull/6375) - Bump sweetalert2 from 11.6.4 to 11.6.5 in /apps/block_scout_web/assets
- [#6393](https://github.com/blockscout/blockscout/pull/6393) - Bump babel-loader from 9.0.1 to 9.1.0 in /apps/block_scout_web/assets
- [#6417](https://github.com/blockscout/blockscout/pull/6417) - Bump loader-utils from 2.0.2 to 2.0.3 in /apps/block_scout_web/assets
- [#6410](https://github.com/blockscout/blockscout/pull/6410) - Bump sweetalert2 from 11.6.5 to 11.6.7 in /apps/block_scout_web/assets
- [#6411](https://github.com/blockscout/blockscout/pull/6411) - Bump eslint from 8.26.0 to 8.27.0 in /apps/block_scout_web/assets
- [#6412](https://github.com/blockscout/blockscout/pull/6412) - Bump sass from 1.55.0 to 1.56.0 in /apps/block_scout_web/assets
- [#6413](https://github.com/blockscout/blockscout/pull/6413) - Bump jest-environment-jsdom from 29.2.2 to 29.3.0 in /apps/block_scout_web/assets
- [#6414](https://github.com/blockscout/blockscout/pull/6414) - Bump @babel/core from 7.19.6 to 7.20.2 in /apps/block_scout_web/assets
- [#6416](https://github.com/blockscout/blockscout/pull/6416) - Bump @babel/preset-env from 7.19.4 to 7.20.2 in /apps/block_scout_web/assets
- [#6419](https://github.com/blockscout/blockscout/pull/6419) - Bump jest from 29.2.2 to 29.3.1 in /apps/block_scout_web/assets
- [#6421](https://github.com/blockscout/blockscout/pull/6421) - Bump webpack from 5.74.0 to 5.75.0 in /apps/block_scout_web/assets
- [#6423](https://github.com/blockscout/blockscout/pull/6423) - Bump jest-environment-jsdom from 29.3.0 to 29.3.1 in /apps/block_scout_web/assets
- [#6424](https://github.com/blockscout/blockscout/pull/6424) - Bump floki from 0.33.1 to 0.34.0
- [#6422](https://github.com/blockscout/blockscout/pull/6422) - Bump sass from 1.56.0 to 1.56.1 in /apps/block_scout_web/assets
- [#6430](https://github.com/blockscout/blockscout/pull/6430) - Bump web3 from 1.8.0 to 1.8.1 in /apps/block_scout_web/assets
- [#6431](https://github.com/blockscout/blockscout/pull/6431) - Bump sweetalert2 from 11.6.7 to 11.6.8 in /apps/block_scout_web/assets
- [#6432](https://github.com/blockscout/blockscout/pull/6432) - Bump sass-loader from 13.1.0 to 13.2.0 in /apps/block_scout_web/assets
- [#6445](https://github.com/blockscout/blockscout/pull/6445) - Bump postcss from 8.4.18 to 8.4.19 in /apps/block_scout_web/assets
- [#6446](https://github.com/blockscout/blockscout/pull/6446) - Bump core-js from 3.26.0 to 3.26.1 in /apps/block_scout_web/assets
- [#6452](https://github.com/blockscout/blockscout/pull/6452) - Bump @fortawesome/fontawesome-free from 6.2.0 to 6.2.1 in /apps/block_scout_web/assets
- [#6456](https://github.com/blockscout/blockscout/pull/6456) - Bump loader-utils from 2.0.3 to 2.0.4 in /apps/block_scout_web/assets
- [#6462](https://github.com/blockscout/blockscout/pull/6462) - Bump chartjs-adapter-luxon from 1.2.0 to 1.2.1 in /apps/block_scout_web/assets
- [#6469](https://github.com/blockscout/blockscout/pull/6469) - Bump sweetalert2 from 11.6.8 to 11.6.9 in /apps/block_scout_web/assets
- [#6471](https://github.com/blockscout/blockscout/pull/6471) - Bump mini-css-extract-plugin from 2.6.1 to 2.7.0 in /apps/block_scout_web/assets
- [#6470](https://github.com/blockscout/blockscout/pull/6470) - Bump chart.js from 3.9.1 to 4.0.1 in /apps/block_scout_web/assets
- [#6472](https://github.com/blockscout/blockscout/pull/6472) - Bump webpack-cli from 4.10.0 to 5.0.0 in /apps/block_scout_web/assets
- [#6487](https://github.com/blockscout/blockscout/pull/6487) - Bump eslint from 8.27.0 to 8.28.0 in /apps/block_scout_web/assets
- [#6488](https://github.com/blockscout/blockscout/pull/6488) - Bump ex_doc from 0.29.0 to 0.29.1
- [#6491](https://github.com/blockscout/blockscout/pull/6491) - Bump minimatch from 3.0.4 to 3.0.8 in /apps/block_scout_web/assets
- [#6479](https://github.com/blockscout/blockscout/pull/6479) - Bump ecto_sql from 3.9.0 to 3.9.1
- [#6486](https://github.com/blockscout/blockscout/pull/6486) - Bump sweetalert2 from 11.6.9 to 11.6.10 in /apps/block_scout_web/assets
- [#6498](https://github.com/blockscout/blockscout/pull/6498) - Bump sweetalert2 from 11.6.10 to 11.6.13 in /apps/block_scout_web/assets
- [#6506](https://github.com/blockscout/blockscout/pull/6506) - Bump web3modal from 1.9.9 to 1.9.10 in /apps/block_scout_web/assets
- [#6505](https://github.com/blockscout/blockscout/pull/6505) - Bump highlight.js from 11.6.0 to 11.7.0 in /apps/block_scout_web/assets
- [#6504](https://github.com/blockscout/blockscout/pull/6504) - Bump sweetalert2 from 11.6.13 to 11.6.14 in /apps/block_scout_web/assets
- [#6507](https://github.com/blockscout/blockscout/pull/6507) - Bump remote_ip from 1.0.0 to 1.1.0
- [#6497](https://github.com/blockscout/blockscout/pull/6497) - Bump chartjs-adapter-luxon from 1.2.1 to 1.3.0 in /apps/block_scout_web/assets
- [#6519](https://github.com/blockscout/blockscout/pull/6519) - Bump photoswipe from 5.3.3 to 5.3.4 in /apps/block_scout_web/assets
- [#6520](https://github.com/blockscout/blockscout/pull/6520) - Bump @babel/core from 7.20.2 to 7.20.5 in /apps/block_scout_web/assets
- [#6527](https://github.com/blockscout/blockscout/pull/6527) - Bump luxon from 3.1.0 to 3.1.1 in /apps/block_scout_web/assets
- [#6526](https://github.com/blockscout/blockscout/pull/6526) - Bump mini-css-extract-plugin from 2.7.0 to 2.7.1 in /apps/block_scout_web/assets
- [#6533](https://github.com/blockscout/blockscout/pull/6533) - Bump postcss-loader from 7.0.1 to 7.0.2 in /apps/block_scout_web/assets
- [#6534](https://github.com/blockscout/blockscout/pull/6534) - Bump sweetalert2 from 11.6.14 to 11.6.15 in /apps/block_scout_web/assets
- [#6539](https://github.com/blockscout/blockscout/pull/6539) - Bump decode-uri-component from 0.2.0 to 0.2.2 in /apps/block_scout_web/assets
- [#6555](https://github.com/blockscout/blockscout/pull/6555) - Bump bignumber.js from 9.1.0 to 9.1.1 in /apps/block_scout_web/assets
- [#6557](https://github.com/blockscout/blockscout/pull/6557) - Bump webpack-cli from 5.0.0 to 5.0.1 in /apps/block_scout_web/assets
- [#6558](https://github.com/blockscout/blockscout/pull/6558) - Bump eslint from 8.28.0 to 8.29.0 in /apps/block_scout_web/assets
- [#6556](https://github.com/blockscout/blockscout/pull/6556) - Bump mini-css-extract-plugin from 2.7.1 to 2.7.2 in /apps/block_scout_web/assets
- [#6562](https://github.com/blockscout/blockscout/pull/6562) - Bump qs from 6.5.2 to 6.5.3 in /apps/block_scout_web/assets
- [#6577](https://github.com/blockscout/blockscout/pull/6577) - Bump postcss from 8.4.19 to 8.4.20 in /apps/block_scout_web/assets
- [#6578](https://github.com/blockscout/blockscout/pull/6578) - Bump sass from 1.56.1 to 1.56.2 in /apps/block_scout_web/assets

</details>

## 4.1.8-beta

### Features

- [#5968](https://github.com/blockscout/blockscout/pull/5968) - Add call type in the response of txlistinternal API method
- [#5860](https://github.com/blockscout/blockscout/pull/5860) - Integrate rust verifier micro-service ([blockscout-rs/verifier](https://github.com/blockscout/blockscout-rs/tree/main/verification))
- [#6001](https://github.com/blockscout/blockscout/pull/6001) - Add ETHEREUM_JSONRPC_DISABLE_ARCHIVE_BALANCES env var that filters requests and query node only if the block quantity is "latest"
- [#5944](https://github.com/blockscout/blockscout/pull/5944) - Add tab with state changes to transaction page

### Fixes

- [#6038](https://github.com/blockscout/blockscout/pull/6038) - Extend token name from string to text type
- [#6037](https://github.com/blockscout/blockscout/pull/6037) - Fix order of results in txlistinternal API endpoint
- [#6036](https://github.com/blockscout/blockscout/pull/6036) - Fix address checksum on transaction page
- [#6032](https://github.com/blockscout/blockscout/pull/6032) - Sort by address.hash column in accountlist API endpoint
- [#6017](https://github.com/blockscout/blockscout/pull/6017), [#6028](https://github.com/blockscout/blockscout/pull/6028) - Move "contract interaction" and "Add chain to MM" env vars to runtime
- [#6012](https://github.com/blockscout/blockscout/pull/6012) - Fix display of estimated addresses counter on the main page
- [#5978](https://github.com/blockscout/blockscout/pull/5978) - Allow timestamp param in the log of eth_getTransactionReceipt method
- [#5977](https://github.com/blockscout/blockscout/pull/5977) - Fix address overview.html.eex in case of nil implementation address hash
- [#5975](https://github.com/blockscout/blockscout/pull/5975) - Fix CSV export of internal transactions
- [#5957](https://github.com/blockscout/blockscout/pull/5957) - Server-side reCAPTCHA check for CSV export
- [#5954](https://github.com/blockscout/blockscout/pull/5954) - Fix ace editor appearance
- [#5942](https://github.com/blockscout/blockscout/pull/5942), [#5945](https://github.com/blockscout/blockscout/pull/5945) - Fix nightly solidity versions filtering UX
- [#5904](https://github.com/blockscout/blockscout/pull/5904) - Enhance health API endpoint: better parsing HEALTHY_BLOCKS_PERIOD and use it in the response
- [#5903](https://github.com/blockscout/blockscout/pull/5903) - Disable compile env validation
- [#5887](https://github.com/blockscout/blockscout/pull/5887) - Added missing environment variables to Makefile container params
- [#5850](https://github.com/blockscout/blockscout/pull/5850) - Fix too large postgres notifications
- [#5809](https://github.com/blockscout/blockscout/pull/5809) - Fix 404 on `/metadata` page
- [#5807](https://github.com/blockscout/blockscout/pull/5807) - Update Makefile migrate command due to release build
- [#5786](https://github.com/blockscout/blockscout/pull/5786) - Replace `current_path` with `Controller.current_full_path` in two controllers
- [#5948](https://github.com/blockscout/blockscout/pull/5948) - Fix unexpected messages in `CoinBalanceOnDemand`
- [#6013](https://github.com/blockscout/blockscout/pull/6013) - Fix ERC-1155 tokens fetching
- [#6043](https://github.com/blockscout/blockscout/pull/6043) - Fix token instance fetching
- [#6093](https://github.com/blockscout/blockscout/pull/6093) - Fix Indexer.Fetcher.TokenInstance for ERC-1155 tokens

### Chore

- [#5921](https://github.com/blockscout/blockscout/pull/5921) - Bump briefly from 25942fb to 1dd66ee
- [#6033](https://github.com/blockscout/blockscout/pull/6033) - Bump sass from 1.54.7 to 1.54.8 in /apps/block_scout_web/assets
- [#6046](https://github.com/blockscout/blockscout/pull/6046) - Bump credo from 1.6.6 to 1.6.7
- [#6045](https://github.com/blockscout/blockscout/pull/6045) - Re-use _btn_copy.html for raw trace page
- [#6035](https://github.com/blockscout/blockscout/pull/6035) - Hide copy btn if no raw trace
- [#6034](https://github.com/blockscout/blockscout/pull/6034) - Suppress empty sections in supported chain dropdown
- [#5939](https://github.com/blockscout/blockscout/pull/5939) - Bump sweetalert2 from 11.4.26 to 11.4.27 in /apps/block_scout_web/assets
- [#5938](https://github.com/blockscout/blockscout/pull/5938) - Bump xss from 1.0.13 to 1.0.14 in /apps/block_scout_web/assets
- [#5743](https://github.com/blockscout/blockscout/pull/5743) - Fixing tracer not found #5729
- [#5952](https://github.com/blockscout/blockscout/pull/5952) - Bump sweetalert2 from 11.4.27 to 11.4.28 in /apps/block_scout_web/assets
- [#5955](https://github.com/blockscout/blockscout/pull/5955) - Bump ex_doc from 0.28.4 to 0.28.5
- [#5956](https://github.com/blockscout/blockscout/pull/5956) - Bump bcrypt_elixir from 2.3.1 to 3.0.1
- [#5964](https://github.com/blockscout/blockscout/pull/5964) - Bump sweetalert2 from 11.4.28 to 11.4.29 in /apps/block_scout_web/assets
- [#5966](https://github.com/blockscout/blockscout/pull/5966) - Bump sass from 1.54.4 to 1.54.5 in /apps/block_scout_web/assets
- [#5967](https://github.com/blockscout/blockscout/pull/5967) - Bump @babel/core from 7.18.10 to 7.18.13 in /apps/block_scout_web/assets
- [#5973](https://github.com/blockscout/blockscout/pull/5973) - Bump prometheus from 4.9.0 to 4.9.1
- [#5974](https://github.com/blockscout/blockscout/pull/5974) - Bump cldr_utils from 2.19.0 to 2.19.1
- [#5884](https://github.com/blockscout/blockscout/pull/5884) - Bump nimble_csv from 1.1.0 to 1.2.0
- [#5984](https://github.com/blockscout/blockscout/pull/5984) - Bump jest from 28.1.3 to 29.0.0 in /apps/block_scout_web/assets
- [#5983](https://github.com/blockscout/blockscout/pull/5983) - Bump core-js from 3.24.1 to 3.25.0 in /apps/block_scout_web/assets
- [#5981](https://github.com/blockscout/blockscout/pull/5981) - Bump eslint-plugin-promise from 6.0.0 to 6.0.1 in /apps/block_scout_web/assets
- [#5982](https://github.com/blockscout/blockscout/pull/5982) - Bump jest-environment-jsdom from 28.1.3 to 29.0.0 in /apps/block_scout_web/assets
- [#5987](https://github.com/blockscout/blockscout/pull/5987) - Bump jest from 29.0.0 to 29.0.1 in /apps/block_scout_web/assets
- [#5988](https://github.com/blockscout/blockscout/pull/5988) - Bump jest-environment-jsdom from 29.0.0 to 29.0.1 in /apps/block_scout_web/assets
- [#5989](https://github.com/blockscout/blockscout/pull/5989) - Bump jquery from 3.6.0 to 3.6.1 in /apps/block_scout_web/assets
- [#5990](https://github.com/blockscout/blockscout/pull/5990) - Bump web3modal from 1.9.8 to 1.9.9 in /apps/block_scout_web/assets
- [#6004](https://github.com/blockscout/blockscout/pull/6004) - Bump luxon from 3.0.1 to 3.0.3 in /apps/block_scout_web/assets
- [#6005](https://github.com/blockscout/blockscout/pull/6005) - Bump ex_cldr from 2.33.1 to 2.33.2
- [#6006](https://github.com/blockscout/blockscout/pull/6006) - Bump eslint from 8.22.0 to 8.23.0 in /apps/block_scout_web/assets
- [#6015](https://github.com/blockscout/blockscout/pull/6015) - Bump @fortawesome/fontawesome-free from 6.1.2 to 6.2.0 in /apps/block_scout_web/assets
- [#6021](https://github.com/blockscout/blockscout/pull/6021) - Bump sass from 1.54.5 to 1.54.7 in /apps/block_scout_web/assets
- [#6018](https://github.com/blockscout/blockscout/pull/6018) - Update chromedriver version
- [#5836](https://github.com/blockscout/blockscout/pull/5836) - Bump comeonin from 4.1.2 to 5.3.3
- [#5869](https://github.com/blockscout/blockscout/pull/5869) - Bump reduce-reducers from 0.4.3 to 1.0.4 in /apps/block_scout_web/assets
- [#5919](https://github.com/blockscout/blockscout/pull/5919) - Bump floki from 0.32.1 to 0.33.1
- [#5930](https://github.com/blockscout/blockscout/pull/5930) - Bump eslint from 8.21.0 to 8.22.0 in /apps/block_scout_web/assets
- [#5845](https://github.com/blockscout/blockscout/pull/5845) - Bump autoprefixer from 10.4.2 to 10.4.8 in /apps/block_scout_web/assets
- [#5877](https://github.com/blockscout/blockscout/pull/5877) - Bump eslint from 8.17.0 to 8.21.0 in /apps/block_scout_web/assets
- [#5875](https://github.com/blockscout/blockscout/pull/5875) - Bump sass from 1.49.8 to 1.54.3 in /apps/block_scout_web/assets
- [#5873](https://github.com/blockscout/blockscout/pull/5873) - Bump highlight.js from 11.4.0 to 11.6.0 in /apps/block_scout_web/assets
- [#5870](https://github.com/blockscout/blockscout/pull/5870) - Bump spandex_ecto from 0.6.2 to 0.7.0
- [#5867](https://github.com/blockscout/blockscout/pull/5867) - Bump @babel/preset-env from 7.16.11 to 7.18.10 in /apps/block_scout_web/assets
- [#5876](https://github.com/blockscout/blockscout/pull/5876) - Bump bignumber.js from 9.0.2 to 9.1.0 in /apps/block_scout_web/assets
- [#5871](https://github.com/blockscout/blockscout/pull/5871) - Bump redux from 4.1.2 to 4.2.0 in /apps/block_scout_web/assets
- [#5868](https://github.com/blockscout/blockscout/pull/5868) - Bump ex_rlp from 0.5.3 to 0.5.4
- [#5874](https://github.com/blockscout/blockscout/pull/5874) - Bump core-js from 3.20.3 to 3.24.1 in /apps/block_scout_web/assets
- [#5882](https://github.com/blockscout/blockscout/pull/5882) - Bump math from 0.3.1 to 0.7.0
- [#5878](https://github.com/blockscout/blockscout/pull/5878) - Bump css-minimizer-webpack-plugin from 3.4.1 to 4.0.0 in /apps/block_scout_web/assets
- [#5883](https://github.com/blockscout/blockscout/pull/5883) - Bump postgrex from 0.15.10 to 0.15.13
- [#5885](https://github.com/blockscout/blockscout/pull/5885) - Bump hammer from 6.0.0 to 6.1.0
- [#5893](https://github.com/blockscout/blockscout/pull/5893) - Bump prometheus from 4.8.1 to 4.9.0
- [#5892](https://github.com/blockscout/blockscout/pull/5892) - Bump babel-loader from 8.2.3 to 8.2.5 in /apps/block_scout_web/assets
- [#5890](https://github.com/blockscout/blockscout/pull/5890) - Bump sweetalert2 from 11.3.10 to 11.4.26 in /apps/block_scout_web/assets
- [#5889](https://github.com/blockscout/blockscout/pull/5889) - Bump sass from 1.54.3 to 1.54.4 in /apps/block_scout_web/assets
- [#5894](https://github.com/blockscout/blockscout/pull/5894) - Bump jest from 27.4.7 to 28.1.3 in /apps/block_scout_web/assets
- [#5865](https://github.com/blockscout/blockscout/pull/5865) - Bump timex from 3.7.1 to 3.7.9
- [#5872](https://github.com/blockscout/blockscout/pull/5872) - Bump benchee from 0.13.2 to 0.99.0
- [#5895](https://github.com/blockscout/blockscout/pull/5895) - Bump wallaby from 0.29.1 to 0.30.1
- [#5905](https://github.com/blockscout/blockscout/pull/5905) - Bump absinthe from 1.6.5 to 1.6.8
- [#5881](https://github.com/blockscout/blockscout/pull/5881) - Bump dataloader from 1.0.9 to 1.0.10
- [#5909](https://github.com/blockscout/blockscout/pull/5909) - Bump junit_formatter from 3.3.0 to 3.3.1
- [#5912](https://github.com/blockscout/blockscout/pull/5912) - Bump credo from 1.6.4 to 1.6.6
- [#5911](https://github.com/blockscout/blockscout/pull/5911) - Bump absinthe_relay from 1.5.1 to 1.5.2
- [#5915](https://github.com/blockscout/blockscout/pull/5915) - Bump flow from 0.15.0 to 1.2.0
- [#5916](https://github.com/blockscout/blockscout/pull/5916) - Bump dialyxir from 1.1.0 to 1.2.0
- [#5910](https://github.com/blockscout/blockscout/pull/5910) - Bump benchee from 0.99.0 to 1.1.0
- [#5917](https://github.com/blockscout/blockscout/pull/5917) - Bump bypass from 1.0.0 to 2.1.0
- [#5920](https://github.com/blockscout/blockscout/pull/5920) - Bump spandex_datadog from 1.1.0 to 1.2.0
- [#5918](https://github.com/blockscout/blockscout/pull/5918) - Bump logger_file_backend from 0.0.12 to 0.0.13
- [#5863](https://github.com/blockscout/blockscout/pull/5863) - Update Poison hex package
- [#5861](https://github.com/blockscout/blockscout/pull/5861) - Add cache for docker build
- [#5859](https://github.com/blockscout/blockscout/pull/5859) - Update ex_cldr hex packages
- [#5858](https://github.com/blockscout/blockscout/pull/5858) - Update CHANGELOG; revert update of css-loader; rename fontawesome icons selectors
- [#5811](https://github.com/blockscout/blockscout/pull/5811) - Bump chartjs-adapter-luxon from 1.1.0 to 1.2.0 in /apps/block_scout_web/assets
- [#5814](https://github.com/blockscout/blockscout/pull/5814) - Bump webpack from 5.69.1 to 5.74.0 in /apps/block_scout_web/assets
- [#5812](https://github.com/blockscout/blockscout/pull/5812) - Bump mini-css-extract-plugin from 2.5.3 to 2.6.1 in /apps/block_scout_web/assets
- [#5819](https://github.com/blockscout/blockscout/pull/5819) - Bump xss from 1.0.10 to 1.0.13 in /apps/block_scout_web/assets
- [#5818](https://github.com/blockscout/blockscout/pull/5818) - Bump @fortawesome/fontawesome-free from 6.0.0-beta3 to 6.1.2 in /apps/block_scout_web/assets
- [#5821](https://github.com/blockscout/blockscout/pull/5821) - Bump spandex from 3.0.3 to 3.1.0
- [#5830](https://github.com/blockscout/blockscout/pull/5830) - Bump spandex_phoenix from 1.0.5 to 1.0.6
- [#5825](https://github.com/blockscout/blockscout/pull/5825) - Bump postcss from 8.4.6 to 8.4.16 in /apps/block_scout_web/assets
- [#5816](https://github.com/blockscout/blockscout/pull/5816) - Bump webpack-cli from 4.9.2 to 4.10.0 in /apps/block_scout_web/assets
- [#5822](https://github.com/blockscout/blockscout/pull/5822) - Bump chart.js from 3.7.0 to 3.9.1 in /apps/block_scout_web/assets
- [#5829](https://github.com/blockscout/blockscout/pull/5829) - Bump mox from 0.5.2 to 1.0.2
- [#5823](https://github.com/blockscout/blockscout/pull/5823) - Bump luxon from 2.4.0 to 3.0.1 in /apps/block_scout_web/assets
- [#5837](https://github.com/blockscout/blockscout/pull/5837) - Bump @walletconnect/web3-provider from 1.7.8 to 1.8.0 in /apps/block_scout_web/assets
- [#5840](https://github.com/blockscout/blockscout/pull/5840) - Bump web3modal from 1.9.5 to 1.9.8 in /apps/block_scout_web/assets
- [#5842](https://github.com/blockscout/blockscout/pull/5842) - Bump copy-webpack-plugin from 10.2.1 to 11.0.0 in /apps/block_scout_web/assets
- [#5835](https://github.com/blockscout/blockscout/pull/5835) - Bump tesla from 1.3.3 to 1.4.4
- [#5841](https://github.com/blockscout/blockscout/pull/5841) - Bump sass-loader from 12.6.0 to 13.0.2 in /apps/block_scout_web/assets
- [#5844](https://github.com/blockscout/blockscout/pull/5844) - Bump postcss-loader from 6.2.1 to 7.0.1 in /apps/block_scout_web/assets
- [#5838](https://github.com/blockscout/blockscout/pull/5838) - Bump path-parser from 4.2.0 to 6.1.0 in /apps/block_scout_web/assets
- [#5843](https://github.com/blockscout/blockscout/pull/5843) - Bump @tarekraafat/autocomplete.js from 10.2.6 to 10.2.7 in /apps/block_scout_web/assets
- [#5834](https://github.com/blockscout/blockscout/pull/5834) - Bump clipboard from 2.0.9 to 2.0.11 in /apps/block_scout_web/assets
- [#5827](https://github.com/blockscout/blockscout/pull/5827) - Bump @babel/core from 7.16.12 to 7.18.10 in /apps/block_scout_web/assets
- [#5851](https://github.com/blockscout/blockscout/pull/5851) - Bump exvcr from 0.13.2 to 0.13.3
- [#5824](https://github.com/blockscout/blockscout/pull/5824) - Bump ex_json_schema from 0.6.2 to 0.9.1
- [#5849](https://github.com/blockscout/blockscout/pull/5849) - Bump gettext 0.18.2 -> 0.20.0
- [#5806](https://github.com/blockscout/blockscout/pull/5806) - Update target Postgres version in Docker: 13 -> 14

## 4.1.7-beta

### Features

- [#5783](https://github.com/blockscout/blockscout/pull/5783) - Allow to setup multiple ranges of blocks to index

### Fixes

- [#5799](https://github.com/blockscout/blockscout/pull/5799) - Fix address_tokens_usd_sum function
- [#5798](https://github.com/blockscout/blockscout/pull/5798) - Copy explorer node_modules to result image
- [#5797](https://github.com/blockscout/blockscout/pull/5797) - Fix flickering token tooltip

### Chore

- [#5796](https://github.com/blockscout/blockscout/pull/5796) - Add job for e2e tests on every push to master + fix job "Merge 'master' to specific branch after release"

## 4.1.6-beta

### Features

- [#5739](https://github.com/blockscout/blockscout/pull/5739) - Erigon archive node support
- [#5732](https://github.com/blockscout/blockscout/pull/5732) - Manage testnet label (right to the navbar logo)
- [#5699](https://github.com/blockscout/blockscout/pull/5699) - Switch to basic (non-pro) API endpoint for Coingecko requests, if API key is not provided
- [#5542](https://github.com/blockscout/blockscout/pull/5542) - Add `jq` in docker image
- [#5345](https://github.com/blockscout/blockscout/pull/5345) - Graphql: add user-selected ordering to transactions for address query

### Fixes

- [#5768](https://github.com/blockscout/blockscout/pull/5768) - Outstanding rows limit for missing blocks query (catchup fetcher)
- [#5737](https://github.com/blockscout/blockscout/pull/5737), [#5772](https://github.com/blockscout/blockscout/pull/5772) - Fix double requests; Fix token balances dropdown view
- [#5723](https://github.com/blockscout/blockscout/pull/5723) - Add nil clause for Data.to_string/1
- [#5714](https://github.com/blockscout/blockscout/pull/5714) - Add clause for EthereumJSONRPC.Transaction.elixir_to_params/1 when gas_price is missing in the response
- [#5697](https://github.com/blockscout/blockscout/pull/5697) - Gas price oracle: ignore gas price rounding for values less than 0.01
- [#5690](https://github.com/blockscout/blockscout/pull/5690) - Allow special characters for password in DB URL parser
- [#5778](https://github.com/blockscout/blockscout/pull/5778) - Allow hyphen in database name

### Chore

- [#5787](https://github.com/blockscout/blockscout/pull/5787) - Add job for merging master to specific branch after release
- [#5788](https://github.com/blockscout/blockscout/pull/5788) - Update Docker image on every push to master branch
- [#5736](https://github.com/blockscout/blockscout/pull/5736) - Remove obsolete network selector
- [#5730](https://github.com/blockscout/blockscout/pull/5730) - Add primary keys for DB tables where they do not exist
- [#5703](https://github.com/blockscout/blockscout/pull/5703) - Remove bridged tokens functionality from Blockscout core
- [#5700](https://github.com/blockscout/blockscout/pull/5700) - Remove Staking dapp logic from Blockscout core
- [#5696](https://github.com/blockscout/blockscout/pull/5696) - Update .tool-versions
- [#5695](https://github.com/blockscout/blockscout/pull/5695) - Decimal hex package update 1.9 -> 2.0
- [#5684](https://github.com/blockscout/blockscout/pull/5684) - Block import timings logs

## 4.1.5-beta

### Features

- [#5667](https://github.com/blockscout/blockscout/pull/5667) - Address page: scroll to selected tab's data

### Fixes

- [#5680](https://github.com/blockscout/blockscout/pull/5680) - Fix broken token icons; Disable animation in lists; Fix doubled requests for some pages
- [#5671](https://github.com/blockscout/blockscout/pull/5671) - Fix double requests for token exchange rates; Disable fetching `btc_value` by default (add `EXCHANGE_RATES_FETCH_BTC_VALUE` env variable); Add `CACHE_EXCHANGE_RATES_PERIOD` env variable
- [#5676](https://github.com/blockscout/blockscout/pull/5676) - Fix wrong miner address shown for post EIP-1559 block for clique network

### Chore

- [#5679](https://github.com/blockscout/blockscout/pull/5679) - Optimize query in fetch_min_missing_block_cache function
- [#5674](https://github.com/blockscout/blockscout/pull/5674) - Disable token holder refreshing
- [#5661](https://github.com/blockscout/blockscout/pull/5661) - Fixes yaml syntax for boolean env variables in docker compose

## 4.1.4-beta

### Features

- [#5656](https://github.com/blockscout/blockscout/pull/5656) - Gas price oracle
- [#5613](https://github.com/blockscout/blockscout/pull/5613) - Exchange rates CoinMarketCap source module
- [#5588](https://github.com/blockscout/blockscout/pull/5588) - Add broadcasting of coin balance
- [#5560](https://github.com/blockscout/blockscout/pull/5560) - Manual fetch beneficiaries
- [#5479](https://github.com/blockscout/blockscout/pull/5479) - Remake of solidity verifier module; Verification UX improvements
- [#5540](https://github.com/blockscout/blockscout/pull/5540) - Tx page: scroll to selected tab's data

### Fixes

- [#5647](https://github.com/blockscout/blockscout/pull/5647) - Add handling for invalid Sourcify response
- [#5635](https://github.com/blockscout/blockscout/pull/5635) - Set CoinGecko source in exchange_rates_source function fix in case of token_bridge
- [#5629](https://github.com/blockscout/blockscout/pull/5629) - Fix empty coin balance for empty address
- [#5612](https://github.com/blockscout/blockscout/pull/5612) - Fix token transfers order
- [#5626](https://github.com/blockscout/blockscout/pull/5626) - Fix vyper compiler versions order
- [#5603](https://github.com/blockscout/blockscout/pull/5603) - Fix failing verification attempts
- [#5598](https://github.com/blockscout/blockscout/pull/5598) - Fix token dropdown
- [#5592](https://github.com/blockscout/blockscout/pull/5592) - Burn fees for legacy transactions
- [#5568](https://github.com/blockscout/blockscout/pull/5568) - Add regexp for ipfs checking
- [#5567](https://github.com/blockscout/blockscout/pull/5567) - Sanitize token name and symbol before insert into DB, display in the application
- [#5564](https://github.com/blockscout/blockscout/pull/5564) - Add fallback clauses to `string_to_..._hash` functions
- [#5538](https://github.com/blockscout/blockscout/pull/5538) - Fix internal transaction's tile bug

### Chore

- [#5660](https://github.com/blockscout/blockscout/pull/5660) - Display txs count chart by default, disable price chart by default, add chart titles
- [#5659](https://github.com/blockscout/blockscout/pull/5659) - Use chartjs-adapter-luxon instead chartjs-adapter-moment for charts
- [#5651](https://github.com/blockscout/blockscout/pull/5651), [#5657](https://github.com/blockscout/blockscout/pull/5657) - Gnosis chain rebranded theme and generalization of chart legend colors definition
- [#5640](https://github.com/blockscout/blockscout/pull/5640) - Clean up and fix tests, reduce amount of warnings
- [#5625](https://github.com/blockscout/blockscout/pull/5625) - Get rid of some redirects to checksummed address url
- [#5623](https://github.com/blockscout/blockscout/pull/5623) - Allow hyphen in DB password
- [#5543](https://github.com/blockscout/blockscout/pull/5543) - Increase max_restarts to 1_000 (from 3 by default) for explorer, block_scout_web supervisors
- [#5536](https://github.com/blockscout/blockscout/pull/5536) - NPM audit fix

## 4.1.3-beta

### Features

- [#5515](https://github.com/blockscout/blockscout/pull/5515) - Integrate ace editor to display contract sources
- [#5505](https://github.com/blockscout/blockscout/pull/5505) - Manage debug_traceTransaction JSON RPC method timeout
- [#5491](https://github.com/blockscout/blockscout/pull/5491) - Sequential blocks broadcast on the main page
- [#5312](https://github.com/blockscout/blockscout/pull/5312) - Add OpenZeppelin proxy storage slot
- [#5302](https://github.com/blockscout/blockscout/pull/5302) - Add specific tx receipt fields for the GoQuorum client
- [#5268](https://github.com/blockscout/blockscout/pull/5268), [#5313](https://github.com/blockscout/blockscout/pull/5313) - Contract names display improvement

### Fixes

- [#5528](https://github.com/blockscout/blockscout/pull/5528) - Token balances fetcher retry
- [#5524](https://github.com/blockscout/blockscout/pull/5524) - ContractState module resistance to unresponsive archive node
- [#5513](https://github.com/blockscout/blockscout/pull/5513) - Do not fill pending blocks ops with block numbers below TRACE_FIRST_BLOCK
- [#5508](https://github.com/blockscout/blockscout/pull/5508) - Hide indexing banner if we fetched internal transactions from TRACE_FIRST_BLOCK
- [#5504](https://github.com/blockscout/blockscout/pull/5504) - Extend TRACE_FIRST_BLOCK env var to geth variant
- [#5488](https://github.com/blockscout/blockscout/pull/5488) - Split long contract output to multiple lines
- [#5487](https://github.com/blockscout/blockscout/pull/5487) - Fix array displaying in decoded constructor args
- [#5482](https://github.com/blockscout/blockscout/pull/5482) - Fix for querying of the contract read functions
- [#5455](https://github.com/blockscout/blockscout/pull/5455) - Fix unverified_smart_contract function: add md5 of bytecode to the changeset
- [#5454](https://github.com/blockscout/blockscout/pull/5454) - Docker: Fix the qemu-x86_64 signal 11 error on Apple Silicon
- [#5443](https://github.com/blockscout/blockscout/pull/5443) - Geth: display tx revert reason
- [#5420](https://github.com/blockscout/blockscout/pull/5420) - Deduplicate addresses and coin balances before inserting to the DB
- [#5416](https://github.com/blockscout/blockscout/pull/5416) - Fix getsourcecode for EOA addresses
- [#5413](https://github.com/blockscout/blockscout/pull/5413) - Fix params encoding for read contracts methods
- [#5411](https://github.com/blockscout/blockscout/pull/5411) - Fix character_not_in_repertoire error for tx revert reason
- [#5410](https://github.com/blockscout/blockscout/pull/5410) - Handle exited realtime fetcher
- [#5383](https://github.com/blockscout/blockscout/pull/5383) - Fix reload transactions button
- [#5381](https://github.com/blockscout/blockscout/pull/5381), [#5397](https://github.com/blockscout/blockscout/pull/5397) - Fix exchange rate broadcast error
- [#5375](https://github.com/blockscout/blockscout/pull/5375) - Fix pending transactions fetcher
- [#5374](https://github.com/blockscout/blockscout/pull/5374) - Return all ERC-1155's token instances in tokenList api endpoint
- [#5342](https://github.com/blockscout/blockscout/pull/5342) - Fix 500 error on NF token page with nil metadata
- [#5319](https://github.com/blockscout/blockscout/pull/5319), [#5357](https://github.com/blockscout/blockscout/pull/5357), [#5425](https://github.com/blockscout/blockscout/pull/5425) - Empty blocks sanitizer performance improvement
- [#5310](https://github.com/blockscout/blockscout/pull/5310) - Fix flash on reload in dark mode
- [#5306](https://github.com/blockscout/blockscout/pull/5306) - Fix indexer bug
- [#5300](https://github.com/blockscout/blockscout/pull/5300), [#5305](https://github.com/blockscout/blockscout/pull/5305) - Token instance page: general video improvements
- [#5136](https://github.com/blockscout/blockscout/pull/5136) - Improve contract verification
- [#5285](https://github.com/blockscout/blockscout/pull/5285) - Fix verified smart-contract bytecode twins feature
- [#5269](https://github.com/blockscout/blockscout/pull/5269) - Address Page: Fix implementation address align
- [#5264](https://github.com/blockscout/blockscout/pull/5264) - Fix bug with 500 response on `partial` sourcify status
- [#5263](https://github.com/blockscout/blockscout/pull/5263) - Fix bug with name absence for contract
- [#5259](https://github.com/blockscout/blockscout/pull/5259) - Fix `coin-balances/by-day` bug
- [#5239](https://github.com/blockscout/blockscout/pull/5239) - Add accounting for block rewards in `getblockreward` api method

### Chore

- [#5506](https://github.com/blockscout/blockscout/pull/5506) - Refactor config files
- [#5480](https://github.com/blockscout/blockscout/pull/5480) - Remove duplicate of balances_params_to_address_params function
- [#5473](https://github.com/blockscout/blockscout/pull/5473) - Refactor daily coin balances fetcher
- [#5458](https://github.com/blockscout/blockscout/pull/5458) - Decrease min safe polling period for realtime fetcher
- [#5456](https://github.com/blockscout/blockscout/pull/5456) - Ignore arbitrary block details fields for custom Ethereum clients
- [#5450](https://github.com/blockscout/blockscout/pull/5450) - Logging error in publishing of smart-contract
- [#5433](https://github.com/blockscout/blockscout/pull/5433) - Caching modules refactoring
- [#5419](https://github.com/blockscout/blockscout/pull/5419) - Add check if address exists for some api methods
- [#5408](https://github.com/blockscout/blockscout/pull/5408) - Update websocket_client hex package
- [#5407](https://github.com/blockscout/blockscout/pull/5407) - Update hackney, certifi, tzdata
- [#5369](https://github.com/blockscout/blockscout/pull/5369) - Manage indexer memory limit
- [#5368](https://github.com/blockscout/blockscout/pull/5368) - Refactoring from SourcifyFilePathBackfiller
- [#5367](https://github.com/blockscout/blockscout/pull/5367) - Resolve Prototype Pollution in minimist dependency
- [#5366](https://github.com/blockscout/blockscout/pull/5366) - Fix Vyper smart-contract verification form tooltips
- [#5348](https://github.com/blockscout/blockscout/pull/5348) - Block data for Avalanche: pass blockExtraData param
- [#5341](https://github.com/blockscout/blockscout/pull/5341) - Remove unused broadcasts
- [#5318](https://github.com/blockscout/blockscout/pull/5318) - Eliminate Jquery import from chart-loader.js
- [#5317](https://github.com/blockscout/blockscout/pull/5317) - NPM audit
- [#5303](https://github.com/blockscout/blockscout/pull/5303) - Besu: revertReason support in trace
- [#5301](https://github.com/blockscout/blockscout/pull/5301) - Allow specific block keys for sgb/ava
- [#5295](https://github.com/blockscout/blockscout/pull/5295) - CI pipeline: build and push Docker image to Docker Hub on every release
- [#5290](https://github.com/blockscout/blockscout/pull/5290) - Bump ex_doc from 0.25.2 to 0.28.2
- [#5289](https://github.com/blockscout/blockscout/pull/5289) - Bump ex_abi from 1.5.9 to 1.5.11
- [#5288](https://github.com/blockscout/blockscout/pull/5288) - Makefile: find exact container by name
- [#5287](https://github.com/blockscout/blockscout/pull/5287) - Docker: modify native token symbol
- [#5286](https://github.com/blockscout/blockscout/pull/5286) - Change namespace for one of the SmartContractViewTest test
- [#5260](https://github.com/blockscout/blockscout/pull/5260) - Makefile release task to prerelease and release task
- [#5082](https://github.com/blockscout/blockscout/pull/5082) - Elixir 1.12 -> 1.13

## 4.1.2-beta

### Features

- [#5232](https://github.com/blockscout/blockscout/pull/5232) - Contract Read Page: Add functions overloading support
- [#5220](https://github.com/blockscout/blockscout/pull/5220) - Add info about proxy contracts to api methods response
- [#5200](https://github.com/blockscout/blockscout/pull/5200) - Docker-compose configuration
- [#5105](https://github.com/blockscout/blockscout/pull/5105) - Redesign token page
- [#5016](https://github.com/blockscout/blockscout/pull/5016) - Add view for internal transactions error
- [#4690](https://github.com/blockscout/blockscout/pull/4690) - Improve pagination: introduce pagination with random access to pages; Integrate it to the Transactions List page

### Fixes

- [#5248](https://github.com/blockscout/blockscout/pull/5248) - Speedup query for getting verified smart-contract bytecode twin
- [#5241](https://github.com/blockscout/blockscout/pull/5241) - Fix DB hostname Regex pattern
- [#5216](https://github.com/blockscout/blockscout/pull/5216) - Add token-transfers-toggle.js to the `block_transaction/index.html.eex`
- [#5212](https://github.com/blockscout/blockscout/pull/5212) - Fix `gas_used` value bug
- [#5197](https://github.com/blockscout/blockscout/pull/5197) - Fix contract functions outputs
- [#5196](https://github.com/blockscout/blockscout/pull/5196) - Various Docker setup fixes
- [#5192](https://github.com/blockscout/blockscout/pull/5192) - Fix DATABASE_URL config parser
- [#5191](https://github.com/blockscout/blockscout/pull/5191) - Add empty view for new addresses
- [#5184](https://github.com/blockscout/blockscout/pull/5184) - eth_call method: remove from param from the request, if it is null
- [#5172](https://github.com/blockscout/blockscout/pull/5172), [#5182](https://github.com/blockscout/blockscout/pull/5182) - Reduced the size of js bundles
- [#5169](https://github.com/blockscout/blockscout/pull/5169) - Fix several UI bugs; Add tooltip to the prev/next block buttons
- [#5166](https://github.com/blockscout/blockscout/pull/5166), [#5198](https://github.com/blockscout/blockscout/pull/5198) - Fix contracts verification bugs
- [#5160](https://github.com/blockscout/blockscout/pull/5160) - Fix blocks validated hint
- [#5155](https://github.com/blockscout/blockscout/pull/5155) - Fix get_implementation_abi_from_proxy/2 implementation
- [#5154](https://github.com/blockscout/blockscout/pull/5154) - Fix token counters bug
- [#4862](https://github.com/blockscout/blockscout/pull/4862) - Fix internal transactions pagination

### Chore

- [#5230](https://github.com/blockscout/blockscout/pull/5230) - Contract verification forms refactoring
- [#5227](https://github.com/blockscout/blockscout/pull/5227) - Major update of css-loader npm package
- [#5226](https://github.com/blockscout/blockscout/pull/5226) - Update mini-css-extract-plugin, css-minimizer-webpack-plugin packages
- [#5224](https://github.com/blockscout/blockscout/pull/5224) - Webpack config refactoring
- [#5223](https://github.com/blockscout/blockscout/pull/5223) - Migrate fontawesome 5 -> 6
- [#5202](https://github.com/blockscout/blockscout/pull/5202), [#5229](https://github.com/blockscout/blockscout/pull/5229) - Docker setup Makefile release/publish tasks
- [#5195](https://github.com/blockscout/blockscout/pull/5195) - Add Berlin, London to the list of default EVM versions
- [#5190](https://github.com/blockscout/blockscout/pull/5190) - Set 8545 as default port everywhere except Ganache JSON RPC variant
- [#5189](https://github.com/blockscout/blockscout/pull/5189) - ENV var to manage pending transactions fetcher switching off
- [#5171](https://github.com/blockscout/blockscout/pull/5171) - Replace lodash NPM package with tiny lodash modules
- [#5170](https://github.com/blockscout/blockscout/pull/5170) - Token price row name fix
- [#5153](https://github.com/blockscout/blockscout/pull/5153) - Discord link instead of Gitter
- [#5142](https://github.com/blockscout/blockscout/pull/5142) - Updated some outdated npm packages
- [#5140](https://github.com/blockscout/blockscout/pull/5140) - Babel minor and core-js major updates
- [#5139](https://github.com/blockscout/blockscout/pull/5139) - Eslint major update
- [#5138](https://github.com/blockscout/blockscout/pull/5138) - Webpack minor update
- [#5119](https://github.com/blockscout/blockscout/pull/5119) - Inventory controller refactoring
- [#5118](https://github.com/blockscout/blockscout/pull/5118) - Fix top navigation template

## 4.1.1-beta

### Features

- [#5090](https://github.com/blockscout/blockscout/pull/5090) - Allotted rate limit by IP
- [#5080](https://github.com/blockscout/blockscout/pull/5080) - Allotted rate limit by a global API key

### Fixes

- [#5085](https://github.com/blockscout/blockscout/pull/5085) - Fix wallet style
- [#5088](https://github.com/blockscout/blockscout/pull/5088) - Store address transactions/token transfers in the DB
- [#5071](https://github.com/blockscout/blockscout/pull/5071) - Fix write page contract tuple input
- [#5066](https://github.com/blockscout/blockscout/pull/5066) - Fix read contract page bug
- [#5034](https://github.com/blockscout/blockscout/pull/5034) - Fix broken functions input at transaction page
- [#5025](https://github.com/blockscout/blockscout/pull/5025) - Add standard input JSON files validation
- [#5051](https://github.com/blockscout/blockscout/pull/5051) - Fix 500 response when ABI method was parsed as nil

### Chore

- [#5092](https://github.com/blockscout/blockscout/pull/5092) - Resolve vulnerable follow-redirects npm dep in ./apps/explorer
- [#5091](https://github.com/blockscout/blockscout/pull/5091) - Refactor search page template
- [#5081](https://github.com/blockscout/blockscout/pull/5081) - Add internal transactions fetcher disabled? config parameter
- [#5063](https://github.com/blockscout/blockscout/pull/5063) - Resolve moderate NPM vulnerabilities with npm audit tool
- [#5053](https://github.com/blockscout/blockscout/pull/5053) - Update ex_keccak lib

## 4.1.0-beta

### Features

- [#5030](https://github.com/blockscout/blockscout/pull/5030) - API rate limiting
- [#4924](https://github.com/blockscout/blockscout/pull/4924) - Add daily bytecode verification to prevent metamorphic contracts vulnerability
- [#4908](https://github.com/blockscout/blockscout/pull/4908) - Add verification via standard JSON input
- [#5004](https://github.com/blockscout/blockscout/pull/5004) - Add ability to set up a separate DB endpoint for the API endpoints
- [#4989](https://github.com/blockscout/blockscout/pull/4989), [#4991](https://github.com/blockscout/blockscout/pull/4991) - Bridged tokens list API endpoint
- [#4931](https://github.com/blockscout/blockscout/pull/4931) - Web3 modal with Wallet Connect for Write contract page and Staking Dapp

### Fixes

- [#5045](https://github.com/blockscout/blockscout/pull/5045) - Contracts interaction improvements
- [#5032](https://github.com/blockscout/blockscout/pull/5032) - Fix token transfer csv export
- [#5020](https://github.com/blockscout/blockscout/pull/5020) - Token instance image display improvement
- [#5019](https://github.com/blockscout/blockscout/pull/5019) - Fix fetch_last_token_balance function termination
- [#5011](https://github.com/blockscout/blockscout/pull/5011) - Fix `0x0` implementation address
- [#5008](https://github.com/blockscout/blockscout/pull/5008) - Extend decimals cap in format_according_to_decimals up to 24
- [#5005](https://github.com/blockscout/blockscout/pull/5005) - Fix falsy appearance `Connection Lost` warning on reload/switch page
- [#5003](https://github.com/blockscout/blockscout/pull/5003) - API router refactoring
- [#4992](https://github.com/blockscout/blockscout/pull/4992) - Fix `type` field in transactions after enabling 1559
- [#4979](https://github.com/blockscout/blockscout/pull/4979), [#4993](https://github.com/blockscout/blockscout/pull/4993) - Store total gas_used in addresses table
- [#4977](https://github.com/blockscout/blockscout/pull/4977) - Export token transfers on address: include transfers on contract itself
- [#4976](https://github.com/blockscout/blockscout/pull/4976) - Handle :econnrefused in pending transactions fetcher
- [#4965](https://github.com/blockscout/blockscout/pull/4965) - Fix search field appearance on medium size screens
- [#4945](https://github.com/blockscout/blockscout/pull/4945) - Fix `Verify & Publish` button link
- [#4938](https://github.com/blockscout/blockscout/pull/4938) - Fix displaying of nested arrays for contracts read
- [#4888](https://github.com/blockscout/blockscout/pull/4888) - Fix fetch_top_tokens method: add nulls last for token holders desc order
- [#4867](https://github.com/blockscout/blockscout/pull/4867) - Fix bug in querying contracts method and improve contracts interactions

### Chore

- [#5047](https://github.com/blockscout/blockscout/pull/5047) - At contract write use wei precision
- [#5023](https://github.com/blockscout/blockscout/pull/5023) - Capability to leave an empty logo
- [#5018](https://github.com/blockscout/blockscout/pull/5018) - Resolve npm vulnerabilities via npm audix fix
- [#5014](https://github.com/blockscout/blockscout/pull/5014) - Separate FIRST_BLOCK and TRACE_FIRST_BLOCK option for blocks import and tracing methods
- [#4998](https://github.com/blockscout/blockscout/pull/4998) - API endpoints logger
- [#4983](https://github.com/blockscout/blockscout/pull/4983), [#5038](https://github.com/blockscout/blockscout/pull/5038) - Fix contract verification tests
- [#4861](https://github.com/blockscout/blockscout/pull/4861) - Add separate column for token icons

## 4.0.0-beta

### Features

- [#4807](https://github.com/blockscout/blockscout/pull/4807) - Added support for BeaconProxy pattern
- [#4777](https://github.com/blockscout/blockscout/pull/4777), [#4791](https://github.com/blockscout/blockscout/pull/4791), [#4799](https://github.com/blockscout/blockscout/pull/4799), [#4847](https://github.com/blockscout/blockscout/pull/4847) - Added decoding revert reason
- [#4776](https://github.com/blockscout/blockscout/pull/4776) - Added view for unsuccessfully fetched values from read functions
- [#4761](https://github.com/blockscout/blockscout/pull/4761) - ERC-1155 support
- [#4739](https://github.com/blockscout/blockscout/pull/4739) - Improve logs and inputs decoding
- [#4747](https://github.com/blockscout/blockscout/pull/4747) - Advanced CSV export
- [#4745](https://github.com/blockscout/blockscout/pull/4745) - Vyper contracts verification
- [#4699](https://github.com/blockscout/blockscout/pull/4699), [#4793](https://github.com/blockscout/blockscout/pull/4793), [#4820](https://github.com/blockscout/blockscout/pull/4820), [#4827](https://github.com/blockscout/blockscout/pull/4827) - Address page face lifting
- [#4667](https://github.com/blockscout/blockscout/pull/4667) - Transaction Page: Add expand/collapse button for long contract method data
- [#4641](https://github.com/blockscout/blockscout/pull/4641), [#4733](https://github.com/blockscout/blockscout/pull/4733) - Improve Read Contract page logic
- [#4660](https://github.com/blockscout/blockscout/pull/4660) - Save Sourcify path instead of filename
- [#4656](https://github.com/blockscout/blockscout/pull/4656) - Open in Tenderly button
- [#4655](https://github.com/blockscout/blockscout/pull/4655), [#4676](https://github.com/blockscout/blockscout/pull/4676) - EIP-3091 support
- [#4621](https://github.com/blockscout/blockscout/pull/4621) - Add beacon contract address slot for proxy
- [#4625](https://github.com/blockscout/blockscout/pull/4625) - Contract address page: Add implementation link to the overview of proxy contracts
- [#4624](https://github.com/blockscout/blockscout/pull/4624) - Support HTML tags in alert message
- [#4608](https://github.com/blockscout/blockscout/pull/4608), [#4622](https://github.com/blockscout/blockscout/pull/4622) - Block Details page: Improved style of transactions button
- [#4596](https://github.com/blockscout/blockscout/pull/4596), [#4681](https://github.com/blockscout/blockscout/pull/4681), [#4693](https://github.com/blockscout/blockscout/pull/4693) - Display token icon for bridged with Mainnet tokens or identicons for other tokens
- [#4520](https://github.com/blockscout/blockscout/pull/4520) - Add support for EIP-1559
- [#4593](https://github.com/blockscout/blockscout/pull/4593) - Add status in `Position` pane for txs have no block
- [#4579](https://github.com/blockscout/blockscout/pull/4579) - Write contract page: Resize inputs; Improve multiplier selector

### Fixes

- [#4857](https://github.com/blockscout/blockscout/pull/4857) - Fix `tx/raw-trace` Internal Server Error
- [#4854](https://github.com/blockscout/blockscout/pull/4854) - Fix infinite gas usage count loading
- [#4853](https://github.com/blockscout/blockscout/pull/4853) - Allow custom optimizations runs for contract verifications via API
- [#4840](https://github.com/blockscout/blockscout/pull/4840) - Replace Enum.dedup with Enum.uniq where actually uniq items are expected
- [#4835](https://github.com/blockscout/blockscout/pull/4835) - Fix view for broken token icons
- [#4830](https://github.com/blockscout/blockscout/pull/4830) - Speed up txs per day chart data collection
- [#4818](https://github.com/blockscout/blockscout/pull/4818) - Fix for extract_omni_bridged_token_metadata_wrapper method
- [#4812](https://github.com/blockscout/blockscout/pull/4812), [#4815](https://github.com/blockscout/blockscout/pull/4815) - Check if exists custom_cap property of extended token object before access it
- [#4810](https://github.com/blockscout/blockscout/pull/4810) - Show `nil` block.size as `N/A bytes`
- [#4806](https://github.com/blockscout/blockscout/pull/4806) - Get token type for token balance update if it is empty
- [#4802](https://github.com/blockscout/blockscout/pull/4802) - Fix floating tooltip on the main page
- [#4801](https://github.com/blockscout/blockscout/pull/4801) - Added clauses and tests for get_total_staked_and_ordered/1
- [#4798](https://github.com/blockscout/blockscout/pull/4798) - Token instance View contract icon Safari fix
- [#4796](https://github.com/blockscout/blockscout/pull/4796) - Fix nil.timestamp issue
- [#4764](https://github.com/blockscout/blockscout/pull/4764) - Add cleaning of substrings of `require` messages from parsed constructor arguments
- [#4778](https://github.com/blockscout/blockscout/pull/4778) - Migrate :optimization_runs field type: `int4 -> int8` in `smart_contracts` table
- [#4768](https://github.com/blockscout/blockscout/pull/4768) - Block Details page: handle zero division
- [#4751](https://github.com/blockscout/blockscout/pull/4751) - Change text and link for `trade STAKE` button
- [#4746](https://github.com/blockscout/blockscout/pull/4746) - Fix comparison of decimal value
- [#4711](https://github.com/blockscout/blockscout/pull/4711) - Add trimming to the contract functions inputs
- [#4729](https://github.com/blockscout/blockscout/pull/4729) - Fix bugs with fees in cases of txs with `gas price = 0`
- [#4725](https://github.com/blockscout/blockscout/pull/4725) - Fix hardcoded coin name on transaction's and block's page
- [#4724](https://github.com/blockscout/blockscout/pull/4724), [#4842](https://github.com/blockscout/blockscout/pull/4841) - Sanitizer of "empty" blocks
- [#4717](https://github.com/blockscout/blockscout/pull/4717) - Contract verification fix: check only success creation tx
- [#4713](https://github.com/blockscout/blockscout/pull/4713) - Search input field: sanitize input
- [#4703](https://github.com/blockscout/blockscout/pull/4703) - Block Details page: Fix pagination on the Transactions tab
- [#4686](https://github.com/blockscout/blockscout/pull/4686) - Block page: check gas limit value before division
- [#4678](https://github.com/blockscout/blockscout/pull/4678) - Internal transactions indexer: fix issue of some pending transactions never become confirmed
- [#4668](https://github.com/blockscout/blockscout/pull/4668) - Fix css for dark theme
- [#4654](https://github.com/blockscout/blockscout/pull/4654) - AddressView: Change `@burn_address` to string `0x0000000000000000000000000000000000000000`
- [#4626](https://github.com/blockscout/blockscout/pull/4626) - Refine view of popup for reverted tx
- [#4640](https://github.com/blockscout/blockscout/pull/4640) - Token page: fixes in mobile view
- [#4612](https://github.com/blockscout/blockscout/pull/4612) - Hide error selector in the contract's functions list
- [#4615](https://github.com/blockscout/blockscout/pull/4615) - Fix broken style for `View more transfers` button
- [#4592](https://github.com/blockscout/blockscout/pull/4592) - Add `type` field for `receive` and `fallback` entities of a Smart Contract
- [#4601](https://github.com/blockscout/blockscout/pull/4601) - Fix endless Fetching tokens... message on empty addresses
- [#4591](https://github.com/blockscout/blockscout/pull/4591) - Add step and min value for txValue input field
- [#4589](https://github.com/blockscout/blockscout/pull/4589) - Fix solid outputs on contract read page
- [#4586](https://github.com/blockscout/blockscout/pull/4586) - Fix floating tooltips on the token transfer family blocks
- [#4587](https://github.com/blockscout/blockscout/pull/4587) - Enable navbar menu on Search results page
- [#4582](https://github.com/blockscout/blockscout/pull/4582) - Fix NaN input on write contract page

### Chore

- [#4876](https://github.com/blockscout/blockscout/pull/4876) - Add missing columns updates when INSERT ... ON CONFLICT DO UPDATE ... happens
- [#4872](https://github.com/blockscout/blockscout/pull/4872) - Set explicit ascending order by hash in acquire transactions query of internal transactions import
- [#4871](https://github.com/blockscout/blockscout/pull/4871) - Remove cumulative gas used update duplicate
- [#4860](https://github.com/blockscout/blockscout/pull/4860) - Node 16 support
- [#4828](https://github.com/blockscout/blockscout/pull/4828) - Logging for txs/day chart
- [#4823](https://github.com/blockscout/blockscout/pull/4823) - Various error handlers with unresponsive JSON RPC endpoint
- [#4821](https://github.com/blockscout/blockscout/pull/4821) - Block Details page: Remove crossing at the Burnt Fee line
- [#4819](https://github.com/blockscout/blockscout/pull/4819) - Add config for GasUsage Cache
- [#4781](https://github.com/blockscout/blockscout/pull/4781) - PGAnalyze index suggestions
- [#4735](https://github.com/blockscout/blockscout/pull/4735) - Code clean up: Remove clauses for outdated ganache bugs
- [#4726](https://github.com/blockscout/blockscout/pull/4726) - Update chart.js
- [#4707](https://github.com/blockscout/blockscout/pull/4707) - Top navigation: Move Accounts tab to Tokens
- [#4704](https://github.com/blockscout/blockscout/pull/4704) - Update to Erlang/OTP 24
- [#4682](https://github.com/blockscout/blockscout/pull/4682) - Update all possible outdated mix dependencies
- [#4663](https://github.com/blockscout/blockscout/pull/4663) - Migrate to Elixir 1.12.x
- [#4661](https://github.com/blockscout/blockscout/pull/4661) - Update NPM packages to resolve vulnerabilities
- [#4649](https://github.com/blockscout/blockscout/pull/4649) - 1559 Transaction Page: Convert Burnt Fee to ether and add price in USD
- [#4646](https://github.com/blockscout/blockscout/pull/4646) - Transaction page: Rename burned to burnt
- [#4611](https://github.com/blockscout/blockscout/pull/4611) - Ability to hide miner in block views

## 3.7.3-beta

### Features

- [#4569](https://github.com/blockscout/blockscout/pull/4569) - Smart-Contract: remove comment with the submission date
- [#4568](https://github.com/blockscout/blockscout/pull/4568) - TX page: Token transfer and minting section improvements
- [#4540](https://github.com/blockscout/blockscout/pull/4540) - Align copy buttons for `Block Details` and `Transaction Details` pages
- [#4528](https://github.com/blockscout/blockscout/pull/4528) - Block Details page: rework view
- [#4531](https://github.com/blockscout/blockscout/pull/4531) - Add Arbitrum support
- [#4524](https://github.com/blockscout/blockscout/pull/4524) - Add index position of transaction in the block
- [#4489](https://github.com/blockscout/blockscout/pull/4489) - Search results page
- [#4475](https://github.com/blockscout/blockscout/pull/4475) - Tx page face lifting
- [#4452](https://github.com/blockscout/blockscout/pull/4452) - Add names for smart-contract's function response

### Fixes

- [#4553](https://github.com/blockscout/blockscout/pull/4553) - Indexer performance update: skip genesis block in requesting of trace_block API endpoint
- [#4544](https://github.com/blockscout/blockscout/pull/4544) - Indexer performance update: Add skip_metadata flag for token if indexer failed to get any of [name, symbol, decimals, totalSupply]
- [#4542](https://github.com/blockscout/blockscout/pull/4542) - Indexer performance update: Deduplicate tokens in the indexer token transfers transformer
- [#4535](https://github.com/blockscout/blockscout/pull/4535) - Indexer performance update:: Eliminate multiple updates of the same token while parsing mint/burn token transfers batch
- [#4527](https://github.com/blockscout/blockscout/pull/4527) - Indexer performance update: refactor coin balance daily fetcher
- [#4525](https://github.com/blockscout/blockscout/pull/4525) - Uncataloged token transfers query performance improvement
- [#4513](https://github.com/blockscout/blockscout/pull/4513) - Fix installation with custom default path: add NETWORK_PATH variable to the current_path
- [#4500](https://github.com/blockscout/blockscout/pull/4500) - `/tokens/{addressHash}/instance/{id}/token-transfers`: fix incorrect next page url
- [#4493](https://github.com/blockscout/blockscout/pull/4493) - Contract's code page: handle null contracts_creation_transaction
- [#4488](https://github.com/blockscout/blockscout/pull/4488) - Tx page: handle empty to_address
- [#4483](https://github.com/blockscout/blockscout/pull/4483) - Fix copy-paste typo in `token_transfers_counter.ex`
- [#4473](https://github.com/blockscout/blockscout/pull/4473), [#4481](https://github.com/blockscout/blockscout/pull/4481) - Search autocomplete: fix for address/block/tx hash
- [#4472](https://github.com/blockscout/blockscout/pull/4472) - Search autocomplete: fix Cannot read property toLowerCase of undefined
- [#4456](https://github.com/blockscout/blockscout/pull/4456) - URL encoding for NFT media files URLs
- [#4453](https://github.com/blockscout/blockscout/pull/4453) - Unescape characters for string output type in the contract response
- [#4401](https://github.com/blockscout/blockscout/pull/4401) - Fix displaying of token holders with the same amount

### Chore

- [#4550](https://github.com/blockscout/blockscout/pull/4550) - Update con_cache package to 1.0
- [#4523](https://github.com/blockscout/blockscout/pull/4523) - Change order of transactions in block's view
- [#4521](https://github.com/blockscout/blockscout/pull/4521) - Rewrite transaction page tooltips
- [#4516](https://github.com/blockscout/blockscout/pull/4516) - Add DB migrations step into Docker start script
- [#4497](https://github.com/blockscout/blockscout/pull/4497) - Handle error in fetch_validators_list method
- [#4444](https://github.com/blockscout/blockscout/pull/4444) - Main page performance cumulative update
- [#4439](https://github.com/blockscout/blockscout/pull/4439), - [#4465](https://github.com/blockscout/blockscout/pull/4465) - Fix revert response in contract's output

## 3.7.2-beta

### Features

- [#4424](https://github.com/blockscout/blockscout/pull/4424) - Display search results categories
- [#4423](https://github.com/blockscout/blockscout/pull/4423) - Add creation time of contract in the results of the search
- [#4391](https://github.com/blockscout/blockscout/pull/4391) - Add batched transactions on the `address/{addressHash}/transactions` page
- [#4353](https://github.com/blockscout/blockscout/pull/4353) - Added live-reload on the token holders page

### Fixes

- [#4437](https://github.com/blockscout/blockscout/pull/4437) - Fix `PendingTransactionsSanitizer` for non-consensus blocks
- [#4430](https://github.com/blockscout/blockscout/pull/4430) - Fix current token balance on-demand fetcher
- [#4429](https://github.com/blockscout/blockscout/pull/4429), [#4431](https://github.com/blockscout/blockscout/pull/4431) - Fix 500 response on `/tokens/{addressHash}/token-holders?type=JSON` when total supply is zero
- [#4419](https://github.com/blockscout/blockscout/pull/4419) - Order contracts in the search by inserted_at in descending order
- [#4418](https://github.com/blockscout/blockscout/pull/4418) - Fix empty search results for the full-word search criteria
- [#4406](https://github.com/blockscout/blockscout/pull/4406) - Fix internal server error on the validator's txs page
- [#4360](https://github.com/blockscout/blockscout/pull/4360) - Fix false-pending transactions in reorg blocks
- [#4388](https://github.com/blockscout/blockscout/pull/4388) - Fix internal server error on contract page for instances without sourcify envs
- [#4385](https://github.com/blockscout/blockscout/pull/4385) - Fix html template for transaction's input; Add copy text for tuples

### Chore

- [#4400](https://github.com/blockscout/blockscout/pull/4400) - Add "Token ID" label onto `tokens/.../instance/.../token-transfers` page
- [#4398](https://github.com/blockscout/blockscout/pull/4398) - Speed up the transactions loading on the front-end
- [#4384](https://github.com/blockscout/blockscout/pull/4384) - Fix Elixir version in `.tool-versions`
- [#4382](https://github.com/blockscout/blockscout/pull/4382) - Replace awesomplete with autocomplete.js
- [#4371](https://github.com/blockscout/blockscout/pull/4371) - Place search outside of burger in mobile view
- [#4355](https://github.com/blockscout/blockscout/pull/4355) - Do not redirect to 404 page with empty string in the search field

## 3.7.1-beta

### Features

- [#4331](https://github.com/blockscout/blockscout/pull/4331) - Added support for partially verified contracts via [Sourcify](https://sourcify.dev)
- [#4323](https://github.com/blockscout/blockscout/pull/4323) - Renamed Contract Byte Code, add Contract Creation Code on contract's page
- [#4312](https://github.com/blockscout/blockscout/pull/4312) - Display pending transactions on address page
- [#4299](https://github.com/blockscout/blockscout/pull/4299) - Added [Sourcify](https://sourcify.dev) verification API endpoint
- [#4267](https://github.com/blockscout/blockscout/pull/4267) - Extend verification through [Sourcify](https://sourcify.dev) smart-contract verification: fetch smart contract metadata from Sourcify repo if it has been already verified there
- [#4241](https://github.com/blockscout/blockscout/pull/4241) - Reload transactions on the main page without reloading of the whole page
- [#4218](https://github.com/blockscout/blockscout/pull/4218) - Hide long arrays in smart-contracts
- [#4205](https://github.com/blockscout/blockscout/pull/4205) - Total transactions fees per day API endpoint
- [#4158](https://github.com/blockscout/blockscout/pull/4158) - Calculate total fee per day
- [#4067](https://github.com/blockscout/blockscout/pull/4067) - Display LP tokens USD value and custom metadata in tokens dropdown at address page

### Fixes

- [#4351](https://github.com/blockscout/blockscout/pull/4351) - Support effectiveGasPrice property in tx receipt (Geth specific)
- [#4346](https://github.com/blockscout/blockscout/pull/4346) - Fix internal server error on raw-trace transaction page
- [#4345](https://github.com/blockscout/blockscout/pull/4345) - Fix bug on validator's address transactions page(Support effectiveGasPrice property in receipt (geth specific))
- [#4342](https://github.com/blockscout/blockscout/pull/4342) - Remove dropped/replaced txs from address transactions page
- [#4320](https://github.com/blockscout/blockscout/pull/4320) - Fix absence of imported smart-contracts' source code in `getsourcecode` API method
- [#4274](https://github.com/blockscout/blockscout/pull/4302) - Fix search token-autocomplete
- [#4316](https://github.com/blockscout/blockscout/pull/4316) - Fix `/decompiled-contracts` bug
- [#4310](https://github.com/blockscout/blockscout/pull/4310) - Fix logo URL redirection, set font-family defaults for chart.js
- [#4308](https://github.com/blockscout/blockscout/pull/4308) - Fix internal server error on contract verification options page
- [#4307](https://github.com/blockscout/blockscout/pull/4307) - Fix for composing IPFS URLs for NFTs images
- [#4306](https://github.com/blockscout/blockscout/pull/4306) - Check token instance images MIME types
- [#4295](https://github.com/blockscout/blockscout/pull/4295) - Mobile view fix: transaction tile tx hash overflow
- [#4294](https://github.com/blockscout/blockscout/pull/4294) - User wont be able to open verification pages for verified smart-contract
- [#4240](https://github.com/blockscout/blockscout/pull/4240) - `[]` is accepted in write contract page
- [#4236](https://github.com/blockscout/blockscout/pull/4236), [#4242](https://github.com/blockscout/blockscout/pull/4242) - Fix typo, constructor instead of constructor
- [#4167](https://github.com/blockscout/blockscout/pull/4167) - Deduplicate block numbers in acquire_blocks function
- [#4149](https://github.com/blockscout/blockscout/pull/4149) - Exclude smart_contract_additional_sources from JSON encoding in address schema
- [#4137](https://github.com/blockscout/blockscout/pull/4137) - Get token balance query improvement
- [#4129](https://github.com/blockscout/blockscout/pull/4129) - Speedup procedure of finding missing block numbers for catchup fetcher
- [#4038](https://github.com/blockscout/blockscout/pull/4038) - Add clause for abi_decode_address_output/1 when is_nil(address)
- [#3989](https://github.com/blockscout/blockscout/pull/3989), [4061](https://github.com/blockscout/blockscout/pull/4061) - Fixed bug that sometimes lead to incorrect ordering of token transfers
- [#3946](https://github.com/blockscout/blockscout/pull/3946) - Get NFT metadata from URIs with status_code 301
- [#3888](https://github.com/blockscout/blockscout/pull/3888) - EIP-1967 contract proxy pattern detection fix

### Chore

- [#4315](https://github.com/blockscout/blockscout/pull/4315) - Replace node_modules/ with ~ in app.scss
- [#4314](https://github.com/blockscout/blockscout/pull/4314) - Set infinite timeout for fetch_min_missing_block_cache method DB query
- [#4300](https://github.com/blockscout/blockscout/pull/4300) - Remove clear_build.sh script
- [#4268](https://github.com/blockscout/blockscout/pull/4268) - Migration to Chart.js 3.0
- [#4253](https://github.com/blockscout/blockscout/pull/4253) - Elixir 1.11.4, npm audit fix
- [#4231](https://github.com/blockscout/blockscout/pull/4231) - Transactions stats: get min/max blocks in one query
- [#4157](https://github.com/blockscout/blockscout/pull/4157) - Fix internal docs generation
- [#4127](https://github.com/blockscout/blockscout/pull/4127) - Update ex_keccak package
- [#4063](https://github.com/blockscout/blockscout/pull/4063) - Do not display 4bytes signature in the tx tile for contract creation
- [#3934](https://github.com/blockscout/blockscout/pull/3934) - Update nimble_csv package
- [#3902](https://github.com/blockscout/blockscout/pull/3902) - Increase number of left symbols in short address view
- [#3894](https://github.com/blockscout/blockscout/pull/3894) - Refactoring: replace inline style display: none with d-none class
- [#3893](https://github.com/blockscout/blockscout/pull/3893) - Add left/right paddings in tx tile
- [#3870](https://github.com/blockscout/blockscout/pull/3870) - Manage token balance on-demand fetcher threshold via env var

## 3.7.0-beta

### Features

- [#3858](https://github.com/blockscout/blockscout/pull/3858) - Integration with Sourcify
- [#3834](https://github.com/blockscout/blockscout/pull/3834) - Method name in tx tile
- [#3792](https://github.com/blockscout/blockscout/pull/3792) - Cancel pending transaction
- [#3786](https://github.com/blockscout/blockscout/pull/3786) - Read contract: enable methods with StateMutability: pure
- [#3758](https://github.com/blockscout/blockscout/pull/3758) - Add pool metadata display/change to Staking DApp
- [#3750](https://github.com/blockscout/blockscout/pull/3750) - getblocknobytime block module API endpoint

### Fixes

- [#3835](https://github.com/blockscout/blockscout/pull/3835) - Fix getTokenHolders API endpoint pagination
- [#3787](https://github.com/blockscout/blockscout/pull/3787) - Improve tokens list elements display
- [#3785](https://github.com/blockscout/blockscout/pull/3785) - Fix for write contract functionality: false and 0 boolean inputs are parsed as true
- [#3783](https://github.com/blockscout/blockscout/pull/3783) - Fix number of block confirmations
- [#3773](https://github.com/blockscout/blockscout/pull/3773) - Inventory pagination query performance improvement
- [#3767](https://github.com/blockscout/blockscout/pull/3767) - Decoded contract method input tuple reader fix
- [#3748](https://github.com/blockscout/blockscout/pull/3748) - Skip null topics in eth_getLogs API endpoint

### Chore

- [#3831](https://github.com/blockscout/blockscout/pull/3831) - Process type field in eth_getTransactionReceipt response
- [#3802](https://github.com/blockscout/blockscout/pull/3802) - Extend Become a Candidate popup in Staking DApp
- [#3801](https://github.com/blockscout/blockscout/pull/3801) - Poison package update
- [#3799](https://github.com/blockscout/blockscout/pull/3799) - Update credo, dialyxir mix packages
- [#3789](https://github.com/blockscout/blockscout/pull/3789) - Update repo organization
- [#3788](https://github.com/blockscout/blockscout/pull/3788) - Update fontawesome NPM package

## 3.6.0-beta

### Features

- [#3743](https://github.com/blockscout/blockscout/pull/3743) - Minimal proxy pattern support (EIP-1167)
- [#3722](https://github.com/blockscout/blockscout/pull/3722) - Allow double quotes for (u)int arrays inputs during contract interaction
- [#3694](https://github.com/blockscout/blockscout/pull/3694) - LP tokens total liquidity
- [#3676](https://github.com/blockscout/blockscout/pull/3676) - Bridged tokens TLV in USD
- [#3674](https://github.com/blockscout/blockscout/pull/3674) - Display Sushiswap pools data
- [#3637](https://github.com/blockscout/blockscout/pull/3637) - getsourcecode API endpoint: show data for unverified contract from verified contract with the same bytecode
- [#3631](https://github.com/blockscout/blockscout/pull/3631) - Tokens search
- [#3631](https://github.com/blockscout/blockscout/pull/3631) - BSC OMNI bridge support
- [#3603](https://github.com/blockscout/blockscout/pull/3603) - Display method output parameter name at contract read page
- [#3597](https://github.com/blockscout/blockscout/pull/3597) - Show APY for delegators in Staking DApp
- [#3584](https://github.com/blockscout/blockscout/pull/3584) - Token holders API endpoint
- [#3564](https://github.com/blockscout/blockscout/pull/3564) - Staking welcome message

### Fixes

- [#3742](https://github.com/blockscout/blockscout/pull/3742) - Fix Sushiswap LP tokens custom metadata fetcher: bytes(n) symbol and name support
- [#3741](https://github.com/blockscout/blockscout/pull/3741) - Contract reader fix when there are multiple input params including an array type
- [#3735](https://github.com/blockscout/blockscout/pull/3735) - Token balance on demand fetcher memory leak fix
- [#3732](https://github.com/blockscout/blockscout/pull/3732) - POSDAO: fix snapshotting and remove temporary code
- [#3731](https://github.com/blockscout/blockscout/pull/3731) - Handle bad gateway at pending transactions fetcher
- [#3730](https://github.com/blockscout/blockscout/pull/3730) - Set default period for average block time counter refresh interval
- [#3729](https://github.com/blockscout/blockscout/pull/3729) - Token on-demand balance fetcher: handle nil balance
- [#3728](https://github.com/blockscout/blockscout/pull/3728) - Coinprice api endpoint: handle nil rates
- [#3723](https://github.com/blockscout/blockscout/pull/3723) - Fix losing digits at value conversion back from WEI
- [#3715](https://github.com/blockscout/blockscout/pull/3715) - Pending transactions sanitizer process
- [#3710](https://github.com/blockscout/blockscout/pull/3710) - Missing @destination in bridged-tokens template
- [#3707](https://github.com/blockscout/blockscout/pull/3707) - Fetch bridged token price by address of foreign token, not by symbol
- [#3686](https://github.com/blockscout/blockscout/pull/3686) - BSC bridged tokens detection fix
- [#3683](https://github.com/blockscout/blockscout/pull/3683) - Token instance image IPFS link display fix
- [#3655](https://github.com/blockscout/blockscout/pull/3655) - Handle absence of readAll function in some old/legacy browsers
- [#3634](https://github.com/blockscout/blockscout/pull/3634) - Fix transaction decoding view: support tuple types
- [#3623](https://github.com/blockscout/blockscout/pull/3623) - Ignore unrecognized messages in bridge counter processes
- [#3622](https://github.com/blockscout/blockscout/pull/3622) - Contract reader: fix int type output Ignore unrecognized messages in bridge counter processes
- [#3621](https://github.com/blockscout/blockscout/pull/3621) - Contract reader: :binary input/output fix
- [#3620](https://github.com/blockscout/blockscout/pull/3620) - Ignore unfamiliar messages by Explorer.Staking.ContractState module
- [#3611](https://github.com/blockscout/blockscout/pull/3611) - Fix logo size
- [#3600](https://github.com/blockscout/blockscout/pull/3600) - Prevent update validator metadata with empty name from contract
- [#3592](https://github.com/blockscout/blockscout/pull/3592), [#3601](https://github.com/blockscout/blockscout/pull/3601), [#3607](https://github.com/blockscout/blockscout/pull/3607) - Contract interaction: fix nested tuples in the output view, add formatting
- [#3583](https://github.com/blockscout/blockscout/pull/3583) - Reduce RPC requests and DB changes by Staking DApp
- [#3577](https://github.com/blockscout/blockscout/pull/3577) - Eliminate GraphiQL page XSS attack

### Chore

- [#3745](https://github.com/blockscout/blockscout/pull/3745) - Refactor and optimize Staking DApp
- [#3744](https://github.com/blockscout/blockscout/pull/3744) - Update Mix packages: timex, hackney, tzdata certifi
- [#3736](https://github.com/blockscout/blockscout/pull/3736), [#3739](https://github.com/blockscout/blockscout/pull/3739) - Contract writer: Fix sending a transaction with tuple input type
- [#3719](https://github.com/blockscout/blockscout/pull/3719) - Rename ethprice API endpoint
- [#3717](https://github.com/blockscout/blockscout/pull/3717) - Update alpine-elixir-phoenix 1.11.3
- [#3714](https://github.com/blockscout/blockscout/pull/3714) - Application announcements management: whole explorer, staking dapp
- [#3712](https://github.com/blockscout/blockscout/pull/3712) - POSDAO refactoring: use pool ID instead of staking address
- [#3709](https://github.com/blockscout/blockscout/pull/3709) - Fix 413 Request Entity Too Large returned from single request batch
- [#3708](https://github.com/blockscout/blockscout/pull/3708) - NPM 6 -> 7
- [#3701](https://github.com/blockscout/blockscout/pull/3701) - Increase LP tokens calc process re-check interval
- [#3700](https://github.com/blockscout/blockscout/pull/3700) - Update tool versions
- [#3697](https://github.com/blockscout/blockscout/pull/3697) - Update hackney dependency
- [#3696](https://github.com/blockscout/blockscout/pull/3696) - Table loader fix
- [#3688](https://github.com/blockscout/blockscout/pull/3688) - Reorganize staking buttons
- [#3687](https://github.com/blockscout/blockscout/pull/3687) - Miscellaneous minor fixes
- [#3667](https://github.com/blockscout/blockscout/pull/3667) - Store bridged token price in the DB
- [#3662](https://github.com/blockscout/blockscout/pull/3662) - Order bridged tokens in descending order by tokens holder for Omni bridge cap calculation
- [#3659](https://github.com/blockscout/blockscout/pull/3659) - Staking Dapp new buttons: swap, bridge
- [#3645](https://github.com/blockscout/blockscout/pull/3645) - Change Twitter handle
- [#3644](https://github.com/blockscout/blockscout/pull/3644) - Correct exchange rate for SURF.finance token
- [#3618](https://github.com/blockscout/blockscout/pull/3618) - Contracts verification up to 10 libraries
- [#3616](https://github.com/blockscout/blockscout/pull/3616) - POSDAO refactoring: use zero address instead of staker address for certain cases
- [#3612](https://github.com/blockscout/blockscout/pull/3612) - POSDAO refactoring: use 'getDelegatorPools' getter instead of 'getStakerPools' in Staking DApp
- [#3585](https://github.com/blockscout/blockscout/pull/3585) - Add auto switching from eth_subscribe to eth_blockNumber in Staking DApp
- [#3574](https://github.com/blockscout/blockscout/pull/3574) - Correct UNI token price
- [#3569](https://github.com/blockscout/blockscout/pull/3569) - Allow re-define cache period vars at runtime
- [#3567](https://github.com/blockscout/blockscout/pull/3567) - Force to show filter at the page where filtered items list is empty
- [#3565](https://github.com/blockscout/blockscout/pull/3565) - Staking dapp: unhealthy state alert message

## 3.5.1-beta

### Features

- [#3558](https://github.com/blockscout/blockscout/pull/3558) - Focus to search field with a forward slash key
- [#3541](https://github.com/blockscout/blockscout/pull/3541) - Staking dapp stats: total number of delegators, total staked amount
- [#3540](https://github.com/blockscout/blockscout/pull/3540) - Apply DarkForest custom theme to NFT instances

### Fixes

- [#3551](https://github.com/blockscout/blockscout/pull/3551) - Fix contract's method's output of tuple type

### Chore

- [#3557](https://github.com/blockscout/blockscout/pull/3557) - Single Staking menu
- [#3540](https://github.com/blockscout/blockscout/pull/3540), [#3545](https://github.com/blockscout/blockscout/pull/3545) - Support different versions of DarkForest (0.4 - 0.5)

## 3.5.0-beta

### Features

- [#3536](https://github.com/blockscout/blockscout/pull/3536) - Revert reason in the result of contract's method call
- [#3532](https://github.com/blockscout/blockscout/pull/3532) - Contract interaction: an easy setting of precision for integer input
- [#3531](https://github.com/blockscout/blockscout/pull/3531) - Allow double quotes in input data of contract methods
- [#3515](https://github.com/blockscout/blockscout/pull/3515) - CRC total balance
- [#3513](https://github.com/blockscout/blockscout/pull/3513) - Allow square brackets for an array input data in contracts interaction
- [#3480](https://github.com/blockscout/blockscout/pull/3480) - Add support of Autonity client
- [#3470](https://github.com/blockscout/blockscout/pull/3470) - Display sum of tokens' USD value at tokens holder's address page
- [#3462](https://github.com/blockscout/blockscout/pull/3462) - Display price for bridged tokens

### Fixes

- [#3535](https://github.com/blockscout/blockscout/pull/3535) - Improve speed of tokens dropdown loading at owner address page
- [#3530](https://github.com/blockscout/blockscout/pull/3530) - Allow trailing/leading whitespaces for inputs for contract read methods
- [#3526](https://github.com/blockscout/blockscout/pull/3526) - Order staking pools
- [#3525](https://github.com/blockscout/blockscout/pull/3525), [#3533](https://github.com/blockscout/blockscout/pull/3533) - Address token balance on demand fetcher
- [#3514](https://github.com/blockscout/blockscout/pull/3514) - Read contract: fix internal server error
- [#3513](https://github.com/blockscout/blockscout/pull/3513) - Fix input data processing for method call (array type of data)
- [#3509](https://github.com/blockscout/blockscout/pull/3509) - Fix QR code tooltip appearance in mobile view
- [#3507](https://github.com/blockscout/blockscout/pull/3507), [#3510](https://github.com/blockscout/blockscout/pull/3510) - Fix left margin of balance card in mobile view
- [#3506](https://github.com/blockscout/blockscout/pull/3506) - Fix token transfer's tile styles: prevent overlapping of long names
- [#3505](https://github.com/blockscout/blockscout/pull/3505) - Fix Staking DApp first loading
- [#3433](https://github.com/blockscout/blockscout/pull/3433) - Token balances and rewards tables deadlocks elimination
- [#3494](https://github.com/blockscout/blockscout/pull/3494), [#3497](https://github.com/blockscout/blockscout/pull/3497), [#3504](https://github.com/blockscout/blockscout/pull/3504), [#3517](https://github.com/blockscout/blockscout/pull/3517) - Contracts interaction: fix method call with array[] inputs
- [#3494](https://github.com/blockscout/blockscout/pull/3494), [#3495](https://github.com/blockscout/blockscout/pull/3495) - Contracts interaction: fix tuple output display
- [#3479](https://github.com/blockscout/blockscout/pull/3479) - Fix working with big numbers in Staking DApp
- [#3477](https://github.com/blockscout/blockscout/pull/3477) - Contracts interaction: fix broken call of GnosisProxy contract methods with parameters
- [#3477](https://github.com/blockscout/blockscout/pull/3477) - Contracts interaction: fix broken call of fallback function
- [#3476](https://github.com/blockscout/blockscout/pull/3476) - Fix contract verification of precompiled contracts
- [#3467](https://github.com/blockscout/blockscout/pull/3467) - Fix Firefox styles
- [#3464](https://github.com/blockscout/blockscout/pull/3464) - Fix display of token transfers list at token page (fix unique identifier of a tile)

- [#3457](https://github.com/blockscout/blockscout/pull/3457) - Fix endless block invalidation issue
- [#3457](https://github.com/blockscout/blockscout/pull/3457) - Fix doubled total transferred/minted/burnt tokens on transaction's page if block has reorg
- [#3457](https://github.com/blockscout/blockscout/pull/3457) - Fix doubled token transfer on block's page if block has reorg

### Chore

- [#3500](https://github.com/blockscout/blockscout/pull/3500) - Update solc version in explorer folder
- [#3498](https://github.com/blockscout/blockscout/pull/3498) - Make Staking DApp work with transferAndCall function
- [#3496](https://github.com/blockscout/blockscout/pull/3496) - Rollback websocket_client module to 1.3.0
- [#3489](https://github.com/blockscout/blockscout/pull/3489) - Migrate to Webpack@5
- [#3487](https://github.com/blockscout/blockscout/pull/3487) - Docker setup update to be compatible with Erlang OTP 23
- [#3484](https://github.com/blockscout/blockscout/pull/3484) - Elixir upgrade to 11.2
- [#3483](https://github.com/blockscout/blockscout/pull/3483) - Update outdated dependencies
- [#3483](https://github.com/blockscout/blockscout/pull/3483) - Migrate to Erlang/OTP 23
- [#3468](https://github.com/blockscout/blockscout/pull/3468) - Do not check supported networks on application loading page
- [#3467](https://github.com/blockscout/blockscout/pull/3467) - NodeJS engine upgrade up to 14
- [#3460](https://github.com/blockscout/blockscout/pull/3460) - Update Staking DApp scripts due to MetaMask breaking changes

## 3.4.0-beta

### Features

- [#3442](https://github.com/blockscout/blockscout/pull/3442) - Constructor arguments autodetection in API verify endpoint
- [#3435](https://github.com/blockscout/blockscout/pull/3435) - Token transfers counter cache
- [#3420](https://github.com/blockscout/blockscout/pull/3420) - Enable read/write proxy tabs for Gnosis safe proxy contract
- [#3411](https://github.com/blockscout/blockscout/pull/3411) - Circles UBI theme
- [#3406](https://github.com/blockscout/blockscout/pull/3406), [#3409](https://github.com/blockscout/blockscout/pull/3409) - Adding mp4 files support for NFTs
- [#3398](https://github.com/blockscout/blockscout/pull/3398) - Collect and display gas usage per day at the main page
- [#3385](https://github.com/blockscout/blockscout/pull/3385), [#3397](https://github.com/blockscout/blockscout/pull/3397) - Total gas usage at the main page
- [#3384](https://github.com/blockscout/blockscout/pull/3384), [#3386](https://github.com/blockscout/blockscout/pull/3386) - Address total gas usage
- [#3377](https://github.com/blockscout/blockscout/pull/3377) - Add links to contract libraries
- [#2292](https://github.com/blockscout/blockscout/pull/2292), [#3356](https://github.com/blockscout/blockscout/pull/3356), [#3359](https://github.com/blockscout/blockscout/pull/3359), [#3360](https://github.com/blockscout/blockscout/pull/3360), [#3365](https://github.com/blockscout/blockscout/pull/3365) - Add Web UI for POSDAO Staking DApp
- [#3354](https://github.com/blockscout/blockscout/pull/3354) - Tx hash in EOA coin balance history
- [#3333](https://github.com/blockscout/blockscout/pull/3333), [#3337](https://github.com/blockscout/blockscout/pull/3337), [#3393](https://github.com/blockscout/blockscout/pull/3393) - Dark forest contract custom theme
- [#3330](https://github.com/blockscout/blockscout/pull/3330) - Caching of address transactions counter, remove query 10_000 rows limit

### Fixes

- [#3449](https://github.com/blockscout/blockscout/pull/3449) - Correct avg time calculation
- [#3443](https://github.com/blockscout/blockscout/pull/3443) - Improve blocks handling in Staking DApp
- [#3440](https://github.com/blockscout/blockscout/pull/3440) - Rewrite missing blocks range query
- [#3439](https://github.com/blockscout/blockscout/pull/3439) - Dark mode color fixes (search, charts)
- [#3437](https://github.com/blockscout/blockscout/pull/3437) - Fix Postgres Docker container
- [#3428](https://github.com/blockscout/blockscout/pull/3428) - Fix address tokens search
- [#3424](https://github.com/blockscout/blockscout/pull/3424) - Fix display of long NFT IDs
- [#3422](https://github.com/blockscout/blockscout/pull/3422) - Fix contract reader: tuple type
- [#3408](https://github.com/blockscout/blockscout/pull/3408) - Fix (total) difficulty display
- [#3401](https://github.com/blockscout/blockscout/pull/3401), [#3432](https://github.com/blockscout/blockscout/pull/3432) - Fix procedure of marking internal transactions as failed
- [#3400](https://github.com/blockscout/blockscout/pull/3400) - Add :last_block_number realtime chain event
- [#3399](https://github.com/blockscout/blockscout/pull/3399) - Fix Token transfers CSV export
- [#3396](https://github.com/blockscout/blockscout/pull/3396) - Handle exchange rates request throttled
- [#3382](https://github.com/blockscout/blockscout/pull/3382) - Check ets table exists for known tokens
- [#3376](https://github.com/blockscout/blockscout/pull/3376) - Fix contract nested inputs
- [#3375](https://github.com/blockscout/blockscout/pull/3375) - Prevent terminating of tokens/contracts process
- [#3374](https://github.com/blockscout/blockscout/pull/3374) - Fix find block timestamp query
- [#3373](https://github.com/blockscout/blockscout/pull/3373) - Fix horizontal scroll in Tokens table
- [#3370](https://github.com/blockscout/blockscout/pull/3370) - Improve contracts verification: refine constructor arguments extractor
- [#3368](https://github.com/blockscout/blockscout/pull/3368) - Fix Verify contract loading button width
- [#3357](https://github.com/blockscout/blockscout/pull/3357) - Fix token transfer realtime fetcher
- [#3353](https://github.com/blockscout/blockscout/pull/3353) - Fix xDai buttons hover color
- [#3352](https://github.com/blockscout/blockscout/pull/3352) - Fix dark body background
- [#3350](https://github.com/blockscout/blockscout/pull/3350) - Fix tokens list pagination
- [#3347](https://github.com/blockscout/blockscout/pull/3347) - Contract interaction: fix encoding of bytes output
- [#3346](https://github.com/blockscout/blockscout/pull/3346), [#3351](https://github.com/blockscout/blockscout/pull/3351) - Fix inventory tab pagination
- [#3344](https://github.com/blockscout/blockscout/pull/3344) - Fix logs search on address page
- [#3342](https://github.com/blockscout/blockscout/pull/3342) - Fix mobile styles for contract code tab
- [#3341](https://github.com/blockscout/blockscout/pull/3341) - Change Solc binary downloader path to official primary supported path
- [#3339](https://github.com/blockscout/blockscout/pull/3339) - Repair websocket subscription
- [#3329](https://github.com/blockscout/blockscout/pull/3329) - Fix pagination for bridged tokens list page
- [#3335](https://github.com/blockscout/blockscout/pull/3335) - MarketCap calculation: check that ETS tables exist before inserting new data or lookup from the table

### Chore

- [#5240](https://github.com/blockscout/blockscout/pull/5240) - Managing invalidation of address coin balance cache
- [#3450](https://github.com/blockscout/blockscout/pull/3450) - Replace window.web3 with window.ethereum
- [#3446](https://github.com/blockscout/blockscout/pull/3446), [#3448](https://github.com/blockscout/blockscout/pull/3448) - Set infinity timeout and increase cache invalidation period for counters
- [#3431](https://github.com/blockscout/blockscout/pull/3431) - Standardize token name definition, if name is empty
- [#3421](https://github.com/blockscout/blockscout/pull/3421) - Functions to enable GnosisSafe app link
- [#3414](https://github.com/blockscout/blockscout/pull/3414) - Manage lis of other explorers in the footer via env var
- [#3407](https://github.com/blockscout/blockscout/pull/3407) - Add EthereumJSONRPC.HTTP.HTTPoison.json_rpc function clause when URL is null
- [#3405](https://github.com/blockscout/blockscout/pull/3405) - N/A instead of 0 for market cap if it is not fetched
- [#3404](https://github.com/blockscout/blockscout/pull/3404) - DISABLE_KNOWN_TOKENS env var
- [#3403](https://github.com/blockscout/blockscout/pull/3403) - Refactor Coingecko interaction
- [#3394](https://github.com/blockscout/blockscout/pull/3394) - Actualize docker vars list
- [#3372](https://github.com/blockscout/blockscout/pull/3372), [#3380](https://github.com/blockscout/blockscout/pull/3380) - Improve all lists header container
- [#3371](https://github.com/blockscout/blockscout/pull/3371) - Eliminate dark background except Dark forest theme
- [#3366](https://github.com/blockscout/blockscout/pull/3366) - Stabilize tests execution in Github Actions CI
- [#3343](https://github.com/blockscout/blockscout/pull/3343) - Make (Bridged) Tokens' list page's header more compact

## 3.3.3-beta

### Features

- [#3320](https://github.com/blockscout/blockscout/pull/3320) - Bridged tokens from AMB extensions support
- [#3311](https://github.com/blockscout/blockscout/pull/3311) - List of addresses with restricted access option
- [#3293](https://github.com/blockscout/blockscout/pull/3293) - Composite market cap for xDai: TokenBridge + OmniBridge
- [#3282](https://github.com/blockscout/blockscout/pull/3282), [#3318](https://github.com/blockscout/blockscout/pull/3318) - Import bridged tokens custom metadata
- [#3281](https://github.com/blockscout/blockscout/pull/3281) - Write contract: display currently connected address
- [#3279](https://github.com/blockscout/blockscout/pull/3279) - NFT instance: link to the app
- [#3278](https://github.com/blockscout/blockscout/pull/3278) - Support of fetching of NFT metadata from IPFS
- [#3273](https://github.com/blockscout/blockscout/pull/3273) - Update token metadata at burn/mint events
- [#3268](https://github.com/blockscout/blockscout/pull/3268) - Token total supply on-demand fetcher
- [#3261](https://github.com/blockscout/blockscout/pull/3261) - Bridged tokens table

### Fixes

- [#3323](https://github.com/blockscout/blockscout/pull/3323) - Fix logs list API endpoint response
- [#3319](https://github.com/blockscout/blockscout/pull/3319) - Eliminate horizontal scroll
- [#3314](https://github.com/blockscout/blockscout/pull/3314) - Handle nil values from response of CoinGecko price API
- [#3313](https://github.com/blockscout/blockscout/pull/3313) - Fix xDai styles: invisible tokens on address
- [#3312](https://github.com/blockscout/blockscout/pull/3312) - Replace symbol for some tokens to be able to find price in CoinGecko for OmniBridge balance
- [#3307](https://github.com/blockscout/blockscout/pull/3307) - Replace "latest" compiler version with the actual one
- [#3303](https://github.com/blockscout/blockscout/pull/3303) - Address contract twins feature performance
- [#3295](https://github.com/blockscout/blockscout/pull/3295) - Token instance: check if external_url is not null before trimming
- [#3291](https://github.com/blockscout/blockscout/pull/3291) - Support unlimited number of external rewards in block
- [#3290](https://github.com/blockscout/blockscout/pull/3290) - Eliminate protocol Jason.Encoder not implemented for... error
- [#3284](https://github.com/blockscout/blockscout/pull/3284) - Fix fetch_coin_balance query: coin balance delta
- [#3276](https://github.com/blockscout/blockscout/pull/3276) - Bridged tokens status/metadata fetcher refactoring
- [#3264](https://github.com/blockscout/blockscout/pull/3264) - Fix encoding of address output if function input exists
- [#3259](https://github.com/blockscout/blockscout/pull/3259), [#3269](https://github.com/blockscout/blockscout/pull/3269) - Contract interaction: array input type parsing fix
- [#3257](https://github.com/blockscout/blockscout/pull/3257) - Contracts read/write: method_id instead function_name as a key
- [#3256](https://github.com/blockscout/blockscout/pull/3256) - Fix for invisible validator address at block page and wrong alert text color at xDai

### Chore

- [#3327](https://github.com/blockscout/blockscout/pull/3327) - Handle various indexer fetchers errors in setup with non-archive node
- [#3325](https://github.com/blockscout/blockscout/pull/3325) - Dark theme improvements
- [#3316](https://github.com/blockscout/blockscout/pull/3316), [#3317](https://github.com/blockscout/blockscout/pull/3317) - xDai smile logo
- [#3315](https://github.com/blockscout/blockscout/pull/3315) - Environment variable to disable Bridge market cap updater
- [#3308](https://github.com/blockscout/blockscout/pull/3308) - Fixate latest stable release of Elixir, Node, Postgres
- [#3297](https://github.com/blockscout/blockscout/pull/3297) - Actualize names of default chains
- [#3285](https://github.com/blockscout/blockscout/pull/3285) - Switch to RPC endpoint polling if ETHEREUM_JSONRPC_WS_URL is an empty string
- [#3274](https://github.com/blockscout/blockscout/pull/3274) - Replace underscore with hyphen in routes
- [#3260](https://github.com/blockscout/blockscout/pull/3260) - Update NPM dependencies to fix known vulnerabilities
- [#3258](https://github.com/blockscout/blockscout/pull/3258) - Token transfer: check that block exists before retrieving timestamp

## 3.3.2-beta

### Features

- [#3252](https://github.com/blockscout/blockscout/pull/3252) - Gas price at the main page
- [#3239](https://github.com/blockscout/blockscout/pull/3239) - Hide address page tabs if no items
- [#3236](https://github.com/blockscout/blockscout/pull/3236) - Easy verification of contracts which has verified twins (the same bytecode)
- [#3227](https://github.com/blockscout/blockscout/pull/3227) - Distinguishing of bridged tokens
- [#3224](https://github.com/blockscout/blockscout/pull/3224) - Top tokens page

### Fixes

- [#3249](https://github.com/blockscout/blockscout/pull/3249) - Fix incorrect ABI decoding of address in tuple output
- [#3237](https://github.com/blockscout/blockscout/pull/3237) - Refine contract method signature detection for read/write feature
- [#3235](https://github.com/blockscout/blockscout/pull/3235) - Fix coin supply api endpoint
- [#3233](https://github.com/blockscout/blockscout/pull/3233) - Fix for the contract verification for solc 0.5 family with experimental features enabled
- [#3231](https://github.com/blockscout/blockscout/pull/3231) - Improve search: unlimited number of searching results
- [#3231](https://github.com/blockscout/blockscout/pull/3231) - Improve search: allow search with space
- [#3231](https://github.com/blockscout/blockscout/pull/3231) - Improve search: order by token holders in descending order and token/contract name is ascending order
- [#3226](https://github.com/blockscout/blockscout/pull/3226) - Fix notifier query for live update of token transfers
- [#3220](https://github.com/blockscout/blockscout/pull/3220) - Allow interaction with navbar menu at block-not-found page

### Chore

- [#3326](https://github.com/blockscout/blockscout/pull/3326) - Chart smooth lines
- [#3250](https://github.com/blockscout/blockscout/pull/3250) - Eliminate occurrences of obsolete env variable ETHEREUM_JSONRPC_JSON_RPC_TRANSPORT
- [#3240](https://github.com/blockscout/blockscout/pull/3240), [#3251](https://github.com/blockscout/blockscout/pull/3251) - various CSS improving
- [f3a720](https://github.com/blockscout/blockscout/commit/2dd909c10a79b0bf4b7541a486be114152f3a720) - Make wobserver optional

## 3.3.1-beta

### Features

- [#3216](https://github.com/blockscout/blockscout/pull/3216) - Display new token transfers at token page and address page without refreshing the page
- [#3199](https://github.com/blockscout/blockscout/pull/3199) - Show compilation error at contract verification
- [#3193](https://github.com/blockscout/blockscout/pull/3193) - Raw trace copy button
- [#3184](https://github.com/blockscout/blockscout/pull/3184) - Apps navbar menu item
- [#3145](https://github.com/blockscout/blockscout/pull/3145) - Pending txs per address API endpoint

### Fixes

- [#3219](https://github.com/blockscout/blockscout/pull/3219) - Fix revert reason message detection
- [#3215](https://github.com/blockscout/blockscout/pull/3215) - Coveralls in CI through Github Actions
- [#3214](https://github.com/blockscout/blockscout/pull/3214) - Fix current token balances fetcher
- [#3143](https://github.com/blockscout/blockscout/pull/3143) - Fix "Connection lost..." error at address page
- [#3209](https://github.com/blockscout/blockscout/pull/3209) - GraphQL: fix internal server error at request of internal transactions at address
- [#3207](https://github.com/blockscout/blockscout/pull/3207) - Fix read contract bytes array type output
- [#3203](https://github.com/blockscout/blockscout/pull/3203) - Improve "get mined blocks" query performance
- [#3202](https://github.com/blockscout/blockscout/pull/3202) - Fix contracts verification with experimental features enabled
- [#3201](https://github.com/blockscout/blockscout/pull/3201) - Connect to Metamask button
- [#3192](https://github.com/blockscout/blockscout/pull/3192) - Dropdown menu doesn't open at "not found" page
- [#3190](https://github.com/blockscout/blockscout/pull/3190) - Contract log/method decoded view improvements: eliminate horizontal scroll, remove excess borders, whitespaces
- [#3185](https://github.com/blockscout/blockscout/pull/3185) - Transaction page: decoding logs from nested contracts calls
- [#3182](https://github.com/blockscout/blockscout/pull/3182) - Besu: support revertReason key in eth_getTransactionReceipt endpoint
- [#3178](https://github.com/blockscout/blockscout/pull/3178) - Fix permanent fetching tokens...  when read/write proxy tab is active
- [#3178](https://github.com/blockscout/blockscout/pull/3178) - Fix unavailable navbar menu when read/write proxy tab is active

### Chore

- [#3212](https://github.com/blockscout/blockscout/pull/3212) - GitHub actions CI config
- [#3210](https://github.com/blockscout/blockscout/pull/3210) - Update Phoenix up to 1.4.17
- [#3206](https://github.com/blockscout/blockscout/pull/3206) - Update Elixir version: 1.10.2 -> 1.10.3
- [#3204](https://github.com/blockscout/blockscout/pull/3204) - GraphQL Absinthe related packages update up to stable versions
- [#3180](https://github.com/blockscout/blockscout/pull/3180) - Return correct status in verify API endpoint if contract verified
- [#3180](https://github.com/blockscout/blockscout/pull/3180) - Remove Kovan from the list of default chains

## 3.3.0-beta

### Features

- [#3174](https://github.com/blockscout/blockscout/pull/3174) - EIP-1967 support: transparent proxy pattern
- [#3173](https://github.com/blockscout/blockscout/pull/3173) - Display implementation address at read/write proxy tabs
- [#3171](https://github.com/blockscout/blockscout/pull/3171) - Import accounts/contracts/balances from Geth genesis.json
- [#3161](https://github.com/blockscout/blockscout/pull/3161) - Write proxy contracts feature
- [#3160](https://github.com/blockscout/blockscout/pull/3160) - Write contracts feature
- [#3157](https://github.com/blockscout/blockscout/pull/3157) - Read methods of implementation on proxy contract

### Fixes

- [#3168](https://github.com/blockscout/blockscout/pull/3168) - Eliminate internal server error at /accounts page with token-bridge type of supply and inexistent bridge contracts
- [#3169](https://github.com/blockscout/blockscout/pull/3169) - Fix for verification of contracts defined in genesis block

### Chore

## 3.2.0-beta

### Features

- [#3154](https://github.com/blockscout/blockscout/pull/3154) - Support of Hyperledger Besu client
- [#3153](https://github.com/blockscout/blockscout/pull/3153) - Proxy contracts: logs decoding using implementation ABI
- [#3153](https://github.com/blockscout/blockscout/pull/3153) - Proxy contracts: methods decoding using implementation ABI
- [#3149](https://github.com/blockscout/blockscout/pull/3149) - Display and store revert reason of tx on demand at transaction details page and at gettxinfo API endpoint.

### Fixes

### Chore

- [#3152](https://github.com/blockscout/blockscout/pull/3152) - Fix contract compilation tests for old versions of compiler

## 3.1.3-beta

### Features

- [#3125](https://github.com/blockscout/blockscout/pull/3125)  - Availability to configure a number of days to consider at coin balance history chart via environment variable

### Fixes

- [#3146](https://github.com/blockscout/blockscout/pull/3146) - Fix coin balance history page: order of items, fix if no balance changes
- [#3142](https://github.com/blockscout/blockscout/pull/3142) - Speed-up last coin balance timestamp query (coin balance history page performance improvement)
- [#3140](https://github.com/blockscout/blockscout/pull/3140) - Fix performance of the balance changing history list loading
- [#3133](https://github.com/blockscout/blockscout/pull/3133) - Take into account FIRST_BLOCK in trace_ReplayBlockTransactions requests
- [#3132](https://github.com/blockscout/blockscout/pull/3132) - Fix performance of coin supply API endpoints
- [#3130](https://github.com/blockscout/blockscout/pull/3130) - Take into account FIRST_BLOCK for block rewards fetching
- [#3128](https://github.com/blockscout/blockscout/pull/3128) - Token instance metadata retriever refinement: add processing of token metadata if only image URL is passed to token URI
- [#3126](https://github.com/blockscout/blockscout/pull/3126) - Fetch balance only for blocks which are greater or equal block with FIRST_BLOCK number
- [#3125](https://github.com/blockscout/blockscout/pull/3125) - Fix performance of coin balance history chart
- [#3122](https://github.com/blockscout/blockscout/pull/3122) - Exclude balance percentage calculation for burn address on accounts page
- [#3121](https://github.com/blockscout/blockscout/pull/3121) - Geth: handle response from eth_getblockbyhash JSON RPC method without totalDifficulty (uncle blocks)
- [#3119](https://github.com/blockscout/blockscout/pull/3119), [#3120](https://github.com/blockscout/blockscout/pull/3120) - Fix performance of Inventory tab loading for ERC-721 tokens
- [#3114](https://github.com/blockscout/blockscout/pull/3114) - Fix performance of "Blocks validated" page
- [#3112](https://github.com/blockscout/blockscout/pull/3112) - Fix verification of contracts, compiled with nightly builds of solc compiler
- [#3112](https://github.com/blockscout/blockscout/pull/3112) - Check compiler version at contract verification
- [#3106](https://github.com/blockscout/blockscout/pull/3106) - Fix verification of contracts with `immutable` declaration
- [#3106](https://github.com/blockscout/blockscout/pull/3106), [#3115](https://github.com/blockscout/blockscout/pull/3115) - Fix verification of contracts, created from factory (from internal transaction)

### Chore

- [#3137](https://github.com/blockscout/blockscout/pull/3137) - RSK Papyrus Release v2.0.1 hardfork: cumulativeDifficulty
- [#3134](https://github.com/blockscout/blockscout/pull/3134) - Get last value of fetched coinsupply API endpoint from DB if cache is empty
- [#3124](https://github.com/blockscout/blockscout/pull/3124) - Display upper border for tx speed if the value cannot be calculated

## 3.1.2-beta

### Features

- [#3089](https://github.com/blockscout/blockscout/pull/3089) - CoinGecko API coin id environment variable
- [#3069](https://github.com/blockscout/blockscout/pull/3069) - Make a link to address page on decoded constructor argument of address type
- [#3067](https://github.com/blockscout/blockscout/pull/3067) - Show proper title of the tile or container for token burnings/mintings instead of "Token Transfer"
- [#3066](https://github.com/blockscout/blockscout/pull/3066) - ERC-721 token instance page: link to token added
- [#3065](https://github.com/blockscout/blockscout/pull/3065) - Transactions history chart

### Fixes

- [#3097](https://github.com/blockscout/blockscout/pull/3097) - Fix contract reader decoding
- [#3095](https://github.com/blockscout/blockscout/pull/3095) - Fix constructor arguments decoding
- [#3092](https://github.com/blockscout/blockscout/pull/3092) - Contract verification: constructor arguments search search refinement
- [#3077](https://github.com/blockscout/blockscout/pull/3077) - Finally speedup pending tx list
- [#3076](https://github.com/blockscout/blockscout/pull/3076) - Speedup tx list query on address page: check if an address has a reward, check if this is actual payout key of the validator - beneficiary, return only mined txs in tx list query
- [#3071](https://github.com/blockscout/blockscout/pull/3071) - Speedup list of token transfers per token query
- [#3070](https://github.com/blockscout/blockscout/pull/3070) - Index creation to blazingly speedup token holders query
- [#3064](https://github.com/blockscout/blockscout/pull/3064) - Automatically define Block reward contract address in TokenBridge supply module
- [#3061](https://github.com/blockscout/blockscout/pull/3061) - Fix verification of contracts with error messages in require in parent contract
- [#2756](https://github.com/blockscout/blockscout/pull/2756) - Improve subquery joins

### Chore

- [#3100](https://github.com/blockscout/blockscout/pull/3100) - Update npm packages
- [#3099](https://github.com/blockscout/blockscout/pull/3099) - Remove pending txs cache
- [#3093](https://github.com/blockscout/blockscout/pull/3093) - Extend list of env vars for Docker setup
- [#3084](https://github.com/blockscout/blockscout/pull/3084) - Bump Elixir version 1.10.2
- [#3079](https://github.com/blockscout/blockscout/pull/3079) - Extend optionality of websockets to Geth

## 3.1.1-beta

### Features

- [#3058](https://github.com/blockscout/blockscout/pull/3058) - Searching by verified contract name

### Fixes

- [#3053](https://github.com/blockscout/blockscout/pull/3053) - Fix ABI decoding in contracts methods, logs (migrate to ex_abi 0.3.0)
- [#3044](https://github.com/blockscout/blockscout/pull/3044) - Prevent division by zero on /accounts page
- [#3043](https://github.com/blockscout/blockscout/pull/3043) - Extract host name for split couple of indexer and web app
- [#3042](https://github.com/blockscout/blockscout/pull/3042) - Speedup pending txs list query
- [#2944](https://github.com/blockscout/blockscout/pull/2944), [#3046](https://github.com/blockscout/blockscout/pull/3046) - Split js logic into multiple files

## 3.1.0-beta

### Features

- [#3013](https://github.com/blockscout/blockscout/pull/3013), [#3026](https://github.com/blockscout/blockscout/pull/3026), [#3031](https://github.com/blockscout/blockscout/pull/3031) - Raw trace of transaction on-demand
- [#3000](https://github.com/blockscout/blockscout/pull/3000) - Get rid of storing of first trace for all types of transactions for Parity variant
- [#2875](https://github.com/blockscout/blockscout/pull/2875) - Save contract code from Parity genesis file
- [#2834](https://github.com/blockscout/blockscout/pull/2834), [#3009](https://github.com/blockscout/blockscout/pull/3009), [#3014](https://github.com/blockscout/blockscout/pull/3014), [#3033](https://github.com/blockscout/blockscout/pull/3033) - always redirect to checksummed hash

### Fixes

- [#3037](https://github.com/blockscout/blockscout/pull/3037) - Make buttons color at verification page consistent
- [#3034](https://github.com/blockscout/blockscout/pull/3034) - Support stateMutability=view to define reading functions in smart-contracts
- [#3029](https://github.com/blockscout/blockscout/pull/3029) - Fix transactions and blocks appearance on the main page
- [#3028](https://github.com/blockscout/blockscout/pull/3028) - Decrease polling period value for realtime fetcher
- [#3027](https://github.com/blockscout/blockscout/pull/3027) - Rescue for SUPPORTED_CHAINS env var parsing
- [#3025](https://github.com/blockscout/blockscout/pull/3025) - Fix splitting of indexer/web components setup
- [#3024](https://github.com/blockscout/blockscout/pull/3024) - Fix pool size default value in config
- [#3021](https://github.com/blockscout/blockscout/pull/3021), [#3022](https://github.com/blockscout/blockscout/pull/3022) - Refine dev/test config
- [#3016](https://github.com/blockscout/blockscout/pull/3016), [#3017](https://github.com/blockscout/blockscout/pull/3017) - Fix token instance QR code data
- [#3012](https://github.com/blockscout/blockscout/pull/3012) - Speedup token transfers list query
- [#3011](https://github.com/blockscout/blockscout/pull/3011) - Revert realtime fetcher small skips feature
- [#3007](https://github.com/blockscout/blockscout/pull/3007) - Fix copy UTF8 tx input action
- [#2996](https://github.com/blockscout/blockscout/pull/2996) - Fix awesomplete lib loading in Firefox
- [#2993](https://github.com/blockscout/blockscout/pull/2993) - Fix path definition for contract verification endpoint
- [#2990](https://github.com/blockscout/blockscout/pull/2990) - Fix import of Parity spec file
- [#2989](https://github.com/blockscout/blockscout/pull/2989) - Introduce API_PATH env var
- [#2988](https://github.com/blockscout/blockscout/pull/2988) - Fix web manifest accessibility
- [#2967](https://github.com/blockscout/blockscout/pull/2967) - Fix styles loading for firefox
- [#2950](https://github.com/blockscout/blockscout/pull/2950) - Add `creationMethod` to `EthereumJSONRPC.Parity.Trace.Action.entry_to_elixir`
- [#2897](https://github.com/blockscout/blockscout/pull/2897) - remove duplicate indexes
- [#2883](https://github.com/blockscout/blockscout/pull/2883) - Fix long contracts names

### Chore

- [#3032](https://github.com/blockscout/blockscout/pull/3032) - Remove indexing status alert for Ganache variant
- [#3030](https://github.com/blockscout/blockscout/pull/3030) - Remove default websockets URL from config
- [#2995](https://github.com/blockscout/blockscout/pull/2995) - Support API_PATH env var in Docker file

## 3.0.0-beta

### Features

- [#2835](https://github.com/blockscout/blockscout/pull/2835), [#2871](https://github.com/blockscout/blockscout/pull/2871), [#2872](https://github.com/blockscout/blockscout/pull/2872), [#2886](https://github.com/blockscout/blockscout/pull/2886), [#2925](https://github.com/blockscout/blockscout/pull/2925), [#2936](https://github.com/blockscout/blockscout/pull/2936), [#2949](https://github.com/blockscout/blockscout/pull/2949), [#2940](https://github.com/blockscout/blockscout/pull/2940), [#2958](https://github.com/blockscout/blockscout/pull/2958) - Add "block_hash" to logs, token_transfers and internal transactions and "pending blocks operations" approach
- [#2975](https://github.com/blockscout/blockscout/pull/2975) - Refine UX of contracts verification
- [#2926](https://github.com/blockscout/blockscout/pull/2926) - API endpoint: sum balances except burnt address
- [#2918](https://github.com/blockscout/blockscout/pull/2918) - Add tokenID for tokentx API action explicitly

### Fixes

- [#2969](https://github.com/blockscout/blockscout/pull/2969) - Fix contract constructor require msg appearance in constructor arguments encoded view
- [#2964](https://github.com/blockscout/blockscout/pull/2964) - Fix bug in skipping of constructor arguments in contract verification
- [#2961](https://github.com/blockscout/blockscout/pull/2961) - Add a guard that addresses is enum in `values` function in `read contract` page
- [#2960](https://github.com/blockscout/blockscout/pull/2960) - Add BLOCKSCOUT_HOST to docker setup
- [#2956](https://github.com/blockscout/blockscout/pull/2956) - Add support of 0.6.x version of compiler
- [#2955](https://github.com/blockscout/blockscout/pull/2955) - Move socket path to env
- [#2938](https://github.com/blockscout/blockscout/pull/2938) - utf8 copy tx input tooltip
- [#2934](https://github.com/blockscout/blockscout/pull/2934) - RSK release 1.2.0 breaking changes support
- [#2933](https://github.com/blockscout/blockscout/pull/2933) - Get rid of deadlock in the query to address_current_token_balance table
- [#2932](https://github.com/blockscout/blockscout/pull/2932) - fix duplicate websocket connection
- [#2928](https://github.com/blockscout/blockscout/pull/2928) - Speedup pending block ops int txs to fetch query
- [#2924](https://github.com/blockscout/blockscout/pull/2924) - Speedup address to logs query
- [#2915](https://github.com/blockscout/blockscout/pull/2915) - Speedup of blocks_without_reward_query
- [#2914](https://github.com/blockscout/blockscout/pull/2914) - Reduce execution time of stream_unfetched_token_instances query
- [#2910](https://github.com/blockscout/blockscout/pull/2910) - Reorganize queries and indexes for internal_transactions table
- [#2908](https://github.com/blockscout/blockscout/pull/2908) - Fix performance of address page
- [#2906](https://github.com/blockscout/blockscout/pull/2906) - fix address sum cache
- [#2902](https://github.com/blockscout/blockscout/pull/2902) - Offset in blocks retrieval for average block time
- [#2900](https://github.com/blockscout/blockscout/pull/2900) - check fetched instance metadata in multiple places
- [#2899](https://github.com/blockscout/blockscout/pull/2899) - fix empty buffered task
- [#2887](https://github.com/blockscout/blockscout/pull/2887) - increase chart loading speed

### Chore

- [#2959](https://github.com/blockscout/blockscout/pull/2959) - Remove logs from test folder too in the cleaning script
- [#2954](https://github.com/blockscout/blockscout/pull/2954) - Upgrade absinthe and ecto deps
- [#2947](https://github.com/blockscout/blockscout/pull/2947) - Upgrade Circle CI postgres Docker image
- [#2946](https://github.com/blockscout/blockscout/pull/2946) - Fix vulnerable NPM deps
- [#2942](https://github.com/blockscout/blockscout/pull/2942) - Actualize Docker setup
- [#2896](https://github.com/blockscout/blockscout/pull/2896) - Disable Parity websockets tests
- [#2873](https://github.com/blockscout/blockscout/pull/2873) - bump elixir to 1.9.4

## 2.1.1-beta

### Features

- [#2862](https://github.com/blockscout/blockscout/pull/2862) - Coin total supply from DB API endpoint
- [#2857](https://github.com/blockscout/blockscout/pull/2857) - Extend getsourcecode API view with new output fields
- [#2822](https://github.com/blockscout/blockscout/pull/2822) - Estimated address count on the main page, if cache is empty
- [#2821](https://github.com/blockscout/blockscout/pull/2821) - add autodetection of constructor arguments
- [#2825](https://github.com/blockscout/blockscout/pull/2825) - separate token transfers and transactions
- [#2787](https://github.com/blockscout/blockscout/pull/2787) - async fetching of address counters
- [#2791](https://github.com/blockscout/blockscout/pull/2791) - add ipc client
- [#2449](https://github.com/blockscout/blockscout/pull/2449) - add ability to send notification events through postgres notify

### Fixes

- [#2864](https://github.com/blockscout/blockscout/pull/2864) - add token instance metadata type check
- [#2855](https://github.com/blockscout/blockscout/pull/2855) - Fix favicons load
- [#2854](https://github.com/blockscout/blockscout/pull/2854) - Fix all npm vulnerabilities
- [#2851](https://github.com/blockscout/blockscout/pull/2851) - Fix paths for front assets
- [#2843](https://github.com/blockscout/blockscout/pull/2843) - fix realtime fetcher small skips feature
- [#2841](https://github.com/blockscout/blockscout/pull/2841) - LUKSO dashboard height fix
- [#2837](https://github.com/blockscout/blockscout/pull/2837) - fix txlist ordering issue
- [#2830](https://github.com/blockscout/blockscout/pull/2830) - Fix wrong color of contract icon on xDai chain
- [#2829](https://github.com/blockscout/blockscout/pull/2829) - Fix for stuck gas limit label and value
- [#2828](https://github.com/blockscout/blockscout/pull/2828) - Fix for script that clears compilation/launching assets
- [#2800](https://github.com/blockscout/blockscout/pull/2800) - return not found for not verified contract for token read_contract
- [#2806](https://github.com/blockscout/blockscout/pull/2806) - Fix blocks fetching on the main page
- [#2803](https://github.com/blockscout/blockscout/pull/2803) - Fix block validator custom tooltip
- [#2748](https://github.com/blockscout/blockscout/pull/2748) - Rewrite token updater
- [#2704](https://github.com/blockscout/blockscout/pull/2704) - refetch null values in token balances
- [#2690](https://github.com/blockscout/blockscout/pull/2690) - do not stich json rpc config into module for net version cache

### Chore

- [#2878](https://github.com/blockscout/blockscout/pull/2878) - Decrease loaders showing delay on the main page
- [#2859](https://github.com/blockscout/blockscout/pull/2859) - Add eth_blockNumber API endpoint to eth_rpc section
- [#2846](https://github.com/blockscout/blockscout/pull/2846) - Remove networks images preload
- [#2845](https://github.com/blockscout/blockscout/pull/2845) - Set outline none for nav dropdown item in mobile view (fix for Safari)
- [#2844](https://github.com/blockscout/blockscout/pull/2844) - Extend external reward types up to 20
- [#2827](https://github.com/blockscout/blockscout/pull/2827) - Node js 12.13.0 (latest LTS release) support
- [#2818](https://github.com/blockscout/blockscout/pull/2818) - allow hiding marketcap percentage
- [#2817](https://github.com/blockscout/blockscout/pull/2817) - move docker integration documentation to blockscout docs
- [#2808](https://github.com/blockscout/blockscout/pull/2808) - Add tooltip for tx input
- [#2807](https://github.com/blockscout/blockscout/pull/2807) - 422 page
- [#2805](https://github.com/blockscout/blockscout/pull/2805) - Update supported chains default option
- [#2801](https://github.com/blockscout/blockscout/pull/2801) - remove unused clause in address_to_unique_tokens query

## 2.1.0-beta

### Features

- [#2776](https://github.com/blockscout/blockscout/pull/2776) - fetch token counters async
- [#2772](https://github.com/blockscout/blockscout/pull/2772) - add token instance images to the token inventory tab
- [#2733](https://github.com/blockscout/blockscout/pull/2733) - Add cache for first page of uncles
- [#2735](https://github.com/blockscout/blockscout/pull/2735) - Add pending transactions cache
- [#2726](https://github.com/blockscout/blockscout/pull/2726) - Remove internal_transaction block_number setting from blocks runner
- [#2717](https://github.com/blockscout/blockscout/pull/2717) - Improve speed of nonconsensus data removal
- [#2679](https://github.com/blockscout/blockscout/pull/2679) - added fixed height for card chain blocks and card chain transactions
- [#2678](https://github.com/blockscout/blockscout/pull/2678) - fixed dashboard banner height bug
- [#2672](https://github.com/blockscout/blockscout/pull/2672) - added new theme for xUSDT
- [#2667](https://github.com/blockscout/blockscout/pull/2667) - Add ETS-based cache for accounts page
- [#2666](https://github.com/blockscout/blockscout/pull/2666) - fetch token counters in parallel
- [#2665](https://github.com/blockscout/blockscout/pull/2665) - new menu layout for mobile devices
- [#2663](https://github.com/blockscout/blockscout/pull/2663) - Fetch address counters in parallel
- [#2642](https://github.com/blockscout/blockscout/pull/2642) - add ERC721 coin instance page
- [#2762](https://github.com/blockscout/blockscout/pull/2762) - on-fly fetching of token instances
- [#2470](https://github.com/blockscout/blockscout/pull/2470) - Allow Realtime Fetcher to wait for small skips

### Fixes

- [#4325](https://github.com/blockscout/blockscout/pull/4325) - Fix search on `/tokens` page
- [#2793](https://github.com/blockscout/blockscout/pull/2793) - Hide "We are indexing this chain right now. Some of the counts may be inaccurate" banner if no txs in blockchain
- [#2779](https://github.com/blockscout/blockscout/pull/2779) - fix fetching `latin1` encoded data
- [#2799](https://github.com/blockscout/blockscout/pull/2799) - fix catchup fetcher for empty node and db
- [#2783](https://github.com/blockscout/blockscout/pull/2783) - Fix stuck value and ticker on the token page
- [#2781](https://github.com/blockscout/blockscout/pull/2781) - optimize txlist json rpc
- [#2777](https://github.com/blockscout/blockscout/pull/2777) - Remove duplicate blocks from changes_list before import
- [#2770](https://github.com/blockscout/blockscout/pull/2770) - do not re-fetch token instances without uris
- [#2769](https://github.com/blockscout/blockscout/pull/2769) - optimize token token transfers query
- [#2768](https://github.com/blockscout/blockscout/pull/2768) - Remove nonconsensus blocks from cache after internal transactions importing
- [#2761](https://github.com/blockscout/blockscout/pull/2761) - add indexes for token instances fetching queries
- [#2767](https://github.com/blockscout/blockscout/pull/2767) - fix websocket subscriptions with token instances
- [#2765](https://github.com/blockscout/blockscout/pull/2765) - fixed width issue for cards in mobile view for Transaction Details page
- [#2755](https://github.com/blockscout/blockscout/pull/2755) - various token instance fetcher fixes
- [#2753](https://github.com/blockscout/blockscout/pull/2753) - fix nft token instance images
- [#2750](https://github.com/blockscout/blockscout/pull/2750) - fixed contract buttons color for NFT token instance on each theme
- [#2746](https://github.com/blockscout/blockscout/pull/2746) - fixed wrong alignment in logs decoded view
- [#2745](https://github.com/blockscout/blockscout/pull/2745) - optimize addresses page
- [#2742](https://github.com/blockscout/blockscout/pull/2742) -
fixed menu hovers in dark mode desktop view
- [#2737](https://github.com/blockscout/blockscout/pull/2737) - switched hardcoded subnetwork value to elixir expression for mobile menu
- [#2736](https://github.com/blockscout/blockscout/pull/2736) - do not update cache if no blocks were inserted
- [#2731](https://github.com/blockscout/blockscout/pull/2731) - fix library verification
- [#2718](https://github.com/blockscout/blockscout/pull/2718) - Include all addresses taking part in transactions in wallets' addresses counter
- [#2709](https://github.com/blockscout/blockscout/pull/2709) - Fix stuck label and value for uncle block height
- [#2707](https://github.com/blockscout/blockscout/pull/2707) - fix for dashboard banner chart legend items
- [#2706](https://github.com/blockscout/blockscout/pull/2706) - fix empty total_supply in coin gecko response
- [#2701](https://github.com/blockscout/blockscout/pull/2701) - Exclude nonconsensus blocks from avg block time calculation by default
- [#2696](https://github.com/blockscout/blockscout/pull/2696) - do not update fetched_coin_balance with nil
- [#2693](https://github.com/blockscout/blockscout/pull/2693) - remove non consensus internal transactions
- [#2691](https://github.com/blockscout/blockscout/pull/2691) - fix exchange rate websocket update for Rootstock
- [#2688](https://github.com/blockscout/blockscout/pull/2688) - fix try it out section
- [#2687](https://github.com/blockscout/blockscout/pull/2687) - remove non-consensus token transfers, logs when inserting new consensus blocks
- [#2684](https://github.com/blockscout/blockscout/pull/2684) - do not filter pending logs
- [#2682](https://github.com/blockscout/blockscout/pull/2682) - Use Task.start instead of Task.async in caches
- [#2671](https://github.com/blockscout/blockscout/pull/2671) - fixed buttons color at smart contract section
- [#2660](https://github.com/blockscout/blockscout/pull/2660) - set correct last value for coin balances chart data
- [#2619](https://github.com/blockscout/blockscout/pull/2619) - Enforce DB transaction's order to prevent deadlocks
- [#2738](https://github.com/blockscout/blockscout/pull/2738) - do not fail block `internal_transactions_indexed_at` field update

### Chore

- [#2797](https://github.com/blockscout/blockscout/pull/2797) - Return old style menu
- [#2796](https://github.com/blockscout/blockscout/pull/2796) - Optimize all images with ImageOptim
- [#2794](https://github.com/blockscout/blockscout/pull/2786) - update hosted versions in readme
- [#2789](https://github.com/blockscout/blockscout/pull/2786) - remove projects table in readme, link to docs version
- [#2786](https://github.com/blockscout/blockscout/pull/2786) - updated docs links, removed docs folder
- [#2752](https://github.com/blockscout/blockscout/pull/2752) - allow enabling internal transactions for simple token transfers txs
- [#2749](https://github.com/blockscout/blockscout/pull/2749) - fix opt 22.1 support
- [#2744](https://github.com/blockscout/blockscout/pull/2744) - Disable Geth tests in CI
- [#2724](https://github.com/blockscout/blockscout/pull/2724) - fix ci by commenting a line in hackney library
- [#2708](https://github.com/blockscout/blockscout/pull/2708) - add log index to logs view
- [#2723](https://github.com/blockscout/blockscout/pull/2723) - get rid of ex_json_schema warnings
- [#2740](https://github.com/blockscout/blockscout/pull/2740) - add verify contract rpc doc

## 2.0.4-beta

### Features

- [#2636](https://github.com/blockscout/blockscout/pull/2636) - Execute all address' transactions page queries in parallel
- [#2596](https://github.com/blockscout/blockscout/pull/2596) - support AuRa's empty step reward type
- [#2588](https://github.com/blockscout/blockscout/pull/2588) - add verification submission comment
- [#2505](https://github.com/blockscout/blockscout/pull/2505) - support POA Network emission rewards
- [#2581](https://github.com/blockscout/blockscout/pull/2581) - Add generic Map-like Cache behavior and implementation
- [#2561](https://github.com/blockscout/blockscout/pull/2561) - Add token's type to the response of tokenlist method
- [#2555](https://github.com/blockscout/blockscout/pull/2555) - find and show decoding candidates for logs
- [#2499](https://github.com/blockscout/blockscout/pull/2499) - import emission reward ranges
- [#2497](https://github.com/blockscout/blockscout/pull/2497) - Add generic Ordered Cache behavior and implementation

### Fixes

- [#2659](https://github.com/blockscout/blockscout/pull/2659) - Multipurpose front-end part update
- [#2640](https://github.com/blockscout/blockscout/pull/2640) - SVG network icons
- [#2635](https://github.com/blockscout/blockscout/pull/2635) - optimize ERC721 inventory query
- [#2626](https://github.com/blockscout/blockscout/pull/2626) - Fixing 2 Mobile UI Issues
- [#2623](https://github.com/blockscout/blockscout/pull/2623) - fix a blinking test
- [#2616](https://github.com/blockscout/blockscout/pull/2616) - deduplicate coin history records by delta
- [#2613](https://github.com/blockscout/blockscout/pull/2613) - fix getminedblocks rpc endpoint
- [#2612](https://github.com/blockscout/blockscout/pull/2612) - Add cache updating independently from Indexer
- [#2610](https://github.com/blockscout/blockscout/pull/2610) - use CoinGecko instead of CoinMarketcap for exchange rates
- [#2592](https://github.com/blockscout/blockscout/pull/2592) - process new metadata format for whisper
- [#2591](https://github.com/blockscout/blockscout/pull/2591) - Fix url error in API page
- [#2572](https://github.com/blockscout/blockscout/pull/2572) - Ease non-critical css
- [#2570](https://github.com/blockscout/blockscout/pull/2570) - Network icons preload
- [#2569](https://github.com/blockscout/blockscout/pull/2569) - do not fetch emission rewards for transactions csv exporter
- [#2568](https://github.com/blockscout/blockscout/pull/2568) - filter pending token transfers
- [#2564](https://github.com/blockscout/blockscout/pull/2564) - fix first page button for uncles and reorgs
- [#2563](https://github.com/blockscout/blockscout/pull/2563) - Fix view less transfers button
- [#2538](https://github.com/blockscout/blockscout/pull/2538) - fetch the last not empty coin balance records
- [#2468](https://github.com/blockscout/blockscout/pull/2468) - fix confirmations for non consensus blocks

### Chore

- [#2662](https://github.com/blockscout/blockscout/pull/2662) - fetch coin gecko id based on the coin symbol
- [#2646](https://github.com/blockscout/blockscout/pull/2646) - Added Xerom to list of Additional Chains using BlockScout
- [#2634](https://github.com/blockscout/blockscout/pull/2634) - add Lukso to networks dropdown
- [#2617](https://github.com/blockscout/blockscout/pull/2617) - skip cache update if there are no blocks inserted
- [#2611](https://github.com/blockscout/blockscout/pull/2611) - fix js dependency vulnerabilities
- [#2594](https://github.com/blockscout/blockscout/pull/2594) - do not start genesis data fetching periodically
- [#2590](https://github.com/blockscout/blockscout/pull/2590) - restore backward compatibility with old releases
- [#2577](https://github.com/blockscout/blockscout/pull/2577) - Need recompile column in the env vars table
- [#2574](https://github.com/blockscout/blockscout/pull/2574) - limit request body in json rpc error
- [#2566](https://github.com/blockscout/blockscout/pull/2566) - upgrade absinthe phoenix

## 2.0.3-beta

### Features

- [#2433](https://github.com/blockscout/blockscout/pull/2433) - Add a functionality to try Eth RPC methods in the documentation
- [#2529](https://github.com/blockscout/blockscout/pull/2529) - show both eth value and token transfers on transaction overview page
- [#2376](https://github.com/blockscout/blockscout/pull/2376) - Split API and WebApp routes
- [#2477](https://github.com/blockscout/blockscout/pull/2477) - aggregate token transfers on transaction page
- [#2458](https://github.com/blockscout/blockscout/pull/2458) - Add LAST_BLOCK var to add ability indexing in the range of blocks
- [#2456](https://github.com/blockscout/blockscout/pull/2456) - fetch pending transactions for geth
- [#2403](https://github.com/blockscout/blockscout/pull/2403) - Return gasPrice field at the result of gettxinfo method

### Fixes

- [#2562](https://github.com/blockscout/blockscout/pull/2562) - Fix dark theme flickering
- [#2560](https://github.com/blockscout/blockscout/pull/2560) - fix slash before not empty path in docs
- [#2559](https://github.com/blockscout/blockscout/pull/2559) - fix rsk total supply for empty exchange rate
- [#2553](https://github.com/blockscout/blockscout/pull/2553) - Dark theme import to the end of sass
- [#2550](https://github.com/blockscout/blockscout/pull/2550) - correctly encode decimal values for frontend
- [#2549](https://github.com/blockscout/blockscout/pull/2549) - Fix wrong color of tooltip
- [#2548](https://github.com/blockscout/blockscout/pull/2548) - CSS preload support in Firefox
- [#2547](https://github.com/blockscout/blockscout/pull/2547) - do not show eth value if it's zero on the transaction overview page
- [#2543](https://github.com/blockscout/blockscout/pull/2543) - do not hide search input during logs search
- [#2524](https://github.com/blockscout/blockscout/pull/2524) - fix dark theme validator data styles
- [#2532](https://github.com/blockscout/blockscout/pull/2532) - don't show empty token transfers on the transaction overview page
- [#2528](https://github.com/blockscout/blockscout/pull/2528) - fix coin history chart data
- [#2520](https://github.com/blockscout/blockscout/pull/2520) - Hide loading message when fetching is failed
- [#2523](https://github.com/blockscout/blockscout/pull/2523) - Avoid importing internal_transactions of pending transactions
- [#2519](https://github.com/blockscout/blockscout/pull/2519) - enable `First` page button in pagination
- [#2518](https://github.com/blockscout/blockscout/pull/2518) - create suggested indexes
- [#2517](https://github.com/blockscout/blockscout/pull/2517) - remove duplicate indexes
- [#2515](https://github.com/blockscout/blockscout/pull/2515) - do not aggregate NFT token transfers
- [#2514](https://github.com/blockscout/blockscout/pull/2514) - Isolating of staking dapp css && extracting of non-critical css
- [#2512](https://github.com/blockscout/blockscout/pull/2512) - alert link fix
- [#2509](https://github.com/blockscout/blockscout/pull/2509) - value-ticker gaps fix
- [#2508](https://github.com/blockscout/blockscout/pull/2508) - logs view columns fix
- [#2506](https://github.com/blockscout/blockscout/pull/2506) - fix two active tab in the top menu
- [#2503](https://github.com/blockscout/blockscout/pull/2503) - Mitigate autocompletion library influence to page loading performance
- [#2502](https://github.com/blockscout/blockscout/pull/2502) - increase reward task timeout
- [#2463](https://github.com/blockscout/blockscout/pull/2463) - dark theme fixes
- [#2496](https://github.com/blockscout/blockscout/pull/2496) - fix docker build
- [#2495](https://github.com/blockscout/blockscout/pull/2495) - fix logs for indexed chain
- [#2459](https://github.com/blockscout/blockscout/pull/2459) - fix top addresses query
- [#2425](https://github.com/blockscout/blockscout/pull/2425) - Force to show address view for checksummed address even if it is not in DB
- [#2551](https://github.com/blockscout/blockscout/pull/2551) - Correctly handle dynamically created Bootstrap tooltips

### Chore

- [#2554](https://github.com/blockscout/blockscout/pull/2554) - remove extra slash for endpoint url in docs
- [#2552](https://github.com/blockscout/blockscout/pull/2552) - remove brackets for token holders percentage
- [#2507](https://github.com/blockscout/blockscout/pull/2507) - update minor version of ecto, ex_machina, phoenix_live_reload
- [#2516](https://github.com/blockscout/blockscout/pull/2516) - update absinthe plug from fork
- [#2473](https://github.com/blockscout/blockscout/pull/2473) - get rid of cldr warnings
- [#2402](https://github.com/blockscout/blockscout/pull/2402) - bump otp version to 22.0
- [#2492](https://github.com/blockscout/blockscout/pull/2492) - hide decoded row if event is not decoded
- [#2490](https://github.com/blockscout/blockscout/pull/2490) - enable credo duplicated code check
- [#2432](https://github.com/blockscout/blockscout/pull/2432) - bump credo version
- [#2457](https://github.com/blockscout/blockscout/pull/2457) - update mix.lock
- [#2435](https://github.com/blockscout/blockscout/pull/2435) - Replace deprecated extract-text-webpack-plugin with mini-css-extract-plugin
- [#2450](https://github.com/blockscout/blockscout/pull/2450) - Fix clearance of logs and node_modules folders in clearing script
- [#2434](https://github.com/blockscout/blockscout/pull/2434) - get rid of timex warnings
- [#2402](https://github.com/blockscout/blockscout/pull/2402) - bump otp version to 22.0
- [#2373](https://github.com/blockscout/blockscout/pull/2373) - Add script to validate internal_transactions constraint for large DBs

## 2.0.2-beta

### Features

- [#2412](https://github.com/blockscout/blockscout/pull/2412) - dark theme
- [#2399](https://github.com/blockscout/blockscout/pull/2399) - decode verified smart contract's logs
- [#2391](https://github.com/blockscout/blockscout/pull/2391) - Controllers Improvements
- [#2379](https://github.com/blockscout/blockscout/pull/2379) - Disable network selector when is empty
- [#2374](https://github.com/blockscout/blockscout/pull/2374) - decode constructor arguments for verified smart contracts
- [#2366](https://github.com/blockscout/blockscout/pull/2366) - paginate eth logs
- [#2360](https://github.com/blockscout/blockscout/pull/2360) - add default evm version to smart contract verification
- [#2352](https://github.com/blockscout/blockscout/pull/2352) - Fetch rewards in parallel with transactions
- [#2294](https://github.com/blockscout/blockscout/pull/2294) - add healthy block period checking endpoint
- [#2324](https://github.com/blockscout/blockscout/pull/2324) - set timeout for loading message on the main page

### Fixes

- [#2421](https://github.com/blockscout/blockscout/pull/2421) - Fix hiding of loader for txs on the main page
- [#2420](https://github.com/blockscout/blockscout/pull/2420) - fetch data from cache in healthy endpoint
- [#2416](https://github.com/blockscout/blockscout/pull/2416) - Fix "page not found" handling in the router
- [#2413](https://github.com/blockscout/blockscout/pull/2413) - remove outer tables for decoded data
- [#2410](https://github.com/blockscout/blockscout/pull/2410) - preload smart contract for logs decoding
- [#2405](https://github.com/blockscout/blockscout/pull/2405) - added templates for table loader and tile loader
- [#2398](https://github.com/blockscout/blockscout/pull/2398) - show only one decoded candidate
- [#2389](https://github.com/blockscout/blockscout/pull/2389) - Reduce Lodash lib size (86% of lib methods are not used)
- [#2388](https://github.com/blockscout/blockscout/pull/2388) - add create2 support to geth's js tracer
- [#2387](https://github.com/blockscout/blockscout/pull/2387) - fix not existing keys in transaction json rpc
- [#2378](https://github.com/blockscout/blockscout/pull/2378) - Page performance: exclude moment.js localization files except EN, remove unused css
- [#2368](https://github.com/blockscout/blockscout/pull/2368) - add two columns of smart contract info
- [#2375](https://github.com/blockscout/blockscout/pull/2375) - Update created_contract_code_indexed_at on transaction import conflict
- [#2346](https://github.com/blockscout/blockscout/pull/2346) - Avoid fetching internal transactions of blocks that still need refetching
- [#2350](https://github.com/blockscout/blockscout/pull/2350) - fix invalid User agent headers
- [#2345](https://github.com/blockscout/blockscout/pull/2345) - do not override existing market records
- [#2337](https://github.com/blockscout/blockscout/pull/2337) - set url params for prod explicitly
- [#2341](https://github.com/blockscout/blockscout/pull/2341) - fix transaction input json encoding
- [#2311](https://github.com/blockscout/blockscout/pull/2311) - fix market history overriding with zeroes
- [#2310](https://github.com/blockscout/blockscout/pull/2310) - parse url for api docs
- [#2299](https://github.com/blockscout/blockscout/pull/2299) - fix interpolation in error message
- [#2303](https://github.com/blockscout/blockscout/pull/2303) - fix transaction csv download link
- [#2304](https://github.com/blockscout/blockscout/pull/2304) - footer grid fix for md resolution
- [#2291](https://github.com/blockscout/blockscout/pull/2291) - dashboard fix for md resolution, transactions load fix, block info row fix, addresses page issue, check mark issue
- [#2326](https://github.com/blockscout/blockscout/pull/2326) - fix nested constructor arguments

### Chore

- [#2422](https://github.com/blockscout/blockscout/pull/2422) - check if address_id is binary in token_transfers_csv endpoint
- [#2418](https://github.com/blockscout/blockscout/pull/2418) - Remove parentheses in market cap percentage
- [#2401](https://github.com/blockscout/blockscout/pull/2401) - add ENV vars to manage updating period of average block time and market history cache
- [#2363](https://github.com/blockscout/blockscout/pull/2363) - add parameters example for eth rpc
- [#2342](https://github.com/blockscout/blockscout/pull/2342) - Upgrade Postgres image version in Docker setup
- [#2325](https://github.com/blockscout/blockscout/pull/2325) - Reduce function input to address' hash only where possible
- [#2323](https://github.com/blockscout/blockscout/pull/2323) - Group Explorer caches
- [#2305](https://github.com/blockscout/blockscout/pull/2305) - Improve Address controllers
- [#2302](https://github.com/blockscout/blockscout/pull/2302) - fix names for xDai source
- [#2289](https://github.com/blockscout/blockscout/pull/2289) - Optional websockets for dev environment
- [#2307](https://github.com/blockscout/blockscout/pull/2307) - add GoJoy to README
- [#2293](https://github.com/blockscout/blockscout/pull/2293) - remove request idle timeout configuration
- [#2255](https://github.com/blockscout/blockscout/pull/2255) - bump elixir version to 1.9.0

## 2.0.1-beta

### Features

- [#2283](https://github.com/blockscout/blockscout/pull/2283) - Add transactions cache
- [#2182](https://github.com/blockscout/blockscout/pull/2182) - add market history cache
- [#2109](https://github.com/blockscout/blockscout/pull/2109) - use bigger updates instead of `Multi` transactions in BlocksTransactionsMismatch
- [#2075](https://github.com/blockscout/blockscout/pull/2075) - add blocks cache
- [#2151](https://github.com/blockscout/blockscout/pull/2151) - hide dropdown menu then other networks list is empty
- [#2191](https://github.com/blockscout/blockscout/pull/2191) - allow to configure token metadata update interval
- [#2146](https://github.com/blockscout/blockscout/pull/2146) - feat: add eth_getLogs rpc endpoint
- [#2216](https://github.com/blockscout/blockscout/pull/2216) - Improve token's controllers by avoiding unnecessary preloads
- [#2235](https://github.com/blockscout/blockscout/pull/2235) - save and show additional validation fields to smart contract
- [#2190](https://github.com/blockscout/blockscout/pull/2190) - show all token transfers
- [#2193](https://github.com/blockscout/blockscout/pull/2193) - feat: add BLOCKSCOUT_HOST, and use it in API docs
- [#2266](https://github.com/blockscout/blockscout/pull/2266) - allow excluding uncles from average block time calculation

### Fixes

- [#2290](https://github.com/blockscout/blockscout/pull/2290) - Add eth_get_balance.json to AddressView's render
- [#2286](https://github.com/blockscout/blockscout/pull/2286) - banner stats issues on sm resolutions, transactions title issue
- [#2284](https://github.com/blockscout/blockscout/pull/2284) - add 404 status for not existing pages
- [#2244](https://github.com/blockscout/blockscout/pull/2244) - fix internal transactions failing to be indexed because of constraint
- [#2281](https://github.com/blockscout/blockscout/pull/2281) - typo issues, dropdown issues
- [#2278](https://github.com/blockscout/blockscout/pull/2278) - increase threshold for scientific notation
- [#2275](https://github.com/blockscout/blockscout/pull/2275) - Description for networks selector
- [#2263](https://github.com/blockscout/blockscout/pull/2263) - added an ability to close network selector on outside click
- [#2257](https://github.com/blockscout/blockscout/pull/2257) - 'download csv' button added to different tabs
- [#2242](https://github.com/blockscout/blockscout/pull/2242) - added styles for 'download csv' button
- [#2261](https://github.com/blockscout/blockscout/pull/2261) - header logo aligned to the center properly
- [#2254](https://github.com/blockscout/blockscout/pull/2254) - search length issue, tile link wrapping issue
- [#2238](https://github.com/blockscout/blockscout/pull/2238) - header content alignment issue, hide navbar on outside click
- [#2229](https://github.com/blockscout/blockscout/pull/2229) - gap issue between qr and copy button in token transfers, top cards width and height issue
- [#2201](https://github.com/blockscout/blockscout/pull/2201) - footer columns fix
- [#2179](https://github.com/blockscout/blockscout/pull/2179) - fix docker build error
- [#2165](https://github.com/blockscout/blockscout/pull/2165) - sort blocks by timestamp when calculating average block time
- [#2175](https://github.com/blockscout/blockscout/pull/2175) - fix coinmarketcap response errors
- [#2164](https://github.com/blockscout/blockscout/pull/2164) - fix large numbers in balance view card
- [#2155](https://github.com/blockscout/blockscout/pull/2155) - fix pending transaction query
- [#2183](https://github.com/blockscout/blockscout/pull/2183) - tile content aligning for mobile resolution fix, dai logo fix
- [#2162](https://github.com/blockscout/blockscout/pull/2162) - contract creation tile color changed
- [#2144](https://github.com/blockscout/blockscout/pull/2144) - 'page not found' images path fixed for goerli
- [#2142](https://github.com/blockscout/blockscout/pull/2142) - Removed posdao theme and logo, added 'page not found' image for goerli
- [#2138](https://github.com/blockscout/blockscout/pull/2138) - badge colors issue, api titles issue
- [#2129](https://github.com/blockscout/blockscout/pull/2129) - Fix for width of explorer elements
- [#2121](https://github.com/blockscout/blockscout/pull/2121) - Binding of 404 page
- [#2120](https://github.com/blockscout/blockscout/pull/2120) - footer links and socials focus color issue
- [#2113](https://github.com/blockscout/blockscout/pull/2113) - renewed logos for rsk, dai, blockscout; themes color changes for lukso; error images for lukso
- [#2112](https://github.com/blockscout/blockscout/pull/2112) - themes color improvements, dropdown color issue
- [#2110](https://github.com/blockscout/blockscout/pull/2110) - themes colors issues, ui issues
- [#2103](https://github.com/blockscout/blockscout/pull/2103) - ui issues for all themes
- [#2090](https://github.com/blockscout/blockscout/pull/2090) - updated some ETC theme colors
- [#2096](https://github.com/blockscout/blockscout/pull/2096) - RSK theme fixes
- [#2093](https://github.com/blockscout/blockscout/pull/2093) - detect token transfer type for deprecated erc721 spec
- [#2111](https://github.com/blockscout/blockscout/pull/2111) - improve address transaction controller
- [#2108](https://github.com/blockscout/blockscout/pull/2108) - fix uncle fetching without full transactions
- [#2128](https://github.com/blockscout/blockscout/pull/2128) - add new function clause for uncle errors
- [#2123](https://github.com/blockscout/blockscout/pull/2123) - fix coins percentage view
- [#2119](https://github.com/blockscout/blockscout/pull/2119) - fix map logging
- [#2130](https://github.com/blockscout/blockscout/pull/2130) - fix navigation
- [#2148](https://github.com/blockscout/blockscout/pull/2148) - filter pending logs
- [#2147](https://github.com/blockscout/blockscout/pull/2147) - add rsk format of checksum
- [#2149](https://github.com/blockscout/blockscout/pull/2149) - remove pending transaction count
- [#2177](https://github.com/blockscout/blockscout/pull/2177) - remove duplicate entries from UncleBlock's Fetcher
- [#2169](https://github.com/blockscout/blockscout/pull/2169) - add more validator reward types for xDai
- [#2173](https://github.com/blockscout/blockscout/pull/2173) - handle correctly empty transactions
- [#2174](https://github.com/blockscout/blockscout/pull/2174) - fix reward channel joining
- [#2186](https://github.com/blockscout/blockscout/pull/2186) - fix net version test
- [#2196](https://github.com/blockscout/blockscout/pull/2196) - Nethermind client fixes
- [#2237](https://github.com/blockscout/blockscout/pull/2237) - fix rsk total_supply
- [#2198](https://github.com/blockscout/blockscout/pull/2198) - reduce transaction status and error constraint
- [#2167](https://github.com/blockscout/blockscout/pull/2167) - feat: document eth rpc api mimicking endpoints
- [#2225](https://github.com/blockscout/blockscout/pull/2225) - fix metadata decoding in Solidity 0.5.9 smart contract verification
- [#2204](https://github.com/blockscout/blockscout/pull/2204) - fix large contract verification
- [#2258](https://github.com/blockscout/blockscout/pull/2258) - reduce BlocksTransactionsMismatch memory footprint
- [#2247](https://github.com/blockscout/blockscout/pull/2247) - hide logs search if there are no logs
- [#2248](https://github.com/blockscout/blockscout/pull/2248) - sort block after query execution for average block time
- [#2249](https://github.com/blockscout/blockscout/pull/2249) - More transaction controllers improvements
- [#2267](https://github.com/blockscout/blockscout/pull/2267) - Modify implementation of `where_transaction_has_multiple_internal_transactions`
- [#2270](https://github.com/blockscout/blockscout/pull/2270) - Remove duplicate params in `Indexer.Fetcher.TokenBalance`
- [#2268](https://github.com/blockscout/blockscout/pull/2268) - remove not existing assigns in html code
- [#2276](https://github.com/blockscout/blockscout/pull/2276) - remove port in docs

### Chore

- [#2127](https://github.com/blockscout/blockscout/pull/2127) - use previous chromedriver version
- [#2118](https://github.com/blockscout/blockscout/pull/2118) - show only the last decompiled contract
- [#2255](https://github.com/blockscout/blockscout/pull/2255) - upgrade elixir version to 1.9.0
- [#2256](https://github.com/blockscout/blockscout/pull/2256) - use the latest version of chromedriver

## 2.0.0-beta

### Features

- [#2044](https://github.com/blockscout/blockscout/pull/2044) - New network selector.
- [#2091](https://github.com/blockscout/blockscout/pull/2091) - Added "Question" modal.
- [#1963](https://github.com/blockscout/blockscout/pull/1963), [#1959](https://github.com/blockscout/blockscout/pull/1959), [#1948](https://github.com/blockscout/blockscout/pull/1948), [#1936](https://github.com/blockscout/blockscout/pull/1936), [#1925](https://github.com/blockscout/blockscout/pull/1925), [#1922](https://github.com/blockscout/blockscout/pull/1922), [#1903](https://github.com/blockscout/blockscout/pull/1903), [#1874](https://github.com/blockscout/blockscout/pull/1874), [#1895](https://github.com/blockscout/blockscout/pull/1895), [#2031](https://github.com/blockscout/blockscout/pull/2031), [#2073](https://github.com/blockscout/blockscout/pull/2073), [#2074](https://github.com/blockscout/blockscout/pull/2074),  - added new themes and logos for poa, eth, rinkeby, goerli, ropsten, kovan, sokol, xdai, etc, rsk and default theme
- [#1726](https://github.com/blockscout/blockscout/pull/2071) - Updated styles for the new smart contract page.
- [#2081](https://github.com/blockscout/blockscout/pull/2081) - Tooltip for 'more' button, explorers logos added
- [#2010](https://github.com/blockscout/blockscout/pull/2010) - added "block not found" and "tx not found pages"
- [#1928](https://github.com/blockscout/blockscout/pull/1928) - pagination styles were updated
- [#1940](https://github.com/blockscout/blockscout/pull/1940) - qr modal button and background issue
- [#1907](https://github.com/blockscout/blockscout/pull/1907) - dropdown color bug fix (lukso theme) and tooltip color bug fix
- [#1859](https://github.com/blockscout/blockscout/pull/1859) - feat: show raw transaction traces
- [#1941](https://github.com/blockscout/blockscout/pull/1941) - feat: add on demand fetching and stale attr to rpc
- [#1957](https://github.com/blockscout/blockscout/pull/1957) - Calculate stakes ratio before insert pools
- [#1956](https://github.com/blockscout/blockscout/pull/1956) - add logs tab to address
- [#1952](https://github.com/blockscout/blockscout/pull/1952) - feat: exclude empty contracts by default
- [#1954](https://github.com/blockscout/blockscout/pull/1954) - feat: use creation init on self destruct
- [#2036](https://github.com/blockscout/blockscout/pull/2036) - New tables for staking pools and delegators
- [#1974](https://github.com/blockscout/blockscout/pull/1974) - feat: previous page button logic
- [#1999](https://github.com/blockscout/blockscout/pull/1999) - load data async on addresses page
- [#1807](https://github.com/blockscout/blockscout/pull/1807) - New theming capabilities.
- [#2040](https://github.com/blockscout/blockscout/pull/2040) - Verification links to other explorers for ETH
- [#2037](https://github.com/blockscout/blockscout/pull/2037) - add address logs search functionality
- [#2012](https://github.com/blockscout/blockscout/pull/2012) - make all pages pagination async
- [#2064](https://github.com/blockscout/blockscout/pull/2064) - feat: add fields to tx apis, small cleanups
- [#2100](https://github.com/blockscout/blockscout/pull/2100) - feat: eth_get_balance rpc endpoint

### Fixes

- [#2228](https://github.com/blockscout/blockscout/pull/2228) - favorites duplication issues, active radio issue
- [#2207](https://github.com/blockscout/blockscout/pull/2207) - new 'download csv' button design
- [#2206](https://github.com/blockscout/blockscout/pull/2206) - added styles for 'Download All Transactions as CSV' button
- [#2099](https://github.com/blockscout/blockscout/pull/2099) - logs search input width
- [#2098](https://github.com/blockscout/blockscout/pull/2098) - nav dropdown issue, logo size issue
- [#2082](https://github.com/blockscout/blockscout/pull/2082) - dropdown styles, tooltip gap fix, 404 page added
- [#2077](https://github.com/blockscout/blockscout/pull/2077) - ui issues
- [#2072](https://github.com/blockscout/blockscout/pull/2072) - Fixed checkmarks not showing correctly in tabs.
- [#2066](https://github.com/blockscout/blockscout/pull/2066) - fixed length of logs search input
- [#2056](https://github.com/blockscout/blockscout/pull/2056) - log search form styles added
- [#2043](https://github.com/blockscout/blockscout/pull/2043) - Fixed modal dialog width for 'verify other explorers'
- [#2025](https://github.com/blockscout/blockscout/pull/2025) - Added a new color to display transactions' errors.
- [#2033](https://github.com/blockscout/blockscout/pull/2033) - Header nav. dropdown active element color issue
- [#2019](https://github.com/blockscout/blockscout/pull/2019) - Fixed the missing tx hashes.
- [#2020](https://github.com/blockscout/blockscout/pull/2020) - Fixed a bug triggered when a second click to a selected tab caused the other tabs to hide.
- [#1944](https://github.com/blockscout/blockscout/pull/1944) - fixed styles for token's dropdown.
- [#1926](https://github.com/blockscout/blockscout/pull/1926) - status label alignment
- [#1849](https://github.com/blockscout/blockscout/pull/1849) - Improve chains menu
- [#1868](https://github.com/blockscout/blockscout/pull/1868) - fix: logs list endpoint performance
- [#1822](https://github.com/blockscout/blockscout/pull/1822) - Fix style breaks in decompiled contract code view
- [#1885](https://github.com/blockscout/blockscout/pull/1885) - highlight reserved words in decompiled code
- [#1896](https://github.com/blockscout/blockscout/pull/1896) - re-query tokens in top nav autocomplete
- [#1905](https://github.com/blockscout/blockscout/pull/1905) - fix reorgs, uncles pagination
- [#1904](https://github.com/blockscout/blockscout/pull/1904) - fix `BLOCK_COUNT_CACHE_TTL` env var type
- [#1915](https://github.com/blockscout/blockscout/pull/1915) - fallback to 2 latest evm versions
- [#1937](https://github.com/blockscout/blockscout/pull/1937) - Check the presence of overlap[i] object before retrieving properties from it
- [#1960](https://github.com/blockscout/blockscout/pull/1960) - do not remove bold text in decompiled contacts
- [#1966](https://github.com/blockscout/blockscout/pull/1966) - fix: add fields for contract filter performance
- [#2017](https://github.com/blockscout/blockscout/pull/2017) - fix: fix to/from filters on tx list pages
- [#2008](https://github.com/blockscout/blockscout/pull/2008) - add new function clause for xDai network beneficiaries
- [#2009](https://github.com/blockscout/blockscout/pull/2009) - addresses page improvements
- [#2027](https://github.com/blockscout/blockscout/pull/2027) - fix: `BlocksTransactionsMismatch` ignoring blocks without transactions
- [#2062](https://github.com/blockscout/blockscout/pull/2062) - fix: uniq by hash, instead of transaction
- [#2052](https://github.com/blockscout/blockscout/pull/2052) - allow bytes32 for name and symbol
- [#2047](https://github.com/blockscout/blockscout/pull/2047) - fix: show creating internal transactions
- [#2014](https://github.com/blockscout/blockscout/pull/2014) - fix: use better queries for listLogs endpoint
- [#2027](https://github.com/blockscout/blockscout/pull/2027) - fix: `BlocksTransactionsMismatch` ignoring blocks without transactions
- [#2070](https://github.com/blockscout/blockscout/pull/2070) - reduce `max_concurrency` of `BlocksTransactionsMismatch` fetcher
- [#2083](https://github.com/blockscout/blockscout/pull/2083) - allow total_difficulty to be nil
- [#2086](https://github.com/blockscout/blockscout/pull/2086) - fix geth's staticcall without output

### Chore

- [#1900](https://github.com/blockscout/blockscout/pull/1900) - SUPPORTED_CHAINS ENV var
- [#1958](https://github.com/blockscout/blockscout/pull/1958) - Default value for release link env var
- [#1964](https://github.com/blockscout/blockscout/pull/1964) - ALLOWED_EVM_VERSIONS env var
- [#1975](https://github.com/blockscout/blockscout/pull/1975) - add log index to transaction view
- [#1988](https://github.com/blockscout/blockscout/pull/1988) - Fix wrong parity tasks names in Circle CI
- [#2000](https://github.com/blockscout/blockscout/pull/2000) - docker/Makefile: always set a container name
- [#2018](https://github.com/blockscout/blockscout/pull/2018) - Use PORT env variable in dev config
- [#2055](https://github.com/blockscout/blockscout/pull/2055) - Increase timeout for geth indexers
- [#2069](https://github.com/blockscout/blockscout/pull/2069) - Docsify integration: static docs page generation

## 1.3.15-beta

### Features

- [#1857](https://github.com/blockscout/blockscout/pull/1857) - Re-implement Geth JS internal transaction tracer in Elixir
- [#1989](https://github.com/blockscout/blockscout/pull/1989) - fix: consolidate address w/ balance one at a time
- [#2002](https://github.com/blockscout/blockscout/pull/2002) - Get estimated count of blocks when cache is empty

### Fixes

- [#1869](https://github.com/blockscout/blockscout/pull/1869) - Fix output and gas extraction in JS tracer for Geth
- [#1992](https://github.com/blockscout/blockscout/pull/1992) - fix: support https for wobserver polling
- [#2027](https://github.com/blockscout/blockscout/pull/2027) - fix: `BlocksTransactionsMismatch` ignoring blocks without transactions

## 1.3.14-beta

- [#1812](https://github.com/blockscout/blockscout/pull/1812) - add pagination to addresses page
- [#1920](https://github.com/blockscout/blockscout/pull/1920) - fix: remove source code fields from list endpoint
- [#1876](https://github.com/blockscout/blockscout/pull/1876) - async calculate a count of blocks

### Fixes

- [#1917](https://github.com/blockscout/blockscout/pull/1917) - Force block refetch if transaction is re-collated in a different block

### Chore

- [#1892](https://github.com/blockscout/blockscout/pull/1892) - Remove temporary worker modules

## 1.3.13-beta

### Features

- [#1933](https://github.com/blockscout/blockscout/pull/1933) - add eth_BlockNumber json rpc method

### Fixes

- [#1875](https://github.com/blockscout/blockscout/pull/1875) - fix: resolve false positive constructor arguments
- [#1881](https://github.com/blockscout/blockscout/pull/1881) - fix: store solc versions locally for performance
- [#1898](https://github.com/blockscout/blockscout/pull/1898) - check if the constructor has arguments before verifying constructor arguments

## 1.3.12-beta

Reverting of synchronous block counter, implemented in #1848

## 1.3.11-beta

### Features

- [#1815](https://github.com/blockscout/blockscout/pull/1815) - Be able to search without prefix "0x"
- [#1813](https://github.com/blockscout/blockscout/pull/1813) - Add total blocks counter to the main page
- [#1806](https://github.com/blockscout/blockscout/pull/1806) - Verify contracts with a post request
- [#1848](https://github.com/blockscout/blockscout/pull/1848) - Add cache for block counter

### Fixes

- [#1829](https://github.com/blockscout/blockscout/pull/1829) - Handle nil quantities in block decoding routine
- [#1830](https://github.com/blockscout/blockscout/pull/1830) - Make block size field nullable
- [#1840](https://github.com/blockscout/blockscout/pull/1840) - Handle case when total supply is nil
- [#1838](https://github.com/blockscout/blockscout/pull/1838) - Block counter calculates only consensus blocks

### Chore

- [#1814](https://github.com/blockscout/blockscout/pull/1814) - Clear build artifacts script
- [#1837](https://github.com/blockscout/blockscout/pull/1837) - Add -f flag to clear_build.sh script delete static folder

## 1.3.10-beta

### Features

- [#1739](https://github.com/blockscout/blockscout/pull/1739) - highlight decompiled source code
- [#1696](https://github.com/blockscout/blockscout/pull/1696) - full-text search by tokens
- [#1742](https://github.com/blockscout/blockscout/pull/1742) - Support RSK
- [#1777](https://github.com/blockscout/blockscout/pull/1777) - show ERC-20 token transfer info on transaction page
- [#1770](https://github.com/blockscout/blockscout/pull/1770) - set a websocket keepalive from config
- [#1789](https://github.com/blockscout/blockscout/pull/1789) - add ERC-721 info to transaction overview page
- [#1801](https://github.com/blockscout/blockscout/pull/1801) - Staking pools fetching

### Fixes

- [#1724](https://github.com/blockscout/blockscout/pull/1724) - Remove internal tx and token balance fetching from realtime fetcher
- [#1727](https://github.com/blockscout/blockscout/pull/1727) - add logs pagination in rpc api
- [#1740](https://github.com/blockscout/blockscout/pull/1740) - fix empty block time
- [#1743](https://github.com/blockscout/blockscout/pull/1743) - sort decompiled smart contracts in lexicographical order
- [#1756](https://github.com/blockscout/blockscout/pull/1756) - add today's token balance from the previous value
- [#1769](https://github.com/blockscout/blockscout/pull/1769) - add timestamp to block overview
- [#1768](https://github.com/blockscout/blockscout/pull/1768) - fix first block parameter
- [#1778](https://github.com/blockscout/blockscout/pull/1778) - Make websocket optional for realtime fetcher
- [#1790](https://github.com/blockscout/blockscout/pull/1790) - fix constructor arguments verification
- [#1793](https://github.com/blockscout/blockscout/pull/1793) - fix top nav autocomplete
- [#1795](https://github.com/blockscout/blockscout/pull/1795) - fix line numbers for decompiled contracts
- [#1803](https://github.com/blockscout/blockscout/pull/1803) - use coinmarketcap for total_supply by default
- [#1802](https://github.com/blockscout/blockscout/pull/1802) - make coinmarketcap's number of pages configurable
- [#1799](https://github.com/blockscout/blockscout/pull/1799) - Use eth_getUncleByBlockHashAndIndex for uncle block fetching
- [#1531](https://github.com/blockscout/blockscout/pull/1531) - docker: fix dockerFile for secp256k1 building
- [#1835](https://github.com/blockscout/blockscout/pull/1835) - fix: ignore `pong` messages without error

### Chore

- [#1804](https://github.com/blockscout/blockscout/pull/1804) - (Chore) Divide chains by Mainnet/Testnet in menu
- [#1783](https://github.com/blockscout/blockscout/pull/1783) - Update README with the chains that use Blockscout
- [#1780](https://github.com/blockscout/blockscout/pull/1780) - Update link to the Github repo in the footer
- [#1757](https://github.com/blockscout/blockscout/pull/1757) - Change twitter acc link to official Blockscout acc twitter
- [#1749](https://github.com/blockscout/blockscout/pull/1749) - Replace the link in the footer with the official POA announcements tg channel link
- [#1718](https://github.com/blockscout/blockscout/pull/1718) - Flatten indexer module hierarchy and supervisor tree
- [#1753](https://github.com/blockscout/blockscout/pull/1753) - Add a check mark to decompiled contract tab
- [#1744](https://github.com/blockscout/blockscout/pull/1744) - remove `0x0..0` from tests
- [#1763](https://github.com/blockscout/blockscout/pull/1763) - Describe indexer structure and list existing fetchers
- [#1800](https://github.com/blockscout/blockscout/pull/1800) - Disable lazy logging check in Credo

## 1.3.9-beta

### Features

- [#1662](https://github.com/blockscout/blockscout/pull/1662) - allow specifying number of optimization runs
- [#1654](https://github.com/blockscout/blockscout/pull/1654) - add decompiled code tab
- [#1661](https://github.com/blockscout/blockscout/pull/1661) - try to compile smart contract with the latest evm version
- [#1665](https://github.com/blockscout/blockscout/pull/1665) - Add contract verification RPC endpoint.
- [#1706](https://github.com/blockscout/blockscout/pull/1706) - allow setting update interval for addresses with b

### Fixes

- [#1669](https://github.com/blockscout/blockscout/pull/1669) - do not fail if multiple matching tokens are found
- [#1691](https://github.com/blockscout/blockscout/pull/1691) - decrease token metadata update interval
- [#1688](https://github.com/blockscout/blockscout/pull/1688) - do not fail if failure reason is atom
- [#1692](https://github.com/blockscout/blockscout/pull/1692) - exclude decompiled smart contract from encoding
- [#1684](https://github.com/blockscout/blockscout/pull/1684) - Discard child block with parent_hash not matching hash of imported block
- [#1699](https://github.com/blockscout/blockscout/pull/1699) - use seconds as transaction cache period measure
- [#1697](https://github.com/blockscout/blockscout/pull/1697) - fix failing in rpc if balance is empty
- [#1711](https://github.com/blockscout/blockscout/pull/1711) - rescue failing repo in block number cache update
- [#1712](https://github.com/blockscout/blockscout/pull/1712) - do not set contract code from transaction input
- [#1714](https://github.com/blockscout/blockscout/pull/1714) - fix average block time calculation

### Chore

- [#1693](https://github.com/blockscout/blockscout/pull/1693) - Add a checklist to the PR template

## 1.3.8-beta

### Features

- [#1611](https://github.com/blockscout/blockscout/pull/1611) - allow setting the first indexing block
- [#1596](https://github.com/blockscout/blockscout/pull/1596) - add endpoint to create decompiled contracts
- [#1634](https://github.com/blockscout/blockscout/pull/1634) - add transaction count cache

### Fixes

- [#1630](https://github.com/blockscout/blockscout/pull/1630) - (Fix) color for release link in the footer
- [#1621](https://github.com/blockscout/blockscout/pull/1621) - Modify query to fetch failed contract creations
- [#1614](https://github.com/blockscout/blockscout/pull/1614) - Do not fetch burn address token balance
- [#1639](https://github.com/blockscout/blockscout/pull/1614) - Optimize token holder count updates when importing address current balances
- [#1643](https://github.com/blockscout/blockscout/pull/1643) - Set internal_transactions_indexed_at for empty blocks
- [#1647](https://github.com/blockscout/blockscout/pull/1647) - Fix typo in view
- [#1650](https://github.com/blockscout/blockscout/pull/1650) - Add petersburg evm version to smart contract verifier
- [#1657](https://github.com/blockscout/blockscout/pull/1657) - Force consensus loss for parent block if its hash mismatches parent_hash

### Chore

## 1.3.7-beta

### Features

### Fixes

- [#1615](https://github.com/blockscout/blockscout/pull/1615) - Add more logging to code fixer process
- [#1613](https://github.com/blockscout/blockscout/pull/1613) - Fix USD fee value
- [#1577](https://github.com/blockscout/blockscout/pull/1577) - Add process to fix contract with code
- [#1583](https://github.com/blockscout/blockscout/pull/1583) - Chunk JSON-RPC batches in case connection times out

### Chore

- [#1610](https://github.com/blockscout/blockscout/pull/1610) - Add PIRL to Readme

## 1.3.6-beta

### Features

- [#1589](https://github.com/blockscout/blockscout/pull/1589) - RPC endpoint to list addresses
- [#1567](https://github.com/blockscout/blockscout/pull/1567) - Allow setting different configuration just for realtime fetcher
- [#1562](https://github.com/blockscout/blockscout/pull/1562) - Add incoming transactions count to contract view
- [#1608](https://github.com/blockscout/blockscout/pull/1608) - Add listcontracts RPC Endpoint

### Fixes

- [#1595](https://github.com/blockscout/blockscout/pull/1595) - Reduce block_rewards in the catchup fetcher
- [#1590](https://github.com/blockscout/blockscout/pull/1590) - Added guard for fetching blocks with invalid number
- [#1588](https://github.com/blockscout/blockscout/pull/1588) - Fix usd value on address page
- [#1586](https://github.com/blockscout/blockscout/pull/1586) - Exact timestamp display
- [#1581](https://github.com/blockscout/blockscout/pull/1581) - Consider `creates` param when fetching transactions
- [#1559](https://github.com/blockscout/blockscout/pull/1559) - Change v column type for Transactions table

### Chore

- [#1579](https://github.com/blockscout/blockscout/pull/1579) - Add SpringChain to the list of Additional Chains Utilizing BlockScout
- [#1578](https://github.com/blockscout/blockscout/pull/1578) - Refine contributing procedure
- [#1572](https://github.com/blockscout/blockscout/pull/1572) - Add option to disable block rewards in indexer config

## 1.3.5-beta

### Features

- [#1560](https://github.com/blockscout/blockscout/pull/1560) - Allow executing smart contract functions in arbitrarily sized batches
- [#1543](https://github.com/blockscout/blockscout/pull/1543) - Use trace_replayBlockTransactions API for faster tracing
- [#1558](https://github.com/blockscout/blockscout/pull/1558) - Allow searching by token symbol
- [#1551](https://github.com/blockscout/blockscout/pull/1551) Exact date and time for Transaction details page
- [#1547](https://github.com/blockscout/blockscout/pull/1547) - Verify smart contracts with evm versions
- [#1540](https://github.com/blockscout/blockscout/pull/1540) - Fetch ERC721 token balances if sender is '0x0..0'
- [#1539](https://github.com/blockscout/blockscout/pull/1539) - Add the link to release in the footer
- [#1519](https://github.com/blockscout/blockscout/pull/1519) - Create contract methods
- [#1496](https://github.com/blockscout/blockscout/pull/1496) - Remove dropped/replaced transactions in pending transactions list
- [#1492](https://github.com/blockscout/blockscout/pull/1492) - Disable usd value for an empty exchange rate
- [#1466](https://github.com/blockscout/blockscout/pull/1466) - Decoding candidates for unverified contracts

### Fixes

- [#1545](https://github.com/blockscout/blockscout/pull/1545) - Fix scheduling of latest block polling in Realtime Fetcher
- [#1554](https://github.com/blockscout/blockscout/pull/1554) - Encode integer parameters when calling smart contract functions
- [#1537](https://github.com/blockscout/blockscout/pull/1537) - Fix test that depended on date
- [#1534](https://github.com/blockscout/blockscout/pull/1534) - Render a nicer error when creator cannot be determined
- [#1527](https://github.com/blockscout/blockscout/pull/1527) - Add index to value_fetched_at
- [#1518](https://github.com/blockscout/blockscout/pull/1518) - Select only distinct failed transactions
- [#1516](https://github.com/blockscout/blockscout/pull/1516) - Fix coin balance params reducer for pending transaction
- [#1511](https://github.com/blockscout/blockscout/pull/1511) - Set correct log level for production
- [#1510](https://github.com/blockscout/blockscout/pull/1510) - Fix test that fails every 1st day of the month
- [#1509](https://github.com/blockscout/blockscout/pull/1509) - Add index to blocks' consensus
- [#1508](https://github.com/blockscout/blockscout/pull/1508) - Remove duplicated indexes
- [#1505](https://github.com/blockscout/blockscout/pull/1505) - Use https instead of ssh for absinthe libs
- [#1501](https://github.com/blockscout/blockscout/pull/1501) - Constructor_arguments must be type `text`
- [#1498](https://github.com/blockscout/blockscout/pull/1498) - Add index for created_contract_address_hash in transactions
- [#1493](https://github.com/blockscout/blockscout/pull/1493) - Do not do work in process initialization
- [#1487](https://github.com/blockscout/blockscout/pull/1487) - Limit geth sync to 128 blocks
- [#1484](https://github.com/blockscout/blockscout/pull/1484) - Allow decoding input as utf-8
- [#1479](https://github.com/blockscout/blockscout/pull/1479) - Remove smoothing from coin balance chart

### Chore

- [https://github.com/blockscout/blockscout/pull/1532](https://github.com/blockscout/blockscout/pull/1532) - Upgrade elixir to 1.8.1
- [https://github.com/blockscout/blockscout/pull/1553](https://github.com/blockscout/blockscout/pull/1553) - Dockerfile: remove 1.7.1 version pin FROM bitwalker/alpine-elixir-phoenix
- [https://github.com/blockscout/blockscout/pull/1465](https://github.com/blockscout/blockscout/pull/1465) - Resolve lodash security alert
