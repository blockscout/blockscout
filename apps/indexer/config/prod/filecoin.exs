import Config

~w(config config_helper.exs)
|> Path.join()
|> Code.eval_file()

config :indexer,
  block_interval: ConfigHelper.parse_time_env_var("INDEXER_CATCHUP_BLOCK_INTERVAL", "0s"),
  json_rpc_named_arguments: [
    transport:
      if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
        do: EthereumJSONRPC.HTTP,
        else: EthereumJSONRPC.IPC
      ),
    transport_options: [
      http: EthereumJSONRPC.HTTP.Tesla,
      urls: ConfigHelper.parse_urls_list(:http),
      trace_urls: ConfigHelper.parse_urls_list(:trace),
      eth_call_urls: ConfigHelper.parse_urls_list(:eth_call),
      fallback_urls: ConfigHelper.parse_urls_list(:fallback_http),
      fallback_trace_urls: ConfigHelper.parse_urls_list(:fallback_trace),
      fallback_eth_call_urls: ConfigHelper.parse_urls_list(:fallback_eth_call),
      method_to_url: [
        eth_call: :eth_call,
        trace_block: :trace
      ],
      http_options: ConfigHelper.http_options(10)
    ],
    variant: EthereumJSONRPC.Filecoin
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
