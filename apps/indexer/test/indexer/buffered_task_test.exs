defmodule Indexer.BufferedTaskTest do
  use ExUnit.Case

  import Mox

  alias Indexer.{BoundQueue, BufferedTask}
  alias Indexer.BufferedTaskTest.{RetryableTask, ShrinkableTask}

  @max_batch_size 2
  @flush_interval 50
  @assert_receive_timeout 200

  @moduletag :capture_log

  # must be global as can't guarantee that `init` can be mocked before `BufferedTask` `start_link` returns
  setup :set_mox_global

  setup :verify_on_exit!

  defp start_buffer(callback_module, max_batch_size \\ @max_batch_size) do
    start_supervised!({Task.Supervisor, name: BufferedTaskSup})

    start_supervised(
      {BufferedTask,
       [
         {callback_module,
          state: nil,
          task_supervisor: BufferedTaskSup,
          flush_interval: @flush_interval,
          max_batch_size: max_batch_size,
          max_concurrency: 2,
          poll: false}
       ]}
    )
  end

  defmodule CounterTask do
    @behaviour BufferedTask

    def initial_collection, do: for(i <- 1..11, do: "#{i}")

    def init(initial, reducer, _state) do
      Enum.reduce(initial_collection(), initial, fn item, acc -> reducer.(item, acc) end)
    end

    def run(batch, _state) do
      send(__MODULE__, {:run, batch})
      :ok
    end
  end

  defmodule EmptyTask do
    @behaviour BufferedTask

    def init(initial, _reducer, _state) do
      initial
    end

    def run(batch, _state) do
      send(__MODULE__, {:run, batch})
      :ok
    end
  end

  test "init buffers initial entries then executes on-demand entries" do
    Process.register(self(), CounterTask)
    {:ok, buffer} = start_buffer(CounterTask)

    CounterTask.initial_collection()
    |> Enum.chunk_every(@max_batch_size)
    |> Enum.each(fn batch ->
      assert_receive {:run, ^batch}
    end)

    refute_receive _

    BufferedTask.buffer(buffer, ~w(12 13 14 15 16))
    assert_receive {:run, ~w(12 13)}, @assert_receive_timeout
    assert_receive {:run, ~w(14 15)}, @assert_receive_timeout
    assert_receive {:run, ~w(16)}, @assert_receive_timeout
    refute_receive _

    BufferedTask.buffer(buffer, ~w(17))
    assert_receive {:run, ~w(17)}, @assert_receive_timeout
    refute_receive _
  end

  test "init with zero entries schedules future buffer flushes" do
    Process.register(self(), EmptyTask)
    {:ok, buffer} = start_buffer(EmptyTask)
    refute_receive _

    BufferedTask.buffer(buffer, ~w(some more entries))

    assert_receive {:run, ~w(some more)}, @assert_receive_timeout
    assert_receive {:run, ~w(entries)}, @assert_receive_timeout
    refute_receive _
  end

  @tag :capture_log
  test "crashed runs are retried" do
    RetryableTask
    |> expect(:init, fn initial, _, _ -> initial end)
    |> expect(:run, fn [:boom] = batch, _state ->
      send(RetryableTask, {:run, {0, batch}})
      raise "boom"
    end)
    |> expect(:run, fn [:boom] = batch, _state ->
      send(RetryableTask, {:run, {1, batch}})
      :ok
    end)

    Process.register(self(), RetryableTask)
    {:ok, buffer} = start_buffer(RetryableTask)

    BufferedTask.buffer(buffer, [:boom])
    assert_receive {:run, {0, [:boom]}}, @assert_receive_timeout
    assert_receive {:run, {1, [:boom]}}, @assert_receive_timeout
    refute_receive _
  end

  test "run/1 allows tasks to be programmatically retried" do
    RetryableTask
    |> expect(:init, fn initial, _, _ -> initial end)
    |> expect(:run, fn [1, 2] = batch, _state ->
      send(RetryableTask, {:run, {0, batch}})
      :retry
    end)
    |> expect(:run, fn [3] = batch, _state ->
      send(RetryableTask, {:run, {0, batch}})
      :retry
    end)
    |> expect(:run, fn [1, 2] = batch, _state ->
      send(RetryableTask, {:run, {1, batch}})
      :retry
    end)
    |> expect(:run, fn [3] = batch, _state ->
      send(RetryableTask, {:run, {1, batch}})
      :retry
    end)
    |> expect(:run, fn [1, 2] = batch, _state ->
      send(RetryableTask, {:final_run, {2, batch}})
      :ok
    end)
    |> expect(:run, fn [3] = batch, _state ->
      send(RetryableTask, {:final_run, {2, batch}})
      :ok
    end)

    Process.register(self(), RetryableTask)
    {:ok, buffer} = start_buffer(RetryableTask)

    BufferedTask.buffer(buffer, [1, 2, 3])
    assert_receive {:run, {0, [1, 2]}}, @assert_receive_timeout
    assert_receive {:run, {0, [3]}}, @assert_receive_timeout
    assert_receive {:run, {1, [1, 2]}}, @assert_receive_timeout
    assert_receive {:run, {1, [3]}}, @assert_receive_timeout
    assert_receive {:final_run, {2, [1, 2]}}, @assert_receive_timeout
    assert_receive {:final_run, {2, [3]}}, @assert_receive_timeout
    refute_receive _
  end

  test "debug_count/1 returns count of buffered entries" do
    RetryableTask
    |> expect(:init, fn initial, _, _ -> initial end)
    |> stub(:run, fn [{:sleep, time}], _state ->
      :timer.sleep(time)
      :ok
    end)

    {:ok, buffer} = start_buffer(RetryableTask, 1)

    assert %{buffer: 0, tasks: 0} = BufferedTask.debug_count(buffer)

    BufferedTask.buffer(buffer, [{:sleep, 1_000}])
    BufferedTask.buffer(buffer, [{:sleep, 1_000}])
    BufferedTask.buffer(buffer, [{:sleep, 1_000}])
    Process.sleep(200)

    assert %{buffer: buffer, tasks: tasks} = BufferedTask.debug_count(buffer)
    assert buffer + tasks == 3
  end

  describe "handle_info(:flush, state)" do
    test "without 0 size without maximum size schedules next flush" do
      {:ok, bound_queue} = BoundQueue.push_back(%BoundQueue{}, 1)
      start_supervised!({Task.Supervisor, name: BufferedTaskSup})

      refute BoundQueue.shrunk?(bound_queue)

      assert {:noreply, %BufferedTask{flush_timer: flush_timer}} =
               BufferedTask.handle_info(:flush, %BufferedTask{
                 callback_module: ShrinkableTask,
                 callback_module_state: nil,
                 bound_queue: bound_queue,
                 flush_interval: 50,
                 flush_timer: nil,
                 task_supervisor: BufferedTaskSup,
                 max_batch_size: 1,
                 max_concurrency: 1
               })

      refute flush_timer == nil
    end

    test "without 0 size with maximum size schedules next flush" do
      {:ok, bound_queue} = BoundQueue.push_back(%BoundQueue{}, 1)
      {:ok, bound_queue} = BoundQueue.push_back(bound_queue, 2)
      {:ok, bound_queue} = BoundQueue.shrink(bound_queue)

      assert BoundQueue.shrunk?(bound_queue)

      start_supervised!({Task.Supervisor, name: BufferedTaskSup})

      assert {:noreply, %BufferedTask{flush_timer: flush_timer}} =
               BufferedTask.handle_info(:flush, %BufferedTask{
                 callback_module: ShrinkableTask,
                 callback_module_state: nil,
                 bound_queue: bound_queue,
                 flush_interval: 50,
                 flush_timer: nil,
                 task_supervisor: BufferedTaskSup,
                 max_batch_size: 1,
                 max_concurrency: 1
               })

      refute flush_timer == nil
    end

    test "with 0 size without maximum size schedules next flush" do
      bound_queue = %BoundQueue{}

      refute BoundQueue.shrunk?(bound_queue)

      start_supervised!({Task.Supervisor, name: BufferedTaskSup})

      assert {:noreply, %BufferedTask{flush_timer: flush_timer}} =
               BufferedTask.handle_info(:flush, %BufferedTask{
                 callback_module: ShrinkableTask,
                 callback_module_state: nil,
                 bound_queue: bound_queue,
                 flush_interval: 50,
                 flush_timer: nil,
                 task_supervisor: BufferedTaskSup,
                 max_batch_size: 1,
                 max_concurrency: 1
               })

      refute flush_timer == nil
    end

    test "with 0 size with maximum size calls init/2 to get work that was shed before scheduling next flush" do
      {:ok, bound_queue} = BoundQueue.push_back(%BoundQueue{}, 1)
      {:ok, bound_queue} = BoundQueue.push_back(bound_queue, 2)
      {:ok, bound_queue} = BoundQueue.shrink(bound_queue)

      assert {:ok, {1, bound_queue}} = BoundQueue.pop_front(bound_queue)
      assert Enum.empty?(bound_queue)
      assert BoundQueue.shrunk?(bound_queue)

      start_supervised!({Task.Supervisor, name: BufferedTaskSup})

      ShrinkableTask
      |> expect(:init, fn initial, reducer, _ ->
        Enum.reduce([2, 3, 4], initial, reducer)
      end)

      assert {:noreply, %BufferedTask{flush_timer: flush_timer}} =
               BufferedTask.handle_info(:flush, %BufferedTask{
                 callback_module: ShrinkableTask,
                 callback_module_state: nil,
                 bound_queue: bound_queue,
                 flush_interval: 50,
                 flush_timer: nil,
                 task_supervisor: BufferedTaskSup,
                 max_batch_size: 2,
                 max_concurrency: 1
               })

      refute flush_timer == nil

      assert_receive {:"$gen_call", from1, {:push_back, [2, 3]}}, @assert_receive_timeout

      GenServer.reply(from1, :ok)

      assert_receive {:"$gen_call", from2, {:push_back, [4]}}, @assert_receive_timeout

      GenServer.reply(from2, :ok)

      assert_receive :flush, @assert_receive_timeout
    end
  end
end
