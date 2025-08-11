defmodule Explorer.Migrator.EmptyInternalTransactionsZeroValues do
  @moduledoc """
  Searches for all internal transactions with zero `value` and empties it.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Ecto.Multi
  alias Explorer.Chain.InternalTransaction
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "empty_internal_transactions_zero_values"

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
      where: internal_transaction.value == ^0
    )
  end

  # sobelow_skip ["DOS.StringToAtom"]
  @impl FillingMigration
  def update_batch(internal_transactions) do
    now = DateTime.utc_now()

    update_transaction =
      internal_transactions
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {internal_transaction, ind}, acc ->
        acc
        |> Multi.update_all(
          String.to_atom("update_internal_transactions_value_#{ind}"),
          from(
            it in InternalTransaction,
            where: it.block_hash == ^internal_transaction.block_hash,
            where: it.transaction_index == ^internal_transaction.transaction_index,
            where: it.index == ^internal_transaction.index
          ),
          set: [value: nil, updated_at: now]
        )
      end)

    update_transaction
    |> Repo.transact()
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
