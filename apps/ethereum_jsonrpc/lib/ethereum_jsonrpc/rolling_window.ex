defmodule EthereumJSONRPC.RollingWindow do
  @moduledoc """
  Tracker for counting an event that occurs within a moving time window.

  This is an abstraction to keep track of events within a recent time windows
  group into smaller buckets of time relative to the current time. It gives a
  better approximation of recent events without needing to constantly check for
  event timestamps.

  ## Options

  * `:table` - Name of table for direct access
  * `:duration` - Total amount of time to count events in milliseconds
  * `:window_count` - Amount of slices to subdivide the total window length

  For example, if you choose a duration of 60,000 milliseconds with a window
  count of 6, you'll have 6 slices of 10,000 milliseconds event windows.

  NOTE: Duration must be evenly divisible by window_count.
  """

  use GenServer

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
    duration = Keyword.fetch!(opts, :duration)
    window_count = Keyword.fetch!(opts, :window_count)

    unless rem(duration, window_count) == 0 do
      raise ArgumentError, "duration must be evenly divisible by window_count"
    end

    window_length = div(duration, window_count)

    table = :ets.new(table_name, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

    replace_match_spec = match_spec(window_count)
    delete_match_spec = delete_match_spec(window_count)

    state = %{
      table: table,
      window_length: window_length,
      window_count: window_count,
      replace_match_spec: replace_match_spec,
      delete_match_spec: delete_match_spec
    }

    schedule_sweep(window_length)

    {:ok, state}
  end

  def handle_info(
        :sweep,
        %{
          table: table,
          window_length: window_length,
          delete_match_spec: delete_match_spec,
          replace_match_spec: replace_match_spec
        } = state
      ) do
    sweep(table, delete_match_spec, replace_match_spec)

    schedule_sweep(window_length)

    {:noreply, state}
  end

  # Additional call to sweep to manually invoke sweeping for testing
  def handle_call(
        :sweep,
        _from,
        %{
          table: table,
          delete_match_spec: delete_match_spec,
          replace_match_spec: replace_match_spec
        } = state
      ) do
    sweep(table, delete_match_spec, replace_match_spec)

    {:reply, :ok, state}
  end

  # Public for testing
  defp sweep(table, delete_match_spec, replace_match_spec) do
    # Delete any rows where all windows empty
    :ets.match_delete(table, delete_match_spec)

    :ets.select_replace(table, replace_match_spec)
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
  Count all events in all windows for a given key.
  """
  @spec count(table :: atom, key :: term()) :: non_neg_integer()
  def count(table, key) do
    case :ets.lookup(table, key) do
      [{_, current_window, windows}] -> current_window + Enum.sum(windows)
      _ -> 0
    end
  end

  @doc """
  Display the raw contents of all windows for a given key.
  """
  @spec inspect(table :: atom, key :: term()) :: nonempty_list(non_neg_integer) | []
  def inspect(table, key) do
    case :ets.whereis(table) do
      :undefined ->
        []

      tid ->
        case :ets.lookup(tid, key) do
          [{_, current_window, windows}] ->
            [current_window | windows]

          _ ->
            []
        end
    end
  end
end
