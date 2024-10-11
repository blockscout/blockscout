defmodule Explorer.Chain.RollupReorgMonitorQueue do
  @moduledoc """
    A module containing (encapsulating) the reorg monitor queue and functions to manage it.
    Mostly used by the `Indexer.Fetcher.RollupL1ReorgMonitor` module.
  """

  alias Explorer.BoundQueue

  @doc """
    Pops the number of reorg block from the front of the queue for the specified rollup module.

    ## Parameters
    - `module`: The module for which the block number is popped from the queue.

    ## Returns
    - The popped block number.
    - `nil` if the reorg queue is empty.
  """
  @spec reorg_block_pop(module()) :: non_neg_integer() | nil
  def reorg_block_pop(module) do
    table_name = reorg_table_name(module)

    case BoundQueue.pop_front(reorg_queue_get(table_name)) do
      {:ok, {block_number, updated_queue}} ->
        :ets.insert(table_name, {:queue, updated_queue})
        block_number

      {:error, :empty} ->
        nil
    end
  end

  @doc """
    Pushes the number of reorg block to the back of the queue for the specified rollup module.

    ## Parameters
    - `block_number`: The reorg block number.
    - `module`: The module for which the block number is pushed to the queue.

    ## Returns
    - Nothing is returned.
  """
  @spec reorg_block_push(non_neg_integer(), module()) :: any()
  def reorg_block_push(block_number, module) do
    table_name = reorg_table_name(module)
    {:ok, updated_queue} = BoundQueue.push_back(reorg_queue_get(table_name), block_number)
    :ets.insert(table_name, {:queue, updated_queue})
  end

  # Reads a block number queue instance from the ETS table associated with the queue.
  # The table name depends on the module name and formed by the `reorg_table_name` function.
  #
  # ## Parameters
  # - `table_name`: The ETS table name of the queue.
  #
  # ## Returns
  # - `BoundQueue` instance for the queue. The queue may be empty (then %BoundQueue{} is returned).
  @spec reorg_queue_get(atom()) :: BoundQueue.t(any())
  defp reorg_queue_get(table_name) do
    if :ets.whereis(table_name) == :undefined do
      :ets.new(table_name, [
        :set,
        :named_table,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    with info when info != :undefined <- :ets.info(table_name),
         [{_, value}] <- :ets.lookup(table_name, :queue) do
      value
    else
      _ -> %BoundQueue{}
    end
  end

  # Forms an ETS table name for the block number queue for the given module name.
  #
  # ## Parameters
  # - `module`: The module name (instance) for which the ETS table name should be formed.
  #
  # ## Returns
  # - An atom defining the table name.
  #
  # sobelow_skip ["DOS.BinToAtom"]
  @spec reorg_table_name(module()) :: atom()
  defp reorg_table_name(module) do
    :"#{module}#{:_reorgs}"
  end
end
