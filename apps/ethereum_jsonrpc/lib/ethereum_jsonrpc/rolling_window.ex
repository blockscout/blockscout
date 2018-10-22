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
    table_name = Keyword.fetch!(opts, :table)
    window_length = Keyword.fetch!(opts, :window_length)
    window_count = Keyword.fetch!(opts, :window_count)

    table = :ets.new(table_name, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

    # TODO: Calculate the match spec for the given window count here, and store it in state

    state = %{
      table: table,
      window_length: window_length,
      window_count: window_count
    }

    schedule_sweep(window_length)

    {:ok, state}
  end

  def handle_info(:sweep, %{window_count: window_count, table: table, window_length: window_length} = state) do
    Logger.debug(fn -> "Sweeping windows" end)
    # TODO consider broadcasting to indexers than some threshold has been met with result of updating the counter

    # Delete any rows wheree all windows empty
    delete_match_spec = delete_match_spec(window_count)

    :ets.match_delete(table, delete_match_spec)

    match_spec = match_spec(window_count)

    :ets.select_replace(table, match_spec)

    schedule_sweep(window_length)

    {:noreply, state}
  end

  defp match_spec(window_count) do
    # This match spec represents this function:
    #
    #  :ets.fun2ms(fn
    #    {key, n, [a, b, _]} ->
    #     {key, 0, [n, a, b]}
    #
    #   {key, n, windows} ->
    #     {key, 0, [n | windows]}
    # end)
    #
    # This function is an example for when window size is 3. The match spec
    # matches on all but the last element of the list

    [
      {
        full_windows_match_spec_matcher(window_count),
        [],
        full_windows_match_spec_mapper(window_count)
      },
      {
        partial_windows_match_spec_matcher(),
        [],
        partial_windows_match_spec_mapper()
      }
    ]
  end

  defp full_windows_match_spec_matcher(1) do
    {:"$1", :"$2", []}
  end

  defp full_windows_match_spec_matcher(window_count) do
    windows =
      3
      |> Range.new(window_count)
      |> Enum.map(&:"$#{&1}")
      |> Kernel.++([:_])

    {:"$1", :"$2", windows}
  end

  defp full_windows_match_spec_mapper(1) do
    [{{:"$1", 0, []}}]
  end

  defp full_windows_match_spec_mapper(window_count) do
    windows =
      3
      |> Range.new(window_count)
      |> Enum.map(&:"$#{&1}")

    [{{:"$1", 0, [:"$2" | windows]}}]
  end

  defp partial_windows_match_spec_matcher do
    {:"$1", :"$2", :"$3"}
  end

  defp partial_windows_match_spec_mapper do
    [{{:"$1", 0, [:"$2" | :"$3"]}}]
  end

  defp delete_match_spec(window_count) do
    {:"$1", 0, List.duplicate(0, window_count - 1)}
  end

  defp schedule_sweep(window_length) do
    Process.send_after(self(), :sweep, window_length)
  end

  @doc """
  Increment the count of events in the current window
  """
  @spec inc(table :: atom, key :: term()) :: :ok
  def inc(table, key) do
    default = {key, 0, []}

    :ets.update_counter(table, key, {2, 1}, default)

    :ok
  end

  @doc """
  Count all events in all windows
  """
  @spec count(table :: atom, key :: term()) :: non_neg_integer()
  def count(table, key) do
    case :ets.lookup(table, key) do
      [{_, current_window, windows}] -> current_window + Enum.sum(windows)
      _ -> 0
    end
  end

  @doc """
  Display the raw contents of all windows for a given key
  """
  @spec inspect(table :: atom, key :: term()) :: nonempty_list(non_neg_integer)
  def inspect(table, key) do
    case :ets.lookup(table, key) do
      [{_, current_window, windows}] ->
        [current_window | windows]

      _ ->
        []
    end
  end
end
