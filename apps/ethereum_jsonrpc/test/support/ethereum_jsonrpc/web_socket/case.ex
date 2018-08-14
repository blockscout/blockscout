defmodule EthereumJSONRPC.WebSocket.Case do
  use ExUnit.CaseTemplate

  alias EthereumJSONRPC.WebSocket

  setup do
    pid = start_supervised!({WebSocket.Client, %{url: url()}})

    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.WebSocket,
        transport_options: %{
          pid: pid
        }
      ]
    }
  end

  def url do
    "ETHEREUM_JSONRPC_WEB_SOCKET_URL"
    |> System.get_env()
    |> Kernel.||("wss://sokol-ws.poa.network/ws")
  end
end
