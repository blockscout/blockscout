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
  alias Explorer.Chain.ZkSync.{
    LifecycleTransaction,
    TransactionBatch
  }
  # alias Explorer.{Chain, PagingOptions, Repo}
  alias Explorer.{
    Repo,
    Chain
  }

  def batches(start_number, end_number, options) when is_list(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    from(tb in TransactionBatch, order_by: [desc: tb.number])
    |> where([tb], tb.number >= ^start_number and tb.number <= ^end_number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  @doc """
    Gets the number of the latest batch with execute_id.
    Returns nil if not found
  """
  @spec last_executed_batch_number() :: non_neg_integer() | nil
  def last_executed_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        where: not is_nil(tb.execute_id),
        order_by: [desc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(nil)
  end

  @doc """
    Gets the number of the oldest batch.
    Returns nil if not found
  """
  @spec oldest_available_batch_number() :: non_neg_integer() | nil
  def oldest_available_batch_number do
    query =
      from(tb in TransactionBatch,
        select: tb.number,
        order_by: [asc: tb.number],
        limit: 1
      )

    query
    |> Repo.one()
    |> Kernel.||(nil)
  end

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
