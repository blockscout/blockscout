defmodule Indexer.Memory.Monitor do
  @moduledoc """
  Monitors memory usage of Erlang VM.

  If memory usage (as reported by `:erlang.memory(:total)` exceeds the configured limit, then the `Process` with the
  worst memory usage (as reported by `Process.info(pid, :memory)`) in `shrinkable_set` is asked to
  `c:Indexer.Memory.Shrinkable.shrink/0`.
  """

  require Logger

  import Bitwise
  import Indexer.Logger, only: [process: 1]

  alias Indexer.Memory.Shrinkable
  alias Indexer.Prometheus.Instrumenter

  defstruct limit: 0,
            timer_interval: :timer.minutes(1),
            timer_reference: nil,
            shrinkable_set: MapSet.new(),
            shrunk?: false

  use GenServer

  @expandable_memory_coefficient 0.4

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
    state = struct!(__MODULE__, Map.put_new(options, :limit, define_memory_limit()))
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
  def handle_info(:check, %{limit: limit} = state) do
    total = :erlang.memory(:total)

    set_metrics(state)

    shrunk_state =
      if limit < total do
        log_memory(%{limit: limit, total: total})
        shrink_or_log(state)
        %{state | shrunk?: true}
      else
        state
      end

    final_state =
      if state.shrunk? and total <= limit * @expandable_memory_coefficient do
        log_expandable_memory(%{limit: limit, total: total})
        expand(state)
        %{state | shrunk?: false}
      else
        shrunk_state
      end

    flush(:check)

    {:noreply, final_state}
  end

  defp define_memory_limit do
    case Application.get_env(:indexer, :memory_limit) do
      integer when is_integer(integer) -> integer
      _not_set -> memory_limit_from_system()
    end
  end

  defp memory_limit_from_system do
    default_limit = 1 <<< 30

    percentage =
      case Application.get_env(:explorer, :mode) do
        :indexer -> 100
        _ -> Application.get_env(:indexer, :system_memory_percentage)
      end

    case :memsup.get_system_memory_data()[:total_memory] do
      nil -> default_limit
      total_memory -> floor(total_memory * percentage / 100)
    end
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
    Logger.warning(fn ->
      [
        to_string(total),
        " / ",
        to_string(limit),
        " bytes (",
        to_string(div(100 * total, limit)),
        "%) of memory limit used, shrinking queues"
      ]
    end)
  end

  defp log_expandable_memory(%{total: total, limit: limit}) do
    Logger.info(fn ->
      [
        to_string(total),
        " / ",
        to_string(limit),
        " bytes (",
        to_string(div(100 * total, limit)),
        "%) of memory limit used, expanding queues"
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
    Logger.warning(fn ->
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

  defp expand(%__MODULE__{} = state) do
    state
    |> shrinkable_memory_pairs()
    |> Enum.each(fn {pid, _memory} ->
      Logger.info(fn -> ["Expanding queue ", process(pid)] end)
      Shrinkable.expand(pid)
    end)
  end

  @megabytes_divisor 2 ** 20
  defp set_metrics(%__MODULE__{shrinkable_set: shrinkable_set}) do
    total_memory =
      Enum.reduce(Enum.to_list(shrinkable_set) ++ on_demand_fetchers(), 0, fn pid, acc ->
        memory = memory(pid) / @megabytes_divisor
        name = name(pid)

        Instrumenter.set_memory_consumed(name, memory)

        acc + memory
      end)

    Instrumenter.set_memory_consumed(:total, total_memory)
  end

  defp on_demand_fetchers do
    [Indexer.Application, Indexer.Supervisor, Explorer.Supervisor]
    |> Enum.reject(&is_nil(Process.whereis(&1)))
    |> Enum.flat_map(fn supervisor ->
      supervisor
      |> Supervisor.which_children()
      |> Enum.filter(fn {name, _, _, _} -> is_atom(name) and String.contains?(to_string(name), "OnDemand") end)
      |> Enum.flat_map(fn
        {_, pid, :supervisor, _} ->
          pid
          |> Supervisor.which_children()
          |> Enum.filter(&(elem(&1, 2) == :worker))
          |> Enum.map(&elem(&1, 1))

        {_, pid, _, _} ->
          [pid]
      end)
    end)
  end

  defp name(pid) do
    case Process.info(pid, :registered_name) do
      {:registered_name, name} when is_atom(name) ->
        name
        |> to_string()
        |> String.split(".")
        |> Enum.slice(-2, 2)
        |> Enum.join(".")

      _ ->
        nil
    end
  end

  defp shrinkable_memory_pairs(%__MODULE__{shrinkable_set: shrinkable_set}) do
    shrinkable_set
    |> Enum.map(fn pid -> {pid, memory(pid)} end)
    |> Enum.sort_by(&elem(&1, 1), &>=/2)
  end
end
