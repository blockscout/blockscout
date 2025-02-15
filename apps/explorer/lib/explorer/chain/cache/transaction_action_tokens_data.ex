defmodule Explorer.Chain.Cache.TransactionActionTokensData do
  @moduledoc """
  Caches tokens data for Indexer.Transform.TransactionActions.
  """
  use GenServer

  @cache_name :transaction_actions_tokens_data_cache

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

  def fetch_from_cache(address) do
    with info when info != :undefined <- :ets.info(@cache_name),
         [{_, value}] <- :ets.lookup(@cache_name, address) do
      value
    else
      _ -> %{symbol: nil, decimals: nil}
    end
  end

  def put_to_cache(address, data) do
    if not :ets.member(@cache_name, address) do
      # we need to add a new item to the cache, but don't exceed the limit
      cache_size = :ets.info(@cache_name, :size)

      how_many_to_remove = cache_size - get_max_token_cache_size() + 1

      range = Range.new(1, how_many_to_remove, 1)

      for _step <- range do
        :ets.delete(@cache_name, :ets.first(@cache_name))
      end
    end

    :ets.insert(@cache_name, {address, data})
  end

  defp get_max_token_cache_size do
    Application.get_env(:explorer, __MODULE__)[:max_cache_size]
  end
end
