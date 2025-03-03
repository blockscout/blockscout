defmodule Indexer.Fetcher.Arbitrum.Workers.Batches.Tasks do
  @moduledoc """
    Manages the discovery and importation of new and historical batches of transactions for an Arbitrum rollup.

    This module orchestrates the discovery of batches of transactions processed
    through the Arbitrum Sequencer. It distinguishes between new batches currently
    being created and historical batches processed in the past but not yet imported
    into the database.

    The module processes logs from the `SequencerBatchDelivered` events emitted by
    the Arbitrum `SequencerInbox` contract to extract batch details. It maintains
    linkages between batches and their corresponding rollup blocks and transactions.
    For batches stored in Data Availability solutions like AnyTrust or Celestia,
    it retrieves DA information to locate the batch data. The module also tracks
    cross-chain messages initiated in rollup blocks associated with new batches,
    updating their status to committed (`:sent`).

    For any blocks or transactions missing in the database, data is requested in
    chunks from the rollup RPC endpoint by `eth_getBlockByNumber`. Additionally,
    to complete batch details and lifecycle transactions, RPC calls to
    `eth_getTransactionByHash` and `eth_getBlockByNumber` on L1 are made in chunks
    for the necessary information not available in the logs.
  """
  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Fetcher.Arbitrum.Workers.Batches.Discovery, as: BatchesDiscovery

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
  @spec check_new(%{
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
  def check_new(
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
          discover_new(
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
      - `config`: Configuration settings including the L1 rollup initialization
        block, RPC configurations, SequencerInbox address, a shift for the message
        to block number mapping, and a limit for new batches discovery.
      - `data`: Contains the ending block number for the historical batch discovery.

    ## Returns
    - `{:ok, start_block, new_state}`: On successful discovery and processing, where
      `start_block` is the calculated starting block for the discovery range,
      indicating the need to consider another block range in the next iteration of
      historical batch discovery, and `new_state` contains updated cache data.
    - `{:ok, l1_rollup_init_block, new_state}`: If the discovery process has reached
      the rollup initialization block, indicating that all batches up to the rollup
      origins have been discovered and no further action is needed.
  """
  @spec check_historical(%{
          :config => %{
            :l1_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            :l1_sequencer_inbox_address => binary(),
            :messages_to_blocks_shift => non_neg_integer(),
            :new_batches_limit => non_neg_integer(),
            :l1_rollup_init_block => non_neg_integer(),
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
        }) :: {:ok, non_neg_integer(), %{optional(any()) => any()}}
  def check_historical(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            rollup_rpc: rollup_rpc_config,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            new_batches_limit: new_batches_limit,
            node_interface_address: node_interface_address
          },
          data: %{historical_batches_end_block: end_block}
        } = state
      ) do
    {lowest_l1_block, new_state} = get_lowest_l1_block_for_commitments(state)

    if end_block >= lowest_l1_block do
      start_block = max(lowest_l1_block, end_block - l1_rpc_config.logs_block_range + 1)

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

      {:ok, start_block, new_state}
    else
      {:ok, lowest_l1_block, new_state}
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
      - `config`: Configuration settings including the L1 rollup initialization
        block, RPC configurations, SequencerInbox address, a shift for the message
        to block number mapping, a limit for new batches discovery, and the max
        size of the range for missing batches inspection.
      - `data`: Contains the ending batch number for the missing batches inspection.

    ## Returns
    - `{:ok, start_batch, new_state}`: On successful inspection of the given batch range, where
      `start_batch` is the calculated starting batch for the inspected range,
      indicating the need to consider another batch range in the next iteration of
      missing batch inspection, and `new_state` contains updated cache data.
    - `{:ok, lowest_batch, new_state}`: If the discovery process has been finished, indicating
      that all batches up to the rollup origins have been checked and no further
      action is needed.
  """
  @spec inspect_for_missing(%{
          :config => %{
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
            :l1_rollup_init_block => non_neg_integer(),
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
        }) :: {:ok, non_neg_integer(), %{optional(any()) => any()}}
  def inspect_for_missing(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            rollup_rpc: rollup_rpc_config,
            l1_sequencer_inbox_address: sequencer_inbox_address,
            messages_to_blocks_shift: messages_to_blocks_shift,
            new_batches_limit: new_batches_limit,
            missing_batches_range: missing_batches_range,
            lowest_batch: lowest_batch,
            node_interface_address: node_interface_address
          },
          data: %{missing_batches_end_batch: end_batch}
        } = state
      )
      when not is_nil(lowest_batch) and not is_nil(end_batch) do
    # No need to inspect for missing batches below the lowest batch
    # since it is assumed that they are picked up by historical batches
    # discovery process
    if end_batch > lowest_batch do
      start_batch = max(lowest_batch, end_batch - missing_batches_range + 1)

      log_info("Batch range for missing batches inspection: #{start_batch}..#{end_batch}")

      {lowest_l1_block, new_state} = get_lowest_l1_block_for_commitments(state)

      l1_block_ranges_for_missing_batches =
        DbSettlement.get_l1_block_ranges_for_missing_batches(start_batch, end_batch, lowest_l1_block - 1)

      unless l1_block_ranges_for_missing_batches == [] do
        discover_missing(
          sequencer_inbox_address,
          l1_block_ranges_for_missing_batches,
          new_batches_limit,
          messages_to_blocks_shift,
          l1_rpc_config,
          node_interface_address,
          rollup_rpc_config
        )
      end

      {:ok, start_batch, new_state}
    else
      {:ok, lowest_batch, state}
    end
  end

  # Initiates the discovery process for batches within a specified block range.
  #
  # Invokes the actual discovery process for new batches by calling
  # `BatchesDiscovery.perform` with the provided parameters.
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
  @spec discover_new(
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
  defp discover_new(
         sequencer_inbox_address,
         start_block,
         end_block,
         new_batches_limit,
         messages_to_blocks_shift,
         l1_rpc_config,
         node_interface_address,
         rollup_rpc_config
       ) do
    BatchesDiscovery.perform(
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
  # Calls `BatchesDiscovery.perform` with parameters reversed for start and end
  # blocks to process historical data.
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
    BatchesDiscovery.perform(
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
  @spec discover_missing(
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
  defp discover_missing(
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
          # `BatchesDiscovery.perform` is not used here to demonstrate the need to fetch batches
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

  # Determines the lowest L1 block number from which to start discovering batch commitments.
  # The function either returns a cached value or queries the database for the batch containing
  # the first rollup block. If no batch is found, it falls back to the L1 rollup initialization
  # block without caching it.
  @spec get_lowest_l1_block_for_commitments(%{
          :config => %{
            :l1_rollup_init_block => non_neg_integer(),
            :rollup_first_block => non_neg_integer(),
            optional(any()) => any()
          },
          :data => %{
            optional(:lowest_l1_block_for_commitments) => non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {non_neg_integer(), %{optional(any()) => any()}}
  defp get_lowest_l1_block_for_commitments(
         %{
           config: %{
             l1_rollup_init_block: l1_rollup_init_block,
             rollup_first_block: rollup_first_block
           },
           data: data
         } = state
       ) do
    case Map.get(data, :lowest_l1_block_for_commitments) do
      nil ->
        # If first block is 0, start from block 1 since block 0 is not included in any batch
        # and therefore has no commitment. Otherwise use the first block value
        lowest_rollup_block = if rollup_first_block == 0, do: 1, else: rollup_first_block

        case DbSettlement.get_batch_by_rollup_block_number(lowest_rollup_block) do
          nil ->
            {l1_rollup_init_block, state}

          batch ->
            block_number = batch.commitment_transaction.block_number

            {block_number,
             %{
               state
               | data: Map.put(data, :lowest_l1_block_for_commitments, block_number)
             }}
        end

      cached_block ->
        {cached_block, state}
    end
  end
end
