defmodule BlockScoutWeb.API.RPC.BlockController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Chain, as: ChainWeb
  alias Explorer.Chain
  alias Explorer.Chain.Block.Reader.General, as: BlockGeneralReader
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Cache.Counters.AverageBlockTime
  alias Timex.Duration

  @doc """
  Calculates the total reward for mining a specific block.

  ## Parameters
    - conn: Plug.Conn struct.
    - params: A map containing the query parameters which should include:
      - `blockno`: The number of the block for which to calculate the reward.

  ## Description
  This function computes the block reward, which consists of:
    - The sum of the transaction fees (gas_used * gas_price) for the block.
    - A static reward for the miner, which may vary over the blockchain's lifespan.
    - The reward for uncle blocks calculated as (1/32 * static_reward * number_of_uncles).

  ## Responses
    - On success: Renders a JSON response with the reward details for the block.
    - On failure: Renders an error response with an appropriate message due to:
      - Absence of the `blockno` parameter.
      - Invalid `blockno` parameter.
      - Non-existence of the specified block.
  """
  @spec getblockreward(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  @doc """
  Calculates and renders the estimated time until a target block number is reached.

  ## Parameters
    - conn: Plug.Conn struct.
    - params: A map containing the query parameters which should include:
      - `blockno`: The target block number to countdown to.

  ## Description
  This function takes a target block number from the `params` map and calculates the remaining time in seconds until that block is reached, considering the current maximum block number and the average block time.

  ## Responses
    - On success: Renders a view with the countdown information including the current block number, target block number, the number of remaining blocks, and the estimated time in seconds until the target block number is reached.
    - On failure: Renders an error view with an appropriate message, which could be due to:
      - Missing `blockno` parameter.
      - Invalid block number provided.
      - Average block time calculation being disabled.
      - Chain is currently indexing and cannot provide the information.
      - The target block number has already been passed.
  """
  @spec getblockcountdown(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  @doc """
  Retrieves the block number associated with a given timestamp and closest policy.

  ## Parameters
    - conn: Plug.Conn struct.
    - params: A map containing the query parameters which should include:
      - `timestamp`: The timestamp to query the block number for.
      - `closest`: The policy to determine which block number to return. It could be a value like 'before' or 'after' to indicate whether the closest block before or after the given timestamp should be returned.

  ## Description
  This function finds the block number that is closest to a specific timestamp according to the provided 'closest' policy.

  ## Responses
    - On success: Renders a JSON response with the found block number.
    - On failure: Renders an error response with an appropriate message, which could be due to:
      - Missing `timestamp` parameter.
      - Missing `closest` parameter.
      - Invalid `timestamp` parameter.
      - Invalid `closest` parameter.
      - No block corresponding to the given timestamp and closest policy.
  """
  @spec getblocknobytime(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def getblocknobytime(conn, params) do
    from_api = true

    with {:timestamp_param, {:ok, unsafe_timestamp}} <- {:timestamp_param, Map.fetch(params, "timestamp")},
         {:closest_param, {:ok, unsafe_closest}} <- {:closest_param, Map.fetch(params, "closest")},
         {:ok, timestamp} <- ChainWeb.param_to_block_timestamp(unsafe_timestamp),
         {:ok, closest} <- ChainWeb.param_to_block_closest(unsafe_closest),
         {:ok, block_number} <- BlockGeneralReader.timestamp_to_block_number(timestamp, closest, from_api) do
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

  @doc """
  Fetches the highest block number from the chain.

  ## Parameters
    - conn: Plug.Conn struct.
    - params: A map containing the query parameters which may include:
      - `id`: An optional parameter that defaults to 1 if not provided.

  ## Description
  This function retrieves the maximum block number that has been recorded in the blockchain.

  ## Responses
    - Renders a JSON response including the maximum block number and the provided or default `id`.
  """
  @spec eth_block_number(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def eth_block_number(conn, params) do
    id = Map.get(params, "id", 1)
    max_block_number = BlockNumber.get_max()

    render(conn, :eth_block_number, number: max_block_number, id: id)
  end
end
