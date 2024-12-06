defmodule Explorer.ExchangeRates do
  @moduledoc """
  Local cache for native coin exchange rates.

  Exchange rate data is updated every 10 minutes or CACHE_EXCHANGE_RATES_PERIOD seconds.
  """

  use GenServer

  require Logger

  alias Explorer.Chain.Events.Publisher
  alias Explorer.Market
  alias Explorer.ExchangeRates.{Source, Token}

  @table_name :exchange_rates

  @impl GenServer
  def handle_info(:update, state) do
    Logger.debug(fn -> "Updating cached exchange rates" end)

    fetch_rates()

    {:noreply, state}
  end

  # Callback for successful fetch
  @impl GenServer
  def handle_info({_ref, {:ok, secondary_coin?, [coin]}}, state) do
    if store() == :ets do
      :ets.insert(table_name(), {secondary_coin?, coin})
    end

    broadcast_event(:exchange_rate)

    unless secondary_coin? do
      schedule_next_consolidation()
    end

    {:noreply, state}
  end

  # Callback for errored fetch
  @impl GenServer
  def handle_info({_ref, {:error, secondary_coin?, reason}}, state) do
    Logger.warning(fn ->
      "Failed to get #{if secondary_coin?, do: "secondary", else: ""} exchange rates with reason '#{reason}'."
    end)

    unless secondary_coin? do
      schedule_next_consolidation()
    end

    {:noreply, state}
  end

  # Callback that a monitored process has shutdown
  @impl GenServer
  def handle_info({:DOWN, _, :process, _, _}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def init(_) do
    send(self(), :update)

    table_opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    if store() == :ets do
      :ets.new(table_name(), table_opts)
    end

    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  defp schedule_next_consolidation do
    if consolidate?() do
      Process.send_after(self(), :update, cache_period())
    end
  end

  @spec get_coin_exchange_rate() :: Token.t() | nil
  def get_coin_exchange_rate do
    if store() == :ets && enabled?() do
      case :ets.lookup(table_name(), false) do
        [{_, coin} | _] -> coin
        _ -> nil
      end
    end
  end

  @spec get_secondary_coin_exchange_rate() :: Token.t() | nil
  def get_secondary_coin_exchange_rate do
    if store() == :ets && enabled?() do
      case :ets.lookup(table_name(), true) do
        [{_, coin} | _] -> coin
        _ -> nil
      end
    end
  end

  @doc """
  Lists exchange rates for the tracked tickers.
  """
  @spec list :: [Token.t()] | nil
  def list do
    if enabled?() do
      list_from_store(store())
    end
  end

  @doc """
  Returns a specific rate from the tracked tickers by symbol
  """
  @spec lookup(String.t()) :: Token.t() | nil
  def lookup(symbol) do
    if store() == :ets && enabled?() do
      case :ets.lookup(table_name(), symbol) do
        [tuple | _] when is_tuple(tuple) -> Token.from_tuple(tuple)
        _ -> nil
      end
    end
  end

  @doc false
  @spec table_name() :: atom()
  def table_name do
    config(:table_name) || @table_name
  end

  @spec broadcast_event(atom()) :: :ok
  defp broadcast_event(event_type) do
    Publisher.broadcast(event_type)
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  @spec fetch_rates :: Task.t()
  defp fetch_rates do
    Task.Supervisor.async_nolink(Explorer.MarketTaskSupervisor, fetch_rates_task(false))

    if secondary_coin_enabled?() do
      Task.Supervisor.async_nolink(Explorer.MarketTaskSupervisor, fetch_rates_task(true))
    end
  end

  defp fetch_rates_task(false) do
    fn ->
      case Source.fetch_exchange_rates() do
        {:ok, coin} -> {:ok, false, add_coin_info_from_db(coin)}
        {:error, reason} -> {:error, false, reason}
      end
    end
  end

  defp fetch_rates_task(true) do
    fn ->
      case Source.fetch_secondary_exchange_rates() do
        {:ok, coin} -> {:ok, true, coin}
        {:error, reason} -> {:error, true, reason}
      end
    end
  end

  defp add_coin_info_from_db(tokens) do
    case Market.fetch_recent_history() do
      [today | _the_rest] ->
        tvl_from_history = Map.get(today, :tvl)

        tokens
        |> Enum.map(fn
          %Token{tvl_usd: nil} = token -> %{token | tvl_usd: tvl_from_history}
          token -> token
        end)

      _ ->
        tokens
    end
  end

  defp list_from_store(:ets) do
    table_name()
    |> :ets.tab2list()
    |> Enum.map(fn {_, coin} -> coin end)
    |> Enum.sort_by(fn %Token{symbol: symbol} -> symbol end)
  end

  defp list_from_store(_), do: []

  defp store do
    config(:store) || :ets
  end

  defp cache_period do
    Application.get_env(:explorer, __MODULE__, [])[:cache_period]
  end

  defp enabled? do
    Application.get_env(:explorer, __MODULE__, [])[:enabled] == true
  end

  defp consolidate? do
    Application.get_env(:explorer, __MODULE__, [])[:enable_consolidation]
  end

  defp secondary_coin_enabled? do
    Application.get_env(:explorer, __MODULE__, [])[:secondary_coin_enabled]
  end
end
