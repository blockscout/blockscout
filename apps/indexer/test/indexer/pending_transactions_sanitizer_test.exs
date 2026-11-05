# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.PendingTransactionsSanitizerTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import ExUnit.CaptureLog, only: [capture_log: 1]
  import Mox

  alias Explorer.Chain.{Transaction, Wei}
  alias Explorer.Repo
  alias Indexer.PendingTransactionsSanitizer

  setup :verify_on_exit!

  describe "sanitize_pending_transactions/1" do
    test "with included transaction", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      pending_transaction = insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -2))
      block = insert(:block, consensus: true, refetch_needed: false)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "transactionHash" => to_string(pending_transaction.hash),
                 "blockHash" => to_string(block.hash),
                 "cumulativeGasUsed" => "0x5208",
                 "gasUsed" => "0x5208",
                 "status" => "0x1",
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end
      )

      PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)

      updated_block = Repo.reload(block)
      assert updated_block.refetch_needed == true

      assert [transaction] = Repo.all(Transaction)

      assert transaction.cumulative_gas_used == Decimal.new("21000")
      assert transaction.gas_used == Decimal.new("21000")
      assert transaction.block_hash == block.hash
      assert transaction.status == :ok
      assert transaction.index == 0
    end

    test "with empty result", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -2))
      block = insert(:block, consensus: true, refetch_needed: false)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: nil
             }
           ]}
        end
      )

      PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)

      updated_block = Repo.reload(block)
      assert updated_block.refetch_needed == false

      assert [] = Repo.all(Transaction)
    end

    test "with non-consensus block", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      pending_transaction = insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -2))
      block = insert(:block, consensus: false, refetch_needed: false)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "transactionHash" => to_string(pending_transaction.hash),
                 "blockHash" => to_string(block.hash),
                 "cumulativeGasUsed" => "0x5208",
                 "gasUsed" => "0x5208",
                 "status" => "0x1",
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end
      )

      PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)

      updated_block = Repo.reload(block)
      assert updated_block.refetch_needed == false

      assert [transaction] = Repo.all(Transaction)

      assert transaction.cumulative_gas_used == Decimal.new("21000")
      assert transaction.gas_used == Decimal.new("21000")
      assert transaction.block_hash == block.hash
      assert transaction.status == :ok
      assert transaction.index == 0
    end

    test "with gas price and contract address", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      pending_transaction = insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -2), gas_price: nil)
      block = insert(:block, consensus: true, refetch_needed: false)
      contract_address = insert(:address)

      EthereumJSONRPC.Mox
      |> expect(
        :json_rpc,
        fn _json, _options ->
          {:ok,
           [
             %{
               id: 0,
               jsonrpc: "2.0",
               result: %{
                 "transactionHash" => to_string(pending_transaction.hash),
                 "blockHash" => to_string(block.hash),
                 "cumulativeGasUsed" => "0x5208",
                 "gasUsed" => "0x5208",
                 "effectiveGasPrice" => "0x76be5e6c00",
                 "contractAddress" => to_string(contract_address.hash),
                 "status" => "0x1",
                 "transactionIndex" => "0x0"
               }
             }
           ]}
        end
      )

      PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)

      updated_block = Repo.reload(block)
      assert updated_block.refetch_needed == true

      assert [transaction] = Repo.all(Transaction)

      assert transaction.cumulative_gas_used == Decimal.new("21000")
      assert transaction.gas_used == Decimal.new("21000")
      assert Wei.to(transaction.gas_price, :wei) == Decimal.new("510000000000")
      assert transaction.block_hash == block.hash
      assert transaction.created_contract_address_hash == contract_address.hash
      assert transaction.status == :ok
      assert transaction.index == 0
    end

    test "processes all pending transactions page by page", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      set_receipts_batch_size(2)

      # The same `inserted_at` makes the pages split by the transaction hash.
      inserted_at = Timex.shift(Timex.now(), days: -2)
      stale_transactions = insert_list(5, :transaction, inserted_at: inserted_at)
      fresh_transaction = insert(:transaction)

      {still_pending_transactions, not_found_transactions} = Enum.split(stale_transactions, 2)

      results =
        Map.merge(
          Map.new(still_pending_transactions, &{to_string(&1.hash), still_pending_receipt(&1)}),
          Map.new(not_found_transactions, &{to_string(&1.hash), nil})
        )

      expect_receipts(EthereumJSONRPC.Mox, 3, results)

      PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)

      assert_received {:receipts_requested, first_page_hashes}
      assert_received {:receipts_requested, second_page_hashes}
      assert_received {:receipts_requested, third_page_hashes}

      assert Enum.map([first_page_hashes, second_page_hashes, third_page_hashes], &length/1) == [2, 2, 1]

      assert Enum.sort(first_page_hashes ++ second_page_hashes ++ third_page_hashes) ==
               stale_transactions |> Enum.map(&to_string(&1.hash)) |> Enum.sort()

      assert transaction_hashes(Repo.all(Transaction)) ==
               transaction_hashes([fresh_transaction | still_pending_transactions])
    end

    test "continues with the next page after a failed one", %{json_rpc_named_arguments: json_rpc_named_arguments} do
      set_receipts_batch_size(1)

      failed_transaction = insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -3))
      not_found_transaction = insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -2))

      EthereumJSONRPC.Mox
      |> expect(:json_rpc, fn _requests, _options -> {:error, :econnrefused} end)
      |> expect_receipts(1, %{to_string(not_found_transaction.hash) => nil})

      log =
        capture_log(fn ->
          PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)
        end)

      assert log =~ "Error while fetching pending transaction receipts: :econnrefused"

      assert_received {:receipts_requested, [not_found_transaction_hash]}
      assert not_found_transaction_hash == to_string(not_found_transaction.hash)

      assert transaction_hashes(Repo.all(Transaction)) == transaction_hashes([failed_transaction])
    end

    test "leaves the transactions that become stale during a run to the next run",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      set_receipts_batch_size(1)
      window_size = Application.get_env(:indexer, PendingTransactionsSanitizer)[:window_size]
      test_pid = self()

      insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -2))

      expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _options ->
        [%{id: id}] = List.flatten(requests)

        # Newer than the cutoff of the run, but older than `window_size` by the time the next page is read.
        transaction = insert(:transaction, inserted_at: DateTime.add(DateTime.utc_now(), -window_size, :millisecond))
        send(test_pid, {:became_stale, transaction})

        {:ok, [%{id: id, jsonrpc: "2.0", result: nil}]}
      end)

      PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)

      assert_received {:became_stale, became_stale_transaction}
      assert transaction_hashes(Repo.all(Transaction)) == transaction_hashes([became_stale_transaction])
    end

    test "does not delete a transaction included into a block after its receipt is fetched",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      transaction = insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -2))
      block = insert(:block, consensus: true)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _options ->
        [%{id: id}] = List.flatten(requests)

        # The block with the transaction is imported after the node responded.
        with_block(transaction, block)

        {:ok, [%{id: id, jsonrpc: "2.0", result: nil}]}
      end)

      PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)

      assert [%Transaction{block_hash: block_hash}] = Repo.all(Transaction)
      assert block_hash == block.hash
    end

    test "does not update a transaction included into a block after its receipt is fetched",
         %{json_rpc_named_arguments: json_rpc_named_arguments} do
      transaction = insert(:transaction, inserted_at: Timex.shift(Timex.now(), days: -2))
      block = insert(:block, consensus: true, refetch_needed: false)

      expect(EthereumJSONRPC.Mox, :json_rpc, fn requests, _options ->
        [%{id: id}] = List.flatten(requests)

        # The block with the transaction is imported after the node responded.
        with_block(transaction, block, index: 1, cumulative_gas_used: 42_000, gas_used: 21_000, status: :ok)

        {:ok,
         [
           %{
             id: id,
             jsonrpc: "2.0",
             result: %{
               "transactionHash" => to_string(transaction.hash),
               "blockHash" => to_string(block.hash),
               "cumulativeGasUsed" => "0x5208",
               "gasUsed" => "0x5208",
               "status" => "0x1",
               "transactionIndex" => "0x0"
             }
           }
         ]}
      end)

      PendingTransactionsSanitizer.sanitize_pending_transactions(json_rpc_named_arguments)

      assert Repo.reload(block).refetch_needed == false

      assert [%Transaction{} = updated_transaction] = Repo.all(Transaction)
      assert updated_transaction.block_hash == block.hash
      assert updated_transaction.index == 1
      assert updated_transaction.cumulative_gas_used == Decimal.new(42_000)
    end
  end

  defp set_receipts_batch_size(receipts_batch_size) do
    initial_receipts_batch_size = Application.get_env(:indexer, :receipts_batch_size)
    Application.put_env(:indexer, :receipts_batch_size, receipts_batch_size)
    on_exit(fn -> Application.put_env(:indexer, :receipts_batch_size, initial_receipts_batch_size) end)
  end

  # Expects `times` batches of receipt requests and responds with the results from `results_by_hash`.
  # The hashes requested in each batch are sent to the test process.
  defp expect_receipts(mock, times, results_by_hash) do
    test_pid = self()

    expect(mock, :json_rpc, times, fn requests, _options ->
      requests = List.flatten(requests)

      send(test_pid, {:receipts_requested, Enum.map(requests, fn %{params: [hash]} -> hash end)})

      {:ok,
       Enum.map(requests, fn %{id: id, params: [hash]} ->
         %{id: id, jsonrpc: "2.0", result: Map.fetch!(results_by_hash, hash)}
       end)}
    end)
  end

  defp still_pending_receipt(transaction) do
    %{"transactionHash" => to_string(transaction.hash), "blockHash" => nil}
  end

  defp transaction_hashes(transactions) do
    transactions
    |> Enum.map(&to_string(&1.hash))
    |> Enum.sort()
  end
end
