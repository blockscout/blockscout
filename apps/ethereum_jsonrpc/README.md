# EthereumJSONRPC

Ethereum JSONRPC client.

## Configuration

Configuration for parity URLs can be provided with the following mix
config:

```elixir
config :ethereum_jsonrpc,
  url: "https://sokol.poa.network",
  trace_url: "https://sokol-trace.poa.network",
  http: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
```

Note: the tracing node URL is provided separately from `:url`,
via `:trace_url`. The trace URL and is used for
`fetch_internal_transactions`, which is only a supported method on
tracing nodes. The `:http` option is passed directly to the HTTP
library (`HTTPoison`), which forwards the options down to `:hackney`.

## Installation

The OTP application `:ethereum_jsonrpc` can be used in other umbrella
OTP applications by adding `ethereum_jsonrpc` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ethereum_jsonrpc, in_umbrella: true}
  ]
end
```

