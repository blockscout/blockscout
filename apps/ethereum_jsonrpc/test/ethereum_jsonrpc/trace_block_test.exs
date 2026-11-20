# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.TraceBlockTest do
  use ExUnit.Case, async: true

  import Mox

  alias EthereumJSONRPC.RSK

  setup :verify_on_exit!

  setup do
    %{json_rpc_named_arguments: [transport: EthereumJSONRPC.Mox, transport_options: [], variant: RSK]}
  end

  describe "fetch_block_internal_transactions/2 batch response completeness" do
    test "returns an error when a block reply is missing", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id_1, params: ["0x1"]}, %{params: ["0x2"]}], _ ->
        {:ok, [%{id: id_1, result: []}]}
      end)
      # the block left without a reply is requested again, separately
      |> expect(:json_rpc, fn [%{params: ["0x2"]}], _ -> {:ok, []} end)

      assert {:error, {:missing_responses, [2]}} =
               RSK.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
    end

    test "accepts a complete batch with out-of-order replies", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id_1, params: ["0x1"]}, %{id: id_2, params: ["0x2"]}], _ ->
        {:ok, [%{id: id_2, result: []}, %{id: id_1, result: []}]}
      end)

      assert {:ok, []} = RSK.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
    end

    test "returns the received reply error over a missing reply", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{params: ["0x1"]}, %{id: id_2, params: ["0x2"]}], _ ->
        {:ok, [%{id: id_2, error: %{code: -32_000, message: "historical backend error"}}]}
      end)
      |> expect(:json_rpc, fn [%{params: ["0x1"]}], _ -> {:ok, []} end)

      assert {:error, [%{message: "historical backend error", data: %{"blockNumber" => 2}}]} =
               RSK.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
    end

    test "attributes an id-less error by a separate request", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      error = %{code: -32_000, message: "historical backend error"}

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id_1, params: ["0x1"]}, %{params: ["0x2"]}], _ ->
        {:ok, [%{id: id_1, result: []}, %{id: nil, error: error}]}
      end)
      |> expect(:json_rpc, fn [%{params: ["0x2"]}], _ -> {:ok, [%{id: nil, error: error}]} end)

      assert {:error, [%{message: "historical backend error", data: %{"blockNumber" => 2}}]} =
               RSK.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
    end

    test "returns an unattributable id-less error without a block number", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      error = %{code: -32_000, message: "historical backend error"}

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{params: ["0x1"]}, %{params: ["0x2"]}], _ ->
        {:ok, [%{id: nil, error: error}]}
      end)

      assert {:error, [returned_error]} = RSK.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
      assert returned_error == error
    end
  end
end
