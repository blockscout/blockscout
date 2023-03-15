# ChangeLog

## Current

### Features

- [#7068](https://github.com/blockscout/blockscout/pull/7068) - Add authenticate endpoint
- [#6990](https://github.com/blockscout/blockscout/pull/6990) - Improved http requests logging, batch transfers pagination; New API v2 endpoint `/smart-contracts/counters`; And some refactoring

### Fixes

- [#7062](https://github.com/blockscout/blockscout/pull/7062) - Save block count in the DB when calculated in Cache module
- [#7008](https://github.com/blockscout/blockscout/pull/7008) - Fetch image/video content from IPFS link
- [#7007](https://github.com/blockscout/blockscout/pull/7007), [#7031](https://github.com/blockscout/blockscout/pull/7031), [#7058](https://github.com/blockscout/blockscout/pull/7058), [#7061](https://github.com/blockscout/blockscout/pull/7061), [#7067](https://github.com/blockscout/blockscout/pull/7067) - Token instance fetcher fixes
- [#7009](https://github.com/blockscout/blockscout/pull/7009) - Fix updating coin balances with empty value
- [#7055](https://github.com/blockscout/blockscout/pull/7055) - Set updated_at on token update even if there are no changes
- [#7080](https://github.com/blockscout/blockscout/pull/7080) - Deduplicate second degree relations before insert

### Chore

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

- [#6699](https://github.com/blockscout/blockscout/pull/6699) - L1 tx fields fix for Goerli Optimism BedRock update
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
- [#4699](https://github.com/blockscout/blockscout/pull/4699), [#4793](https://github.com/blockscout/blockscout/pull/4793), [#4820](https://github.com/blockscout/blockscout/pull/4820), [#4827](https://github.com/blockscout/blockscout/pull/4827) - Address page facelifting
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
- [#4475](https://github.com/blockscout/blockscout/pull/4475) - Tx page facelifting
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
- [#3585](https://github.com/blockscout/blockscout/pull/3585) - Add autoswitching from eth_subscribe to eth_blockNumber in Staking DApp
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
- [#3235](https://github.com/blockscout/blockscout/pull/3235) - Fix coin supply api edpoint
- [#3233](https://github.com/blockscout/blockscout/pull/3233) - Fix for the contract verifiaction for solc 0.5 family with experimental features enabled
- [#3231](https://github.com/blockscout/blockscout/pull/3231) - Improve search: unlimited number of searching results
- [#3231](https://github.com/blockscout/blockscout/pull/3231) - Improve search: allow search with space
- [#3231](https://github.com/blockscout/blockscout/pull/3231) - Improve search: order by token holders in descending order and token/contract name is ascending order
- [#3226](https://github.com/blockscout/blockscout/pull/3226) - Fix notifier query for live update of token transfers
- [#3220](https://github.com/blockscout/blockscout/pull/3220) - Allow interaction with navbar menu at block-not-found page

### Chore

- [#3326](https://github.com/blockscout/blockscout/pull/3326) - Chart smooth lines
- [#3250](https://github.com/blockscout/blockscout/pull/3250) - Eliminate occurrences of obsolete env variable ETHEREUM_JSONRPC_JSON_RPC_TRANSPORT
- [#3240](https://github.com/blockscout/blockscout/pull/3240), [#3251](https://github.com/blockscout/blockscout/pull/3251) - various CSS imroving
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
- [#2581](https://github.com/blockscout/blockscout/pull/2581) - Add generic Map-like Cache behaviour and implementation
- [#2561](https://github.com/blockscout/blockscout/pull/2561) - Add token's type to the response of tokenlist method
- [#2555](https://github.com/blockscout/blockscout/pull/2555) - find and show decoding candidates for logs
- [#2499](https://github.com/blockscout/blockscout/pull/2499) - import emission reward ranges
- [#2497](https://github.com/blockscout/blockscout/pull/2497) - Add generic Ordered Cache behaviour and implementation

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
- [#2590](https://github.com/blockscout/blockscout/pull/2590) - restore backward compatablity with old releases
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
- [#2549](https://github.com/blockscout/blockscout/pull/2549) - Fix wrong colour of tooltip
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

- [#2127](https://github.com/blockscout/blockscout/pull/2127) - use previouse chromedriver version
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
- [#1896](https://github.com/blockscout/blockscout/pull/1896) - re-query tokens in top nav automplete
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

- [#1630](https://github.com/blockscout/blockscout/pull/1630) - (Fix) colour for release link in the footer
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
