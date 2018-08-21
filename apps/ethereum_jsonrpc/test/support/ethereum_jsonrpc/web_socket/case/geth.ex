defmodule EthereumJSONRPC.WebSocket.Case.Geth do
  @moduledoc """
  `EthereumJSONRPC.WebSocket.Case` connecting to Geth.
  """

  import ExUnit.Callbacks, only: [start_supervised!: 1]

  def setup do
    url = "wss://mainnet.infura.io/ws/8lTvJTKmHPCHazkneJsY"
    web_socket_module = EthereumJSONRPC.WebSocket.Socket
    web_socket = start_supervised!({web_socket_module, [url, []]})

    %{
      block_interval: 5_000,
      subscribe_named_arguments: [
        transport: EthereumJSONRPC.WebSocket,
        transport_options: [
          web_socket: web_socket_module,
          web_socket_options: %{web_socket: web_socket},
          url: url
        ]
      ]
    }
  end
end
