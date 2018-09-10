defmodule Indexer.Wobserver.BufferedTaskTest do
  use ExUnit.Case, async: false

  alias Indexer.Wobserver.BufferedTask

  setup do
    table = :ets.new(Indexer.Wobserver.Metrics, [:set, :public, {:read_concurrency, true}])

    %{table: table}
  end

  describe "increment_current_buffer_length/3" do
    test "uses default of 0 when there is no key", %{table: table} do
      assert BufferedTask.increment_current_buffer_length(table, :unknown, 1) == 1
    end
  end
end
