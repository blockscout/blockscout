defmodule Explorer.Migrator.SanitizeReplacedTransactions do
  @moduledoc """
  Cleans the transactions that are related to non-consensus blocks.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Transaction
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "sanitize_replaced_transactions"

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
    from(t in Transaction, where: t.block_consensus == false)
  end

  @impl FillingMigration
  def update_batch(transaction_hashes) do
    query = from(t in Transaction, where: t.hash in ^transaction_hashes)

    Repo.delete_all(query, timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
