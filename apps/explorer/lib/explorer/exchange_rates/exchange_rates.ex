defmodule Explorer.ExchangeRates do
  @moduledoc """
  Local cache for token exchange rates.

  Exchange rate data is updated every 5 minutes.
  """

  use GenServer

  require Logger

  alias Explorer.ExchangeRates.{Source, Token}

  @interval :timer.minutes(5)
  @table_name :exchange_rates

  @impl GenServer
  def handle_info(:update, state) do
    Logger.debug(fn -> "Updating cached exchange rates" end)

    fetch_rates()

    {:noreply, state}
  end

  # Callback for successful fetch
  @impl GenServer
  def handle_info({_ref, {:ok, tokens}}, state) do
    if store() == :ets do
      records = Enum.map(tokens, &Token.to_tuple/1)
      :ets.insert(table_name(), records)
    end

    broadcast_event(:exchange_rate)

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

    if store() == :ets do
      :ets.new(table_name(), table_opts)
    end

    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Lists exchange rates for the tracked tickers.
  """
  @spec list :: [Token.t()]
  def list do
    list_from_store(store())
  end

  @doc """
  Returns a specific rate from the tracked tickers by symbol
  """
  @spec lookup(String.t()) :: Token.t() | nil
  def lookup(symbol) do
    if store() == :ets do
      case :ets.lookup(table_name(), symbol) do
        [tuple | _] when is_tuple(tuple) -> Token.from_tuple(tuple)
        _ -> nil
      end
    end
  end

  @doc false
  @spec table_name() :: atom()
  def table_name, do: @table_name

  @spec broadcast_event(atom()) :: :ok
  defp broadcast_event(event_type) do
    Registry.dispatch(Registry.ChainEvents, event_type, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, {:chain_event, event_type})
      end
    end)
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  @spec fetch_rates :: Task.t()
  defp fetch_rates do
    Task.Supervisor.async_nolink(Explorer.MarketTaskSupervisor, fn ->
      Source.fetch_exchange_rates()
    end)
  end

  defp list_from_store(:ets) do
    table_name()
    |> :ets.tab2list()
    |> Enum.map(&Token.from_tuple/1)
    |> Enum.sort_by(fn %Token{symbol: symbol} -> symbol end)
  end

  defp list_from_store(_), do: []

  defp store do
    config(:store) || :ets
  end
end
