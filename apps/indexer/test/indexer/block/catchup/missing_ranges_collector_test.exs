defmodule Indexer.Block.Catchup.MissingRangesCollectorTest do
  use Explorer.DataCase, async: false

  alias Explorer.Utility.MissingBlockRange
  alias Indexer.Block.Catchup.MissingRangesCollector

  describe "default_init" do
    setup do
      initial_env = Application.get_all_env(:indexer)
      on_exit(fn -> Application.put_all_env([{:indexer, initial_env}]) end)
    end

    test "empty envs" do
      insert(:block, number: 1_000_000)
      insert(:block, number: 500_123)
      MissingRangesCollector.start_link([])
      Process.sleep(500)

      assert [999_999..900_000//-1] = batch = MissingBlockRange.get_latest_batch(1)
      MissingBlockRange.clear_batch(batch)
      assert [899_999..800_000//-1] = batch = MissingBlockRange.get_latest_batch(1)
      MissingBlockRange.clear_batch(batch)
      assert [799_999..700_000//-1] = batch = MissingBlockRange.get_latest_batch(1)
      MissingBlockRange.clear_batch(batch)

      insert(:block, number: 1_200_000)
      Process.sleep(500)

      assert [1_199_999..1_100_001//-1] = batch = MissingBlockRange.get_latest_batch(1)
      MissingBlockRange.clear_batch(batch)
      assert [1_100_000..1_000_001//-1] = batch = MissingBlockRange.get_latest_batch(1)
      MissingBlockRange.clear_batch(batch)
      assert [699_999..600_000//-1] = batch = MissingBlockRange.get_latest_batch(1)
      MissingBlockRange.clear_batch(batch)
      assert [599_999..500_124//-1, 500_122..500_000//-1] = MissingBlockRange.get_latest_batch(2)
    end

    test "FIRST_BLOCK and LAST_BLOCK envs" do
      Application.put_env(:indexer, :first_block, "100")
      Application.put_env(:indexer, :last_block, "200")

      insert(:missing_block_range, from_number: 250, to_number: 220)
      insert(:missing_block_range, from_number: 220, to_number: 190)
      insert(:missing_block_range, from_number: 120, to_number: 90)
      insert(:missing_block_range, from_number: 90, to_number: 80)

      MissingRangesCollector.start_link([])
      Process.sleep(500)

      assert [%{from_number: 120, to_number: 100}, %{from_number: 200, to_number: 190}] = Repo.all(MissingBlockRange)
    end
  end

  describe "ranges_init" do
    setup do
      initial_env = Application.get_all_env(:indexer)
      on_exit(fn -> Application.put_all_env([{:indexer, initial_env}]) end)
    end

    test "infinite range" do
      Application.put_env(:indexer, :block_ranges, "1..5,3..5,2qw1..12,10..11a,,asd..qwe,10..latest")

      insert(:block, number: 200_000)

      MissingRangesCollector.start_link([])
      Process.sleep(500)

      assert [199_999..100_010//-1] = batch = MissingBlockRange.get_latest_batch(1)
      MissingBlockRange.clear_batch(batch)
      assert [100_009..10//-1] = batch = MissingBlockRange.get_latest_batch(1)
      MissingBlockRange.clear_batch(batch)
      assert [5..1//-1] = MissingBlockRange.get_latest_batch(1)
    end

    test "finite range" do
      Application.put_env(:indexer, :block_ranges, "10..20,5..15,18..25,35..40,30..50,150..200")

      insert(:block, number: 200_000)

      MissingRangesCollector.start_link([])
      Process.sleep(500)

      assert [200..150//-1, 50..30//-1, 25..5//-1] = batch = MissingBlockRange.get_latest_batch(3)
      MissingBlockRange.clear_batch(batch)
      assert [] = MissingBlockRange.get_latest_batch()
    end

    test "finite range with existing blocks" do
      Application.put_env(:indexer, :block_ranges, "10..20,5..15,18..25,35..40,30..50,150..200")

      insert(:block, number: 200_000)
      insert(:block, number: 175)
      insert(:block, number: 33)

      MissingRangesCollector.start_link([])
      Process.sleep(500)

      assert [200..176//-1, 174..150//-1, 50..34//-1, 32..30//-1, 25..5//-1] =
               batch = MissingBlockRange.get_latest_batch(5)

      MissingBlockRange.clear_batch(batch)
      assert [] = MissingBlockRange.get_latest_batch()
    end
  end

  test "parse_block_ranges/1" do
    assert MissingRangesCollector.parse_block_ranges("1..5,3..5,2qw1..12,10..11a,,asd..qwe,10..latest") ==
             {:infinite_ranges, [1..5], 9}

    assert MissingRangesCollector.parse_block_ranges("latest..123,,fvdskvjglav!@#$%^&,2..1") == :no_ranges

    assert MissingRangesCollector.parse_block_ranges("10..20,5..15,18..25,35..40,30..50,100..latest,150..200") ==
             {:infinite_ranges, [5..25, 30..50], 99}

    assert MissingRangesCollector.parse_block_ranges("10..20,5..15,18..25,35..40,30..50,150..200") ==
             {:finite_ranges, [5..25, 30..50, 150..200]}
  end
end
