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

  @type new_batches_data_map :: %{
          :start_block => non_neg_integer()
        }

  @type historical_batches_data_map :: %{
          :end_block => non_neg_integer(),
          optional(:lowest_l1_block_for_commitments) => non_neg_integer()
        }

  @type missing_batches_data_map :: %{
          :end_batch => non_neg_integer()
        }

  @typep batches_related_state :: %{
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
             :rollup_first_block => non_neg_integer(),
             :rollup_rpc => %{
               :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
               :chunk_size => non_neg_integer(),
               optional(any()) => any()
             },
             :node_interface_address => binary(),
             optional(any()) => any()
           },
           :task_data => %{
             :new_batches => new_batches_data_map(),
             :historical_batches => historical_batches_data_map(),
             :missing_batches => missing_batches_data_map(),
             optional(any()) => any()
           },
           optional(any()) => any()
         }

  @doc """
    Determines whether missing batches discovery should be run based on configuration.

    ## Parameters
    - A map containing configuration with lowest batch information.

    ## Returns
    - `true` if lowest batch is not nil in the configuration
    - `false` otherwise
  """
  @spec run_missing_batches_discovery?(batches_related_state()) :: boolean()
  def run_missing_batches_discovery?(%{config: %{lowest_batch: lowest_batch}}) do
    not is_nil(lowest_batch)
  end

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
    - `state`: A map containing:
      - `config`: Configuration map containing RPC settings, contract addresses,
        batch limits and other parameters
      - `task_data`: Task-related data including:
        - `new_batches`: Contains the `start_block` number for new batch discovery
        - `historical_batches`: Contains data about historical batches processing

    ## Returns
    - `{:ok, updated_state}`: Where `updated_state` includes an updated `start_block` value
      for the next iteration. If blocks were processed successfully, `start_block` is set to
      one after the last processed block. If no new blocks were found on L1, the state
      remains unchanged.
  """
  @spec check_new(batches_related_state()) :: {:ok, batches_related_state()}
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
          task_data: %{
            new_batches: %{
              start_block: start_block
            },
            historical_batches: %{
              end_block: historical_batches_end_block
            }
          }
        } = state
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

      # The next iteration will consider the block range which starts from the block
      # after the last processed block
      {:ok, ArbitrumHelper.update_fetcher_task_data(state, :new_batches, %{start_block: end_block + 1})}
    else
      # No new blocks on L1 produced from the last iteration of the new batches discovery
      {:ok, state}
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
    - `state`: A map containing:
      - `config`: Configuration map containing RPC settings, contract addresses,
        batch limits and other parameters
      - `task_data`: Task-related data including:
        - `historical_batches`: Contains the `end_block` number for historical
          batch discovery in the current iteration

    ## Returns
    - `{:ok, updated_state}`: Where `updated_state` includes an updated `end_block` value
      for the next iteration. If the current range of blocks was processed successfully,
      `end_block` is set to one before the starting block of the current range. If the
      process has reached the lowest L1 block that needs to be checked, `end_block` is
      set to one before that lowest block.
  """
  @spec check_historical(batches_related_state()) :: {:ok, batches_related_state()}
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
          task_data: %{historical_batches: %{end_block: end_block}}
        } = state
      ) do
    {lowest_l1_block, new_state} = get_lowest_l1_block_for_commitments(state)

    data_for_next_iteration =
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

        # The next iteration will consider the block range which ends by the block
        # before the last processed block
        %{end_block: start_block - 1}
      else
        # The historical discovery process has reached the lowest L1 block that
        # needs to be checked for batches
        %{end_block: lowest_l1_block - 1}
      end

    {:ok, ArbitrumHelper.update_fetcher_task_data(new_state, :historical_batches, data_for_next_iteration)}
  end

  @doc """
    Determines whether the historical batches discovery process has completed.

    This function checks if the end block for historical batches discovery is lower than
    the lowest L1 block containing batch commitments. When this condition is met, it means
    all historical batches up to the rollup initialization block have been discovered.

    ## Parameters
    - A map containing:
      - `task_data`: Contains the end block for historical batches discovery

    ## Returns
    - `true` if historical batches discovery has completed (end_block < lowest_l1_block)
    - `false` otherwise
  """
  @spec historical_batches_discovery_completed?(batches_related_state()) :: boolean()
  def historical_batches_discovery_completed?(
        %{
          task_data: %{historical_batches: %{end_block: end_block}}
        } = state
      ) do
    {lowest_l1_block, _} = get_lowest_l1_block_for_commitments(state)

    end_block < lowest_l1_block
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
    - `state`: A map containing:
      - `config`: Configuration map containing RPC settings, contract addresses,
        batch limits and other parameters
      - `task_data`: Task-related data including:
        - `missing_batches`: Contains the `end_batch` number for the missing batches
          inspection in the current iteration.

    ## Returns
    - `{:ok, updated_state}`: Where `updated_state` includes an updated `end_batch` value
      for the next iteration. If the current range of batches was handled successfully,
      `end_batch` is set to one before the starting batch of the current range. If the
      process has reached the lowest batch boundary, `end_batch` is set to one before
      the lowest batch.
  """
  @spec inspect_for_missing(batches_related_state()) :: {:ok, batches_related_state()}
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
          task_data: %{missing_batches: %{end_batch: end_batch}}
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

      # The next iteration will consider the batch range which ends by the batch
      # before the last processed batch
      {:ok, ArbitrumHelper.update_fetcher_task_data(new_state, :missing_batches, %{end_batch: start_batch - 1})}
    else
      # The missing batches inspection process has reached the lowest batch boundary
      {:ok, ArbitrumHelper.update_fetcher_task_data(state, :missing_batches, %{end_batch: lowest_batch - 1})}
    end
  end

  @doc """
    Determines whether the missing batches inspection process has completed.

    This function checks if the inspection process has reached or gone below the
    lowest batch that needs to be inspected. The process is considered complete
    when the lowest boundary of the range being inspected in the most recent
    inspection iteration is less than or equal to the number of the lowest batch
    known at the time of the batch fetcher start.

    ## Parameters
    - A map containing:
      - `config`: Configuration with the lowest batch number to inspect
      - `task_data`: Contains the current end batch being processed

    ## Returns
    - `true` if end_batch <= lowest_batch and both values are not nil
    - `false` if either value is nil or end_batch > lowest_batch
  """
  @spec missing_batches_inspection_completed?(batches_related_state()) :: boolean()
  def missing_batches_inspection_completed?(%{
        config: %{
          lowest_batch: lowest_batch
        },
        task_data: %{missing_batches: %{end_batch: end_batch}}
      })
      when not is_nil(lowest_batch) and not is_nil(end_batch) do
    end_batch <= lowest_batch
  end

  def missing_batches_inspection_completed?(_), do: false

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
  @spec get_lowest_l1_block_for_commitments(batches_related_state()) :: {non_neg_integer(), batches_related_state()}
  defp get_lowest_l1_block_for_commitments(
         %{
           config: %{
             l1_rollup_init_block: l1_rollup_init_block,
             rollup_first_block: rollup_first_block
           },
           task_data: %{
             historical_batches: historical_batches_data
           }
         } = state
       ) do
    case Map.get(historical_batches_data, :lowest_l1_block_for_commitments) do
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
             ArbitrumHelper.update_fetcher_task_data(state, :historical_batches, %{
               lowest_l1_block_for_commitments: block_number
             })}
        end

      cached_block ->
        {cached_block, state}
    end
  end
end
