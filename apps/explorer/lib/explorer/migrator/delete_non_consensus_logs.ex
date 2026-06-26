# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.DeleteNonConsensusLogs do
  @moduledoc """
  Deletes all logs related to non-consensus blocks
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias Explorer.Chain.{Block, Log}
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "delete_non_consensus_logs"

  @impl FillingMigration
  def migration_name, do: @migration_name

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
    Log
    |> join(:inner, [l], b in Block, on: l.block_hash == b.hash)
    |> where([l], l.block_number in ^block_numbers)
    |> where([l, b], b.consensus == false)
    |> Repo.delete_all(timeout: :infinity)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
