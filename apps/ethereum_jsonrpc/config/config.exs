# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :ethereum_jsonrpc,
  http: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]],
  trace_url: "http://127.0.0.1:8545",
  url: "http://127.0.0.1:8545"
