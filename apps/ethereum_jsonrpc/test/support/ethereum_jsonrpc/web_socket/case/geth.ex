defmodule EthereumJSONRPC.WebSocket.Case.Geth do
  @moduledoc """
  `EthereumJSONRPC.WebSocket.Case` connecting to Geth.
  """

  import ExUnit.Callbacks, only: [start_supervised!: 1]

  def setup do
    url = "wss://mainnet.infura.io/ws/8lTvJTKmHPCHazkneJsY"
    web_socket_module = EthereumJSONRPC.WebSocket.WebSocketClient
    web_socket = start_supervised!({web_socket_module, [url, [keepalive: :timer.minutes(10)], []]})

    %{
      block_interval: 25_000,
      subscribe_named_arguments: [
        transport: EthereumJSONRPC.WebSocket,
        transport_options: %EthereumJSONRPC.WebSocket{
          web_socket: web_socket_module,
          web_socket_options: %EthereumJSONRPC.WebSocket.WebSocketClient.Options{web_socket: web_socket},
          url: url
        }
      ]
    }
  end
end
