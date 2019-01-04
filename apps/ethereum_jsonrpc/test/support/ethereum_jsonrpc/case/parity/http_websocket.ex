defmodule EthereumJSONRPC.Case.Parity.HTTPWebSocket do
  @moduledoc """
  `EthereumJSONRPC.Case` for connecting to Parity using `EthereumJSONRPC.HTTP` for `json_rpc_named_arguments`
  `transport` and `EthereumJSONRPC.WebSocket` for `subscribe_named_arguments` `transport`.
  """

  def setup do
    EthereumJSONRPC.WebSocket.Case.Parity.setup()
    |> Map.put(
      :json_rpc_named_arguments,
      transport: EthereumJSONRPC.HTTP,
      transport_options: [
        http: EthereumJSONRPC.HTTP.HTTPoison,
        http_options: [recv_timeout: 60_000, timeout: 60_000, hackney: [pool: :ethereum_jsonrpc]],
        url: "http://3.85.253.242:8545"
      ],
      variant: EthereumJSONRPC.Parity
    )
  end
end
