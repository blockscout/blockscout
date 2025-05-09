defmodule Explorer.Migrator.ReindexDuplicatedInternalTransactions do
  @moduledoc """
  Searches for all blocks that contains internal transactions with duplicated block_hash, transaction_index, index,
  deletes all internal transactions for such blocks and adds them to pending operations.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Repo

  alias Explorer.Chain.{
    Block,
    InternalTransaction,
    PendingBlockOperation
  }

  alias Explorer.Migrator.FillingMigration
  alias Indexer.Fetcher.InternalTransaction, as: InternalTransactionFetcher

  @migration_name "reindex_duplicated_internal_transactions"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> distinct(true)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(
      it in InternalTransaction,
      group_by: [it.block_hash, it.transaction_index, it.index],
      having: count("*") > 1,
      select: it.block_hash
    )
  end

  @impl FillingMigration
  def update_batch(block_hashes) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      InternalTransaction
      |> where([it], it.block_hash in ^block_hashes)
      |> Repo.delete_all()

      pbo_params =
        Block
        |> where([b], b.hash in ^block_hashes)
        |> where([b], b.consensus == true)
        |> select([b], %{block_hash: b.hash, block_number: b.number})
        |> Repo.all()
        |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))

      {_total, inserted} =
        Repo.insert_all(PendingBlockOperation, pbo_params, on_conflict: :nothing, returning: [:block_number])

      unless is_nil(Process.whereis(InternalTransactionFetcher)) do
        inserted
        |> Enum.map(& &1.block_number)
        |> InternalTransactionFetcher.async_fetch([], false)
      end
    end)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
