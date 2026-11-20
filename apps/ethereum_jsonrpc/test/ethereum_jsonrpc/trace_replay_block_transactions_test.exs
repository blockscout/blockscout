# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule EthereumJSONRPC.TraceReplayBlockTransactionsTest do
  use ExUnit.Case, async: true

  import Mox

  alias EthereumJSONRPC.Nethermind

  setup :verify_on_exit!

  setup do
    EthereumJSONRPC.Case.Nethermind.Mox.setup()
  end

  @transaction_hash_1 "0x0fa6f723216dba694337f9bb37d8870725655bdf2573526a39454685659e39b1"
  @transaction_hash_2 "0x0fa6f723216dba694337f9bb37d8870725655bdf2573526a39454685659e39b2"
  @block_hash "0x74c72ccabcb98b7ebbd7b31de938212b7e8814a002263b6569564e944d88f51f"

  defp trace do
    %{
      "action" => %{
        "callType" => "call",
        "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
        "to" => "0x1e0eaa06d02f965be2dfe0bc9ff52b2d82133461",
        "gas" => "0x5208",
        "input" => "0x",
        "value" => "0x0"
      },
      "result" => %{"gasUsed" => "0x0", "output" => "0x"},
      "traceAddress" => [],
      "type" => "call"
    }
  end

  defp block_reply(id, transaction_hash),
    do: %{id: id, result: [%{"trace" => [trace()], "transactionHash" => transaction_hash}]}

  @block_hash_2 "0x74c72ccabcb98b7ebbd7b31de938212b7e8814a002263b6569564e944d88f520"

  defp first_trace_params(transaction_hash \\ @transaction_hash_1) do
    %{hash_data: transaction_hash, block_hash: @block_hash, block_number: 1, transaction_index: 0}
  end

  describe "fetch_block_internal_transactions/2 batch response completeness" do
    test "returns an error when a block reply is missing", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id_1, params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [block_reply(id_1, @transaction_hash_1)]}
      end)
      # the block left without a reply is requested again, separately
      |> expect(:json_rpc, fn [%{params: ["0x2", _]}], _ -> {:ok, []} end)

      assert {:error, {:missing_responses, [2]}} =
               Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
    end

    test "accepts a complete batch with out-of-order replies", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id_1, params: ["0x1", _]}, %{id: id_2, params: ["0x2", _]}], _ ->
        {:ok, [block_reply(id_2, @transaction_hash_2), block_reply(id_1, @transaction_hash_1)]}
      end)

      assert {:ok, internal_transactions} =
               Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)

      assert internal_transactions |> Enum.map(&{&1.block_number, &1.transaction_hash}) |> Enum.sort() ==
               [{1, @transaction_hash_1}, {2, @transaction_hash_2}]
    end

    test "keeps the received replies when a reply arrives on the separate request", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id_1, params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [block_reply(id_1, @transaction_hash_1)]}
      end)
      |> expect(:json_rpc, fn [%{id: id_2, params: ["0x2", _]}], _ ->
        {:ok, [block_reply(id_2, @transaction_hash_2)]}
      end)

      assert {:ok, internal_transactions} =
               Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)

      assert internal_transactions |> Enum.map(&{&1.block_number, &1.transaction_hash}) |> Enum.sort() ==
               [{1, @transaction_hash_1}, {2, @transaction_hash_2}]
    end

    test "returns the received reply error over a missing reply", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id_1, params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [%{id: id_1, error: %{code: -32_000, message: "historical backend error"}}]}
      end)
      |> expect(:json_rpc, fn [%{params: ["0x2", _]}], _ -> {:ok, []} end)

      # the fetcher needs the block number to mark the block for refetch
      assert {:error, [%{message: "historical backend error", data: %{"blockNumber" => 1}}]} =
               Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
    end

    test "attributes several id-less errors by separate requests, not by reply order", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      errors_by_block = %{"0x1" => %{code: -32_000, message: "first"}, "0x2" => %{code: -32_000, message: "second"}}

      EthereumJSONRPC.Mox
      # the order of the id-less replies is the opposite of the request order
      |> expect(:json_rpc, fn [%{params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [%{id: nil, error: errors_by_block["0x2"]}, %{id: nil, error: errors_by_block["0x1"]}]}
      end)
      |> expect(:json_rpc, 2, fn [%{params: [block_quantity, _]}], _ ->
        {:ok, [%{id: nil, error: errors_by_block[block_quantity]}]}
      end)

      assert {:error, errors} = Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)

      assert errors |> Enum.map(&{&1.message, &1.data["blockNumber"]}) |> Enum.sort() == [{"first", 1}, {"second", 2}]
    end

    test "returns an unattributable id-less error without a block number", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      error = %{code: -32_000, message: "historical backend error"}

      # one reply for the whole batch: exactly one call, and no block is marked
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [%{id: nil, error: error}]}
      end)

      assert {:error, [returned_error]} =
               Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)

      assert returned_error == error
    end

    test "returns the received reply errors when a separate request fails", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id_1, params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [%{id: id_1, error: %{code: -32_000, message: "historical backend error"}}]}
      end)
      |> expect(:json_rpc, fn [%{params: ["0x2", _]}], _ -> {:error, :timeout} end)

      assert {:error, [%{message: "historical backend error", data: %{"blockNumber" => 1}}]} =
               Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
    end

    test "returns the id-less error of the batch when a separate request gets no reply", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      error = %{code: -32_000, message: "historical backend error"}

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id_1, params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [block_reply(id_1, @transaction_hash_1), %{id: nil, error: error}]}
      end)
      |> expect(:json_rpc, fn [%{params: ["0x2", _]}], _ -> {:ok, []} end)

      # not attributed to the block that wasn't answered separately
      assert {:error, [returned_error]} =
               Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)

      assert returned_error == error
    end

    test "does not return the block number a node put into an unattributable error", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [%{id: nil, error: %{code: -32_000, message: "historical backend error", data: %{"blockNumber" => 99}}}]}
      end)

      # the fetcher marks the block of such an error for refetch
      assert {:error, [%{message: "historical backend error", data: data}]} =
               Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)

      assert data == %{}
    end

    test "returns the failure of a separate request when no error is received", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn [%{id: id_1, params: ["0x1", _]}, %{params: ["0x2", _]}], _ ->
        {:ok, [block_reply(id_1, @transaction_hash_1)]}
      end)
      |> expect(:json_rpc, fn [%{params: ["0x2", _]}], _ -> {:error, :timeout} end)

      assert {:error, :timeout} = Nethermind.fetch_block_internal_transactions([1, 2], json_rpc_named_arguments)
    end
  end

  describe "fetch_first_trace/2 errors" do
    test "returns the failure of the request instead of raising", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [_], _ -> {:error, :timeout} end)

      assert {:error, :timeout} = Nethermind.fetch_first_trace([first_trace_params()], json_rpc_named_arguments)
    end

    test "returns an error when the transaction reply is missing", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [_], _ -> {:ok, []} end)

      assert {:error, {:missing_responses, [%{hash_data: @transaction_hash_1}]}} =
               Nethermind.fetch_first_trace([first_trace_params()], json_rpc_named_arguments)
    end

    test "returns :not_found when the transaction has no traces", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [%{id: id}], _ -> {:ok, [%{id: id, result: %{"trace" => []}}]} end)

      assert {:error, :not_found} = Nethermind.fetch_first_trace([first_trace_params()], json_rpc_named_arguments)
    end

    test "returns an unattributable id-less error instead of missing replies", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      error = %{code: -32_000, message: "boom"}

      expect(EthereumJSONRPC.Mox, :json_rpc, fn [_, _], _ -> {:ok, [%{id: nil, error: error}]} end)

      assert {:error, [^error]} =
               Nethermind.fetch_first_trace(
                 [first_trace_params(@transaction_hash_1), first_trace_params(@transaction_hash_2)],
                 json_rpc_named_arguments
               )
    end

    test "returns the block of the transaction the trace belongs to", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      transactions_params = [
        first_trace_params(@transaction_hash_1),
        %{hash_data: @transaction_hash_2, block_hash: @block_hash_2, block_number: 2, transaction_index: 0}
      ]

      # the first requested transaction has no traces
      expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _ ->
        %{id: id_1} = Enum.find(requests, &match?(%{params: [@transaction_hash_1, _]}, &1))
        %{id: id_2} = Enum.find(requests, &match?(%{params: [@transaction_hash_2, _]}, &1))

        {:ok,
         [
           %{id: id_2, result: %{"trace" => [trace()], "transactionHash" => @transaction_hash_2}},
           %{id: id_1, result: %{"trace" => []}}
         ]}
      end)

      assert {:ok,
              [
                %{
                  first_trace: %{transaction_hash: @transaction_hash_2, block_number: 2},
                  block_hash: @block_hash_2,
                  block_number: 2
                }
              ]} = Nethermind.fetch_first_trace(transactions_params, json_rpc_named_arguments)
    end

    test "attributes an id-less error reply to the requested transaction", %{
      json_rpc_named_arguments: json_rpc_named_arguments
    } do
      expect(EthereumJSONRPC.Mox, :json_rpc, fn [_], _ ->
        {:ok, [%{id: nil, error: %{code: -32_000, message: "boom"}}]}
      end)

      assert {:error, [%{message: "boom", data: %{"transactionHash" => @transaction_hash_1}}]} =
               Nethermind.fetch_first_trace([first_trace_params()], json_rpc_named_arguments)
    end
  end
end
