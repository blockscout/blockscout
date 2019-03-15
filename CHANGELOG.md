## Current

### Features

### Fixes

### Chore

## 1.3.5-beta

### Features

 - [#1560](https://github.com/poanetwork/blockscout/pull/1560) - Allow executing smart contract functions in arbitrarily sized batches
 - [#1543](https://github.com/poanetwork/blockscout/pull/1543) - Use trace_replayBlockTransactions API for faster tracing
 - [#1558](https://github.com/poanetwork/blockscout/pull/1558) - Allow searching by token symbol
 - [https://github.com/poanetwork/blockscout/pull/1551](https://github.com/poanetwork/blockscout/pull/1551) Exact date and time for Transaction details page
 - [https://github.com/poanetwork/blockscout/pull/1547](https://github.com/poanetwork/blockscout/pull/1547) - Verify smart contracts with evm versions
 - [https://github.com/poanetwork/blockscout/pull/1540](https://github.com/poanetwork/blockscout/pull/1540) - Fetch ERC721 token balances if sender is '0x0..0'
 - [https://github.com/poanetwork/blockscout/pull/1539](https://github.com/poanetwork/blockscout/pull/1539) - Add the link to release in the footer
- [https://github.com/poanetwork/blockscout/pull/1519](https://github.com/poanetwork/blockscout/pull/1519) - Create contract methods
 - [https://github.com/poanetwork/blockscout/pull/1496](https://github.com/poanetwork/blockscout/pull/1496) - Remove dropped/replaced transactions in pending transactions list
 - [https://github.com/poanetwork/blockscout/pull/1492](https://github.com/poanetwork/blockscout/pull/1492) - Disable usd value for an empty exchange rate
 - [https://github.com/poanetwork/blockscout/pull/1466](https://github.com/poanetwork/blockscout/pull/1466) - Decoding candidates for unverified contracts

### Fixes
 - [https://github.com/poanetwork/blockscout/pull/1545](https://github.com/poanetwork/blockscout/pull/1545) - Fix scheduling of latest block polling in Realtime Fetcher
 - [https://github.com/poanetwork/blockscout/pull/1554](https://github.com/poanetwork/blockscout/pull/1554) - Encode integer parameters when calling smart contract functions
- [https://github.com/poanetwork/blockscout/pull/1537](https://github.com/poanetwork/blockscout/pull/1537) - Fix test that depended on date
- [https://github.com/poanetwork/blockscout/pull/1534](https://github.com/poanetwork/blockscout/pull/1534) - Render a nicer error when creator cannot be determined
- [https://github.com/poanetwork/blockscout/pull/1527](https://github.com/poanetwork/blockscout/pull/1527) - Add index to value_fetched_at
- [https://github.com/poanetwork/blockscout/pull/1518](https://github.com/poanetwork/blockscout/pull/1518) - Select only distinct failed transactions
 - [https://github.com/poanetwork/blockscout/pull/1516](https://github.com/poanetwork/blockscout/pull/1516) - Fix coin balance params reducer for pending transaction
 - [https://github.com/poanetwork/blockscout/pull/1511](https://github.com/poanetwork/blockscout/pull/1511) - Set correct log level for production
 - [https://github.com/poanetwork/blockscout/pull/1510](https://github.com/poanetwork/blockscout/pull/1510) - Fix test that fails every 1st day of the month
- [https://github.com/poanetwork/blockscout/pull/1509](https://github.com/poanetwork/blockscout/pull/1509) - Add index to blocks' consensus
 - [https://github.com/poanetwork/blockscout/pull/1508](https://github.com/poanetwork/blockscout/pull/1508) - Remove duplicated indexes
 - [https://github.com/poanetwork/blockscout/pull/1505](https://github.com/poanetwork/blockscout/pull/1505) - Use https instead of ssh for absinthe libs
 - [https://github.com/poanetwork/blockscout/pull/1501](https://github.com/poanetwork/blockscout/pull/1501) - Constructor_arguments must be type `text`
 - [https://github.com/poanetwork/blockscout/pull/1498](https://github.com/poanetwork/blockscout/pull/1498) - Add index for created_contract_address_hash in transactions
 - [https://github.com/poanetwork/blockscout/pull/1493](https://github.com/poanetwork/blockscout/pull/1493) - Do not do work in process initialization
 - [https://github.com/poanetwork/blockscout/pull/1487](https://github.com/poanetwork/blockscout/pull/1487) - Limit geth sync to 128 blocks
 - [https://github.com/poanetwork/blockscout/pull/1484](https://github.com/poanetwork/blockscout/pull/1484) - Allow decoding input as utf-8
 - [https://github.com/poanetwork/blockscout/pull/1479](https://github.com/poanetwork/blockscout/pull/1479) - Remove smoothing from coin balance chart

### Chore
 - [https://github.com/poanetwork/blockscout/pull/1532](https://github.com/poanetwork/blockscout/pull/1532) - Upgrade elixir to 1.8.1
- [https://github.com/poanetwork/blockscout/pull/1553](https://github.com/poanetwork/blockscout/pull/1553) - Dockerfile: remove 1.7.1 version pin FROM bitwalker/alpine-elixir-phoenix
- [https://github.com/poanetwork/blockscout/pull/1465](https://github.com/poanetwork/blockscout/pull/1465) - Resolve lodash security alert