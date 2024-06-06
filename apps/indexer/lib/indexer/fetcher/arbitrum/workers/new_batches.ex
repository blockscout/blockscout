defmodule Indexer.Fetcher.Arbitrum.Workers.NewBatches do
  @moduledoc """
    Manages the discovery and importation of new and historical batches of transactions for an Arbitrum rollup.

    This module orchestrates the discovery of batches of transactions processed
    through the Arbitrum Sequencer. It distinguishes between new batches currently
    being created and historical batches processed in the past but not yet imported
    into the database.

    The process involves fetching logs for the `SequencerBatchDelivered` event
    emitted by the Arbitrum `SequencerInbox` contract, processing these logs to
    extract batch details, and then building the link between batches and the
    corresponding rollup blocks and transactions. It also discovers those
    cross-chain messages initiated in rollup blocks linked with the new batches
    and updates the status of messages to consider them as committed (`:sent`).

    For any blocks or transactions missing in the database, data is requested in
    chunks from the rollup RPC endpoint by `eth_getBlockByNumber`. Additionally,
    to complete batch details and lifecycle transactions, RPC calls to
    `eth_getTransactionByHash` and `eth_getBlockByNumber` on L1 are made in chunks
    for the necessary information not available in the logs.
  """

  alias ABI.{FunctionSelector, TypeDecoder}

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_debug: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Indexer.Helper, as: IndexerHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Db, Logging, Rpc}

  alias Explorer.Chain

  require Logger

  # keccak256("SequencerBatchDelivered(uint256,bytes32,bytes32,bytes32,uint256,(uint64,uint64,uint64,uint64),uint8)")
  @message_sequencer_batch_delivered "0x7394f4a19a13c7b92b5bb71033245305946ef78452f7b4986ac1390b5df4ebd7"

  @doc """
    Discovers and imports new batches of rollup transactions within the current L1 block range.

    This function determines the L1 block range for discovering new batches of rollup
    transactions. It retrieves logs representing SequencerBatchDelivered events
    emitted by the SequencerInbox contract within this range. The logs are processed
    to identify new batches and their corresponding details. Comprehensive data
    structures for these batches, along with their lifecycle transactions, rollup
    blocks, and rollup transactions, are constructed. In addition, the function
    updates the status of L2-to-L1 messages that have been committed within these new
    batches. All discovered and processed data are then imported into the database.
    The process targets only the batches that have not been previously processed,
    thereby enhancing efficiency.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including RPC configurations, SequencerInbox
                  address, a shift for the message to block number mapping, and
                  a limit for new batches discovery.
      - `data`: Contains the starting block number for new batch discovery.

    ## Returns
    - `{:ok, end_block}`: On successful discovery and processing, where `end_block`
                          indicates the necessity to consider the next block range
                          in the following iteration of new batch discovery.
    - `{:ok, start_block - 1}`: If there are no new blocks to be processed,
                                indicating that the current start block should be
                                reconsidered in the next iteration.
  """
  @spec discover_new_batches(%{
          :config => %{
            :l1_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            :l1_sequencer_inbox_address => binary(),
            :messages_to_blocks_shift => non_neg_integer(),
            :new_batches_limit => non_neg_integer(),
            :rollup_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :chunk_size => non_neg_integer(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          :data => %{:new_batches_start_block => non_neg_integer(), optional(any()) => any()},
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  def discover_new_batches(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            rollup_rpc: rollup_rpc_config,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            new_batches_limit: new_batches_limit
          },
          data: %{new_batches_start_block: start_block}
        } = _state
      ) do
    # Requesting the "latest" block instead of "safe" allows to catch new batches
    # without latency.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        l1_rpc_config.json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + l1_rpc_config.logs_block_range - 1, latest_block)

    if start_block <= end_block do
      log_info("Block range for new batches discovery: #{start_block}..#{end_block}")

      discover(
        sequencer_inbox_address,
        start_block,
        end_block,
        new_batches_limit,
        messages_to_blocks_shift,
        l1_rpc_config,
        rollup_rpc_config
      )

      {:ok, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  @doc """
    Discovers and imports historical batches of rollup transactions within a specified block range.

    This function determines the L1 block range for discovering historical batches
    of rollup transactions. Within this range, it retrieves logs representing the
    SequencerBatchDelivered events emitted by the SequencerInbox contract. These
    logs are processed to identify the batches and their details. The function then
    constructs comprehensive data structures for batches, lifecycle transactions,
    rollup blocks, and rollup transactions. Additionally, it identifies L2-to-L1
    messages that have been committed within these batches and updates their status.
    All discovered and processed data are then imported into the database, with the
    process targeting only previously undiscovered batches to enhance efficiency.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including the L1 rollup initialization block,
                  RPC configurations, SequencerInbox address, a shift for the message
                  to block number mapping, and a limit for new batches discovery.
      - `data`: Contains the ending block number for the historical batch discovery.

    ## Returns
    - `{:ok, start_block}`: On successful discovery and processing, where `start_block`
                            is the calculated starting block for the discovery range,
                            indicating the need to consider another block range in the
                            next iteration of historical batch discovery.
    - `{:ok, l1_rollup_init_block}`: If the discovery process has reached the rollup
                                     initialization block, indicating that all batches
                                     up to the rollup origins have been discovered and
                                     no further action is needed.
  """
  @spec discover_historical_batches(%{
          :config => %{
            :l1_rollup_init_block => non_neg_integer(),
            :l1_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            :l1_sequencer_inbox_address => binary(),
            :messages_to_blocks_shift => non_neg_integer(),
            :new_batches_limit => non_neg_integer(),
            :rollup_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :chunk_size => non_neg_integer(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          :data => %{:historical_batches_end_block => any(), optional(any()) => any()},
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  def discover_historical_batches(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            rollup_rpc: rollup_rpc_config,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            l1_rollup_init_block: l1_rollup_init_block,
            new_batches_limit: new_batches_limit
          },
          data: %{historical_batches_end_block: end_block}
        } = _state
      ) do
    if end_block >= l1_rollup_init_block do
      start_block = max(l1_rollup_init_block, end_block - l1_rpc_config.logs_block_range + 1)

      log_info("Block range for historical batches discovery: #{start_block}..#{end_block}")

      discover_historical(
        sequencer_inbox_address,
        start_block,
        end_block,
        new_batches_limit,
        messages_to_blocks_shift,
        l1_rpc_config,
        rollup_rpc_config
      )

      {:ok, start_block}
    else
      {:ok, l1_rollup_init_block}
    end
  end

  # Initiates the discovery process for batches within a specified block range.
  #
  # Invokes the actual discovery process for new batches by calling `do_discover`
  # with the provided parameters.
  #
  # ## Parameters
  # - `sequencer_inbox_address`: The SequencerInbox contract address.
  # - `start_block`: The starting block number for discovery.
  # - `end_block`: The ending block number for discovery.
  # - `new_batches_limit`: Limit of new batches to process in one iteration.
  # - `messages_to_blocks_shift`: Shift value for message to block number mapping.
  # - `l1_rpc_config`: Configuration for L1 RPC calls.
  # - `rollup_rpc_config`: Configuration for rollup RPC calls.
  #
  # ## Returns
  # - N/A
  defp discover(
         sequencer_inbox_address,
         start_block,
         end_block,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         rollup_rpc_config
       ) do
    do_discover(
      sequencer_inbox_address,
      start_block,
      end_block,
      new_batches_limit,
      messages_to_blocks_shift,
      l1_rpc_config,
      rollup_rpc_config
    )
  end

  # Initiates the historical discovery process for batches within a specified block range.
  #
  # Calls `do_discover` with parameters reversed for start and end blocks to
  # process historical data.
  #
  # ## Parameters
  # - `sequencer_inbox_address`: The SequencerInbox contract address.
  # - `start_block`: The starting block number for discovery.
  # - `end_block`: The ending block number for discovery.
  # - `new_batches_limit`: Limit of new batches to process in one iteration.
  # - `messages_to_blocks_shift`: Shift value for message to block number mapping.
  # - `l1_rpc_config`: Configuration for L1 RPC calls.
  # - `rollup_rpc_config`: Configuration for rollup RPC calls.
  #
  # ## Returns
  # - N/A
  defp discover_historical(
         sequencer_inbox_address,
         start_block,
         end_block,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         rollup_rpc_config
       ) do
    do_discover(
      sequencer_inbox_address,
      end_block,
      start_block,
      new_batches_limit,
      messages_to_blocks_shift,
      l1_rpc_config,
      rollup_rpc_config
    )
  end

  # Performs the discovery of new or historical batches within a specified block range,
  # processing and importing the relevant data into the database.
  #
  # This function retrieves SequencerBatchDelivered event logs from the specified block range
  # and processes these logs to identify new batches and their corresponding details. It then
  # constructs comprehensive data structures for batches, lifecycle transactions, rollup
  # blocks, and rollup transactions. Additionally, it identifies any L2-to-L1 messages that
  # have been committed within these batches and updates their status. All discovered and
  # processed data are then imported into the database.
  #
  # ## Parameters
  # - `sequencer_inbox_address`: The SequencerInbox contract address used to filter logs.
  # - `start_block`: The starting block number for the discovery range.
  # - `end_block`: The ending block number for the discovery range.
  # - `new_batches_limit`: The maximum number of new batches to process in one iteration.
  # - `messages_to_blocks_shift`: The value used to align message counts with rollup block numbers.
  # - `l1_rpc_config`: RPC configuration parameters for L1.
  # - `rollup_rpc_config`: RPC configuration parameters for rollup data.
  #
  # ## Returns
  # - N/A
  defp do_discover(
         sequencer_inbox_address,
         start_block,
         end_block,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         rollup_rpc_config
       ) do
    raw_logs =
      get_logs_new_batches(
        min(start_block, end_block),
        max(start_block, end_block),
        sequencer_inbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    logs =
      if end_block >= start_block do
        raw_logs
      else
        Enum.reverse(raw_logs)
      end

    # Discovered logs are divided into chunks to ensure progress
    # in batch discovery, even if an error interrupts the fetching process.
    logs
    |> Enum.chunk_every(new_batches_limit)
    |> Enum.each(fn chunked_logs ->
      {batches, lifecycle_txs, rollup_blocks, rollup_txs, committed_txs} =
        handle_batches_from_logs(
          chunked_logs,
          messages_to_blocks_shift,
          l1_rpc_config,
          rollup_rpc_config
        )

      {:ok, _} =
        Chain.import(%{
          arbitrum_lifecycle_transactions: %{params: lifecycle_txs},
          arbitrum_l1_batches: %{params: batches},
          arbitrum_batch_blocks: %{params: rollup_blocks},
          arbitrum_batch_transactions: %{params: rollup_txs},
          arbitrum_messages: %{params: committed_txs},
          timeout: :infinity
        })
    end)
  end

  # Fetches logs for SequencerBatchDelivered events from the SequencerInbox contract within a block range.
  #
  # Retrieves logs that correspond to SequencerBatchDelivered events, specifically
  # from the SequencerInbox contract, between the specified block numbers.
  #
  # ## Parameters
  # - `start_block`: The starting block number for log retrieval.
  # - `end_block`: The ending block number for log retrieval.
  # - `sequencer_inbox_address`: The address of the SequencerInbox contract.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  #
  # ## Returns
  # - A list of logs for SequencerBatchDelivered events within the specified block range.
  defp get_logs_new_batches(start_block, end_block, sequencer_inbox_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        sequencer_inbox_address,
        [@message_sequencer_batch_delivered],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      log_debug("Found #{length(logs)} SequencerBatchDelivered logs")
    end

    logs
  end

  # Processes logs to extract batch information and prepare it for database import.
  #
  # This function analyzes SequencerBatchDelivered event logs to identify new batches
  # and retrieves their details, avoiding the reprocessing of batches already known
  # in the database. It enriches the details of new batches with data from corresponding
  # L1 transactions and blocks, including timestamps and block ranges. The function
  # then prepares batches, associated rollup blocks and transactions, and lifecycle
  # transactions for database import. Additionally, L2-to-L1 messages initiated in the
  # rollup blocks associated with the discovered batches are retrieved from the database,
  # marked as `:sent`, and prepared for database import.
  #
  # ## Parameters
  # - `logs`: The list of SequencerBatchDelivered event logs.
  # - `msg_to_block_shift`: The shift value for mapping batch messages to block numbers.
  # - `l1_rpc_config`: The RPC configuration for L1 requests.
  # - `rollup_rpc_config`: The RPC configuration for rollup data requests.
  #
  # ## Returns
  # - A tuple containing lists of batches, lifecycle transactions, rollup blocks,
  #   rollup transactions, and committed messages (with the status `:sent`), all
  #   ready for database import.
  defp handle_batches_from_logs(
         logs,
         msg_to_block_shift,
         %{
           json_rpc_named_arguments: json_rpc_named_arguments,
           chunk_size: chunk_size
         } = l1_rpc_config,
         rollup_rpc_config
       ) do
    existing_batches =
      logs
      |> parse_logs_to_get_batch_numbers()
      |> Db.batches_exist()

    {batches, txs_requests, blocks_requests} = parse_logs_for_new_batches(logs, existing_batches)

    blocks_to_ts = Rpc.execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size)

    {lifecycle_txs_wo_indices, batches_to_import} =
      execute_tx_requests_parse_txs_calldata(txs_requests, msg_to_block_shift, blocks_to_ts, batches, l1_rpc_config)

    {blocks_to_import, rollup_txs_to_import} = get_rollup_blocks_and_transactions(batches_to_import, rollup_rpc_config)

    lifecycle_txs =
      lifecycle_txs_wo_indices
      |> Db.get_indices_for_l1_transactions()

    tx_counts_per_batch = batches_to_rollup_txs_amounts(rollup_txs_to_import)

    batches_list_to_import =
      batches_to_import
      |> Map.values()
      |> Enum.reduce([], fn batch, updated_batches_list ->
        [
          batch
          |> Map.put(:commitment_id, get_l1_tx_id_by_hash(lifecycle_txs, batch.tx_hash))
          |> Map.put(
            :transactions_count,
            case tx_counts_per_batch[batch.number] do
              nil -> 0
              value -> value
            end
          )
          |> Map.drop([:tx_hash])
          | updated_batches_list
        ]
      end)

    committed_txs =
      blocks_to_import
      |> Map.keys()
      |> Enum.max()
      |> get_committed_l2_to_l1_messages()

    {batches_list_to_import, Map.values(lifecycle_txs), Map.values(blocks_to_import), rollup_txs_to_import,
     committed_txs}
  end

  # Extracts batch numbers from logs of SequencerBatchDelivered events.
  defp parse_logs_to_get_batch_numbers(logs) do
    logs
    |> Enum.map(fn event ->
      {batch_num, _, _} = sequencer_batch_delivered_event_parse(event)
      batch_num
    end)
  end

  # Parses logs representing SequencerBatchDelivered events to identify new batches.
  #
  # This function sifts through logs of SequencerBatchDelivered events, extracts the
  # necessary data, and assembles a map of new batch descriptions. Additionally, it
  # prepares RPC `eth_getTransactionByHash` and `eth_getBlockByNumber` requests to
  # fetch details not present in the logs. To minimize subsequent RPC calls, only
  # batches not previously known (i.e., absent in `existing_batches`) are processed.
  #
  # ## Parameters
  # - `logs`: A list of event logs to be processed.
  # - `existing_batches`: A list of batch numbers already processed.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of new batch descriptions, which are not yet ready for database import.
  #   - A list of RPC `eth_getTransactionByHash` requests for fetching details of
  #     the L1 transactions associated with these batches.
  #   - A list of RPC requests to fetch details of the L1 blocks where these batches
  #     were included.
  defp parse_logs_for_new_batches(logs, existing_batches) do
    {batches, txs_requests, blocks_requests} =
      logs
      |> Enum.reduce({%{}, [], %{}}, fn event, {batches, txs_requests, blocks_requests} ->
        {batch_num, before_acc, after_acc} = sequencer_batch_delivered_event_parse(event)

        tx_hash_raw = event["transactionHash"]
        tx_hash = Rpc.string_hash_to_bytes_hash(tx_hash_raw)
        blk_num = quantity_to_integer(event["blockNumber"])

        if batch_num in existing_batches do
          {batches, txs_requests, blocks_requests}
        else
          updated_batches =
            Map.put(
              batches,
              batch_num,
              %{
                number: batch_num,
                before_acc: before_acc,
                after_acc: after_acc,
                tx_hash: tx_hash
              }
            )

          updated_txs_requests = [
            Rpc.transaction_by_hash_request(%{id: 0, hash: tx_hash_raw})
            | txs_requests
          ]

          updated_blocks_requests =
            Map.put(
              blocks_requests,
              blk_num,
              BlockByNumber.request(%{id: 0, number: blk_num}, false, true)
            )

          log_info("New batch #{batch_num} found in #{tx_hash_raw}")

          {updated_batches, updated_txs_requests, updated_blocks_requests}
        end
      end)

    {batches, txs_requests, Map.values(blocks_requests)}
  end

  # Parses SequencerBatchDelivered event to get batch sequence number and associated accumulators
  defp sequencer_batch_delivered_event_parse(event) do
    [_, batch_sequence_number, before_acc, after_acc] = event["topics"]

    {quantity_to_integer(batch_sequence_number), before_acc, after_acc}
  end

  # Executes transaction requests and parses the calldata to extract batch data.
  #
  # This function processes a list of RPC `eth_getTransactionByHash` requests, extracts
  # and decodes the calldata from the transactions to obtain batch details. It updates
  # the provided batch map with block ranges for new batches and constructs a map of
  # lifecycle transactions with their timestamps and finalization status.
  #
  # ## Parameters
  # - `txs_requests`: The list of RPC requests to fetch transaction data.
  # - `msg_to_block_shift`: The shift value to adjust the message count to the correct
  #                         rollup block numbers.
  # - `blocks_to_ts`: A map of block numbers to their timestamps, required to complete
  #                   data for corresponding lifecycle transactions.
  # - `batches`: The current batch data to be updated.
  # - A configuration map containing JSON RPC arguments, a track finalization flag,
  #   and a chunk size for batch processing.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of lifecycle (L1) transactions, which are not yet compatible with
  #     database import and require further processing.
  #   - An updated map of batch descriptions, also requiring further processing
  #     before database import.
  defp execute_tx_requests_parse_txs_calldata(txs_requests, msg_to_block_shift, blocks_to_ts, batches, %{
         json_rpc_named_arguments: json_rpc_named_arguments,
         track_finalization: track_finalization?,
         chunk_size: chunk_size
       }) do
    txs_requests
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce({%{}, batches}, fn chunk, {l1_txs, updated_batches} ->
      chunk
      # each eth_getTransactionByHash will take time since it returns entire batch
      # in `input` which is heavy because contains dozens of rollup blocks
      |> Rpc.make_chunked_request(json_rpc_named_arguments, "eth_getTransactionByHash")
      |> Enum.reduce({l1_txs, updated_batches}, fn resp, {txs_map, batches_map} ->
        block_num = quantity_to_integer(resp["blockNumber"])
        tx_hash = Rpc.string_hash_to_bytes_hash(resp["hash"])

        # Although they are called messages in the functions' ABI, in fact they are
        # rollup blocks
        {batch_num, prev_message_count, new_message_count} =
          add_sequencer_l2_batch_from_origin_calldata_parse(resp["input"])

        # In some cases extracted numbers for messages does not linked directly
        # with rollup blocks, for this, the numbers are shifted by a value specific
        # for particular rollup
        updated_batches_map =
          Map.put(
            batches_map,
            batch_num,
            Map.merge(batches_map[batch_num], %{
              start_block: prev_message_count + msg_to_block_shift,
              end_block: new_message_count + msg_to_block_shift - 1
            })
          )

        updated_txs_map =
          Map.put(txs_map, tx_hash, %{
            hash: tx_hash,
            block_number: block_num,
            timestamp: blocks_to_ts[block_num],
            status:
              if track_finalization? do
                :unfinalized
              else
                :finalized
              end
          })

        {updated_txs_map, updated_batches_map}
      end)
    end)
  end

  # Parses calldata of `addSequencerL2BatchFromOrigin` or `addSequencerL2BatchFromBlobs`
  # functions to extract batch information.
  defp add_sequencer_l2_batch_from_origin_calldata_parse(calldata) do
    case calldata do
      "0x8f111f3c" <> encoded_params ->
        # addSequencerL2BatchFromOrigin(uint256 sequenceNumber, bytes calldata data, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount)
        [sequence_number, _data, _after_delayed_messages_read, _gas_refunder, prev_message_count, new_message_count] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            %FunctionSelector{
              function: "addSequencerL2BatchFromOrigin",
              types: [
                {:uint, 256},
                :bytes,
                {:uint, 256},
                :address,
                {:uint, 256},
                {:uint, 256}
              ]
            }
          )

        {sequence_number, prev_message_count, new_message_count}

      "0x3e5aa082" <> encoded_params ->
        # addSequencerL2BatchFromBlobs(uint256 sequenceNumber, uint256 afterDelayedMessagesRead, address gasRefunder, uint256 prevMessageCount, uint256 newMessageCount)
        [sequence_number, _after_delayed_messages_read, _gas_refunder, prev_message_count, new_message_count] =
          TypeDecoder.decode(
            Base.decode16!(encoded_params, case: :lower),
            %FunctionSelector{
              function: "addSequencerL2BatchFromBlobs",
              types: [
                {:uint, 256},
                {:uint, 256},
                :address,
                {:uint, 256},
                {:uint, 256}
              ]
            }
          )

        {sequence_number, prev_message_count, new_message_count}
    end
  end

  # Retrieves rollup blocks and transactions for a list of batches.
  #
  # This function extracts rollup block ranges from each batch's data to determine
  # the required blocks. It then fetches existing rollup blocks and transactions from
  # the database and recovers any missing data through RPC if necessary.
  #
  # ## Parameters
  # - `batches`: A list of batches, each containing rollup block ranges associated
  #              with the batch.
  # - `rollup_rpc_config`: Configuration for RPC calls to fetch rollup data.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of rollup blocks, ready for database import.
  #   - A list of rollup transactions, ready for database import.
  defp get_rollup_blocks_and_transactions(
         batches,
         rollup_rpc_config
       ) do
    blocks_to_batches = unwrap_rollup_block_ranges(batches)

    required_blocks_numbers = Map.keys(blocks_to_batches)
    log_debug("Identified #{length(required_blocks_numbers)} rollup blocks")

    {blocks_to_import_map, txs_to_import_list} =
      get_rollup_blocks_and_txs_from_db(required_blocks_numbers, blocks_to_batches)

    # While it's not entirely aligned with data integrity principles to recover
    # rollup blocks and transactions from RPC that are not yet indexed, it's
    # a practical compromise to facilitate the progress of batch discovery. Given
    # the potential high frequency of new batch appearances and the substantial
    # volume of blocks and transactions, prioritizing discovery process advancement
    # is deemed reasonable.
    {blocks_to_import, txs_to_import} =
      recover_data_if_necessary(
        blocks_to_import_map,
        txs_to_import_list,
        required_blocks_numbers,
        blocks_to_batches,
        rollup_rpc_config
      )

    log_info(
      "Found #{length(Map.keys(blocks_to_import))} rollup blocks and #{length(txs_to_import)} rollup transactions in DB"
    )

    {blocks_to_import, txs_to_import}
  end

  # Unwraps rollup block ranges from batch data to create a block-to-batch number map.
  #
  # ## Parameters
  # - `batches`: A map where keys are batch identifiers and values are structs
  #              containing the start and end blocks of each batch.
  #
  # ## Returns
  # - A map where each key is a rollup block number and its value is the
  #   corresponding batch number.
  defp unwrap_rollup_block_ranges(batches) do
    batches
    |> Map.values()
    |> Enum.reduce(%{}, fn batch, b_2_b ->
      batch.start_block..batch.end_block
      |> Enum.reduce(b_2_b, fn block_num, b_2_b_inner ->
        Map.put(b_2_b_inner, block_num, batch.number)
      end)
    end)
  end

  # Retrieves rollup blocks and transactions from the database based on given block numbers.
  #
  # This function fetches rollup blocks from the database using provided block numbers.
  # For each block, it constructs a map of rollup block details and a list of
  # transactions, including the batch number from `blocks_to_batches` mapping, block
  # hash, and transaction hash.
  #
  # ## Parameters
  # - `rollup_blocks_numbers`: A list of rollup block numbers to retrieve from the
  #                            database.
  # - `blocks_to_batches`: A mapping from block numbers to batch numbers.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of rollup blocks associated with the batch numbers, ready for
  #     database import.
  #   - A list of transactions, each associated with its respective rollup block
  #     and batch number, ready for database import.
  defp get_rollup_blocks_and_txs_from_db(rollup_blocks_numbers, blocks_to_batches) do
    rollup_blocks_numbers
    |> Db.rollup_blocks()
    |> Enum.reduce({%{}, []}, fn block, {blocks_map, txs_list} ->
      batch_num = blocks_to_batches[block.number]

      updated_txs_list =
        block.transactions
        |> Enum.reduce(txs_list, fn tx, acc ->
          [%{tx_hash: tx.hash.bytes, batch_number: batch_num} | acc]
        end)

      updated_blocks_map =
        blocks_map
        |> Map.put(block.number, %{
          block_number: block.number,
          batch_number: batch_num,
          confirmation_id: nil
        })

      {updated_blocks_map, updated_txs_list}
    end)
  end

  # Recovers missing rollup blocks and transactions from the RPC if not all required blocks are found in the current data.
  #
  # This function compares the required rollup block numbers with the ones already
  # present in the current data. If some blocks are missing, it retrieves them from
  # the RPC along with their transactions. The retrieved blocks and transactions
  # are then merged with the current data to ensure a complete set for further
  # processing.
  #
  # ## Parameters
  # - `current_rollup_blocks`: The map of rollup blocks currently held.
  # - `current_rollup_txs`: The list of transactions currently held.
  # - `required_blocks_numbers`: A list of block numbers that are required for
  #                              processing.
  # - `blocks_to_batches`: A map associating rollup block numbers with batch numbers.
  # - `rollup_rpc_config`: Configuration for the RPC calls.
  #
  # ## Returns
  # - A tuple containing the updated map of rollup blocks and the updated list of
  #   transactions, both are ready for database import.
  defp recover_data_if_necessary(
         current_rollup_blocks,
         current_rollup_txs,
         required_blocks_numbers,
         blocks_to_batches,
         rollup_rpc_config
       ) do
    required_blocks_amount = length(required_blocks_numbers)

    found_blocks_numbers = Map.keys(current_rollup_blocks)
    found_blocks_numbers_length = length(found_blocks_numbers)

    if found_blocks_numbers_length != required_blocks_amount do
      log_info("Only #{found_blocks_numbers_length} of #{required_blocks_amount} rollup blocks found in DB")

      {recovered_blocks_map, recovered_txs_list, _} =
        recover_rollup_blocks_and_txs_from_rpc(
          required_blocks_numbers,
          found_blocks_numbers,
          blocks_to_batches,
          rollup_rpc_config
        )

      {Map.merge(current_rollup_blocks, recovered_blocks_map), current_rollup_txs ++ recovered_txs_list}
    else
      {current_rollup_blocks, current_rollup_txs}
    end
  end

  # Recovers missing rollup blocks and their transactions from RPC based on required block numbers.
  #
  # This function identifies missing rollup blocks by comparing the required block
  # numbers with those already found. It then fetches the missing blocks in chunks
  # using JSON RPC calls, aggregating the results into a map of rollup blocks and
  # a list of transactions. The data is processed to ensure each block and its
  # transactions are correctly associated with their batch number.
  #
  # ## Parameters
  # - `required_blocks_numbers`: A list of block numbers that are required to be
  #                              fetched.
  # - `found_blocks_numbers`: A list of block numbers that have already been
  #                           fetched.
  # - `blocks_to_batches`: A map linking block numbers to their respective batch
  #                        numbers.
  # - `rollup_rpc_config`: A map containing configuration parameters including
  #                        JSON RPC arguments for rollup RPC and the chunk size
  #                        for batch processing.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of rollup blocks associated with the batch numbers, ready for
  #     database import.
  #   - A list of transactions, each associated with its respective rollup block
  #     and batch number, ready for database import.
  #   - The updated counter of processed chunks (usually ignored).
  defp recover_rollup_blocks_and_txs_from_rpc(
         required_blocks_numbers,
         found_blocks_numbers,
         blocks_to_batches,
         %{
           json_rpc_named_arguments: rollup_json_rpc_named_arguments,
           chunk_size: rollup_chunk_size
         } = _rollup_rpc_config
       ) do
    missed_blocks = required_blocks_numbers -- found_blocks_numbers
    missed_blocks_length = length(missed_blocks)

    missed_blocks
    |> Enum.sort()
    |> Enum.chunk_every(rollup_chunk_size)
    |> Enum.reduce({%{}, [], 0}, fn chunk, {blocks_map, txs_list, chunks_counter} ->
      Logging.log_details_chunk_handling(
        "Collecting rollup data",
        {"block", "blocks"},
        chunk,
        chunks_counter,
        missed_blocks_length
      )

      requests =
        chunk
        |> Enum.reduce([], fn block_num, requests_list ->
          [
            BlockByNumber.request(
              %{
                id: blocks_to_batches[block_num],
                number: block_num
              },
              false
            )
            | requests_list
          ]
        end)

      {blocks_map_updated, txs_list_updated} =
        requests
        |> Rpc.make_chunked_request_keep_id(rollup_json_rpc_named_arguments, "eth_getBlockByNumber")
        |> prepare_rollup_block_map_and_transactions_list(blocks_map, txs_list)

      {blocks_map_updated, txs_list_updated, chunks_counter + length(chunk)}
    end)
  end

  # Processes JSON responses to construct a mapping of rollup block information and a list of transactions.
  #
  # This function takes JSON RPC responses for rollup blocks and processes each
  # response to create a mapping of rollup block details and a comprehensive list
  # of transactions associated with these blocks. It ensures that each block and its
  # corresponding transactions are correctly associated with their batch number.
  #
  # ## Parameters
  # - `json_responses`: A list of JSON RPC responses containing rollup block data.
  # - `rollup_blocks`: The initial map of rollup block information.
  # - `rollup_txs`: The initial list of rollup transactions.
  #
  # ## Returns
  # - A tuple containing:
  #   - An updated map of rollup blocks associated with their batch numbers, ready
  #     for database import.
  #   - An updated list of transactions, each associated with its respective rollup
  #     block and batch number, ready for database import.
  defp prepare_rollup_block_map_and_transactions_list(json_responses, rollup_blocks, rollup_txs) do
    json_responses
    |> Enum.reduce({rollup_blocks, rollup_txs}, fn resp, {blocks_map, txs_list} ->
      batch_num = resp.id
      blk_num = quantity_to_integer(resp.result["number"])

      updated_blocks_map =
        Map.put(
          blocks_map,
          blk_num,
          %{block_number: blk_num, batch_number: batch_num, confirmation_id: nil}
        )

      updated_txs_list =
        case resp.result["transactions"] do
          nil ->
            txs_list

          new_txs ->
            Enum.reduce(new_txs, txs_list, fn l2_tx_hash, txs_list ->
              [%{tx_hash: l2_tx_hash, batch_number: batch_num} | txs_list]
            end)
        end

      {updated_blocks_map, updated_txs_list}
    end)
  end

  # Retrieves the unique identifier of an L1 transaction by its hash from the given
  # map. `nil` if there is no such transaction in the map.
  defp get_l1_tx_id_by_hash(l1_txs, hash) do
    l1_txs
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
  end

  # Aggregates rollup transactions by batch number, counting the number of transactions in each batch.
  defp batches_to_rollup_txs_amounts(rollup_txs) do
    rollup_txs
    |> Enum.reduce(%{}, fn tx, acc ->
      Map.put(acc, tx.batch_number, Map.get(acc, tx.batch_number, 0) + 1)
    end)
  end

  # Retrieves initiated L2-to-L1 messages up to specified block number and marks them as 'sent'.
  defp get_committed_l2_to_l1_messages(block_number) do
    block_number
    |> Db.initiated_l2_to_l1_messages()
    |> Enum.map(fn tx ->
      Map.put(tx, :status, :sent)
    end)
  end
end
