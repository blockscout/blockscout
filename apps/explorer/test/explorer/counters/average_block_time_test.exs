defmodule Explorer.Counters.AverageBlockTimeTest do
  use Explorer.DataCase

  doctest Explorer.Counters.AverageBlockTimeDurationFormat

  alias Explorer.Chain.Block
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Repo

  setup do
    start_supervised!(AverageBlockTime)
    Application.put_env(:explorer, AverageBlockTime, enabled: true)

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

      insert(:block, number: block_number, consensus: true, timestamp: Timex.shift(first_timestamp, seconds: 3))
      insert(:block, number: block_number, consensus: false, timestamp: Timex.shift(first_timestamp, seconds: 9))
      insert(:block, number: block_number, consensus: false, timestamp: Timex.shift(first_timestamp, seconds: 6))

      assert Repo.aggregate(Block, :count, :hash) == 3

      AverageBlockTime.refresh()

      assert AverageBlockTime.average_block_time() == Timex.Duration.parse!("PT3S")
    end
  end
end
