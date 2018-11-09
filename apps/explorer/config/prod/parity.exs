use Mix.Config

config :explorer,
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.HTTP,
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
<<<<<<< HEAD
      url: System.get_env("TRACE_URL") || "https://sokol-trace.poa.network",
      method_to_url: [
        eth_call: System.get_env("TRACE_URL") || "https://sokol-trace.poa.network",
        eth_getBalance: System.get_env("TRACE_URL") || "https://sokol-trace.poa.network",
        trace_replayTransaction: System.get_env("TRACE_URL") || "https://sokol-trace.poa.network",
=======
      url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL") || "https://sokol.poa.network",
      method_to_url: [
        eth_call: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "https://sokol-trace.poa.network",
        eth_getBalance: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "https://sokol-trace.poa.network",
        trace_replayTransaction: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "https://sokol-trace.poa.network"
>>>>>>> master
      ],
      http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]]
    ],
    variant: EthereumJSONRPC.Parity
  ],
  subscribe_named_arguments: [
    transport: EthereumJSONRPC.WebSocket,
    transport_options: [
      web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
<<<<<<< HEAD
      url: System.get_env("WS_URL") || "https://sokol-trace.poa.network"
=======
      url: System.get_env("ETHEREUM_JSONRPC_WS_URL") || "wss://sokol-ws.poa.network/ws"
>>>>>>> master
    ],
    variant: EthereumJSONRPC.Parity
  ]
