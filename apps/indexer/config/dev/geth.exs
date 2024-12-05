import Config

~w(config config_helper.exs)
|> Path.join()
|> Code.eval_file()

hackney_opts = ConfigHelper.hackney_options()
timeout = ConfigHelper.timeout(1)

config :indexer,
  block_interval: ConfigHelper.parse_time_env_var("INDEXER_CATCHUP_BLOCK_INTERVAL", "5s"),
  json_rpc_named_arguments: [
    transport:
      if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
        do: EthereumJSONRPC.HTTP,
        else: EthereumJSONRPC.IPC
      ),
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
      urls: ConfigHelper.parse_urls_list(:http, "http://localhost:8545"),
      trace_urls: ConfigHelper.parse_urls_list(:trace, "http://localhost:8545"),
      eth_call_urls: ConfigHelper.parse_urls_list(:eth_call, "http://localhost:8545"),
      fallback_urls: ConfigHelper.parse_urls_list(:fallback_http),
      fallback_trace_urls: ConfigHelper.parse_urls_list(:fallback_trace),
      fallback_eth_call_urls: ConfigHelper.parse_urls_list(:fallback_eth_call),
      method_to_url: [
        eth_call: :eth_call,
        debug_traceTransaction: :trace,
        debug_traceBlockByNumber: :trace
      ],
      http_options: [recv_timeout: timeout, timeout: timeout, hackney: hackney_opts]
    ],
    variant: EthereumJSONRPC.Geth
  ],
  subscribe_named_arguments: [
    transport:
      System.get_env("ETHEREUM_JSONRPC_WS_URL") && System.get_env("ETHEREUM_JSONRPC_WS_URL") !== "" &&
        EthereumJSONRPC.WebSocket,
    transport_options: [
      web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
      url: System.get_env("ETHEREUM_JSONRPC_WS_URL"),
      fallback_url: System.get_env("ETHEREUM_JSONRPC_FALLBACK_WS_URL")
    ]
  ]
