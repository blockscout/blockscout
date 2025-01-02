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
end
