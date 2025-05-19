defmodule Explorer.Migrator.ReindexDuplicatedInternalTransactionsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.{InternalTransaction, PendingBlockOperation}
  alias Explorer.Migrator.{MigrationStatus, ReindexDuplicatedInternalTransactions}
  alias Explorer.Repo

  test "Reindex duplicated internal transactions" do
    transaction_from_invalid_block =
      :transaction
      |> insert()
      |> with_block()

    Enum.each(1..10, fn index ->
      insert(
        :internal_transaction,
        transaction: transaction_from_invalid_block,
        index: index,
        block_number: transaction_from_invalid_block.block_number,
        transaction_index: transaction_from_invalid_block.index,
        block_hash: transaction_from_invalid_block.block_hash,
        block_index: index
      )
    end)

    Enum.each(11..13, fn index ->
      insert(
        :internal_transaction,
        transaction: transaction_from_invalid_block,
        index: index - 10,
        block_number: transaction_from_invalid_block.block_number,
        transaction_index: transaction_from_invalid_block.index,
        block_hash: transaction_from_invalid_block.block_hash,
        block_index: index
      )
    end)

    transaction_from_valid_block =
      :transaction
      |> insert()
      |> with_block()

    Enum.each(1..10, fn index ->
      insert(
        :internal_transaction,
        transaction: transaction_from_valid_block,
        index: index,
        block_number: transaction_from_valid_block.block_number,
        transaction_index: transaction_from_valid_block.index,
        block_hash: transaction_from_valid_block.block_hash,
        block_index: index
      )
    end)

    assert MigrationStatus.get_status("reindex_duplicated_internal_transactions") == nil

    ReindexDuplicatedInternalTransactions.start_link([])

    wait_for_results(fn ->
      Repo.one!(from(pbo in PendingBlockOperation, limit: 1))
    end)

    assert MigrationStatus.get_status("reindex_duplicated_internal_transactions") == "completed"

    internal_transactions = Repo.all(InternalTransaction)

    assert Enum.count(internal_transactions) == 10

    Enum.each(internal_transactions, fn it ->
      assert it.block_hash == transaction_from_valid_block.block_hash
    end)

    pbo = Repo.one(PendingBlockOperation)

    assert pbo.block_hash == transaction_from_invalid_block.block_hash
    assert pbo.block_number == transaction_from_invalid_block.block_number
  end
end
