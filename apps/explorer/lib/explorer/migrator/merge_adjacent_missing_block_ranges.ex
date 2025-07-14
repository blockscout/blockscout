defmodule Explorer.Migrator.MergeAdjacentMissingBlockRanges do
  @moduledoc """
  Merges adjacent missing block ranges (like 10..5, 4..3) into one (10..3).
  """

  use Explorer.Migrator.FillingMigration

  import Ecto.Query

  alias EthereumJSONRPC.Utility.RangesHelper
  alias Explorer.Migrator.FillingMigration
  alias Explorer.Repo
  alias Explorer.Utility.MissingBlockRange

  @migration_name "merge_adjacent_missing_block_ranges"

  @impl FillingMigration
  def migration_name, do: @migration_name

  @impl FillingMigration
  def last_unprocessed_identifiers(state) do
    limit = batch_size()

    data =
      unprocessed_data_query()
      |> select([m1, _m2], m1)
      |> limit(^limit)
      |> Repo.all(timeout: :infinity)

    {data, state}
  end

  @impl FillingMigration
  def unprocessed_data_query do
    from(m1 in MissingBlockRange,
      inner_join: m2 in MissingBlockRange,
      on:
        m1.from_number + 1 == m2.to_number and
          ((is_nil(m1.priority) and is_nil(m2.priority)) or m1.priority == m2.priority)
    )
  end

  @impl FillingMigration
  def update_batch(ranges_batch) do
    {priority_ranges, non_priority_ranges, delete_ids} =
      Enum.reduce(ranges_batch, {[], [], []}, fn range, {priority_acc, non_priority_acc, delete_acc} ->
        if is_nil(range.priority) do
          {priority_acc, [range.from_number..range.to_number | non_priority_acc], [range.id | delete_acc]}
        else
          {[range.from_number..range.to_number | priority_acc], non_priority_acc, [range.id | delete_acc]}
        end
      end)

    Repo.transaction(fn ->
      MissingBlockRange
      |> where([m], m.id in ^Enum.uniq(delete_ids))
      |> Repo.delete_all(timeout: :infinity)

      priority_ranges
      |> RangesHelper.sanitize_ranges()
      |> MissingBlockRange.save_batch(1)

      non_priority_ranges
      |> RangesHelper.sanitize_ranges()
      |> MissingBlockRange.save_batch(nil)
    end)
  end

  @impl FillingMigration
  def update_cache, do: :ok
end
