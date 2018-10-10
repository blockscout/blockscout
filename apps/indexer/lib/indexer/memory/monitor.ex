defmodule Indexer.Memory.Monitor do
  @moduledoc """
  Monitors memory usage of Erlang VM.

  If memory usage (as reported by `:erlang.memory(:total)` exceeds the configured limit, then the `Process` with the
  worst memory usage (as reported by `Process.info(pid, :memory)`) in `shrinkable_set` is asked to
  `c:Indexer.Memory.Shrinkable.shrink/0`.
  """

  require Bitwise
  require Logger

  import Bitwise

  alias Indexer.Memory.Shrinkable

  defstruct limit: 1 <<< 30,
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
  def handle_call(:shinkable, {pid, _}, %__MODULE__{shrinkable_set: shrinkable_set} = state) do
    Process.monitor(pid)

    {:reply, :ok, %__MODULE__{state | shrinkable_set: MapSet.put(shrinkable_set, pid)}}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, pid, _}, %__MODULE__{shrinkable_set: shrinkable_set}) do
    {:noreply, %__MODULE__{shrinkable_set: MapSet.delete(shrinkable_set, pid)}}
  end

  @impl GenServer
  def handle_info(:check, %__MODULE__{limit: limit} = state) do
    total = :erlang.memory(:total)

    if limit < total do
      case shrinkable_with_most_memory(state) do
        {:error, :not_found} ->
          Logger.error(fn ->
            [
              prefix(%{total: total, limit: limit}),
              "  No processes are registered as shrinkable.  Limit will remain surpassed."
            ]
          end)

        {:ok, {pid, memory}} ->
          Logger.warn(fn ->
            prefix = [
              prefix(%{total: total, limit: limit}),
              "  Worst memory usage (",
              to_string(memory),
              " bytes) among shrinkable processes is ",
              inspect(pid)
            ]

            {:registered_name, registered_name} = Process.info(pid, :registered_name)

            prefix =
              case registered_name do
                [] -> [prefix, "."]
                _ -> [prefix, " (", inspect(registered_name), ")."]
              end

            [prefix, "  Asking ", inspect(pid), " to shrinkable to drop below limit."]
          end)

          :ok = Shrinkable.shrink(pid)
      end
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

  defp prefix(%{total: total, limit: limit}) do
    [
      to_string(total),
      " / ",
      to_string(limit),
      " bytes (",
      to_string(div(100 * total, limit)),
      "%) of memory limit used."
    ]
  end

  defp shrinkable_with_most_memory(%__MODULE__{shrinkable_set: shrinkable_set}) do
    if Enum.empty?(shrinkable_set) do
      {:error, :not_found}
    else
      pid_memory =
        shrinkable_set
        |> Enum.map(fn pid -> {pid, memory(pid)} end)
        |> Enum.max_by(&elem(&1, 1))

      {:ok, pid_memory}
    end
  end
end
