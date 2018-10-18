defmodule EthereumJSONRPC.RollingWindow do
  @moduledoc """
  TODO
  """

  use GenServer
  require Logger

  def child_spec([init_arguments]) do
    child_spec([init_arguments, []])
  end

  def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :permanent,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(init_arguments, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, init_arguments, gen_server_options)
  end

  def init(opts) do
    table_name = Keyword.fetch!(opts, :bucket)
    window_length = Keyword.fetch!(opts, :window_length)
    window_count = Keyword.fetch!(opts, :window_count)

    table = :ets.new(table_name, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

    state = %{
      table: table,
      window_length: window_length,
      window_count: window_count
    }

    schedule_sweep(window_length)

    {:ok, state}
  end

  def handle_call({:count, key}, _from, %{table: table} = state) do
    count =
      case :ets.lookup(table, key) do
        [windows] -> windows |> Tuple.to_list() |> tl() |> Enum.sum()
        _ -> 0
      end

    {:reply, count, state}
  end

  def handle_call({:inspect, key}, _from, %{table: table, window_count: window_count} = state) do
    windows =
      case :ets.lookup(table, key) do
        [windows] ->
          windows |> Tuple.to_list() |> tl()

        _ ->
          List.duplicate(0, window_count)
      end

    {:reply, windows, state}
  end

  def handle_cast({:inc, key}, %{table: table, window_count: window_count} = state) do
    windows = List.duplicate(0, window_count)
    default = List.to_tuple([key | windows])

    :ets.update_counter(table, key, {2, 1}, default)

    {:noreply, state}
  end

  def handle_info(:sweep, %{window_count: window_count, table: table, window_length: window_length} = state) do
    Logger.debug(fn -> "Sweeping windows" end)

    # Delete any rows wheree all windows empty
    delete_match_spec = delete_match_spec(window_count)

    :ets.match_delete(table, delete_match_spec)

    match_spec = match_spec(window_count)

    :ets.select_replace(table, match_spec)

    schedule_sweep(window_length)

    {:noreply, state}
  end

  defp match_spec(window_count) do
    [
      {
        match_spec_matcher(window_count),
        [],
        match_spec_mapper(window_count)
      }
    ]
  end

  defp match_spec_matcher(window_count) do
    range = Range.new(1, window_count + 1)

    range
    |> Enum.map(&:"$#{&1}")
    |> List.to_tuple()
  end

  defp delete_match_spec(window_count) do
    List.to_tuple([:"$1" | List.duplicate(0, window_count)])
  end

  defp match_spec_mapper(1) do
    [{{:"$1", 0}}]
  end

  defp match_spec_mapper(window_count) do
    inner_tuple =
      1..window_count
      |> Enum.map(&:"$#{&1}")
      |> List.to_tuple()
      |> Tuple.insert_at(1, 0)

    [{inner_tuple}]
  end

  defp schedule_sweep(window_length) do
    Process.send_after(self(), :sweep, window_length)
  end

  @doc """
  Increment the count of events in the current window
  """
  @spec inc(GenServer.server(), key :: term()) :: :ok
  def inc(server, key) do
    # Consider requiring the bucket and key to be passed in here
    # so that this and count/2 do not need to call to the server
    GenServer.cast(server, {:inc, key})
  end

  @doc """
  Count all events in all windows
  """
  @spec count(GenServer.server(), key :: term()) :: non_neg_integer()
  def count(server, key) do
    GenServer.call(server, {:count, key})
  end

  @doc """
  Display the raw contents of all windows for a given key
  """
  @spec inspect(GenServer.server(), key :: term()) :: nonempty_list(non_neg_integer)
  def inspect(server, key) do
    GenServer.call(server, {:inspect, key})
  end
end
