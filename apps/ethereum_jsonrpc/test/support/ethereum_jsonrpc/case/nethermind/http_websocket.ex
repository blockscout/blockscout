defmodule EthereumJSONRPC.Case.Nethermind.HTTPWebSocket do
  @moduledoc """
  `EthereumJSONRPC.Case` for connecting to Nethermind using `EthereumJSONRPC.HTTP` for `json_rpc_named_arguments`
  `transport` and `EthereumJSONRPC.WebSocket` for `subscribe_named_arguments` `transport`.
  """

  def setup do
    EthereumJSONRPC.WebSocket.Case.Nethermind.setup()
    |> Map.put(
      :json_rpc_named_arguments,
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.Tesla,
        http_options: [recv_timeout: 60_000, timeout: 60_000, pool: :ethereum_jsonrpc],
        urls: ["http://3.85.253.242:8545"]
      ],
      variant: EthereumJSONRPC.Nethermind
    )
  end
end
