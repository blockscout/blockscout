defmodule Explorer.Migrator.ReindexInternalTransactionsWithIncompatibleStatus do
  @moduledoc """
  Searches for all failed transactions for which all internal transactions are successful
  and adds them to pending_block_operations or pending_transaction_operations.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.{
    Block,
    InternalTransaction,
    PendingBlockOperation,
    PendingOperationsHelper,
    PendingTransactionOperation,
    Transaction
  }

  alias Explorer.Migrator.FillingMigration
  alias Indexer.Fetcher.InternalTransaction, as: InternalTransactionFetcher

  @migration_name "reindex_internal_transactions_with_incompatible_status"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select_query()
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
      where: t.block_consensus == true,
      where: not is_nil(t.block_number),
      where: not exists(pbo_query),
      where: exists(it_query),
      where: not exists(it_error_query)
    )
  end

  @impl FillingMigration
  def update_batch(block_numbers_or_transaction_hashes) do
    now = DateTime.utc_now()

    pending_operations_type = PendingOperationsHelper.pending_operations_type()

    {_total, inserted} =
      case pending_operations_type do
        "blocks" ->
          params =
            Block
            |> where([b], b.number in ^block_numbers_or_transaction_hashes)
            |> where([b], b.consensus == true)
            |> select([b], %{block_hash: b.hash, block_number: b.number})
            |> Repo.all()
            |> Enum.uniq_by(& &1.block_number)
            |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))

          Repo.insert_all(PendingBlockOperation, params, on_conflict: :nothing, returning: [:block_number])

        "transactions" ->
          params =
            Enum.map(block_numbers_or_transaction_hashes, fn transaction_hash ->
              %{transaction_hash: transaction_hash, inserted_at: now, updated_at: now}
            end)

          Repo.insert_all(PendingTransactionOperation, params, on_conflict: :nothing, returning: [:transaction_hash])
      end

    unless is_nil(Process.whereis(InternalTransactionFetcher)) do
      {block_numbers, transactions} =
        case pending_operations_type do
          "blocks" ->
            {Enum.map(inserted, & &1.block_number), []}

          "transactions" ->
            transactions =
              inserted
              |> Enum.map(& &1.transaction_hash)
              |> Chain.get_transactions_by_hashes()

            {[], transactions}
        end

      InternalTransactionFetcher.async_fetch(block_numbers, transactions, false)
    end
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp select_query(query) do
    case PendingOperationsHelper.pending_operations_type() do
      "blocks" -> select(query, [t], t.block_number)
      "transactions" -> select(query, [t], t.hash)
    end
  end
end
