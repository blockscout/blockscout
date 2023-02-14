import Config

basic_auth_user = System.get_env("ETHEREUM_JSONRPC_USER", "")
basic_auth_pass = System.get_env("ETHEREUM_JSONRPC_PASSWORD", "")

hackney_opts =
  [pool: :ethereum_jsonrpc]
  |> (&if(System.get_env("ETHEREUM_JSONRPC_HTTP_INSECURE", "") == "true", do: [:insecure] ++ &1, else: &1)).()
  |> (&if(basic_auth_user != "" && basic_auth_pass != "",
        do: [basic_auth: {basic_auth_user, basic_auth_pass}] ++ &1,
        else: &1
      )).()

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
