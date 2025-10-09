defmodule Explorer.Migrator.TransactionBlockConsensus do
  @moduledoc """
  Fixes transactions block_consensus field
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Transaction
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "transactions_block_consensus"

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
    from(
      transaction in Transaction,
      join: block in assoc(transaction, :block),
      where: transaction.block_consensus != block.consensus
    )
  end

  @impl FillingMigration
  def update_batch(transaction_hashes) do
    query =
      from(transaction in Transaction,
        join: block in assoc(transaction, :block),
        where: transaction.hash in ^transaction_hashes,
        update: [set: [block_consensus: block.consensus]]
      )

    Repo.update_all(query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
