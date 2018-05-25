defmodule Explorer.BufferedTask do
  @moduledoc """
  TODO
  """
  use GenServer
  require Logger

  @callback init(initial :: term, reducer :: function) ::
              {:ok, accumulated_results :: term | initial :: term} | {:error, reason :: term}

  @callback run(entries :: list, retries :: pos_integer) :: :ok | {:retry, reason :: term} | {:halt, reason :: term}

  @doc """
  Buffers list of entries for future async execution.
  """
  def buffer(server, entries, timeout \\ 5000) when is_list(entries) do
    GenServer.call(server, {:buffer, entries}, timeout)
  end

  @doc false
  def debug_count(server) do
    GenServer.call(server, :debug_count)
  end

  def start_link({module, base_opts}) do
    default_opts = Application.fetch_env!(:explorer, :indexer)
    opts = Keyword.merge(default_opts, base_opts)

    GenServer.start_link(__MODULE__, {module, opts}, name: opts[:name])
  end

  def init({callback_module, opts}) do
    send(self(), :initial_stream)

    state = %{
      pid: self(),
      init_task: nil,
      flush_timer: nil,
      callback_module: callback_module,
      flush_interval: Keyword.fetch!(opts, :flush_interval),
      max_batch_size: Keyword.fetch!(opts, :max_batch_size),
      max_concurrency: Keyword.fetch!(opts, :max_concurrency),
      stream_chunk_size: Keyword.fetch!(opts, :stream_chunk_size),
      current_buffer: [],
      buffer: :queue.new(),
      tasks: %{}
    }

    {:ok, state}
  end

  def handle_info(:initial_stream, state) do
    {:noreply, do_initial_stream(state)}
  end

  def handle_info(:flush, state) do
    {:noreply, flush(state)}
  end

  def handle_info({ref, {:performed, :ok}}, state) do
    {:noreply, drop_task(state, ref)}
  end

  def handle_info({ref, {:performed, {:retry, _reason}}}, state) do
    {:noreply, drop_task_and_retry(state, ref)}
  end

  def handle_info({ref, {:performed, {:halt, _reason}}}, state) do
    {:noreply, drop_task(state, ref)}
  end

  def handle_info({ref, :ok}, %{init_task: ref} = state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, :normal}, %{init_task: ref} = state) do
    {:noreply, %{state | init_task: :complete}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, drop_task_and_retry(state, ref)}
  end

  def handle_call({:async_perform, stream_que}, _from, state) do
    new_buffer = :queue.join(state.buffer, stream_que)
    {:reply, :ok, spawn_next_batch(%{state | buffer: new_buffer})}
  end

  def handle_call({:buffer, entries}, _from, state) do
    {:reply, :ok, buffer_entries(state, entries)}
  end

  def handle_call(:debug_count, _from, state) do
    count = length(state.current_buffer) + :queue.len(state.buffer) * state.max_batch_size

    {:reply, count, state}
  end

  defp drop_task(state, ref) do
    spawn_next_batch(%{state | tasks: Map.delete(state.tasks, ref)})
  end

  defp drop_task_and_retry(state, ref) do
    {batch, retries} = Map.fetch!(state.tasks, ref)

    state
    |> drop_task(ref)
    |> queue(batch, retries + 1)
  end

  defp buffer_entries(state, []), do: state

  defp buffer_entries(state, entries) do
    %{state | current_buffer: [entries | state.current_buffer]}
  end

  defp queue(%{} = state, batch, retries) do
    %{state | buffer: queue(state.buffer, batch, retries)}
  end

  defp queue({_, _} = que, batch, retries) do
    :queue.in({batch, retries}, que)
  end

  defp do_initial_stream(%{stream_chunk_size: stream_chunk_size} = state) do
    task =
      Task.Supervisor.async(Explorer.TaskSupervisor, fn ->
        {0, []}
        |> state.callback_module.init(fn
          entry, {len, acc} when len + 1 >= stream_chunk_size ->
            [entry | acc]
            |> chunk_into_queue(state)
            |> async_perform(state.pid)

            {0, []}

          entry, {len, acc} ->
            {len + 1, [entry | acc]}
        end)
        |> catchup_remaining(state)
      end)

    schedule_next_buffer_flush(%{state | init_task: task.ref})
  end

  defp catchup_remaining({:ok, {0, []}}, _state), do: :ok

  defp catchup_remaining({:ok, {_len, batch}}, state) do
    batch
    |> chunk_into_queue(state)
    |> async_perform(state.pid)

    :ok
  end

  defp chunk_into_queue(entries, state) do
    entries
    |> Enum.reverse()
    |> Enum.chunk_every(state.max_batch_size)
    |> Enum.reduce(:queue.new(), fn batch, acc -> queue(acc, batch, 0) end)
  end

  defp take_batch(state) do
    case :queue.out(state.buffer) do
      {{:value, batch}, new_queue} -> {batch, new_queue}
      {:empty, new_queue} -> {[], new_queue}
    end
  end

  defp async_perform(entries, dest) do
    GenServer.call(dest, {:async_perform, entries})
  end

  defp schedule_next_buffer_flush(state) do
    timer = Process.send_after(self(), :flush, state.flush_interval)
    %{state | flush_timer: timer}
  end

  defp spawn_next_batch(state) do
    if Enum.count(state.tasks) < state.max_concurrency and :queue.len(state.buffer) > 0 do
      {{batch, retries}, new_queue} = take_batch(state)

      task =
        Task.Supervisor.async_nolink(Explorer.TaskSupervisor, fn ->
          {:performed, state.callback_module.run(batch, retries)}
        end)

      %{state | tasks: Map.put(state.tasks, task.ref, {batch, retries}), buffer: new_queue}
    else
      state
    end
  end

  defp flush(%{current_buffer: []} = state) do
    state |> spawn_next_batch() |> schedule_next_buffer_flush()
  end

  defp flush(%{current_buffer: current} = state) do
    current
    |> List.flatten()
    |> Enum.chunk_every(state.max_batch_size)
    |> Enum.reduce(%{state | current_buffer: []}, fn batch, state_acc ->
      queue(state_acc, batch, 0)
    end)
    |> flush()
  end
end
