defmodule EthereumJSONRPC.WebSocket.Case do
  use ExUnit.CaseTemplate

  import EthereumJSONRPC.Case, only: [module: 2]

  setup do
    module("ETHEREUM_JSONRPC_WEB_SOCKET_CASE", "EthereumJSONRPC.WebSocket.Case.Mox").setup()
  end
end
