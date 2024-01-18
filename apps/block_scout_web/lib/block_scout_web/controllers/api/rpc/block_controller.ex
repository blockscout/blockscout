defmodule BlockScoutWeb.API.RPC.BlockController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Chain, as: ChainWeb
  alias Explorer.Chain
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Counters.AverageBlockTime
  alias Timex.Duration

  @doc """
  Reward for mining a block.

  The block reward is the sum of the following:

  * Sum of the transaction fees (gas_used * gas_price) for the block
  * A static reward for miner (this value may change during the life of the chain)
  * The reward for uncle blocks (1/32 * static_reward * number_of_uncles)
  """
  def getblockreward(conn, params) do
    with {:block_param, {:ok, unsafe_block_number}} <- {:block_param, Map.fetch(params, "blockno")},
         {:ok, block_number} <- ChainWeb.param_to_block_number(unsafe_block_number),
         {:ok, block} <-
           Chain.number_to_block(block_number,
             necessity_by_association: %{rewards: :optional},
             api?: true
           ) do
      render(conn, :block_reward, block: block)
    else
      {:block_param, :error} ->
        render(conn, :error, error: "Query parameter 'blockno' is required")

      {:error, :invalid} ->
        render(conn, :error, error: "Invalid block number")

      {:error, :not_found} ->
        render(conn, :error, error: "Block does not exist")
    end
  end

  def getblockcountdown(conn, params) do
    with {:block_param, {:ok, unsafe_target_block_number}} <- {:block_param, Map.fetch(params, "blockno")},
         {:ok, target_block_number} <- ChainWeb.param_to_block_number(unsafe_target_block_number),
         {:max_block, current_block_number} when not is_nil(current_block_number) <-
           {:max_block, BlockNumber.get_max()},
         {:average_block_time, average_block_time} when is_struct(average_block_time) <-
           {:average_block_time, AverageBlockTime.average_block_time()},
         {:remaining_blocks, remaining_blocks} when remaining_blocks > 0 <-
           {:remaining_blocks, target_block_number - current_block_number} do
      estimated_time_in_sec = Float.round(remaining_blocks * Duration.to_seconds(average_block_time), 1)

      render(conn, :block_countdown,
        current_block: current_block_number,
        countdown_block: target_block_number,
        remaining_blocks: remaining_blocks,
        estimated_time_in_sec: estimated_time_in_sec
      )
    else
      {:block_param, :error} ->
        render(conn, :error, error: "Query parameter 'blockno' is required")

      {:error, :invalid} ->
        render(conn, :error, error: "Invalid block number")

      {:average_block_time, {:error, :disabled}} ->
        render(conn, :error, error: "Average block time calculating is disabled, so getblockcountdown is not available")

      {stage, _} when stage in ~w(max_block average_block_time)a ->
        render(conn, :error, error: "Chain is indexing now, try again later")

      {:remaining_blocks, _} ->
        render(conn, :error, error: "Error! Block number already pass")
    end
  end

  def getblocknobytime(conn, params) do
    from_api = true

    with {:timestamp_param, {:ok, unsafe_timestamp}} <- {:timestamp_param, Map.fetch(params, "timestamp")},
         {:closest_param, {:ok, unsafe_closest}} <- {:closest_param, Map.fetch(params, "closest")},
         {:ok, timestamp} <- ChainWeb.param_to_block_timestamp(unsafe_timestamp),
         {:ok, closest} <- ChainWeb.param_to_block_closest(unsafe_closest),
         {:ok, block_number} <- Chain.timestamp_to_block_number(timestamp, closest, from_api) do
      render(conn, block_number: block_number)
    else
      {:timestamp_param, :error} ->
        render(conn, :error, error: "Query parameter 'timestamp' is required")

      {:closest_param, :error} ->
        render(conn, :error, error: "Query parameter 'closest' is required")

      {:error, :invalid_timestamp} ->
        render(conn, :error, error: "Invalid `timestamp` param")

      {:error, :invalid_closest} ->
        render(conn, :error, error: "Invalid `closest` param")

      {:error, :not_found} ->
        render(conn, :error, error: "Block does not exist")
    end
  end

  def eth_block_number(conn, params) do
    id = Map.get(params, "id", 1)
    max_block_number = BlockNumber.get_max()

    render(conn, :eth_block_number, number: max_block_number, id: id)
  end
end
