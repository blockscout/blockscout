# Changelog

All notable changes to this project will be documented in this file.

## [unreleased]

### 🚀 Features

- Super-mega-important-feature

### 🐛 Bug Fixes

- Super mega important fix

### ⚙️ Miscellaneous Tasks

- Something fixed

## [6.3.0-beta] - 2024-03-18

### 🚀 Features

- Stream blocks without internal transactions backwards

### ⚙️ Miscellaneous Tasks

- Changelog
- Remove repetitive words
- Fix some comments

## [6.2.1-beta] - 2024-02-29

### 🐛 Bug Fixes

- Not found page for unknown blobs

### ⚙️ Miscellaneous Tasks

- Changelog

## [6.2.0-beta] - 2024-02-28

### 🚀 Features

- Blobs migrations and api
- Add blobs fetcher
- Add basic blob fetcher tests
- Add burn blob fee in tx view
- Blobs in search

### 🐛 Bug Fixes

- Format
- Tests
- Fmt and test config
- Review refactor
- Fmt
- Hide doctest behind chain type
- Tests
- One more test
- Too many connections in tests
- More review comments
- Transaction blobs order in API
- Linter

### ⚙️ Miscellaneous Tasks

- Refactor
- Docstrings and broken tests
- Update default values
- Try to fix connection timeout
- Update env defaults
- Move blob function out of chain.ex
- Bump actions/cache to v4 (#9393)

### Noves.fi

- Add proxy endpoint for describeTxs endpoint (#9351)

## [6.1.0-beta] - 2024-02-05

### ⚙️ Miscellaneous Tasks

- Equalize elixir stack versions

### Plt_add_deps

- From :transitive to :app_tree

## [5.3.3-beta] - 2023-12-11

### Smart-contract

- Delete embeds_many relation on replace

## [5.3.1-beta] - 2023-10-26

### Account

- Add pagination + envs for limits (#8528)

## [5.3.0-beta] - 2023-10-20

### Dependabot

- Ignore bootstrap updates, interval update from daily to weekly

### Dependabot

- Ignore web3 4.x

## [5.2.2-beta] - 2023-08-17

### CI

- Prerelease -> postrelease

## [5.2.0-beta] - 2023-06-20

### Account

- Check composed email beofre sending

## [5.1.5-beta] - 2023-05-18

### Fix

- Cannot read properties of null (reading 'value')

## [5.1.4-beta] - 2023-04-27

### Account

- Derive Auth logout urls from existing envs

## [5.1.0-beta] - 2023-02-13

### Docker-compose

- Increase max connections and db pool size

## [5.0.0-beta] - 2023-01-11

### Account

- Add Custom ABI feature
- Add public tags
- Add API for interaction with front-end
- Refactoring
- Add tags endpoints to API
- Add tests for API

## [4.1.7-beta] - 2022-08-04

### RELEASE_VERSION

- 4.1.6

## [4.1.6-beta] - 2022-08-02

### Graphql

- Add user-selected ordering to transactions for address

## [4.1.3-beta] - 2022-05-05

### Besu

- RevertReason support in trace

### CI

- Build and push Docker image to Docker Hub

### Geth

- Display tx revert reason

### Makefile

- Find exact container by name

## [4.1.0-beta] - 2021-12-29

### Web3Modal

- GetNetId function refactoring

### Web3modal

- Minor fixes

## [4.0.0-beta] - 2021-11-09

### ERC-1155

- Token balanaces indexer update
- Fix indexer

### Finalize

- Check if exists custom_cap property of extended token object before access it

### Optimiation_runs

- Int4 -> int8

## [3.7.1-beta] - 2021-07-09

### Refactoring

- Replace inline style display: none with d-none class

### Typo

- Constructor instead of contructor

## [3.6.0-beta] - 2021-03-26

### Hotfix

- Exclude Sushiswap LP tokens TLV in USD
- Exclude Sushiswap LP tokens TLV in USD
- Token1() method signature

## [3.5.1-beta] - 2021-01-12

### DarkForest

- Apply theme to token instance, differentiate versions of DF

## [3.3.3-beta] - 2020-10-02

### Refactoring

- Handle empty array type input

## [3.3.2-beta] - 2020-08-24

### XDai

- Do not apply link style for buttons

## [3.3.1-beta] - 2020-08-03

### Besu

- Add revertReason key

### GraphQL

- Fix innternal server error at request of internal transactions at address

## [3.1.3-beta] - 2020-06-05

### Inventory

- Distinct: [desc: tt.token_id]

### Verification

- Check compiler version

## [3.1.2-beta] - 2020-05-08

### Version

- Bump 3.1.2

## [2.1.1-beta] - 2019-11-27

### Fix

- Remove outer container of transaction-count if there is no value

## [2.0.4-beta] - 2019-09-06

### Hotfix

- Ethereum-mainnet network icon preload

### Hotfix

- Missing vars for non-critical styles
- Missing ethereum-mainnet.png for networks selector

## [2.0.2-beta] - 2019-07-25

### 🐛 Bug Fixes

- External library is only for verified contract

### 📚 Documentation

- Pin bitwalker/alpine-elixir-phoenix:1.9.0

## [2.0.1-beta] - 2019-07-03

### 🚀 Features

- Eth_get_balance rpc endpoint
- Add eth_getLogs rpc endpoint
- Add eth_getLogs rpc endpoint
- Document eth rpc api mimicking endpoints
- Calculate RSK market cap
- Add BLOCKSCOUT_HOST, and use it in API docs

## [2.0.0-beta] - 2019-06-04

### 🚀 Features

- Show raw transaction traces
- Add on demand fetching and stale attr to rpc
- Exclude empty contracts by default
- Display init for selfdestructed contracts.
- Add fields to tx apis, small cleanups

### 🐛 Bug Fixes

- Logs list endpoint performance
- Store solc versions locally for performance
- Resolve false positive constructor arguments
- Split constructor args for verification
- Remove source code fields from list endpoint
- Consolidate address w/ balance one at a time
- Support https for wobserver polling
- Add fields for contrat filter performance
- Fix to/from filters on tx list pages
- Use better queries for listLogs endpoint
- Use better queries for listLogs endpoint
- Show creating internal transactions
- Uniq by hash, instead of transaction

### 📚 Documentation

- Always set a container name

### 🧪 Testing

- Fix an order of chains in the list
- Missing semicolon

### CHANGELOG

- #2000 - docker/Makefile: always set a container name

### README.md

- Add blocks.ether1.wattpool.net for Ether-1

## [1.3.11-beta] - 2019-04-26

### 🚀 Features

- Verify contracts with a post request
- Verify contracts with a post request (#1806)

### 🐛 Bug Fixes

- Ignore  messages without error

## [1.3.10-beta] - 2019-04-22

### 🚀 Features

- Add RSK support
- Slightly more informative json rpc error messages + logging
- Set a ping_interval from config, defaulting to 300 seconds

### 📚 Documentation

- Fix dockerFile for secp256k1 building

## [1.3.9-beta] - 2019-04-09

### 🚀 Features

- Add not_decompiled_with_version filter
- Verify contracts via an RPC endpoint

## [1.3.8-beta] - 2019-03-27

### 🚀 Features

- Add listcontracts endpoint

## [1.3.6-beta] - 2019-03-19

### 🚀 Features

- Allow setting different configuration just for realtime fetcher
- Rpc address to list addresses

## [1.3.5-beta] - 2019-03-14

### 🚀 Features

- Optimize/rework `init` for replaced transactions fetcher
- Allow decoding input as utf-8
- Remove dropped/replaced transactions in pending transactions list
- Decoding candidates for unverified contracts
- Add an admin method to import contract methods.

### 🐛 Bug Fixes

- Resolve lodash security alert
- Configure BLOCKSCOUT_VERSION in a standard way
- Constructor_arguments must be type `text`
- Resolve flaky tests via sequential builds
- Render a nicer error when creator cannot be determined

### Dockerfile

- Remove 1.7.1 version pin FROM bitwalker/alpine-elixir-phoenix

## [1.3.4-beta] - 2019-02-20

### 🚀 Features

- Show an approximation of transaction time

### 🐛 Bug Fixes

- Add coin_balance_status to address_validations

## [1.3.3-beta] - 2019-02-15

### 🚀 Features

- Synchronously fetch coin balances when an address is viewed.
- Make replaced transactions disabled

### 🐛 Bug Fixes

- Cleanup uncataloged fetcher query, and push_front

## [1.3.2-beta] - 2019-02-04

### 🐛 Bug Fixes

- Import clique genesis blocks

### Dockerfile

- Pin bitwalker/alpine-elixir-phoenix to image version 1.7.1
- Install missing python dependency
- Conditionally change coin name in gettext via env

## [1.3.0-beta] - 2019-01-26

### 🚀 Features

- Restart on heartbeat timeout
- Store average block time in a genserver
- Render block time with up to one decimal point of accuracy
- Allow deferring js to specific pages
- Add alt tags to logos
- Better footer, configurable network list
- Render addresses according to eip-55
- Add a minimum polling interval to protect from overrun

### 🐛 Bug Fixes

- Match more explicitly on ABI decoding result
- Update spandex for run time config
- Poll on import completion and only new blocks
- Add height for footer logo
- Don't reload every page

### Fix

- Variable quantity is unused

## [1.2.1-beta] - 2018-12-03

### 🚀 Features

- Support tracing via spandex

## [1.2.0-beta] - 2018-11-21

### 🚀 Features

- Decode transaction input on overview
- Fix ABI decodding, and decode tx logs

### 🐛 Bug Fixes

- Handle case where contract is not verified

### ⚙️ Miscellaneous Tasks

- Format
- Gettext
- Fix unused var warning
- Gettext
- Resolve credo warnings
- Format
- Improve test coverage
- Dialyzer
- Refactor/clean up and improve visuals
- Cleanup, error handling, tests
- Hide decoded input for transfers/contract creations
- Gettext
- Remove comments
- Gettext
- Do_copy_text -> defp
- Privatize function and fix indentation
- Gettext

## [1.1.0-beta] - 2018-10-26

### 🐛 Bug Fixes

- Sleep when throttled to prevent stampedes

### WIP

- Add rolling window rate limiter + retry logic
- Generalize rolling window
- Rolling window event counter.
- Request coordinator + starting rolling window
- Application + request coordinator cleanup
- Clean up request coordinator with functionality and docs
- Finish/clean up rolling window tracker
- Test rolling window and request coordinator

## [1.0-beta] - 2018-10-11

### /blocks/

- Id works with number or hash now

### 🐛 Bug Fixes

- *(explorer)* Gas_used/gas_limit should be numeric, not int
- *(apps)* Adjust gas_used to Decimal
- *(ci)* Gas_limit and gas_used is decimal

### {

- Ok, nil} -> {:error, :not_found} in handle_get_block_by_tag

<!-- generated by git-cliff -->
