defmodule Explorer.BufferedTask do
  @moduledoc """
  TODO
  """
  use GenServer
  require Logger

  @callback init(initial :: term, reducer :: function) ::
              {:ok, accumulated_results :: term | initial :: term} | {:error, reason :: term}

  @callback run(entries :: list) :: :ok | {:retry, reason :: term} | {:halt, reason :: term}

  @flush_interval :timer.seconds(3)

  def buffer(server, entry) do
    GenServer.call(server, {:buffer, entry})
  end

  def start_link({module, base_opts}) do
    default_opts = Application.fetch_env!(:explorer, :indexer)
    opts = Keyword.merge(default_opts, base_opts)

    GenServer.start_link(__MODULE__, {module, opts}, name: opts[:name])
  end

  def init({callback_module, opts}) do
    send(self(), :initial_stream)

    state = %{
      callback_module: callback_module,
      debug_logs: Keyword.get(opts, :debug_logs, false),
      flush_timer: nil,
      flush_interval: Keyword.get(opts, :flush_interval, @flush_interval),
      max_batch_size: Keyword.fetch!(opts, :max_batch_size),
      max_concurrency: Keyword.fetch!(opts, :max_concurrency),
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

  def handle_info({:async_perform, entries}, state) do
    {:noreply, spawn_next_batch(state, entries)}
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

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, drop_task_and_retry(state, ref)}
  end

  def handle_call({:buffer, entries}, _from, state) do
    {:reply, :ok, buffer_entries(state, entries)}
  end

  defp drop_task(state, ref) do
    schedule_async_perform([])
    %{state | tasks: Map.delete(state.tasks, ref)}
  end

  defp drop_task_and_retry(state, ref) do
    batch = Map.fetch!(state.tasks, ref)

    state
    |> drop_task(ref)
    |> buffer_entries(batch)
  end

  defp buffer_entries(state, []), do: state

  defp buffer_entries(state, entries) do
    current_buffer = entries ++ state.current_buffer
    {batch, overflow} = Enum.split(current_buffer, state.max_batch_size)

    if length(batch) == state.max_batch_size do
      %{state | current_buffer: overflow, buffer: :queue.in(batch, state.buffer)}
    else
      %{state | current_buffer: current_buffer}
    end
  end

  defp do_initial_stream(state) do
    {0, []}
    |> state.callback_module.init(fn entry, {len, acc} ->
      batch = [entry | acc]

      if len + 1 >= state.max_batch_size do
        schedule_async_perform(Enum.reverse(batch))
        {0, []}
      else
        {len + 1, batch}
      end
    end)
    |> catchup_remaining()

    schedule_next_buffer_flush(state)
  end

  defp catchup_remaining({:ok, {0, []}}), do: :ok

  defp catchup_remaining({:ok, {_len, batch}}) do
    schedule_async_perform(Enum.reverse(batch))
    :ok
  end

  defp take_batch(state) do
    case :queue.out(state.buffer) do
      {{:value, batch}, new_queue} -> {batch, new_queue}
      {:empty, new_queue} -> {:halt, {[], new_queue}}
    end
  end

  defp schedule_async_perform(entries, after_ms \\ 0) do
    Process.send_after(self(), {:async_perform, entries}, after_ms)
  end

  defp schedule_next_buffer_flush(state) do
    timer = Process.send_after(self(), :flush, state.flush_interval)
    %{state | flush_timer: timer}
  end

  defp spawn_next_batch(state, entries) do
    state = buffer_entries(state, entries)

    if Enum.count(state.tasks) < state.max_concurrency and :queue.len(state.buffer) > 0 do
      {batch, new_queue} = take_batch(state)

      task =
        Task.Supervisor.async_nolink(Explorer.TaskSupervisor, fn ->
          debug(state, fn -> "processing #{Enum.count(batch)} entries for #{inspect(state.callback_module)}" end)
          {:performed, state.callback_module.run(batch)}
        end)

      %{state | tasks: Map.put(state.tasks, task.ref, batch), buffer: new_queue}
    else
      state
    end
  end

  defp flush(%{current_buffer: []} = state) do
    state |> spawn_next_batch([]) |> schedule_next_buffer_flush()
  end

  defp flush(%{current_buffer: current} = state) do
    {batch, overflow} = Enum.split(current, state.max_batch_size)

    flush(%{
      state
      | buffer: :queue.in(batch, state.buffer),
        current_buffer: overflow
    })
  end

  defp debug(%{debug_logs: true}, func), do: Logger.debug(func)
  defp debug(%{debug_logs: false}, _func), do: :noop
end
