defmodule Explorer.ExchangeRates do
  @moduledoc """
  Local cache for token exchange rates.

  Exchange rate data is updated every 5 minutes.
  """

  use GenServer

  require Logger

  alias Explorer.ExchangeRates.Token

  @interval :timer.minutes(5)
  @table_name :exchange_rates

  ## GenServer functions

  @impl GenServer
  def handle_info(:update, state) do
    Logger.debug(fn -> "Updating cached exchange rates" end)

    fetch_rates()

    {:noreply, state}
  end

  # Callback for successful fetch
  @impl GenServer
  def handle_info({_ref, {:ok, tokens}}, state) do
    records =
      for %Token{symbol: symbol} = token <- tokens do
        {symbol, token}
      end

    if store() == :ets, do: :ets.insert(table_name(), records)

    {:noreply, state}
  end

  # Callback for errored fetch
  @impl GenServer
  def handle_info({_ref, {:error, reason}}, state) do
    Logger.warn(fn -> "Failed to get exchange rates with reason '#{reason}'." end)

    fetch_rates()

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
    :timer.send_interval(@interval, :update)

    table_opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    if store() == :ets, do: :ets.new(table_name(), table_opts)

    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Public functions

  @doc """
  Lists exchange rates for the tracked tickers.
  """
  @spec list :: [Token.t()]
  def list do
    list_from_store(store())
  end

  ## Undocumented public functions

  @doc false
  @spec table_name() :: atom()
  def table_name, do: @table_name

  ## Private functions

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  @spec exchange_rates_source() :: module()
  defp exchange_rates_source do
    config(:source) || Explorer.ExchangeRates.Source.CoinMarketCap
  end

  @spec fetch_rates :: Task.t()
  defp fetch_rates do
    Task.Supervisor.async_nolink(Explorer.MarketTaskSupervisor, fn ->
      exchange_rates_source().fetch_exchange_rates()
    end)
  end

  defp list_from_store(:ets) do
    table_name()
    |> :ets.tab2list()
    |> Enum.map(fn {_, rate} -> rate end)
    |> Enum.sort_by(fn %Token{symbol: symbol} -> symbol end)
  end

  defp list_from_store(_), do: []

  defp store do
    config(:store) || :ets
  end
end
