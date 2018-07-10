use Mix.Config

config :ethereum_jsonrpc,
  url: "https://sokol.poa.network",
  method_to_url: [
    eth_getBalance: "https://sokol-trace.poa.network",
    trace_replayTransaction: "https://sokol-trace.poa.network"
  ],
  variant: EthereumJSONRPC.Parity
