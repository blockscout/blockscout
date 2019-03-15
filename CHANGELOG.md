## Current

### Features

### Fixes


## 1.3.5-beta

### Features

 - [#1560](https://github.com/poanetwork/blockscout/pull/1560) - Allow executing smart contract functions in arbitrarily sized batches
 - [#1543](https://github.com/poanetwork/blockscout/pull/1543) - Use trace_replayBlockTransactions API for faster tracing
 - [#1558](https://github.com/poanetwork/blockscout/pull/1558) - Allow searching by token symbol
 - [#1551](https://github.com/poanetwork/blockscout/pull/1551) Exact date and time for Transaction details page
 - [#1547](https://github.com/poanetwork/blockscout/pull/1547) - Verify smart contracts with evm versions
 - [#1540](https://github.com/poanetwork/blockscout/pull/1540) - Fetch ERC721 token balances if sender is '0x0..0'
 - [#1539](https://github.com/poanetwork/blockscout/pull/1539) - Add the link to release in the footer
 - [#1519](https://github.com/poanetwork/blockscout/pull/1519) - Create contract methods
 - [#1496](https://github.com/poanetwork/blockscout/pull/1496) - Remove dropped/replaced transactions in pending transactions list
 - [#1492](https://github.com/poanetwork/blockscout/pull/1492) - Disable usd value for an empty exchange rate
 - [#1466](https://github.com/poanetwork/blockscout/pull/1466) - Decoding candidates for unverified contracts

### Fixes
 - [#1545](https://github.com/poanetwork/blockscout/pull/1545) - Fix scheduling of latest block polling in Realtime Fetcher
 - [#1554](https://github.com/poanetwork/blockscout/pull/1554) - Encode integer parameters when calling smart contract functions
 - [#1537](https://github.com/poanetwork/blockscout/pull/1537) - Fix test that depended on date
 - [#1534](https://github.com/poanetwork/blockscout/pull/1534) - Render a nicer error when creator cannot be determined
 - [#1527](https://github.com/poanetwork/blockscout/pull/1527) - Add index to value_fetched_at
 - [#1518](https://github.com/poanetwork/blockscout/pull/1518) - Select only distinct failed transactions
 - [#1516](https://github.com/poanetwork/blockscout/pull/1516) - Fix coin balance params reducer for pending transaction
 - [#1511](https://github.com/poanetwork/blockscout/pull/1511) - Set correct log level for production
 - [#1510](https://github.com/poanetwork/blockscout/pull/1510) - Fix test that fails every 1st day of the month
 - [#1509](https://github.com/poanetwork/blockscout/pull/1509) - Add index to blocks' consensus
 - [#1508](https://github.com/poanetwork/blockscout/pull/1508) - Remove duplicated indexes
 - [#1505](https://github.com/poanetwork/blockscout/pull/1505) - Use https instead of ssh for absinthe libs
 - [#1501](https://github.com/poanetwork/blockscout/pull/1501) - Constructor_arguments must be type `text`
 - [#1498](https://github.com/poanetwork/blockscout/pull/1498) - Add index for created_contract_address_hash in transactions
 - [#1493](https://github.com/poanetwork/blockscout/pull/1493) - Do not do work in process initialization
 - [#1487](https://github.com/poanetwork/blockscout/pull/1487) - Limit geth sync to 128 blocks
 - [#1484](https://github.com/poanetwork/blockscout/pull/1484) - Allow decoding input as utf-8
 - [#1479](https://github.com/poanetwork/blockscout/pull/1479) - Remove smoothing from coin balance chart

### Chore
 - [https://github.com/poanetwork/blockscout/pull/1532](https://github.com/poanetwork/blockscout/pull/1532) - Upgrade elixir to 1.8.1
 - [https://github.com/poanetwork/blockscout/pull/1553](https://github.com/poanetwork/blockscout/pull/1553) - Dockerfile: remove 1.7.1 version pin FROM bitwalker/alpine-elixir-phoenix
 - [https://github.com/poanetwork/blockscout/pull/1465](https://github.com/poanetwork/blockscout/pull/1465) - Resolve lodash security alert