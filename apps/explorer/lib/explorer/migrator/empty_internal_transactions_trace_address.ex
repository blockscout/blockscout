defmodule Explorer.Migrator.EmptyInternalTransactionsTraceAddress do
  @moduledoc """
  Searches for all internal transactions with non-empty trace_address and empties it.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Ecto.Multi
  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "empty_internal_transactions_trace_address"

  @fields ~w(block_hash transaction_index index)a

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    internal_transactions =
      unprocessed_data_query()
      |> select([it], ^@fields)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {internal_transactions, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(
      internal_transaction in InternalTransaction,
      where: not is_nil(internal_transaction.trace_address)
    )
  end

  @impl FillingMigration
  def update_batch(internal_transactions) do
    update_transaction =
      internal_transactions
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {internal_transaction, ind}, acc ->
        acc
        |> Multi.update_all(
          String.to_atom("update_internal_transactions_trace_address_#{ind}"),
          from(
            it in InternalTransaction,
            where: it.block_hash == ^internal_transaction.block_hash,
            where: it.transaction_index == ^internal_transaction.transaction_index,
            where: it.index == ^internal_transaction.index
          ),
          set: [trace_address: nil]
        )
      end)

    update_transaction
    |> Repo.transact()
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
