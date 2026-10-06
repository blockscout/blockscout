# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Migrator.ReindexBlocksWithStaleInternalTransactions do
  @moduledoc """
  Searches for blocks whose internal transactions were not refreshed after a
  block with the same number lost consensus and sends them to a full refetch
  (see `Explorer.Chain.Block.full_refetch/1`).

  Internal transactions of a block that lost consensus used to stay in the DB
  until reorgs started to be handled via `internal_transactions_delete_queue`.
  Since internal transactions are identified by
  `(block_number, transaction_index, index)` only, such leftovers are
  indistinguishable from the internal transactions of the consensus block.

  Every import of a consensus block bumps `updated_at` of all the other blocks
  with the same number, and the internal transactions of that number are
  deleted and refetched afterwards, so they get a later `inserted_at`. Thus a
  block number is considered stale if it has a non-consensus block and an
  internal transaction inserted between `inserted_at` and `updated_at` of that
  block. The lower bound excludes uncle blocks fetched after the internal
  transactions of the consensus block had been imported.

  The migration processes block numbers in batches from the maximum down to the
  minimum number of non-consensus blocks and persists its progress, so it runs
  to completion only once. To re-run it, delete the
  "reindex_blocks_with_stale_internal_transactions" record from the
  `migrations_status` table.
  """

  use Explorer.Migrator.FillingMigration

  require Logger

  import Ecto.Query

  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Chain.{Block, InternalTransaction}
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo

  @migration_name "reindex_blocks_with_stale_internal_transactions"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(%{"max_block_number" => from_number, "min_block_number" => min_number} = state)
      when from_number < min_number,
      do: {[], state}

  def last_unprocessed_identifiers(%{"max_block_number" => from_number, "min_block_number" => min_number} = state) do
    limit = batch_size() * concurrency()
    to_number = max(from_number - limit + 1, min_number)

    {Enum.to_list(from_number..to_number//-1), %{state | "max_block_number" => to_number - 1}}
  end

  def last_unprocessed_identifiers(state) do
    {min_block_number, max_block_number} =
      Repo.one(
        from(block in Block, where: block.consensus == false, select: {min(block.number), max(block.number)}),
        timeout: :infinity
      )

    state
    |> Map.merge(%{"min_block_number" => min_block_number || 0, "max_block_number" => max_block_number || -1})
    |> last_unprocessed_identifiers()
  end

  @impl FillingMigration
  def unprocessed_data_query, do: nil

  @impl FillingMigration
  def update_batch(block_numbers) do
    {min_block_number, max_block_number} = Enum.min_max(block_numbers)

    min_block_number
    |> stale_block_numbers(max_block_number)
    |> RangesHelper.filter_traceable_block_numbers()
    |> full_refetch()
  end

  @impl FillingMigration
  def update_cache, do: :ok

  defp stale_block_numbers(from_block_number, to_block_number) do
    query =
      from(
        block in Block,
        as: :block,
        where: block.number >= ^from_block_number and block.number <= ^to_block_number,
        where: block.consensus == false,
        where: block.updated_at > block.inserted_at,
        where: exists(stale_internal_transactions_query()),
        distinct: true,
        select: block.number
      )

    Repo.all(query, timeout: :infinity)
  end

  defp stale_internal_transactions_query do
    from(
      it in InternalTransaction,
      where: it.block_number == parent_as(:block).number,
      where: it.inserted_at >= parent_as(:block).inserted_at,
      where: it.inserted_at < parent_as(:block).updated_at,
      select: 1
    )
  end

  defp full_refetch([]), do: 0

  defp full_refetch(block_numbers) do
    case Block.full_refetch(block_numbers) do
      :ok ->
        Logger.info(
          "Migration #{@migration_name} sent blocks to full refetch: #{inspect(block_numbers, limit: :infinity)}"
        )

        Enum.count(block_numbers)

      {:error, reason} ->
        raise "Migration #{@migration_name} failed to send blocks #{inspect(block_numbers, limit: :infinity)} to full refetch: #{inspect(reason)}"
    end
  end
end
