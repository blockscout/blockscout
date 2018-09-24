defmodule EthereumJSONRPC.Case.Geth.HTTPWebSocket do
  @moduledoc """
  `EthereumJSONRPC.Case` for connecting to Geth using `EthereumJSONRPC.HTTP` for `json_rpc_named_arguments`
  `transport` and `EthereumJSONRPC.WebSocket` for `subscribe_named_arguments` `transport`.
  """

  def setup do
    EthereumJSONRPC.WebSocket.Case.Geth.setup()
    |> Map.put(
      :json_rpc_named_arguments,
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]],
        url: "https://mainnet.infura.io/8lTvJTKmHPCHazkneJsY"
      ],
      variant: EthereumJSONRPC.Geth
    )
  end
end
