defmodule Explorer.Chain.ZkSync.Reader do
  @moduledoc "Contains read functions for zksync modules."

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      order_by: 2,
      where: 2,
      where: 3
    ]

  import Explorer.Chain, only: [select_repo: 1]

  # alias Explorer.Chain.Zkevm.{BatchTransaction, LifecycleTransaction, TransactionBatch}
  alias Explorer.Chain.ZkSync.LifecycleTransaction
  # alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.Repo

  @doc """
    Reads a list of L1 transactions by their hashes from `zksync_lifecycle_l1_transactions` table.
  """
  @spec lifecycle_transactions(list()) :: list()
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
    Determines ID of the future lifecycle transaction by reading `zksync_lifecycle_l1_transactions` table.
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

end
