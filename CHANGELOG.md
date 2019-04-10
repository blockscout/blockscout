## Current

### Features

### Fixes

- [#1727](https://github.com/poanetwork/blockscout/pull/1727) - add logs pagination in rpc api

### Chore


## 1.3.9-beta

### Features

 - [#1704](https://github.com/poanetwork/blockscout/pull/1704) - Add new styles and "Stakes" page for POSDAO network
 - [#1662](https://github.com/poanetwork/blockscout/pull/1662) - allow specifying number of optimization runs
 - [#1654](https://github.com/poanetwork/blockscout/pull/1654) - add decompiled code tab
 - [#1661](https://github.com/poanetwork/blockscout/pull/1661) - try to compile smart contract with the latest evm version
 - [#1665](https://github.com/poanetwork/blockscout/pull/1665) - Add contract verification RPC endpoint.
 - [#1706](https://github.com/poanetwork/blockscout/pull/1706) - allow setting update interval for addresses with b

### Fixes

 - [#1669](https://github.com/poanetwork/blockscout/pull/1669) - do not fail if multiple matching tokens are found
 - [#1691](https://github.com/poanetwork/blockscout/pull/1691) - decrease token metadata update interval
 - [#1688](https://github.com/poanetwork/blockscout/pull/1688) - do not fail if failure reason is atom
 - [#1692](https://github.com/poanetwork/blockscout/pull/1692) - exclude decompiled smart contract from encoding
 - [#1684](https://github.com/poanetwork/blockscout/pull/1684) - Discard child block with parent_hash not matching hash of imported block
 - [#1699](https://github.com/poanetwork/blockscout/pull/1699) - use seconds as transaction cache period measure
 - [#1697](https://github.com/poanetwork/blockscout/pull/1697) - fix failing in rpc if balance is empty
 - [#1711](https://github.com/poanetwork/blockscout/pull/1711) - rescue failing repo in block number cache update
 - [#1712](https://github.com/poanetwork/blockscout/pull/1712) - do not set contract code from transaction input
 - [#1714](https://github.com/poanetwork/blockscout/pull/1714) - fix average block time calculation

### Chore

 - [#1693](https://github.com/poanetwork/blockscout/pull/1693) - Add a checklist to the PR template


## 1.3.8-beta

### Features

 - [#1611](https://github.com/poanetwork/blockscout/pull/1611) - allow setting the first indexing block
 - [#1596](https://github.com/poanetwork/blockscout/pull/1596) - add endpoint to create decompiled contracts
 - [#1634](https://github.com/poanetwork/blockscout/pull/1634) - add transaction count cache

### Fixes

 - [#1630](https://github.com/poanetwork/blockscout/pull/1630) - (Fix) colour for release link in the footer
 - [#1621](https://github.com/poanetwork/blockscout/pull/1621) - Modify query to fetch failed contract creations
 - [#1614](https://github.com/poanetwork/blockscout/pull/1614) - Do not fetch burn address token balance
 - [#1639](https://github.com/poanetwork/blockscout/pull/1614) - Optimize token holder count updates when importing address current balances
 - [#1643](https://github.com/poanetwork/blockscout/pull/1643) - Set internal_transactions_indexed_at for empty blocks
 - [#1647](https://github.com/poanetwork/blockscout/pull/1647) - Fix typo in view
 - [#1650](https://github.com/poanetwork/blockscout/pull/1650) - Add petersburg evm version to smart contract verifier
 - [#1657](https://github.com/poanetwork/blockscout/pull/1657) - Force consensus loss for parent block if its hash mismatches parent_hash

### Chore


## 1.3.7-beta

### Features

### Fixes

 - [#1615](https://github.com/poanetwork/blockscout/pull/1615) - Add more logging to code fixer process
 - [#1613](https://github.com/poanetwork/blockscout/pull/1613) - Fix USD fee value
 - [#1577](https://github.com/poanetwork/blockscout/pull/1577) - Add process to fix contract with code
 - [#1583](https://github.com/poanetwork/blockscout/pull/1583) - Chunk JSON-RPC batches in case connection times out

### Chore

 - [#1610](https://github.com/poanetwork/blockscout/pull/1610) - Add PIRL to Readme

## 1.3.6-beta

### Features

 - [#1589](https://github.com/poanetwork/blockscout/pull/1589) - RPC endpoint to list addresses
 - [#1567](https://github.com/poanetwork/blockscout/pull/1567) - Allow setting different configuration just for realtime fetcher
 - [#1562](https://github.com/poanetwork/blockscout/pull/1562) - Add incoming transactions count to contract view
 - [#1608](https://github.com/poanetwork/blockscout/pull/1608) - Add listcontracts RPC Endpoint

### Fixes

 - [#1595](https://github.com/poanetwork/blockscout/pull/1595) - Reduce block_rewards in the catchup fetcher
 - [#1590](https://github.com/poanetwork/blockscout/pull/1590) - Added guard for fetching blocks with invalid number
 - [#1588](https://github.com/poanetwork/blockscout/pull/1588) - Fix usd value on address page
 - [#1586](https://github.com/poanetwork/blockscout/pull/1586) - Exact timestamp display
 - [#1581](https://github.com/poanetwork/blockscout/pull/1581) - Consider `creates` param when fetching transactions
 - [#1559](https://github.com/poanetwork/blockscout/pull/1559) - Change v column type for Transactions table

### Chore

 - [#1579](https://github.com/poanetwork/blockscout/pull/1579) - Add SpringChain to the list of Additional Chains Utilizing BlockScout
 - [#1578](https://github.com/poanetwork/blockscout/pull/1578) - Refine contributing procedure
 - [#1572](https://github.com/poanetwork/blockscout/pull/1572) - Add option to disable block rewards in indexer config


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
