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

  describe "top_fhe_callers/1" do
    test "returns empty list when no callers exist" do
      assert [] == FheOperation.top_fhe_callers(10)
    end

    test "returns top callers ordered by total HCU" do
      caller_1 = insert(:address)
      caller_2 = insert(:address)
      transaction = insert(:transaction) |> with_block()

      # Caller 1 operations
      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 1,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        caller: caller_1.hash,
        hcu_cost: 500
      )

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 2,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        caller: caller_1.hash,
        hcu_cost: 300
      )

      # Caller 2 operations
      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 3,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        caller: caller_2.hash,
        hcu_cost: 100
      )

      callers = FheOperation.top_fhe_callers(10)

      assert length(callers) == 2
      assert Enum.at(callers, 0).caller == caller_1.hash
      assert Enum.at(callers, 0).total_hcu == 800
      assert Enum.at(callers, 0).operation_count == 2
      assert Enum.at(callers, 1).caller == caller_2.hash
      assert Enum.at(callers, 1).total_hcu == 100
      assert Enum.at(callers, 1).operation_count == 1
    end

    test "respects limit parameter" do
      callers = Enum.map(1..5, fn _ -> insert(:address) end)
      transaction = insert(:transaction) |> with_block()

      Enum.each(callers, fn caller ->
        insert(:fhe_operation,
          transaction_hash: transaction.hash,
          log_index: :rand.uniform(1000),
          block_hash: transaction.block.hash,
          block_number: transaction.block_number,
          caller: caller.hash,
          hcu_cost: 100
        )
      end)

      top_callers = FheOperation.top_fhe_callers(3)

      assert length(top_callers) == 3
    end

    test "excludes operations without caller" do
      transaction = insert(:transaction) |> with_block()

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 1,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        caller: nil,
        hcu_cost: 100
      )

      assert [] == FheOperation.top_fhe_callers(10)
    end
  end

  describe "operation_stats/0" do
    test "returns empty list when no operations exist" do
      assert [] == FheOperation.operation_stats()
    end

    test "returns operation distribution statistics" do
      transaction = insert(:transaction) |> with_block()

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 1,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        operation: "FheAdd",
        operation_type: "arithmetic"
      )

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 2,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        operation: "FheAdd",
        operation_type: "arithmetic"
      )

      insert(:fhe_operation,
        transaction_hash: transaction.hash,
        log_index: 3,
        block_hash: transaction.block.hash,
        block_number: transaction.block_number,
        operation: "FheMul",
        operation_type: "arithmetic"
      )

      stats = FheOperation.operation_stats()

      assert length(stats) == 2

      fhe_add_stat = Enum.find(stats, &(&1.operation == "FheAdd"))
      assert fhe_add_stat.count == 2
      assert fhe_add_stat.operation_type == "arithmetic"

      fhe_mul_stat = Enum.find(stats, &(&1.operation == "FheMul"))
      assert fhe_mul_stat.count == 1
      assert fhe_mul_stat.operation_type == "arithmetic"
    end
  end
end

