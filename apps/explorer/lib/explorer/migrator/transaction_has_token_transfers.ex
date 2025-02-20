defmodule Explorer.Migrator.TransactionHasTokenTransfers do
  @moduledoc """
  Backfills the transactions table with the `has_token_transfers` field.
  """

  alias Explorer.Chain.Transaction
  alias Explorer.Migrator.FillingMigration

  use FillingMigration

  import Ecto.Query

  @migration_name "transaction_has_token_transfers"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size() * concurrency()

    ids =
      unprocessed_data_query()
      |> select([t], t.hash)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {ids, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(transaction in Transaction, where: is_nil(transaction.has_token_transfers))
  end

  @impl FillingMigration
  def update_batch(transaction_hashes) do
    Transaction
    |> where([transaction], transaction.hash in ^transaction_hashes)
    |> update([transaction],
      set: [
        has_token_transfers:
          fragment(
            "EXISTS (SELECT 1 FROM token_transfers WHERE transaction_hash = ? LIMIT 1)",
            transaction.hash
          )
      ]
    )
    |> Repo.update_all([], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
