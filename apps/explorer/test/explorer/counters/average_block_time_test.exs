defmodule Explorer.Counters.AverageBlockTimeTest do
  use Explorer.DataCase

  doctest Explorer.Counters.AverageBlockTimeDurationFormat

  alias Explorer.Counters.AverageBlockTime

  defp block(number, last, duration), do: %{number: number, timestamp: Timex.shift(last, seconds: duration)}

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

    test "with only one block, the duration is 0" do
      now = Timex.now()
      block = block(0, now, 0)

      assert AverageBlockTime.average_block_time(block) == Timex.Duration.parse!("PT0S")
    end

    test "once there are two blocks, the duration is the average distance between them all" do
      now = Timex.now()

      block0 = block(0, now, 0)
      block1 = block(1, now, 2)
      block2 = block(2, now, 6)

      AverageBlockTime.average_block_time(block0)
      assert AverageBlockTime.average_block_time(block1) == Timex.Duration.parse!("PT2S")
      assert AverageBlockTime.average_block_time(block2) == Timex.Duration.parse!("PT3S")
    end

    test "only the last 100 blocks are considered" do
      now = Timex.now()

      block0 = block(0, now, 0)
      block1 = block(1, now, 2000)

      AverageBlockTime.average_block_time(block0)
      AverageBlockTime.average_block_time(block1)

      for i <- 1..100 do
        block = block(i + 1, now, 2000 + i)
        AverageBlockTime.average_block_time(block)
      end

      assert AverageBlockTime.average_block_time() == Timex.Duration.parse!("PT1S")
    end
  end
end
