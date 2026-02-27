defmodule Explorer.Chain.FheOperationTest do
  use Explorer.DataCase

  alias Explorer.Chain.{Block, FheOperation, Hash, Transaction}

  describe "by_transaction_hash/1" do
    test "returns empty list when no operations exist" do
      transaction = insert(:transaction) |> with_block()

      assert [] == FheOperation.by_transaction_hash(transaction.hash)
    end

    test "returns operations ordered by log_index" do
      transaction = insert(:transaction) |> with_block()
      block = transaction.block

      operation_3 =
        insert(:fhe_operation,
          transaction_hash: transaction.hash,
          log_index: 3,
          block_hash: block.hash,
          block_number: block.number
        )

      operation_1 =
        insert(:fhe_operation,
          transaction_hash: transaction.hash,
          log_index: 1,
          block_hash: block.hash,
          block_number: block.number
        )

      operation_2 =
        insert(:fhe_operation,
          transaction_hash: transaction.hash,
          log_index: 2,
          block_hash: block.hash,
          block_number: block.number
        )

      operations = FheOperation.by_transaction_hash(transaction.hash)

      assert length(operations) == 3
      assert Enum.at(operations, 0).log_index == operation_1.log_index
      assert Enum.at(operations, 1).log_index == operation_2.log_index
      assert Enum.at(operations, 2).log_index == operation_3.log_index
    end

    test "only returns operations for specified transaction" do
      transaction_1 = insert(:transaction) |> with_block()
      transaction_2 = insert(:transaction) |> with_block()

      insert(:fhe_operation,
        transaction_hash: transaction_1.hash,
        log_index: 1,
        block_hash: transaction_1.block.hash,
        block_number: transaction_1.block_number
      )

      insert(:fhe_operation,
        transaction_hash: transaction_2.hash,
        log_index: 1,
        block_hash: transaction_2.block.hash,
        block_number: transaction_2.block_number
      )

      operations = FheOperation.by_transaction_hash(transaction_1.hash)

      assert length(operations) == 1
      assert Enum.at(operations, 0).transaction_hash == transaction_1.hash
    end
  end

  describe "transaction_metrics/1" do
    test "returns zero metrics when no operations exist" do
      transaction = insert(:transaction) |> with_block()

      metrics = FheOperation.transaction_metrics(transaction.hash)

      assert metrics.operation_count == 0
      assert metrics.total_hcu == 0
      assert metrics.max_depth_hcu == 0
    end

    test "calculates correct metrics for single operation" do
      transaction = insert(:transaction) |> with_block()

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 1,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        hcu_cost: 100,
        hcu_depth: 1
      )

      metrics = FheOperation.transaction_metrics(transaction.hash)

      assert metrics.operation_count == 1
      assert metrics.total_hcu == 100
      assert metrics.max_depth_hcu == 1
    end

    test "calculates correct metrics for multiple operations" do
      transaction = insert(:transaction) |> with_block()

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 1,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        hcu_cost: 100,
        hcu_depth: 1
      )

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 2,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        hcu_cost: 200,
        hcu_depth: 3
      )

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 3,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        hcu_cost: 150,
        hcu_depth: 2
      )

      metrics = FheOperation.transaction_metrics(transaction.hash)

      assert metrics.operation_count == 3
      assert metrics.total_hcu == 450
      assert metrics.max_depth_hcu == 3
    end
  end
end
