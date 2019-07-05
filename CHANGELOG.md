## Current

### Features

### Fixes

### Chore


## 2.0.1-beta

### Features
- [#2283](https://github.com/poanetwork/blockscout/pull/2283) - Add transactions cache
- [#2182](https://github.com/poanetwork/blockscout/pull/2182) - add market history cache
- [#2109](https://github.com/poanetwork/blockscout/pull/2109) - use bigger updates instead of `Multi` transactions in BlocksTransactionsMismatch
- [#2075](https://github.com/poanetwork/blockscout/pull/2075) - add blocks cache
- [#2151](https://github.com/poanetwork/blockscout/pull/2151) - hide dropdown menu then other networks list is empty
- [#2191](https://github.com/poanetwork/blockscout/pull/2191) - allow to configure token metadata update interval
- [#2146](https://github.com/poanetwork/blockscout/pull/2146) - feat: add eth_getLogs rpc endpoint
- [#2216](https://github.com/poanetwork/blockscout/pull/2216) - Improve token's controllers by avoiding unnecessary preloads
- [#2235](https://github.com/poanetwork/blockscout/pull/2235) - save and show additional validation fields to smart contract
- [#2190](https://github.com/poanetwork/blockscout/pull/2190) - show all token transfers
- [#2193](https://github.com/poanetwork/blockscout/pull/2193) - feat: add BLOCKSCOUT_HOST, and use it in API docs
- [#2266](https://github.com/poanetwork/blockscout/pull/2266) - allow excluding uncles from average block time calculation

### Fixes
- [#2286](https://github.com/poanetwork/blockscout/pull/2286) - banner stats issues on sm resolutions, transactions title issue
- [#2284](https://github.com/poanetwork/blockscout/pull/2284) - add 404 status for not existing pages
- [#2244](https://github.com/poanetwork/blockscout/pull/2244) - fix internal transactions failing to be indexed because of constraint
- [#2281](https://github.com/poanetwork/blockscout/pull/2281) - typo issues, dropdown issues
- [#2278](https://github.com/poanetwork/blockscout/pull/2278) - increase threshold for scientific notation
- [#2275](https://github.com/poanetwork/blockscout/pull/2275) - Description for networks selector
- [#2263](https://github.com/poanetwork/blockscout/pull/2263) - added an ability to close network selector on outside click
- [#2257](https://github.com/poanetwork/blockscout/pull/2257) - 'download csv' button added to different tabs
- [#2242](https://github.com/poanetwork/blockscout/pull/2242) - added styles for 'download csv' button
- [#2261](https://github.com/poanetwork/blockscout/pull/2261) - header logo aligned to the center properly
- [#2254](https://github.com/poanetwork/blockscout/pull/2254) - search length issue, tile link wrapping issue
- [#2238](https://github.com/poanetwork/blockscout/pull/2238) - header content alignment issue, hide navbar on outside click
- [#2229](https://github.com/poanetwork/blockscout/pull/2229) - gap issue between qr and copy button in token transfers, top cards width and height issue
- [#2201](https://github.com/poanetwork/blockscout/pull/2201) - footer columns fix
- [#2179](https://github.com/poanetwork/blockscout/pull/2179) - fix docker build error
- [#2165](https://github.com/poanetwork/blockscout/pull/2165) - sort blocks by timestamp when calculating average block time
- [#2175](https://github.com/poanetwork/blockscout/pull/2175) - fix coinmarketcap response errors
- [#2164](https://github.com/poanetwork/blockscout/pull/2164) - fix large numbers in balance view card
- [#2155](https://github.com/poanetwork/blockscout/pull/2155) - fix pending transaction query
- [#2183](https://github.com/poanetwork/blockscout/pull/2183) - tile content aligning for mobile resolution fix, dai logo fix
- [#2162](https://github.com/poanetwork/blockscout/pull/2162) - contract creation tile color changed
- [#2144](https://github.com/poanetwork/blockscout/pull/2144) - 'page not found' images path fixed for goerli
- [#2142](https://github.com/poanetwork/blockscout/pull/2142) - Removed posdao theme and logo, added 'page not found' image for goerli
- [#2138](https://github.com/poanetwork/blockscout/pull/2138) - badge colors issue, api titles issue
- [#2129](https://github.com/poanetwork/blockscout/pull/2129) - Fix for width of explorer elements
- [#2121](https://github.com/poanetwork/blockscout/pull/2121) - Binding of 404 page
- [#2120](https://github.com/poanetwork/blockscout/pull/2120) - footer links and socials focus color issue
- [#2113](https://github.com/poanetwork/blockscout/pull/2113) - renewed logos for rsk, dai, blockscout; themes color changes for lukso; error images for lukso
- [#2112](https://github.com/poanetwork/blockscout/pull/2112) - themes color improvements, dropdown color issue
- [#2110](https://github.com/poanetwork/blockscout/pull/2110) - themes colors issues, ui issues
- [#2103](https://github.com/poanetwork/blockscout/pull/2103) - ui issues for all themes
- [#2090](https://github.com/poanetwork/blockscout/pull/2090) - updated some ETC theme colors
- [#2096](https://github.com/poanetwork/blockscout/pull/2096) - RSK theme fixes
- [#2093](https://github.com/poanetwork/blockscout/pull/2093) - detect token transfer type for deprecated erc721 spec
- [#2111](https://github.com/poanetwork/blockscout/pull/2111) - improve address transaction controller
- [#2108](https://github.com/poanetwork/blockscout/pull/2108) - fix uncle fetching without full transactions
- [#2128](https://github.com/poanetwork/blockscout/pull/2128) - add new function clause for uncle errors
- [#2123](https://github.com/poanetwork/blockscout/pull/2123) - fix coins percentage view
- [#2119](https://github.com/poanetwork/blockscout/pull/2119) - fix map logging
- [#2130](https://github.com/poanetwork/blockscout/pull/2130) - fix navigation
- [#2148](https://github.com/poanetwork/blockscout/pull/2148) - filter pending logs
- [#2147](https://github.com/poanetwork/blockscout/pull/2147) - add rsk format of checksum
- [#2149](https://github.com/poanetwork/blockscout/pull/2149) - remove pending transaction count
- [#2177](https://github.com/poanetwork/blockscout/pull/2177) - remove duplicate entries from UncleBlock's Fetcher
- [#2169](https://github.com/poanetwork/blockscout/pull/2169) - add more validator reward types for xDai
- [#2173](https://github.com/poanetwork/blockscout/pull/2173) - handle correctly empty transactions
- [#2174](https://github.com/poanetwork/blockscout/pull/2174) - fix reward channel joining
- [#2186](https://github.com/poanetwork/blockscout/pull/2186) - fix net version test
- [#2237](https://github.com/poanetwork/blockscout/pull/2237) - fix rsk total_supply
- [#2198](https://github.com/poanetwork/blockscout/pull/2198) - reduce transaction status and error constraint
- [#2167](https://github.com/poanetwork/blockscout/pull/2167) - feat: document eth rpc api mimicking endpoints
- [#2225](https://github.com/poanetwork/blockscout/pull/2225) - fix metadata decoding in Solidity 0.5.9 smart contract verification
- [#2204](https://github.com/poanetwork/blockscout/pull/2204) - fix large contract verification
- [#2258](https://github.com/poanetwork/blockscout/pull/2258) - reduce BlocksTransactionsMismatch memory footprint
- [#2247](https://github.com/poanetwork/blockscout/pull/2247) - hide logs search if there are no logs
- [#2248](https://github.com/poanetwork/blockscout/pull/2248) - sort block after query execution for average block time
- [#2249](https://github.com/poanetwork/blockscout/pull/2249) - More transaction controllers improvements
- [#2267](https://github.com/poanetwork/blockscout/pull/2267) - Modify implementation of `where_transaction_has_multiple_internal_transactions`
- [#2270](https://github.com/poanetwork/blockscout/pull/2270) - Remove duplicate params in `Indexer.Fetcher.TokenBalance`
- [#2268](https://github.com/poanetwork/blockscout/pull/2268) - remove not existing assigns in html code
- [#2276](https://github.com/poanetwork/blockscout/pull/2276) - remove port in docs

### Chore
- [#2127](https://github.com/poanetwork/blockscout/pull/2127) - use previouse chromedriver version
- [#2118](https://github.com/poanetwork/blockscout/pull/2118) - show only the last decompiled contract
- [#2256](https://github.com/poanetwork/blockscout/pull/2256) - use the latest version of chromedriver

## 2.0.0-beta

### Features
- [#2044](https://github.com/poanetwork/blockscout/pull/2044) - New network selector.
- [#2091](https://github.com/poanetwork/blockscout/pull/2091) - Added "Question" modal.
- [#1963](https://github.com/poanetwork/blockscout/pull/1963), [#1959](https://github.com/poanetwork/blockscout/pull/1959), [#1948](https://github.com/poanetwork/blockscout/pull/1948), [#1936](https://github.com/poanetwork/blockscout/pull/1936), [#1925](https://github.com/poanetwork/blockscout/pull/1925), [#1922](https://github.com/poanetwork/blockscout/pull/1922), [#1903](https://github.com/poanetwork/blockscout/pull/1903), [#1874](https://github.com/poanetwork/blockscout/pull/1874), [#1895](https://github.com/poanetwork/blockscout/pull/1895), [#2031](https://github.com/poanetwork/blockscout/pull/2031), [#2073](https://github.com/poanetwork/blockscout/pull/2073), [#2074](https://github.com/poanetwork/blockscout/pull/2074),  - added new themes and logos for poa, eth, rinkeby, goerli, ropsten, kovan, sokol, xdai, etc, rsk and default theme
- [#1726](https://github.com/poanetwork/blockscout/pull/2071) - Updated styles for the new smart contract page.
- [#2081](https://github.com/poanetwork/blockscout/pull/2081) - Tooltip for 'more' button, explorers logos added
- [#2010](https://github.com/poanetwork/blockscout/pull/2010) - added "block not found" and "tx not found pages"
- [#1928](https://github.com/poanetwork/blockscout/pull/1928) - pagination styles were updated
- [#1940](https://github.com/poanetwork/blockscout/pull/1940) - qr modal button and background issue
- [#1907](https://github.com/poanetwork/blockscout/pull/1907) - dropdown color bug fix (lukso theme) and tooltip color bug fix
- [#1859](https://github.com/poanetwork/blockscout/pull/1859) - feat: show raw transaction traces
- [#1941](https://github.com/poanetwork/blockscout/pull/1941) - feat: add on demand fetching and stale attr to rpc
- [#1957](https://github.com/poanetwork/blockscout/pull/1957) - Calculate stakes ratio before insert pools
- [#1956](https://github.com/poanetwork/blockscout/pull/1956) - add logs tab to address
- [#1952](https://github.com/poanetwork/blockscout/pull/1952) - feat: exclude empty contracts by default
- [#1954](https://github.com/poanetwork/blockscout/pull/1954) - feat: use creation init on self destruct
- [#2036](https://github.com/poanetwork/blockscout/pull/2036) - New tables for staking pools and delegators
- [#1974](https://github.com/poanetwork/blockscout/pull/1974) - feat: previous page button logic
- [#1999](https://github.com/poanetwork/blockscout/pull/1999) - load data async on addresses page
- [#1807](https://github.com/poanetwork/blockscout/pull/1807) - New theming capabilites.
- [#2040](https://github.com/poanetwork/blockscout/pull/2040) - Verification links to other explorers for ETH
- [#2037](https://github.com/poanetwork/blockscout/pull/2037) - add address logs search functionality
- [#2012](https://github.com/poanetwork/blockscout/pull/2012) - make all pages pagination async
- [#2064](https://github.com/poanetwork/blockscout/pull/2064) - feat: add fields to tx apis, small cleanups
- [#2100](https://github.com/poanetwork/blockscout/pull/2100) - feat: eth_get_balance rpc endpoint

### Fixes
- [#2228](https://github.com/poanetwork/blockscout/pull/2228) - favorites duplication issues, active radio issue
- [#2207](https://github.com/poanetwork/blockscout/pull/2207) - new 'download csv' button design
- [#2206](https://github.com/poanetwork/blockscout/pull/2206) - added styles for 'Download All Transactions as CSV' button
- [#2099](https://github.com/poanetwork/blockscout/pull/2099) - logs search input width
- [#2098](https://github.com/poanetwork/blockscout/pull/2098) - nav dropdown issue, logo size issue
- [#2082](https://github.com/poanetwork/blockscout/pull/2082) - dropdown styles, tooltip gap fix, 404 page added
- [#2077](https://github.com/poanetwork/blockscout/pull/2077) - ui issues
- [#2072](https://github.com/poanetwork/blockscout/pull/2072) - Fixed checkmarks not showing correctly in tabs.
- [#2066](https://github.com/poanetwork/blockscout/pull/2066) - fixed length of logs search input
- [#2056](https://github.com/poanetwork/blockscout/pull/2056) - log search form styles added
- [#2043](https://github.com/poanetwork/blockscout/pull/2043) - Fixed modal dialog width for 'verify other explorers'
- [#2025](https://github.com/poanetwork/blockscout/pull/2025) - Added a new color to display transactions' errors.
- [#2033](https://github.com/poanetwork/blockscout/pull/2033) - Header nav. dropdown active element color issue
- [#2019](https://github.com/poanetwork/blockscout/pull/2019) - Fixed the missing tx hashes.
- [#2020](https://github.com/poanetwork/blockscout/pull/2020) - Fixed a bug triggered when a second click to a selected tab caused the other tabs to hide.
- [#1944](https://github.com/poanetwork/blockscout/pull/1944) - fixed styles for token's dropdown.
- [#1926](https://github.com/poanetwork/blockscout/pull/1926) - status label alignment
- [#1849](https://github.com/poanetwork/blockscout/pull/1849) - Improve chains menu
- [#1868](https://github.com/poanetwork/blockscout/pull/1868) - fix: logs list endpoint performance
- [#1822](https://github.com/poanetwork/blockscout/pull/1822) - Fix style breaks in decompiled contract code view
- [#1885](https://github.com/poanetwork/blockscout/pull/1885) - highlight reserved words in decompiled code
- [#1896](https://github.com/poanetwork/blockscout/pull/1896) - re-query tokens in top nav automplete
- [#1905](https://github.com/poanetwork/blockscout/pull/1905) - fix reorgs, uncles pagination
- [#1904](https://github.com/poanetwork/blockscout/pull/1904) - fix `BLOCK_COUNT_CACHE_TTL` env var type
- [#1915](https://github.com/poanetwork/blockscout/pull/1915) - fallback to 2 latest evm versions
- [#1937](https://github.com/poanetwork/blockscout/pull/1937) - Check the presence of overlap[i] object before retrieving properties from it
- [#1960](https://github.com/poanetwork/blockscout/pull/1960) - do not remove bold text in decompiled contacts
- [#1966](https://github.com/poanetwork/blockscout/pull/1966) - fix: add fields for contract filter performance
- [#2017](https://github.com/poanetwork/blockscout/pull/2017) - fix: fix to/from filters on tx list pages
- [#2008](https://github.com/poanetwork/blockscout/pull/2008) - add new function clause for xDai network beneficiaries
- [#2009](https://github.com/poanetwork/blockscout/pull/2009) - addresses page improvements
- [#2027](https://github.com/poanetwork/blockscout/pull/2027) - fix: `BlocksTransactionsMismatch` ignoring blocks without transactions
- [#2062](https://github.com/poanetwork/blockscout/pull/2062) - fix: uniq by hash, instead of transaction
- [#2052](https://github.com/poanetwork/blockscout/pull/2052) - allow bytes32 for name and symbol
- [#2047](https://github.com/poanetwork/blockscout/pull/2047) - fix: show creating internal transactions
- [#2014](https://github.com/poanetwork/blockscout/pull/2014) - fix: use better queries for listLogs endpoint
- [#2027](https://github.com/poanetwork/blockscout/pull/2027) - fix: `BlocksTransactionsMismatch` ignoring blocks without transactions
- [#2070](https://github.com/poanetwork/blockscout/pull/2070) - reduce `max_concurrency` of `BlocksTransactionsMismatch` fetcher
- [#2083](https://github.com/poanetwork/blockscout/pull/2083) - allow total_difficuly to be nil
- [#2086](https://github.com/poanetwork/blockscout/pull/2086) - fix geth's staticcall without output

### Chore

- [#1900](https://github.com/poanetwork/blockscout/pull/1900) - SUPPORTED_CHAINS ENV var
- [#1958](https://github.com/poanetwork/blockscout/pull/1958) - Default value for release link env var
- [#1964](https://github.com/poanetwork/blockscout/pull/1964) - ALLOWED_EVM_VERSIONS env var
- [#1975](https://github.com/poanetwork/blockscout/pull/1975) - add log index to transaction view
- [#1988](https://github.com/poanetwork/blockscout/pull/1988) - Fix wrong parity tasks names in Circle CI
- [#2000](https://github.com/poanetwork/blockscout/pull/2000) - docker/Makefile: always set a container name
- [#2018](https://github.com/poanetwork/blockscout/pull/2018) - Use PORT env variable in dev config
- [#2055](https://github.com/poanetwork/blockscout/pull/2055) - Increase timeout for geth indexers
- [#2069](https://github.com/poanetwork/blockscout/pull/2069) - Docsify integration: static docs page generation

## 1.3.15-beta

### Features

- [#1857](https://github.com/poanetwork/blockscout/pull/1857) - Re-implement Geth JS internal transaction tracer in Elixir
- [#1989](https://github.com/poanetwork/blockscout/pull/1989) - fix: consolidate address w/ balance one at a time
- [#2002](https://github.com/poanetwork/blockscout/pull/2002) - Get estimated count of blocks when cache is empty

### Fixes

- [#1869](https://github.com/poanetwork/blockscout/pull/1869) - Fix output and gas extraction in JS tracer for Geth
- [#1992](https://github.com/poanetwork/blockscout/pull/1992) - fix: support https for wobserver polling
- [#2027](https://github.com/poanetwork/blockscout/pull/2027) - fix: `BlocksTransactionsMismatch` ignoring blocks without transactions


## 1.3.14-beta

- [#1812](https://github.com/poanetwork/blockscout/pull/1812) - add pagination to addresses page
- [#1920](https://github.com/poanetwork/blockscout/pull/1920) - fix: remove source code fields from list endpoint
- [#1876](https://github.com/poanetwork/blockscout/pull/1876) - async calculate a count of blocks

### Fixes

- [#1917](https://github.com/poanetwork/blockscout/pull/1917) - Force block refetch if transaction is re-collated in a different block

### Chore

- [#1892](https://github.com/poanetwork/blockscout/pull/1892) - Remove temporary worker modules

## 1.3.13-beta

### Features

- [#1933](https://github.com/poanetwork/blockscout/pull/1933) - add eth_BlockNumber json rpc method

### Fixes

- [#1875](https://github.com/poanetwork/blockscout/pull/1875) - fix: resolve false positive constructor arguments
- [#1881](https://github.com/poanetwork/blockscout/pull/1881) - fix: store solc versions locally for performance
- [#1898](https://github.com/poanetwork/blockscout/pull/1898) - check if the constructor has arguments before verifying constructor arguments

## 1.3.12-beta

Reverting of synchronous block counter, implemented in #1848

## 1.3.11-beta

### Features

- [#1815](https://github.com/poanetwork/blockscout/pull/1815) - Be able to search without prefix "0x"
- [#1813](https://github.com/poanetwork/blockscout/pull/1813) - Add total blocks counter to the main page
- [#1806](https://github.com/poanetwork/blockscout/pull/1806) - Verify contracts with a post request
- [#1848](https://github.com/poanetwork/blockscout/pull/1848) - Add cache for block counter

### Fixes

- [#1829](https://github.com/poanetwork/blockscout/pull/1829) - Handle nil quantities in block decoding routine
- [#1830](https://github.com/poanetwork/blockscout/pull/1830) - Make block size field nullable
- [#1840](https://github.com/poanetwork/blockscout/pull/1840) - Handle case when total supply is nil
- [#1838](https://github.com/poanetwork/blockscout/pull/1838) - Block counter calculates only consensus blocks

### Chore

- [#1814](https://github.com/poanetwork/blockscout/pull/1814) - Clear build artefacts script
- [#1837](https://github.com/poanetwork/blockscout/pull/1837) - Add -f flag to clear_build.sh script delete static folder

## 1.3.10-beta

### Features

- [#1739](https://github.com/poanetwork/blockscout/pull/1739) - highlight decompiled source code
- [#1696](https://github.com/poanetwork/blockscout/pull/1696) - full-text search by tokens
- [#1742](https://github.com/poanetwork/blockscout/pull/1742) - Support RSK
- [#1777](https://github.com/poanetwork/blockscout/pull/1777) - show ERC-20 token transfer info on transaction page
- [#1770](https://github.com/poanetwork/blockscout/pull/1770) - set a websocket keepalive from config
- [#1789](https://github.com/poanetwork/blockscout/pull/1789) - add ERC-721 info to transaction overview page
- [#1801](https://github.com/poanetwork/blockscout/pull/1801) - Staking pools fetching

### Fixes

 - [#1724](https://github.com/poanetwork/blockscout/pull/1724) - Remove internal tx and token balance fetching from realtime fetcher
 - [#1727](https://github.com/poanetwork/blockscout/pull/1727) - add logs pagination in rpc api
 - [#1740](https://github.com/poanetwork/blockscout/pull/1740) - fix empty block time
 - [#1743](https://github.com/poanetwork/blockscout/pull/1743) - sort decompiled smart contracts in lexicographical order
 - [#1756](https://github.com/poanetwork/blockscout/pull/1756) - add today's token balance from the previous value
 - [#1769](https://github.com/poanetwork/blockscout/pull/1769) - add timestamp to block overview
 - [#1768](https://github.com/poanetwork/blockscout/pull/1768) - fix first block parameter
 - [#1778](https://github.com/poanetwork/blockscout/pull/1778) - Make websocket optional for realtime fetcher
 - [#1790](https://github.com/poanetwork/blockscout/pull/1790) - fix constructor arguments verification
 - [#1793](https://github.com/poanetwork/blockscout/pull/1793) - fix top nav autocomplete
 - [#1795](https://github.com/poanetwork/blockscout/pull/1795) - fix line numbers for decompiled contracts
 - [#1803](https://github.com/poanetwork/blockscout/pull/1803) - use coinmarketcap for total_supply by default
 - [#1802](https://github.com/poanetwork/blockscout/pull/1802) - make coinmarketcap's number of pages configurable
 - [#1799](https://github.com/poanetwork/blockscout/pull/1799) - Use eth_getUncleByBlockHashAndIndex for uncle block fetching
 - [#1531](https://github.com/poanetwork/blockscout/pull/1531) - docker: fix dockerFile for secp256k1 building
 - [#1835](https://github.com/poanetwork/blockscout/pull/1835) - fix: ignore `pong` messages without error

### Chore

 - [#1804](https://github.com/poanetwork/blockscout/pull/1804) - (Chore) Divide chains by Mainnet/Testnet in menu
 - [#1783](https://github.com/poanetwork/blockscout/pull/1783) - Update README with the chains that use Blockscout
 - [#1780](https://github.com/poanetwork/blockscout/pull/1780) - Update link to the Github repo in the footer
 - [#1757](https://github.com/poanetwork/blockscout/pull/1757) - Change twitter acc link to official Blockscout acc twitter
 - [#1749](https://github.com/poanetwork/blockscout/pull/1749) - Replace the link in the footer with the official POA announcements tg channel link
 - [#1718](https://github.com/poanetwork/blockscout/pull/1718) - Flatten indexer module hierarchy and supervisor tree
 - [#1753](https://github.com/poanetwork/blockscout/pull/1753) - Add a check mark to decompiled contract tab
 - [#1744](https://github.com/poanetwork/blockscout/pull/1744) - remove `0x0..0` from tests
 - [#1763](https://github.com/poanetwork/blockscout/pull/1763) - Describe indexer structure and list existing fetchers
 - [#1800](https://github.com/poanetwork/blockscout/pull/1800) - Disable lazy logging check in Credo


## 1.3.9-beta

### Features

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
