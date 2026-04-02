defmodule Indexer.PendingTransactionsSanitizerTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.Transaction
  alias Explorer.Repo
  alias Indexer.PendingTransactionsSanitizer

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
  end
end
