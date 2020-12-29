defmodule Explorer.Counters.AverageBlockTimeTest do
  use Explorer.DataCase

  doctest Explorer.Counters.AverageBlockTimeDurationFormat

  alias Explorer.Chain.Block
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Repo

  setup do
    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true)

    Application.put_env(:explorer, :include_uncles_in_average_block_time, true)

    on_exit(fn ->
      Application.put_env(:explorer, AverageBlockTime, enabled: false)
    end)
  end

  describe "average_block_time/1" do
    test "when disabled, it returns an error" do
      Application.put_env(:explorer, AverageBlockTime, enabled: false)

      assert AverageBlockTime.average_block_time() == {:error, :disabled}
    end

    test "without blocks duration is 0" do
      assert AverageBlockTime.average_block_time() == Timex.Duration.parse!("PT0S")
    end

    test "considers both uncles and consensus blocks" do
      block_number = 99_999_999

      first_timestamp = Timex.now()

      insert(:block, number: block_number, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: -100 - 6))

      insert(:block, number: block_number, consensus: false, timestamp: Timex.shift(first_timestamp, seconds: -100 - 12))

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
  end
end
