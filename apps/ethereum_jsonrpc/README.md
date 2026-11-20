# EthereumJSONRPC

`:ethereum_jsonrpc` is the umbrella app that Blockscout uses to talk to Ethereum and other EVM-compatible nodes over
JSON-RPC. The `:explorer` and `:indexer` apps use it for every node call. It handles:

- **Requests.** It builds single and batch JSON-RPC requests, correlates batch responses back to request ids, and
  splits batches by target endpoint (`EthereumJSONRPC.json_rpc/2`, `EthereumJSONRPC.BatchCorrelation`).
- **Transports.** Transports implement the `EthereumJSONRPC.Transport` behaviour:
  - `EthereumJSONRPC.HTTP`, with the `EthereumJSONRPC.HTTP.Tesla` (Mint) or `EthereumJSONRPC.HTTP.HTTPoison` client
  - `EthereumJSONRPC.IPC`, a Unix socket served by a `:poolboy` pool
  - `EthereumJSONRPC.WebSocket`, which also serves `eth_subscribe` subscriptions through
    `EthereumJSONRPC.WebSocket.WebSocketClient` (WebSockex) and `EthereumJSONRPC.WebSocket.RetryWorker`
- **Node client variants.** Variants implement the `EthereumJSONRPC.Variant` behaviour and hide client-specific
  tracing and pending-transaction APIs: `Geth`, `Nethermind`, `Erigon`, `Besu`, `RSK`, `Filecoin` and `Anvil`.
- **Data fetching and parsing.** It fetches and parses blocks (by number, hash, tag or nephew), transactions,
  receipts (per transaction or per block), logs, uncles, withdrawals, EIP-7702 authorizations, balances, code,
  nonces, block reward beneficiaries, internal transactions and raw traces.
- **Contract calls.** It encodes and decodes ABI calls (`EthereumJSONRPC.Contract`, `EthereumJSONRPC.Encoder`,
  `EthereumJSONRPC.ERC20`, `EthereumJSONRPC.NFT`).
- **Chain-specific helpers.** It includes helpers for Arbitrum, ZkSync and Zilliqa (quorum certificates).
- **Resilience.** It provides:
  - separate endpoint pools for regular, trace and `eth_call` requests, each with optional fallbacks
  - `EthereumJSONRPC.Utility.EndpointAvailabilityObserver`, which counts endpoint errors and switches to fallback
    URLs
  - `EthereumJSONRPC.Utility.EndpointAvailabilityChecker`, which re-enables endpoints once they recover
  - `EthereumJSONRPC.RequestCoordinator`, which backs off after timeouts and optionally throttles requests globally
    using `EthereumJSONRPC.RollingWindow`
- **Observability.** It exports Prometheus metrics (`EthereumJSONRPC.Prometheus.Instrumenter`) and Spandex/Datadog
  tracing (`EthereumJSONRPC.Tracer`).

## Usage

Almost every public function takes `json_rpc_named_arguments`, a keyword list that selects the transport, the
endpoints and the variant:

```elixir
json_rpc_named_arguments = [
  transport: EthereumJSONRPC.HTTP,
  transport_options: [
    http: EthereumJSONRPC.HTTP.Tesla,
    urls: ["http://localhost:8545"],
    trace_urls: ["http://localhost:8545"],
    eth_call_urls: ["http://localhost:8545"],
    fallback_urls: nil,
    method_to_url: [
      eth_call: :eth_call,
      debug_traceTransaction: :trace,
      debug_traceBlockByNumber: :trace
    ],
    http_options: [pool: :ethereum_jsonrpc, recv_timeout: 60_000, timeout: 60_000]
  ],
  variant: EthereumJSONRPC.Geth
]

{:ok, block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest", json_rpc_named_arguments)
{:ok, blocks} = EthereumJSONRPC.fetch_blocks_by_range(block_number..block_number, json_rpc_named_arguments)
```

`method_to_url` routes methods to the `trace` or `eth_call` URL pools. Any method that is not listed goes to `urls`.
When several URLs are configured for a pool, each request picks one at random. Endpoints that fail repeatedly are
replaced by the matching `fallback_*` URLs until they recover. Leave `fallback_*` options unset (`nil`) when
there is no fallback: an empty list counts as a configured fallback with nothing to switch to.

Inside Blockscout, these arguments are not written by hand. The per-variant config files build them from environment
variables:

- `apps/explorer/config/{dev,prod}/<variant>.exs`
- `apps/indexer/config/{dev,prod}/<variant>.exs`

The running application reads them from `Application.get_env(:explorer, :json_rpc_named_arguments)` and
`:subscribe_named_arguments`.

## Configuration

Configuration is set through environment variables that are read in `config/runtime.exs` and
`config/config_helper.exs`. The most important ones are:

