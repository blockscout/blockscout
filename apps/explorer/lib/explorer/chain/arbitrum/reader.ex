defmodule Explorer.Chain.Arbitrum.Reader do
  @moduledoc """
  TBD
  """

  import Ecto.Query, only: [from: 2, subquery: 1]

  alias Explorer.Chain.Arbitrum.{BatchBlock, L1Batch, L1Execution, LifecycleTransaction, Message}

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.{Log, Transaction}

  # 32-byte signature of the event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)
  @l2_to_l1_event "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc"

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
  def rollup_block_of_earliest_discovered_message_from_l2 do
    query =
      from(msg in Message,
        select: msg.originating_tx_blocknum,
        where: msg.direction == :from_l2 and not is_nil(msg.originating_tx_blocknum),
        order_by: [asc: msg.originating_tx_blocknum],
        limit: 1
      )

    query
    |> Repo.one()
  end

  @doc """
  TBD
  """
  def rollup_block_of_earliest_discovered_message_to_l2 do
    completion_tx_subquery =
      from(msg in Message,
        select: msg.completion_tx_hash,
        where: msg.direction == :to_l2 and not is_nil(msg.completion_tx_hash),
        order_by: [asc: msg.message_id],
        limit: 1
      )

    query =
      from(tx in Transaction,
        select: tx.block_number,
        where: tx.hash == subquery(completion_tx_subquery),
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

  def batches_exist(batches_numbers) do
    query =
      from(
        batch in L1Batch,
        select: batch.number,
        where: batch.number in ^batches_numbers
      )

    query
    |> Repo.all(timeout: :infinity)
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
        inner_join: fb in FullBlock,
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
        inner_join: fb in FullBlock,
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
        inner_join: ex in L1Execution,
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
        inner_join: ex in L1Execution,
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
        inner_join: fb in FullBlock,
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

  def l1_blocks_of_confirmations_bounding_first_unconfirmed_rollup_blocks_gap do
    rollup_blocks_query =
      from(
        rb in BatchBlock,
        inner_join: fb in FullBlock,
        on: rb.hash == fb.hash,
        select: %{
          block_num: fb.number,
          confirm_id: rb.confirm_id
        },
        where: not is_nil(rb.confirm_id)
      )

    confirmed_ranges_query =
      from(
        subquery in subquery(rollup_blocks_query),
        select: %{
          confirm_id: subquery.confirm_id,
          min_block_num: min(subquery.block_num),
          max_block_num: max(subquery.block_num)
        },
        group_by: subquery.confirm_id
      )

    confirmed_combined_ranges_query =
      from(
        subquery in subquery(confirmed_ranges_query),
        select: %{
          confirm_id: subquery.confirm_id,
          min_block_num: subquery.min_block_num,
          max_block_num: subquery.max_block_num,
          prev_max_number: fragment("LAG(?, 1) OVER (ORDER BY ?)", subquery.max_block_num, subquery.min_block_num),
          prev_confirm_id: fragment("LAG(?, 1) OVER (ORDER BY ?)", subquery.confirm_id, subquery.min_block_num)
        }
      )

    main_query =
      from(
        subquery in subquery(confirmed_combined_ranges_query),
        inner_join: tx_cur in LifecycleTransaction,
        on: subquery.confirm_id == tx_cur.id,
        left_join: tx_prev in LifecycleTransaction,
        on: subquery.prev_confirm_id == tx_prev.id,
        select: {tx_prev.block, tx_cur.block},
        where: subquery.min_block_num - 1 != subquery.prev_max_number or is_nil(subquery.prev_max_number),
        order_by: [desc: subquery.min_block_num],
        limit: 1
      )

    main_query
    |> Repo.one()
  end

  def l2_to_l1_logs(sender, start_block, end_block) do
    query =
      from(log in Log,
        where:
          log.block_number >= ^start_block and
            log.block_number <= ^end_block and
            log.address_hash == ^sender and
            log.first_topic == ^@l2_to_l1_event
      )

    Repo.all(query, timeout: :infinity)
  end

  def l2_to_l1_event, do: @l2_to_l1_event
end
