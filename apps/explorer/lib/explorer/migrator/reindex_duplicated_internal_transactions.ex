defmodule Explorer.Migrator.ReindexDuplicatedInternalTransactions do
  @moduledoc """
  Searches for all blocks that contains internal transactions with duplicated block_number, transaction_index, index,
  deletes all internal transactions for such blocks and adds them to pending operations.
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  import Ecto.Query
  import Explorer.QueryHelper, only: [select_ctid: 1, join_on_ctid: 2]

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
  def last_unprocessed_identifiers(%{"last_processed_block_number" => _} = state) do
    limit = batch_size() * concurrency()

    ids =
      state
      |> unprocessed_data_query()
      |> distinct(true)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    case {ids, state["step"]} do
      {[], step} when step != "finalize" ->
        new_state = Map.put(state, "step", "finalize")
        MigrationStatus.update_meta(migration_name(), new_state)
        last_unprocessed_identifiers(new_state)

      {ids, step} when step != "finalize" ->
        {ids, Map.put(state, "last_processed_block_number", Enum.max(ids))}

      {ids, step} when step == "finalize" ->
        {ids, state}
    end
  end

  def last_unprocessed_identifiers(state) do
    state
    |> Map.put("last_processed_block_number", -1)
    |> last_unprocessed_identifiers()
  end

  @impl FillingMigration
  def unprocessed_data_query(%{"last_processed_block_number" => last_processed_block_number} = state) do
    if state["step"] == "finalize" do
      from(
        it in InternalTransaction,
        select: it.block_hash,
        where: not is_nil(it.block_hash),
        group_by: [it.block_hash, it.transaction_index, it.index],
        having: count("*") > 1
      )
    else
      from(
        it in InternalTransaction,
        select: it.block_number,
        where: not is_nil(it.block_number) and it.block_number >= ^last_processed_block_number,
        group_by: [it.block_number, it.transaction_index, it.index],
        having: count("*") > 1,
        order_by: it.block_number
      )
    end
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
        locked_internal_transactions_to_delete_query =
          from(
            it in InternalTransaction,
            select: select_ctid(it),
            where: field(it, ^it_field) in ^block_numbers_or_hashes,
            order_by: [asc: it.transaction_hash, asc: it.index],
            lock: "FOR UPDATE"
          )

        delete_query =
          from(
            it in InternalTransaction,
            inner_join: locked_it in subquery(locked_internal_transactions_to_delete_query),
            on: join_on_ctid(it, locked_it)
          )

        Repo.delete_all(delete_query)

        pbo_params =
          Block
          |> where([b], field(b, ^block_field) in ^block_numbers_or_hashes)
          |> where([b], b.consensus == true)
          |> select([b], %{block_hash: b.hash, block_number: b.number})
          |> Repo.all()
          |> Enum.map(&Map.merge(&1, %{inserted_at: now, updated_at: now}))

        ordered_pbo_params = Enum.sort_by(pbo_params, &{&1.block_hash})

        {_total, inserted} =
          Repo.insert_all(PendingBlockOperation, ordered_pbo_params, on_conflict: :nothing, returning: [:block_number])

        inserted
      end)

    case result do
      {:ok, inserted_pbo} ->
        if not is_nil(Process.whereis(InternalTransactionFetcher)) do
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
