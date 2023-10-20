defmodule Explorer.Market.History.Cataloger do
  @moduledoc """
  Fetches the daily market history.

  Market grabs the last 365 day's worth of market history for the configured
  coin in the explorer. Once that data is fetched, current day's values are
  checked every 60 minutes. Additionally, failed requests to the history
  source will follow exponential backoff `100ms * 2^(n+1)` where `n` is the
  number of failed requests.

  """

  use GenServer

  require Logger

  alias Explorer.History.Process, as: HistoryProcess
  alias Explorer.Market

  @price_failed_attempts 10
  @market_cap_failed_attempts 3
  @tvl_failed_attempts 3

  @impl GenServer
  def init(:ok) do
    if Application.get_env(:explorer, __MODULE__)[:enabled] do
      send(self(), {:fetch_price_history, 365})

      {:ok, %{}}
    else
      :ignore
    end
  end

  @impl GenServer
  def handle_info({:fetch_price_history, day_count}, state) do
    fetch_price_history(day_count)

    {:noreply, state}
  end

  @impl GenServer
  # Record fetch successful.
  def handle_info({_ref, {:price_history, {_, _, {:ok, records}}}}, state) do
    Process.send(self(), {:fetch_market_cap_history, 365}, [])
    state = state |> Map.put_new(:price_records, records)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:fetch_market_cap_history, day_count}, state) do
    fetch_market_cap_history(day_count)
    state = state |> Map.put_new(:price_records, [])

    {:noreply, state}
  end

  @impl GenServer
  # Record fetch successful.
  def handle_info({_ref, {:market_cap_history, {_, _, {:ok, nil}}}}, state) do
    Process.send(self(), {:fetch_tvl_history, 365}, [])
    state = state |> Map.put_new(:market_cap_records, [])

    {:noreply, state}
  end

  @impl GenServer
  # Record fetch successful.
  def handle_info({_ref, {:market_cap_history, {_, _, {:ok, market_cap_records}}}}, state) do
    Process.send(self(), {:fetch_tvl_history, 365}, [])
    state = state |> Map.put_new(:market_cap_records, market_cap_records)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:fetch_tvl_history, day_count}, state) do
    fetch_tvl_history(day_count)

    {:noreply, state}
  end

  @impl GenServer
  # Record fetch successful.
  def handle_info({_ref, {:tvl_history, {_, _, {:ok, nil}}}}, state) do
    state = state |> Map.put_new(:tvl_records, [])
    records = compile_records(state)
    market_cap_history(records, state)
  end

  @impl GenServer
  # Record fetch successful.
  def handle_info({_ref, {:tvl_history, {_, _, {:ok, tvl_records}}}}, state) do
    state = state |> Map.put_new(:tvl_records, tvl_records)
    records = compile_records(state)
    market_cap_history(records, state)
  end

  # Failed to get records. Try again.
  @impl GenServer
  def handle_info({_ref, {:price_history, {day_count, failed_attempts, :error}}}, state) do
    Logger.warn(fn -> "Failed to fetch price history. Trying again." end)

    fetch_price_history(day_count, failed_attempts + 1)

    {:noreply, state}
  end

  # Failed to get records. Try again.
  @impl GenServer
  def handle_info({_ref, {:market_cap_history, {day_count, failed_attempts, :error}}}, state) do
    Logger.warn(fn -> "Failed to fetch market cap history. Trying again." end)

    fetch_market_cap_history(day_count, failed_attempts + 1)

    {:noreply, state}
  end

  # Failed to get records. Try again.
  @impl GenServer
  def handle_info({_ref, {:tvl_history, {day_count, failed_attempts, :error}}}, state) do
    Logger.warn(fn -> "Failed to fetch market cap history. Trying again." end)

    fetch_tvl_history(day_count, failed_attempts + 1)

    {:noreply, state}
  end

  # Callback that a monitored process has shutdown.
  @impl GenServer
  def handle_info({:DOWN, _, :process, _, _}, state) do
    {:noreply, state}
  end

  @doc """
  Starts a process to continually fetch market history.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec config_or_default(atom(), term(), term()) :: term()
  defp config_or_default(key, module, default) do
    Application.get_env(:explorer, module)[key] || default
  end

  @spec config_or_default(atom(), term()) :: term()
  defp config_or_default(key, default) do
    Application.get_env(:explorer, __MODULE__)[key] || default
  end

  defp market_cap_history(records, state) do
    Market.bulk_insert_history(records)

    # Schedule next check for history
    fetch_after = config_or_default(:history_fetch_interval, :timer.minutes(60))
    Process.send_after(self(), {:fetch_price_history, 1}, fetch_after)

    {:noreply, state}
  end

  @spec source_price() :: module()
  defp source_price do
    config_or_default(:price_source, Explorer.ExchangeRates.Source, Explorer.Market.History.Source.Price.CryptoCompare)
  end

  @spec source_market_cap() :: module()
  defp source_market_cap do
    config_or_default(
      :market_cap_source,
      Explorer.ExchangeRates.Source,
      Explorer.Market.History.Source.MarketCap.CoinGecko
    )
  end

  @spec source_tvl() :: module()
  defp source_tvl do
    config_or_default(
      :tvl_source,
      Explorer.ExchangeRates.Source,
      Explorer.Market.History.Source.TVL.DefiLlama
    )
  end

  @spec fetch_price_history(non_neg_integer(), non_neg_integer()) :: Task.t()
  defp fetch_price_history(day_count, failed_attempts \\ 0) do
    Task.Supervisor.async_nolink(Explorer.MarketTaskSupervisor, fn ->
      Process.sleep(HistoryProcess.delay(failed_attempts))

      if failed_attempts < @price_failed_attempts do
        {:price_history, {day_count, failed_attempts, source_price().fetch_price_history(day_count)}}
      else
        {:price_history, {day_count, failed_attempts, {:ok, []}}}
      end
    end)
  end

  @spec fetch_market_cap_history(non_neg_integer()) :: Task.t()
  defp fetch_market_cap_history(day_count, failed_attempts \\ 0) do
    Task.Supervisor.async_nolink(Explorer.MarketTaskSupervisor, fn ->
      Process.sleep(HistoryProcess.delay(failed_attempts))

      if failed_attempts < @market_cap_failed_attempts do
        {:market_cap_history, {day_count, failed_attempts, source_market_cap().fetch_market_cap(day_count)}}
      else
        {:market_cap_history, {day_count, failed_attempts, {:ok, nil}}}
      end
    end)
  end

  @spec fetch_tvl_history(non_neg_integer()) :: Task.t()
  defp fetch_tvl_history(day_count, failed_attempts \\ 0) do
    Task.Supervisor.async_nolink(Explorer.MarketTaskSupervisor, fn ->
      Process.sleep(HistoryProcess.delay(failed_attempts))

      if failed_attempts < @tvl_failed_attempts do
        {:tvl_history, {day_count, failed_attempts, source_tvl().fetch_tvl(day_count)}}
      else
        {:tvl_history, {day_count, failed_attempts, {:ok, nil}}}
      end
    end)
  end

  defp compile_records(state) do
    price_records = state.price_records
    market_cap_records = state.market_cap_records
    tvl_records = state.tvl_records

    all_records = price_records ++ market_cap_records ++ tvl_records

    all_records
    |> Enum.group_by(fn %{date: date} -> date end)
    |> Map.values()
    |> Enum.map(fn a ->
      Enum.reduce(a, %{}, fn x, acc -> Map.merge(x, acc) end)
    end)
  end
end
