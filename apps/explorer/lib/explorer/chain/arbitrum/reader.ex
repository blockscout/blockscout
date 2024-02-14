defmodule Explorer.Chain.Arbitrum.Reader do
  @moduledoc """
  TBD
  """

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 2,
      where: 2,
      where: 3
    ]

  alias Explorer.Chain.Arbitrum.{L1Batch, LifecycleTransaction, Message}

  alias Explorer.{Chain, Repo}

  @doc """
  TBD
  """
  def l1_block_of_latest_discovered_message_to_l2 do
    query =
      from(msg in Message,
        select: msg.originating_tx_blocknum,
        where: msg.direction == :to_l2 and not is_nil(msg.originating_tx_blocknum),
        order_by: [desc: msg.message_id],
        limit: 1
      )

    query
    |> Repo.one()
  end

  @doc """
  TBD
  """
  def l1_block_of_latest_committed_batch do
    query =
      from(batch in L1Batch,
        order_by: [desc: batch.number],
        limit: 1
      )

    case query
         |> Chain.join_associations(%{
           :commit_transaction => :optional
         })
         |> Repo.one() do
      nil -> nil
      batch -> batch.commit_transaction.block
    end
  end

  @doc """
    Reads a list of L1 transactions by their hashes from the `arbitrum_lifecycle_l1_transactions` table.

    ## Parameters
    - `l1_tx_hashes`: A list of hashes to retrieve L1 transactions for.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.LifecycleTransaction` corresponding to the hashes from
      the input list. The output list may be smaller than the input list.
  """
  @spec lifecycle_transactions(maybe_improper_list(binary(), [])) :: [Explorer.Chain.Arbitrum.LifecycleTransaction]
  def lifecycle_transactions(l1_tx_hashes) do
    query =
      from(
        lt in LifecycleTransaction,
        select: {lt.hash, lt.id},
        where: lt.hash in ^l1_tx_hashes
      )

    Repo.all(query, timeout: :infinity)
  end

  @doc """
    Determines the next index for the L1 transaction available in the `arbitrum_lifecycle_l1_transactions` table.

    ## Returns
    - The next available index. If there are no L1 transactions imported yet, it will return `1`.
  """
  @spec next_id() :: non_neg_integer()
  def next_id do
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

  def lifecycle_unfinalized_transactions(finalized_block) do
    query =
      from(
        lt in LifecycleTransaction,
        where: lt.block <= ^finalized_block and lt.status == :unfinalized
      )

    Repo.all(query, timeout: :infinity)
  end
end
