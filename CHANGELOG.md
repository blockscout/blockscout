# ChangeLog

## Current

### 🚀 Features

- Super-mega-important-feature

### 🐛 Bug Fixes

- Super mega important fix

### ⚙️ Miscellaneous Tasks

- Bump floki from 0.36.0 to 0.36.1 ([#9685](https://github.com/blockscout/blockscout/issues/9685))
- Bump floki from 0.36.0 to 0.36.1 ([#9684](https://github.com/blockscout/blockscout/issues/9684))
- Bump floki from 0.36.0 to 0.36.1 ([#9683](https://github.com/blockscout/blockscout/issues/9683))
- Something fixed

## [6.3.0-beta] - 2024-03-18

### 🚀 Features

- Stream blocks without internal transactions backwards

### 🐛 Bug Fixes

- Fix zero balances coming via WS ([#9510](https://github.com/blockscout/blockscout/issues/9510))


- Fix infinite retries for orphaned blobs ([#9620](https://github.com/blockscout/blockscout/issues/9620))

* fix: implement finite retries for orphaned blobs

* chore: changelog
- Fix fetch_coin_balance query to compare between balances with values ([#9638](https://github.com/blockscout/blockscout/issues/9638))

* Fix fetch_coin_balance query to compare between balances with non-nil values

* Review fix
- Fix no function clause matching in BENS.item_to_address_hash_strings/1 ([#9640](https://github.com/blockscout/blockscout/issues/9640))


- Fix typos in CHANGELOG

- Fix skipped read methods ([#9621](https://github.com/blockscout/blockscout/issues/9621))

* Bump ex_abi from 0.7.0 to 0.7.1

* Add regression test for function ABI missing `outputs` field
- Fix Geth block internal transactions fetching

- Fix logging

- Fix token instance transform panic ([#9601](https://github.com/blockscout/blockscout/issues/9601))

* fix: token instance transform panic

* chore: changelog
- Fix duplicate read methods ([#9591](https://github.com/blockscout/blockscout/issues/9591))

* Fix the typo in docs

* Fix duplicated results in `methods-read` endpoint

* Add regression test ensuring read-methods are not duplicated

* Update `CHANGELOG.md`
- Fix MultipleResultsError in smart_contract_creation_tx_bytecode/1

- Fix case for less 20 bytes in response

- Fix EIP-1967 beacon proxy pattern detection

- Fix format and cspell tests

- Fix timestamp handler for unfinalized zkEVM batches

- Fix get_blocks_by_events function

- Fix missing `0x` prefix in `eth_getLogs` response  ([#9514](https://github.com/blockscout/blockscout/issues/9514))

* Remove `transactionLogIndex` from `eth_getLogs` response

* Fix missing `0x` prefix for `blockNumber`, `logIndex`, `transactionIndex` in `eth_getLogs` response

* Fix logs pagination test

* Fix docs for `index` field in chain log

* Update smart contract ABI wiki link

* Add regression test for missing `0x` in `eth_getLogs`

### 🚜 Refactor

- Refactoring


### 📚 Documentation

- Docker-compose 2.24.6 compatibility


### ⚙️ Miscellaneous Tasks

- Fix some comments
- Remove repetitive words
- Changelog

## [6.2.1-beta] - 2024-02-29

### 🐛 Bug Fixes

- Fix no function clause matching in Integer.parse/2 ([#9484](https://github.com/blockscout/blockscout/issues/9484))

* Fix no function clause matching in Integer.parse/2

* Changelog
- Fix tabs counter cache bug

- Not found page for unknown blobs

### ⚙️ Miscellaneous Tasks

- Changelog

## [6.2.0-beta] - 2024-02-28

### 🚀 Features

- Blobs in search
- Add burn blob fee in tx view
- Add basic blob fetcher tests
- Add blobs fetcher
- Blobs migrations and api

### 🐛 Bug Fixes

- Fix Noves.fi endpoint

- Fix Noves.fi endpoints

- Fix parsing contract creation

- Fix index definition

- Fix quick search bug

- Fix outdated deps cache in CI ([#9398](https://github.com/blockscout/blockscout/issues/9398))

* chore: try with --skip-umbrella-children

* chore: try with double caching

* chore: revert to single cache

* chore: changelog
- Fix Shibarium workflow name

- Fix spelling

- Fixes for Chain.import related to CHAIN_TYPE

- Fixes after rebase

- Fix Explorer.Chain.Import.Runner.Zkevm.BridgeOperations

- Fix operation type

- Fix using of startblock/endblock in API v1 list endpoints: txlist, txlistinternal, tokentx ([#9364](https://github.com/blockscout/blockscout/issues/9364))

* Fix using of startblock/endblock in API v1 list endpoints: txlist, txlistinternal, tokentx

* Add CHANGELOG entry
- Fix tests

- Fix typo
- Fix typos
- Linter
- Transaction blobs order in API
- More review comments
- Too many connections in tests
- One more test
- Tests
- Hide doctest behind chain type
- Fmt
- Review refactor
- Fmt and test config
- Tests
- Format
- Fix read contract bug ([#9300](https://github.com/blockscout/blockscout/issues/9300))

* Fix read contract bug

* Changelog
- Fix manual uncle reward calculation

- Fix dialyzer and add TypedEctoSchema

- Fixing stats DB connection vars


### 🚜 Refactor

- Refactoring, cover with tests

- Refactor token transfers migration name

- Refactor weth transfers sanitizing

Co-authored-by: nikitosing <32202610+nikitosing@users.noreply.github.com>
- Refactor Indexer.Block.Fetcher

- Refactoring

- Refactor Indexer.Fetcher.Zkevm.BridgeL1


### ⚙️ Miscellaneous Tasks

- Bump actions/cache to v4 ([#9393](https://github.com/blockscout/blockscout/issues/9393))
- Move blob function out of chain.ex
- Update env defaults
- Try to fix connection timeout
- Update default values
- Docstrings and broken tests
- Refactor

## [6.1.0-beta] - 2024-02-05

### 🐛 Bug Fixes

- Fix Blockscout version in pre-release workflow

- Fix getblockreward; Add getblockcountdown actions

- Fix pending transactions sanitizer ([#9261](https://github.com/blockscout/blockscout/issues/9261))

* Fix pending transactions sanitizer

* Add block consensus filters to list_transactions and list_token_transfers
- Fix 500 response on token id which is not in DB ([#9187](https://github.com/blockscout/blockscout/issues/9187))

* Fix Internal Server Error on request for nonexistent token instance

* Add spec and doc
- Fix log decoding bug ([#9241](https://github.com/blockscout/blockscout/issues/9241))

* Fix log decoding bug

* Add regression test

* Process review comment
- Fix flickering test

- Fix bug with match error; Add sorting before broadcasting updated token balances

- Fix reviewer comments

- Fix common-blockscout.env
- Fix typo

- Fix typo

- Fix typo

- Fix Explorer.Chain.Cache.GasPriceOracle.merge_fees

- Fix some log topics for Suave and Polygon Edge


### ⚙️ Miscellaneous Tasks

- Equalize elixir stack versions

## [6.0.0-beta] - 2024-01-08

### 🐛 Bug Fixes

- Fix migration_finished? logic

- Fix migration status upsert

- Fix suffix in Blockscout version in prerelease workflow

- Fix comment

- Fix token_transfers bug

- Fix bens variables to snake_case and change from POST to GET


### 🚜 Refactor

- Refactoring


## [5.4.0-beta] - 2023-12-22

### 🐛 Bug Fixes

- Fix tests

- Fix gettext

- Fix tx input decoding in tx summary microservice request

- Fix after review

- Fix after review

- Fix review comments; Fix txransaction actions preload


### 🚜 Refactor

- Refactor transactions event preloads


## [5.3.3-beta] - 2023-12-11

### 🐛 Bug Fixes

- Fix microservices.yml docker-compose stats cors issue

- Fix method decoding by candidates

- Fix native coin exchange rate

- Fix CI

- Fix abi encoded string argument

- Fix reviewer comments

- Fix order of proxy standards: 1167, 1967


## [5.3.2-beta] - 2023-11-28

### 🐛 Bug Fixes

- Fix average block time

- Fix tests

- Fix tests after rebasing

- Fix cycle of rootstock fetcher

[no ci]

- Fix after review; Add test

- Fix for eth_getbalance API v1 endpoint when requesting latest tag

- Fix Indexer.Transform.Addresses for non-Suave setup ([#8784](https://github.com/blockscout/blockscout/issues/8784))

* Fix Indexer.Transform.Addresses for non-Suave setup

* Update changelog

* Fix bin/install_chrome_headless.sh

* Fix bin/install_chrome_headless.sh

* Rename Explorer.Token.MetadataRetrieverTest

* Reset GA cache

* Fix test in InstanceMetadataRetrieverTest

---------

Co-authored-by: POA <33550681+poa@users.noreply.github.com>
Co-authored-by: Viktor Baranov <baranov.viktor.27@gmail.com>
- Fix for tvl update in market history when row already exists

- Fix internal transaction error

- Fix flaky account notifier test ([#8724](https://github.com/blockscout/blockscout/issues/8724))

* Fix flaky account notifier test

* Update CHANGELOG.md
- Fix CHANGELOG


## [5.3.1-beta] - 2023-10-26

### 🐛 Bug Fixes

- Fix sourcify check ([#8714](https://github.com/blockscout/blockscout/issues/8714))

* Fix sourcify check

* Changelog
- Fix sourcify enabled flag ([#8705](https://github.com/blockscout/blockscout/issues/8705))

* Fix sourcify enabled flag

* Changelog
- Fix transaction_controller.ex

- Fix for zkEVM websocket connection

- Fixes after rebase

- Fix repos list definition in releases_tasks

- Fix config/runtime.exs

- Fix syntax

- Fix for dialyzer

- Fix is_verified for /addresses and /smart-contracts

- Fix db pool size exceeds Postgres max connections


### 🚜 Refactor

- Refactor Indexer.Fetcher.ZkevmTxnBatch


## [5.3.0-beta] - 2023-10-20

### 🐛 Bug Fixes

- Fix TokenBalance fetcher retry logic

- Fix polygon tracer

- Fix typos

- Fix empty tvl in /stats page

- Fix NEXT_PUBLIC_API_SPEC_URL in common-frontend.env

- Fix css-loader

- Fix nil structLogs

- Fix issue template filling

- Fix issue template

- Fix empty TransferBatch event handling ([#7959](https://github.com/blockscout/blockscout/issues/7959))

* Fix empty TransferBatch event handling

* changelog

* format

* migration

* fixed changelog

---------

Co-authored-by: Victor Baranov <baranov.viktor.27@gmail.com>

### 🚜 Refactor

- Refactor parsing of FIRST_BLOCK, LAST_BLOCK, TRACE_FIRST_BLOCK, TRACE_LAST_BLOCK env variables

- Refactor docker-compose config: add DB healthcheck, run DB via non-root user


## [5.2.3-beta] - 2023-09-20

### 🐛 Bug Fixes

- Fix arm docker image build

- Fix reorg transactions

- Fix reorgs query

- Fix market cap calculation in case of CMC

- Fix contracts' output decoding

- Fix market cap in /stats endpoint

- Fix errors in some variables in the file docker-compose/envs/common-frontend.env

- Fix current token balances redefining

- Fix hackney options

- Fixing visualizer CORS issue in docker-compose


### 🚜 Refactor

- Refactor zip_tuple_values_with_types/2

- Refactor zip_tuple_values_with_types/2

- Refactor and fix paging params in API v2


## [5.2.2-beta] - 2023-08-17

### 🐛 Bug Fixes

- Fix API v2 broken tx response

- Fix missing range insert

- Fix explorer tests

- Fix Dockerfile build
- Fix docker-compose with new frontend Auth0 path

- Fix Rootstock charts API

- Fix eth_getLogs API endpoint


### 🚜 Refactor

- Refactor address counter functions


### 📚 Documentation

- Docker-compose for new UI with external backend

- Docker-compose-nginx.yml add extra_hosts


## [5.2.1-beta] - 2023-07-20

### 🐛 Bug Fixes

- Fixed wrong TX url in email notifications for mainnet ([#7951](https://github.com/blockscout/blockscout/issues/7951))

* Fixed wrong TX url in email notifications for mainnet

* changelog
- Fix fetching libstdc++ in install_chrome_headless.sh

- Fix catchup numbers_to_ranges function

- Fix "Elixir.Indexer.Memory.Monitor",{{badkey,limit}

- Fix Docker image build

- Fix tests

- Fix twin compiler version

- Fix other tests

- Fix ethereum_jsonrpc tests

- Fix pending gas price in pending tx

- Fix warning

- Fix created_contract_code_indexed_at updating

- Fix nginx config for UI 2.0 websocket ([#7825](https://github.com/blockscout/blockscout/issues/7825))

* fix nginx config for UI 2.0 websocket

* update change log
- Fix tests warning; Fix env name

- Fix additional sources and interfaces, save names

- Fix parsing of database password period(s)

- Fix missing ranges insertion and deletion logic


## [5.2.0-beta] - 2023-06-20

### 🐛 Bug Fixes

- Fix for dialyzer

- Fix import of tx actions

- Fix contract args displaying bug

- Fixing E2E tests

- Fix contract creation transactions

- Fix ABI read functions filter ([#7636](https://github.com/blockscout/blockscout/issues/7636))

* Fix ABI read functions filter

* Changelog

* Drop empty_inputs?/1
- Fix single 1155 transfer displaying

- Fix tokens pagination

- Fix reviewer comments

- Fix created_contract_address_hash detection

- Fix count on empty database

- Fix wording

- Fix gwei to wei in database

- Fix shrinking logo in safari


### 🚜 Refactor

- Refactor state changes


## [5.1.5-beta] - 2023-05-18

### 🐛 Bug Fixes

- Fix missing range sanitize

- Fix range inserting + refactor

- Fix MissingRangesManipulator

- Fix pending txs is not a map

- Fix missing block ranges clearing

- Fix tests

- Fix RE_CAPTCHA_DISABLED variable parsing

- Fix smart contract displaying

- Fix review comment

- Cannot read properties of null (reading 'value')
- Fix footer link :focus color


### 🚜 Refactor

- Refactoring queries with blcoks


### 📚 Documentation

- Docker compose for front-end


## [5.1.4-beta] - 2023-04-27

### 🐛 Bug Fixes

- Fix Elixir tracer to work with polygon edge

- Fix tokensupply API v1 endpoint: handle nil total_supply

- Fix CIDv0

- Fix tx type for pending contract creation; Remove owner for not unique ERC-1155 token instances

- Fix status for dropped/replaced tx

- Fix default `TOKEN_EXCHANGE_RATE_REFETCH_INTERVAL` ([#7270](https://github.com/blockscout/blockscout/issues/7270))

* Fix default TOKEN_EXCHANGE_RATE_REFETCH_INTERVAL

* Update CHANGELOG.md

---------

Co-authored-by: Victor Baranov <baranov.viktor.27@gmail.com>
- Fix translation check


### 🚜 Refactor

- Refactor Indexer.Fetcher.TokenInstance aliasing

- Refactor Indexer.Fetcher.TokenInstance naming


## [5.1.3-beta] - 2023-04-11

### 🐛 Bug Fixes

- Fix test

- Fix MissingRangesCollector max block number fetching

- Fix read interaction with functions which accepts multidimensional arrays

- Fix Makefile docker setup

- Fix build from Dockerfile


### 🚜 Refactor

- Refactor queries


## [5.1.2-beta] - 2023-03-30

### 🐛 Bug Fixes

- Fix Docker image generation on release

- Fix internal transactions processing for non-consensus blocks

- Fix realtime fetcher test

- Fix realtime fetcher scheduling

- Fix frontend-main docker image tag

- Fix docker image tag generation

- Fix timeout duration parsing

- Fix custom ABI loading

- Fix pagination; Add same token_id squashing; Add tests

- Fix `formating` in spell check

- Fix spell in namings, add spell checking in CI

- Fix updating coin balances with empty value ([#7009](https://github.com/blockscout/blockscout/issues/7009))


- Fix BufferedTask initial stream

- Fix CHANGELOG entry

- Fix for mix credo


### 🚜 Refactor

- Refactor runtime config ([#7119](https://github.com/blockscout/blockscout/issues/7119))

* Refactor runtime config

* Process reviewer comments

* Invalidate GA cache
- Refactor code to support Credo 1.7

- Refactoring indexing ratio related functions

- Refactor Reader: query_function_with_names and query_function

- Refactoring

- Refactor socket.js


## [5.1.1-beta] - 2023-02-27

### 🐛 Bug Fixes

- Fix review comments

- Fix TokenTotalSupplyOnDemand fetcher; Add FirstTraceOnDemand fetcher; Add fallback values in blocks to on demand fetchers

- Fix indexed_ratio_blocks

- Fix wss connect

- Fix ttl_check_interval for cache modules

- Fix 99% on indexing banner

- Fix WebSocketClient

- Fix value in "Indexing tokens" banner

- Fix pull request id

- Fix unit test

- Fix an error occurred when decoding base64 encoded json

- Fix bugs in verification API v2 ([#6911](https://github.com/blockscout/blockscout/issues/6911))

* Fix bugs in verification API v2

* Fix test
- Fix services ports in docker-compose

- Fix token type definition for multiple interface tokens

- Fix Internal Server Error on tx input decoding ([#6889](https://github.com/blockscout/blockscout/issues/6889))

* Fix Internal Server Error on tx input decoding

* Update CHANGELOG.md

---------

Co-authored-by: Victor Baranov <baranov.viktor.27@gmail.com>

## [5.1.0-beta] - 2023-02-13

### 🐛 Bug Fixes

- Fix pool checker in tx actions fetcher

- Fix task restart in tx actions fetcher

- Fix #6838 review comments: refactor app.html.eex

- Fix 503 page
- Fix block realtime fetcher

- Fix geth transaction tracer

- Fix handling unknown calls from callTracer

- Fix fetcher_test.exs

- Fix for addresses.ex

- Fixes for mix credo and gettext

- Fix dialyzer error

- Fix tx action type name

- Fix indexer tests

- Fix for gettext

- Fix for dialyzer

- Fix gettext

- Fix vertical scroller for tx actions area

- Fix handling of INDEXER_TX_ACTIONS_REINDEX_PROTOCOLS env setting

- Fix tx actions transformer to be able to use it in fetcher

- Fix tx actions ordering

- Fix bounds clearing

- Fix tx count on empty chain

- Fix address counter on empty chain ([#6746](https://github.com/blockscout/blockscout/issues/6746))

* Fix address counter on empty chain

* Update CHANGELOG.md

[no ci]
- Fix dialyzer

- Fix timestamps in /tokens/{address_hash}/transfers

- Fix test

- Fix tests

- Fix smart contract bug + regression test


### 🚜 Refactor

- Refactoring

- Refactoring

- Refactor tx action amount view

- Refactor find_tx_action_addresses function

- Refactoring

- Refactoring

- Refactor for mix credo

- Refactor TransactionActions transformer for mix credo

- Refactor TransactionActions transformer and extend error logging

- Refactor TransactionActions transformer

- Refactor TransactionActions transformer

- Refactor `try rescue` statements to keep stacktrace ([#6786](https://github.com/blockscout/blockscout/issues/6786))

* Refactor try rescue statements to keep stacktrace

* Update CHANGELOG.md
- Refactor Vyper.PublisherWorker


### 📚 Documentation

- Increase max connections and db pool size

## [5.0.0-beta] - 2023-01-11

### 🐛 Bug Fixes

- Fix bugs in smart contracts API v2

- Fix tests

- Fix tests

- Fix MissingRangesCollector initial state

- Fix mix credo

- Fix error on non-existent method id + regression test

- Fix unhandled error; Add regression tests; Add missing existance smart-contracts checks

- Fix tests

- Fix min_missing_block_number updating

- Fix FIRST_BLOCK LAST_BLOCK envs logic

- Fix frontend image ([#6606](https://github.com/blockscout/blockscout/issues/6606))

* test latest image for frontend-main

* test latest image for frontend-main

* add ARG to Dockerfile

* update Changelog
- Fix wrong h1 closing tag
- Fix build job

- Fix bug with proxy for twins

- Fix internal transactions query

- Fix index creation migration

- Fix get_implementation_address_hash call

- Fix mix gettext

- Fix mix credo

- Fix pr issues

- Fix sol2uml button layout

- Fix pr issues for sol2uml

- Fix nil filename bug

- Fix image viewer bug

- Fix state for contract creation transactions

- Fix token balances migrations

- Fix token name with unicode graphemes shortening

- Fix double slash in the path

- Fix search for address logs

- Fix token id migrator worker test

- Fix LowestBlockNumberUpdater test

- Fixes

- Fix gettext

- Fix double slash in the path

- Fix docker build and e2e tests workflows ([#6387](https://github.com/blockscout/blockscout/issues/6387))

* debug e2e workflow

* fix workflow for e2e

* fix CHANGELOG.md

* debug workflow for e2e

* debug workflow for e2e
- Fix UI issues

- Fix color of navbar submenus (Block, Transactions)
- Changed search field style
- Conditionally remove plus sign from counters
- Add borders to filters
- Fixed filters button style
- Replace loading spinners with "N/A"
- Add margin to filter button
- Add commas to stats numbers

Update gettext

- Fix transactions response

- Fix definitions of NETWORK_PATH, API_PATH, SOKCET_ROOT: process trailing slash

- Fix and refactor address logs page and search

Fix double reqiest

Fix cancel search button

Add dynamic search and search by enter

- Fix sending request on each key in token search

- Fix token search with space

- Fix DISABLE_TOKEN_INSTANCE_FETCHER env

- Fix /blocks page freezing in case of large blocks numbers gaps

- Fix coin_id test

- Fix Indexing message appearance

- Fix runtime definition of ETHEREUM_JSONRPC_VARIANT variable

- Fix SMV variable name

- Fix unfetched token balances

- Fix changelog

- Fix token instance async_fetch

- Fix token instance fetcher for ERC-1155

- Fix inconsistent behaviour of getsourcecode method

- Fix tests

- Fix tests

- Fix docker compose

- Fix tests

- Fix tests

- Fix gettext

- Fix key :id not found error

- Fix tests

- Fix hash field for watchlist notifications

- Fix after rebase

- Fix editing public tags request (case with deleting addresses)

- Fix edit form for public tags request; Add space trimming for tags

- Fix public tags request bug

- Fix migration

- Fix duplicates of native coin transfer: remove Notify.async from insert_changes_list

- Fixing failed test: Revert Poison 5.0.0 -> 4.0.1

- Fix button margin

- Fix ESLint failed test

- Fix credo & dialyzer

- Fix tests

- Fix errors with tags

- Fix transaction tags in tile; summary

- Fix tags duplication

- Fix bug with floating number at the beginning of the API keys page

- Fix warnings, eslint; mix gettext

- Fix code complexity

- Fix the index query for tags

- Fix nil comparsion and list conversion errors

- Fix batch ERC-1155 email notifications


### 🚜 Refactor

- Refactor contract libs render, CONTRACT_VERIFICATION_MAX_LIBRARIES, refactor parsing integer env vars in config

- Refactor JSON RPC variants

- Refactor DB config


### 📚 Documentation

- Docs + refactor

- Docker-compose persistent logs

- Docker compose confgis improvement: Redis container name and persistent storage

- Docker-compose config for Erigon

- Docker compose: add config for Erigon


## [4.1.8-beta] - 2022-09-05

### 🐛 Bug Fixes

- Fix version in apps/explorer/mix.exs

- Fix token transfers tests

- Fix dialyzer

- Fix token instance fetching

- Fix token_ids array type cast

- Fix test envs

- Fix ERC-1155 tokens fetching

- Fix order of results in txlistinternal API endpoint

- Fix address checksum on transaction page

- Fix ad appearance at domain blockscout.com or subdomains

- Fix display of estimated  addresses counter

- Fix address overview.html.eex in case of nil implementation address hash

- Fix CSV export of internal transactions

- Fix ace editor appearance

- Fix unexpected messages in CoinBalanceOnDemand

- Fix nightly solidity versions filtering UX ([#5942](https://github.com/blockscout/blockscout/issues/5942))


- Fixing tracer not found #5729

- Fix vyper verification with twin contract data

- Fix focus on Next button in 1st verification form (chose verification)

- Fix large postgres notifications ([#5850](https://github.com/blockscout/blockscout/issues/5850))

* Fix large postgres notifications

* Update Changelog

Co-authored-by: Victor Baranov <baranov.viktor.27@gmail.com>
- Fix subpath not added to transaction_controller and holder_controller

- Update current_path to equal Controller.current_full_path(conn)


## [4.1.7-beta] - 2022-08-04

### 🐛 Bug Fixes

- Fix address_tokens_usd_sum function

- Fix Cannot find module solc

- Fix flickering token tooltip


## [4.1.6-beta] - 2022-08-02

### 🐛 Bug Fixes

- Fix CHANGELOG.md

- Fix CHANGELOG.md

- Fix runtime test conf

- Fix migrator pool_size

- Fix server starting

- Fix double requests; Fix token balances dropdown view


### 🚜 Refactor

- Refactor runtime config


### 📚 Documentation

- Dockerfile optimizations


## [4.1.5-beta] - 2022-06-17

### 🐛 Bug Fixes

- Fix broken token icons; Disable animation in lists of data in order to speed up UI; Fix double requests for some pages

- Fix wrong miner address shown for post EIP-1559 block for clique network

- Fixes yaml syntax for docker compose


## [4.1.4-beta] - 2022-06-15

### 🐛 Bug Fixes

- Fixes in Circles, Dark-forest themes

- Fix dark theme

- Fix warnings in tests

- Fix empty coin balance for empty address

- Fix tests

- Fix vyper compiler versions order

- Fixed burned_fees manual reward calculation

- Fixed emission reward query range

- Fix burned_fees type

- Fix failing verification attempts

- Fix token dropdown

- Fix address on twin verification; Change redirect routes for verified contracts

- Fix twin verification

- Fix func name

- Fix Chain module attribute typo

- Fix internal tx's tile bug


## [4.1.3-beta] - 2022-05-05

### 🐛 Bug Fixes

- Fix js import

- Fix structure array encoding

- Fix params encoding for read contracts methods

- Fix displaying own names on internal tx tiles

- Fix array displaying in decoded constructor args

- Fix unverified_smart_contract function: add md5 of bytecode to the changeset

- Fix character_not_in_repertoire error for tx revert reason

- Fix getsourcecode for EOA addresses

- Fix tests

- Fix tests

- Fix Jason encode error

- Fix reload transactions button

- Fix typo in config_helper.ex

enviroment -> environment
- Fix pending txs fetcher

- Fix Vyper verification form tooltips

- Fix 500 error on NF token page with nil metadata

- Fix flash on reload in dark mode

- Fix no function clause matching in Indexer.Block.Catchup.BoundIntervalSupervisor.handle_info

- Fix vulnerability

- Fix sed

- Fix bytecode twins feature

- Fix bug with 500 response on partial sourcify status

- Fix implementation address align

- Fix coin-balances/by-day bug


### 🚜 Refactor

- Refactor config

- Refactor daily coin balances fetcher

- Refactoring from SourcifyFilePathBackfiller


## [4.1.2-beta] - 2022-03-04

### 🐛 Bug Fixes

- Fix pool_size value setting from env vars in configs

- Fix hostname Regex pattern

- Fix BS container image var usage

- Fix BS container image var usage

- Fix contract verification when constructor args provided

- Fix docker-compose

- Fix contract functions outputs

- Fix internal txs pagination

- Fix constructor arguments verification bugs

- Fix several UI bugs; Add tooltip to the prev/next block buttons

- Fix Staking Dapp styles

- Fix typo in DB migration module name

- Fix blocks validated hint

- Fix get_implementation_abi_from_proxy/2 implementation

- Fix token counters bug

- Fix _topnav template


### 🚜 Refactor

- Refactoring suggestions processed


### 📚 Documentation

- Docker setup Makefile release publish tasks

- Docker-compose configs


## [4.1.1-beta] - 2022-01-17

### 🐛 Bug Fixes

- Fix typo in layout_view_test.exs

enviroment -> environment
- Fix long names crossing with USD

- Fix wallet style

- Fix read contract page bug

- Fix write page contract tuple input

- Fix typo
- Fix broken functions input

- Fix 500 response when ABI method was decoded as nil


### 🚜 Refactor

- Refactor search page template


## [4.1.0-beta] - 2021-12-29

### 🐛 Bug Fixes

- Fix token transfers csv export

- Fix failing verifier test

- Fix fetch_last_token_balance process termination

- Fix constanlty failing 2 contract verification tests

- Fix tests

- Fix 0x0 implementation address

- Fix bugs and improve contract interactions

- Fix falsy Connection Lost on reload page

- Fix displaying of nested arrays for contracts read

- Fix search field appearance on medium size screens

- Fix format_according_to_decimals method

- Fix fetch_top_tokens add nulls last for token holders


## [4.0.0-beta] - 2021-11-09

### 🐛 Bug Fixes

- Fix infinite gas usage count loading

- Fix read contract page

- Fix view for broken token icons

- Fix floating tooltip on the main page

- Fix for extract_omni_bridged_token_metadata_wrapper method

- Fix nil.timestamp issue

- Fix type var value for _tokens.html rendering in case of 1155

- Fix token balances 500 response

(cherry picked from commit 238533eff76b719abb5a5fbfe166c6aef1b27305)

- Fix balances indexing error: ON CONFLICT DO UPDATE command cannot affect row a second time

(cherry picked from commit 7af2be774b7d9b41260174121b11acf293050b52)

- Fix tests

(cherry picked from commit 9386adfb0b15685d87bc6917a0ddfa9dc115faf3)

- Fix mobile view for address page

(cherry picked from commit 520d262781f7e790f58a3b4ebc894e64238e6d6b)

- Fix CSV export logs test

- Fix comparison of decimal value

- Fix fees for zero gas price txs

- Fix typo in naming

- Fix hardcoded strings

- Fix pagination in Block Details, Transactions tab

- Fix internationalization files

- Fix blockscout web transaction overview token creation section

- Fix duplicate entry

- Fix timestamp for blocks pages

- Fix css for dark theme

- Fix endless Fetching tokens message on emty addresses

- Fix solid outputs on contract read page

- Fix floating tooltips on token transfer block

- Fix NaN input in write contract


## [3.7.3-beta] - 2021-08-27

### 🐛 Bug Fixes

- Fix width of table

- Fix test

- Fix routes: add NETWORK_PATH variable to current_path

- Fix incorrect next page url

- Fix 500 response on empty contract's code page

- Fix copy-paste typo in token_transfers_counter.ex

- Fix autocomplete links to txs, blocks, addresses

- Fix Cannot read property toLowerCase of undefined

- Fix contract read page error

- Fix error response in contract's output

- Fix token holders list


## [3.7.2-beta] - 2021-07-26

### 🐛 Bug Fixes

- Fix bug zero total supply

- Fix current token balance on-demand fetcher

- Fix zero total supply bug

- Fix empty search results

- Fix internal server error on validator's transactions page

- Fix false pending txs

- Fix html template for txs input

- Fix elixir version in .tool-versions

- Fix gettext


## [3.7.1-beta] - 2021-07-09

### 🐛 Bug Fixes

- Fix raw trace bug

- Fix txs page for validators

- Fix gettext

- Fix dialyzer, gettext

- Fix token search

- Fix getsourcecode bug

- Fix /decompiled-contracts bug

- Fix logo url redirection, set font-family defaults for chart.js

- Fix internal server error on contract verification options page

- Fixed bug with empty array in write page

- Fix docs generation

- Fix gettext

- Fix tests for list_token_transfers function

- Fix tokenlist API endpoint return only tokens with positive balance

- Fix padding in tx tile


### 🚜 Refactor

- Replace inline style display: none with d-none class

## [3.7.0-beta] - 2021-04-26

### 🐛 Bug Fixes

- Fix getTokenHolders API endpoint pagination

- Fix more typos in the same file
- Fix typo in doc: they -> them
- Fix number of confirmations

- Fix mobile styles for tx tile


### 🚜 Refactor

- Refactor and optimize Staking DApp


## [3.6.0-beta] - 2021-03-26

### 🐛 Bug Fixes

- Fix sushiswap lp tokens custom metadata fetcher

- Fix POSDAO snapshotting and remove temporary code

- Fix losing digits at wei conversion

- Fix stake_snapshotting.ex

- Fix stake_snapshotting.ex

- Fix .dialyzer-ignore

- Fix ValidatorSetAuRa ABI JSON

- Fix trace internal transactions for create contract without code

We faced method handler crashed error in Kotti
```
[%{code: -32000, data: %{block_number: 1743966, transaction_hash: "0x0e439d91608cfcd2ff89ca9345bb8a93a4f1522fe82a0666e21f02afa7011848", transaction_index: 0}, message: "method handler crashed"}]
```

I found similar issues but there is no solution yet
https://github.com/poanetwork/blockscout/issues/3234
https://github.com/poanetwork/blockscout/issues/2445

But I found that in our case in Kotti this transactions is contact creation tx. But tx doesn't has input (so no contract code). 

```
{
    "jsonrpc": "2.0",
    "method": "eth_getTransactionByHash",
    "params": ["0x0e439d91608cfcd2ff89ca9345bb8a93a4f1522fe82a0666e21f02afa7011848"],
    "id": 83
}

{
    "jsonrpc": "2.0",
    "id": 83,
    "result": {
        "blockHash": "0x9e37819c590ace5a4451b4cb6374674bc1270f069d0fb95ad7898bef92844901",
        "blockNumber": "0x1a9c5e",
        "from": "0x0343bd58f238839da7b3b5179a44ab310ad5aa2b",
        "gas": "0x1368c",
        "gasPrice": "0x3b9aca00",
        "hash": "0x0e439d91608cfcd2ff89ca9345bb8a93a4f1522fe82a0666e21f02afa7011848",
        "input": "0x",
        "nonce": "0x3",
        "to": null,
        "transactionIndex": "0x0",
        "value": "0x0",
        "v": "0x30",
        "r": "0x36f1ddd3870a6fde0e94074d068e6208e2260a6fd692e7173a2e45ea024b9b7b",
        "s": "0x597439bd880257437f9656edc3a6120d16e3ccc8c6bd807bd2757bae50a5a6b6"
    }
}
```

I don't know how it could happen (maybe somebody could explain this). But I add handle to not take contact code if input was empty
- Fix 413 Request Entity Too Large returned from single request batch

- Fix gettext

- Fix transaction decoding view: support tuple types

- Fix gettext merging

- Fix logo size

- Fix Predicted Reward column in Delegators popup

- Fix Predicted Reward column in Delegators popup

- Fix contract reader

- Fix nested types

- Fixes

- Fix Staking DApp light optimizations


### 🚜 Refactor

- Refactoring

- Refactoring


## [3.5.1-beta] - 2021-01-12

### 🐛 Bug Fixes

- Fix output of tuple type

- Fix DF theme applying


## [3.5.0-beta] - 2020-12-24

### 🐛 Bug Fixes

- Fix QR code tooltip appearance

- Fix left margin of balance card in mobile view

- Fix tt tile styles: prevent overlapping of long names

- Fix Staking DApp first loading

- Fix write call without params

- Fix contract write call inputs

- Fix tuple array output in contract interaction

- Fix working with big numbers in Staking DApp

- Fix doubled token transfer at block page if block has reorg

- Fix endless block invalidation problem

- Fix call to fallback function and call of GnosisProxy contract methods

- Fix contract verification from genesis block

- Fix display of token transfers list (fix unique identifier of a tile)


### 🚜 Refactor

- Refactoring

- Refactor cache for tokens exchange rates


## [3.4.0-beta] - 2020-11-16

### 🐛 Bug Fixes

- Fix .dialyzer-ignore

- Fixes for credo and gettext

- Fix tests

- Fixed postgres docker image
- Fix unnecessary tx error status

- Fix address tokens search

- Fix long NFT id

- Fix contract reader: tuple type

- Fix token view mobile style (Circles UBI)

- Fix difficulty display

- Fix int txs error status

- Fix Token transfers CSV export

- Fix total tx info icon placement in mobile view

- Fix DF, night mode styles

- Fix gas price usage counter

- Fix contract nested inputs

- Fix find block timestamp query

- Fix horisontal scroll in Tokens table

- Fix Verify contract button width

- Fix Staking dapp dark mode styles

- Fix tokens dropdown appearance

- Fix token transfer realtime fetcher

- Fix TokenBridge market cap calculator

- Fixes after rebase

- Fix unit test

- Fix 'Stake' and 'Become a Candidate' popups

- Fix displaying fractional balances in header

- Fix viewing_chain_test.exs

- Fix viewing_addresses_test.exs

- Fix the order of mock calls in contract_state_test.exs

- Fix bug in dropdown with tokens appearance in address view page

- Fix 3 failed tests in stakes_controller_test.exs

- Fix tests: gettext, eslint

- Fix tests: mix format and mix credo

- Fix staking page refreshing

- Fix find_claim_reward_pools function

- Fix delegators counter and other improvements

- Fix snapshotting

- Fix tooltip in Delegators window

- Fix round error for reward ratios

- Fix start_snapshotting function

- Fix fields/variables names


- Fix order for reward ratio responses

- Fix issues in Staking DApp related to pool filters ([#2730](https://github.com/blockscout/blockscout/issues/2730))

* Fix disappearing pagination on pools filter toggle

* Wrap stakes table items in container to set minimum heigh

* Reduce flickering of content on changing pools table height

- Fix Staking DApp theme colors ([#2700](https://github.com/blockscout/blockscout/issues/2700))

* Fix button color in dark mode on Error Status modal

* Fix dark theme color in stake dialog modals

* Fix dark theme color for empty state in stake pools list

* Fix dark theme color for non-empty state in stake pools list

* Fix delegators list modal width for inactive pools

* Fix dark theme color for banned pools

* Fix differences in transition speed for input prepend block

* Fix dark theme color for input autofill

* Fix chart color in staking modals

* Fix to hide only tooltips that triggered by elements inside stakes top block

- Fix Staking DApp UI issues ([#2692](https://github.com/blockscout/blockscout/issues/2692))

2, 3, 4, 5, 6, 7, 12, 13, 19, 26

* Fix items disappearing misbehavior of staking filters
* Fix items disappearing animation of staking filters
* Fix not disappearing tooltip in stakes-top container on block number update
* Fix stakes top stats width to have fixed size on refresh
* Replace stakes table with flex boxes to fixate size of table header
* Fix staking modals width
* Change style for non clickable addresses in delegators list modal
* Decrease top stats min size to fit in firefox but look nice in logout state
* Make fixed width for delegators list modal
* Refactor stakes-address-container to set active and not active styles
* Reduce gap for modal tile in validation info modal

- Fix xDai btn hover styles

- Fix dark body background

- Fix inventory pagination where condition

- Fix tokens list pagination

- Fix inventory tab pagination

- Fix logs search

- Fix mobile styles for contract code tab

- Fix validated transactions visibility page

- Fix applying dark forest theme

- Fix dark forest theme bugs, allow multiple contracts

- Fix gettext

- Fix flickering between light and custom themes

- Fix flickering between light and custom themes

- Fix last_update cache key to store txs count

- Fix pagination for bridged tokens list page


### 🚜 Refactor

- Refactor CoinGecko interaction


## [3.3.3-beta] - 2020-10-02

### 🐛 Bug Fixes

- Fix logs api response

- Fix OWL tokens info

- Fix xDai styles: invisible tokens on address

- Fix xDai styles: invisible tokens on address

- Fixate latest stable release of Elixir, Node, Postgres

- Fix acquire of market cap from omnni-bridge

- Fix condition for external rewards

- Fix fetch_coin_balance query: coin balance delta

- Fix encoding of address output if function input exists

- Fix invisible token name at transfer page

- Fix tab status for bridged tokens

- Fix for invisible validator address at block page


### 🚜 Refactor

- Handle empty array type input
- Refactoring to fix an issue at xDai

- Refactoring


## [3.3.2-beta] - 2020-08-24

### 🐛 Bug Fixes

- Fix gettext

- Fix gettext

- Fix tests

- Fix contract funnction method detection

- Fix one more test

- Fix tests

- Fix coin supply api

- Fix dialyzer test

- Fix for the contract verifiaction for solc 0.5 family with experimental features enabled

- Fix foreign chaind detection

- Fix query for bridged token feature

- Fix tests

- Fix notifier query for live update of token transfers

- Fix navbar menu at block not found page


## [3.3.1-beta] - 2020-08-03

### 🐛 Bug Fixes

- Fix revert reason detection

- Fix tests

- Fix view for read contract

- Fix read contract bytes array type

- Fix verification with experimental features enabled

- Fix non-interactive navbar at not found page

- Fix permanent fetching tokens and unavailable navbar menu when read/write proxy tab is active


## [3.3.0-beta] - 2020-07-02

### 🐛 Bug Fixes

- Fix error on token\'s read contract tab

- Fix for acocunts page with token-bridge supply and inexistent bridge contracts

- Fix for verification of contracts from genesis block

- Fix for definnition of contract type: proxy/regular


## [3.2.0-beta] - 2020-06-17

### 🐛 Bug Fixes

- Fix several tests

- Fix contract compilation tests for old versions of compiler: change compiler version since nightly versions of some older versions were removed


## [3.1.3-beta] - 2020-06-05

### 🐛 Bug Fixes

- Fix coin balance history page if no balance changes

- Fix performance of the balance changing history under the chart

- Fix coinn supply query: Or the value is incompatible or it must be interpolated (using ^) so it may be cast accordingly in query

- Fix performance of coin supply API endpoints

- Fix JSONN structure

- Fix merging conflict

- Fix tests

- Fix tests

- Fix performance of Inventory tab

- Fix verification of contracts created from factory


### ⚡ Performance

- Performance fix: index on blocks [miner_hash, number]


## [3.1.2-beta] - 2020-05-08

### 🐛 Bug Fixes

- Fix migration

- Fix contract reader

- Fix constructor arguments decoding

- Fix format and internationalization

- Fix test

- Fix order by statement for txs stats query

- Fix test


## [3.1.1-beta] - 2020-03-23

### 🐛 Bug Fixes

- Fix views width

- Fix missing conn in eex template


## [3.1.0-beta] - 2020-02-28

### 🐛 Bug Fixes

- Fix checksum in query paramater of address_counters endpoint

- Fix transactions and blocks appearance if less blocks and txs on the page than it can contain

- Fix splitting setup

- Fix pool size default value in config

- Fix default values for ENV vars

- Fix filters functionality

- Fix token instance QR code data when api_path is different from path

- Fix token instance QR code data

- Fix checksum address on token/instance pages

- Fix gettext

- Fix checksum redirect tests

- Fix redirect to checksummed address

- Fix copy UTF8 tx input action

- Fix contract code param name (Parity)

- Fix manual merging conflict

- Fix internalization files

- Fix mix formatting

- Fix long contracts names

- Fix awesomplete lib loading in Firefox

- Fix typo and support API_PATH env var

- Fix web manifest accessibility

- Fix import spec file to support accounts without 0x prefix and single block reward

- Fix styles loading for firefox

- Fix path definition for contract verification endpoint


### 🚜 Refactor

- Refactoring

- Refactoring


## [3.0.0-beta] - 2020-01-28

### 🐛 Bug Fixes

- Fix contract constructor require msg appearance in constructor arguments encoded view

- Fix bug in skipping of constructor arguments inn contract verification

- Fix npm deps

- Fix linter errors

- Fix tests

- Fix ViewingAddressesTest

- Fix remaining tests

- Fix tests

- Fix tests

- Fix remaining tests

- Fix Tokens.TokenControllerTest

- Fix more tests

- Fix AddressInternalTransactionControllerTest

- Fix AddressTransactionControllerTest

- Fix AddressTokenControllerTest

- Fix AddressTokenTransferControllerTest

- Fix internalization

- Fix eth api docs

- Fix tests

- Fix performance of address page even without limiting of rewards to retrieve

- Fix api templates

- Fix internalization files

- Fix getsourcecode test

- Fix merging conflicts

- Fix viewing_transactions_test

- Fix tests

- Fix logs queries

- Fix chain_test

- Fix query

- Fix remaining tests

- Fix most tests

- Fix chain tests

- Fix merging conflicts

- Fix tests

- Fix node_test.exs

- Fix joining

- Fix tests

- Fix tests

- Fix query

- Fix remaining tests

- Fix most tests

- Fix token transfer factory

- Fix duplicate websocket connection

- Fix linter errors

- Fix selected column name

- Fix

- Fix tests

- Fix address sum cache

on the first call address sum cache starts task to
fetch a value from the DB and return nil

- Fix tests

- Fix dialyzer

- Fix address sum cache

on the first call address sum cache starts task to
fetch a value from the DB and return nil

- Fix

- Fix empty buffered task

current fetcher do not process new items
when they were added after initial records from
db were processed.

This PR fixes it.


## [2.1.1-beta] - 2019-11-27

### 🐛 Bug Fixes

- Fix linter errors

- Fix ui for chart loading

- Fix dialyzer

- Fix test

- Fix credo

- Fix token updating

- Fix build

- Fix paths for fron assets

- Fix npm vulerabilities

- Fix favicons' paths

- Fix typo

- Fix build

- Fix wrong constructor argument detection

- Fix token transfer query

- Fix remaining tests

- Fix chain_test

- Fix gettext

- Fix remaining tests

- Fix AddressTokenTransferControllerTest

- Fix merging conflicts

- Fix token transfer loading

- Fix address_hash_to_token_transfers

- Fix address token transfers view

- Fix tests

- Fix realtime fetcher small skips feature

If indexing is started from scratch, realtime fetcher
tries to index large ranges of blocks. For example, 5..1852044.
It produces errors like
`failed to fetch: :emfile.  Block will be retried by catchup indexer`

This PR limits the number of blocks to 10

- Fix txlist ordering issue

- Fix viewing_app_test.exs

- Fix for stuck gas limit label and value

- Fix gettext

- Fix test

- Fix loader

- Fix

- Fix count for a contract

- Remove outer container of transaction-count if there is no value
- Fix gettext

- Fix gettext

- Fix tests

- Fix style

- Fix indentation

- Fix gettext

- Fix CR comment

- Fix address_to_unique_tokens query

- Fix message handling

- Fix block validator custom tooltip

- Fix blocks fetching on the main page

- Fix gettext


## [2.1.0-beta] - 2019-10-23

### 🐛 Bug Fixes

- Fix tests

- Fix style

- Fix gettext

- Fix config

- Fix listener init

- Fix logging level

- Fix build

- Fix fetching `latin1` encoded data

some json contain latin1 encoded data which
fails to be decoded

- Fix stuck value and ticker on token page

- Fix build

- Fix tests

- Fix token instances query

- Fix logging

- Fix websocket subscriptions with token instances

- Fix query

- Fix not found token instance

- Fix opt 22.1 support

- Fixed broken mobile view for cards on transaction details page

- Fix dialyzer

- Fix build

- Fix build

- Fix gettext

- Fixed left-padding on history_chart

- Fixed credo, dialyzer, and gettext

- Fixed elixir formatting

- Fixed history_chart legend txs number formatting

- Fixed history_chart left axis cutoff problem

- Fix legend and axis spacing on history_chart

- Fixed legend color for txs history chart

- Fixed explorer/config/config.exs problems

- Fixed typos

- Fixed legend

- Fixed gettext

- Fixed formatting

- Fixed the _.js import errors

- Fixed formatting

- Fixed function nil.number_of_transactions/0 is undefined in tests

- Fixed formatting

- Fixed contract buttons color for each theme

- Fix query

- Fix gettext

- Fix gettext

- Fix image html

- Fix style issues

- Fix token instance metadata tab

- Fix gettext

- Fix token instances query

- Fix image src

- Fix gettext

- Fix qr url

- Fix token transfer tickers

- Fix gettext

- Fix token instance fetcher

- Fix gettext test after manual merging

- Fix qr code

- Fix block transactions test

- Fix remaining tests

- Fix token helpers test

- Fix gettext

- Fix gettext

- Fix credo

- Fix gettext

- Fix QR Code

- Fix token instance router and controller

- Fix dialyzer

- Fixed menu hovers in dark mode desktop view

- Fix gettext

- Fixed logs alignment

- Fixed address alignment in logs decoded view

- Fix library verification

bytecode of a library contains address of a deployed library

- Fix try it out section

- Fix ci

- Fix stuck label and value for uncle block height

- Fix tests

- Fix test

- Fix empty total_supply in coin gecko response

- Fix exchange rate websocket update for Rootstock

Rootstock has custom logic for market cap calculation that
uses data from DB. This PR add required feilds to exchange_rate
when sending it through a web socket.

- Fix gettext

- Fix typo

- Fix typo

- Fixed buttons color at smart contract section

- Fix CR issues

- Fix for dashboard banner


## [2.0.4-beta] - 2019-09-06

### 🐛 Bug Fixes

- Fix build

- Fix POA Importer

- Fix api/rpc/contract_controller_test

- Fix tests

- Fix typo

- Fixed tooltips issue, header should work fine, fixed buttons colors on Contract Address Details page

- Fix remaining tests

- Fix tests

- Fix gettext

- Fix tests

- Fix market_cap calculation

- Fixed incorrect numerical order in Chores

- Fix test

- Fix tests

- Fix error of url in API page

- Fix env var description

- Fix test

- Fix json decoding

- Fix CoinGecko tests

- Fix gettext

- Fix gettext

- Fix gettext

- Fix confirmations for non consensus blocks

- Fix gettext

- Fix html for address logs view

- Fix transaction assign in view

- Fix tests

- Fix transaction logs view

- Fix gettext and credo

- Fix tests

- Fix a blinking test

The test was failing because `RollingWindow` process is already
initialized in `setup` hook

- Fix tests

- Fix explorer/etherscan tests

- Fix rpc/address_controller test

- Fixed UI issuewith inconsistency in error box text colors

- Fixed height issue with dashboard banner, added tooltips to the block details page.

- Fixed dashboard-banner-container height issue during loading  on the main blockscout page

- Fix sobelow

- Fix GenesisData process startup

- Fix sobelow

- Fix tests

- Fix process init

- Fix credo

- Fix PGRange to Block.Range conversion

- Fix build

- Fix test

- Fix eslint issues

- Fix first page button for uncles and rewards

- Fix remaining test

- Fix tests

- Fix tests

- Fix dialyzer

- Fix sobelow

- Fix duplicate entries

- Fix chart step size

- Fix order

- Fix query

- Fix style

- Fix js chart


## [2.0.3-beta] - 2019-08-13

### 🐛 Bug Fixes

- Fix CR issues

- Fix rsk total supply for empty exchang rate

- Fix dark theme flickering

- Fix CR issue

- Fix slash before not empty path

- Fixate 2.0.3 release
- Fix typo in changelog entry

- Fix gettext

- Fix ticker

- Fix rendering

- Fix gettext

- Fix failed contract verifications test

- Fix gettext

- Fix gettext

- Fix gettext

- Fix a bug with active tab

- Fix coin history chart data

- Fix gettext

- Fix dialyzer

- Fix gettext

- Fix factory

- Fix gettext

- Fix test

- Fix logging for finished indexed with last block set

- Fix indexed ratio type

- Fix total supply rpc

- Fix graphql schema type

- Fix CLDR issues

- Fix credo

- Fix query

- Fix top addresses query

- Fix typespec

- Fix dialyzer

- Fix cr issues

- Fix build

- Fix new credo warnings

- Fix complexity credo warning

- Fix with body

- Fix remaining case warnings

- Fix credo case warnings

- Fix gettext, add CHANGELOG entry

- Fix coin balance history view


## [2.0.2-beta] - 2019-07-25

### 🐛 Bug Fixes

- Fix hiding of loader for txs on the main page

- Fix gettext

- Fix gettext

- Fix raw trace

- Fix gettext

- Fix create2 changeset

- Fix tracer

- Fix test

- Fix gettext

- Fix internalization files

- Fix router page not found path

- Fix build

- Fix not existing keys in transaction json rpc

- Fix internalization files

- Fix gettext

- Fix gettext

- Fix decoding for unverified smart contracts

- Fix gettext

- Fix CR issues

- Fix js style

- Fix CR issues

- Fix test

- Fix conflicts

- Fix external library style

- Fix conflicts

- Fix dialyzer

- Fix typespec

- Fix CR issue

- Fix dialyzer

- Fix dialyzer

- Fix dialyzer

- Fix test

- Fix release

- Fix gettext

- Fix typo

- Fix gettext

- Fix CR issues

- Fix html columns

- Fix gettext

- Fix gettext

- Fix CR issues

- Fix verification of older smart contracts with constructor args

- Fix credo

- Fix empty clause

- Fix nested constructor arguments

- Fix dialyzer line number

- Fix dialyzer

- Fix invalid User agent headers

- Fix transaction input

- Fix tests

- Fix market history overriding

- Fix path issue

- Fix gettext test

- External library is only for verified contract
- Fix Contract byte code header style, external libraries to the bottom of the verified contract view

- Fix style issues

- Fix build

- Fix external libary function

- Fix js style

- Fix typo

- Fix js style

- Fix credo

- Fix gettext

- Fix event name

- Fix dialyzer

- Fix adding a job to the processing queue

- Fix tests

- Fix name for xDai source

- Fix transaction csv download link

- Fix interpolation in error message

- Fix CR issues

- Fix dialyzer

- Fix build

- Fix CR issue

- Fix more Nethermind errors

- Fix Nethermind json rpc errors

- Fix response without request id


### 📚 Documentation

- Pin bitwalker/alpine-elixir-phoenix:1.9.0

## [2.0.1-beta] - 2019-07-03

### 🚀 Features

- Add BLOCKSCOUT_HOST, and use it in API docs
- Calculate RSK market cap
- Document eth rpc api mimicking endpoints
- Add eth_getLogs rpc endpoint
- Add eth_getLogs rpc endpoint
- Eth_get_balance rpc endpoint

### 🐛 Bug Fixes

- Fix value conversion

- Fix supply for days

- Fix circulating value

- Fix rsk marketcap

- Fix rsk total_supply

- Fix internal transactions failing to insert because of transaction's error check constraint

- Fix gettext

- Fix gettext

- Fix tests

- Fix gettext

- Fix typo

- Fix CR issues

- Fix gettext

- Fix gettext and format tests

- Fix gettext

- Fix gettext

- Fix gettext

- Fix credo

- Fix pattern matching

- Fix gettext

- Fix credo

- Fix spaces

- Fix unidentified token transfers

- Fix gettext

- Fix CHANGELOG

- Fix typo

- Fix tests

- Fix dialyzer

- Fix gettext

- Fix gettext

- Fix gettext

- Fix test

- Fix credo

- Fix port

- Fix large contract verification

- Fix typo

- Fix metadata decomdiing in smart contract verification

- Fix test

- Fix tests

- Fix tests

- Fix tests

- Fix ChannelCase

- Fix failing test

- Fix tests

- Fix conflict

- Fix parity test

- Fix test

- Fix tests

- Fix config

- Fix docker build error

- Fix net version test

- Fix child id

- Fix credo

- Fix dialyzer

- Fix large number in balance view card

- Fix credo

- Fix coinmarketcap errors

- Fix reward channel joining

- Fix test

- Fix gettext

- Fix retries

- Fix navigation

- Fix navigation

- Fix map interpolation in logger

- Fix coin percentage view

- Fix for width of explorers

- Fix chain tests

- Fix tests

- Fix page size

- Fix credo

- Fixed uncles without full transactions


## [2.0.0-beta] - 2019-06-04

### 🚀 Features

- Add fields to tx apis, small cleanups
- Display init for selfdestructed contracts.
- Exclude empty contracts by default
- Add on demand fetching and stale attr to rpc
- Show raw transaction traces

### 🐛 Bug Fixes

- Fix geth's staticcall without output

- Fix typo

- Fix gettext

- Fix CHANGELOG

- Fix CR issues

- Fix log page number

- Fixed length of logs search input

- Fix remaining js issues

- Fix js style

- Fix credo

- Fix js indent

- Fix gettext

- Uniq by hash, instead of transaction
- Show creating internal transactions
- Use better queries for listLogs endpoint
- Use better queries for listLogs endpoint
- Fix BlocksTransactionsMismatch temporary fetcher

This solves a problem that was found with this fetcher:
block with no transactions were not taken into account, so they were not checked and never had their `refetch_needed` field set to false.

- Fix credo

- Fix transaction internal transaction controller tests

- Fix gettext

- Fix block transaction tests

- Fix gettext

- Fix gettext

- Fix transaction token transfer tests

- Fix credo, gettext

- Fix transaction log tests

- Fix address_token_controller tests

- Fix to/from filters on tx list pages
- Fix gettext

- Fix templates

- Fix gettext

- Fix mix format

- Fix eslint

- Fix gettext

- Fix tests

- Fix gettext

- Fix items

- Fix gettext

- Add fields for contrat filter performance
- Support https for wobserver polling
- Consolidate address w/ balance one at a time
- Fix wrong parity tasks names

- Fix eslint

- Fix eslint

- Fix style issues

- Fix eslint

- Fix js indentation

- Fix style issues

- Fix error with access behavior

- Fix gettext

- Fix pagination

- Fix tests

- Fix response

- Fix indexer tests

- Fix tests

- Fix CR issues

- Fix CR issue

- Fix various tests

- Fix potential race condition while dropping replaced transactions

Don't discard a transaction if it was eventually collated in the period
between replaced transaction worker initialization and actual dropping.

- Fix gettext test

- Fix different SUPPORTED_CHAINS env var tests

- Fix tests for SUPPORTED_CHAINS env var: assign value for correct variable

- Remove source code fields from list endpoint
- Fix mix.credo test

- Fix test

- Fix CR issues

- Fix build

- Fix System.get_env("BLOCK_COUNT_CACHE_TTL") type

- Split constructor args for verification
- Resolve false positive constructor arguments
- Store solc versions locally for performance
- Fix gettext

- Fix gettext

- Fix tests

- Fix reorgs, uncles pagination

- Fix gettext

- Fix gettext

- Fix gettext

- Fix gettext

- Fix line numbers

- Fix credo

- Fix display of verification alternatives in the tx details page

- Fix internal transaction output in JS tracer

That was most probably a typo.

- Fix typo

- Fix sobelow

- Fix credo warnings

- Fix staking pools fetcher

- Fix typo

- Logs list endpoint performance
- Fix gettext

- Fix mix format test


### 📚 Documentation

- Docsify setup

- Always set a container name

## [1.3.11-beta] - 2019-04-26

### 🚀 Features

- Verify contracts with a post request ([#1806](https://github.com/blockscout/blockscout/issues/1806))
- Verify contracts with a post request

### 🐛 Bug Fixes

- Ignore  messages without error

## [1.3.10-beta] - 2019-04-22

### 🚀 Features

- Set a ping_interval from config, defaulting to 300 seconds
- Slightly more informative json rpc error messages + logging
- Add RSK support

### 🐛 Bug Fixes

- Fix remaining tests

- Fix remaining tests

- Fix total_supply in test

- Fix search field border break/overlap

- Fix gettext

- Fix top nav autocomplete

- Fix detecting swarm code

- Fix gettext

- Fix line numbers for decompiled contracts

- Fix contructor arguments verification

- Fix eslint

- Fix CHANGELOG entry

- Fix first block parameter

- Fix CR issues

- Fix failing test

- Fix gettext

- Fix command order

- Fix script

- Fix gettext

- Fix credo

- Fix CHANGELOG: feature -> chore

- Fix gettext

- Fix empty block time

- Fix test

- Fix highlighting

- Fix tests


### 📚 Documentation

- Fix dockerFile for secp256k1 building

## [1.3.9-beta] - 2019-04-09

### 🚀 Features

- Verify contracts via an RPC endpoint
- Add not_decompiled_with_version filter

### 🐛 Bug Fixes

- Fix paging params

- Fix view

- Fix tests

- Fix dialyzer

- Fix converting to integer

- Fix average block time calculation

- Fix failing in rpc if balance is empty

- Fix test

- Fix build

- Fix CHANGELOG entry

- Fix current selected tab for decompiled code

- Fix mobile dropdown menu

- Fix gettext and credo


## [1.3.8-beta] - 2019-03-27

### 🚀 Features

- Add listcontracts endpoint

### 🐛 Bug Fixes

- Fix dialyzer

- Fix credo

- Fix tests

- Fix named arguments in code compiler

- Fix view test

- Fix color for release link

- Fix gettext

- Fix second typo

- Fix typo


## [1.3.7-beta] - 2019-03-20

### 🐛 Bug Fixes

- Fix gettext


## [1.3.6-beta] - 2019-03-19

### 🚀 Features

- Rpc address to list addresses
- Allow setting different configuration just for realtime fetcher

### 🐛 Bug Fixes

- Fix tests

- Fix credo

- Fix merge conflicts

- Fix build

- Fix typo

- Fix usd fee

- Fix tests

- Fix tests

- Fix usd value on address page


## [1.3.5-beta] - 2019-03-14

### 🚀 Features

- Add an admin method to import contract methods.
- Decoding candidates for unverified contracts
- Remove dropped/replaced transactions in pending transactions list
- Allow decoding input as utf-8
- Optimize/rework `init` for replaced transactions fetcher

### 🐛 Bug Fixes

- Fix gettext

- Fix test coverage

- Render a nicer error when creator cannot be determined
- Fix check formatted test

- Fix XSS

- Fix check_formatted test

- Fix view test

- Fix view tests

- Fix view

- Fix scheduling of latest block polling in Realtime Fetcher

Timer is set using Elixir's `Process.send_after/3` method, which is incompatible with Erlang's `:timer` module.
Thus, `:timer.cancel` doesn't have any effect on it, and in fact returns `{:error, :badarg}`.
This causes more and more polling being scheduled after every websocket event, which might cause excessive flooding of a node with `eth_getBlockByNumber` requests after some running time.

- Fix test that depended on date

- Fix test

- Fix dialyzer

- Resolve flaky tests via sequential builds
- Fix gettext

- Fix view method

- Fix comment
- Fix coin balance params reducer for pening transaction

- Fix bootstap build

- Fix bootstrap vulnerability

- Fix test that fails every 1st day of the month

- Constructor_arguments must be type `text`
- Fix build

- Fix credo

- Fix timeout for task

- Fix install instructions
- Fix credo for temp module

- Fix credeo, add query timeout

- Fix query

- Fix  query, add test

- Configure BLOCKSCOUT_VERSION in a standard way
- Fix credo

- Resolve lodash security alert

### 📚 Documentation

- Remove 1.7.1 version pin FROM bitwalker/alpine-elixir-phoenix

## [1.3.4-beta] - 2019-02-20

### 🚀 Features

- Show an approximation of transaction time

### 🐛 Bug Fixes

- Add coin_balance_status to address_validations
- Fix dialyzer

- Fix constructor arguments migration


## [1.3.3-beta] - 2019-02-15

### 🚀 Features

- Make replaced transactions disabled
- Synchronously fetch coin balances when an address is viewed.

### 🐛 Bug Fixes

- Cleanup uncataloged fetcher query, and push_front
- Fix gettext

- Fix nil input data

- Fix verifier, add tests

- Fix cardinality error issue

- Fix html tests

- Fix compilation warning


## [1.3.2-beta] - 2019-02-04

### 🐛 Bug Fixes

- Import clique genesis blocks
- Fix block reward styling on Mobile

- Fix external 2

- Fix remaining tests

- Fix receipts for pending transactions

- Fix block_hash is null statement

- Fix formatting

- Fix typo


### 📚 Documentation

- Conditionally change coin name in gettext via env
- Install missing python dependency
- Pin bitwalker/alpine-elixir-phoenix to image version 1.7.1

## [1.3.0-beta] - 2019-01-26

### 🚀 Features

- Add a minimum polling interval to protect from overrun
- Render addresses according to eip-55
- Better footer, configurable network list
- Add alt tags to logos
- Allow deferring js to specific pages
- Render block time with up to one decimal point of accuracy
- Store average block time in a genserver
- Restart on heartbeat timeout

### 🐛 Bug Fixes

- Fix dialyzer

- Don't reload every page
- Fix map access keys

- Fix migration

- Fix CR issues

- Fix compilation warnings

- Fix supervisor names

- Fix tests

- Fix compilation warnings

- Fix Code.Fetcher

- Add height for footer logo
- Fix dialyzer

- Fix address extraction for codes parameters

- Fix credo

- Fix parity and geth json rpc tests

- Fixup! fixup! fix: poll on import completion and only new blocks

- Fixup! fix: poll on import completion and only new blocks

- Poll on import completion and only new blocks
- Fix tests of transactions on non-consensus blocks

Tests for BlockTransactionController mistakenly simulated transactions
on non-consensus blocks by making the `transaction.block` `consensus`
`false`, but this is unrealistic - the importing only sets the consensus
block to `transaction.block` and non-consensus blocks show up as
`transaction.transaction_forks` `transaction_fork.uncle`.  To prevent
this from happening again, `Explorer.Factory.with_block` now checks the
`block` has `consensus: true`.  With this setup fixed, the tests needed
to be updated to show that *no* _transactions_ would be shown for
non-consensus blocks (because there are only transactions forks) and
whether the non-consensus blocks showed as "above tip" only had to do
with the number being above the consensus number and not to do with it
being non-consensus.

Floki selectors are used to improve error messages when messages are
unexpected.

- Fix sigil formatting

- Fix CR issues

- Variable quantity is unused
- Fixes for ganache JSON RPC mistakes

- Fix test to expose #1277

- Fix assert in test

Unused variable warning was an indication that the `assert` was
rebinding the variable and `^` was missing.  Rewritten to inline the
expected value for better error message from `assert`.

- Fix 'DBConnection.OwnershipError' in feature tests.

* Add sandbox config to shared mode when test is async false.

- Fix frontend tests

- Update spandex for run time config
- Fix missed pinning

Showed up as unused variables

- Fix picking wrong clause for fetch_token_balances_from_blockchain

Fixes #1215

The short-circuiting `[]` was not being used.

- Fix Address Trasaction query

* When we removed the Transaction dynamic query in favor of a union approach, we removed the guarantee we had with the joins and the subquery.

* The bug was that only the first transaction that had token transfers was being shown.

- Fix realtime indexer's 'no skips prevention' bug

Why:

* For the realtime indexer's logic that fills in skipped block numbers
to account for reorgs. See issue for details and examples.
* Issue link: https://github.com/poanetwork/blockscout/issues/1189

This change addresses the need by:

* Editing the realtime fetcher to keep track of the max block number
seen.
* Editing realtime fetcher's `start_fetch_and_import` function to only
fill in for skipped block numbers when the block number received from
the `newHeads` subscription is not a reorg. A reorg in this case is
defined as a block number that is less than or equal to the max block
number the realtime fetcher has seen.
* Editing realtime fetcher's `fetch_and_import_block` function to wait 5
seconds if the block number given for it to fetch is a reorg. This is
useful to improve the chance that the latest fetched block for a given
number gets consensus. E.g. when goerli's `newHeads` sends two identical
block numbers at virtually the same time: `100, 101, 101, 102, 103`, we
want to increase the chance taht the second attempt at fetching 101 gets
consensus.

- Fix displayed address length

- Fix blocks validated page to show all tabs

* Add to blocks validated use the "address/_tabs.html" partial
* Add to "address/_tabs.html" considers if block validated page is the current page
* Add tests to ensure all behavior above.

- Fix realtime indexer's 'no skips prevention' bug

Why:

* For the realtime indexer's logic that fills in skipped block numbers
to account for reorgs. See issue for details and examples.
* Issue link: https://github.com/poanetwork/blockscout/issues/1189

This change addresses the need by:

* Editing the realtime fetcher to keep track of the max block number
seen.
* Editing realtime fetcher's `start_fetch_and_import` function to only
fill in for skipped block numbers when the block number received from
the `newHeads` subscription is not a reorg. A reorg in this case is
defined as a block number that is less than or equal to the max block
number the realtime fetcher has seen.
* Editing realtime fetcher's `fetch_and_import_block` function to wait 5
seconds if the block number given for it to fetch is a reorg. This is
useful to improve the chance that the latest fetched block for a given
number gets consensus. E.g. when goerli's `newHeads` sends two identical
block numbers at virtually the same time: `100, 101, 101, 102, 103`, we
want to increase the chance taht the second attempt at fetching 101 gets
consensus.

- Fix realtime address balance update

The balance update stopped working because the client was trying to
subscribe twice in the channel topic. When the server receives a
duplicated subscription, he closes the first connection to open a new
one.

In our case, the client subscribed in the address channel in address.js
and again address/transactions.js, then the server was keeping only the
last subscription.

- Fix the tests

- Fix test

- Fix randomly failing test

- Match more explicitly on ABI decoding result
- Fix controller tests


### 🚜 Refactor

- Refactor transaction tile identifier

Now both transactions and emission rewards must be in the same list, so
I changed the identifier to a more generic name to contemplate both of
cases.

- Refactor transactions page

As we did in other pages, we removed the infinite scroll and make the
first load async.

- Refactor address.js to use async_load_listing redux


### 📚 Documentation

- Document Explorer.Chain.SmartContract

Fixes #1342

Document `t:Explorer.Chain.SmartContract.t/0` to clarify difference
between `t:Explorer.Chain.SmartContract.t/0` `contract_source_code` and
`t:Explorer.Chain.Address.t/0` `contract_code`.

Include Solidity ABI Spec docs so domain knowledge is available with the
source.


## [1.2.1-beta] - 2018-12-03

### 🚀 Features

- Support tracing via spandex

### 🐛 Bug Fixes

- Fix pagination on inventory tab at Token's page

This code was removed and it shouldn't :(. Besides bringing this code
back, I'm adding tests in the controller layer to make sure that it will
not happen anymore.

- Fix pages broken by previous commit

- Fix token transfers' tests

- Fix core tests

- Fix typo in "validation count" redux when loading state.

- Fix the tests

this test was breaking because it started from the async page that was
very unstable and the element wasn't being found by the driver even
though it works correctly on a normal browser so I made it change the
starting point to a page that is no async and skipping the "click on the
tab step"


### 🚜 Refactor

- Refactor JS for async load

- Refactor controller and template for async load

- Refactor async listing load to use redux

- Refactor template for first page async load

- Refactor token transfers' pagination

We changed the token transfer's pagination uses the block_number instead
of the inserted_at. It will make the pagination consistent since the
list is sorted by the block_number.


## [1.2.0-beta] - 2018-11-21

### 🚀 Features

- Fix ABI decodding, and decode tx logs
- Decode transaction input on overview

### 🐛 Bug Fixes

- Fix credo and format issues

- Fix reducer function on metadata updater

It was concatenating the result in the reverse order.

- Handle case where contract is not verified
- Fix warning

- Fix typo

= instead of == in assert

- Fix pattern matching error when transaction does not loads to_address.smart_contract

- Fix project timeline link on README

- Fix heading
- Fix loading of secrets file for test

- Fix performance issue in address page

- Fix layout test

- Fix no schema on GraphiQL

Why:

* For the schema to be available at `/graphiql`
* Issue link: https://github.com/poanetwork/blockscout/issues/1042

This change addresses the need by:

* Changing GraphQL `max_complexity` from 50 to 200 for introspection to
be possible on GraphiQL.
* Editing test that relied on a `max_complexity` of 50.

- Fixup test cases

- Fixup test cases

- Fix address[] display when reading Smart Contracts

- Fix channel disconnected and batching messages

- Fixes the topics order in the gettxinfo endpoint

- Fixes broken test

- Fix rich list tiles on mobile

- Fix block label alignment on tablet

- Fix transaction input code layout and style

- Fix navbar link hover state on mobile

- Fix ping/pong from ganache ws implementation

- Fix read contract response layout

- Fixed mobile search bar and network ui bug


### 🚜 Refactor

- Refactor metadata_updater to get interval on start

- Refactor cataloged token query to Chain.Token

- Refactor Indexer.Token.Fetcher

This refactor aims to remove the responsability of reading functions
from the Smart Contract from Token.Fetcher. Now, we have the module
Explorer.Token.FunctionsReader that is responsible for it.

- Refactor message building from controller to view


### ⚡ Performance

- Performance improvements to generation of top accounts page

The list_top_addresses query is now a left join of addresses and transactions tables,
returning the top 250 address and their respective transaction counts at the same time.

The call to transaction_count() which hits the database has been removed from the per account tile template,
and the value is now passed in from the above query.

balance_percentage/2() has been added, taking total_supply as an argument rather than querying the database.
The per account tile template now uses this version, with total_supply queried once and passed in.

It may be worth adding an index to the addresses table i.e.
create index addresses_fetched_coin_balance_hash_index on addresses (fetched_coin_balance desc nulls last, hash asc);

Note the list_top_address query makes use of a SQL fragment as the version of Ecto used by blockscout does not support coalesce.


### ⚙️ Miscellaneous Tasks

- Gettext
- Privatize function and fix indentation
- Do_copy_text -> defp
- Gettext
- Remove comments
- Gettext
- Hide decoded input for transfers/contract creations
- Cleanup, error handling, tests
- Refactor/clean up and improve visuals
- Dialyzer
- Improve test coverage
- Format
- Resolve credo warnings
- Gettext
- Fix unused var warning
- Gettext
- Format

## [1.1.0-beta] - 2018-10-26

### 🐛 Bug Fixes

- Sleep when throttled to prevent stampedes
- Fix error when indexing Wanchain

Why:

* When attempting to index Wanchain we were seeing this error:
  ```
  ** (FunctionClauseError) no function clause matching in
  EthereumJSONRPC.Transaction.entry_to_elixir/1
  (ethereum_jsonrpc) lib/ethereum_jsonrpc/transaction.ex:260:
  EthereumJSONRPC.Transaction.entry_to_elixir({"txType", "0x1"})
  ```

  After looking into this it looks like Wanchain returns a "txType" of 1
  for normal transactions and 6 for privacy transactions. It's not clear
  at this time if this is something we want BlockScout to keep track of so
  we'll be ignoring it for now.
* Issue link: https://github.com/poanetwork/blockscout/issues/994

This change addresses the need by:

* Editing `EthereumJSONRPC.Transaction.entry_to_elixir/1` to accept a
key of "txType" without generating a `FunctionClauseError`.

- Fix topnav dropdown link hover state

- Fix divide-by-zero error in indexed_ratio

Dividing by `max_block_number` assumes it is 1-based, but it is 0-based,
so add 1.

- Fix typo

- Fix mix formatting

- Fix InternalTransaction listing page by removing transaction fields.

- Fix ping/pong from ganache ws implementation

- Fix tests

- Fix merge conflict in address.js

Co-authored-by: Stamates <stamates@hotmail.com>

- Fix the Address page to count only transactions sent

- Fix formatting

- Fix spacing

- Fixes for pr comments

- Fixes for ganache integration

- Fixed validation count bug on address page.

address.js
When the page loaded, the number of validations was being set to the
number of transactions.

remove logging in address.js

- Fix text color in address balance

- Fix the fixes

- Fix dashboard chart legend colors


### 🚜 Refactor

- Refactor link to allow for updatable counter
- Refactor transactions count by address

Now, the app is going to count how many transactions an specific address
has sent instead of an estimated count.

The reasons why we are doing that are:
- we have a inaccurate count (bad user experience)
- it's slower

As we already store the nonce when the app index transactions, we can
query this value by address to know how many transactions the address
has sent.


## [1.0-beta] - 2018-10-11

### 🚀 Features

- Feature testing

- Feature tests should always work async


### 🐛 Bug Fixes

- Fix text on Block Mined (includes I18n)
- Fix a z-index issue with the network selection menu

- Fix channel event name for chain transactions.
- Fix issue with channel connection on transactions

- Fix intro animation fill mode

- Fix dropdown buttons that are not in the navbar

- Fix gettext bug on Contract's Code page

- Fix queries.

Update chain queries and created tests for mentioned queries.

- Fix token balance log error

We inverted the value of address_hash with the contract_address_hash.
This commit fixes that.

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fixed merge conflict and fixed number formatting

- Fix token holders' tab at the Token's page

This page was breaking when the given Token has the total supply nil.

To fix that, we added a view function to check if we should show the
total supply percentage. Since we want to display just for Tokens that
have total supply, we are ignoring for the ones that don't have.

- Fix pagination button in Address Token's tab

- Fix failing UI tests

- Fix button states

- Fix transaction not having IN/OUT on live update due to misnamed variable.

- *(ci)* Gas_limit and gas_used is decimal
- *(apps)* Adjust gas_used to Decimal
- *(explorer)* Gas_used/gas_limit should be numeric, not int
- Fix Token Holders' link from Read Smart Contract page

We used conn.params['id'] instead of conn.params['token_id']. To fix it
I'm changing to use `@token.contract_address_hash` for it doesn't depend
from URL params anymore.

- Fix div overflow in Smart Contract's page.

- Fix tab-menu active style in Read Contract's page

We displayed the Read Contract's tab and Token Holder's tab as active
style instead of just the first one.

- Fix bullets
- Fix bullet points

- Fix explorer test

- Fix small mistake of addin mr-4 to a data attribute

- Fix token balances' query

This query was considering the next-to-last token balance when the last
one had the value 0.

In order to this work properly, I'm moving the query that gets token
balances from the last block to a sub-query and moving the condition to
consider just values greater than 0 to the main query.  This way we are
sure that we always are considering the last block and we are skipping
the ones that have the value equal to 0.

- Fixed weird margin on input
- Fix copy contract source code tooltip text

- Fix broken tests

Co-authored-by: Luke Imhoff <luke.imhoff@dockyard.com>

- Fix circle test reporting

Co-authored-by: Stamates <stamates@hotmail.com>
Co-authored-by: Luke Imhoff <luke.imhoff@dockyard.com>

- Fix channel issues
- Fix padding on token transfer tile for token page

- Fix older/newer pagination button inconsistencies

- Fix spacing on account page pagination

Fixes #515

- Fix height container on transactions

Fixes #627

- Fix dialyzer

- Fixed the space between logo and links in navbar to be consistent based off the themed logo
- Fixed some styling bugs 
- Fix cards height on address overview

- Fix real-time events on AWS

- Fix dropdown hover bg color

- Fix trace url

- Fix test

- Fix format_according_to_decimals to considers thousands separator

- Fix flaky hashes_to_transactions tests (non-ordered results)
- Fix catchup_block_number not being set

catchup_block_number can't be set in state because it is set in a
separate task, so have the Task return it instead of storing it in a
state field.

- Fix Token Transfer factory

- Fix transaction addresses wrapping onto two lines

- Fix formatting

- Fixed test on transaction log page
- Fix phrasing when genesis task completes

- Fix typo

- Fix social media links

Fixes #450

- Fix prod config file to use prod config instead of dev

- Fix issue with balance card live update styling
- Fixed text for the changes made on block details
- Fix typo in etheream_jsonrpc_test.exs

Rename it to ethereum_jsonrpc_test.exs

- Fix dropdown overlaps on homepage.

- Fix chunk_range/3 for descending ranges

- Fix off-by-1 errors in chunk_ranges

- Fix Indexer Supervisor three

We are facing this error when starting the `Indexer`:
```
    ** (EXIT) an exception was raised:
        ** (ArgumentError) :json_rpc_named_arguments must be provided to
          `Elixir.Indexer.InternalTransactionFetcher.child_spec to allow for json_rpc calls when running.
```

It was missing the `json_rpc_named_arguments` to InternalTransactionFetcher children.

- Fix the tests
- Fix {:error, :not_found} when starting indexer

- Fix multiple results in Repo.One with multiple create type internal transactions
- Fix tests and formatting
- Fix ERC20 token support
- Fix webpack-cli vulnerability

- Fixed search input test 
- Fixed footer to the bottom 
- Fix search bar focus state and sizing

- Fix tests to use new factory setups (not associating based on hash)
- Fix Address contract_code in InternalTransactionFetcher

- Fixed top nav links color and margin 
- Fix typespecs, handle default keyword list options cleanly, check inputs

Co-authored-by: Stamates <stamates@hotmail.com>

- Fix typo

- Fix tests broken by rebase

- Fix typo

- Fix html formatting

- Fix js lint errors

- Fixed z index on header
- Fix assertion
- Fix remaining controller tests that were failing from frontend redesign
- Fixed the margins on the data chart on the homepg
- Fixed social media links on sidebar 
- Fixed margin on the graph for mobile 
- Fix flaky tests

Don't match against `Statistics.fetch()` since the `%Statistics{}` from
`Server.init` was previously changed to be empty to prevent `Statistics.fetch`
from timing out `init` and killing the whole supervision tree and then
VM.

- Fix dialyzer warnings

- Fix accidental delegate variable character deletion

- Fix unclosed ` in docs

- Fix tests that were accounting for the old smaller window

- Fix dialyzer warnings

- Fix dialyzer warnings

- Fix “from” and “to” order on transaction show internal transactions page
- Fix internal transaction indexes

- Fix dialyzer warnings

- Fix unknown types for dialyzer

- Fixed another width issue for header
- Fixed the container size for the header size 
- Fix footer to bottom and other css tweaks
- Fix gettext and eslint

- Fix tests

Co-authored-by: jimmay5469 <jimmay5469@gmail.com>

- Fixed margins on container 
- Fix credo for Sokol full changes

- Fix tests for Sokol full changes

- Fix https://github.com/poanetwork/poa-explorer/issues/112

Co-authored-by: jimmay5469 <jimmay5469@gmail.com>
- Fix CircleCI configuration for sobelow

Co-authored-by: jimmay5469 <jimmay5469@gmail.com>

- Fix HTML formatting

- Fix deploy by persisting .circleci to workspace

Fixes `bash: .circleci/setup-heroku.sh: No such file or directory`

- Fix README to describe running without iex

- Fix a README setup instructions

- Fix typo in readme
- Fix some issues with Credo and Dialyzer.

- Fix 404 behavior

- Fix the fork url in README.md


### 🚜 Refactor

- Refactor block tile partial and fix import transition on homepage

- Refactor to replace any block that matches the new block received

- Refactor view to use configured envs

Since we have different networks, this commit allows us to use the
information below from the environmnet:

* network title
* subnetwork title
* network icon
* network logo

If those configurations are not set in the env, we are going to use the
default from POA.

- Refactor Token's page controller

We are refactoring this controller to follow the same pattern that we
have been using in the Address's page and Transaction's page since it
uses the same approach.

This way, we can use a generic helper to deal with tabs.

- Refactor address rendering functions and add test coverage
- Refactor button class names

- Refactor block and transaction details overview layout to align cards

- Refactor Token Balances dropdown to use database

- Refactor 'Read Smart Contract' functionality to be via AJAX

- Refactor 'tokens' to be inside a namespace

* Moved token related files under 'tokens' namespace;
* Created 'tokens/overview/details' partial with the tokens header information;
* Add 'tokens/read_contract_controller.ex';

- Refactor import test
- Refactor identical transaction tiles to single partial

Co-authored-by: Stamates <stamates@hotmail.com>

- Refactor transaction list partial on homepage

Co-authored-by: Stamates <stamates@hotmail.com>

- Refactor block list partial on homepage

Co-authored-by: Stamates <stamates@hotmail.com>

- Refactor transaction element to fit on mobile sized screens

- Refactor internal transaction elements to avoid text wrapping

- Refactor navbar link hover state

- Refactor icon link component

- Refactor address page using redux

- Refactor batch function

Co-authored-by: Stamates <stamates@hotmail.com>

- Refactor how we recognize routes

Co-authored-by: Stamates <stamates@hotmail.com>

- Refactoring of css/html & removing code
- Refactor footer elements

- Refactor to fix dialyzer failures
- Refactor query for better performance

Co-authored-by: Stamates <stamates@hotmail.com>

- Refactor sidebar for maintainability   


Co-authored-by: kspohlman <katie@gaslight.co>
- Refactor sidebar for maintainability   


Co-authored-by: kspohlman <katie@gaslight.co>
- Refactor the Total Counts for Transaction Indexes

Counting 10 million rows takes a while. Use a shortcut.
- Refactor AddressForm join for balances


### 📚 Documentation

- Document AddressExtraction.extract_addresses

- Document reducers in Explorer.Chain

* Check that function is 2-arity in guard also


<!-- generated by git-cliff -->
