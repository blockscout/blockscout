defmodule Explorer.Market.Fetcher.Coin do
  @moduledoc """
  Local cache for native coin exchange rates.

  Exchange rate data is updated every 10 minutes or MARKET_COIN_CACHE_PERIOD seconds.
  """

  use GenServer, restart: :transient

  require Logger

  alias Explorer.Chain.Events.Publisher
  alias Explorer.Market
  alias Explorer.Market.{Source, Token}

  @table_name :exchange_rates

  @type t() :: %__MODULE__{
          native_coin_source: module() | :ignored | nil,
          secondary_coin_source: module() | :ignored | nil
        }

  defstruct [:native_coin_source, :secondary_coin_source]

  @impl GenServer
  def init(_) do
    table_opts = [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ]

    if config(:store) == :ets do
      :ets.new(table_name(), table_opts)
    end

    native_coin_source = Source.native_coin_source()

    if is_nil(native_coin_source) do
      Logger.info("Native coin source is not configured")
    else
      send(self(), {:update, false})
    end

    secondary_coin_source = Source.secondary_coin_source()

    if is_nil(secondary_coin_source) do
      Logger.info("Secondary coin source is not configured")
    else
      send(self(), {:update, true})
    end

    if is_nil(native_coin_source) and is_nil(secondary_coin_source) do
      :ignore
    else
      {:ok, %__MODULE__{native_coin_source: native_coin_source, secondary_coin_source: secondary_coin_source}}
    end
  end

  @impl GenServer
  def handle_info({:update, secondary_coin?}, state) do
    fetch_rates(secondary_coin?, state)

    {:noreply, state}
  end

  # Callback for successful fetch
  @impl GenServer
  def handle_info({_ref, {{:ok, coin}, secondary_coin?}}, state) do
    coin = if secondary_coin?, do: coin, else: add_coin_info_from_db(coin)

    if config(:store) == :ets do
      :ets.insert(table_name(), {secondary_coin?, coin})
    end

    unless secondary_coin? do
      broadcast_event(:exchange_rate)
    end

    schedule_next_consolidation(secondary_coin?)

    {:noreply, state}
  end

  # Callback for errored fetch
  @impl GenServer
  def handle_info({_ref, {{:error, reason}, secondary_coin?}}, state) do
    Logger.warning(fn ->
      "Failed to get #{Source.secondary_coin_string(secondary_coin?)} exchange rates with reason '#{reason}'."
    end)

    schedule_next_consolidation(secondary_coin?)

    {:noreply, state}
  end

  # Callback for not implemented fetch
  @impl GenServer
  def handle_info({_ref, {:ignore, secondary_coin?}}, state) do
    Logger.warning(
      "Configured #{Source.secondary_coin_string(secondary_coin?)} source does not implement coin fetching"
    )

    state =
      if secondary_coin? do
        %{state | secondary_coin_source: :ignored}
      else
        %{state | native_coin_source: :ignored}
      end

    if state.native_coin_source == :ignored and state.secondary_coin_source == :ignored do
      {:stop, :shutdown, state}
    else
      {:noreply, state}
    end
  end

  # Callback that a monitored process has shutdown
  @impl GenServer
  def handle_info({:DOWN, _, :process, _, _}, state) do
    {:noreply, state}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  defp schedule_next_consolidation(secondary_coin?) do
    if config(:enable_consolidation) do
      Process.send_after(self(), {:update, secondary_coin?}, config(:cache_period))
    end
  end

  @doc """
  Retrieves the primary coin exchange rate from the ETS table.

  This function fetches the primary exchange rate data for the token from the ETS
  table if the store is configured to use ETS and the functionality is enabled.

  ## Returns
  - A `Token.t()` struct containing the coin exchange rate data if found
  - `nil` if no data is found or if the store is not configured properly
  """
  @spec get_coin_exchange_rate() :: Token.t() | nil
  def get_coin_exchange_rate do
    do_get_coin_exchange_rate(false)
  end

  @doc """
  Retrieves the secondary coin exchange rate from the ETS table.

  This function fetches the secondary exchange rate data for the token from the
  ETS table if the store is configured to use ETS and the functionality is
  enabled.

  ## Returns
  - A `Token.t()` struct containing the secondary coin exchange rate data if found
  - `nil` if no data is found or if the store is not configured properly
  """
  @spec get_secondary_coin_exchange_rate() :: Token.t() | nil
  def get_secondary_coin_exchange_rate do
    do_get_coin_exchange_rate(true)
  end

  defp do_get_coin_exchange_rate(secondary_coin?) do
    if config(:store) == :ets && config(:enabled) && :ets.whereis(table_name()) != :undefined do
      case :ets.lookup(table_name(), secondary_coin?) do
        [{_, coin} | _] -> coin
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

  @spec config(atom()) :: term()
  defp config(key) do
    Application.get_env(:explorer, __MODULE__, [])[key]
  end

  @spec fetch_rates(boolean(), t()) :: Task.t()
  defp fetch_rates(false, state) do
    if state.native_coin_source do
      Task.Supervisor.async_nolink(
        Explorer.MarketTaskSupervisor,
        fn -> {state.native_coin_source.fetch_native_coin(), false} end
      )
    end
  end

  defp fetch_rates(true, state) do
    if state.secondary_coin_source do
      Task.Supervisor.async_nolink(Explorer.MarketTaskSupervisor, fn ->
        {state.secondary_coin_source.fetch_secondary_coin(), true}
      end)
    end
  end

  defp add_coin_info_from_db(coin) do
    case Market.fetch_recent_history() do
      [today | _the_rest] ->
        tvl_from_history = Map.get(today, :tvl)

        case coin do
          %Token{tvl: nil} = coin -> %{coin | tvl: tvl_from_history}
          coin -> coin
        end

      _ ->
        coin
    end
  end
end
