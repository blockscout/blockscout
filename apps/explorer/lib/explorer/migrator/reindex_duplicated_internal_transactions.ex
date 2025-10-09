defmodule Explorer.Migrator.ReindexDuplicatedInternalTransactions do
  @moduledoc """
  Searches for all blocks that contains internal transactions with duplicated block_number, transaction_index, index,
  deletes all internal transactions for such blocks and adds them to pending operations.
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  import Ecto.Query

  alias Explorer.Repo

  alias Explorer.Chain.{
    Block,
    Hash,
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
      state
      |> unprocessed_data_query()
      |> distinct(true)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    case {ids, state["step"]} do
      {[], step} when step != "finalize" ->
        new_state = %{"step" => "finalize"}
        MigrationStatus.update_meta(migration_name(), new_state)
        last_unprocessed_identifiers(new_state)

      {ids, _field} ->
        {ids, state}
    end
  end

  @impl FillingMigration
  def unprocessed_data_query(state) do
    field =
      case state["step"] do
        "finalize" -> :block_hash
        _ -> :block_number
      end

    from(
      it in InternalTransaction,
      where: not is_nil(field(it, ^field)),
      group_by: [field(it, ^field), it.transaction_index, it.index],
      having: count("*") > 1,
      select: field(it, ^field)
    )
  end

  @impl FillingMigration
  def update_batch(block_numbers_or_hashes) do
    now = DateTime.utc_now()

    {it_field, block_field} =
      case block_numbers_or_hashes do
        [number | _] when is_integer(number) -> {:block_number, :number}
        [%Hash{} | _] -> {:block_hash, :hash}
      end

    result =
      Repo.transaction(fn ->
        InternalTransaction
        |> where([it], field(it, ^it_field) in ^block_numbers_or_hashes)
        |> Repo.delete_all()

        pbo_params =
          Block
          |> where([b], field(b, ^block_field) in ^block_numbers_or_hashes)
          |> where([b], b.consensus == true)
          |> select([b], %{block_hash: b.hash, block_number: b.number})
          |> Repo.all()
          |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))

        {_total, inserted} =
          Repo.insert_all(PendingBlockOperation, pbo_params, on_conflict: :nothing, returning: [:block_number])

        inserted
      end)

    case result do
      {:ok, inserted_pbo} ->
        unless is_nil(Process.whereis(InternalTransactionFetcher)) do
          inserted_pbo
          |> Enum.map(& &1.block_number)
          |> InternalTransactionFetcher.async_fetch([], false)
        end

        :ok

      {:error, error} ->
        Logger.error("Migration #{@migration_name} failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
