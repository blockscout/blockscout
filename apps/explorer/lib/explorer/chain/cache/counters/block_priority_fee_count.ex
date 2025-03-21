defmodule Explorer.Chain.Cache.Counters.BlockPriorityFeeCount do
  @moduledoc """
  Caches Block Priority Fee counter.
  """
  use GenServer
  use Utils.CompileTimeEnvHelper, enable_consolidation: [:explorer, [__MODULE__, :enable_consolidation]]

  alias Explorer.Chain
  alias Explorer.Chain.Cache.Counters.Helper

  @cache_name :block_priority_fee_counter

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

  def fetch(block_hash) do
    if does_not_exist?(block_hash) do
      update_cache(block_hash)
    end

    block_hash_string = get_block_hash_string(block_hash)
    fetch_from_cache("#{block_hash_string}")
  end

  def cache_name, do: @cache_name

  defp does_not_exist?(block_hash) do
    block_hash_string = get_block_hash_string(block_hash)
    :ets.lookup(@cache_name, "#{block_hash_string}") == []
  end

  defp update_cache(block_hash) do
    block_hash_string = get_block_hash_string(block_hash)
    new_data = Chain.block_to_priority_fee_of_1559_transactions(block_hash)
    Helper.put_into_ets_cache(@cache_name, "#{block_hash_string}", new_data)
  end

  defp fetch_from_cache(key) do
    Helper.fetch_from_ets_cache(@cache_name, key)
  end

  defp get_block_hash_string(block_hash) do
    Base.encode16(block_hash.bytes, case: :lower)
  end

  defp enable_consolidation?, do: @enable_consolidation
end
