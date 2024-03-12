defmodule Explorer.Counters.TokenHoldersCounter do
  @moduledoc """
  Caches Token holders counter.
  """
  use GenServer

  alias Explorer.Chain
  alias Explorer.Chain.AddressCounter
  alias Explorer.Counters.Helper

  @cache_name :token_holders_count
  @last_update_key "last_update"
  @updated_at :updated_at

  config = Application.compile_env(:explorer, Explorer.Counters.TokenHoldersCounter)
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

    fetch_count_from_cache(address_hash)
  end

  def cache_name, do: @cache_name

  defp cache_expired?(address_hash) do
    cache_period = Application.get_env(:explorer, __MODULE__)[:cache_period]
    updated_at = fetch_updated_at_from_cache(address_hash)

    cond do
      is_nil(updated_at) -> true
      Helper.current_time() - updated_at > cache_period -> true
      true -> false
    end
  end

  defp update_cache(address_hash) do
    address_hash_string = to_string(address_hash)
    put_into_ets_cache("hash_#{address_hash_string}_#{@last_update_key}", Helper.current_time())
    new_data = Chain.count_token_holders_from_token_hash(address_hash)
    put_into_ets_cache("hash_#{address_hash_string}", new_data)
    put_into_db_cache(address_hash_string, new_data)
  end

  defp fetch_count_from_cache(address_hash) do
    address_hash_string = to_string(address_hash)
    key = "hash_#{address_hash_string}"

    Helper.fetch_from_ets_cache(key, @cache_name) || Helper.fetch_from_db_cache(address_hash, @cache_name)
  end

  defp fetch_updated_at_from_cache(address_hash) do
    address_hash_string = to_string(address_hash)
    key = "hash_#{address_hash_string}_#{@last_update_key}"

    Helper.fetch_from_ets_cache(key, @cache_name) || Helper.fetch_from_db_cache(address_hash, @updated_at)
  end

  defp put_into_ets_cache(key, value) do
    :ets.insert(@cache_name, {key, value})
  end

  defp put_into_db_cache(address_hash_string, counter) do
    AddressCounter.create(%{hash: address_hash_string, token_holders_count: counter})
  end

  defp create_cache_table do
    Helper.create_cache_table(@cache_name)
  end

  defp enable_consolidation?, do: @enable_consolidation
end
