# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.ReindexBlocksWithUncatalogedTokenTransfers do
  @moduledoc """
  Searches for blocks containing token transfer logs that don't have an
  associated token transfer record and adds them to missing block ranges so
  they are re-fetched and the missed token transfers get cataloged.

  Missed token transfers happen due to formats that weren't supported at the
  time they were parsed during main indexing. The migration processes blocks
  in batches from the maximum block number down to 0 and persists its
  progress, so it runs to completion only once. To re-run it after a parser
  update, delete the "reindex_blocks_with_uncataloged_token_transfers" record
  from the `migration_status` table.
  """

  use Explorer.Migrator.FillingMigration

  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.TokenTransfer
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Utility.MissingBlockRange

  @migration_name "reindex_blocks_with_uncataloged_token_transfers"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"max_block_number" => -1} = state), do: {[], state}

  def last_unprocessed_identifiers(%{"max_block_number" => from_block_number} = state) do
    limit = batch_size() * concurrency()
    to_block_number = max(from_block_number - limit + 1, 0)

    {Enum.to_list(from_block_number..to_block_number//-1), %{state | "max_block_number" => to_block_number - 1}}
  end

  def last_unprocessed_identifiers(state) do
    state
    |> Map.put("max_block_number", BlockNumber.get_max())
    |> last_unprocessed_identifiers()
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    {min_block_number, max_block_number} = Enum.min_max(block_numbers)

    case TokenTransfer.uncataloged_token_transfer_block_numbers(min_block_number, max_block_number) do
      [] -> :ok
      uncataloged_block_numbers -> MissingBlockRange.add_ranges_by_block_numbers(uncataloged_block_numbers)
    end
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
