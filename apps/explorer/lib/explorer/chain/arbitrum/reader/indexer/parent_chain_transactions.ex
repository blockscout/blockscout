defmodule Explorer.Chain.Arbitrum.Reader.Indexer.ParentChainTransactions do
  @moduledoc """
    Provides functions for querying Arbitrum L1 (parent chain) lifecycle transactions.

    Lifecycle transactions are parent chain transactions that affect the state of the Arbitrum
    rollup. These transactions can be:
      * Batch commitment transactions created by the sequencer
      * State root confirmation transactions after fraud proof window expiration
      * User-initiated transactions executing messages from the rollup
  """

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Arbitrum.LifecycleTransaction
  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.Hash
  alias Explorer.Repo

  @doc """
    Reads a list of L1 transactions by their hashes from the `arbitrum_lifecycle_l1_transactions` table and returns their IDs.

    ## Parameters
    - `l1_transaction_hashes`: A list of hashes to retrieve L1 transactions for.

    ## Returns
    - A list of tuples containing transaction hashes and IDs for the transaction
      hashes from the input list. The output list may be smaller than the input
      list.
  """
  @spec lifecycle_transaction_ids([binary()]) :: [{Hash.t(), non_neg_integer}]
  def lifecycle_transaction_ids(l1_transaction_hashes) when is_list(l1_transaction_hashes) do
    query =
      from(
        lt in LifecycleTransaction,
        select: {lt.hash, lt.id},
        where: lt.hash in ^l1_transaction_hashes
      )

    Repo.all(query)
  end

  @doc """
    Reads a list of L1 transactions by their hashes from the `arbitrum_lifecycle_l1_transactions` table.

    ## Parameters
    - `l1_transaction_hashes`: A list of hashes to retrieve L1 transactions for.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.LifecycleTransaction` corresponding to the
      hashes from the input list. The output list may be smaller than the input
      list.
  """
  @spec lifecycle_transactions([binary()]) :: [LifecycleTransaction.t()]
  def lifecycle_transactions(l1_transaction_hashes) when is_list(l1_transaction_hashes) do
    query =
      from(
        lt in LifecycleTransaction,
        where: lt.hash in ^l1_transaction_hashes
      )

    Repo.all(query)
  end

  @doc """
    Determines the next index for the L1 transaction available in the `arbitrum_lifecycle_l1_transactions` table.

    ## Returns
    - The next available index. If there are no L1 transactions imported yet, it will return `1`.
  """
  @spec next_lifecycle_transaction_id() :: non_neg_integer
  def next_lifecycle_transaction_id do
    query =
      from(lt in LifecycleTransaction,
        select: lt.id,
        order_by: [desc: lt.id],
        limit: 1
      )

    last_id =
      query
      |> Repo.one()
      |> Kernel.||(0)

    last_id + 1
  end

  @doc """
    Retrieves unfinalized L1 transactions from the `LifecycleTransaction` table that are
    involved in changing the statuses of rollup blocks or transactions.

    An L1 transaction is considered unfinalized if it has not yet reached a state where
    it is permanently included in the blockchain, meaning it is still susceptible to
    potential reorganization or change. Transactions are evaluated against the `finalized_block`
    parameter to determine their finalized status.

    ## Parameters
    - `finalized_block`: The L1 block number above which transactions are considered finalized.
      Transactions in blocks higher than this number are not included in the results.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.LifecycleTransaction` representing unfinalized transactions,
      or `[]` if no unfinalized transactions are found.
  """
  @spec lifecycle_unfinalized_transactions(FullBlock.block_number()) :: [LifecycleTransaction.t()]
  def lifecycle_unfinalized_transactions(finalized_block)
      when is_integer(finalized_block) and finalized_block >= 0 do
    query =
      from(
        lt in LifecycleTransaction,
        where: lt.block_number <= ^finalized_block and lt.status == :unfinalized
      )

    Repo.all(query)
  end
end
