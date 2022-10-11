defmodule Explorer.Counters.TokenHoldersCounter do
  @moduledoc """
  Caches Token holders counter.
  """
  use GenServer

  alias Explorer.Chain

  @cache_name :token_holders_counter
  @last_update_key "last_update"

  @ets_opts [
    :set,
    :named_table,
    :public,
    read_concurrency: true
  ]

  config = Application.get_env(:explorer, Explorer.Counters.TokenHoldersCounter)
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

  def fetch(address_hash) do
    if cache_expired?(address_hash) do
      update_cache(address_hash)
    end

    address_hash_string = to_string(address_hash)
    fetch_from_cache("hash_#{address_hash_string}")
  end

  def cache_name, do: @cache_name

  defp cache_expired?(address_hash) do
    cache_period = token_holders_counter_cache_period()
    address_hash_string = to_string(address_hash)
    updated_at = fetch_from_cache("hash_#{address_hash_string}_#{@last_update_key}")

    cond do
      is_nil(updated_at) -> true
      current_time() - updated_at > cache_period -> true
      true -> false
    end
  end

  defp update_cache(address_hash) do
    address_hash_string = to_string(address_hash)
    put_into_cache("hash_#{address_hash_string}_#{@last_update_key}", current_time())
    new_data = Chain.count_token_holders_from_token_hash(address_hash)
    put_into_cache("hash_#{address_hash_string}", new_data)
  end

  defp fetch_from_cache(key) do
    case :ets.lookup(@cache_name, key) do
      [{_, value}] ->
        value

      [] ->
        0
    end
  end

  defp put_into_cache(key, value) do
    :ets.insert(@cache_name, {key, value})
  end

  defp current_time do
    utc_now = DateTime.utc_now()

    DateTime.to_unix(utc_now, :millisecond)
  end

  def create_cache_table do
    if :ets.whereis(@cache_name) == :undefined do
      :ets.new(@cache_name, @ets_opts)
    end
  end

  def enable_consolidation?, do: @enable_consolidation

  defp token_holders_counter_cache_period do
    case Integer.parse(System.get_env("TOKEN_HOLDERS_COUNTER_CACHE_PERIOD", "")) do
      {secs, ""} -> :timer.seconds(secs)
      _ -> :timer.hours(1)
    end
  end
end
