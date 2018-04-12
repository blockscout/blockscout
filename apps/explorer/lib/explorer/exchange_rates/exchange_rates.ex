defmodule Explorer.ExchangeRates do
  @moduledoc """
  Local cache for relevant exchange rates.

  Exchange rate data is updated every 5 minutes.
  """

  use GenServer

  require Logger

  alias Explorer.ExchangeRates.Rate

  @default_tickers ~w(poa-network)
  @interval :timer.minutes(5)
  @table_name :exchange_rates

  ## GenServer functions

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    send(self(), :update)
    :timer.send_interval(@interval, :update)

    table_opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    :ets.new(table_name(), table_opts)

    {:ok, %{}}
  end

  def handle_info(:update, state) do
    Logger.debug(fn -> "Updating cached exchange rates" end)

    for ticker <- @default_tickers do
      fetch_ticker(ticker)
    end

    {:noreply, state}
  end

  # Callback for successful ticker fetch
  def handle_info({_ref, {ticker, {:ok, %Rate{} = rate}}}, state) do
    :ets.insert(table_name(), {ticker, rate})

    {:noreply, state}
  end

  # Callback for errored ticker fetch
  def handle_info({_ref, {ticker, {:error, reason}}}, state) do
    Logger.warn(fn ->
      "Failed to get exchange rates for ticker '#{ticker}' with reason '#{reason}'."
    end)

    fetch_ticker(ticker)

    {:noreply, state}
  end

  # Callback that a monitored process has shutdown
  def handle_info({:DOWN, _, :process, _, _}, state) do
    {:noreply, state}
  end

  ## Public functions

  @doc """
  Lists exchange rates for the tracked tickers.
  """
  @spec all_tickers() :: [Rate.t()]
  def all_tickers do
    table_name()
    |> :ets.tab2list()
    |> Enum.map(fn {_, rate} -> rate end)
    |> Enum.sort_by(fn %Rate{ticker_symbol: ticker_symbol} -> ticker_symbol end)
  end

  ## Undocumented public functions

  @doc false
  @spec table_name() :: atom()
  def table_name, do: @table_name

  ## Private functions

  @spec fetch_ticker(String.t()) :: Task.t()
  defp fetch_ticker(ticker) do
    Task.Supervisor.async_nolink(Explorer.ExchangeRateTaskSupervisor, fn ->
      {ticker, ticker_source().fetch_exchange_rate(ticker)}
    end)
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  @spec ticker_source() :: module()
  defp ticker_source do
    config(:source) || Explorer.ExchangeRates.Source.CoinMarketCap
  end
end
