# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.PendingTransactionOperationTest do
  use Explorer.DataCase

  alias Explorer.Chain.PendingTransactionOperation

  describe "min_block_number/0" do
    test "returns nil when there are no pending transaction operations" do
      :transaction |> insert() |> with_block(insert(:block, number: 3))

      assert PendingTransactionOperation.min_block_number() == nil
    end

    test "returns the lowest block number of the transactions with pending operations" do
      for block_number <- [9, 4, 6] do
        transaction = :transaction |> insert() |> with_block(insert(:block, number: block_number))
        insert(:pending_transaction_operation, transaction_hash: transaction.hash)
      end

      # a transaction of a lower block without a pending operation
      :transaction |> insert() |> with_block(insert(:block, number: 2))

      assert PendingTransactionOperation.min_block_number() == 4
    end
  end
end
