use Mix.Config

config :explorer,
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.HTTP,
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
      url: "https://foundation-trace-fn4v7.poa.network",
      method_to_url: [
        eth_call: "https://foundation-trace-fn4v7.poa.network",
        eth_getBalance: "https://foundation-trace-fn4v7.poa.network",
        trace_replayTransaction: "https://foundation-trace-fn4v7.poa.network"
      ],
      http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
    ],
    variant: EthereumJSONRPC.Parity
  ],
  subscribe_named_arguments: [
    transport: EthereumJSONRPC.WebSocket,
    transport_options: [
      web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
      url: "wss://foundation-trace-fn4v7.poa.network/ws"
    ],
    variant: EthereumJSONRPC.Parity
  ]
