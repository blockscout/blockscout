defmodule Explorer.Migrator.MergeAdjacentMissingBlockRangesTest do
  use Explorer.DataCase, async: false

  alias Explorer.Migrator.MergeAdjacentMissingBlockRanges
  alias Explorer.Repo
  alias Explorer.Utility.MissingBlockRange

  test "Merges adjacent ranges" do
    Repo.delete_all(MissingBlockRange)

    insert(:missing_block_range, from_number: 100, to_number: 70, priority: nil)
    insert(:missing_block_range, from_number: 69, to_number: 60, priority: nil)
    insert(:missing_block_range, from_number: 59, to_number: 50, priority: 1)
    insert(:missing_block_range, from_number: 45, to_number: 45, priority: nil)
    insert(:missing_block_range, from_number: 40, to_number: 30, priority: 1)
    insert(:missing_block_range, from_number: 29, to_number: 20, priority: 1)
    insert(:missing_block_range, from_number: 19, to_number: 10, priority: nil)
    insert(:missing_block_range, from_number: 9, to_number: 5, priority: nil)
    insert(:missing_block_range, from_number: 4, to_number: 0, priority: nil)

    MergeAdjacentMissingBlockRanges.start_link([])
    Process.sleep(100)

    ranges = Repo.all(MissingBlockRange)

    assert length(ranges) == 5

    assert Enum.any?(ranges, fn range ->
             range.from_number == 100 and range.to_number == 60 and range.priority == nil
           end)

    assert Enum.any?(ranges, fn range ->
             range.from_number == 59 and range.to_number == 50 and range.priority == 1
           end)

    assert Enum.any?(ranges, fn range ->
             range.from_number == 45 and range.to_number == 45 and range.priority == nil
           end)

    assert Enum.any?(ranges, fn range ->
             range.from_number == 40 and range.to_number == 20 and range.priority == 1
           end)

    assert Enum.any?(ranges, fn range ->
             range.from_number == 19 and range.to_number == 0 and range.priority == nil
           end)

    Repo.delete_all(MissingBlockRange)
  end
end
