defmodule Indexer.Fetcher.Arbitrum.Workers.NewConfirmations do
  @moduledoc """
    Handles the discovery and processing of new and historical confirmations of rollup blocks for an Arbitrum rollup.

    This module orchestrates the discovery of rollup block confirmations delivered
    to the Arbitrum Outbox contract. It distinguishes between new confirmations of
    rollup blocks and past confirmations that were previously unprocessed or missed.

    The process involves fetching logs for the `SendRootUpdated` events emitted by
    the Arbitrum Outbox contract. These events indicate the top of the rollup blocks
    confirmed up to a specific point in time. The identified block is used to find
    all blocks beneath it that are not confirmed by other `SendRootUpdated` events.
    All discovered blocks are then linked with the corresponding transaction that
    emitted the `SendRootUpdated` event. Additionally, L2-to-L1 messages included in
    the rollup blocks up to the confirmed top are identified to change their status
    from `:sent` to `:confirmed`.

    Though the `SendRootUpdated` event implies that all rollup blocks below the
    mentioned block are confirmed, the current design of the process attempts to
    match every rollup block to a specific confirmation. This means that if there
    are two confirmations, and the earlier one points to block N while the later
    points to block M (such that M > N), the blocks from N+1 to M are linked with
    the latest confirmation, and blocks from X+1 to N are linked to the earlier
    confirmation (where X is the rollup block mentioned in an even earlier
    confirmation).

    Currently, the process of discovering confirmed rollup blocks works with any
    position of the top confirmed block in a batch. Later, if it is confirmed that
    the top block in a confirmation always aligns with the last block in a batch,
    this approach to rollup block discovery can be revisited for simplification.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1, log_info: 1, log_debug: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber
  alias Indexer.Helper, as: IndexerHelper

  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Rpc}
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum

  require Logger

  @typedoc """
    A map containing list of transaction logs for a specific block range.
    - the key is the tuple with the start and end of the block range
    - the value is the list of transaction logs received for the block range
  """
  @type cached_logs :: %{{non_neg_integer(), non_neg_integer()} => [%{String.t() => any()}]}

  @logs_per_report 10
  @zero_counters %{pairs_counter: 1, capped_logs_counter: 0, report?: false}

  # keccak256("SendRootUpdated(bytes32,bytes32)")
  @send_root_updated_event "0xb4df3847300f076a369cd76d2314b470a1194d9e8a6bb97f1860aee88a5f6748"

  @doc """
    Discovers and processes new confirmations of rollup blocks within a calculated block range.

    This function identifies the appropriate L1 block range for discovering new
    rollup confirmations. It fetches logs representing `SendRootUpdated` events
    within this range to identify the new tops of rollup block confirmations. The
    discovered confirmations are processed to update the status of rollup blocks
    and L2-to-L1 messages accordingly. Eventually, updated rollup blocks,
    cross-chain messages, and newly constructed lifecycle transactions are imported
    into the database.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including the L1 outbox address, L1 RPC
                  configurations.
      - `data`: Contains the starting L1 block number from which to begin the new
                confirmation discovery.

    ## Returns
    - `{retcode, end_block}` where `retcode` is either `:ok` or
      `:confirmation_missed` indicating the success or failure of the discovery
      process, and `end_block` is used to determine the start block number for the
      next iteration of new confirmations discovery.
    - `{:ok, start_block - 1}` if there are no new blocks to be processed,
      indicating that the current start block should be reconsidered in the next
      iteration.
  """
  @spec discover_new_rollup_confirmation(%{
          :config => %{
            :l1_outbox_address => binary(),
            :l1_rpc => %{
              :finalized_confirmations => boolean(),
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          :data => %{:new_confirmations_start_block => non_neg_integer(), optional(any()) => any()},
          optional(any()) => any()
        }) :: {:confirmation_missed, non_neg_integer()} | {:ok, non_neg_integer()}
  def discover_new_rollup_confirmation(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address
          },
          data: %{new_confirmations_start_block: start_block}
        } = _state
      ) do
    # It makes sense to use "safe" here. Blocks are confirmed with delay in one week
    # (applicable for ArbitrumOne and Nova), so 10 mins delay is not significant
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        if(l1_rpc_config.finalized_confirmations, do: "safe", else: "latest"),
        l1_rpc_config.json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + l1_rpc_config.logs_block_range - 1, latest_block)

    if start_block <= end_block do
      log_info("Block range for new rollup confirmations discovery: #{start_block}..#{end_block}")

      retcode =
        discover(
          outbox_address,
          start_block,
          end_block,
          l1_rpc_config
        )

      {retcode, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  @doc """
    Discovers and processes historical confirmations of rollup blocks within a calculated block range.

    This function determines the appropriate L1 block range for discovering
    historical rollup confirmations based on the provided end block or from the
    analysis of confirmations missed in the database. It then fetches logs
    representing `SendRootUpdated` events within this range to identify the
    historical tops of rollup block confirmations. The discovered confirmations
    are processed to update the status of rollup blocks and L2-to-L1 messages
    accordingly. Eventually, updated rollup blocks, cross-chain messages, and newly
    constructed lifecycle transactions are imported into the database.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including the L1 outbox address, rollup
                  initialization block, RPC configurations, and the start block for
                  the confirmation discovery.
      - `data`: Contains optional start and end L1 block numbers to limit the range
                for historical confirmation discovery.

    ## Returns
    - `{retcode, {start_block, interim_start_block}}` where
      - `retcode` is either `:ok` or `:confirmation_missed`
      - `start_block` is the starting block for the next iteration of discovery
      - `interim_start_block` is the end block for the next iteration of discovery
  """
  @spec discover_historical_rollup_confirmation(%{
          :config => %{
            :l1_outbox_address => binary(),
            :l1_rollup_init_block => non_neg_integer(),
            :l1_rpc => %{
              :finalized_confirmations => boolean(),
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            :l1_start_block => non_neg_integer(),
            optional(any()) => any()
          },
          :data => %{
            :historical_confirmations_end_block => nil | non_neg_integer(),
            :historical_confirmations_start_block => nil | non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) ::
          {:confirmation_missed, {nil | non_neg_integer(), nil | non_neg_integer()}}
          | {:ok, {nil | non_neg_integer(), nil | non_neg_integer()}}
  def discover_historical_rollup_confirmation(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address,
            l1_start_block: l1_start_block,
            l1_rollup_init_block: l1_rollup_init_block
          },
          data: %{
            historical_confirmations_end_block: expected_confirmation_end_block,
            historical_confirmations_start_block: expected_confirmation_start_block
          }
        } = _state
      ) do
    {interim_start_block, end_block} =
      case expected_confirmation_end_block do
        nil ->
          Db.l1_blocks_to_expect_rollup_blocks_confirmation(nil)

        _ ->
          {expected_confirmation_start_block, expected_confirmation_end_block}
      end

    with {:end_block_defined, true} <- {:end_block_defined, not is_nil(end_block)},
         {:genesis_not_reached, true} <- {:genesis_not_reached, end_block >= l1_rollup_init_block} do
      start_block =
        case interim_start_block do
          nil ->
            max(l1_rollup_init_block, end_block - l1_rpc_config.logs_block_range + 1)

          value ->
            Enum.max([l1_rollup_init_block, value, end_block - l1_rpc_config.logs_block_range + 1])
        end

      log_info("Block range for historical rollup confirmations discovery: #{start_block}..#{end_block}")

      retcode =
        discover(
          outbox_address,
          start_block,
          end_block,
          l1_rpc_config
        )

      {retcode, {start_block, interim_start_block}}
    else
      # TODO: Investigate on a live system what will happen when all blocks are confirmed

      # the situation when end block is `nil` is possible when there is no confirmed
      # block in the database and the historical confirmations discovery must start
      # from the L1 block specified as L1 start block (configured, or the latest block number)
      {:end_block_defined, false} -> {:ok, {l1_start_block, nil}}
      # If the genesis of the rollup has been reached during historical confirmations
      # discovery, no further actions are needed.
      {:genesis_not_reached, false} -> {:ok, {l1_rollup_init_block, nil}}
    end
  end

  # Discovers and processes new confirmations of rollup blocks within the given block range.
  #
  # This function fetches logs within the specified L1 block range to find new
  # confirmations of rollup blocks. It processes these logs to extract confirmation
  # details, identifies the corresponding rollup blocks and updates their
  # status, and also discovers L2-to-L1 messages to be marked as confirmed. The
  # identified lifecycle transactions, rollup blocks, and confirmed messages are then
  # imported into the database.
  #
  # ## Parameters
  # - `outbox_address`: The address of the Arbitrum outbox contract.
  # - `start_block`: The starting block number for fetching logs.
  # - `end_block`: The ending block number for fetching logs.
  # - `l1_rpc_config`: Configuration for L1 RPC calls.
  #
  # ## Returns
  # - The retcode indicating the result of the discovery and processing operation,
  #   either `:ok` or `:confirmation_missed`.
  defp discover(
         outbox_address,
         start_block,
         end_block,
         l1_rpc_config
       ) do
    {logs, _} =
      get_logs_new_confirmations(
        start_block,
        end_block,
        outbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    {retcode, {lifecycle_txs, rollup_blocks, confirmed_txs}} =
      handle_confirmations_from_logs(
        logs,
        l1_rpc_config,
        outbox_address
      )

    {:ok, _} =
      Chain.import(%{
        arbitrum_lifecycle_transactions: %{params: lifecycle_txs},
        arbitrum_batch_blocks: %{params: rollup_blocks},
        arbitrum_messages: %{params: confirmed_txs},
        timeout: :infinity
      })

    retcode
  end

  # Processes logs to handle confirmations for rollup blocks.
  #
  # This function analyzes logs containing `SendRootUpdated` events with information
  # about the confirmations up to a specific point in time. It identifies the ranges
  # of rollup blocks covered by the confirmations and constructs lifecycle
  # transactions linked to these confirmed blocks. Considering the highest confirmed
  # rollup block number, it discovers L2-to-L1 messages that have been committed and
  # updates their status to confirmed. Lists of confirmed rollup blocks, lifecycle
  # transactions, and confirmed messages are prepared for database import.
  #
  # ## Parameters
  # - `logs`: Log entries representing `SendRootUpdated` events.
  # - `l1_rpc_config`: Configuration for L1 RPC calls.
  # - `outbox_address`: The address of the Arbitrum outbox contract.
  #
  # ## Returns
  # - `{retcode, {lifecycle_txs, rollup_blocks, confirmed_txs}}` where
  #   - `retcode` is either `:ok` or `:confirmation_missed`
  #   - `lifecycle_txs` is a list of lifecycle transactions confirming blocks in the
  #     rollup
  #   - `rollup_blocks` is a list of rollup blocks associated with the corresponding
  #     lifecycle transactions
  #   - `confirmed_messages` is a list of L2-to-L1 messages identified up to the
  #     highest confirmed block number, to be imported with the new status
  #     `:confirmed`
  @spec handle_confirmations_from_logs(
          [%{String.t() => any()}],
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :logs_block_range => non_neg_integer(),
            :chunk_size => non_neg_integer(),
            :finalized_confirmations => boolean()
          },
          binary()
        ) ::
          {:ok | :confirmation_missed,
           {[Arbitrum.LifecycleTransaction.to_import()], [Arbitrum.BatchBlock.to_import()],
            [Arbitrum.Message.to_import()]}}
  defp handle_confirmations_from_logs(logs, l1_rpc_config, outbox_address)

  defp handle_confirmations_from_logs([], _, _) do
    {:ok, {[], [], []}}
  end

  defp handle_confirmations_from_logs(
         logs,
         l1_rpc_config,
         outbox_address
       ) do
    {rollup_blocks_to_l1_txs, lifecycle_txs_basic, blocks_requests} = parse_logs_for_new_confirmations(logs)

    rollup_blocks =
      discover_rollup_blocks(
        rollup_blocks_to_l1_txs,
        %{
          json_rpc_named_arguments: l1_rpc_config.json_rpc_named_arguments,
          logs_block_range: l1_rpc_config.logs_block_range,
          outbox_address: outbox_address
        }
      )

    applicable_lifecycle_txs = take_lifecycle_txs_for_confirmed_blocks(rollup_blocks, lifecycle_txs_basic)

    retcode =
      if Enum.count(lifecycle_txs_basic) != Enum.count(applicable_lifecycle_txs) do
        :confirmation_missed
      else
        :ok
      end

    if Enum.empty?(applicable_lifecycle_txs) do
      {retcode, {[], [], []}}
    else
      {lifecycle_txs, rollup_blocks, highest_confirmed_block_number} =
        finalize_lifecycle_txs_and_confirmed_blocks(
          applicable_lifecycle_txs,
          rollup_blocks,
          blocks_requests,
          l1_rpc_config
        )

      # Drawback of marking messages as confirmed during a new confirmation handling
      # is that the status change could become stuck if confirmations are not handled.
      # For example, due to DB inconsistency: some blocks/batches are missed.
      confirmed_messages = get_confirmed_l2_to_l1_messages(highest_confirmed_block_number)

      {retcode, {lifecycle_txs, rollup_blocks, confirmed_messages}}
    end
  end

  # Parses logs to extract new confirmations for rollup blocks and prepares related data.
  #
  # This function processes `SendRootUpdated` event logs. For each event, it maps
  # the hash of the top confirmed rollup block provided in the event to
  # the confirmation description, containing the L1 transaction hash and
  # block number. It also prepares a set of lifecycle transactions in basic form
  # and block requests to later fetch timestamps for the corresponding lifecycle
  # transactions.
  #
  # ## Parameters
  # - `logs`: A list of log entries representing `SendRootUpdated` events.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map associating rollup block hashes with their confirmation descriptions.
  #   - A map of basic-form lifecycle transactions keyed by L1 transaction hash.
  #   - A list of RPC requests to fetch block data for these lifecycle transactions.
  defp parse_logs_for_new_confirmations(logs) do
    {rollup_block_to_l1_txs, lifecycle_txs, blocks_requests} =
      logs
      |> Enum.reduce({%{}, %{}, %{}}, fn event, {block_to_txs, lifecycle_txs, blocks_requests} ->
        rollup_block_hash = send_root_updated_event_parse(event)

        l1_tx_hash_raw = event["transactionHash"]
        l1_tx_hash = Rpc.string_hash_to_bytes_hash(l1_tx_hash_raw)
        l1_blk_num = quantity_to_integer(event["blockNumber"])

        updated_block_to_txs =
          Map.put(
            block_to_txs,
            rollup_block_hash,
            %{l1_tx_hash: l1_tx_hash, l1_block_num: l1_blk_num}
          )

        updated_lifecycle_txs =
          Map.put(
            lifecycle_txs,
            l1_tx_hash,
            %{hash: l1_tx_hash, block_number: l1_blk_num}
          )

        updated_blocks_requests =
          Map.put(
            blocks_requests,
            l1_blk_num,
            BlockByNumber.request(%{id: 0, number: l1_blk_num}, false, true)
          )

        log_info("New confirmation for the rollup block #{rollup_block_hash} found in #{l1_tx_hash_raw}")

        {updated_block_to_txs, updated_lifecycle_txs, updated_blocks_requests}
      end)

    {rollup_block_to_l1_txs, lifecycle_txs, Map.values(blocks_requests)}
  end

  # Transforms rollup block hashes to numbers and associates them with their confirmation descriptions.
  #
  # This function converts a map linking rollup block hashes to confirmation descriptions
  # into a map of rollup block numbers to confirmations, facilitating the identification
  # of blocks for confirmation. The function then processes confirmations starting from
  # the lowest rollup block number, ensuring that each block is associated with the
  # correct confirmation. This sequential handling preserves the confirmation history,
  # allowing future processing to accurately associate blocks with their respective
  # confirmations.
  #
  # ## Parameters
  # - `rollup_blocks_to_l1_txs`: A map of rollup block hashes to confirmation descriptions.
  # - `outbox_config`: Configuration for the Arbitrum outbox contract.
  #
  # ## Returns
  # - A list of rollup blocks each associated with the transaction's hash that
  #   confirms the block.
  defp discover_rollup_blocks(rollup_blocks_to_l1_txs, outbox_config) do
    block_to_l1_txs =
      rollup_blocks_to_l1_txs
      |> Map.keys()
      |> Enum.reduce(%{}, fn block_hash, transformed ->
        rollup_block_num = Db.rollup_block_hash_to_num(block_hash)

        # nil is applicable for the case when the block is not indexed yet by
        # the block fetcher, it makes sense to skip this block so far
        case rollup_block_num do
          nil ->
            log_warning("The rollup block #{block_hash} did not found. Plan to skip the confirmations")
            transformed

          value ->
            Map.put(transformed, value, rollup_blocks_to_l1_txs[block_hash])
        end
      end)

    if Enum.empty?(block_to_l1_txs) do
      []
    else
      # Oldest (with the lowest number) block is first
      rollup_block_numbers = Enum.sort(Map.keys(block_to_l1_txs), :asc)

      rollup_block_numbers
      |> Enum.reduce([], fn block_num, updated_rollup_blocks ->
        log_info("Attempting to mark all rollup blocks including ##{block_num} and lower as confirmed")

        {_, confirmed_blocks} =
          discover_rollup_blocks_belonging_to_one_confirmation(
            block_num,
            block_to_l1_txs[block_num],
            outbox_config
          )

        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        if length(confirmed_blocks) > 0 do
          log_info("Found #{length(confirmed_blocks)} confirmed blocks")

          add_confirmation_transaction(confirmed_blocks, block_to_l1_txs[block_num].l1_tx_hash) ++
            updated_rollup_blocks
        else
          log_info("Either no unconfirmed blocks found or DB inconsistency error discovered")
          []
        end
      end)
    end
  end

  # Discovers rollup blocks within a single confirmation, ensuring no gaps in the confirmed range.
  #
  # This function follows these steps to identify unconfirmed rollup blocks related
  # to a single confirmation event:
  # 1. Retrieve the batch associated with the specified rollup block number.
  # 2. Obtain a list of unconfirmed blocks within that batch.
  # 3. Determine the first unconfirmed block in the batch, considering potential
  #    gaps or already confirmed blocks.
  # 4. Verify the continuity of the unconfirmed blocks range to ensure there are no
  #    database inconsistencies or unindexed blocks.
  # 5. If the first unconfirmed block is at the start of the batch, check if the
  #    confirmation also covers blocks from previous batches. If so, include their
  #    unconfirmed blocks in the range.
  # 6. If all blocks in the previous batch are confirmed, return the current list of
  #    unconfirmed blocks.
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
  # - `cache`: A cache to minimize repetitive `eth_getLogs` calls.
  #
  # ## Returns
  # - `{:ok, unconfirmed_blocks}`: A list of rollup blocks that are confirmed by
  #   the current confirmation but not yet marked as confirmed in the database.
  # - `{:error, []}`: If a discrepancy or inconsistency is found during the
  #   discovery process.
  defp discover_rollup_blocks_belonging_to_one_confirmation(
         rollup_block_num,
         confirmation_desc,
         outbox_config,
         cache \\ %{}
       ) do
    # The following batch fields are required in the further processing:
    # number, start_block, end_block, commitment_transaction.block_number
    with {:ok, batch} <- discover_rollup_blocks__get_batch(rollup_block_num),
         {:ok, unconfirmed_rollup_blocks} when unconfirmed_rollup_blocks != [] <-
           discover_rollup_blocks__get_unconfirmed_rollup_blocks(batch, rollup_block_num),
         # It is not the issue to request logs for the first call of
         # discover_rollup_blocks_belonging_to_one_confirmation since we need
         # to make sure that there is no another confirmation for part of the
         # blocks of the batch.
         # If it returns `{:ok, []}` it will be passed as the return value of
         # discover_rollup_blocks_belonging_to_one_confirmation function.
         {:ok, {first_unconfirmed_block, new_cache}} <-
           discover_rollup_blocks__check_confirmed_blocks_in_batch(
             rollup_block_num,
             length(unconfirmed_rollup_blocks),
             batch,
             confirmation_desc,
             outbox_config,
             cache
           ),
         true <- discover_rollup_blocks__check_consecutive_rollup_blocks(unconfirmed_rollup_blocks, batch.number) do
      if List.first(unconfirmed_rollup_blocks).block_number == batch.start_block do
        log_info("End of the batch #{batch.number} discovered, moving to the previous batch")

        {status, updated_rollup_blocks} =
          discover_rollup_blocks_belonging_to_one_confirmation(
            first_unconfirmed_block - 1,
            confirmation_desc,
            outbox_config,
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
        log_info("All unconfirmed blocks in the batch ##{batch.number} found")
        {:ok, unconfirmed_rollup_blocks}
      end
    end
  end

  # Retrieves the batch containing the specified rollup block and logs the attempt.
  defp discover_rollup_blocks__get_batch(rollup_block_num) do
    # Generally if batch is nil it means either
    # - a batch to a rollup block association is not found, not recoverable
    # - a rollup block is not found, the corresponding batch is not handled yet. It is possible
    #   because the method can be called for guessed block number rather than received from
    #   the batch description or from blocks list received after a batch handling. In this case
    #   the confirmation must be postponed until the corresponding batch is handled.
    batch = Db.get_batch_by_rollup_block_number(rollup_block_num)

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
  defp discover_rollup_blocks__get_unconfirmed_rollup_blocks(batch, rollup_block_num) do
    unconfirmed_rollup_blocks = Db.unconfirmed_rollup_blocks(batch.start_block, rollup_block_num)

    if Enum.empty?(unconfirmed_rollup_blocks) do
      # Blocks are not found only in case when all blocks in the batch confirmed
      # or in case when Chain.Block for block in the batch are not received yet

      if Db.count_confirmed_rollup_blocks_in_batch(batch.number) == batch.end_block - batch.start_block + 1 do
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
  # with `rollup_block_num`. It also checks for a gap in the identified rollup
  # blocks range, indicating potential database inconsistency or an unprocessed batch.
  # To optimize `eth_getLogs` calls required for the `SendRootUpdated` event lookup,
  # it uses a cache.
  #
  # ## Parameters
  # - `rollup_block_num`: The rollup block number to check for confirmation.
  # - `unconfirmed_rollup_blocks_length`: The number of unconfirmed blocks in the batch.
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
  defp discover_rollup_blocks__check_confirmed_blocks_in_batch(
         rollup_block_num,
         unconfirmed_rollup_blocks_length,
         batch,
         confirmation_desc,
         outbox_config,
         cache
       ) do
    # This function might be over-engineered, as confirmations are likely always
    # aligned with the end of a batch. If, after analyzing the databases of fully
    # synchronized BS instances across several Arbitrum-based chains, it is confirmed
    # that this alignment is consistent, then this functionality can be optimized.

    {status, block?, new_cache} = check_if_batch_confirmed(batch, confirmation_desc, outbox_config, cache)

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

        if unconfirmed_rollup_blocks_length == rollup_block_num - first_unconfirmed_block_in_batch + 1 do
          {:ok, {first_unconfirmed_block_in_batch, new_cache}}
        else
          # The case when there is a gap in the blocks range is possible when there is
          # a DB inconsistency. From another side, the case when the confirmation is for blocks
          # in two batches -- one batch has been already indexed, another one has not been yet.
          # Both cases should be handled in the same way - this confirmation must be postponed
          # until the case resolution.
          log_warning(
            "Only #{unconfirmed_rollup_blocks_length} of #{rollup_block_num - first_unconfirmed_block_in_batch + 1} blocks found. Skipping the blocks from the batch #{batch.number}"
          )

          {:error, []}
        end
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
  defp check_if_batch_confirmed(batch, confirmation_desc, l1_outbox_config, cache) do
    log_info(
      "Use L1 blocks #{batch.commitment_transaction.block_number}..#{confirmation_desc.l1_block_num - 1} to look for a rollup block confirmation within #{batch.start_block}..#{batch.end_block} of ##{batch.number}"
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

  # Checks if any blocks within a specific range are identified as the top of confirmed blocks by scanning `SendRootUpdated` events.
  #
  # This function fetches logs for `SendRootUpdated` events within the specified
  # L1 block range to determine if any rollup blocks within the given rollup block
  # range are mentioned in the events, indicating the top of confirmed blocks up
  # to that log. It uses caching to minimize `eth_getLogs` calls.
  #
  # ## Parameters
  # - A tuple `{rollup_start_block, rollup_end_block}` specifying the rollup block
  #   range to check for confirmations
  # - A tuple `{log_start, log_end}` specifying the L1 block range to fetch logs.
  # - `l1_outbox_config`: Configuration for the Arbitrum Outbox contract.
  # - `cache`: A cache of previously fetched logs to reduce `eth_getLogs` calls.
  #
  # ## Returns
  # - A tuple `{:ok, latest_block_confirmed, new_cache, logs_length}`:
  #   - `latest_block_confirmed` is the highest rollup block number confirmed within
  #     the specified range.
  # - A tuple `{:ok, nil, new_cache, logs_length}` if no rollup blocks within the
  #   specified range are confirmed.
  # - A tuple `{:error, nil, new_cache, logs_length}` if during parsing logs a rollup
  #    block with given hash is not being found in the database.
  # For all three cases the `new_cache` contains the updated logs cache.
  @spec do_check_if_batch_confirmed(
          {non_neg_integer(), non_neg_integer()},
          {non_neg_integer(), non_neg_integer()},
          %{
            :outbox_address => String.t(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          },
          __MODULE__.cached_logs()
        ) ::
          {:ok, nil | non_neg_integer(), __MODULE__.cached_logs(), non_neg_integer()}
          | {:error, nil, __MODULE__.cached_logs(), non_neg_integer()}
  defp do_check_if_batch_confirmed(
         {rollup_start_block, rollup_end_block},
         {log_start, log_end},
         l1_outbox_config,
         cache
       ) do
    # The logs in the given L1 blocks range
    {logs, new_cache} =
      get_logs_new_confirmations(
        log_start,
        log_end,
        l1_outbox_config.outbox_address,
        l1_outbox_config.json_rpc_named_arguments,
        cache
      )

    # For every discovered event check if the rollup block in the confirmation
    # is within the specified range which usually means that the event
    # is the confirmation of the batch described by the range.
    {status, latest_block_confirmed} =
      logs
      |> Enum.reduce_while({:ok, nil}, fn event, _acc ->
        log_debug("Examining the transaction #{event["transactionHash"]}")

        rollup_block_hash = send_root_updated_event_parse(event)
        rollup_block_num = Db.rollup_block_hash_to_num(rollup_block_hash)

        case rollup_block_num do
          nil ->
            log_warning("The rollup block ##{rollup_block_hash} not found")
            {:halt, {:error, nil}}

          value when value >= rollup_start_block and value <= rollup_end_block ->
            log_debug("The rollup block ##{rollup_block_num} within the range")
            {:halt, {:ok, rollup_block_num}}

          _ ->
            log_debug("The rollup block ##{rollup_block_num} outside of the range")
            {:cont, {:ok, nil}}
        end
      end)

    {status, latest_block_confirmed, new_cache, length(logs)}
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

  # Retrieves logs for `SendRootUpdated` events between specified blocks,
  # using cache if available to reduce RPC calls.
  #
  # This function fetches logs for `SendRootUpdated` events emitted by the
  # Outbox contract within the given block range. It utilizes a cache to
  # minimize redundant RPC requests. If logs are not present in the cache,
  # it fetches them from the RPC node and updates the cache.
  #
  # ## Parameters
  # - `start_block`: The starting block number for log retrieval.
  # - `end_block`: The ending block number for log retrieval.
  # - `outbox_address`: The address of the Outbox contract.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC
  #   connection.
  # - `cache`: An optional parameter holding previously fetched logs to avoid
  #   redundant RPC calls.
  #
  # ## Returns
  # - A tuple containing:
  #   - The list of logs corresponding to `SendRootUpdated` events.
  #   - The updated cache with the newly fetched logs.
  @spec get_logs_new_confirmations(
          non_neg_integer(),
          non_neg_integer(),
          binary(),
          EthereumJSONRPC.json_rpc_named_arguments(),
          __MODULE__.cached_logs()
        ) :: {[%{String.t() => any()}], __MODULE__.cached_logs()}
  defp get_logs_new_confirmations(start_block, end_block, outbox_address, json_rpc_named_arguments, cache \\ %{})
       when start_block <= end_block do
    # TODO: consider to have a persistent cache in DB to reduce the number of getLogs requests
    {logs, new_cache} =
      case cache[{start_block, end_block}] do
        nil ->
          {:ok, rpc_logs} =
            IndexerHelper.get_logs(
              start_block,
              end_block,
              outbox_address,
              [@send_root_updated_event],
              json_rpc_named_arguments
            )

          {rpc_logs, Map.put(cache, {start_block, end_block}, rpc_logs)}

        cached_logs ->
          {cached_logs, cache}
      end

    if length(logs) > 0 do
      log_debug("Found #{length(logs)} SendRootUpdated logs")
    end

    {logs, new_cache}
  end

  # Extracts the rollup block hash from a `SendRootUpdated` event log.
  defp send_root_updated_event_parse(event) do
    [_, _, l2_block_hash] = event["topics"]

    l2_block_hash
  end

  # Validates if the list of rollup blocks are consecutive without gaps in their numbering.
  defp discover_rollup_blocks__check_consecutive_rollup_blocks(unconfirmed_rollup_blocks, batch_number) do
    if consecutive_rollup_blocks?(unconfirmed_rollup_blocks) do
      true
    else
      # The case when there is a gap in the blocks range is possible when there is
      # a DB inconsistency. From another side, the case when the confirmation is for blocks
      # in two batches -- one batch has been already indexed, another one has not been yet.
      # Both cases should be handled in the same way - this confirmation must be postponed
      # until the case resolution.
      log_warning("Skipping the blocks from the batch #{batch_number}")
      {:error, []}
    end
  end

  # Checks if the list of rollup blocks are consecutive without gaps in their numbering.
  defp consecutive_rollup_blocks?(blocks) do
    {_, status} =
      Enum.reduce_while(blocks, {nil, false}, fn block, {prev, _} ->
        case prev do
          nil ->
            {:cont, {block.block_number, true}}

          value ->
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            if block.block_number - 1 == value do
              {:cont, {block.block_number, true}}
            else
              log_warning("A gap between blocks ##{value} and ##{block.block_number} found")
              {:halt, {block.block_number, false}}
            end
        end
      end)

    status
  end

  # Adds the confirmation transaction hash to each rollup block description in the list.
  defp add_confirmation_transaction(block_descriptions_list, confirm_tx_hash) do
    block_descriptions_list
    |> Enum.reduce([], fn block_descr, updated ->
      new_block_descr =
        block_descr
        |> Map.put(:confirmation_transaction, confirm_tx_hash)

      [new_block_descr | updated]
    end)
  end

  # Selects lifecycle transaction descriptions used for confirming a given list of rollup blocks.
  defp take_lifecycle_txs_for_confirmed_blocks(confirmed_rollup_blocks, lifecycle_txs) do
    confirmed_rollup_blocks
    |> Enum.reduce(%{}, fn block_descr, updated_txs ->
      confirmation_tx_hash = block_descr.confirmation_transaction

      Map.put_new(updated_txs, confirmation_tx_hash, lifecycle_txs[confirmation_tx_hash])
    end)
  end

  # Finalizes lifecycle transaction descriptions and establishes database-ready links
  # between confirmed rollup blocks and their corresponding lifecycle transactions.
  #
  # This function executes chunked requests to L1 to retrieve block timestamps, which,
  # along with the finalization flag, are then used to finalize the lifecycle
  # transaction descriptions. Each entity in the list of blocks, which needs to be
  # confirmed, is updated with the associated lifecycle transaction IDs and prepared
  # for import.
  #
  # ## Parameters
  # - `basic_lifecycle_txs`: The initial list of partially filled lifecycle transaction
  #                          descriptions.
  # - `confirmed_rollup_blocks`: Rollup blocks to be considered as confirmed.
  # - `l1_blocks_requests`: RPC requests of `eth_getBlockByNumber` to fetch L1 block data
  #                         for use in the lifecycle transaction descriptions.
  # - A map containing L1 RPC configuration such as JSON RPC arguments, chunk size,
  #   and a flag indicating whether to track the finalization of transactions.
  #
  # ## Returns
  # - A tuple containing:
  #   - The list of lifecycle transactions, ready for import.
  #   - The list of confirmed rollup blocks, ready for import.
  #   - The highest confirmed block number processed during this run.
  defp finalize_lifecycle_txs_and_confirmed_blocks(
         basic_lifecycle_txs,
         confirmed_rollup_blocks,
         l1_blocks_requests,
         %{
           json_rpc_named_arguments: l1_json_rpc_named_arguments,
           chunk_size: l1_chunk_size,
           track_finalization: track_finalization?
         } = _l1_rpc_config
       ) do
    blocks_to_ts =
      Rpc.execute_blocks_requests_and_get_ts(l1_blocks_requests, l1_json_rpc_named_arguments, l1_chunk_size)

    lifecycle_txs =
      basic_lifecycle_txs
      |> ArbitrumHelper.extend_lifecycle_txs_with_ts_and_status(blocks_to_ts, track_finalization?)
      |> Db.get_indices_for_l1_transactions()

    {updated_rollup_blocks, highest_confirmed_block_number} =
      confirmed_rollup_blocks
      |> Enum.reduce({[], -1}, fn block, {updated_list, highest_confirmed} ->
        chosen_highest_confirmed = max(highest_confirmed, block.block_number)

        updated_block =
          block
          |> Map.put(:confirmation_id, lifecycle_txs[block.confirmation_transaction].id)
          |> Map.drop([:confirmation_transaction])

        {[updated_block | updated_list], chosen_highest_confirmed}
      end)

    {Map.values(lifecycle_txs), updated_rollup_blocks, highest_confirmed_block_number}
  end

  # Retrieves committed L2-to-L1 messages up to specified block number and marks them as 'confirmed'.
  defp get_confirmed_l2_to_l1_messages(-1) do
    []
  end

  defp get_confirmed_l2_to_l1_messages(block_number) do
    block_number
    |> Db.sent_l2_to_l1_messages()
    |> Enum.map(fn tx ->
      Map.put(tx, :status, :confirmed)
    end)
  end
end
