defmodule Explorer.Chain.Cache.TransactionActionUniswapPools do
  @moduledoc """
  Caches Uniswap pools for Indexer.Transform.TransactionActions.
  """
  use GenServer

  @cache_name :transaction_actions_uniswap_pools_cache

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    create_cache_table()
    {:ok, %{}}
  end

  def create_cache_table do
    if :ets.whereis(@cache_name) == :undefined do
      :ets.new(@cache_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end
  end

  def fetch_from_cache(pool_address) do
    with info when info != :undefined <- :ets.info(@cache_name),
         [{_, value}] <- :ets.lookup(@cache_name, pool_address) do
      value
    else
      _ -> nil
    end
  end

  def put_to_cache(address, value) do
    :ets.insert(@cache_name, {address, value})
  end
end
