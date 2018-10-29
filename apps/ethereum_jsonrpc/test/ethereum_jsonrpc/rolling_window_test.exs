defmodule EthereumJSONRPC.RollingWindowTest do
  use ExUnit.Case, async: true

  alias EthereumJSONRPC.RollingWindow

  @table :table

  setup do
    # We set `window_length` to a large time frame so that we can sweep manually to simulate
    # time passing
    RollingWindow.start_link([table: @table, duration: :timer.minutes(120), window_count: 3], name: RollingWindow)

    :ok
  end

  defp sweep do
    GenServer.call(RollingWindow, :sweep)
  end

  test "start_link/2" do
    assert {:ok, _} = RollingWindow.start_link(table: :test_table, duration: 5, window_count: 1)
  end

  describe "init/1" do
    test "raises when duration isn't evenly divisble by window_count" do
      assert_raise ArgumentError, ~r"evenly divisible", fn ->
        RollingWindow.init(table: @table, duration: :timer.seconds(2), window_count: 3)
      end
    end

    test "schedules a sweep" do
      assert {:ok, _} = RollingWindow.init(table: :test_table, duration: 5, window_count: 1)
      assert_receive :sweep, 10
    end
  end

  test "when no increments have happened, inspect returns an empty list" do
    assert RollingWindow.inspect(@table, :foobar) == []
  end

  test "when no increments have happened, count returns 0" do
    assert RollingWindow.count(@table, :foobar) == 0
  end

  test "when an increment has happened, inspect returns the count for that window" do
    RollingWindow.inc(@table, :foobar)

    assert RollingWindow.inspect(@table, :foobar) == [1]
  end

  test "when an increment has happened, count returns the count for that window" do
    RollingWindow.inc(@table, :foobar)

    assert RollingWindow.count(@table, :foobar) == 1
  end

  test "when an increment has happened in multiple windows, inspect returns the count for both windows" do
    RollingWindow.inc(@table, :foobar)
    sweep()
    RollingWindow.inc(@table, :foobar)

    assert RollingWindow.inspect(@table, :foobar) == [1, 1]
  end

  test "when an increment has happened in multiple windows, count returns the sum of both windows" do
    RollingWindow.inc(@table, :foobar)
    sweep()
    RollingWindow.inc(@table, :foobar)

    assert RollingWindow.count(@table, :foobar) == 2
  end

  test "when an increment has happened in multiple windows, with an empty window in between, count still sums all windows" do
    RollingWindow.inc(@table, :foobar)
    sweep()
    sweep()
    RollingWindow.inc(@table, :foobar)

    assert RollingWindow.count(@table, :foobar) == 2
  end

  test "when an increment has happened, but has been swept <window_count> times, it no longer appears in inspect" do
    RollingWindow.inc(@table, :foobar)
    sweep()
    sweep()
    RollingWindow.inc(@table, :foobar)
    sweep()
    RollingWindow.inc(@table, :foobar)

    assert RollingWindow.inspect(@table, :foobar) == [1, 1, 0]
  end

  test "when an increment has happened, but has been swept <window_count> times, it no longer is included in count" do
    RollingWindow.inc(@table, :foobar)
    sweep()
    sweep()
    RollingWindow.inc(@table, :foobar)
    sweep()
    RollingWindow.inc(@table, :foobar)

    assert RollingWindow.count(@table, :foobar) == 2
  end

  test "sweeping schedules another sweep" do
    {:ok, state} = RollingWindow.init(table: :anything, duration: 1, window_count: 1)
    RollingWindow.handle_info(:sweep, state)
    assert_receive(:sweep)
  end
end
