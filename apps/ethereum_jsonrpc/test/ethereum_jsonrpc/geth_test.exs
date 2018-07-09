defmodule EthereumJSONRPC.GethTest do
  use EthereumJSONRPC.Case, async: false

  alias EthereumJSONRPC.Geth

  @moduletag :no_parity

  describe "fetch_internal_transactions/2" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      Geth.fetch_internal_transactions(
        [
          "0x2ec382949ba0b22443aa4cb38267b1fb5e68e188109ac11f7a82f67571a0adf3"
        ],
        json_rpc_named_arguments
      )
    end
  end

  describe "fetch_pending_transactions/1" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      EthereumJSONRPC.Geth.fetch_pending_transactions(json_rpc_named_arguments)
    end
  end
end
