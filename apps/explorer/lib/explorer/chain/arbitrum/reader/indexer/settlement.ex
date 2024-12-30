defmodule Explorer.Chain.Arbitrum.Reader.Indexer.Settlement do
  @moduledoc """
    Provides database query functions for retrieving information about Arbitrum rollup batches
    and state confirmations on the L1 chain.

    This module focuses on reading settlement-related data for the Arbitrum indexer, including:

    * L1 batches - Sequential groups of L2 blocks committed to L1 via commitment transactions
    * Batch blocks - Individual L2 blocks included in L1 batches
    * Block confirmations - L1 transactions that confirm the state of L2 blocks
    * Data availability records - Additional data associated with batches (e.g., AnyTrust keysets)
  """

  import Ecto.Query, only: [from: 2, subquery: 1]

  alias Explorer.Chain.Arbitrum.{
    BatchBlock,
    L1Batch,
    LifecycleTransaction
  }

  alias Explorer.Chain.Arbitrum.Reader.Common

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.Block, as: FullBlock

  @doc """
    Retrieves the number of the latest L1 block where the commitment transaction with a batch was included.

    As per the Arbitrum rollup nature, from the indexer's point of view, a batch does not exist until
    the commitment transaction is submitted to L1. Therefore, the situation where a batch exists but
    there is no commitment transaction is not possible.

    ## Returns
    - The number of the L1 block, or `nil` if no rollup batches are found, or if the association between the batch
      and the commitment transaction has been broken due to database inconsistency.
  """
  @spec l1_block_of_latest_committed_batch() :: FullBlock.block_number() | nil
  def l1_block_of_latest_committed_batch do
    query =
      from(batch in L1Batch,
        order_by: [desc: batch.number],
        limit: 1
      )

    case query
         # :required is used since the situation when commit transaction is not found is not possible
         |> Chain.join_associations(%{:commitment_transaction => :required})
         |> Repo.one(timeout: :infinity) do
      nil -> nil
      batch -> batch.commitment_transaction.block_number
    end
  end

  @doc """
    Retrieves the number of the earliest L1 block where the commitment transaction with a batch was included.

    As per the Arbitrum rollup nature, from the indexer's point of view, a batch does not exist until
    the commitment transaction is submitted to L1. Therefore, the situation where a batch exists but
    there is no commitment transaction is not possible.

    ## Returns
    - The number of the L1 block, or `nil` if no rollup batches are found, or if the association between the batch
      and the commitment transaction has been broken due to database inconsistency.
  """
  @spec l1_block_of_earliest_committed_batch() :: FullBlock.block_number() | nil
  def l1_block_of_earliest_committed_batch do
    query =
      from(batch in L1Batch,
        order_by: [asc: batch.number],
        limit: 1
      )

    case query
         # :required is used since the situation when commit transaction is not found is not possible
         |> Chain.join_associations(%{:commitment_transaction => :required})
         |> Repo.one(timeout: :infinity) do
      nil -> nil
      batch -> batch.commitment_transaction.block_number
    end
  end

  @doc """
    Retrieves the block number of the highest rollup block that has been included in a batch.

    ## Returns
    - The number of the highest rollup block included in a batch, or `nil` if no rollup batches are found.
  """
  @spec highest_committed_block() :: FullBlock.block_number() | nil
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
    Gets the rollup block number by the hash of the block. Lookup is performed only
    for blocks explicitly included in a batch, i.e., the batch has been identified by
    the corresponding fetcher. The function may return `nil` as a successful response
    if the batch containing the rollup block has not been indexed yet.

    ## Parameters
    - `block_hash`: The hash of a block included in the batch.

    ## Returns
    - the number of the rollup block corresponding to the given hash or `nil` if the
      block or batch were not indexed yet.
  """
  @spec rollup_block_hash_to_num(binary()) :: FullBlock.block_number() | nil
  def rollup_block_hash_to_num(block_hash) when is_binary(block_hash) do
    query =
      from(
        fb in FullBlock,
        inner_join: rb in BatchBlock,
        on: rb.block_number == fb.number,
        select: fb.number,
        where: fb.hash == ^block_hash
      )

    query
    |> Repo.one()
  end

  @doc """
    Checks if the numbers from the provided list correspond to the numbers of indexed batches.

    ## Parameters
    - `batches_numbers`: The list of batch numbers.

    ## Returns
    - A list of batch numbers that are indexed and match the provided list, or `[]`
      if none of the batch numbers in the provided list exist in the database. The output list
      may be smaller than the input list.
  """
  @spec batches_exist(maybe_improper_list(non_neg_integer(), [])) :: [non_neg_integer]
  def batches_exist(batches_numbers) when is_list(batches_numbers) do
    query =
      from(
        batch in L1Batch,
        select: batch.number,
        where: batch.number in ^batches_numbers
      )

    query
    |> Repo.all()
  end

  @doc """
    Retrieves the batch in which the rollup block, identified by the given block number, was included.

    ## Parameters
    - `number`: The number of a rollup block.

    ## Returns
    - An instance of `Explorer.Chain.Arbitrum.L1Batch` representing the batch containing
      the specified rollup block number, or `nil` if no corresponding batch is found.
  """
  @spec get_batch_by_rollup_block_number(FullBlock.block_number()) :: L1Batch.t() | nil
  def get_batch_by_rollup_block_number(number)
      when is_integer(number) and number >= 0 do
    query =
      from(batch in L1Batch,
        # end_block has higher number than start_block
        where: batch.end_block >= ^number and batch.start_block <= ^number
      )

    query
    # :required is used since the situation when commit transaction is not found is not possible
    |> Chain.join_associations(%{:commitment_transaction => :required})
    |> Repo.one()
  end

  @doc """
    Retrieves the batch by its number.

    ## Parameters
    - `number`: The number of a rollup batch.

    ## Returns
    - An instance of `Explorer.Chain.Arbitrum.L1Batch`, or `nil` if no batch with
      such a number is found.
  """
  @spec get_batch_by_number(non_neg_integer()) :: L1Batch.t() | nil
  def get_batch_by_number(number) do
    query =
      from(batch in L1Batch,
        where: batch.number == ^number
      )

    query
    |> Repo.one()
  end

  @doc """
    Retrieves the L1 block number where the confirmation transaction of the highest confirmed rollup block was included.

    ## Returns
    - The L1 block number if a confirmed rollup block is found and the confirmation transaction is indexed;
      `nil` if no confirmed rollup blocks are found or if there is a database inconsistency.
  """
  @spec l1_block_of_latest_confirmed_block() :: FullBlock.block_number() | nil
  def l1_block_of_latest_confirmed_block do
    query =
      from(
        rb in BatchBlock,
        where: not is_nil(rb.confirmation_id),
        order_by: [desc: rb.block_number],
        limit: 1
      )

    case query
         # :required is used since existence of the confirmation id is checked above
         |> Chain.join_associations(%{:confirmation_transaction => :required})
         |> Repo.one(timeout: :infinity) do
      nil ->
        nil

      block ->
        case block.confirmation_transaction do
          # `nil` and `%Ecto.Association.NotLoaded{}` indicate DB inconsistency
          nil -> nil
          %Ecto.Association.NotLoaded{} -> nil
          confirmation_transaction -> confirmation_transaction.block_number
        end
    end
  end

  @doc """
    Retrieves the number of the highest confirmed rollup block.

    It calls `Common.highest_confirmed_block/1` with `api?: false` option to use
    primary database.

    ## Returns
    - The number of the highest confirmed rollup block, or `nil` if no confirmed rollup blocks are found.
  """
  @spec highest_confirmed_block() :: FullBlock.block_number() | nil
  def highest_confirmed_block do
    Common.highest_confirmed_block(api?: false)
  end

  @doc """
    Retrieves all unconfirmed rollup blocks within the specified range from `first_block` to `last_block`,
    inclusive, where `first_block` is less than or equal to `last_block`.

    Since the function relies on the block data generated by the block fetcher, the returned list
    may contain fewer blocks than actually exist if some of the blocks have not been indexed by the fetcher yet.

    ## Parameters
    - `first_block`: The rollup block number starting the lookup range.
    - `last_block`:The rollup block number ending the lookup range.

    ## Returns
    - A list of maps containing the batch number, rollup block number and hash for each
      unconfirmed block within the range. Returns `[]` if no unconfirmed blocks are found
      within the range, or if the block fetcher has not indexed them.
  """
  @spec unconfirmed_rollup_blocks(FullBlock.block_number(), FullBlock.block_number()) :: [BatchBlock.t()]
  def unconfirmed_rollup_blocks(first_block, last_block)
      when is_integer(first_block) and first_block >= 0 and
             is_integer(last_block) and first_block <= last_block do
    query =
      from(
        rb in BatchBlock,
        where: rb.block_number >= ^first_block and rb.block_number <= ^last_block and is_nil(rb.confirmation_id),
        order_by: [asc: rb.block_number]
      )

    Repo.all(query)
  end

  @doc """
    Calculates the number of confirmed rollup blocks in the specified batch.

    ## Parameters
    - `batch_number`: The number of the batch for which the count of confirmed blocks is to be calculated.

    ## Returns
    - The number of confirmed blocks in the batch with the given number.
  """
  @spec count_confirmed_rollup_blocks_in_batch(non_neg_integer()) :: non_neg_integer
  def count_confirmed_rollup_blocks_in_batch(batch_number)
      when is_integer(batch_number) and batch_number >= 0 do
    query =
      from(
        rb in BatchBlock,
        where: rb.batch_number == ^batch_number and not is_nil(rb.confirmation_id)
      )

    Repo.aggregate(query, :count)
  end

  @doc """
    Retrieves the numbers of the L1 blocks containing the confirmation transactions
    bounding the first interval where missed confirmation transactions could be found.

    The absence of a confirmation transaction is assumed based on the analysis of a
    series of confirmed rollup blocks. For example, if blocks 0-3 are confirmed by transaction X,
    blocks 7-9 by transaction Y, and blocks 12-15 by transaction Z, there are two gaps:
    blocks 4-6 and 10-11. According to Arbitrum's nature, this indicates that the confirmation
    transactions for blocks 6 and 11 have not yet been indexed.

    In the example above, the function will return the tuple with the numbers of the L1 blocks
    where transactions Y and Z were included.

    ## Returns
    - A tuple of the L1 block numbers between which missing confirmation transactions are suspected,
      or `nil` if no gaps in confirmed blocks are found or if there are no missed confirmation transactions.
  """
  @spec l1_blocks_of_confirmations_bounding_first_unconfirmed_rollup_blocks_gap() ::
          {FullBlock.block_number() | nil, FullBlock.block_number()} | nil
  def l1_blocks_of_confirmations_bounding_first_unconfirmed_rollup_blocks_gap do
    # The first subquery retrieves the numbers of confirmed rollup blocks.
    rollup_blocks_query =
      from(
        rb in BatchBlock,
        select: %{
          block_number: rb.block_number,
          confirmation_id: rb.confirmation_id
        },
        where: not is_nil(rb.confirmation_id)
      )

    # The second subquery builds on the first one, grouping block numbers by their
    # confirmation transactions. As a result, it identifies the starting and ending
    # rollup blocks for every transaction.
    confirmed_ranges_query =
      from(
        subquery in subquery(rollup_blocks_query),
        select: %{
          confirmation_id: subquery.confirmation_id,
          min_block_num: min(subquery.block_number),
          max_block_num: max(subquery.block_number)
        },
        group_by: subquery.confirmation_id
      )

    # The third subquery utilizes the window function LAG to associate each confirmation
    # transaction with the starting rollup block of the preceding transaction.
    confirmed_combined_ranges_query =
      from(
        subquery in subquery(confirmed_ranges_query),
        select: %{
          confirmation_id: subquery.confirmation_id,
          min_block_num: subquery.min_block_num,
          max_block_num: subquery.max_block_num,
          prev_max_number: fragment("LAG(?, 1) OVER (ORDER BY ?)", subquery.max_block_num, subquery.min_block_num),
          prev_confirmation_id:
            fragment("LAG(?, 1) OVER (ORDER BY ?)", subquery.confirmation_id, subquery.min_block_num)
        }
      )

    # The final query identifies confirmation transactions for which the ending block does
    # not precede the starting block of the subsequent confirmation transaction.
    main_query =
      from(
        subquery in subquery(confirmed_combined_ranges_query),
        inner_join: current_transaction in LifecycleTransaction,
        on: subquery.confirmation_id == current_transaction.id,
        left_join: previous_transaction in LifecycleTransaction,
        on: subquery.prev_confirmation_id == previous_transaction.id,
        select: {previous_transaction.block_number, current_transaction.block_number},
        where: subquery.min_block_num - 1 != subquery.prev_max_number or is_nil(subquery.prev_max_number),
        order_by: [desc: subquery.min_block_num],
        limit: 1
      )

    main_query
    |> Repo.one()
  end

  @doc """
    Retrieves an AnyTrust keyset from the database using the provided keyset hash.

    It calls `Common.get_anytrust_keyset/1` with `api?: false` option to use
    primary database.

    ## Parameters
    - `keyset_hash`: A binary representing the hash of the keyset to be retrieved.

    ## Returns
    - A map containing information about the AnyTrust keyset, otherwise an empty map.
  """
  @spec get_anytrust_keyset(binary()) :: map()
  def get_anytrust_keyset(keyset_hash) do
    Common.get_anytrust_keyset(keyset_hash, api?: false)
  end

  @doc """
    Retrieves the batch numbers of missing L1 batches within a specified range.

    This function constructs a query to find the batch numbers of L1 batches that
    are missing within the given range of batch numbers. It uses a right join with
    a generated series to identify batch numbers that do not exist in the
    `arbitrum_l1_batches` table.

    ## Parameters
    - `start_batch_number`: The starting batch number of the search range.
    - `end_batch_number`: The ending batch number of the search range.

    ## Returns
    - A list of batch numbers in ascending order that are missing within the specified range.
  """
  @spec find_missing_batches(non_neg_integer(), non_neg_integer()) :: [non_neg_integer()]
  def find_missing_batches(start_batch_number, end_batch_number)
      when is_integer(start_batch_number) and is_integer(end_batch_number) and end_batch_number >= start_batch_number do
    query =
      from(batch in L1Batch,
        right_join:
          missing_range in fragment(
            """
            (
              SELECT distinct b1.number
              FROM generate_series((?)::integer, (?)::integer) AS b1(number)
              WHERE NOT EXISTS
                (SELECT 1 FROM arbitrum_l1_batches b2 WHERE b2.number=b1.number)
              ORDER BY b1.number DESC
            )
            """,
            ^start_batch_number,
            ^end_batch_number
          ),
        on: batch.number == missing_range.number,
        select: missing_range.number,
        order_by: missing_range.number,
        distinct: missing_range.number
      )

    query
    |> Repo.all()
  end

  @doc """
    Retrieves L1 block numbers for the given list of batch numbers.

    This function finds the numbers of L1 blocks that include L1 transactions
    associated with batches within the specified list of batch numbers.

    ## Parameters
    - `batch_numbers`: A list of batch numbers for which to retrieve the L1 block numbers.

    ## Returns
    - A map where the keys are batch numbers and the values are corresponding L1 block numbers.
  """
  @spec get_l1_blocks_of_batches_by_numbers([non_neg_integer()]) :: %{non_neg_integer() => FullBlock.block_number()}
  def get_l1_blocks_of_batches_by_numbers(batch_numbers) when is_list(batch_numbers) do
    query =
      from(batch in L1Batch,
        join: l1tx in assoc(batch, :commitment_transaction),
        where: batch.number in ^batch_numbers,
        select: {batch.number, l1tx.block_number}
      )

    query
    |> Repo.all()
    |> Enum.reduce(%{}, fn {batch_number, l1_block_number}, acc ->
      Map.put(acc, batch_number, l1_block_number)
    end)
  end

  @doc """
    Retrieves the minimum and maximum batch numbers of L1 batches.

    ## Returns
    - A tuple containing the minimum and maximum batch numbers or `{nil, nil}` if no batches are found.
  """
  @spec get_min_max_batch_numbers() :: {non_neg_integer(), non_neg_integer()} | {nil | nil}
  def get_min_max_batch_numbers do
    query =
      from(batch in L1Batch,
        select: {min(batch.number), max(batch.number)}
      )

    Repo.one(query, timeout: :infinity)
  end
end