| Variable                                                                           | Purpose                                                                                                                                    |
| :--------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------- |
| `ETHEREUM_JSONRPC_VARIANT`                                                         | Node client: `geth` (default), `nethermind`, `erigon`, `besu`, `rsk`, `filecoin`, `anvil`. `parity` is an alias for `nethermind`.           |
| `ETHEREUM_JSONRPC_HTTP_URL` / `ETHEREUM_JSONRPC_HTTP_URLS`                         | Main HTTP endpoint(s). Required.                                                                                                           |
| `ETHEREUM_JSONRPC_TRACE_URL` / `ETHEREUM_JSONRPC_TRACE_URLS`                       | Endpoint(s) for tracing methods. Default to the HTTP URLs.                                                                                 |
| `ETHEREUM_JSONRPC_ETH_CALL_URL` / `ETHEREUM_JSONRPC_ETH_CALL_URLS`                 | Endpoint(s) for `eth_call`. Default to the HTTP URLs.                                                                                      |
| `ETHEREUM_JSONRPC_FALLBACK_{HTTP,TRACE,ETH_CALL}_URL(S)`                           | Fallback endpoints used while the primary ones are unavailable.                                                                            |
| `ETHEREUM_JSONRPC_WS_URL` / `ETHEREUM_JSONRPC_FALLBACK_WS_URL`                     | WebSocket endpoint for new-head subscriptions.                                                                                             |
| `ETHEREUM_JSONRPC_TRANSPORT`, `IPC_PATH`                                           | Set the transport to `ipc` and give the socket path to use IPC instead of HTTP.                                                            |
| `ETHEREUM_JSONRPC_HTTP_TIMEOUT`, `ETHEREUM_JSONRPC_HTTP_BATCH_SIZE`                | HTTP timeout (seconds) and maximum batch size (default 500).                                                                               |
| `ETHEREUM_JSONRPC_HTTP_HEADERS`, `ETHEREUM_JSONRPC_USER`, `ETHEREUM_JSONRPC_PASSWORD`, `ETHEREUM_JSONRPC_HTTP_INSECURE` | Extra headers (JSON), basic auth and TLS verification.                                                        |
| `ETHEREUM_JSONRPC_HTTP_REQUEST_COMPRESSION_*`                                      | Gzip request compression for heavy methods (on by default) or all methods.                                                                |
| `ETHEREUM_JSONRPC_RECEIPTS_BY_BLOCK`, `ETHEREUM_JSONRPC_MAX_RECEIPTS_BY_BLOCK`     | Fetch receipts with `eth_getBlockReceipts` instead of per transaction.                                                                     |
| `ETHEREUM_JSONRPC_GETH_TRACE_BY_BLOCK`, `INDEXER_INTERNAL_TRANSACTIONS_TRACER_TYPE` | Geth tracing mode (per block or per transaction) and tracer (`call_tracer` (default), `js`, `opcode`, `polygon_edge`).                     |
| `ETHEREUM_JSONRPC_DEBUG_TRACE_TRANSACTION_TIMEOUT`                                 | Geth `debug_trace*` timeout (default `5s`).                                                                                                |
| `ETHEREUM_JSONRPC_DISABLE_ARCHIVE_BALANCES`, `ETHEREUM_JSONRPC_ARCHIVE_BALANCES_WINDOW` | Limit historical balance requests on non-archive nodes. Archive balances are disabled automatically when no trace URL is set.         |
| `ETHEREUM_JSONRPC_WAIT_PER_TIMEOUT`, `ETHEREUM_JSONRPC_WS_RETRY_INTERVAL`          | Request coordinator back-off and WebSocket reconnect interval.                                                                             |

See the [Blockscout ENV variables documentation](https://docs.blockscout.com/setup/env-variables) for the full list.

The app's own `config/config.exs` sets the static settings:

- `EthereumJSONRPC.RequestCoordinator` rolling windows. To enable global throttling, uncomment
  `throttle_rate_limit` and `throttle_rolling_window_opts`.
- Tracer settings.
- The default Tesla adapter (`Tesla.Adapter.Mint`).

## Testing

Run the tests from this app's directory. The `test` alias adds `--no-start`, and `test_helper.exs` starts the app
itself.

```shell
cd apps/ethereum_jsonrpc
mix test --exclude no_nethermind
```

Two environment variables set the test backends:

- `ETHEREUM_JSONRPC_CASE` sets `json_rpc_named_arguments` and defaults to `EthereumJSONRPC.Case.Nethermind.Mox`.
- `ETHEREUM_JSONRPC_WEB_SOCKET_CASE` sets `subscribe_named_arguments` and defaults to
  `EthereumJSONRPC.WebSocket.Case.Mox`.

The default Mox cases mock `EthereumJSONRPC.Transport` and never touch a real node. CI runs this setup:

```shell
export ETHEREUM_JSONRPC_CASE=EthereumJSONRPC.Case.Nethermind.Mox
export ETHEREUM_JSONRPC_WEB_SOCKET_CASE=EthereumJSONRPC.WebSocket.Case.Mox
mix test --exclude no_nethermind
```

Other cases live in `test/support/ethereum_jsonrpc/case/` and `test/support/ethereum_jsonrpc/web_socket/case/`:

| Case                                                | Notes                                                       |
| :-------------------------------------------------- | :---------------------------------------------------------- |
| `EthereumJSONRPC.Case.Geth.Mox`                     | Mocked Geth. Run with `--exclude no_geth`.                  |
| `EthereumJSONRPC.Case.Filecoin.Mox`                 | Mocked Filecoin.                                            |
| `EthereumJSONRPC.Case.Nethermind.HTTPWebSocket`     | Live node over HTTP and WebSocket (`...WebSocket.Case.Nethermind`). |
| `EthereumJSONRPC.Case.Geth.HTTPWebSocket`           | Live node over HTTP and WebSocket (`...WebSocket.Case.Geth`).       |

The live `HTTPWebSocket` cases have their node URLs hardcoded in their setup modules. Those URLs are no longer
maintained, so point them at a reachable node before you use these cases.

The mocks that are available to tests are defined in `test/test_helper.exs`:

- `EthereumJSONRPC.Mox` (transport)
- `EthereumJSONRPC.HTTP.Mox` (HTTP status codes such as 413)
- `EthereumJSONRPC.WebSocket.Mox`
- `EthereumJSONRPC.TeslaAdapter.Mox`

## Installation

Other umbrella apps depend on it through:

```elixir
def deps do
  [
    {:ethereum_jsonrpc, in_umbrella: true}
  ]
end
```
