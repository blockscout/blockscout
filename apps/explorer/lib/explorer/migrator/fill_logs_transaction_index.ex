# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.FillLogsTransactionIndex do
  @moduledoc """
  Fills `transaction_index` field in `logs` table.
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.Cache.{BackgroundMigrations, BlockNumber}
  alias Explorer.Chain.{Log, Transaction}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Migrator.HeavyDbIndexOperation.CreateLogsBlockNumberTransactionIndexIndexUniqueIndex
  alias Explorer.Repo

  @migration_name "fill_logs_transaction_index"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def dependent_from_migrations,
    do: [CreateLogsBlockNumberTransactionIndexIndexUniqueIndex.migration_name()]

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"max_block_number" => -1} = state), do: {[], state}

  def last_unprocessed_identifiers(state) do
    block_number = state["max_block_number"] || BlockNumber.get_max()

    limit = batch_size() * concurrency()

    from_block_number = max(block_number - limit, 0)

    {Enum.to_list(from_block_number..block_number), Map.put(state, "max_block_number", from_block_number - 1)}
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    update_query =
      from(l in Log,
        inner_join: t in Transaction,
        on: l.transaction_hash == t.hash,
        where: l.block_number in ^block_numbers,
        update: [set: [transaction_index: t.index]]
      )

    Repo.update_all(update_query, [], timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache do
    BackgroundMigrations.set_fill_logs_transaction_index_finished(true)
  end
end
