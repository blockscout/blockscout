import Config

hackney_opts_base = [pool: :ethereum_jsonrpc]

hackney_opts =
  if System.get_env("ETHEREUM_JSONRPC_HTTP_INSECURE", "") == "true" do
    [:insecure] ++ hackney_opts_base
  else
    hackney_opts_base
  end

config :indexer,
  block_interval: :timer.seconds(5),
  json_rpc_named_arguments: [
    transport:
      if(System.get_env("ETHEREUM_JSONRPC_TRANSPORT", "http") == "http",
        do: EthereumJSONRPC.HTTP,
        else: EthereumJSONRPC.IPC
      ),
    transport_options: [
      http: EthereumJSONRPC.HTTP.HTTPoison,
      url: System.get_env("ETHEREUM_JSONRPC_HTTP_URL"),
      http_options: [recv_timeout: :timer.minutes(10), timeout: :timer.minutes(10), hackney: hackney_opts]
    ],
    variant: EthereumJSONRPC.Geth
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
