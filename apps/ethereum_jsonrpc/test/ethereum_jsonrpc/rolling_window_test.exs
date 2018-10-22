defmodule EthereumJSONRPC.RollingWindowTest do
  use ExUnit.Case, async: true
  use EthereumJSONRPC.Case

  alias EthereumJSONRPC.RollingWindow

  @table :table

  setup do
    # We set `window_length` to a large time frame so that we can sweep manually to simulate
    # time passing
    RollingWindow.start_link([table: @table, window_length: :timer.minutes(120), window_count: 3], name: RollingWindow)

    :ok
  end

  defp sweep do
    GenServer.call(RollingWindow, :sweep)
  end

  test "when no increments have happened, inspect returns an empty list" do
    assert RollingWindow.inspect(@table, :foobar) == []
  end

  test "when no increments hafve happened, count returns 0" do
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

  test "when an increment has happened in multiple windows, with an empty window in between, inspect shows that empty window" do
    RollingWindow.inc(@table, :foobar)
    sweep()
    sweep()
    RollingWindow.inc(@table, :foobar)

    assert RollingWindow.inspect(@table, :foobar) == [1, 0, 1]
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
    {:ok, state} = RollingWindow.init(table: :anything, window_length: 1, window_count: 1)
    RollingWindow.handle_info(:sweep, state)
    assert_receive(:sweep)
  end
end
