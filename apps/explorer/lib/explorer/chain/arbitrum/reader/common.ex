defmodule Explorer.Chain.Arbitrum.Reader.Common do
  @moduledoc """
    Provides common database query functions for Arbitrum-specific data that are shared
    between different Blockscout components.

    This module serves as a central location for core query functionality that needs to
    be accessed from different logical parts of the application, such as:

    * Web API handlers (`Explorer.Chain.Arbitrum.Reader.API`)
    * Chain indexer components (e.g. `Explorer.Chain.Arbitrum.Reader.Indexer.Settlement`)
    * Other potential consumers

    The functions in this module are designed to be configurable in terms of database
    selection (primary vs replica) through options parameters. This allows the calling
    modules to maintain their specific database access patterns while sharing the core
    query logic.

    For example, API handlers typically use replica databases to reduce load on the
    primary database, while indexer components require immediate consistency and thus
    use the primary database. This module accommodates both use cases through options
    parameters.

    When adding new functions to this module, ensure they:
    * Are needed by multiple components of the application
    * Accept options for configuring database selection
    * Implement core query logic that can be reused across different contexts
  """

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
