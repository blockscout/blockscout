defmodule EthereumJSONRPC.RollingWindow do
  @moduledoc """
  TODO
  """

  use GenServer

  @sweep_after :timer.seconds(10)

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
    window_count = Keyword.fetch(otps, :window_count)

    table = :ets.new(bucket, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

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

    match_spec = match_spec(window_count)

    :ets.select_replace(table, match_spec)

    schedule_sweep(window_length)

    {:noreply, state}
  end

  defp match_spec(window_count) do
    [{
      match_spec_matcher(window_count),
      [],
      match_spec_mapper(window_count)
    }]
  end

  defp match_spec_matcher(window_count) do
    range = Range.new(1, window_count + 1)

    range
    |> Enum.map(& :"$#{&1}")
    |> to_tuple()
  end

  defp match_spec_mapper(1) do
    [{{:"$1", 0}}]
  end

  defp match_spec_mapper(window_count) do
    inner_tuple =
      1..window_count
      |> Enum.map(& :"$#{&1}")
      |> to_tuple()
      |> Tuple.insert_at(1, 0)
    [{inner_tuple}]
  end

  defp schedule_sweep(window_length) do
    Process.send_after(self(), :sweep, window_length)
  end

  def log_timeout(key) do
    # TODO account for tables of different window counts
    :ets.update_counter(@tab, key, {2, 1}, {key, 0, 0, 0, 0, 0, 0})
  end

  def count_timeouts(key) do
    # TODO account for tables of different window counts
    case :ets.lookup(@tab, key) do
      [{_, a, b, c, d, e, f}] -> a + b + c + d + e + f
      _ -> 0
    end
  end
end
