defmodule Explorer.Chain.Cache.Counters.AverageBlockTimeTest do
  use Explorer.DataCase

  doctest Explorer.Chain.Cache.Counters.Helper.AverageBlockTimeDurationFormat

  alias Explorer.Chain.Block
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Explorer.Repo

  setup do
    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true, cache_period: 1_800_000)

    Application.put_env(:explorer, :include_uncles_in_average_block_time, true)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)
    end)
  end

  describe "average_block_time/1" do
    test "when disabled, it returns an error" do
      Application.put_env(:explorer, AverageBlockTime, enabled: false, cache_period: 1_800_000)

      assert AverageBlockTime.average_block_time() == {:error, :disabled}
    end

    test "without blocks duration is 0" do
      assert AverageBlockTime.average_block_time() == Timex.Duration.parse!("PT0S")
    end

    test "considers both uncles and consensus blocks" do
      block_number = 99_999_999

      first_timestamp = Timex.now()

      insert(:block, number: block_number, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: -100 - 6))

      insert(:block,
        number: block_number,
        consensus: false,
        timestamp: Timex.shift(first_timestamp, seconds: -100 - 12)
      )

      insert(:block, number: block_number, consensus: false, timestamp: Timex.shift(first_timestamp, seconds: -100 - 9))

      insert(:block,
        number: block_number + 1,
        consensus: true,
        timestamp: Timex.shift(first_timestamp, seconds: -100 - 3)
      )

      Enum.each(1..100, fn i ->
        insert(:block,
          number: block_number + 1 + i,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -(101 - i) - 12)
        )
      end)

      assert Repo.aggregate(Block, :count, :hash) == 104

      AverageBlockTime.refresh()

      assert AverageBlockTime.average_block_time() == Timex.Duration.parse!("PT3S")
    end

    test "excludes uncles if include_uncles_in_average_block_time is set to false" do
      block_number = 99_999_999
      Application.put_env(:explorer, :include_uncles_in_average_block_time, false)

      first_timestamp = Timex.now()

      insert(:block, number: block_number, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 3))
      insert(:block, number: block_number, consensus: false, timestamp: Timex.shift(first_timestamp, seconds: 4))
      insert(:block, number: block_number + 1, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 5))

      Enum.each(1..100, fn i ->
        insert(:block,
          number: block_number + i + 1,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -(101 - i) - 5)
        )
      end)

      AverageBlockTime.refresh()

      assert AverageBlockTime.average_block_time() == Timex.Duration.parse!("PT2S")
    end

    test "excludes uncles if include_uncles_in_average_block_time is set to true" do
      block_number = 99_999_999

      first_timestamp = Timex.now()

      insert(:block, number: block_number, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 3))
      insert(:block, number: block_number, consensus: false, timestamp: Timex.shift(first_timestamp, seconds: 4))
      insert(:block, number: block_number + 1, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 5))

      Enum.each(1..100, fn i ->
        insert(:block,
          number: block_number + i + 1,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -(101 - i) - 5)
        )
      end)

      AverageBlockTime.refresh()

      assert AverageBlockTime.average_block_time() == Timex.Duration.parse!("PT1S")
    end

    test "when there are no uncles sorts by block number" do
      block_number = 99_999_999

      first_timestamp = Timex.now()

      insert(:block, number: block_number, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 3))
      insert(:block, number: block_number + 2, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 9))
      insert(:block, number: block_number + 1, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 6))

      Enum.each(1..100, fn i ->
        insert(:block,
          number: block_number + i + 2,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -(101 - i) - 9)
        )
      end)

      assert Repo.aggregate(Block, :count, :hash) == 103

      AverageBlockTime.refresh()

      assert AverageBlockTime.average_block_time() == Timex.Duration.parse!("PT3S")
    end

    test "timestamps are compared correctly" do
      block_number = 99_999_999

      first_timestamp = ~U[2023-08-23 19:04:59.000000Z]
      pseudo_after_timestamp = ~U[2022-08-23 19:05:59.000000Z]

      insert(:block, number: block_number, consensus: true, timestamp: pseudo_after_timestamp)
      insert(:block, number: block_number + 1, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 3))
      insert(:block, number: block_number + 2, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 6))

      Enum.each(1..100, fn i ->
        insert(:block,
          number: block_number + i + 2,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -(101 - i) - 9)
        )
      end)

      AverageBlockTime.refresh()

      %{timestamps: timestamps} = :sys.get_state(AverageBlockTime)

      assert Enum.sort_by(timestamps, fn {_bn, ts} -> ts end, &>=/2) == timestamps
    end

    test "average time are calculated correctly for blocks that are not in chronological order" do
      block_number = 99_999_999

      first_timestamp = Timex.now()

      insert(:block, number: block_number, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 3))
      insert(:block, number: block_number + 1, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 6))
      insert(:block, number: block_number + 2, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 9))
      insert(:block, number: block_number + 3, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: -69))
      insert(:block, number: block_number + 4, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: -66))
      insert(:block, number: block_number + 5, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: -63))

      Enum.each(1..100, fn i ->
        insert(:block,
          number: block_number + i + 5,
          consensus: true,
          timestamp: Timex.shift(first_timestamp, seconds: -(101 - i) - 9)
        )
      end)

      AverageBlockTime.refresh()

      assert Timex.Duration.to_milliseconds(AverageBlockTime.average_block_time()) == 3000
    end
  end
end
