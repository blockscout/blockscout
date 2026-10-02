# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.ReindexBlocksWithStaleInternalTransactionsTest do
  use Explorer.DataCase, async: false

  alias Explorer.Chain.Block
  alias Explorer.Chain.InternalTransaction.DeleteQueue
  alias Explorer.Migrator.{MigrationStatus, ReindexBlocksWithStaleInternalTransactions}
  alias Explorer.Repo

  @migration_name "reindex_blocks_with_stale_internal_transactions"

  setup do
    configuration = Application.get_env(:explorer, ReindexBlocksWithStaleInternalTransactions)

    Application.put_env(
      :explorer,
      ReindexBlocksWithStaleInternalTransactions,
      Keyword.merge(configuration || [], batch_size: 1, concurrency: 1)
    )

    on_exit(fn ->
      Application.put_env(:explorer, ReindexBlocksWithStaleInternalTransactions, configuration)
    end)
  end

  test "sends blocks with internal transactions left from non-consensus blocks to full refetch" do
    now = Timex.now()

    # internal transactions of the block that lost consensus were not deleted
    stale_block = insert(:block)
    :transaction |> insert() |> with_block(stale_block)

    insert(:block,
      number: stale_block.number,
      consensus: false,
      inserted_at: Timex.shift(now, hours: -3),
      updated_at: Timex.shift(now, hours: -1)
    )

    insert(:internal_transaction,
      block_number: stale_block.number,
      transaction_index: 5,
      index: 1,
      inserted_at: Timex.shift(now, hours: -2)
    )

    # uncle block fetched after the internal transactions of the consensus block had been imported
    uncle_block = insert(:block)
    uncle_transaction = :transaction |> insert() |> with_block(uncle_block)
    uncle_inserted_at = Timex.shift(now, hours: -1)

    insert(:block,
      number: uncle_block.number,
      consensus: false,
      inserted_at: uncle_inserted_at,
      updated_at: uncle_inserted_at
    )

    insert(:internal_transaction,
      transaction: uncle_transaction,
      block_number: uncle_block.number,
      transaction_index: uncle_transaction.index,
      index: 1,
      inserted_at: Timex.shift(now, hours: -2)
    )

    # internal transactions were refetched after the block lost consensus
    refetched_block = insert(:block)
    refetched_transaction = :transaction |> insert() |> with_block(refetched_block)

    insert(:block,
      number: refetched_block.number,
      consensus: false,
      inserted_at: Timex.shift(now, hours: -3),
      updated_at: Timex.shift(now, hours: -2)
    )

    insert(:internal_transaction,
      transaction: refetched_transaction,
      block_number: refetched_block.number,
      transaction_index: refetched_transaction.index,
      index: 1,
      inserted_at: Timex.shift(now, hours: -1)
    )

    assert MigrationStatus.get_status(@migration_name) == nil

    ReindexBlocksWithStaleInternalTransactions.start_link([])

    wait_for_results(fn ->
      Repo.one!(from(ms in MigrationStatus, where: ms.migration_name == ^@migration_name and ms.status == "completed"))
    end)

    stale_block_number = stale_block.number
    assert [%{block_number: ^stale_block_number}] = Repo.all(DeleteQueue)

    assert Block |> where([b], b.number == ^stale_block_number) |> Repo.all() |> Enum.all?(& &1.refetch_needed)

    refute Block
           |> where([b], b.number in ^[uncle_block.number, refetched_block.number])
           |> Repo.all()
           |> Enum.any?(& &1.refetch_needed)
  end

  test "completes without non-consensus blocks" do
    block = insert(:block)
    transaction = :transaction |> insert() |> with_block(block)

    insert(:internal_transaction,
      transaction: transaction,
      block_number: block.number,
      transaction_index: transaction.index,
      index: 1,
      inserted_at: Timex.shift(Timex.now(), hours: -1)
    )

    ReindexBlocksWithStaleInternalTransactions.start_link([])

    wait_for_results(fn ->
      Repo.one!(from(ms in MigrationStatus, where: ms.migration_name == ^@migration_name and ms.status == "completed"))
    end)

    assert Repo.all(DeleteQueue) == []
    refute Repo.reload!(block).refetch_needed
  end
end
