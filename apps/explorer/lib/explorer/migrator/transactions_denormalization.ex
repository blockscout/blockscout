defmodule Explorer.Migrator.TransactionsDenormalization do
  @moduledoc """
  Migrates all transactions to have set block_consensus and block_timestamp
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Cache.BackgroundMigrations
  alias Explorer.Chain.Transaction
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "denormalization"

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
    from(t in Transaction,
      where: not is_nil(t.block_hash) and (is_nil(t.block_consensus) or is_nil(t.block_timestamp))
    )
  end

  @impl FillingMigration
  def update_batch(transaction_hashes) do
    query =
      from(transaction in Transaction,
        join: block in assoc(transaction, :block),
        where: transaction.hash in ^transaction_hashes,
        update: [set: [block_consensus: block.consensus, block_timestamp: block.timestamp]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_transactions_denormalization_finished(true)
  end
end
