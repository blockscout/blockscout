defmodule Explorer.Migrator.ReindexInternalTransactionsWithIncompatibleStatus do
  @moduledoc """
  Searches for all failed transactions for which all internal transactions are successful
  and adds block numbers of these transactions to pending_block_operations.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Block, InternalTransaction, PendingBlockOperation, Transaction}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "reindex_internal_transactions_with_incompatible_status"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([t], t.block_number)
      |> distinct(true)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    pbo_query =
      from(
        pbo in PendingBlockOperation,
        where: pbo.block_number == parent_as(:transaction).block_number
      )

    it_query =
      from(
        it in InternalTransaction,
        where: parent_as(:transaction).hash == it.transaction_hash and it.index > 0,
        select: 1
      )

    it_error_query =
      from(
        it in InternalTransaction,
        where: parent_as(:transaction).hash == it.transaction_hash and not is_nil(it.error) and it.index > 0,
        select: 1
      )

    from(
      t in Transaction,
      as: :transaction,
      where: t.status == ^:error,
      where: not is_nil(t.block_number),
      where: not exists(pbo_query),
      where: exists(it_query),
      where: not exists(it_error_query)
    )
  end

  @impl FillingMigration
  def update_batch(block_numbers) do
    now = DateTime.utc_now()

    params =
      Block
      |> where([b], b.number in ^block_numbers)
      |> select([b], %{block_hash: b.hash, block_number: b.number})
      |> Repo.all()
      |> Enum.uniq_by(& &1.block_number)
      |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))

    Repo.insert_all(PendingBlockOperation, params, on_conflict: :nothing)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
