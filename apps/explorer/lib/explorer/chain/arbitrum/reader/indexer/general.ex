defmodule Explorer.Chain.Arbitrum.Reader.Indexer.General do
  @moduledoc """
    Provides general-purpose blockchain data reading functionality that is currently
    not available in other chain-agnostic modules under `Explorer.Chain.*`.

    While these functions are located in the Arbitrum namespace, they are
    implementation-agnostic and contain no Arbitrum-specific logic. They are
    candidates for relocation to a general blockchain reader module when similar
    functionality is needed for other chains.
  """

  import Ecto.Query, only: [from: 2]

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.Block, as: FullBlock

  @doc """
    Retrieves full details of rollup blocks, including associated transactions, for each
    block number specified in the input list.

    ## Parameters
    - `list_of_block_numbers`: A list of block numbers for which full block details are to be retrieved.

    ## Returns
    - A list of `Explorer.Chain.Block` instances containing detailed information for each
      block number in the input list. Returns an empty list if no blocks are found for the given numbers.
  """
  @spec rollup_blocks([FullBlock.block_number()]) :: [FullBlock.t()]
  def rollup_blocks(list_of_block_numbers)

  def rollup_blocks([]), do: []

  def rollup_blocks(list_of_block_numbers) do
    query =
      from(
        block in FullBlock,
        where: block.number in ^list_of_block_numbers
      )

    query
    # :optional is used since a block may not have any transactions
    |> Chain.join_associations(%{:transactions => :optional})
    |> Repo.all()
  end

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
    query =
      from(block in FullBlock,
        where:
          block.number >= ^start_block_number and block.number <= ^end_block_number and block.consensus == true and
            (is_nil(block.send_count) or is_nil(block.send_root) or is_nil(block.l1_block_number)),
        select: block.number
      )

    Repo.all(query)
  end
end
