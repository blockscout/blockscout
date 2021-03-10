defmodule Explorer.Chain.Cache.TokenExchangeRate do
  @moduledoc """
  Caches Token USD exchange_rate.
  """
  use GenServer

  import Ecto.Query, only: [from: 2]

  alias Ecto.Changeset
  alias Explorer.Chain.BridgedToken
  alias Explorer.ExchangeRates.Source
  alias Explorer.Repo

  @cache_name :token_exchange_rate
  @last_update_key "last_update"

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

  def cache_key(symbol) do
    "token_symbol_exchange_rate_#{symbol}"
  end

  def fetch(token_hash, symbol) do
    if cache_expired?(symbol) || value_is_empty?(symbol) do
      Task.start_link(fn ->
        update_cache(token_hash, symbol)
      end)
    end

    cached_value = fetch_from_cache(cache_key(symbol))

    if is_nil(cached_value) || Decimal.cmp(cached_value, 0) == :eq do
      fetch_from_db(token_hash)
    else
      cached_value
    end
  end

  def cache_name, do: @cache_name

  defp cache_expired?(symbol) do
    cache_period = token_exchange_rate_cache_period()
    updated_at = fetch_from_cache("#{cache_key(symbol)}_#{@last_update_key}")

    cond do
      is_nil(updated_at) -> true
      current_time() - updated_at > cache_period -> true
      true -> false
    end
  end

  defp value_is_empty?(symbol) do
    value = fetch_from_cache(cache_key(symbol))
    is_nil(value) || value == 0
  end

  defp update_cache(token_hash, symbol) do
    put_into_cache("#{cache_key(symbol)}_#{@last_update_key}", current_time())

    exchange_rate = fetch_token_exchange_rate(symbol)

    put_into_db(token_hash, exchange_rate)
    put_into_cache(cache_key(symbol), exchange_rate)
  end

  def fetch_token_exchange_rate(symbol) do
    case Source.fetch_exchange_rates_for_token(symbol) do
      {:ok, [rates]} ->
        rates.usd_value

      _ ->
        nil
    end
  end

  def fetch_token_exchange_rate_by_address(address_hash_str) do
    case Source.fetch_exchange_rates_for_token_address(address_hash_str) do
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

  defp fetch_from_db(nil), do: nil

  defp fetch_from_db(token_hash) do
    token = get_token(token_hash)

    if token do
      token.exchange_rate
    else
      nil
    end
  end

  def put_into_cache(key, value) do
    if cache_table_exists?() do
      :ets.insert(@cache_name, {key, value})
    end
  end

  def put_into_db(token_hash, exchange_rate) do
    token = get_token(token_hash)

    if token && !is_nil(exchange_rate) do
      token
      |> Changeset.change(%{exchange_rate: exchange_rate})
      |> Repo.update()
    end
  end

  defp get_token(token_hash) do
    query =
      from(bt in BridgedToken,
        where: bt.home_token_contract_address_hash == ^token_hash
      )

    query
    |> Repo.one()
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

  defp token_exchange_rate_cache_period do
    case Integer.parse(System.get_env("TOKEN_EXCHANGE_RATE_CACHE_PERIOD", "")) do
      {secs, ""} -> :timer.seconds(secs)
      _ -> :timer.hours(1)
    end
  end
end
