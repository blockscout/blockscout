defmodule Explorer.Chain.Cache.TokenExchangeRate do
  @moduledoc """
  Caches Token USD exchange_rate.
  """
  use GenServer

  alias Explorer.ExchangeRates.Source

  @cache_name :token_exchange_rate
  @last_update_key "last_update"
  @cache_period Application.compile_env(:explorer, __MODULE__)[:period]

  @ets_opts [
    :set,
    :named_table,
    :public,
    read_concurrency: true
  ]

  config = Application.get_env(:explorer, Explorer.Chain.Cache.TokenExchangeRate)
  @enable_consolidation Keyword.get(config, :enable_consolidation)

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    create_cache_table()

    {:ok, %{consolidate?: enable_consolidation?()}, {:continue, :ok}}
  end

  @impl true
  def handle_continue(:ok, %{consolidate?: true} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_continue(:ok, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:consolidate, state) do
    {:noreply, state}
  end

  def cache_key(symbol, address_hash) do
    "token_symbol_exchange_rate_#{symbol}_#{address_hash_str_key(address_hash)}"
  end

  defp address_hash_str_key(address_hash) do
    Base.encode16(address_hash.bytes, case: :lower)
  end

  def fetch(symbol, address_hash) do
    if cache_expired?(symbol, address_hash) || value_is_empty?(symbol, address_hash) do
      Task.start_link(fn ->
        update_cache(symbol, address_hash)
      end)
    end

    fetch_from_cache(cache_key(symbol, address_hash))
  end

  def cache_name, do: @cache_name

  defp cache_expired?(symbol, address_hash) do
    updated_at = fetch_from_cache("#{cache_key(symbol, address_hash)}_#{@last_update_key}")

    cond do
      is_nil(updated_at) -> true
      current_time() - updated_at > @cache_period -> true
      true -> false
    end
  end

  defp value_is_empty?(symbol, address_hash) do
    value = fetch_from_cache(cache_key(symbol, address_hash))
    is_nil(value) || value == 0
  end

  defp update_cache(symbol, address_hash) do
    put_into_cache("#{cache_key(symbol, address_hash)}_#{@last_update_key}", current_time())

    exchange_rate = fetch_token_exchange_rate(symbol)

    IO.inspect("Show exchange_rate for symbol #{symbol}")
    IO.inspect(exchange_rate)

    put_into_cache(cache_key(symbol, address_hash), exchange_rate)
  end

  def fetch_token_exchange_rate(symbol) do
    case Source.fetch_exchange_rates_for_token(symbol) do
      {:ok, [rates]} ->
        rates.usd_value

      _ ->
        nil
    end
  end

  defp fetch_from_cache(key) do
    case :ets.lookup(@cache_name, key) do
      [{_, value}] ->
        value

      [] ->
        0
    end
  end

  def put_into_cache(key, value) do
    if cache_table_exists?() do
      :ets.insert(@cache_name, {key, value})
    end
  end

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end

  def cache_table_exists? do
    :ets.whereis(@cache_name) !== :undefined
  end

  def create_cache_table do
    unless cache_table_exists?() do
      :ets.new(@cache_name, @ets_opts)
    end
  end

  def enable_consolidation?, do: @enable_consolidation
end
