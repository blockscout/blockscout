defmodule Explorer.Counters.Bridge do
  @moduledoc """
  Caches the prices of bridged tokens.

  It loads the count asynchronously and in a time interval of 30 minutes.
  """

  use GenServer

  alias Explorer.Chain.Supply.TokenBridge

  @prices_table :omni_bridge_bridged_tokens_prices
  @bridges_table :bridges_market_cap

  @current_total_supply_from_token_bridge_cache_key "current_total_supply_from_token_bridge"
  @current_market_cap_from_omni_bridge_cache_key "current_market_cap_from_omni_bridge"

  @ets_opts [
    :set,
    :named_table,
    :public,
    read_concurrency: true
  ]

  def price_cache_key(symbol) do
    "token_symbol_price_#{symbol}"
  end

  # It is undesirable to automatically start the consolidation in all environments.
  # Consider the test environment: if the consolidation initiates but does not
  # finish before a test ends, that test will fail. This way, hundreds of
  # tests were failing before disabling the consolidation and the scheduler in
  # the test env.
  config = Application.get_env(:explorer, Explorer.Counters.Bridge)
  @enable_consolidation Keyword.get(config, :enable_consolidation)

  @update_interval_in_seconds Keyword.get(config, :update_interval_in_seconds)

  @doc """
  Starts a process to periodically update bridges marketcaps.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    create_tables()

    {:ok, %{consolidate?: enable_consolidation?()}, {:continue, :ok}}
  end

  def create_prices_table do
    if :ets.whereis(@prices_table) == :undefined do
      :ets.new(@prices_table, @ets_opts)
    end
  end

  def create_bridges_table do
    if :ets.whereis(@bridges_table) == :undefined do
      :ets.new(@bridges_table, @ets_opts)
    end
  end

  def create_tables do
    create_prices_table()
    create_bridges_table()
  end

  defp schedule_next_consolidation do
    Process.send_after(self(), :consolidate, :timer.seconds(@update_interval_in_seconds))
  end

  @doc """
  Inserts new bridged token price into the `:ets` table.
  """
  def insert_price({key, info}) do
    :ets.insert(@prices_table, {key, info})
  end

  @impl true
  def handle_continue(:ok, %{consolidate?: true} = state) do
    consolidate()
    schedule_next_consolidation()

    {:noreply, state}
  end

  @impl true
  def handle_continue(:ok, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:consolidate, state) do
    consolidate()
    schedule_next_consolidation()

    {:noreply, state}
  end

  @doc """
  Fetches the info for a specific item from the `:ets` table.
  """
  def fetch_token_price(symbol) do
    create_prices_table()
    do_fetch_token_price(:ets.lookup(@prices_table, price_cache_key(symbol)))
  end

  defp do_fetch_token_price([{_, result}]), do: result
  defp do_fetch_token_price([]), do: 0

  def fetch_token_bridge_total_supply do
    create_bridges_table()
    do_fetch_token_bridge_total_supply(:ets.lookup(@bridges_table, @current_total_supply_from_token_bridge_cache_key))
  end

  defp do_fetch_token_bridge_total_supply([{_, result}]), do: result

  defp do_fetch_token_bridge_total_supply([]) do
    update_total_supply_from_token_bridge_cache()
  end

  def fetch_omni_bridge_market_cap do
    create_bridges_table()
    do_fetch_omni_bridge_market_cap(:ets.lookup(@bridges_table, @current_market_cap_from_omni_bridge_cache_key))
  end

  defp do_fetch_omni_bridge_market_cap([{_, result}]), do: result

  defp do_fetch_omni_bridge_market_cap([]) do
    update_total_omni_bridge_market_cap_cache()
  end

  defp update_total_supply_from_token_bridge_cache do
    current_total_supply_from_token_bridge = TokenBridge.get_current_total_supply_from_token_bridge()

    :ets.insert(
      @bridges_table,
      {@current_total_supply_from_token_bridge_cache_key, current_total_supply_from_token_bridge}
    )

    current_total_supply_from_token_bridge
  end

  defp update_total_omni_bridge_market_cap_cache do
    current_total_supply_from_omni_bridge = TokenBridge.get_current_market_cap_from_omni_bridge()

    :ets.insert(
      @bridges_table,
      {@current_market_cap_from_omni_bridge_cache_key, current_total_supply_from_omni_bridge}
    )

    current_total_supply_from_omni_bridge
  end

  @doc """
  Consolidates the info by populating the `:ets` table with the current database information.
  """
  def consolidate do
    bridged_mainnet_tokens_list = TokenBridge.get_bridged_mainnet_tokens_list()

    bridged_mainnet_tokens_list
    |> Enum.each(fn {_bridged_token_hash, bridged_token_symbol} ->
      bridged_token_price = TokenBridge.get_current_price_for_bridged_token(bridged_token_symbol)
      insert_price({price_cache_key(bridged_token_symbol), bridged_token_price})
    end)

    update_total_supply_from_token_bridge_cache()
    update_total_omni_bridge_market_cap_cache()
  end

  @doc """
  Returns a boolean that indicates whether consolidation is enabled

  In order to choose whether or not to enable the scheduler and the initial
  consolidation, change the following Explorer config:

  `config :explorer, Explorer.Counters.Bridge, enable_consolidation: true`

  to:

  `config :explorer, Explorer.Counters.Bridge, enable_consolidation: false`
  """
  def enable_consolidation?, do: @enable_consolidation
end
