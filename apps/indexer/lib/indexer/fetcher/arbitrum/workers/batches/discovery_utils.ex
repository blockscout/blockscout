defmodule Indexer.Fetcher.Arbitrum.Workers.Batches.DiscoveryUtils do
  @moduledoc """
  Provides utility functions for batch discovery in Arbitrum rollups.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  alias Explorer.Chain.Arbitrum

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc

  require Logger

  @doc """
    Determines the block range for a batch using either message counts or neighboring batch information.

    Depending on the parameters passed, the function will determine the block
    range for a batch in one of two ways:

    1. Modern batches with message counts from transaction calldata:
      - Message counts are extracted from the contract call data of batch
        submission transactions on L1
      - These counts typically correspond directly to L2 block numbers
      - A shift value may be applied for specific chains (e.g., ArbitrumOne)

    2. Legacy batches from the old `SequencerInbox` contract:
      - No message counts are available in the transaction calldata
      - Block ranges are determined by analyzing neighboring batches
      - Binary search is used to find the opposite block when only one neighbor
        is already indexed

    ## Parameters
    - `batch_number`: The batch number for which to determine the block range
    - `prev_message_count`: The message count before this batch, or `nil`
    - `new_message_count`: The message count after this batch, or `nil`
    - `msg_to_block_shift`: The adjustment value to convert message counts to block numbers
    - `rollup_config`: Configuration map containing:
      - `node_interface_address`: Address of the `NodeInterface` contract
      - `json_rpc_named_arguments`: JSON-RPC connection parameters

    ## Returns
    - A tuple `{start_block, end_block}` representing the inclusive range of rollup
      blocks in the batch
  """
  @spec determine_batch_block_range(
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer() | nil,
          non_neg_integer(),
          %{
            node_interface_address: EthereumJSONRPC.address(),
            json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
          }
        ) :: {non_neg_integer(), non_neg_integer()}
  def determine_batch_block_range(
        batch_number,
        prev_message_count,
        new_message_count,
        msg_to_block_shift,
        rollup_config
      )

  def determine_batch_block_range(batch_number, prev_message_count, new_message_count, _, rollup_config)
      when is_nil(prev_message_count) and is_nil(new_message_count) do
    log_info("No blocks range for batch ##{batch_number}. Trying to find it based on already discovered batches.")

    {highest_block, step_highest_to_lowest} = get_expected_highest_block_and_step(batch_number + 1)
    {lowest_block, step_lowest_to_highest} = get_expected_lowest_block_and_step(batch_number - 1)

    {start_block, end_block} =
      case {lowest_block, highest_block} do
        {nil, nil} -> raise "Impossible to determine the block range for batch #{batch_number}"
        {lowest, nil} -> Rpc.get_block_range_for_batch(lowest, step_lowest_to_highest, batch_number, rollup_config)
        {nil, highest} -> Rpc.get_block_range_for_batch(highest, step_highest_to_lowest, batch_number, rollup_config)
        {lowest, highest} -> {lowest, highest}
      end

    log_info("Blocks range for batch ##{batch_number} is determined as #{start_block}..#{end_block}")
    {start_block, end_block}
  end

  def determine_batch_block_range(_, prev_message_count, new_message_count, msg_to_block_shift, _) do
    # In some cases extracted numbers for messages does not linked directly
    # with rollup blocks, for this, the numbers are shifted by a value specific
    # for particular rollup
    {prev_message_count + msg_to_block_shift, new_message_count + msg_to_block_shift - 1}
  end

  # Calculates the expected highest block and step required for the lowest block look up for a given batch number.
  @spec get_expected_highest_block_and_step(non_neg_integer()) :: {non_neg_integer(), non_neg_integer()} | {nil, nil}
  defp get_expected_highest_block_and_step(batch_number) do
    # since the default direction for the block range exploration is chosen to be from the highest to lowest
    # the step is calculated to be positive
    case DbSettlement.get_batch_by_number(batch_number) do
      nil ->
        {nil, nil}

      %Arbitrum.L1Batch{start_block: start_block, end_block: end_block} ->
        {start_block - 1, half_of_block_range(start_block, end_block, :descending)}
    end
  end

  # Calculates the expected lowest block and step required for the highest block look up for a given batch number.
  @spec get_expected_lowest_block_and_step(non_neg_integer()) :: {non_neg_integer(), integer()} | {nil, nil}
  defp get_expected_lowest_block_and_step(batch_number) do
    # since the default direction for the block range exploration is chosen to be from the highest to lowest
    # the step is calculated to be negative
    case DbSettlement.get_batch_by_number(batch_number) do
      nil ->
        {nil, nil}

      %Arbitrum.L1Batch{start_block: start_block, end_block: end_block} ->
        {end_block + 1, half_of_block_range(start_block, end_block, :ascending)}
    end
  end

  # Calculates half the range between two block numbers, with direction adjustment.
  #
  # ## Parameters
  # - `start_block`: The starting block number.
  # - `end_block`: The ending block number.
  # - `direction`: The direction of calculation, either `:ascending` or `:descending`.
  #
  # ## Returns
  # - An integer representing half the block range, adjusted for direction:
  #   - For `:descending`, a positive integer >= 1.
  #   - For `:ascending`, a negative integer <= -1.
  @spec half_of_block_range(non_neg_integer(), non_neg_integer(), :ascending | :descending) :: integer()
  defp half_of_block_range(start_block, end_block, direction) do
    case direction do
      :descending -> max(div(end_block - start_block + 1, 2), 1)
      :ascending -> min(div(start_block - end_block - 1, 2), -1)
    end
  end
end
