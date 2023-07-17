defmodule Indexer.Memory.Monitor do
  @moduledoc """
  Monitors memory usage of Erlang VM.

  If memory usage (as reported by `:erlang.memory(:total)` exceeds the configured limit, then the `Process` with the
  worst memory usage (as reported by `Process.info(pid, :memory)`) in `shrinkable_set` is asked to
  `c:Indexer.Memory.Shrinkable.shrink/0`.
  """

  require Bitwise
  require Logger

  import Indexer.Logger, only: [process: 1]

  alias Indexer.Memory.Shrinkable

  defstruct limit: 0,
            timer_interval: :timer.minutes(1),
            timer_reference: nil,
            shrinkable_set: MapSet.new()

  use GenServer

  @doc """
  Registers caller as `Indexer.Memory.Shrinkable`.
  """
  def shrinkable(server \\ __MODULE__) do
    GenServer.call(server, :shrinkable)
  end

  def child_spec([]) do
    child_spec([%{}, []])
  end

  def child_spec([init_options, gen_server_options] = start_link_arguments)
      when is_map(init_options) and is_list(gen_server_options) do
    Supervisor.child_spec(%{id: __MODULE__, start: {__MODULE__, :start_link, start_link_arguments}}, [])
  end

  def start_link(init_options, gen_server_options \\ []) when is_map(init_options) and is_list(gen_server_options) do
    GenServer.start_link(__MODULE__, init_options, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(options) when is_map(options) do
    state = struct!(__MODULE__, options)
    {:ok, timer_reference} = :timer.send_interval(state.timer_interval, :check)

    {:ok, %__MODULE__{state | timer_reference: timer_reference}}
  end

  @impl GenServer
  def handle_call(:shrinkable, {pid, _}, %__MODULE__{shrinkable_set: shrinkable_set} = state) do
    Process.monitor(pid)

    {:reply, :ok, %__MODULE__{state | shrinkable_set: MapSet.put(shrinkable_set, pid)}}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, pid, _}, %__MODULE__{shrinkable_set: shrinkable_set} = state) do
    {:noreply, %__MODULE__{state | shrinkable_set: MapSet.delete(shrinkable_set, pid)}}
  end

  @impl GenServer
  def handle_info(:check, state) do
    total = :erlang.memory(:total)

    if memory_limit() < total do
      log_memory(%{limit: memory_limit(), total: total})
      shrink_or_log(state)
    end

    flush(:check)

    {:noreply, state}
  end

  defp flush(message) do
    receive do
      ^message -> flush(message)
    after
      0 ->
        :ok
    end
  end

  defp memory(pid) when is_pid(pid) do
    case Process.info(pid, :memory) do
      {:memory, memory} -> memory
      # process died
      nil -> 0
    end
  end

  defp log_memory(%{total: total, limit: limit}) do
    Logger.warn(fn ->
      [
        to_string(total),
        " / ",
        to_string(limit),
        " bytes (",
        to_string(div(100 * total, limit)),
        "%) of memory limit used."
      ]
    end)
  end

  defp shrink_or_log(%__MODULE__{} = state) do
    case shrink(state) do
      :ok ->
        :ok

      {:error, :minimum_size} ->
        Logger.error(fn -> "No processes could be shrunk.  Limit will remain surpassed." end)
    end
  end

  defp shrink(%__MODULE__{} = state) do
    state
    |> shrinkable_memory_pairs()
    |> shrink()
  end

  defp shrink([]) do
    {:error, :minimum_size}
  end

  defp shrink([{pid, memory} | tail]) do
    Logger.warn(fn ->
      [
        "Worst memory usage (",
        to_string(memory),
        " bytes) among remaining shrinkable processes is ",
        process(pid),
        ".  Asking process to shrink to drop below limit."
      ]
    end)

    case Shrinkable.shrink(pid) do
      :ok ->
        Logger.info(fn ->
          after_memory = memory(pid)

          [
            process(pid),
            " shrunk from ",
            to_string(memory),
            " bytes to ",
            to_string(after_memory),
            " bytes (",
            to_string(div(100 * after_memory, memory)),
            "%)."
          ]
        end)

        :ok

      {:error, :minimum_size} ->
        Logger.error(fn ->
          [process(pid), " is at its minimum size and could not shrink."]
        end)

        shrink(tail)
    end
  end

  defp shrinkable_memory_pairs(%__MODULE__{shrinkable_set: shrinkable_set}) do
    shrinkable_set
    |> Enum.map(fn pid -> {pid, memory(pid)} end)
    |> Enum.sort_by(&elem(&1, 1), &>=/2)
  end

  defp memory_limit do
    Application.get_env(:indexer, :memory_limit)
  end
end
