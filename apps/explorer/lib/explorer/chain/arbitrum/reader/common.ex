defmodule Explorer.Chain.Arbitrum.Reader.Common do
  import Ecto.Query, only: [from: 2]
  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Arbitrum.BatchBlock
  alias Explorer.Chain.Block, as: FullBlock

  @doc """
    Retrieves the number of the highest confirmed rollup block.

    ## Parameters
    - `options`: A keyword list of options:
      - `:api?` - Whether the function is being called from an API context.

    ## Returns
    - The number of the highest confirmed rollup block, or `nil` if no confirmed rollup blocks are found.
  """
  @spec highest_confirmed_block(api?: boolean()) :: FullBlock.block_number() | nil
  def highest_confirmed_block(options) do
    query =
      from(
        rb in BatchBlock,
        where: not is_nil(rb.confirmation_id),
        select: rb.block_number,
        order_by: [desc: rb.block_number],
        limit: 1
      )

    select_repo(options).one(query)
  end
end
