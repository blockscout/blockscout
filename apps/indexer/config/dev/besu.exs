use Mix.Config

config :indexer,
  block_interval: :timer.seconds(5),
  json_rpc_named_arguments: [
    transport:
      if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
        do: EthereumJSONRPC.HTTP,
        else: EthereumJSONRPC.IPC
      ),
    else: EthereumJSONRPC.IPC,
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
      url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL") || "http://localhost:8545",
      method_to_url: [
        eth_getBalance: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "http://localhost:8545",
        trace_block: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "http://localhost:8545",
        trace_replayBlockTransactions: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "http://localhost:8545"
      ],
      http_options: [recv_timeout: :timer.minutes(10), timeout: :timer.minutes(10), hackney: [pool: :ethereum_jsonrpc]]
    ],
    variant: EthereumJSONRPC.Besu
  ],
  subscribe_named_arguments: [
    transport:
      System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
        EthereumJSONRPC.WebSocket,
    transport_options: [
      web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
      url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
    ]
  ]
