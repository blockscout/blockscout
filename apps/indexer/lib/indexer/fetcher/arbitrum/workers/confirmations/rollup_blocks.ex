defmodule Indexer.Fetcher.Arbitrum.Workers.Confirmations.RollupBlocks do
  @moduledoc """
  Handles the discovery and marking of confirmed rollup blocks in Arbitrum.

  In Arbitrum, a confirmation (via SendRootUpdated event) indicates that all rollup blocks
  up to a specific block number are confirmed. The module discovers which blocks belong to
  each confirmation by examining batches that contain these blocks. For example, if there
  are two confirmations where the earlier one points to block N and the later to block M
  (where M > N), the module links blocks from N+1 to M to the later confirmation. Starting
  from the batch containing the confirmed top block, it recursively examines previous
  batches until it either finds a batch with all blocks already confirmed or reaches the
  chain's initial block. Within each batch, it identifies unconfirmed blocks and ensures
  their continuity to prevent gaps in the confirmation sequence.

  The module handles batch-related confirmations by ensuring block continuity within each
  batch. If a block is not yet indexed or a batch association is missing, the confirmation
  processing is postponed. The module also verifies block continuity to detect and handle
  potential database inconsistencies, ensuring that no gaps exist in the confirmed blocks
  sequence.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1, log_info: 1, log_debug: 1]

  alias Explorer.Chain.Arbitrum

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Workers.Confirmations.Events, as: EventsUtils

  require Logger

  @logs_per_report 10
  @zero_counters %{pairs_counter: 1, capped_logs_counter: 0, report?: false}

  @doc """
    Discovers and marks all rollup blocks associated with provided confirmations.

    First, converts the input map of rollup block hashes to a map keyed by block numbers,
    transforming confirmation descriptions to use block numbers instead of hashes. Then
    processes these confirmations sequentially starting from the lowest rollup block
    number, ensuring that each block is associated with the correct confirmation. This
    sequential handling preserves the confirmation history, allowing future processing
    to accurately associate blocks with their respective confirmations.

    ## Parameters
    - `rollup_blocks_to_l1_transactions`: A map linking rollup block hashes (the "top" blocks
      in confirmations) to their confirmation descriptions
    - `outbox_config`: Configuration for the Arbitrum outbox contract
    - `rollup_first_block`: The block number limiting the lowest indexed block of
      the chain

    ## Returns
    - A list of rollup blocks each associated with the transaction's hash that
      confirms the block
  """
  @spec extend_confirmations(
          %{binary() => %{l1_transaction_hash: binary(), l1_block_num: non_neg_integer()}},
          %{
            :logs_block_range => non_neg_integer(),
            :outbox_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          },
          non_neg_integer()
        ) :: [Arbitrum.BatchBlock.to_import()]
  def extend_confirmations(rollup_blocks_to_l1_transactions, outbox_config, rollup_first_block) do
    block_to_l1_transactions =
      rollup_blocks_to_l1_transactions
      |> Map.keys()
      |> Enum.reduce(%{}, fn block_hash, transformed ->
        rollup_block_num = DbSettlement.rollup_block_hash_to_num(block_hash)

        # nil is applicable for the case when the block is not indexed yet by
        # the block fetcher, it makes sense to skip this block so far
        case rollup_block_num do
          nil ->
            log_warning("The rollup block #{compress_hash(block_hash)} did not found. Plan to skip the confirmations")
            transformed

          value ->
            Map.put(transformed, value, rollup_blocks_to_l1_transactions[block_hash])
        end
      end)

    if Enum.empty?(block_to_l1_transactions) do
      []
    else
      # Oldest (with the lowest number) block is first
      rollup_block_numbers = Enum.sort(Map.keys(block_to_l1_transactions), :asc)

      rollup_block_numbers
      |> Enum.reduce([], fn block_number, updated_rollup_blocks ->
        log_info("Attempting to mark all rollup blocks including ##{block_number} and lower as confirmed")

        {_, confirmed_blocks} =
          discover_rollup_blocks_belonging_to_one_confirmation(
            block_number,
            block_to_l1_transactions[block_number],
            outbox_config,
            rollup_first_block
          )

        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        if length(confirmed_blocks) > 0 do
          log_info("Found #{length(confirmed_blocks)} confirmed blocks")

          add_confirmation_transaction(confirmed_blocks, block_to_l1_transactions[block_number].l1_transaction_hash) ++
            updated_rollup_blocks
        else
          log_info("Either no unconfirmed blocks found or DB inconsistency error discovered")
          []
        end
      end)
    end
  end

  # Takes first 6 and last 6 nibbles of the hash
  @spec compress_hash(binary()) :: binary()
  defp compress_hash("0x" <> rest = _full_hash) do
    "0x" <> String.slice(rest, 0, 6) <> "..." <> String.slice(rest, -6, 6)
  end

  # Discovers rollup blocks within a single confirmation, ensuring no gaps in the confirmed range.
  #
  # This function follows these steps to identify unconfirmed rollup blocks related
  # to a single confirmation event:
  # 1. Retrieve the batch associated with the specified rollup block number.
  # 2. Obtain a list of unconfirmed blocks within that batch. For the historical
  #    confirmations discovery, the list will include both unconfirmed blocks that
  #    are covered by the current confirmation and those that a going to be covered
  #    by the predecessor confirmation.
  # 3. Determine the first unconfirmed block in the batch. It could be the first
  #    block in the batch or a block the next after the last confirmed block in the
  #    predecessor confirmation.
  # 4. Verify the continuity of the unconfirmed blocks to be covered by the current
  #    confirmation to ensure there are no database inconsistencies or unindexed
  #    blocks.
  # 5. If the first unconfirmed block is at the start of the batch, check if the
  #    confirmation also covers blocks from previous batches. If so, include their
  #    unconfirmed blocks in the range.
  # 6. If all blocks in the previous batch are confirmed or the current batch is
  #    the first batch in the chain intended to be indexed, return the current list
  #    of unconfirmed blocks.
  # 7. If the first unconfirmed block is in the middle of the batch, return the
  #    current list of unconfirmed blocks.
  # This process continues recursively until it finds a batch with all blocks
  # confirmed, encounters a gap, or reaches the start of the chain of blocks related
  # to the confirmation.
  #
  # Cache Behavior:
  # For each new confirmation, the cache for `eth_getLogs` requests starts empty.
  # During recursive calls for previous batches, the cache fills with results for
  # specific block ranges. With the confirmation description remaining constant
  # through these calls, the cache effectively reduces the number of requests by
  # reusing results for events related to previous batches within the same block
  # ranges. Although the same logs might be re-requested for other confirmations
  # within the same discovery iteration, the cache is not shared across different
  # confirmations and resets for each new confirmation. Extending cache usage
  # across different confirmations would require additional logic to match block
  # ranges and manage cache entries, significantly complicating cache handling.
  # Given the rarity of back-to-back confirmations in the same iteration of
  # discovery in a production environment, the added complexity of shared caching
  # is deemed excessive.
  #
  # ## Parameters
  # - `rollup_block_num`: The rollup block number associated with the confirmation.
  # - `confirmation_desc`: Description of the latest confirmation.
  # - `outbox_config`: Configuration for the Arbitrum outbox contract.
  # - `rollup_first_block`: The block number limiting the lowest indexed block of
  #   the chain.
  # - `cache`: A cache to minimize repetitive `eth_getLogs` calls.
  #
  # ## Returns
  # - `{:ok, unconfirmed_blocks}`: A list of rollup blocks that are confirmed by
  #   the current confirmation but not yet marked as confirmed in the database.
  # - `{:error, []}`: If a discrepancy or inconsistency is found during the
  #   discovery process.
  @spec discover_rollup_blocks_belonging_to_one_confirmation(
          non_neg_integer(),
          %{:l1_block_num => non_neg_integer(), optional(any()) => any()},
          %{
            :logs_block_range => non_neg_integer(),
            :outbox_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          },
          non_neg_integer(),
          EventsUtils.cached_logs()
        ) :: {:ok, [Arbitrum.BatchBlock.to_import()]} | {:error, []}
  defp discover_rollup_blocks_belonging_to_one_confirmation(
         rollup_block_num,
         confirmation_desc,
         outbox_config,
         rollup_first_block,
         cache \\ %{}
       ) do
    # The following batch fields are required in the further processing:
    # number, start_block, end_block, commitment_transaction.block_number
    with {:ok, batch} <- get_batch(rollup_block_num),
         {:ok, raw_unconfirmed_rollup_blocks} when raw_unconfirmed_rollup_blocks != [] <-
           get_unconfirmed_rollup_blocks(batch, rollup_block_num),
         # It is not the issue to request logs for the first call of
         # discover_rollup_blocks_belonging_to_one_confirmation since we need
         # to make sure that there is no another confirmation for part of the
         # blocks of the batch.
         # If it returns `{:ok, []}` it will be passed as the return value of
         # discover_rollup_blocks_belonging_to_one_confirmation function.
         {:ok, {first_unconfirmed_block, new_cache}} <-
           check_confirmed_blocks_of_batch(rollup_block_num, batch, confirmation_desc, outbox_config, cache),
         {:ok, unconfirmed_rollup_blocks} <-
           check_consecutive_rollup_blocks(
             raw_unconfirmed_rollup_blocks,
             first_unconfirmed_block,
             rollup_block_num,
             batch.number
           ) do
      # For the case when the first unconfirmed block in the batch is the batch start block
      # it is the lowest indexed block of the chain, there is no need to deep dive into the
      # previous batches
      if first_unconfirmed_block == batch.start_block and
           not genesis_reached?(first_unconfirmed_block, rollup_first_block) do
        log_info("End of the batch #{batch.number} discovered, moving to the previous batch")

        {status, updated_rollup_blocks} =
          discover_rollup_blocks_belonging_to_one_confirmation(
            first_unconfirmed_block - 1,
            confirmation_desc,
            outbox_config,
            rollup_first_block,
            new_cache
          )

        case status do
          :error -> {:error, []}
          # updated_rollup_blocks will contain either [] if the previous batch
          # already confirmed or list of unconfirmed blocks of all previous
          # unconfirmed batches
          :ok -> {:ok, unconfirmed_rollup_blocks ++ updated_rollup_blocks}
        end
      else
        # During the process of new confirmations discovery it will show "N of N",
        # for the process of historical confirmations discovery it will show "N of M".
        log_info(
          "#{length(unconfirmed_rollup_blocks)} of #{length(raw_unconfirmed_rollup_blocks)} blocks in the batch ##{batch.number} corresponds to current confirmation"
        )

        {:ok, unconfirmed_rollup_blocks}
      end
    end
  end

  # Determines if a rollup block number has reached the lowest indexed block of the chain.
  #
  # ## Parameters
  # - `rollup_block_num`: The rollup block number to check
  # - `rollup_first_block`: The block number limiting the lowest indexed block of
  #   the chain.
  #
  # ## Returns
  # - `true` if the block number has reached genesis, `false` otherwise
  @spec genesis_reached?(non_neg_integer(), non_neg_integer()) :: boolean()
  defp genesis_reached?(rollup_block_num, rollup_first_block) do
    # If it is assumed that rollup_block_num is the number of a block included in a batch, then
    # the first part of the condition covers the case when the first rollup block is configured
    # explicitly (not 0) and it can be a part of any batch. The second part of the condition
    # covers the case when the first rollup block is 0, which cannot be included in any batch,
    # so rollup_block_num belongs to the first batch.
    rollup_block_num <= rollup_first_block or rollup_block_num - 1 <= 0
  end

  # Retrieves the batch containing the specified rollup block and logs the attempt.
  @spec get_batch(non_neg_integer()) :: {:ok, Arbitrum.L1Batch.t()} | {:error, []}
  defp get_batch(rollup_block_num) do
    # Note: No sense in moving this function to Db.Settlement since it contains module
    # specific logs

    # Generally if batch is nil it means either
    # - a batch to a rollup block association is not found, not recoverable
    # - a rollup block is not found, the corresponding batch is not handled yet. It is possible
    #   because the method can be called for guessed block number rather than received from
    #   the batch description or from blocks list received after a batch handling. In this case
    #   the confirmation must be postponed until the corresponding batch is handled.
    batch = DbSettlement.get_batch_by_rollup_block_number(rollup_block_num)

    if batch != nil do
      log_info(
        "Attempt to identify which blocks of the batch ##{batch.number} within ##{batch.start_block}..##{rollup_block_num} are confirmed"
      )

      {:ok, batch}
    else
      log_warning(
        "Batch where the block ##{rollup_block_num} was included is not found, skipping this blocks and lower"
      )

      {:error, []}
    end
  end

  # Identifies unconfirmed rollup blocks within a batch up to specified block
  # number, checking for potential synchronization issues.
  @spec get_unconfirmed_rollup_blocks(
          Arbitrum.L1Batch.t(),
          non_neg_integer()
        ) :: {:ok, [Arbitrum.BatchBlock.to_import()]} | {:error, []}
  defp get_unconfirmed_rollup_blocks(batch, rollup_block_num) do
    # Note: No sense in moving this function to Db.Settlement since it contains module
    # specific logs

    unconfirmed_rollup_blocks = DbSettlement.unconfirmed_rollup_blocks(batch.start_block, rollup_block_num)

    if Enum.empty?(unconfirmed_rollup_blocks) do
      # Blocks are not found only in case when all blocks in the batch confirmed
      # or in case when Chain.Block for block in the batch are not received yet

      if DbSettlement.count_confirmed_rollup_blocks_in_batch(batch.number) == batch.end_block - batch.start_block + 1 do
        log_info("No unconfirmed blocks in the batch #{batch.number}")
        {:ok, []}
      else
        log_warning("Seems that the batch #{batch.number} was not fully synced. Skipping its blocks")
        {:error, []}
      end
    else
      {:ok, unconfirmed_rollup_blocks}
    end
  end

  # Identifies the first block in the batch that is not yet confirmed.
  #
  # This function attempts to find a `SendRootUpdated` event between the already
  # discovered confirmation and the L1 block where the batch was committed, that
  # mentions any block of the batch as the top of the confirmed blocks. Depending
  # on the lookup result, it either considers the found block or the very
  # first block of the batch as the start of the range of unconfirmed blocks ending
  # with `rollup_block_num`.
  # To optimize `eth_getLogs` calls required for the `SendRootUpdated` event lookup,
  # it uses a cache.
  # Since this function only discovers the number of the unconfirmed block, it does
  # not check continuity of the unconfirmed blocks range in the batch.
  #
  # ## Parameters
  # - `rollup_block_num`: The rollup block number to check for confirmation.
  # - `batch`: The batch containing the rollup blocks.
  # - `confirmation_desc`: Details of the latest confirmation.
  # - `outbox_config`: Configuration for the Arbitrum outbox contract.
  # - `cache`: A cache to minimize `eth_getLogs` calls.
  #
  # ## Returns
  # - `{:ok, []}` when all blocks in the batch are already confirmed.
  # - `{:error, []}` when a potential database inconsistency or unprocessed batch is
  #   found.
  # - `{:ok, {first_unconfirmed_block_in_batch, new_cache}}` with the number of the
  #   first unconfirmed block in the batch and updated cache.
  @spec check_confirmed_blocks_of_batch(
          non_neg_integer(),
          Arbitrum.L1Batch.t(),
          %{:l1_block_num => non_neg_integer(), optional(any()) => any()},
          %{
            :logs_block_range => non_neg_integer(),
            :outbox_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          },
          EventsUtils.cached_logs()
        ) :: {:ok, {non_neg_integer(), EventsUtils.cached_logs()}} | {:ok, []} | {:error, []}
  defp check_confirmed_blocks_of_batch(
         rollup_block_num,
         batch,
         confirmation_desc,
         outbox_config,
         cache
       ) do
    # This function might look like over-engineered, but confirmations are not always
    # aligned with the boundaries of a batch unfortunately.

    {status, block?, new_cache} =
      check_if_batch_confirmed(batch, confirmation_desc, outbox_config, rollup_block_num, cache)

    case {status, block? == rollup_block_num} do
      {:error, _} ->
        {:error, []}

      {_, true} ->
        log_info("All the blocks in the batch ##{batch.number} have been already confirmed by another transaction")
        # Though the response differs from another `:ok` response in the function,
        # it is assumed that this case will be handled by the invoking function.
        {:ok, []}

      {_, false} ->
        first_unconfirmed_block_in_batch =
          case block? do
            nil ->
              batch.start_block

            value ->
              log_info("Blocks up to ##{value} of the batch have been already confirmed by another transaction")
              value + 1
          end

        {:ok, {first_unconfirmed_block_in_batch, new_cache}}
    end
  end

  # Checks if any rollup blocks within a batch are confirmed by scanning `SendRootUpdated` events.
  #
  # This function uses the L1 block range from batch's commit transaction block to
  # the block before the latest confirmation to search for `SendRootUpdated` events.
  # These events indicate the top confirmed rollup block. To optimize `eth_getLogs`
  # calls, it uses a cache and requests logs in chunked block ranges.
  #
  # ## Parameters
  # - `batch`: The batch to check for confirmed rollup blocks.
  # - `confirmation_desc`: Description of the latest confirmation details.
  # - `l1_outbox_config`: Configuration for the L1 outbox contract, including block
  #   range for logs retrieval.
  # - `highest_unconfirmed_block`: The batch's highest rollup block number which is
  #    considered as unconfirmed.
  # - `cache`: A cache for the logs to reduce the number of `eth_getLogs` calls.
  #
  # ## Returns
  # - `{:ok, highest_confirmed_rollup_block, new_cache}`:
  #   - `highest_confirmed_rollup_block` is the highest rollup block number confirmed
  #      within the batch.
  #   - `new_cache` contains the updated logs cache.
  # - `{:ok, nil, new_cache}` if no rollup blocks within the batch are confirmed.
  #   - `new_cache` contains the updated logs cache.
  # - `{:error, nil, new_cache}` if an error occurs during the log fetching process,
  #   such as when a rollup block corresponding to a given hash is not found in the
  #   database.
  #   - `new_cache` contains the updated logs cache despite the error.
  @spec check_if_batch_confirmed(
          Arbitrum.L1Batch.t(),
          %{:l1_block_num => non_neg_integer(), optional(any()) => any()},
          %{
            :logs_block_range => non_neg_integer(),
            :outbox_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          },
          non_neg_integer(),
          EventsUtils.cached_logs()
        ) :: {:ok, nil | non_neg_integer(), EventsUtils.cached_logs()} | {:error, nil, EventsUtils.cached_logs()}
  defp check_if_batch_confirmed(batch, confirmation_desc, l1_outbox_config, highest_unconfirmed_block, cache) do
    log_info(
      "Use L1 blocks #{batch.commitment_transaction.block_number}..#{confirmation_desc.l1_block_num - 1} to look for a rollup block confirmation within #{batch.start_block}..#{highest_unconfirmed_block} of ##{batch.number}"
    )

    block_pairs =
      l1_blocks_pairs_to_get_logs(
        batch.commitment_transaction.block_number,
        confirmation_desc.l1_block_num - 1,
        l1_outbox_config.logs_block_range
      )

    block_pairs_length = length(block_pairs)

    {status, block, new_cache, _} =
      block_pairs
      |> Enum.reduce_while({:ok, nil, cache, @zero_counters}, fn {log_start, log_end},
                                                                 {_, _, updated_cache, counters} ->
        {status, latest_block_confirmed, new_cache, logs_amount} =
          do_check_if_batch_confirmed(
            {batch.start_block, batch.end_block},
            {log_start, log_end},
            l1_outbox_config,
            updated_cache
          )

        case {status, latest_block_confirmed} do
          {:error, _} ->
            {:halt, {:error, nil, new_cache, @zero_counters}}

          {_, nil} ->
            next_counters = next_counters(counters, logs_amount)

            # credo:disable-for-lines:3 Credo.Check.Refactor.Nesting
            if next_counters.report? and block_pairs_length != next_counters.pairs_counter do
              log_info("Examined #{next_counters.pairs_counter - 1} of #{block_pairs_length} L1 block ranges")
            end

            {:cont, {:ok, nil, new_cache, next_counters}}

          {_, previous_confirmed_rollup_block} ->
            log_info("Confirmed block ##{previous_confirmed_rollup_block} for the batch found")
            {:halt, {:ok, previous_confirmed_rollup_block, new_cache, @zero_counters}}
        end
      end)

    {status, block, new_cache}
  end

  # Generates descending order pairs of start and finish block numbers, ensuring
  # identical beginning pairs for the same finish block and max range.
  # Examples:
  # l1_blocks_pairs_to_get_logs(1, 10, 3) -> [{8, 10}, {5, 7}, {2, 4}, {1, 1}]
  # l1_blocks_pairs_to_get_logs(5, 10, 3) -> [{8, 10}, {5, 7}]
  @spec l1_blocks_pairs_to_get_logs(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: [
          {non_neg_integer(), non_neg_integer()}
        ]
  defp l1_blocks_pairs_to_get_logs(start, finish, max_range) do
    # credo:disable-for-lines:9 Credo.Check.Refactor.PipeChainStart
    Stream.unfold(finish, fn cur_finish ->
      if cur_finish < start do
        nil
      else
        cur_start = max(cur_finish - max_range + 1, start)
        {{cur_start, cur_finish}, cur_start - 1}
      end
    end)
    |> Enum.to_list()
  end

  # Scans `SendRootUpdated` events in the given L1 block range to find the highest
  # rollup block within the specified range that has been confirmed. Uses caching
  # to minimize `eth_getLogs` calls.
  #
  # ## Parameters
  # - `{rollup_start_block, rollup_end_block}`: Range of rollup blocks to check
  # - `{log_start, log_end}`: Range of L1 blocks to scan for events
  # - `l1_outbox_config`: Arbitrum Outbox contract configuration
  # - `cache`: Cache of previously fetched logs
  #
  # ## Returns
  # - `{:ok, block_num, new_cache, logs_length}`: Found confirmed block in range
  # - `{:ok, nil, new_cache, logs_length}`: No confirmed blocks in range
  # - `{:error, nil, new_cache, logs_length}`: Block hash resolution failed
  @spec do_check_if_batch_confirmed(
          {non_neg_integer(), non_neg_integer()},
          {non_neg_integer(), non_neg_integer()},
          %{
            :outbox_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          },
          EventsUtils.cached_logs()
        ) ::
          {:ok, nil | non_neg_integer(), EventsUtils.cached_logs(), non_neg_integer()}
          | {:error, nil, EventsUtils.cached_logs(), non_neg_integer()}
  defp do_check_if_batch_confirmed(
         batch_block_range,
         {log_start, log_end},
         l1_outbox_config,
         cache
       ) do
    case EventsUtils.fetch_and_sort_confirmations_logs(log_start, log_end, l1_outbox_config, cache) do
      {:error, nil, new_cache, logs_length} ->
        {:error, nil, new_cache, logs_length}

      # For every discovered event check if the rollup block in the confirmation
      # is within the specified range which usually means that the event
      # is the confirmation of the batch described by the range.
      {:ok, sorted_block_numbers, new_cache, logs_length} ->
        latest_block_confirmed = find_first_block_in_range(sorted_block_numbers, batch_block_range)
        {:ok, latest_block_confirmed, new_cache, logs_length}
    end
  end

  # Finds the first block number from the sorted list that falls within the specified range.
  @spec find_first_block_in_range([non_neg_integer()], {non_neg_integer(), non_neg_integer()}) ::
          non_neg_integer() | nil
  defp find_first_block_in_range(sorted_block_numbers, {start_block, end_block}) do
    Enum.find_value(sorted_block_numbers, nil, fn block_num ->
      if block_num >= start_block and block_num <= end_block do
        log_debug("The rollup block ##{block_num} within the range")
        block_num
      else
        log_debug("The rollup block ##{block_num} outside of the range")
        nil
      end
    end)
  end

  # Simplifies the process of updating counters for the `eth_getLogs` requests
  # to be used for logging purposes.
  @spec next_counters(
          %{:pairs_counter => non_neg_integer(), :capped_logs_counter => non_neg_integer(), optional(any()) => any()},
          non_neg_integer()
        ) :: %{
          :pairs_counter => non_neg_integer(),
          :capped_logs_counter => non_neg_integer(),
          :report? => boolean()
        }
  defp next_counters(%{pairs_counter: pairs_counter, capped_logs_counter: capped_logs_counter}, logs_amount) do
    %{
      pairs_counter: pairs_counter + 1,
      capped_logs_counter: rem(capped_logs_counter + logs_amount, @logs_per_report),
      report?: div(capped_logs_counter + logs_amount, @logs_per_report) > 0
    }
  end

  # Returns consecutive rollup blocks within the range of lowest_confirmed_block..highest_confirmed_block
  # assuming that the list of unconfirmed rollup blocks finishes on highest_confirmed_block and
  # is sorted by block number
  @spec check_consecutive_rollup_blocks(
          [Arbitrum.BatchBlock.to_import()],
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: {:ok, [Arbitrum.BatchBlock.to_import()]} | {:error, []}
  defp check_consecutive_rollup_blocks(
         all_unconfirmed_rollup_blocks,
         lowest_confirmed_block,
         highest_confirmed_block,
         batch_number
       ) do
    {status, unconfirmed_rollup_blocks} =
      check_consecutive_rollup_blocks_and_cut(all_unconfirmed_rollup_blocks, lowest_confirmed_block)

    unconfirmed_rollup_blocks_length = length(unconfirmed_rollup_blocks)
    expected_blocks_range_length = highest_confirmed_block - lowest_confirmed_block + 1

    case {status, unconfirmed_rollup_blocks_length == expected_blocks_range_length} do
      {true, true} ->
        {:ok, unconfirmed_rollup_blocks}

      {true, false} ->
        log_warning(
          "Only #{unconfirmed_rollup_blocks_length} of #{expected_blocks_range_length} blocks found. Skipping the blocks from the batch #{batch_number}"
        )

        {:error, []}

      _ ->
        # The case when there is a gap in the blocks range is possible when there is
        # a DB inconsistency. From another side, the case when the confirmation is for blocks
        # in two batches -- one batch has been already indexed, another one has not been yet.
        # Both cases should be handled in the same way - this confirmation must be postponed
        # until the case resolution.
        log_warning("Skipping the blocks from the batch #{batch_number}")
        {:error, []}
    end
  end

  # Checks for consecutive rollup blocks starting from the lowest confirmed block
  # and returns the status and the list of consecutive blocks.
  #
  # This function processes a list of rollup blocks to verify if they are consecutive,
  # starting from the `lowest_confirmed_block`. If a gap is detected between the
  # blocks, the process halts and returns false along with an empty list. If all
  # blocks are consecutive, it returns true along with the list of consecutive
  # blocks.
  #
  # ## Parameters
  # - `blocks`: A list of rollup blocks to check.
  # - `lowest_confirmed_block`: The lowest confirmed block number to start the check.
  #
  # ## Returns
  # - A tuple where the first element is a boolean indicating if all blocks are
  #   consecutive, and the second element is the list of consecutive blocks if the
  #   first element is true, otherwise an empty list.
  @spec check_consecutive_rollup_blocks_and_cut([Arbitrum.BatchBlock.to_import()], non_neg_integer()) ::
          {boolean(), [Arbitrum.BatchBlock.to_import()]}
  defp check_consecutive_rollup_blocks_and_cut(blocks, lowest_confirmed_block) do
    {_, status, cut_blocks} =
      Enum.reduce_while(blocks, {nil, false, []}, fn block, {prev, _, cut_blocks} ->
        case {prev, block.block_number >= lowest_confirmed_block} do
          {nil, true} ->
            {:cont, {block.block_number, true, [block | cut_blocks]}}

          {value, true} ->
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            if block.block_number - 1 == value do
              {:cont, {block.block_number, true, [block | cut_blocks]}}
            else
              log_warning("A gap between blocks ##{value} and ##{block.block_number} found")
              {:halt, {block.block_number, false, []}}
            end

          {_, false} ->
            {:cont, {nil, false, []}}
        end
      end)

    {status, cut_blocks}
  end

  # Adds the confirmation transaction hash to each rollup block description in the list.
  @spec add_confirmation_transaction([Arbitrum.BatchBlock.to_import()], binary()) :: [Arbitrum.BatchBlock.to_import()]
  defp add_confirmation_transaction(block_descriptions_list, confirm_transaction_hash) do
    block_descriptions_list
    |> Enum.reduce([], fn block_descr, updated ->
      new_block_descr =
        block_descr
        |> Map.put(:confirmation_transaction, confirm_transaction_hash)

      [new_block_descr | updated]
    end)
  end
end
