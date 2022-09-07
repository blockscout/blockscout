defmodule Explorer.Counters.BlockPriorityFeeCounter do
  @moduledoc """
  Caches Block Burned Fee counter.
  """
  use GenServer

  alias Explorer.Chain

  @cache_name :block_priority_fee_counter

  @ets_opts [
    :set,
    :named_table,
    :public,
    read_concurrency: true
  ]

  config = Application.get_env(:explorer, Explorer.Counters.BlockPriorityFeeCounter)
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
    new_data = Chain.block_to_priority_fee_of_1559_txs(block_hash)
    put_into_cache("#{block_hash_string}", new_data)
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

  defp get_block_hash_string(block_hash) do
    Base.encode16(block_hash.bytes, case: :lower)
  end

  def create_cache_table do
    if :ets.whereis(@cache_name) == :undefined do
      :ets.new(@cache_name, @ets_opts)
    end
  end

  def enable_consolidation?, do: @enable_consolidation
end
