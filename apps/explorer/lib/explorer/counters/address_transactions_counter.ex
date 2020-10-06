defmodule Explorer.Counters.AddressTransactionsCounter do
  @moduledoc """
  Caches Address transactions counter.
  """
  use GenServer

  alias Explorer.Chain

  @cache_name :address_transactions_counter
  @last_update_key "last_update"
  @cache_period Application.get_env(:explorer, __MODULE__)[:period]

  @ets_opts [
    :set,
    :named_table,
    :public,
    read_concurrency: true
  ]

  config = Application.get_env(:explorer, Explorer.Counters.AddressesCounter)
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

  def fetch(address) do
    if cache_expired?() do
      Task.start_link(fn ->
        update_cache(address)
      end)
    end

    address_hash_string = get_address_hash_string(address)
    fetch_from_cache("hash_#{address_hash_string}")
  end

  def cache_name, do: @cache_name

  def updated_at_key, do: @last_update_key

  defp cache_expired? do
    updated_at = fetch_from_cache(@last_update_key)

    cond do
      is_nil(updated_at) -> true
      current_time() - updated_at > @cache_period -> true
      true -> false
    end
  end

  defp update_cache(address) do
    new_data = Chain.address_to_transaction_count(address)
    address_hash_string = get_address_hash_string(address)
    put_into_cache(@last_update_key, current_time())
    put_into_cache("hash_#{address_hash_string}", new_data)
  end

  defp fetch_from_cache(key) do
    case :ets.lookup(@cache_name, key) do
      [{_, value}] ->
        value

      [] ->
        nil
    end
  end

  defp put_into_cache(key, value) do
    :ets.insert(@cache_name, {key, value})
  end

  defp get_address_hash_string(address) do
    Base.encode16(address.hash.bytes, case: :lower)
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
end
