defmodule Explorer.BufferedTaskTest do
  use ExUnit.Case, async: true

  alias Explorer.BufferedTask

  @max_batch_size 2

  defp start_buffer(callback_module) do
    start_supervised(
      {BufferedTask, {callback_module, flush_interval: 50, max_batch_size: @max_batch_size, max_concurrency: 2}}
    )
  end

  defmodule CounterTask do
    @behaviour BufferedTask

    def initial_collection, do: for(i <- 1..11, do: "#{i}")

    def init(acc, reducer) do
      {:ok, Enum.reduce(initial_collection(), acc, fn item, acc -> reducer.(item, acc) end)}
    end

    def run(batch) do
      send(__MODULE__, {:run, batch})
      :ok
    end
  end

  defmodule FunTask do
    @behaviour BufferedTask

    def init(acc, _reducer) do
      {:ok, acc}
    end

    def run([agent, func]) when is_function(func) do
      count = Agent.get_and_update(agent, &{&1, &1 + 1})
      send(__MODULE__, {:run, count})
      func.(count)
    end

    def run(batch) do
      send(__MODULE__, {:run, batch})
      :ok
    end
  end

  test "init allows buffer to be loaded up with initial entries" do
    Process.register(self(), CounterTask)
    {:ok, buffer} = start_buffer(CounterTask)

    CounterTask.initial_collection()
    |> Enum.chunk_every(@max_batch_size)
    |> Enum.each(fn batch ->
      assert_receive {:run, ^batch}
    end)

    refute_receive _

    BufferedTask.buffer(buffer, ~w(12 13 14 15 16))
    assert_receive {:run, ~w(12 13)}
    assert_receive {:run, ~w(14 15)}
    assert_receive {:run, ~w(16)}
    refute_receive _
  end

  test "init with zero entries schedules future buffer flushes" do
    Process.register(self(), FunTask)
    {:ok, buffer} = start_buffer(FunTask)
    refute_receive _

    BufferedTask.buffer(buffer, ~w(some more entries))

    assert_receive {:run, ~w(some more)}
    assert_receive {:run, ~w(entries)}
    refute_receive _
  end

  test "run/1 allows tasks to be programmatically retried" do
    Process.register(self(), FunTask)
    {:ok, buffer} = start_buffer(FunTask)
    {:ok, count} = Agent.start_link(fn -> 1 end)

    BufferedTask.buffer(buffer, [
      count,
      fn
        1 -> {:retry, :because_reasons}
        2 -> {:retry, :because_reasons}
        3 -> :ok
      end
    ])

    assert_receive {:run, 1}
    assert_receive {:run, 2}
    assert_receive {:run, 3}
    refute_receive _
  end
end
