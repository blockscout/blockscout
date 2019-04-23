defmodule Explorer.Counters.AverageBlockTimeTest do
  use Explorer.DataCase

  doctest Explorer.Counters.AverageBlockTimeDurationFormat

  alias Explorer.Counters.AverageBlockTime

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
  end
end
