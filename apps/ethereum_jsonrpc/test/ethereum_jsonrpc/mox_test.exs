defmodule EthereumJSONRPC.MoxTest do
  @moduledoc """
  Tests that only work with `EthereumJSONRPC.Mox` because they need precise data back from the network that can't be
  gotten reliably.
  """

  use ExUnit.Case, async: true

  import Mox

  setup do
    %{
      json_rpc_named_arguments: [
        transport: EthereumJSONRPC.Mox,
        transport_options: []
      ]
    }
  end

  setup :verify_on_exit!

  describe "fetch_block_number_by_tag/2" do
    test "with pending with null result", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn _json, _options ->
        {:ok, nil}
      end)

      assert {:error, :not_found} = EthereumJSONRPC.fetch_block_number_by_tag("pending", json_rpc_named_arguments)
    end
  end
end
