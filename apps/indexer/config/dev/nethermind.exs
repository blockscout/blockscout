import Config

~w(config config_helper.exs)
|> Path.join()
|> Code.eval_file()

hackney_opts = ConfigHelper.hackney_options()
timeout = ConfigHelper.timeout(10)

config :indexer,
  block_interval: ConfigHelper.parse_time_env_var("INDEXER_CATCHUP_BLOCK_INTERVAL", "5s"),
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
      fallback_url: System.get_env("ETHEREUM_JSONRPC_FALLBACK_HTTP_URL"),
      fallback_trace_url: System.get_env("ETHEREUM_JSONRPC_FALLBACK_TRACE_URL"),
      method_to_url: [
        eth_getBalance: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "http://localhost:8545",
        trace_block: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "http://localhost:8545",
        trace_replayBlockTransactions: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "http://localhost:8545",
        trace_replayTransaction: System.get_env("ETHEREUM_JSONRPC_TRACE_URL") || "http://localhost:8545"
      ],
      http_options: [recv_timeout: timeout, timeout: timeout, hackney: hackney_opts]
    ],
    variant: EthereumJSONRPC.Nethermind
  ],
  # Example configuration to override json_rpc_named_arguments for just the realtime block fetcher
  # realtime_overrides: [
  #   json_rpc_named_arguments: [
  #     transport: EthereumJSONRPC.HTTP,
  #     transport_options: [
  #       http: EthereumJSONRPC.HTTP.HTTPoison,
  #       url: System.get_env("ETHEREUM_JSONRPC_REALTIME_HTTP_URL") || "http://localhost:8545",
  #       method_to_url: [
  #         eth_getBalance: System.get_env("ETHEREUM_JSONRPC_REALTIME_TRACE_URL") || "http://localhost:8545",
  #         trace_block: System.get_env("ETHEREUM_JSONRPC_REALTIME_TRACE_URL") || "http://localhost:8545",
  #         trace_replayTransaction: System.get_env("ETHEREUM_JSONRPC_REALTIME_TRACE_URL") || "http://localhost:8545"
  #       ],
  #       http_options: [recv_timeout: :timer.minutes(1), timeout: :timer.minutes(1), hackney: hackney_opts]
  #     ],
  #     variant: EthereumJSONRPC.Nethermind
  #   ]
  # ],
  subscribe_named_arguments: [
    transport:
      System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
        EthereumJSONRPC.WebSocket,
    transport_options: [
      web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
      url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
    ]
  ]
