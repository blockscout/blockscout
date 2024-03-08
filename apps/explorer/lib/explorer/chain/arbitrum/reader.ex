defmodule Explorer.Chain.Arbitrum.Reader do
  @moduledoc """
  TBD
  """

  import Ecto.Query, only: [from: 2]

  alias Explorer.Chain.Arbitrum.{BatchBlock, L1Batch, L1Execution, LifecycleTransaction, Message}

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.Block, as: FullBlock

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
  def l1_block_of_earliest_discovered_message_to_l2 do
    query =
      from(msg in Message,
        select: msg.originating_tx_blocknum,
        where: msg.direction == :to_l2 and not is_nil(msg.originating_tx_blocknum),
        order_by: [asc: msg.message_id],
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
  TBD
  """
  def l1_block_of_earliest_committed_batch do
    query =
      from(batch in L1Batch,
        order_by: [asc: batch.number],
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
  TBD
  """
  def highest_committed_block do
    query =
      from(batch in L1Batch,
        select: batch.end_block,
        order_by: [desc: batch.number],
        limit: 1
      )

    query
    |> Repo.one()
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

  def l1_executions(message_ids) do
    query =
      from(
        ex in L1Execution,
        where: ex.message_id in ^message_ids
      )

    query
    |> Chain.join_associations(%{
      :execution_transaction => :optional
    })
    |> Repo.all(timeout: :infinity)
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

  def rollup_block_hash_to_num(block_hash) do
    query =
      from(bl in BatchBlock,
        where: bl.hash == ^block_hash
      )

    case query
         |> Chain.join_associations(%{
           :block => :optional
         })
         |> Repo.one() do
      nil ->
        # Block with such hash is not found
        {:ok, nil}

      rollup_block ->
        case rollup_block.block do
          # `nil` and `%Ecto.Association.NotLoaded{}` indicate DB inconsistency
          nil -> {:error, nil}
          %Ecto.Association.NotLoaded{} -> {:error, nil}
          associated_block -> {:ok, associated_block.number}
        end
    end
  end

  def get_batch_by_rollup_block_num(number) do
    query =
      from(batch in L1Batch,
        # end_block has higher number than start_block
        where: batch.end_block >= ^number and batch.start_block <= ^number
      )

    query
    |> Chain.join_associations(%{
      :commit_transaction => :optional
    })
    |> Repo.one()
  end

  def l1_block_of_latest_confirmed_block do
    query =
      from(
        rb in BatchBlock,
        left_join: fb in FullBlock,
        on: rb.hash == fb.hash,
        select: rb,
        where: not is_nil(rb.confirm_id),
        order_by: [desc: fb.number],
        limit: 1
      )

    case query
         |> Chain.join_associations(%{
           :confirm_transaction => :optional
         })
         |> Repo.one() do
      nil -> nil
      block -> block.confirm_transaction.block
    end
  end

  def highest_confirmed_block do
    query =
      from(
        rb in BatchBlock,
        left_join: fb in FullBlock,
        on: rb.hash == fb.hash,
        select: fb.number,
        where: not is_nil(rb.confirm_id),
        order_by: [desc: fb.number],
        limit: 1
      )

    query
    |> Repo.one()
  end

  def l1_block_of_latest_execution do
    query =
      from(
        tx in LifecycleTransaction,
        left_join: ex in L1Execution,
        on: tx.id == ex.execution_id,
        select: tx.block,
        order_by: [desc: tx.block],
        limit: 1
      )

    query
    |> Repo.one()
  end

  def l1_block_of_earliest_execution do
    query =
      from(
        tx in LifecycleTransaction,
        left_join: ex in L1Execution,
        on: tx.id == ex.execution_id,
        select: tx.block,
        order_by: [asc: tx.block],
        limit: 1
      )

    query
    |> Repo.one()
  end

  def unconfirmed_rollup_blocks(first_block, last_block) do
    query =
      from(
        rb in BatchBlock,
        left_join: fb in FullBlock,
        on: rb.hash == fb.hash,
        select: %{
          batch_number: rb.batch_number,
          hash: rb.hash,
          block_num: fb.number,
          confirm_id: rb.confirm_id
        },
        where: fb.number >= ^first_block and fb.number <= ^last_block and is_nil(rb.confirm_id),
        order_by: [asc: fb.number]
      )

    Repo.all(query, timeout: :infinity)
  end

  def count_confirmed_rollup_blocks_in_batch(batch_number) do
    query =
      from(
        rb in BatchBlock,
        where: rb.batch_number >= ^batch_number and not is_nil(rb.confirm_id)
      )

    Repo.aggregate(query, :count, timeout: :infinity)
  end

  def l2_to_l1_messages(status, block_number) do
    query =
      from(msg in Message,
        where: msg.direction == :from_l2 and msg.originating_tx_blocknum <= ^block_number and msg.status == ^status,
        order_by: [desc: msg.message_id]
      )

    Repo.all(query, timeout: :infinity)
  end
end
