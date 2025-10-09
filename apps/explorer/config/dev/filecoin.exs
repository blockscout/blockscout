import Config

~w(config config_helper.exs)
|> Path.join()
|> Code.eval_file()

config :explorer,
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.HTTP,
    transport_options: [
      http: EthereumJSONRPC.HTTP.Tesla,
      urls: ConfigHelper.parse_urls_list(:http, "http://localhost:1234/rpc/v1"),
      trace_urls: ConfigHelper.parse_urls_list(:trace, "http://localhost:1234/rpc/v1"),
      eth_call_urls: ConfigHelper.parse_urls_list(:eth_call, "http://localhost:1234/rpc/v1"),
      fallback_urls: ConfigHelper.parse_urls_list(:fallback_http),
      fallback_trace_urls: ConfigHelper.parse_urls_list(:fallback_trace),
      fallback_eth_call_urls: ConfigHelper.parse_urls_list(:fallback_eth_call),
      method_to_url: [
        eth_call: :eth_call,
        trace_block: :trace
      ],
      http_options: ConfigHelper.http_options(1)
    ],
    variant: EthereumJSONRPC.Filecoin
  ],
  subscribe_named_arguments: [
    transport: EthereumJSONRPC.WebSocket,
    transport_options: [
      web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
      url: System.get_env("ETHEREUM_JSONRPC_WS_URL"),
      fallback_url: System.get_env("ETHEREUM_JSONRPC_FALLBACK_WS_URL")
    ],
    variant: EthereumJSONRPC.Filecoin
  ]
