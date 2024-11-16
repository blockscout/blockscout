import Config

~w(config config_helper.exs)
|> Path.join()
|> Code.eval_file()

hackney_opts = ConfigHelper.hackney_options()
timeout = ConfigHelper.timeout(1)

config :explorer,
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.HTTP,
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
      urls:
        ConfigHelper.parse_urls_list("ETHEREUM_JSONRPC_HTTP_URLS", "ETHEREUM_JSONRPC_HTTP_URL", "http://localhost:7545"),
      eth_call_urls:
        ConfigHelper.parse_urls_list(
          "ETHEREUM_JSONRPC_ETH_CALL_URLS",
          "ETHEREUM_JSONRPC_ETH_CALL_URL",
          "http://localhost:7545"
        ),
      fallback_urls:
        ConfigHelper.parse_urls_list("ETHEREUM_JSONRPC_FALLBACK_HTTP_URLS", "ETHEREUM_JSONRPC_FALLBACK_HTTP_URL"),
      fallback_eth_call_urls:
        ConfigHelper.parse_urls_list(
          "ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URLS",
          "ETHEREUM_JSONRPC_FALLBACK_ETH_CALL_URL"
        ),
      method_to_url: [
        eth_call: :eth_call
      ],
      http_options: [recv_timeout: timeout, timeout: timeout, hackney: hackney_opts]
    ],
    variant: EthereumJSONRPC.Ganache
  ],
  subscribe_named_arguments: [
    transport: EthereumJSONRPC.WebSocket,
    transport_options: [
      web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
      url: System.get_env("ETHEREUM_JSONRPC_WS_URL"),
      fallback_url: System.get_env("ETHEREUM_JSONRPC_FALLBACK_WS_URL")
    ],
    variant: EthereumJSONRPC.Ganache
  ]
