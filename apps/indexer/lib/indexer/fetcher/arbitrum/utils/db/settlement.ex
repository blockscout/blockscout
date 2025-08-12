defmodule Indexer.Fetcher.Arbitrum.Utils.Db.Settlement do
  @moduledoc """
    Provides utility functions for querying Arbitrum rollup settlement data.

    This module serves as a wrapper around the database reader functions from
    `Explorer.Chain.Arbitrum.Reader.Indexer.Settlement`, providing additional data
    transformation and error handling capabilities for:

    * L1 batches - Sequential groups of L2 blocks committed to L1
    * Batch blocks - Individual L2 blocks included in L1 batches
    * Block confirmations - L1 transactions confirming L2 block states
    * Data availability records - Additional batch-related data (e.g., AnyTrust keysets)
  """

  @no_committed_batches_warning "No committed batches found in DB"

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1]

  alias Explorer.Chain.Arbitrum
  alias Explorer.Chain.Arbitrum.Reader.Indexer.Settlement, as: Reader
  alias Explorer.Chain.Block, as: FullBlock

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Tools, as: DbTools

  require Logger

  @doc """
    Calculates the next L1 block number to search for the latest committed batch.

    ## Parameters
    - `value_if_nil`: The default value to return if no committed batch is found.

    ## Returns
    - The next L1 block number after the latest committed batch or `value_if_nil` if no committed batches are found.
  """
  @spec l1_block_to_discover_latest_committed_batch(FullBlock.block_number() | nil) :: FullBlock.block_number() | nil
  def l1_block_to_discover_latest_committed_batch(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_latest_committed_batch() do
      nil ->
        log_warning(@no_committed_batches_warning)
        value_if_nil

      value ->
        value + 1
    end
  end

  @doc """
    Calculates the L1 block number to start the search for committed batches.

    Returns the block number of the earliest L1 block containing a transaction
    that commits a batch, as found in the database. If no committed batches are
    found, it returns a default value. It's safe to use the returned block number
    for subsequent searches, even if it corresponds to a block we've previously
    processed. This is because multiple transactions committing different batches
    can exist within the same block, and revisiting this block ensures no batches
    are missed.

    The batch discovery process is expected to handle potential duplicates
    correctly without creating redundant database entries.

    ## Parameters
    - `value_if_nil`: The default value to return if no committed batch is found.

    ## Returns
    - The L1 block number containing the earliest committed batch or `value_if_nil`.
  """
  @spec l1_block_to_discover_earliest_committed_batch(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_to_discover_earliest_committed_batch(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_earliest_committed_batch() do
      nil ->
        log_warning(@no_committed_batches_warning)
        value_if_nil

      value ->
        value
    end
  end

  @doc """
    Retrieves the block number of the highest rollup block that has been included in a batch.

    ## Parameters
    - `value_if_nil`: The default value to return if no rollup batches are found.

    ## Returns
    - The number of the highest rollup block included in a batch
      or `value_if_nil` if no rollup batches are found.
  """
  @spec highest_committed_block(nil | integer()) :: nil | FullBlock.block_number()
  def highest_committed_block(value_if_nil)
      when is_integer(value_if_nil) or is_nil(value_if_nil) do
    case Reader.highest_committed_block() do
      nil -> value_if_nil
      value -> value
    end
  end

  @doc """
    Retrieves the L1 block number immediately following the block where the confirmation transaction
    for the highest confirmed rollup block was included.

    ## Parameters
    - `value_if_nil`: The default value to return if no confirmed rollup blocks are found.

    ## Returns
    - The L1 block number immediately after the block containing the confirmation transaction of
      the highest confirmed rollup block, or `value_if_nil` if no confirmed rollup blocks are present.
  """
  @spec l1_block_of_latest_confirmed_block(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_of_latest_confirmed_block(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_latest_confirmed_block() do
      nil ->
        log_warning("No confirmed blocks found in DB")
        value_if_nil

      value ->
        value + 1
    end
  end

  @doc """
    Retrieves the block number of the highest rollup block for which a confirmation transaction
    has been sent to L1.

    ## Parameters
    - `value_if_nil`: The default value to return if no confirmed rollup blocks are found.

    ## Returns
    - The block number of the highest confirmed rollup block,
      or `value_if_nil` if no confirmed rollup blocks are found in the database.
  """
  @spec highest_confirmed_block(nil | integer()) :: nil | FullBlock.block_number()
  def highest_confirmed_block(value_if_nil)
      when is_integer(value_if_nil) or is_nil(value_if_nil) do
    case Reader.highest_confirmed_block() do
      nil -> value_if_nil
      value -> value
    end
  end

  @doc """
    Retrieves the block number associated with a specific hash of a rollup block.

    ## Parameters
    - `hash`: The hash of the rollup block whose number is to be retrieved.

    ## Returns
    - The block number associated with the given rollup block hash.
  """
  @spec rollup_block_hash_to_num(binary()) :: FullBlock.block_number() | nil
  def rollup_block_hash_to_num(hash) when is_binary(hash) do
    Reader.rollup_block_hash_to_num(hash)
  end

  @doc """
    Retrieves the L1 batch that includes a specified rollup block number.

    ## Parameters
    - `num`: The block number of the rollup block for which the containing
      L1 batch is to be retrieved.

    ## Returns
    - The `Explorer.Chain.Arbitrum.L1Batch` associated with the given rollup block number
      if it exists and its commit transaction is loaded.
  """
  @spec get_batch_by_rollup_block_number(FullBlock.block_number()) :: Arbitrum.L1Batch.t() | nil
  def get_batch_by_rollup_block_number(num)
      when is_integer(num) and num >= 0 do
    case Reader.get_batch_by_rollup_block_number(num) do
      nil ->
        nil

      batch ->
        case batch.commitment_transaction do
          nil ->
            raise commitment_transaction_not_loaded_error(num)

          %Ecto.Association.NotLoaded{} ->
            raise commitment_transaction_not_loaded_error(num)

          _ ->
            batch
        end
    end
  end

  # Constructs an error message for when a commitment transaction is not loaded
  @spec commitment_transaction_not_loaded_error(FullBlock.block_number()) :: String.t()
  defp commitment_transaction_not_loaded_error(batch_number) do
    "Incorrect state of the DB: commitment_transaction is not loaded for the batch with number #{batch_number}"
  end

  @doc """
    Retrieves a batch by its number.

    ## Parameters
    - `number`: The number of a rollup batch.

    ## Returns
    - An instance of `Explorer.Chain.Arbitrum.L1Batch`, or `nil` if no batch with
      such a number is found.
  """
  @spec get_batch_by_number(non_neg_integer()) :: Arbitrum.L1Batch.t() | nil
  def get_batch_by_number(number) do
    Reader.get_batch_by_number(number)
  end

  @doc """
    Retrieves rollup blocks within the specified range from `first_block` to `last_block`, inclusive,
    that either:
    - Have not been confirmed yet, or
    - May need re-confirmation due to potentially incorrect confirmation assignments

    ## Parameters
    - `first_block`: The rollup block number starting the lookup range.
    - `last_block`: The rollup block number ending the lookup range.

    ## Returns
    - A list of maps, each representing an unconfirmed rollup block within the specified range,
      ordered by block_number in ascending order. If no unconfirmed blocks are found within
      the range, an empty list is returned.
  """
  @spec unconfirmed_rollup_blocks(FullBlock.block_number(), FullBlock.block_number()) :: [
          Arbitrum.BatchBlock.to_import()
        ]
  def unconfirmed_rollup_blocks(first_block, last_block)
      when is_integer(first_block) and first_block >= 0 and
             is_integer(last_block) and first_block <= last_block do
    # Get truly unconfirmed blocks first
    unconfirmed_blocks = Reader.unconfirmed_rollup_blocks(first_block, last_block)

    # If there are unconfirmed blocks, check if we need to add more blocks for re-confirmation
    blocks_to_transform =
      case unconfirmed_blocks do
        [] ->
          []

        blocks ->
          # Since blocks are in descending order, the first one is the highest unconfirmed
          highest_unconfirmed = hd(blocks)

          # If the highest unconfirmed block is not the last_block, it means last_block is already confirmed
          # but potentially with wrong transaction. Get all blocks from highest_unconfirmed + 1 to last_block
          if highest_unconfirmed.block_number < last_block do
            # Get blocks eligible for re-confirmation and combine with truly unconfirmed blocks
            reconfirmation_blocks = Reader.rollup_blocks_by_range(highest_unconfirmed.block_number + 1, last_block)
            reconfirmation_blocks ++ blocks
          else
            blocks
          end
      end

    # Transform blocks to the expected format and maintain ascending order
    blocks_to_transform
    |> Enum.reverse()
    |> Enum.map(&rollup_block_to_map/1)
  end

  @doc """
    Counts the number of confirmed rollup blocks in a specified batch.

    ## Parameters
    - `batch_number`: The batch number for which the count of confirmed rollup blocks
      is to be determined.

    ## Returns
    - A number of rollup blocks confirmed in the specified batch.
  """
  @spec count_confirmed_rollup_blocks_in_batch(non_neg_integer()) :: non_neg_integer()
  def count_confirmed_rollup_blocks_in_batch(batch_number)
      when is_integer(batch_number) and batch_number >= 0 do
    Reader.count_confirmed_rollup_blocks_in_batch(batch_number)
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
  @spec batches_exist([non_neg_integer()]) :: [non_neg_integer()]
  def batches_exist(batches_numbers) when is_list(batches_numbers) do
    Reader.batches_exist(batches_numbers)
  end

  @doc """
    Identifies the range of L1 blocks to investigate for missing confirmations of rollup blocks.

    This function determines the L1 block numbers bounding the interval where gaps in rollup block
    confirmations might exist. It uses the highest confirmed block and the highest unconfirmed block
    below it to define this range.

    The function uses a series of targeted queries instead of a single comprehensive query for
    better performance and stability. This approach:
    1. Avoids expensive table scans and grouping operations on large datasets
    2. Leverages existing indexes more effectively
    3. Reduces memory usage by fetching only necessary data
    4. Prevents query timeouts that can occur with complex joins and window functions
    5. Makes better use of the (confirmation_id, block_number DESC) index for unconfirmed blocks

    The function handles several cases:
    1. No confirmed blocks in DB:
       - Returns `{nil, right_pos_value_if_nil}`
    2. All blocks are confirmed:
       - Returns `{nil, l1_block - 1}` where l1_block is the L1 block number where the earliest
         batch-discovered block was confirmed
    3. Unconfirmed blocks in the middle:
       - Returns `{lower_l1_block + 1, upper_l1_block - 1}` where:
         * lower_l1_block is the L1 block containing confirmation for the highest confirmed block below the gap
         * upper_l1_block is the L1 block containing confirmation for the lowest confirmed block above the gap
    4. All unconfirmed blocks at the bottom:
       - Returns `{nil, upper_l1_block - 1}` where upper_l1_block is the L1 block containing
         confirmation for the lowest confirmed block above the unconfirmed range

    ## Parameters
    - `right_pos_value_if_nil`: The default value to use for the upper bound of the range if no
      confirmed blocks found.

    ## Returns
    - A tuple containing two elements: the lower and upper bounds of L1 block numbers to check
      for missing rollup block confirmations. If the necessary confirmation data is unavailable,
      the first element will be `nil`, and the second will be `right_pos_value_if_nil`.
  """
  @spec l1_blocks_to_expect_rollup_blocks_confirmation(nil | FullBlock.block_number()) ::
          {nil | FullBlock.block_number(), nil | FullBlock.block_number()}
  def l1_blocks_to_expect_rollup_blocks_confirmation(right_pos_value_if_nil) do
    with {:highest_confirmed, highest_confirmed} when not is_nil(highest_confirmed) <-
           {:highest_confirmed, Reader.highest_confirmed_block()},
         {:highest_unconfirmed, highest_unconfirmed} when not is_nil(highest_unconfirmed) <-
           {:highest_unconfirmed, Reader.highest_unconfirmed_block_below(highest_confirmed)} do
      case {Reader.l1_block_of_closest_confirmed_block_above(highest_unconfirmed),
            Reader.l1_block_of_closest_confirmed_block_below(highest_unconfirmed)} do
        {{:ok, upper_l1_block}, {:ok, lower_l1_block}} ->
          # Unconfirmed blocks in the middle
          {lower_l1_block + 1, upper_l1_block - 1}

        {{:ok, upper_l1_block}, {:error, :not_found}} ->
          # All unconfirmed blocks at the bottom
          {nil, upper_l1_block - 1}

        {{:error, _}, _} ->
          # Error case: DB is inconsistent: although there should not be any unconfirmed blocks
          # above the highest unconfirmed block, we cannot find the confirmations transaction
          # for one of the block higher than the highest unconfirmed block.
          raise "DB is inconsistent: could not get the L1 block of the closest confirmed block above the highest unconfirmed block"
      end
    else
      {:highest_confirmed, nil} ->
        # Either the database is empty or all blocks are unconfirmed.
        log_warning("No confirmed blocks found in DB")
        {nil, right_pos_value_if_nil}

      {:highest_unconfirmed, nil} ->
        # All blocks discovered by the batch fetcher are confirmed. But there
        # is a chance that in the next iteration it could be found new blocks
        # below the earliest confirmed block and they are not confirmed yet.
        {nil, Reader.l1_block_of_earliest_block_confirmation() - 1}
    end
  end

  @doc """
    Retrieves L1 block ranges that could be used to re-discover missing batches
    within a specified range of batch numbers.

    This function identifies the L1 block ranges corresponding to missing L1 batches
    within the given range of batch numbers. It first finds the missing batches,
    then determines their neighboring ranges, and finally maps these ranges to the
    corresponding L1 block numbers.

    ## Parameters
    - `start_batch_number`: The starting batch number of the search range.
    - `end_batch_number`: The ending batch number of the search range.
    - `block_for_batch_0`: The L1 block number corresponding to the batch number 0.

    ## Returns
    - A list of tuples, each containing a start and end L1 block number for the
      ranges corresponding to the missing batches.

    ## Examples

    Example #1
    - Within the range from 1 to 10, the missing batch is 2. The L1 block for the
      batch #1 is 10, and the L1 block for the batch #3 is 31.
    - The output will be `[{10, 31}]`.

    Example #2
    - Within the range from 1 to 10, the missing batches are 2 and 6, and
      - The L1 block for the batch #1 is 10.
      - The L1 block for the batch #3 is 31.
      - The L1 block for the batch #5 is 64.
      - The L1 block for the batch #7 is 90.
    - The output will be `[{10, 31}, {64, 90}]`.

    Example #3
    - Within the range from 1 to 10, the missing batches are 2 and 4, and
      - The L1 block for the batch #1 is 10.
      - The L1 block for the batch #3 is 31.
      - The L1 block for the batch #5 is 64.
    - The output will be `[{10, 31}, {32, 64}]`.

    Example #4
    - Within the range from 1 to 10, the missing batches are 2 and 4, and
      - The L1 block for the batch #1 is 10.
      - The L1 block for the batch #3 is 31.
      - The L1 block for the batch #5 is 31.
    - The output will be `[{10, 31}]`.
  """
  @spec get_l1_block_ranges_for_missing_batches(non_neg_integer(), non_neg_integer(), FullBlock.block_number()) :: [
          {FullBlock.block_number(), FullBlock.block_number()}
        ]
  def get_l1_block_ranges_for_missing_batches(start_batch_number, end_batch_number, block_for_batch_0)
      when is_integer(start_batch_number) and is_integer(end_batch_number) and end_batch_number >= start_batch_number do
    # credo:disable-for-lines:4 Credo.Check.Refactor.PipeChainStart
    neighbors_of_missing_batches =
      Reader.find_missing_batches(start_batch_number, end_batch_number)
      |> list_to_chunks()
      |> chunks_to_neighbor_ranges()

    batches_gaps_to_block_ranges(neighbors_of_missing_batches, block_for_batch_0)
  end

  # Splits a list into chunks of consecutive numbers, e.g., [1, 2, 3, 5, 6, 8] becomes [[1, 2, 3], [5, 6], [8]].
  @spec list_to_chunks([non_neg_integer()]) :: [[non_neg_integer()]]
  defp list_to_chunks(list) do
    chunk_fun = fn current, acc ->
      case acc do
        [] ->
          {:cont, [current]}

        [last | _] = acc when current == last + 1 ->
          {:cont, [current | acc]}

        acc ->
          {:cont, Enum.reverse(acc), [current]}
      end
    end

    after_fun = fn acc ->
      case acc do
        # Special case to handle the situation when the initial list is empty
        [] -> {:cont, []}
        _ -> {:cont, Enum.reverse(acc), []}
      end
    end

    list
    |> Enum.chunk_while([], chunk_fun, after_fun)
  end

  # Converts chunks of elements into neighboring ranges, e.g., [[1, 2], [4]] becomes [{0, 3}, {3, 5}].
  @spec chunks_to_neighbor_ranges([[non_neg_integer()]]) :: [{non_neg_integer(), non_neg_integer()}]
  defp chunks_to_neighbor_ranges([]), do: []

  defp chunks_to_neighbor_ranges(list_of_chunks) do
    list_of_chunks
    |> Enum.map(fn current ->
      case current do
        [one_element] -> {one_element - 1, one_element + 1}
        chunk -> {List.first(chunk) - 1, List.last(chunk) + 1}
      end
    end)
  end

  # Converts batch number gaps to L1 block ranges for missing batches discovery.
  #
  # This function takes a list of neighboring batch number ranges representing gaps
  # in the batch sequence and converts them to corresponding L1 block ranges. These
  # L1 block ranges can be used to rediscover missing batches.
  #
  # ## Parameters
  # - `neighbors_of_missing_batches`: A list of tuples, each containing the start
  #   and end batch numbers of a gap in the batch sequence.
  # - `block_for_batch_0`: The L1 block number corresponding to batch number 0.
  #
  # ## Returns
  # - A list of tuples, each containing the start and end L1 block numbers for
  #   ranges where missing batches should be rediscovered.
  @spec batches_gaps_to_block_ranges([{non_neg_integer(), non_neg_integer()}], FullBlock.block_number()) ::
          [{FullBlock.block_number(), FullBlock.block_number()}]
  defp batches_gaps_to_block_ranges(neighbors_of_missing_batches, block_for_batch_0)

  defp batches_gaps_to_block_ranges([], _), do: []

  defp batches_gaps_to_block_ranges(neighbors_of_missing_batches, block_for_batch_0) do
    l1_blocks =
      neighbors_of_missing_batches
      |> Enum.reduce(MapSet.new(), fn {start_batch, end_batch}, acc ->
        acc
        |> MapSet.put(start_batch)
        |> MapSet.put(end_batch)
      end)
      # To avoid error in getting L1 block for the batch 0
      |> MapSet.delete(0)
      |> MapSet.to_list()
      |> Reader.get_l1_blocks_of_batches_by_numbers()
      # It is safe to add the block for the batch 0 even if the batch 1 is missing
      |> Map.put(0, block_for_batch_0)

    neighbors_of_missing_batches
    |> Enum.reduce({[], %{}}, fn {start_batch, end_batch}, {res, blocks_used} ->
      range_start = l1_blocks[start_batch]
      range_end = l1_blocks[end_batch]
      # If the batch's block was already used as a block finishing one of the ranges
      # then we should start another range from the next block to avoid discovering
      # the same batches batches again.
      case {Map.get(blocks_used, range_start, false), range_start == range_end} do
        {true, true} ->
          # Edge case when the range consists of a single block (several batches in
          # the same block) which is going to be inspected up to this moment.
          {res, blocks_used}

        {true, false} ->
          {[{range_start + 1, range_end} | res], Map.put(blocks_used, range_end, true)}

        {false, _} ->
          {[{range_start, range_end} | res], Map.put(blocks_used, range_end, true)}
      end
    end)
    |> elem(0)
  end

  @doc """
    Retrieves the minimum and maximum batch numbers of L1 batches.

    ## Returns
    - A tuple containing the minimum and maximum batch numbers or `{nil, nil}` if no batches are found.
  """
  @spec get_min_max_batch_numbers() :: {non_neg_integer() | nil, non_neg_integer() | nil}
  def get_min_max_batch_numbers do
    Reader.get_min_max_batch_numbers()
  end

  @doc """
    Checks if an AnyTrust keyset exists in the database using the provided keyset hash.

    ## Parameters
    - `keyset_hash`: The hash of the keyset to be checked.

    ## Returns
    - `true` if the keyset exists, `false` otherwise.
  """
  @spec anytrust_keyset_exists?(binary()) :: boolean()
  def anytrust_keyset_exists?(keyset_hash) do
    not Enum.empty?(Reader.get_anytrust_keyset(keyset_hash))
  end

  @doc """
    Retrieves data availability records from the database for the given list of data keys.

    ## Parameters
    - `data_keys`: A list of binary data keys to search for in the database.

    ## Returns
    - A list of matching `DaMultiPurposeRecord` records in import format, or an empty list if no matches are found.
  """
  @spec da_records_by_keys([binary()]) :: [Arbitrum.DaMultiPurposeRecord.to_import()]
  def da_records_by_keys(data_keys) when is_list(data_keys) do
    data_keys
    |> Reader.da_records_by_keys()
    |> Enum.map(&da_record_to_import_format/1)
  end

  # Transforms a DaMultiPurposeRecord database record to import format
  @spec da_record_to_import_format(Arbitrum.DaMultiPurposeRecord.t()) :: Arbitrum.DaMultiPurposeRecord.to_import()
  defp da_record_to_import_format(record) do
    # Extract required fields
    required_keys = [:data_type, :data_key, :batch_number]

    # Create base map with required fields
    import_format = DbTools.db_record_to_map(required_keys, record)

    # Handle the data field separately to ensure it remains as a map
    data =
      case record.data do
        nil -> nil
        %{} = data_map -> data_map
        # Convert any other format to map if needed
        other -> other
      end

    # Add the data field to the result
    Map.put(import_format, :data, data)
  end

  @spec rollup_block_to_map(Arbitrum.BatchBlock.t()) :: Arbitrum.BatchBlock.to_import()
  defp rollup_block_to_map(block) do
    [:batch_number, :block_number, :confirmation_id]
    |> DbTools.db_record_to_map(block)
  end

  @doc """
    Retrieves the L1 block number where the confirmation transaction for a specific rollup block was included.

    ## Parameters
    - `rollup_block_number`: The number of the rollup block for which to find the confirmation L1 block.

    ## Returns
    - The L1 block number if the rollup block is confirmed and the confirmation transaction is indexed;
      `nil` otherwise.
  """
  @spec l1_block_of_confirmation_for_rollup_block(FullBlock.block_number()) :: FullBlock.block_number() | nil
  def l1_block_of_confirmation_for_rollup_block(rollup_block_number)
      when is_integer(rollup_block_number) and rollup_block_number >= 0 do
    case Reader.l1_block_of_confirmation_for_rollup_block(rollup_block_number) do
      {:ok, block_number} -> block_number
      _ -> nil
    end
  end
end
