defmodule EthereumJSONRPC.RollingWindow do
  use GenServer
  require Logger

  @sweep_after :timer.seconds(10)
  @interval :timer.seconds(60)
  @tab :rate_limiter_requests

  ## Client

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def log_timeout(key) do
    :ets.update_counter(@tab, key, {2, 1}, {key, 0, 0, 0, 0, 0, 0})
  end

  def count_timeouts(key) do
    case :ets.lookup(@tab, key) do
      [{_, a, b, c, d, e, f}] -> a + b + c + d + e + f
      _ -> 0
    end
  end

  ## Server
  def init(_) do
    :ets.new(@tab, [:set, :named_table, :public, read_concurrency: true, write_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  def handle_info(:sweep, state) do
    Logger.debug("Sweeping requests")

    match_spec = [
      {{:"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7"}, [], [{{:"$1", 0, :"$2", :"$3", :"$4", :"$5", :"$6"}}]}
    ]

    :ets.select_replace(@tab, match_spec)

    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_after)
  end
end
