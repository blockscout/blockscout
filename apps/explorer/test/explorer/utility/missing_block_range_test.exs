defmodule Explorer.Utility.MissingBlockRangeTest do
  use ExUnit.Case, async: true

  alias Explorer.Utility.MissingBlockRange
  alias Explorer.Repo

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
end
