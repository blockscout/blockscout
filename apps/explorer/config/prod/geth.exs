import Config

hackney_opts_base = [pool: :ethereum_jsonrpc]

hackney_opts =
  if System.get_env("ETHEREUM_JSONRPC_HTTP_INSECURE", "") == "true" do
    [:insecure] ++ hackney_opts_base
  else
    hackney_opts_base
  end

config :explorer,
  json_rpc_named_arguments: [
    transport: EthereumJSONRPC.HTTP,
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
      url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
      http_options: [recv_timeout: :timer.minutes(1), timeout: :timer.minutes(1), hackney: hackney_opts]
    ],
    variant: EthereumJSONRPC.Geth
  ],
  subscribe_named_arguments: [
    transport: EthereumJSONRPC.WebSocket,
    transport_options: [
      web_socket: EthereumJSONRPC.WebSocket.WebSocketClient,
      url: System.get_env("ETHEREUM_JSONRPC_WS_URL")
    ],
    variant: EthereumJSONRPC.Geth
  ]
