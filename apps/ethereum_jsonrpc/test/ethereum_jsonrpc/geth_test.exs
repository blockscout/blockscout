defmodule EthereumJSONRPC.GethTest do
  use EthereumJSONRPC.Case, async: false

  import Mox

  alias EthereumJSONRPC.Geth

  @moduletag :no_parity

  describe "fetch_internal_transactions/2" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      block_number = 3_287_375
      EthereumJSONRPC.Geth.fetch_internal_transactions(block_number, json_rpc_named_arguments)
    end
  end

  describe "fetch_pending_transactions/1" do
    test "is not supported", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      EthereumJSONRPC.Geth.fetch_pending_transactions(json_rpc_named_arguments)
    end
  end
end
