# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Utility.MissingBlockRangeTest do
  use ExUnit.Case, async: true

  import Explorer.Factory

  alias Explorer.Chain.Block
  alias Explorer.Repo
  alias Explorer.Utility.MissingBlockRange

  describe "add_ranges_by_block_numbers/2" do
    setup do
      # Ensure the database is clean before each test
      Repo.delete_all(MissingBlockRange)

      on_exit(fn ->
        # Clean up the database after each test
        Repo.delete_all(MissingBlockRange)
      end)

      :ok
    end

    test "adds ranges for a list of block numbers with a given priority" do
      block_numbers = [1, 2, 3, 5, 6, 10]
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 3

      assert Enum.any?(ranges, fn range ->
               range.from_number == 3 and range.to_number == 1 and range.priority == priority
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 6 and range.to_number == 5 and range.priority == priority
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 10 and range.to_number == 10 and range.priority == priority
             end)
    end

    test "handles an empty list of block numbers" do
      block_numbers = []
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert ranges == []
    end

    test "adds ranges with nil priority" do
      block_numbers = [15, 16, 20]
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 2

      assert Enum.any?(ranges, fn range ->
               range.from_number == 16 and range.to_number == 15 and is_nil(range.priority)
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 20 and range.to_number == 20 and is_nil(range.priority)
             end)
    end

    test "handles case when applying range with priority = nil overlaps with an different existing ranges in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 6, to_number: 3, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 10, to_number: 8, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 15, to_number: 12, priority: nil})

      block_numbers = 5..13 |> Enum.to_list()
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 4

      assert Enum.any?(ranges, fn range ->
               range.from_number == 15 and range.to_number == 11 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 10 and range.to_number == 8 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 7 and range.to_number == 7 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 6 and range.to_number == 3 and range.priority == 1
             end)
    end

    # failed
    test "handles case when applying range with priority = 1 overlaps with an different existing ranges in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 6, to_number: 3, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 10, to_number: 8, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 15, to_number: 12, priority: nil})

      block_numbers = 5..13 |> Enum.to_list()
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 2

      assert Enum.any?(ranges, fn range ->
               range.from_number == 15 and range.to_number == 14 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 13 and range.to_number == 3 and range.priority == 1
             end)
    end

    test "handles case when applying range with priority = nil overlaps with the same existing priority = 1 range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 12, to_number: 6, priority: 1})

      block_numbers = 7..10 |> Enum.to_list()
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 1

      assert Enum.any?(ranges, fn range ->
               range.from_number == 12 and range.to_number == 6 and range.priority == 1
             end)
    end

    test "handles case when applying range with priority = nil overlaps with the same existing nil priority range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 12, to_number: 6, priority: nil})

      block_numbers = 7..10 |> Enum.to_list()
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 1

      assert Enum.any?(ranges, fn range ->
               range.from_number == 12 and range.to_number == 6 and range.priority == nil
             end)
    end

    test "handles case when applying range with priority = 1 overlaps with the same existing priority = 1 range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 12, to_number: 6, priority: 1})

      block_numbers = 7..10 |> Enum.to_list()
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 1

      assert Enum.any?(ranges, fn range ->
               range.from_number == 12 and range.to_number == 6 and range.priority == 1
             end)
    end

    test "handles case when applying range with priority = 1 overlaps with the same existing nil priority range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 12, to_number: 6, priority: nil})

      block_numbers = 7..10 |> Enum.to_list()
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 3

      assert Enum.any?(ranges, fn range ->
               range.from_number == 12 and range.to_number == 11 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 10 and range.to_number == 7 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 6 and range.to_number == 6 and range.priority == nil
             end)
    end

    test "handles case when applying range with nil priority doesn't overlap with the existing different ranges in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 5, to_number: 4, priority: nil})
      Repo.insert!(%MissingBlockRange{from_number: 8, to_number: 7, priority: 1})

      block_numbers = 3..10 |> Enum.to_list()
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 3

      assert Enum.any?(ranges, fn range ->
               range.from_number == 6 and range.to_number == 3 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 8 and range.to_number == 7 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 10 and range.to_number == 9 and range.priority == nil
             end)
    end

    test "does not fail when the adjacent range is deleted by a concurrent transaction" do
      adjacent_range = Repo.insert!(%MissingBlockRange{from_number: 10, to_number: 8, priority: nil})
      test_pid = self()

      # e.g. `clear_batch_if_indexed/1` of a concurrent catchup task
      deleting_task =
        Task.async(fn ->
          Repo.transaction(fn ->
            Repo.delete!(adjacent_range)
            send(test_pid, :deleted)

            receive do
              :commit -> :ok
            end
          end)
        end)

      assert_receive :deleted

      adding_task = Task.async(fn -> MissingBlockRange.add_ranges_by_block_numbers([11]) end)

      # let the adding task reach the adjacent range locked by the deleting one
      Process.sleep(200)
      send(deleting_task.pid, :commit)
      Task.await(deleting_task)

      assert :ok = Task.await(adding_task)
      assert [%{from_number: 11, to_number: 11, priority: nil}] = sorted_ranges()
    end

    test "handles case when applying range with 1 priority doesn't overlap with the existing different ranges in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 5, to_number: 4, priority: nil})
      Repo.insert!(%MissingBlockRange{from_number: 8, to_number: 7, priority: 1})

      block_numbers = 3..10 |> Enum.to_list()
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 1

      assert Enum.any?(ranges, fn range ->
               range.from_number == 10 and range.to_number == 3 and range.priority == 1
             end)
    end

    test "handles case when left of the applying range with nil priority overlaps with the nil priority existing range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 112, to_number: 86, priority: nil})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 25, to_number: 20, priority: nil})

      block_numbers = 7..110 |> Enum.to_list()
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 3

      assert Enum.any?(ranges, fn range ->
               range.from_number == 112 and range.to_number == 46 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 45 and range.to_number == 30 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 29 and range.to_number == 7 and range.priority == nil
             end)
    end

    test "handles case when left of the applying range with nil priority overlaps with the priority = 1 existing range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 112, to_number: 86, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 25, to_number: 20, priority: nil})

      block_numbers = 7..110 |> Enum.to_list()
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 4

      assert Enum.any?(ranges, fn range ->
               range.from_number == 112 and range.to_number == 86 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 85 and range.to_number == 46 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 45 and range.to_number == 30 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 29 and range.to_number == 7 and range.priority == nil
             end)
    end

    test "handles case when left of the applying range with priority = 1 overlaps with the nil priority existing range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 112, to_number: 86, priority: nil})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 25, to_number: 20, priority: nil})

      block_numbers = 7..110 |> Enum.to_list()
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 2

      assert Enum.any?(ranges, fn range ->
               range.from_number == 112 and range.to_number == 111 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 110 and range.to_number == 7 and range.priority == 1
             end)
    end

    test "handles case when left of the applying range with priority = 1 overlaps with the priority = 1 existing range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 112, to_number: 86, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 25, to_number: 20, priority: nil})

      block_numbers = 7..110 |> Enum.to_list()
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 1

      assert Enum.any?(ranges, fn range ->
               range.from_number == 112 and range.to_number == 7 and range.priority == 1
             end)
    end

    test "handles case when right of the applying range with nil priority overlaps with the nil priority existing range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 130, to_number: 46, priority: nil})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 29, to_number: 20, priority: nil})

      block_numbers = 23..130 |> Enum.to_list()
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 3

      assert Enum.any?(ranges, fn range ->
               range.from_number == 130 and range.to_number == 46 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 45 and range.to_number == 30 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 29 and range.to_number == 20 and range.priority == nil
             end)
    end

    test "handles case when right of the applying range with nil priority overlaps with the priority = 1 existing range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 130, to_number: 46, priority: nil})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 29, to_number: 20, priority: 1})

      block_numbers = 23..130 |> Enum.to_list()
      priority = nil

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 3

      assert Enum.any?(ranges, fn range ->
               range.from_number == 130 and range.to_number == 46 and range.priority == nil
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 45 and range.to_number == 30 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 29 and range.to_number == 20 and range.priority == 1
             end)
    end

    test "handles case when right of the applying range with priority = 1 overlaps with the nil priority existing range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 130, to_number: 46, priority: nil})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 29, to_number: 20, priority: nil})

      block_numbers = 23..130 |> Enum.to_list()
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 2

      assert Enum.any?(ranges, fn range ->
               range.from_number == 130 and range.to_number == 23 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 22 and range.to_number == 20 and range.priority == nil
             end)
    end

    test "handles case when right of the applying range with priority = 1 overlaps with the priority = 1 existing range in the DB" do
      Repo.insert!(%MissingBlockRange{from_number: 130, to_number: 46, priority: nil})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 29, to_number: 20, priority: 1})

      block_numbers = 23..130 |> Enum.to_list()
      priority = 1

      MissingBlockRange.add_ranges_by_block_numbers(block_numbers, priority)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 1

      assert Enum.any?(ranges, fn range ->
               range.from_number == 130 and range.to_number == 20 and range.priority == 1
             end)
    end
  end

  describe "clear_batch/1" do
    setup do
      # Ensure the database is clean before each test
      Repo.delete_all(MissingBlockRange)

      on_exit(fn ->
        # Clean up the database after each test
        Repo.delete_all(MissingBlockRange)
      end)

      :ok
    end

    test "correctly clears the batch" do
      Repo.insert!(%MissingBlockRange{from_number: 112, to_number: 86, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 45, to_number: 30, priority: 1})
      Repo.insert!(%MissingBlockRange{from_number: 25, to_number: 20, priority: nil})

      batch = [95..80//-1, 60..58//-1, 42..35//-1, 30..19//-1]

      MissingBlockRange.clear_batch(batch)

      ranges = Repo.all(MissingBlockRange)

      assert length(ranges) == 3

      assert Enum.any?(ranges, fn range ->
               range.from_number == 112 and range.to_number == 96 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 45 and range.to_number == 43 and range.priority == 1
             end)

      assert Enum.any?(ranges, fn range ->
               range.from_number == 34 and range.to_number == 31 and range.priority == 1
             end)
    end
  end

  describe "clear_batch_if_indexed/1" do
    setup do
      # blocks are inserted here, so unlike the rest of the module these tests
      # are run in a sandbox transaction instead of committing to the database
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      Repo.delete_all(MissingBlockRange)

      :ok
    end

    test "clears only the numbers of consensus blocks not marked with refetch_needed" do
      Repo.insert!(%MissingBlockRange{from_number: 10, to_number: 1, priority: nil})

      insert(:block, number: 3)
      insert(:block, number: 4)
      insert(:block, number: 5)
      insert(:block, number: 6, refetch_needed: true)
      insert(:block, number: 7, consensus: false)

      MissingBlockRange.clear_batch_if_indexed([8..3//-1])

      assert [%{from_number: 10, to_number: 6}, %{from_number: 2, to_number: 1}] = sorted_ranges()
    end

    test "keeps the not indexed numbers between the indexed ones" do
      Repo.insert!(%MissingBlockRange{from_number: 10, to_number: 1, priority: nil})

      insert(:block, number: 2)
      insert(:block, number: 3)
      insert(:block, number: 6)
      insert(:block, number: 7)

      MissingBlockRange.clear_batch_if_indexed([1..10])

      assert [%{from_number: 10, to_number: 8}, %{from_number: 5, to_number: 4}, %{from_number: 1, to_number: 1}] =
               sorted_ranges()
    end

    test "clears the numbers at the lower bound of the block ranges" do
      Repo.insert!(%MissingBlockRange{from_number: 3, to_number: 0, priority: nil})

      Enum.each(0..3, &insert(:block, number: &1))

      MissingBlockRange.clear_batch_if_indexed([0..3])

      assert [] = sorted_ranges()
    end

    test "keeps the priority of the not indexed numbers" do
      Repo.insert!(%MissingBlockRange{from_number: 5, to_number: 1, priority: 1})

      insert(:block, number: 2)
      insert(:block, number: 3)

      MissingBlockRange.clear_batch_if_indexed([1..5])

      assert [%{from_number: 5, to_number: 4, priority: 1}, %{from_number: 1, to_number: 1, priority: 1}] =
               sorted_ranges()
    end

    test "keeps a number invalidated after its block has been imported" do
      insert(:block, number: 42)

      # e.g. the failure handler of a concurrent import of the same height
      Block.set_refetch_needed([42])

      MissingBlockRange.clear_batch_if_indexed([42..42])

      assert [%{from_number: 42, to_number: 42}] = sorted_ranges()
    end
  end

  defp sorted_ranges do
    MissingBlockRange
    |> Repo.all()
    |> Enum.sort_by(& &1.from_number, :desc)
  end
end
