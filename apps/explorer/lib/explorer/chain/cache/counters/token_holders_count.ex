defmodule Explorer.Chain.Cache.Counters.TokenHoldersCount do
  @moduledoc """
  Caches Token holders count.
  """
  use GenServer
  use Utils.CompileTimeEnvHelper, enable_consolidation: [:explorer, [__MODULE__, :enable_consolidation]]

  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Cache.Counters.Helper
  alias Explorer.Chain.Token

  @api_true [api?: true]
  @cache_name :token_holders_count
  @ets_last_update_key "last_update"

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Helper.create_cache_table(@cache_name)

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
      Task.start_link(fn ->
        update_cache(address_hash)
      end)
    end

    fetch_count_from_cache(address_hash)
  end

  def cache_name, do: @cache_name

  defp cache_expired?(address_hash) do
    cache_period = Application.get_env(:explorer, __MODULE__)[:cache_period]
    updated_at = fetch_updated_at_from_cache(address_hash, @cache_name)

    cond do
      is_nil(updated_at) -> true
      Helper.current_time() - updated_at > cache_period -> true
      true -> false
    end
  end

  defp update_cache(address_hash) do
    address_hash_string = to_string(address_hash)
    new_data = CurrentTokenBalance.count_token_holders_from_token_hash(address_hash)
    Helper.put_into_ets_cache(@cache_name, "hash_#{address_hash_string}", new_data)
    Helper.put_into_ets_cache(@cache_name, "hash_#{address_hash_string}_#{@ets_last_update_key}", Helper.current_time())
    put_into_db_cache(address_hash, new_data)
  end

  def fetch_count_from_cache(address_hash) do
    address_hash_string = to_string(address_hash)
    key = "hash_#{address_hash_string}"

    Helper.fetch_from_ets_cache(@cache_name, key) || fetch_from_db_cache(address_hash)
  end

  def fetch_updated_at_from_cache(address_hash, cache_name) do
    address_hash_string = to_string(address_hash)
    key = "hash_#{address_hash_string}_#{@ets_last_update_key}"

    Helper.fetch_from_ets_cache(cache_name, key)
  end

  def fetch_from_db_cache(address_hash) do
    token = Token.get_by_contract_address_hash(address_hash, @api_true)
    token.holder_count || 0
  end

  def put_into_db_cache(address_hash, count) do
    Token.update_token_holder_count(address_hash, count)
  end

  defp enable_consolidation?, do: @enable_consolidation
end
