defmodule Indexer.Fetcher.Arbitrum.Workers.NewBatches do
  @moduledoc """
    Manages the discovery and importation of new and historical batches of transactions for an Arbitrum rollup.

    This module orchestrates the discovery of batches of transactions processed
    through the Arbitrum Sequencer. It distinguishes between new batches currently
    being created and historical batches processed in the past but not yet imported
    into the database.

    Fetch logs for the `SequencerBatchDelivered` event emitted by the Arbitrum
    `SequencerInbox` contract. Process the logs to extract batch details. Build the
    link between batches and the corresponding rollup blocks and transactions. If
    the batch data is located in Data Availability solutions like AnyTrust or
    Celestia, fetch DA information to locate the batch data. Discover cross-chain
    messages initiated in rollup blocks linked with the new batches and update the
    status of messages to consider them as committed (`:sent`).

    For any blocks or transactions missing in the database, data is requested in
    chunks from the rollup RPC endpoint by `eth_getBlockByNumber`. Additionally,
    to complete batch details and lifecycle transactions, RPC calls to
    `eth_getTransactionByHash` and `eth_getBlockByNumber` on L1 are made in chunks
    for the necessary information not available in the logs.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_debug: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Indexer.Fetcher.Arbitrum.DA.Common, as: DataAvailabilityInfo
  alias Indexer.Fetcher.Arbitrum.DA.{Anytrust, Celestia}
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Common, as: DbCommon
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Db.ParentChainTransactions, as: DbParentChainTransactions
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.{Logging, Rpc}
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum
  alias Explorer.Chain.Events.Publisher

  require Logger

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
            :node_interface_address => binary(),
            optional(any()) => any()
          },
          :data => %{
            :new_batches_start_block => non_neg_integer(),
            :historical_batches_end_block => non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  def discover_new_batches(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            rollup_rpc: rollup_rpc_config,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            new_batches_limit: new_batches_limit,
            node_interface_address: node_interface_address
          },
          data: %{new_batches_start_block: start_block, historical_batches_end_block: historical_batches_end_block}
        } = _state
      ) do
    # Requesting the "latest" block instead of "safe" allows to catch new batches
    # without latency.

    # It is necessary to re-visit some amount of the previous blocks to ensure that
    # no batches are missed due to reorgs. The amount of blocks to re-visit depends
    # on the current safe block or the block which is considered as safest in case
    # of L3 (where the safe block could be too far behind the latest block) or if
    # RPC does not support "safe" block.
    {safe_block, latest_block} =
      Rpc.get_safe_and_latest_l1_blocks(l1_rpc_config.json_rpc_named_arguments, l1_rpc_config.logs_block_range)

    # At the same time it does not make sense to re-visit blocks that will be
    # re-visited by the historical batches discovery process.
    # If the new batches discovery process does not reach the chain head previously
    # no need to re-visit the blocks.
    safe_start_block = max(min(start_block, safe_block), historical_batches_end_block + 1)

    end_block = min(start_block + l1_rpc_config.logs_block_range - 1, latest_block)

    if safe_start_block <= end_block do
      log_info("Block range for new batches discovery: #{safe_start_block}..#{end_block}")

      # Since with taking the safe block into account, the range safe_start_block..end_block
      # could be larger than L1 RPC max block range for getting logs, it is necessary to
      # divide the range into the chunks
      ArbitrumHelper.execute_for_block_range_in_chunks(
        safe_start_block,
        end_block,
        l1_rpc_config.logs_block_range,
        fn chunk_start, chunk_end ->
          discover(
            sequencer_inbox_address,
            chunk_start,
            chunk_end,
            new_batches_limit,
            messages_to_blocks_shift,
            l1_rpc_config,
            node_interface_address,
            rollup_rpc_config
          )
        end
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
            :node_interface_address => binary(),
            optional(any()) => any()
          },
          :data => %{:historical_batches_end_block => non_neg_integer(), optional(any()) => any()},
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
            new_batches_limit: new_batches_limit,
            node_interface_address: node_interface_address
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
        node_interface_address,
        rollup_rpc_config
      )

      {:ok, start_block}
    else
      {:ok, l1_rollup_init_block}
    end
  end

  @doc """
    Inspects and imports missing batches within a specified range of batch numbers.

    This function first finds the missing batches, then determines their
    neighboring ranges, maps these ranges to the corresponding L1 block numbers,
    and for every such range it retrieves logs representing the
    SequencerBatchDelivered events emitted by the SequencerInbox contract.
    These logs are processed to identify the batches and their details. The
    function then constructs comprehensive data structures for batches,
    lifecycle transactions, rollup blocks, and rollup transactions. Additionally,
    it identifies L2-to-L1 messages that have been committed within these batches
    and updates their status. All discovered and processed data are then imported
    into the database.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including the L1 rollup initialization block,
                  RPC configurations, SequencerInbox address, a shift for the message
                  to block number mapping, a limit for new batches discovery, and the
                  max size of the range for missing batches inspection.
      - `data`: Contains the ending batch number for the missing batches inspection.

    ## Returns
    - `{:ok, start_batch}`: On successful inspection of the given batch range, where
      `start_batch` is the calculated starting batch for the inspected range,
      indicating the need to consider another batch range in the next iteration of
      missing batch inspection.
    - `{:ok, lowest_batch}`: If the discovery process has been finished, indicating
      that all batches up to the rollup origins have been checked and no further
      action is needed.
  """
  @spec inspect_for_missing_batches(%{
          :config => %{
            :l1_rollup_init_block => non_neg_integer(),
            :l1_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            :l1_sequencer_inbox_address => binary(),
            :lowest_batch => non_neg_integer(),
            :messages_to_blocks_shift => non_neg_integer(),
            :missing_batches_range => non_neg_integer(),
            :new_batches_limit => non_neg_integer(),
            :node_interface_address => binary(),
            :rollup_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :chunk_size => non_neg_integer(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          :data => %{:missing_batches_end_batch => non_neg_integer(), optional(any()) => any()},
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  def inspect_for_missing_batches(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            rollup_rpc: rollup_rpc_config,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            l1_rollup_init_block: l1_rollup_init_block,
            new_batches_limit: new_batches_limit,
            missing_batches_range: missing_batches_range,
            lowest_batch: lowest_batch,
            node_interface_address: node_interface_address
          },
          data: %{missing_batches_end_batch: end_batch}
        } = _state
      )
      when not is_nil(lowest_batch) and not is_nil(end_batch) do
    # No need to inspect for missing batches below the lowest batch
    # since it is assumed that they are picked up by historical batches
    # discovery process
    if end_batch > lowest_batch do
      start_batch = max(lowest_batch, end_batch - missing_batches_range + 1)

      log_info("Batch range for missing batches inspection: #{start_batch}..#{end_batch}")

      l1_block_ranges_for_missing_batches =
        DbSettlement.get_l1_block_ranges_for_missing_batches(start_batch, end_batch, l1_rollup_init_block - 1)

      unless l1_block_ranges_for_missing_batches == [] do
        discover_missing_batches(
          sequencer_inbox_address,
          l1_block_ranges_for_missing_batches,
          new_batches_limit,
          messages_to_blocks_shift,
          l1_rpc_config,
          node_interface_address,
          rollup_rpc_config
        )
      end

      {:ok, start_batch}
    else
      {:ok, lowest_batch}
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
  # - `node_interface_address`: The address of the NodeInterface contract on the rollup.
  # - `rollup_rpc_config`: Configuration for rollup RPC calls.
  #
  # ## Returns
  # - N/A
  @spec discover(
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          binary(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) :: any()
  defp discover(
         sequencer_inbox_address,
         start_block,
         end_block,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         node_interface_address,
         rollup_rpc_config
       ) do
    do_discover(
      sequencer_inbox_address,
      start_block,
      end_block,
      new_batches_limit,
      messages_to_blocks_shift,
      l1_rpc_config,
      node_interface_address,
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
  # - `node_interface_address`: The address of the NodeInterface contract on the rollup.
  # - `rollup_rpc_config`: Configuration for rollup RPC calls.
  #
  # ## Returns
  # - N/A
  @spec discover_historical(
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          binary(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) :: any()
  defp discover_historical(
         sequencer_inbox_address,
         start_block,
         end_block,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         node_interface_address,
         rollup_rpc_config
       ) do
    do_discover(
      sequencer_inbox_address,
      end_block,
      start_block,
      new_batches_limit,
      messages_to_blocks_shift,
      l1_rpc_config,
      node_interface_address,
      rollup_rpc_config
    )
  end

  # Initiates the discovery process for missing batches within specified block ranges.
  #
  # This function divides each L1 block range into chunks to call `discover_historical`
  # for every chunk to discover missing batches.
  #
  # ## Parameters
  # - `sequencer_inbox_address`: The SequencerInbox contract address.
  # - `l1_block_ranges`: The L1 block ranges to look for missing batches.
  # - `new_batches_limit`: Limit of new batches to process in one iteration.
  # - `messages_to_blocks_shift`: Shift value for message to block number mapping.
  # - `l1_rpc_config`: Configuration for L1 RPC calls.
  # - `node_interface_address`: The address of the NodeInterface contract on the rollup.
  # - `rollup_rpc_config`: Configuration for rollup RPC calls.
  #
  # ## Returns
  # - N/A
  @spec discover_missing_batches(
          binary(),
          [{non_neg_integer(), non_neg_integer()}],
          non_neg_integer(),
          non_neg_integer(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :logs_block_range => non_neg_integer(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          binary(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) :: :ok
  defp discover_missing_batches(
         sequencer_inbox_address,
         l1_block_ranges,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         node_interface_address,
         rollup_rpc_config
       ) do
    Enum.each(l1_block_ranges, fn {start_block, end_block} ->
      ArbitrumHelper.execute_for_block_range_in_chunks(
        start_block,
        end_block,
        l1_rpc_config.logs_block_range,
        fn chunk_start, chunk_end ->
          # `do_discover` is not used here to demonstrate the need to fetch batches
          # which are already historical
          discover_historical(
            sequencer_inbox_address,
            chunk_start,
            chunk_end,
            new_batches_limit,
            messages_to_blocks_shift,
            l1_rpc_config,
            node_interface_address,
            rollup_rpc_config
          )
        end
      )
    end)
  end

  # Performs the discovery of new or historical batches within a specified block range,
  # processing and importing the relevant data into the database.
  #
  # This function retrieves SequencerBatchDelivered event logs from the specified block
  # range and processes these logs to identify new batches and their corresponding details.
  # It then constructs comprehensive data structures for batches, lifecycle transactions,
  # rollup blocks, rollup transactions, and Data Availability related records. Additionally,
  # it identifies any L2-to-L1 messages that have been committed within these batches and
  # updates their status. All discovered and processed data are then imported into the
  # database. If new batches were found, they are announced to be broadcasted through a
  # websocket.
  #
  # ## Parameters
  # - `sequencer_inbox_address`: The SequencerInbox contract address used to filter logs.
  # - `start_block`: The starting block number for the discovery range.
  # - `end_block`: The ending block number for the discovery range.
  # - `new_batches_limit`: The maximum number of new batches to process in one iteration.
  # - `messages_to_blocks_shift`: The value used to align message counts with rollup block
  #   numbers.
  # - `l1_rpc_config`: RPC configuration parameters for L1.
  # - `node_interface_address`: The address of the NodeInterface contract on the rollup.
  # - `rollup_rpc_config`: RPC configuration parameters for rollup data.
  #
  # ## Returns
  # - N/A
  @spec do_discover(
          binary(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          binary(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) :: any()
  defp do_discover(
         sequencer_inbox_address,
         start_block,
         end_block,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         node_interface_address,
         rollup_rpc_config
       ) do
    raw_logs =
      get_logs_new_batches(
        min(start_block, end_block),
        max(start_block, end_block),
        sequencer_inbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    new_batches_discovery? = end_block >= start_block

    logs =
      if new_batches_discovery? do
        # called by `discover`
        raw_logs
      else
        # called by `discover_historical`
        Enum.reverse(raw_logs)
      end

    # Discovered logs are divided into chunks to ensure progress
    # in batch discovery, even if an error interrupts the fetching process.
    logs
    |> Enum.chunk_every(new_batches_limit)
    |> Enum.each(fn chunked_logs ->
      {batches, lifecycle_transactions, rollup_blocks, rollup_transactions, committed_transactions, da_records,
       batch_to_data_blobs} =
        handle_batches_from_logs(
          chunked_logs,
          messages_to_blocks_shift,
          l1_rpc_config,
          sequencer_inbox_address,
          node_interface_address,
          rollup_rpc_config
        )

      {:ok, _} =
        Chain.import(%{
          arbitrum_lifecycle_transactions: %{params: lifecycle_transactions},
          arbitrum_l1_batches: %{params: batches},
          arbitrum_batch_blocks: %{params: rollup_blocks},
          arbitrum_batch_transactions: %{params: rollup_transactions},
          arbitrum_messages: %{params: committed_transactions},
          arbitrum_da_multi_purpose_records: %{params: da_records},
          arbitrum_batches_to_da_blobs: %{params: batch_to_data_blobs},
          timeout: :infinity
        })

      if not Enum.empty?(batches) and new_batches_discovery? do
        Publisher.broadcast(
          [{:new_arbitrum_batches, extend_batches_with_commitment_transactions(batches, lifecycle_transactions)}],
          :realtime
        )
      end
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
  @spec get_logs_new_batches(non_neg_integer(), non_neg_integer(), binary(), EthereumJSONRPC.json_rpc_named_arguments()) ::
          [%{String.t() => any()}]
  defp get_logs_new_batches(start_block, end_block, sequencer_inbox_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        sequencer_inbox_address,
        [ArbitrumEvents.sequencer_batch_delivered()],
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
  # L1 transactions and blocks, including timestamps and block ranges. The lifecycle
  # transactions for already known batches are updated with actual block numbers and
  # timestamps. The function then prepares batches, associated rollup blocks and
  # transactions, lifecycle transactions and Data Availability related records for
  # database import.
  # Additionally, L2-to-L1 messages initiated in the rollup blocks associated with the
  # discovered batches are retrieved from the database, marked as `:sent`, and prepared
  # for database import.
  #
  # ## Parameters
  # - `logs`: The list of SequencerBatchDelivered event logs.
  # - `msg_to_block_shift`: The shift value for mapping batch messages to block numbers.
  # - `l1_rpc_config`: The RPC configuration for L1 requests.
  # - `sequencer_inbox_address`: The address of the SequencerInbox contract.
  # - `node_interface_address`: The address of the NodeInterface contract on the rollup.
  # - `rollup_rpc_config`: The RPC configuration for rollup data requests.
  #
  # ## Returns
  # - A tuple containing lists of batches, lifecycle transactions, rollup blocks,
  #   rollup transactions, committed messages (with the status `:sent`), records
  #   with DA-related information if applicable, and batch-to-DA-blob associations,
  #   all ready for database import.
  @spec handle_batches_from_logs(
          [%{String.t() => any()}],
          non_neg_integer(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          binary(),
          binary(),
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) :: {
          [Arbitrum.L1Batch.to_import()],
          [Arbitrum.LifecycleTransaction.to_import()],
          [Arbitrum.BatchBlock.to_import()],
          [Arbitrum.BatchTransaction.to_import()],
          [Arbitrum.Message.to_import()],
          [Arbitrum.DaMultiPurposeRecord.to_import()],
          [Arbitrum.BatchToDaBlob.to_import()]
        }
  defp handle_batches_from_logs(
         logs,
         msg_to_block_shift,
         l1_rpc_config,
         sequencer_inbox_address,
         node_interface_address,
         rollup_rpc_config
       )

  defp handle_batches_from_logs([], _, _, _, _, _), do: {[], [], [], [], [], [], []}

  defp handle_batches_from_logs(
         logs,
         msg_to_block_shift,
         %{
           json_rpc_named_arguments: json_rpc_named_arguments,
           chunk_size: chunk_size
         } = l1_rpc_config,
         sequencer_inbox_address,
         node_interface_address,
         rollup_rpc_config
       ) do
    existing_batches =
      logs
      |> Rpc.extract_batch_numbers_from_logs()
      |> DbSettlement.batches_exist()

    {batches, transactions_requests, blocks_requests, existing_commitment_transactions} =
      parse_logs_for_new_batches(logs, existing_batches)

    blocks_to_ts = Rpc.execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size)

    {initial_lifecycle_transactions, batches_to_import, da_info} =
      execute_transaction_requests_parse_transactions_calldata(
        transactions_requests,
        msg_to_block_shift,
        blocks_to_ts,
        batches,
        l1_rpc_config,
        %{
          node_interface_address: node_interface_address,
          json_rpc_named_arguments: rollup_rpc_config.json_rpc_named_arguments
        }
      )

    # Check if the commitment transactions for the batches which are already in the database
    # needs to be updated in case of reorgs
    lifecycle_transactions_wo_indices =
      initial_lifecycle_transactions
      |> Map.merge(update_lifecycle_transactions_for_new_blocks(existing_commitment_transactions, blocks_to_ts))

    {blocks_to_import, rollup_transactions_to_import} =
      get_rollup_blocks_and_transactions(batches_to_import, rollup_rpc_config)

    lifecycle_transactions =
      lifecycle_transactions_wo_indices
      |> DbParentChainTransactions.get_indices_for_l1_transactions()

    transaction_counts_per_batch = batches_to_rollup_transactions_amounts(rollup_transactions_to_import)

    batches_list_to_import =
      batches_to_import
      |> Map.values()
      |> Enum.reduce([], fn batch, updated_batches_list ->
        [
          batch
          |> Map.put(:commitment_id, get_l1_transaction_id_by_hash(lifecycle_transactions, batch.transaction_hash))
          |> Map.put(
            :transactions_count,
            case transaction_counts_per_batch[batch.number] do
              nil -> 0
              value -> value
            end
          )
          |> Map.drop([:transaction_hash])
          | updated_batches_list
        ]
      end)

    {da_records, batch_to_data_blobs} =
      DataAvailabilityInfo.prepare_for_import(da_info, %{
        sequencer_inbox_address: sequencer_inbox_address,
        json_rpc_named_arguments: l1_rpc_config.json_rpc_named_arguments
      })

    # It is safe to not re-mark messages as committed for the batches that are already in the database
    committed_messages =
      if Enum.empty?(blocks_to_import) do
        []
      else
        # Without check on the empty list of keys `Enum.max()` will raise an error
        blocks_to_import
        |> Map.keys()
        |> Enum.max()
        |> get_committed_l2_to_l1_messages()
      end

    {batches_list_to_import, Map.values(lifecycle_transactions), Map.values(blocks_to_import),
     rollup_transactions_to_import, committed_messages, da_records, batch_to_data_blobs}
  end

  # Parses logs representing SequencerBatchDelivered events to identify new batches.
  #
  # This function sifts through logs of SequencerBatchDelivered events, extracts the
  # necessary data, and assembles a map of new batch descriptions. Additionally, it
  # prepares RPC `eth_getTransactionByHash` and `eth_getBlockByNumber` requests to
  # fetch details not present in the logs. To minimize subsequent RPC calls, requests to
  # get the transactions details are only made for batches not previously known.
  # For the existing batches, the function prepares a map of commitment transactions
  # assuming that they must be updated if reorgs occur.
  #
  # The function skips the batch with number 0, as this batch does not contain any
  # rollup blocks and transactions.
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
  #   - A map of commitment transactions for the existing batches where the value is
  #     the block number of the transaction.
  @spec parse_logs_for_new_batches(
          [%{String.t() => any()}],
          [non_neg_integer()]
        ) :: {
          %{
            non_neg_integer() => %{
              :number => non_neg_integer(),
              :before_acc => binary(),
              :after_acc => binary(),
              :transaction_hash => binary()
            }
          },
          [EthereumJSONRPC.Transport.request()],
          [EthereumJSONRPC.Transport.request()],
          %{binary() => non_neg_integer()}
        }
  defp parse_logs_for_new_batches(logs, existing_batches) do
    {batches, transactions_requests, blocks_requests, existing_commitment_transactions} =
      logs
      |> Enum.reduce({%{}, [], %{}, %{}}, fn event, acc ->
        transaction_hash_raw = event["transactionHash"]
        blk_num = quantity_to_integer(event["blockNumber"])

        handle_new_batch_data(
          {Rpc.parse_sequencer_batch_delivered_event(event), transaction_hash_raw, blk_num},
          existing_batches,
          acc
        )
      end)

    {batches, transactions_requests, Map.values(blocks_requests), existing_commitment_transactions}
  end

  # Handles the new batch data to assemble a map of new batch descriptions.
  #
  # This function processes the new batch data by assembling a map of new batch
  # descriptions and preparing RPC `eth_getTransactionByHash` and `eth_getBlockByNumber`
  # requests to fetch details not present in the received batch data. To minimize
  # subsequent RPC calls, requests to get the transaction details are only made for
  # batches not previously known. For existing batches, the function prepares a map
  # of commitment transactions, assuming that they must be updated if reorgs occur.
  # If the batch number is zero, the function does nothing.
  #
  # ## Parameters
  # - `batch_data`: A tuple containing the batch number, before and after accumulators,
  #   transaction hash, and block number.
  # - `existing_batches`: A list of batch numbers that are already processed.
  # - `acc`: A tuple containing new batch descriptions, transaction requests,
  #   block requests, and existing commitment transactions maps.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of new batch descriptions, which are not yet ready for database import.
  #   - A list of RPC `eth_getTransactionByHash` requests for fetching details of
  #     the L1 transactions associated with these batches.
  #   - A map of RPC requests to fetch details of the L1 blocks where these batches
  #     were included. The keys of the map are L1 block numbers.
  #   - A map of commitment transactions for the existing batches where the value is
  #     the block number of the transaction.
  @spec handle_new_batch_data(
          {{non_neg_integer(), binary(), binary()}, binary(), non_neg_integer()},
          [non_neg_integer()],
          {map(), list(), map(), map()}
        ) :: {
          %{
            non_neg_integer() => %{
              :number => non_neg_integer(),
              :before_acc => binary(),
              :after_acc => binary(),
              :transaction_hash => binary()
            }
          },
          [EthereumJSONRPC.Transport.request()],
          %{non_neg_integer() => EthereumJSONRPC.Transport.request()},
          %{binary() => non_neg_integer()}
        }
  defp handle_new_batch_data(
         batch_data,
         existing_batches,
         acc
       )

  defp handle_new_batch_data({{batch_num, _, _}, _, _}, _, acc) when batch_num == 0, do: acc

  defp handle_new_batch_data(
         {{batch_num, before_acc, after_acc}, transaction_hash_raw, blk_num},
         existing_batches,
         {batches, transactions_requests, blocks_requests, existing_commitment_transactions}
       ) do
    transaction_hash = Rpc.string_hash_to_bytes_hash(transaction_hash_raw)

    {updated_batches, updated_transactions_requests, updated_existing_commitment_transactions} =
      if batch_num in existing_batches do
        {batches, transactions_requests, Map.put(existing_commitment_transactions, transaction_hash, blk_num)}
      else
        log_info("New batch #{batch_num} found in #{transaction_hash_raw}")

        updated_batches =
          Map.put(
            batches,
            batch_num,
            %{
              number: batch_num,
              before_acc: before_acc,
              after_acc: after_acc,
              transaction_hash: transaction_hash
            }
          )

        updated_transactions_requests = [
          Rpc.transaction_by_hash_request(%{id: 0, hash: transaction_hash_raw})
          | transactions_requests
        ]

        {updated_batches, updated_transactions_requests, existing_commitment_transactions}
      end

    # In order to have an ability to update commitment transaction for the existing batches
    # in case of reorgs, we need to re-execute the block requests
    updated_blocks_requests =
      Map.put(
        blocks_requests,
        blk_num,
        BlockByNumber.request(%{id: 0, number: blk_num}, false, true)
      )

    {updated_batches, updated_transactions_requests, updated_blocks_requests, updated_existing_commitment_transactions}
  end

  # Executes transaction requests and parses the calldata to extract batch data.
  #
  # This function processes a list of RPC `eth_getTransactionByHash` requests, extracts
  # and decodes the calldata from the transactions to obtain batch details. It updates
  # the provided batch map with block ranges for new batches and constructs a map of
  # lifecycle transactions with their timestamps and finalization status. Additionally,
  # it examines the data availability (DA) information for Anytrust or Celestia and
  # constructs a list of DA info structs.
  #
  # ## Parameters
  # - `transactions_requests`: The list of RPC requests to fetch transaction data.
  # - `msg_to_block_shift`: The shift value to adjust the message count to the correct
  #                         rollup block numbers.
  # - `blocks_to_ts`: A map of block numbers to their timestamps, required to complete
  #                   data for corresponding lifecycle transactions.
  # - `batches`: The current batch data to be updated.
  # - A configuration map containing L1 JSON RPC arguments, a track finalization flag,
  #   and a chunk size for batch processing.
  # - A configuration map containing the rollup RPC arguments and the address of the
  #   NodeInterface contract.
  #
  # ## Returns
  # - A tuple containing:
  #   - A map of lifecycle (L1) transactions, which are not yet compatible with
  #     database import and require further processing.
  #   - An updated map of batch descriptions with block ranges and data availability
  #     information.
  #   - A list of data availability information structs for Anytrust or Celestia.
  @spec execute_transaction_requests_parse_transactions_calldata(
          [EthereumJSONRPC.Transport.request()],
          non_neg_integer(),
          %{EthereumJSONRPC.block_number() => DateTime.t()},
          %{non_neg_integer() => map()},
          %{
            :chunk_size => non_neg_integer(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :track_finalization => boolean(),
            optional(any()) => any()
          },
          %{
            :node_interface_address => binary(),
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            optional(any()) => any()
          }
        ) ::
          {%{
             binary() => %{
               :hash => binary(),
               :block_number => non_neg_integer(),
               :timestamp => DateTime.t(),
               :status => :unfinalized | :finalized
             }
           },
           %{
             non_neg_integer() => %{
               :start_block => non_neg_integer(),
               :end_block => non_neg_integer(),
               :data_available => atom() | nil,
               optional(any()) => any()
             }
           }, [Anytrust.t() | Celestia.t()]}
  defp execute_transaction_requests_parse_transactions_calldata(
         transactions_requests,
         msg_to_block_shift,
         blocks_to_ts,
         batches,
         %{
           json_rpc_named_arguments: json_rpc_named_arguments,
           track_finalization: track_finalization?,
           chunk_size: chunk_size
         },
         rollup_config
       ) do
    transactions_requests
    |> Enum.chunk_every(chunk_size)
    |> Enum.reduce({%{}, batches, []}, fn chunk, {l1_transactions, updated_batches, da_info} ->
      chunk
      # each eth_getTransactionByHash will take time since it returns entire batch
      # in `input` which is heavy because contains dozens of rollup blocks
      |> Rpc.make_chunked_request(json_rpc_named_arguments, "eth_getTransactionByHash")
      |> Enum.reduce({l1_transactions, updated_batches, da_info}, fn resp,
                                                                     {transactions_map, batches_map, da_info_list} ->
        block_number = quantity_to_integer(resp["blockNumber"])
        transaction_hash = Rpc.string_hash_to_bytes_hash(resp["hash"])

        # Although they are called messages in the functions' ABI, in fact they are
        # rollup blocks
        {batch_num, prev_message_count, new_message_count, extra_data} =
          Rpc.parse_calldata_of_add_sequencer_l2_batch(resp["input"])

        # For the case when the rollup blocks range is not discovered on the previous
        # step due to handling of legacy events, it is required to make more
        # sophisticated lookup based on the previously discovered batches and requests
        # to the NodeInterface contract on the rollup.
        {batch_start_block, batch_end_block} =
          determine_batch_block_range(
            batch_num,
            prev_message_count,
            new_message_count,
            msg_to_block_shift,
            rollup_config
          )

        {da_type, da_data} =
          case DataAvailabilityInfo.examine_batch_accompanying_data(batch_num, extra_data) do
            {:ok, t, d} -> {t, d}
            {:error, _, _} -> {nil, nil}
          end

        updated_batches_map =
          Map.put(
            batches_map,
            batch_num,
            Map.merge(batches_map[batch_num], %{
              start_block: batch_start_block,
              end_block: batch_end_block,
              batch_container: da_type
            })
          )

        updated_transactions_map =
          Map.put(transactions_map, transaction_hash, %{
            hash: transaction_hash,
            block_number: block_number,
            timestamp: blocks_to_ts[block_number],
            status:
              if track_finalization? do
                :unfinalized
              else
                :finalized
              end
          })

        # credo:disable-for-lines:6 Credo.Check.Refactor.Nesting
        updated_da_info_list =
          if DataAvailabilityInfo.required_import?(da_type) do
            [da_data | da_info_list]
          else
            da_info_list
          end

        {updated_transactions_map, updated_batches_map, updated_da_info_list}
      end)
    end)
  end

  # Determines the block range for a batch based on provided message counts and
  # previously discovered batches. If the message counts are nil, it attempts to
  # find the block range by inspecting neighboring batches.
  #
  # Parameters:
  # - `batch_number`: The batch number for which the block range is determined.
  # - `prev_message_count`: The message count of the previous batch, or nil if not
  #   available.
  # - `new_message_count`: The message count of the current batch, or nil if not
  #   available.
  # - `msg_to_block_shift`: A shift value used to adjust the block numbers based
  #   on message counts.
  # - `rollup_config`: A map containing the `NodeInterface` contract address and
  #   configuration parameters for the JSON RPC connection.
  #
  # Returns:
  # - A tuple `{start_block, end_block}` representing the range of blocks included
  #   in the specified batch.
  #
  # If both `prev_message_count` and `new_message_count` are nil, the function logs
  # an attempt to determine the block range based on already discovered batches.
  # It calculates the highest and lowest blocks for the neighboring batches and
  # uses them to infer the block range for the current batch. If only one neighbor
  # provides a block, it performs a binary search to find the opposite block.
  #
  # If the message counts are provided, it adjusts them by the specific shift value
  # `msg_to_block_shift` and returns the adjusted block range.
  @spec determine_batch_block_range(
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer() | nil,
          non_neg_integer(),
          %{
            node_interface_address: EthereumJSONRPC.address(),
            json_rpc_named_arguments: EthereumJSONRPC.json_rpc_named_arguments()
          }
        ) :: {non_neg_integer(), non_neg_integer()}
  defp determine_batch_block_range(batch_number, prev_message_count, new_message_count, _, rollup_config)
       when is_nil(prev_message_count) and is_nil(new_message_count) do
    log_info("No blocks range for batch ##{batch_number}. Trying to find it based on already discovered batches.")

    {highest_block, step_highest_to_lowest} = get_expected_highest_block_and_step(batch_number + 1)
    {lowest_block, step_lowest_to_highest} = get_expected_lowest_block_and_step(batch_number - 1)

    {start_block, end_block} =
      case {lowest_block, highest_block} do
        {nil, nil} -> raise "Impossible to determine the block range for batch #{batch_number}"
        {lowest, nil} -> Rpc.get_block_range_for_batch(lowest, step_lowest_to_highest, batch_number, rollup_config)
        {nil, highest} -> Rpc.get_block_range_for_batch(highest, step_highest_to_lowest, batch_number, rollup_config)
        {lowest, highest} -> {lowest, highest}
      end

    log_info("Blocks range for batch ##{batch_number} is determined as #{start_block}..#{end_block}")
    {start_block, end_block}
  end

  defp determine_batch_block_range(_, prev_message_count, new_message_count, msg_to_block_shift, _) do
    # In some cases extracted numbers for messages does not linked directly
    # with rollup blocks, for this, the numbers are shifted by a value specific
    # for particular rollup
    {prev_message_count + msg_to_block_shift, new_message_count + msg_to_block_shift - 1}
  end

  # Calculates the expected highest block and step required for the lowest block look up for a given batch number.
  @spec get_expected_highest_block_and_step(non_neg_integer()) :: {non_neg_integer(), non_neg_integer()} | {nil, nil}
  defp get_expected_highest_block_and_step(batch_number) do
    # since the default direction for the block range exploration is chosen to be from the highest to lowest
    # the step is calculated to be positive
    case DbSettlement.get_batch_by_number(batch_number) do
      nil ->
        {nil, nil}

      %Arbitrum.L1Batch{start_block: start_block, end_block: end_block} ->
        {start_block - 1, half_of_block_range(start_block, end_block, :descending)}
    end
  end

  # Calculates the expected lowest block and step required for the highest block look up for a given batch number.
  @spec get_expected_lowest_block_and_step(non_neg_integer()) :: {non_neg_integer(), integer()} | {nil, nil}
  defp get_expected_lowest_block_and_step(batch_number) do
    # since the default direction for the block range exploration is chosen to be from the highest to lowest
    # the step is calculated to be negative
    case DbSettlement.get_batch_by_number(batch_number) do
      nil ->
        {nil, nil}

      %Arbitrum.L1Batch{start_block: start_block, end_block: end_block} ->
        {end_block + 1, half_of_block_range(start_block, end_block, :ascending)}
    end
  end

  # Calculates half the range between two block numbers, with direction adjustment.
  #
  # ## Parameters
  # - `start_block`: The starting block number.
  # - `end_block`: The ending block number.
  # - `direction`: The direction of calculation, either `:ascending` or `:descending`.
  #
  # ## Returns
  # - An integer representing half the block range, adjusted for direction:
  #   - For `:descending`, a positive integer >= 1.
  #   - For `:ascending`, a negative integer <= -1.
  @spec half_of_block_range(non_neg_integer(), non_neg_integer(), :ascending | :descending) :: integer()
  defp half_of_block_range(start_block, end_block, direction) do
    case direction do
      :descending -> max(div(end_block - start_block + 1, 2), 1)
      :ascending -> min(div(start_block - end_block - 1, 2), -1)
    end
  end

  # Updates lifecycle transactions for new blocks by setting the block number and
  # timestamp for each transaction.
  #
  # The function checks if a transaction's block number and timestamp match the
  # new values. If they do not, the transaction is updated with the new block
  # number and timestamp.
  #
  # Parameters:
  # - `existing_commitment_transactions`: A map where keys are transaction hashes and
  #   values are block numbers.
  # - `block_to_ts`: A map where keys are block numbers and values are timestamps.
  #
  # Returns:
  # - A map where keys are transaction hashes and values are updated lifecycle
  #   transactions with the block number and timestamp set, compatible with the
  #   database import operation.
  @spec update_lifecycle_transactions_for_new_blocks(%{binary() => non_neg_integer()}, %{
          non_neg_integer() => non_neg_integer()
        }) ::
          %{binary() => Arbitrum.LifecycleTransaction.to_import()}
  defp update_lifecycle_transactions_for_new_blocks(existing_commitment_transactions, block_to_ts) do
    existing_commitment_transactions
    |> Map.keys()
    |> DbParentChainTransactions.lifecycle_transactions()
    |> Enum.reduce(%{}, fn transaction, transactions ->
      block_number = existing_commitment_transactions[transaction.hash]
      ts = block_to_ts[block_number]

      case ArbitrumHelper.compare_lifecycle_transaction_and_update(transaction, {block_number, ts}, "commitment") do
        {:updated, updated_transaction} ->
          Map.put(transactions, transaction.hash, updated_transaction)

        _ ->
          transactions
      end
    end)
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
  #   - A map of rollup blocks, where each block is ready for database import.
  #   - A list of rollup transactions, ready for database import.
  @spec get_rollup_blocks_and_transactions(
          %{
            non_neg_integer() => %{
              :number => non_neg_integer(),
              :start_block => non_neg_integer(),
              :end_block => non_neg_integer(),
              optional(any()) => any()
            }
          },
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) ::
          {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()]}
  defp get_rollup_blocks_and_transactions(
         batches,
         rollup_rpc_config
       ) do
    blocks_to_batches = unwrap_rollup_block_ranges(batches)

    required_blocks_numbers = Map.keys(blocks_to_batches)

    if required_blocks_numbers == [] do
      {%{}, []}
    else
      log_debug("Identified #{length(required_blocks_numbers)} rollup blocks")

      {blocks_to_import_map, transactions_to_import_list} =
        get_rollup_blocks_and_transactions_from_db(required_blocks_numbers, blocks_to_batches)

      # While it's not entirely aligned with data integrity principles to recover
      # rollup blocks and transactions from RPC that are not yet indexed, it's
      # a practical compromise to facilitate the progress of batch discovery. Given
      # the potential high frequency of new batch appearances and the substantial
      # volume of blocks and transactions, prioritizing discovery process advancement
      # is deemed reasonable.
      {blocks_to_import, transactions_to_import} =
        recover_data_if_necessary(
          blocks_to_import_map,
          transactions_to_import_list,
          required_blocks_numbers,
          blocks_to_batches,
          rollup_rpc_config
        )

      log_info(
        "Found #{length(Map.keys(blocks_to_import))} rollup blocks and #{length(transactions_to_import)} rollup transactions in DB"
      )

      {blocks_to_import, transactions_to_import}
    end
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
  @spec unwrap_rollup_block_ranges(%{
          non_neg_integer() => %{
            :start_block => non_neg_integer(),
            :end_block => non_neg_integer(),
            :number => non_neg_integer(),
            optional(any()) => any()
          }
        }) :: %{non_neg_integer() => non_neg_integer()}
  defp unwrap_rollup_block_ranges(batches) do
    batches
    |> Map.values()
    |> Enum.reduce(%{}, fn batch, b_2_b ->
      batch.start_block..batch.end_block
      |> Enum.reduce(b_2_b, fn block_number, b_2_b_inner ->
        Map.put(b_2_b_inner, block_number, batch.number)
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
  defp get_rollup_blocks_and_transactions_from_db(rollup_blocks_numbers, blocks_to_batches) do
    rollup_blocks_numbers
    |> DbCommon.rollup_blocks()
    |> Enum.reduce({%{}, []}, fn block, {blocks_map, transactions_list} ->
      batch_num = blocks_to_batches[block.number]

      updated_transactions_list =
        block.transactions
        |> Enum.reduce(transactions_list, fn transaction, acc ->
          [%{transaction_hash: transaction.hash.bytes, batch_number: batch_num} | acc]
        end)

      updated_blocks_map =
        blocks_map
        |> Map.put(block.number, %{
          block_number: block.number,
          batch_number: batch_num,
          confirmation_id: nil
        })

      {updated_blocks_map, updated_transactions_list}
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
  # - `current_rollup_transactions`: The list of transactions currently held.
  # - `required_blocks_numbers`: A list of block numbers that are required for
  #                              processing.
  # - `blocks_to_batches`: A map associating rollup block numbers with batch numbers.
  # - `rollup_rpc_config`: Configuration for the RPC calls.
  #
  # ## Returns
  # - A tuple containing the updated map of rollup blocks and the updated list of
  #   transactions, both are ready for database import.
  @spec recover_data_if_necessary(
          %{non_neg_integer() => Arbitrum.BatchBlock.to_import()},
          [Arbitrum.BatchTransaction.to_import()],
          [non_neg_integer()],
          %{non_neg_integer() => non_neg_integer()},
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) ::
          {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()]}
  defp recover_data_if_necessary(
         current_rollup_blocks,
         current_rollup_transactions,
         required_blocks_numbers,
         blocks_to_batches,
         rollup_rpc_config
       ) do
    required_blocks_amount = length(required_blocks_numbers)

    found_blocks_numbers = Map.keys(current_rollup_blocks)
    found_blocks_numbers_length = length(found_blocks_numbers)

    if found_blocks_numbers_length != required_blocks_amount do
      log_info("Only #{found_blocks_numbers_length} of #{required_blocks_amount} rollup blocks found in DB")

      {recovered_blocks_map, recovered_transactions_list, _} =
        recover_rollup_blocks_and_transactions_from_rpc(
          required_blocks_numbers,
          found_blocks_numbers,
          blocks_to_batches,
          rollup_rpc_config
        )

      {Map.merge(current_rollup_blocks, recovered_blocks_map),
       current_rollup_transactions ++ recovered_transactions_list}
    else
      {current_rollup_blocks, current_rollup_transactions}
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
  #   - A list of transactions, each associated with its respective rollup
  #     block and batch number, ready for database import.
  #   - The updated counter of processed chunks (usually ignored).
  @spec recover_rollup_blocks_and_transactions_from_rpc(
          [non_neg_integer()],
          [non_neg_integer()],
          %{non_neg_integer() => non_neg_integer()},
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            optional(any()) => any()
          }
        ) ::
          {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()],
           non_neg_integer()}
  defp recover_rollup_blocks_and_transactions_from_rpc(
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
    |> Enum.reduce({%{}, [], 0}, fn chunk, {blocks_map, transactions_list, chunks_counter} ->
      Logging.log_details_chunk_handling(
        "Collecting rollup data",
        {"block", "blocks"},
        chunk,
        chunks_counter,
        missed_blocks_length
      )

      requests =
        chunk
        |> Enum.reduce([], fn block_number, requests_list ->
          [
            BlockByNumber.request(
              %{
                id: blocks_to_batches[block_number],
                number: block_number
              },
              false
            )
            | requests_list
          ]
        end)

      {blocks_map_updated, transactions_list_updated} =
        requests
        |> Rpc.make_chunked_request_keep_id(rollup_json_rpc_named_arguments, "eth_getBlockByNumber")
        |> prepare_rollup_block_map_and_transactions_list(blocks_map, transactions_list)

      {blocks_map_updated, transactions_list_updated, chunks_counter + length(chunk)}
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
  # - `rollup_transactions`: The initial list of rollup transactions.
  #
  # ## Returns
  # - A tuple containing:
  #   - An updated map of rollup blocks associated with their batch numbers, ready
  #     for database import.
  #   - An updated list of transactions, each associated with its respective rollup
  #     block and batch number, ready for database import.
  @spec prepare_rollup_block_map_and_transactions_list(
          [%{id: non_neg_integer(), result: %{String.t() => any()}}],
          %{non_neg_integer() => Arbitrum.BatchBlock.to_import()},
          [Arbitrum.BatchTransaction.to_import()]
        ) :: {%{non_neg_integer() => Arbitrum.BatchBlock.to_import()}, [Arbitrum.BatchTransaction.to_import()]}
  defp prepare_rollup_block_map_and_transactions_list(json_responses, rollup_blocks, rollup_transactions) do
    json_responses
    |> Enum.reduce({rollup_blocks, rollup_transactions}, fn resp, {blocks_map, transactions_list} ->
      batch_num = resp.id
      blk_num = quantity_to_integer(resp.result["number"])

      updated_blocks_map =
        Map.put(
          blocks_map,
          blk_num,
          %{block_number: blk_num, batch_number: batch_num, confirmation_id: nil}
        )

      updated_transactions_list =
        case resp.result["transactions"] do
          nil ->
            transactions_list

          new_transactions ->
            Enum.reduce(new_transactions, transactions_list, fn l2_transaction_hash, transactions_list ->
              [%{transaction_hash: l2_transaction_hash, batch_number: batch_num} | transactions_list]
            end)
        end

      {updated_blocks_map, updated_transactions_list}
    end)
  end

  # Retrieves the unique identifier of an L1 transaction by its hash from the given
  # map. `nil` if there is no such transaction in the map.
  defp get_l1_transaction_id_by_hash(l1_transactions, hash) do
    l1_transactions
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
  end

  # Aggregates rollup transactions by batch number, counting the number of transactions in each batch.
  defp batches_to_rollup_transactions_amounts(rollup_transactions) do
    rollup_transactions
    |> Enum.reduce(%{}, fn transaction, acc ->
      Map.put(acc, transaction.batch_number, Map.get(acc, transaction.batch_number, 0) + 1)
    end)
  end

  # Retrieves initiated L2-to-L1 messages up to specified block number and marks them as 'sent'.
  @spec get_committed_l2_to_l1_messages(non_neg_integer()) :: [Arbitrum.Message.to_import()]
  defp get_committed_l2_to_l1_messages(block_number) do
    block_number
    |> DbMessages.initiated_l2_to_l1_messages()
    |> Enum.map(fn transaction ->
      Map.put(transaction, :status, :sent)
    end)
  end

  # Extends the provided list of batches with their corresponding commitment transactions.
  @spec extend_batches_with_commitment_transactions(
          [%{:commitment_id => non_neg_integer(), optional(any()) => any()}],
          [%{:id => non_neg_integer(), optional(any()) => any()}]
        ) :: [
          %{
            :commitment_id => non_neg_integer(),
            :commitment_transaction => %{:id => non_neg_integer(), optional(any()) => any()},
            optional(any()) => any()
          }
        ]
  defp extend_batches_with_commitment_transactions(batches, lifecycle_transactions) do
    Enum.map(batches, fn batch ->
      lifecycle_transaction =
        Enum.find(lifecycle_transactions, fn transaction -> transaction.id == batch.commitment_id end)

      Map.put(batch, :commitment_transaction, lifecycle_transaction)
    end)
  end
end
