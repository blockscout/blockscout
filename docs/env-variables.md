# BlockScout Env Variables

Below is a table outlining the environment variables utilized by BlockScout.

**Notes:**
- This table is horizontally scrollable, version information is located in the last column.
- Settings related to the `ETHEREUM_JSONRPC_VARIANT` variable and client related settings for running a full archive node with geth or parity are located in [this forum post](https://forum.poa.network/t/faq-what-settings-are-required-on-a-parity-or-geth-client/1805).
- Additional information related to certain variables is available on the [ansible deployment](ansible-deployment.md) page.
- To set variables using the CLI, use the export command. For example:
```bash
$ export ETHEREUM_JSONRPC_VARIANT=parity
$ export COIN=POA
$ export NETWORK=POA
```


| Variable | Required | Description | Default | Version | Need recompile | Deprecated in Version |
| --- | --- | --- | ---| --- | --- | --- |
| `NETWORK`| :white_check_mark:  | Environment variable for the main EVM network such as Ethereum Network or POA Network | POA Network | all | | |
| `SUBNETWORK` | :white_check_mark: | Environment variable for the subnetwork such as Core or Sokol Network | Sokol Testnet | all | | |
| `NETWORK_ICON` | :white_check_mark: | Environment variable for the main network icon or testnet icon. Two options are  `_test_network_icon.html` and `_network_icon.html` | `_test_network_icon.html` | all | | |
| `LOGO` | :white_check_mark: | Environment variable for the logo image location. The logo files names for different chains can be found [here](https://github.com/poanetwork/blockscout/tree/master/apps/block_scout_web/assets/static/images) | /images/blockscout_logo.svg | all | | |
| `ETHEREUM_JSONRPC_VARIANT` | :white_check_mark: | This environment variable is used to tell the application which RPC Client the node is using (i.e. Geth, Parity, or Ganache) | parity | all | | |
| `ETHEREUM_JSONRPC_HTTP_URL` | :white_check_mark: | The RPC endpoint used to fetch blocks, transactions, receipts, tokens. | localhost:8545 | all | | |
| `ETHEREUM_JSONRPC_TRACE_URL` | | The RPC endpoint specifically for the Geth/Parity client used by trace_block and trace_replayTransaction. This can be used to designate a tracing node. | localhost:8545 | all | | |
| `ETHEREUM_JSONRPC_WS_URL` | :white_check_mark: | The WebSockets RPC endpoint used to subscribe to the `newHeads` subscription alerting the indexer to fetch new blocks. | ws://localhost:8546 | all | | |
| `NETWORK_PATH` | | Used to set a network path other than what is displayed in the root directory. An example would be to add /eth/mainnet/ to the root directory. | (empty) | all | | |
| `SECRET_KEY_BASE` | :white_check_mark: | Use mix phx.gen.secret to generate a new Secret Key Base string to protect production assets. | (empty) | all | | |
| `CHECK_ORIGIN` | | Used to check the origin of requests when the origin header is present. It defaults to false. In case of true, it will check against the host value. | false | all | | |
| `PORT` | :white_check_mark: | Default port the application runs on is 4000 | 4000 | all | | |
| `COIN` | :white_check_mark: | The coin here is checked via the CoinGecko API to obtain USD prices on graphs and other areas of the UI | POA | all | | |
| `METADATA_CONTRACT` | | This environment variable is specifically used by POA Network to obtain Validators information to display in the UI. | (empty) | all | | |
| `VALIDATORS_CONTRACT` | | This environment variable is specifically used by POA Network to obtain the Emission Fund contract. | (empty) | all | | |
| `SUPPLY_MODULE` | | This environment variable is used by the xDai Chain in order to tell the application how to calculate the total supply of the chain. | false | all | | |
| `SOURCE_MODULE` | | This environment variable is used to calculate the exchange rate and is specifically used by the xDai Chain. | false | all | | |
| `DATABASE_URL` | | Production environment variable to define the Database endpoint. | (empty) | all | | |
| `POOL_SIZE` | | Production environment variable to define the number of database connections allowed. | 20 | all | | |
| `ECTO_USE_SSL` | | Production environment variable to use SSL on Ecto queries. | true | all | | |
| `DATADOG_HOST` | | Host configuration setting for [Datadog integration](https://docs.datadoghq.com/integrations/) | (empty) | all | | |
| `DATADOG_PORT` | | Port configuration setting for [Datadog integration](https://docs.datadoghq.com/integrations/). | (empty} | all | | |
| `SPANDEX_BATCH_SIZE` | | [Spandex](https://github.com/spandex-project/spandex) and Datadog configuration setting. | (empty) | all | |
| `SPANDEX_SYNC_THRESHOLD` | | [Spandex](https://github.com/spandex-project/spandex) and Datadog configuration setting.  | (empty) | all | | |
| `HEART_BEAT_TIMEOUT` | | Production environment variable to restart the application in the event of a crash. | 30 | all | | |
| `HEART_COMMAND` | | Production environment variable to restart the application in the event of a crash. | systemctl restart explorer.service | all | | |
| `BLOCKSCOUT_VERSION` | | Added to the footer to signify the current BlockScout version. | (empty) | v1.3.4+ | | |
| `RELEASE_LINK` | | The link to Blockscout release notes in the footer. | <u>https: //github.com/poanetwork/</u> <br /><u>blockscout/releases/</u> <br /> <u>tag/${BLOCKSCOUT_VERSION}</u> | v1.3.5+ | | |
| `ELIXIR_VERSION` | | Elixir version to install on the node before Blockscout deploy. | (empty) | all | | |
| `BLOCK_TRANSFORMER` | | Transformer for blocks: base or clique. | base |  v1.3.4+ | | |
| `GRAPHIQL_TRANSACTION` | | Default transaction in query to GraphiQL. | (empty) |  v1.2.0+ | :white_check_mark: | |
| `FIRST_BLOCK` | | The block number, where indexing begins from. | 0 |  v1.3.8+ | | |
| `LAST_BLOCK` | | The block number, where indexing stops. | (empty) | v2.0.3+ | | |
| `TXS_COUNT_CACHE_PERIOD` | | Interval in seconds to restart the task, which calculates the total txs count. | 60 * 60 * 2 |  v1.3.9+ | | |
| `ADDRESS_WITH_BALANCES` <br /> `_UPDATE_INTERVAL`|  | Interval in seconds to restart the task, which calculates addresses with balances. | 30 * 60 |  v1.3.9+ | | |
| `LINK_TO_OTHER_EXPLORERS` | | true/false. If true, links to other explorers are added in the footer  | (empty)  |  v1.3.0+ | | |
| `COINMARKETCAP_PAGES` | | the number of pages on coinmarketcap to list in order to find token's price  | 10 |  v1.3.10+ | | v2.0.4 |
| `SUPPORTED_CHAINS` | | Array of supported chains that displays in the footer and in the chains dropdown. This var was introduced in this PR [#1900](https://github.com/poanetwork/blockscout/pull/1900) and looks like an array of JSON objects.  | (empty) |  v2.0.0+ | | |
| `BLOCK_COUNT_CACHE_PERIOD ` | | time to live of cache in seconds. This var was introduced in [#1876](https://github.com/poanetwork/blockscout/pull/1876)  | 600 |  v2.0.0+ | | |
| `ALLOWED_EVM_VERSIONS ` | | the comma-separated list of allowed EVM versions for contracts verification. This var was introduced in [#1964](https://github.com/poanetwork/blockscout/pull/1964)  | "homestead, tangerineWhistle, spuriousDragon, byzantium, constantinople, petersburg" |  v2.0.0+ | | |
| `UNCLES_IN_AVERAGE_BLOCK_TIME` | Include or exclude nonconsensus blocks in avg block time calculation. Exclude if `false`. | false | v2.0.1+ | | |
| `AVERAGE_BLOCK_CACHE_PERIOD` | | Update of average block cache, in seconds | 30 minutes | v2.0.2+ | |
| `MARKET_HISTORY_CACHE_PERIOD` | | Update of market history cache, in seconds | 6 hours | v2.0.2+ | |
| `DISABLE_WEBAPP` | | If `true`, endpoints to webapp are hidden (compile-time) | `false` | v2.0.3+ | :white_check_mark: | |
| `DISABLE_READ_API` | | If `true`, read-only endpoints to API are hidden (compile-time) | `false` | v2.0.3+ | :white_check_mark: | |
| `DISABLE_WRITE_API` | | If `true`, write endpoints to API are hidden (compile-time) | `false` | v2.0.3+ | :white_check_mark: | |
| `DISABLE_INDEXER` | | If `true`, indexer application doesn't run | `false` | v2.0.3+ | :white_check_mark: | |
| `WEBAPP_URL` | | Link to web application instance, e.g. `http://host/path` | (empty) | v2.0.3+ | | |
| `API_URL` | | Link to API instance, e.g. `http://host/path` | (empty) | v2.0.3+ | | |
| `CHAIN_SPEC_PATH` | | Chain specification path (absolute file system path or url) to import block emission reward ranges and genesis account balances from | (empty) | v2.0.4+ | | |
| `COIN_GECKO_ID` | | CoinGecko coin id required for fetching an exchange rate | poa-network | v2.0.4+ | | master |
| `EMISSION_FORMAT` | | Should be set to `POA` if you have block emission indentical to POA Network. This env var is used only if `CHAIN_SPEC_PATH` is set | `STANDARD` | v2.0.4+ | | |
| `REWARDS_CONTRACT_ADDRESS` | | Emission rewards contract address. This env var is used only if `EMISSION_FORMAT` is set to `POA` | `0xeca443e8e1ab29971a45a9c57a6a9875701698a5` | v2.0.4+ | | |
| `INTERNAL_TRANSACTIONOS_FOR_TOKEN_TRANSFERS` | | Does not applicable for parity because we fetch all transactions for it. If set to true fetches internal transactions for simple token transfers transactions. It's disabled by default to increase internal transactions indexing speed | `false` | master | | |
| `BLOCKSCOUT_PROTOCOL` | | Url scheme for blockscout | in prod env `https` is used, in dev env `http` is used | master | | |
| `MAX_SKIPPING_DISTANCE` | | The maximum distance the indexer is allowed to wait for when notified of a number not following the lask known one. | 4 | master | |
| `POS_STAKING_CONTRACT` | | The address of POSDAO staking contract. When provided, enables staking DApp. ValidatorSet and BlockReward contract addresses are fetched using corresponding getters. | (empty) | v2.0.5+ | :white_check_mark: | |