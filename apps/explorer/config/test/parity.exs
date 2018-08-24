use Mix.Config

config :explorer,
  transport: EthereumJSONRPC.HTTP,
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.Mox,
    transport_options: [],
    variant: EthereumJSONRPC.Parity
  ],
  subscribe_named_arguments: [
    transport: EthereumJSONRPC.Mox,
    transport_options: [],
    variant: EthereumJSONRPC.Parity
  ]
