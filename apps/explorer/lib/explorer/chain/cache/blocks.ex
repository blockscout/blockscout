defmodule Explorer.Chain.Cache.Blocks do
  @moduledoc """
  Caches the last imported blocks
  """

  alias Explorer.Chain.Block

  use Explorer.Chain.OrderedCache,
    name: :blocks,
    max_size: 60,
    ids_list_key: "block_numbers",
    preload: :transactions,
    preload: [miner: :names],
    preload: :rewards,
    ttl_check_interval: Application.get_env(:explorer, __MODULE__)[:ttl_check_interval],
    global_ttl: Application.get_env(:explorer, __MODULE__)[:global_ttl]

  @type element :: Block.t()

  @type id :: non_neg_integer()

  def element_to_id(%Block{number: number}), do: number

  def drop_nonconsensus(numbers) when is_nil(numbers) or numbers == [], do: :ok

  def drop_nonconsensus(numbers) when is_list(numbers) do
    ConCache.update(cache_name(), ids_list_key(), fn ids ->
      nonconsensus = MapSet.new(numbers)

      {lost_consensus, kept_consensus} = Enum.split_with(ids, &MapSet.member?(nonconsensus, &1))

      # immediately delete the blocks that lost consensus
      Enum.each(lost_consensus, &ConCache.delete(cache_name(), &1))

      # ids_list is set to never expire
      {:ok, %ConCache.Item{value: kept_consensus, ttl: :infinity}}
    end)
  end

  def drop_nonconsensus(number) when not is_nil(number), do: drop_nonconsensus([number])

  @doc """
  Prepares a block for cache update by aggregating transaction metrics and clearing the transactions list.

  This function ensures that all transaction-related statistics are calculated
  and stored in the block's virtual fields before removing the transactions
  list. This optimization allows the block to retain computed aggregate data
  while eliminating the need to store redundant transaction references that
  are maintained separately in the database.

  The function first triggers transaction aggregation to compute metrics such
  as transaction counts, total fees, burnt fees, and priority fees. After
  aggregation is complete, the transactions list is cleared to reduce memory
  usage.

  ## Parameters
  - `block`: A Block struct that may contain transactions to be aggregated

  ## Returns
  - Block struct with aggregated transaction metrics and an empty transactions list
  """
  @spec sanitize_before_update(Block.t()) :: Block.t()
  def sanitize_before_update(block) do
    block = Block.aggregate_transactions(block)

    %{block | transactions: []}
  end
end
