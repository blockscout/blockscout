defmodule Indexer.Fetcher.Arbitrum.Utils.Db.Common do
  @moduledoc """
    Provides chain-agnostic database utility functions for block-related operations.

    This module contains general-purpose functions for querying data that are not
    specific to Arbitrum and can be used across different blockchain implementations.
    Functions in this module operate only on common database table shared across all
    chain types.

    Note: Consider relocating these functions to a more general utility module if they
    are needed by non-Arbitrum fetchers, as their current placement in the Arbitrum
    namespace may be misleading.
  """

  alias Explorer.Chain.Arbitrum.Reader.Indexer.General, as: ArbitrumReader
  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.Block.Reader.General, as: BlockGeneralReader
  alias Explorer.Utility.MissingBlockRange

  @doc """
    Determines whether a given range of block numbers has been fully indexed without any missing blocks.

    ## Parameters
    - `start_block`: The starting block number of the range to check for completeness in indexing.
    - `end_block`: The ending block number of the range.

    ## Returns
    - `true` if the entire range from `start_block` to `end_block` is indexed and contains no missing
      blocks, indicating no intersection with missing block ranges; `false` otherwise.
  """
  @spec indexed_blocks?(FullBlock.block_number(), FullBlock.block_number()) :: boolean()
  def indexed_blocks?(start_block, end_block)
      when is_integer(start_block) and start_block >= 0 and
             is_integer(end_block) and start_block <= end_block do
    is_nil(MissingBlockRange.intersects_with_range(start_block, end_block))
  end

  @doc """
    Retrieves the block number for the closest block immediately after a given timestamp.

    ## Parameters
    - `timestamp`: The `DateTime` timestamp for which the closest subsequent block number is sought.

    ## Returns
    - `{:ok, block_number}` where `block_number` is the number of the closest block that occurred
      after the specified timestamp.
    - `{:error, :not_found}` if no block is found after the specified timestamp.
  """
  @spec closest_block_after_timestamp(DateTime.t()) :: {:error, :not_found} | {:ok, FullBlock.block_number()}
  def closest_block_after_timestamp(timestamp) do
    BlockGeneralReader.timestamp_to_block_number(timestamp, :after, false, true)
  end

  @doc """
    Retrieves full details of rollup blocks, including associated transactions, for each block number specified in the input list.

    ## Parameters
    - `list_of_block_numbers`: A list of block numbers for which full block details are to be retrieved.

    ## Returns
    - A list of `Explorer.Chain.Block` instances containing detailed information for each
      block number in the input list. Returns an empty list if no blocks are found for the given numbers.
  """
  @spec rollup_blocks([FullBlock.block_number()]) :: [FullBlock.t()]
  def rollup_blocks(list_of_block_numbers), do: ArbitrumReader.rollup_blocks(list_of_block_numbers)

  @doc """
    Retrieves block numbers within a range that are missing Arbitrum-specific fields.

    Identifies rollup blocks that lack one or more of the following fields:
    `send_count`, `send_root`, or `l1_block_number`.

    ## Parameters
    - `start_block_number`: The lower bound of the block range to check.
    - `end_block_number`: The upper bound of the block range to check.

    ## Returns
    - A list of block numbers that are missing one or more required fields.
  """
  @spec blocks_with_missing_fields(FullBlock.block_number(), FullBlock.block_number()) :: [FullBlock.block_number()]
  def blocks_with_missing_fields(start_block_number, end_block_number) do
    ArbitrumReader.blocks_with_missing_fields(start_block_number, end_block_number)
  end
end
