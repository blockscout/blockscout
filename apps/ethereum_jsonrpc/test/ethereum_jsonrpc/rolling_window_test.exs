defmodule EthereumJSONRPC.RollingWindowTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.RollingWindow

  test "start_link/2" do
    assert {:ok, _} = RollingWindow.start_link(table: :test_table, duration: 5, window_count: 1)
  end

  describe "init/1" do
    test "raises when duration isn't evenly divisible by window_count" do
      assert_raise ArgumentError, ~r"evenly divisible", fn ->
        RollingWindow.init(table: :init_test_table, duration: :timer.seconds(2), window_count: 3)
      end
    end

    test "schedules a sweep" do
      assert {:ok, _} = RollingWindow.init(table: :test_table, duration: 5, window_count: 1)
      assert_receive :sweep, 10
    end
  end

  test "when no increments have happened, inspect returns an empty list" do
    table = :no_increments_have_happened
    start_rolling_window(table)

    assert RollingWindow.inspect(table, :foobar) == []
  end

  test "when no increments have happened, count returns 0" do
    table = :no_increments_have_happened_empty_list
    start_rolling_window(table)

    assert RollingWindow.count(table, :foobar) == 0
  end

  test "when an increment has happened, inspect returns the count for that window" do
    table = :no_increments_have_happened_count
    start_rolling_window(table)

    RollingWindow.inc(table, :foobar)

    assert RollingWindow.inspect(table, :foobar) == [1]
  end

  test "when an increment has happened, count returns the count for that window" do
    table = :no_increments_have_happened_count1
    start_rolling_window(table)

    RollingWindow.inc(table, :foobar)

    assert RollingWindow.count(table, :foobar) == 1
  end

  test "when an increment has happened in multiple windows, inspect returns the count for both windows" do
    table = :no_increments_have_happened_multiple_windows
    start_rolling_window(table)

    RollingWindow.inc(table, :foobar)
    sweep(table)
    RollingWindow.inc(table, :foobar)

    assert RollingWindow.inspect(table, :foobar) == [1, 1]
  end

  test "when an increment has happened in multiple windows, count returns the sum of both windows" do
    table = :no_increments_have_happened_multiple_windows1
    start_rolling_window(table)

    RollingWindow.inc(table, :foobar)
    sweep(table)
    RollingWindow.inc(table, :foobar)

    assert RollingWindow.count(table, :foobar) == 2
  end

  test "when an increment has happened, but has been swept <window_count> times, it no longer appears in inspect" do
    table = :no_increments_have_happened_multiple_windows3
    start_rolling_window(table)

    RollingWindow.inc(table, :foobar)
    sweep(table)
    sweep(table)
    RollingWindow.inc(table, :foobar)
    sweep(table)
    RollingWindow.inc(table, :foobar)

    assert RollingWindow.inspect(table, :foobar) == [1, 1, 0]
  end

  test "when an increment has happened, but has been swept <window_count> times, it no longer is included in count" do
    table = :no_increments_have_happened_multiple_windows4
    start_rolling_window(table)

    RollingWindow.inc(table, :foobar)
    sweep(table)
    sweep(table)
    RollingWindow.inc(table, :foobar)
    sweep(table)
    RollingWindow.inc(table, :foobar)

    assert RollingWindow.count(table, :foobar) == 2
  end

  test "sweeping schedules another sweep" do
    {:ok, state} = RollingWindow.init(table: :anything, duration: 1, window_count: 1)
    RollingWindow.handle_info(:sweep, state)
    assert_receive(:sweep)
  end

  defp start_rolling_window(table_name) do
    {:ok, _pid} =
      RollingWindow.start_link([table: table_name, duration: :timer.minutes(120), window_count: 3], name: table_name)
  end

  defp sweep(name) do
    GenServer.call(name, :sweep)
  end
end
