use Mix.Config

config :indexer,
  block_interval: 5_000,
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.HTTP,
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
      url: "https://sokol.poa.network",
      method_to_url: [
        eth_getBalance: "https://sokol-trace.poa.network",
        trace_replayTransaction: "https://sokol-trace.poa.network"
      ],
      http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
    ],
    variant: EthereumJSONRPC.Parity
  ]
