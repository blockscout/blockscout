defmodule Indexer.Fetcher.Arbitrum.Workers.Batches.Discovery do
  @moduledoc """
  Implements core batch discovery functionality for the Arbitrum rollup indexer.

  The module's primary responsibilities include:
    * Processing `SequencerBatchDelivered` event logs to extract batch information
    * Building comprehensive data structures for batches and associated entities
    * Handling Data Availability information for AnyTrust and Celestia solutions
    * Managing L2-to-L1 message status updates for committed messages
    * Importing discovered data into the database
    * Broadcasting new batch notifications for websocket clients
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum
  alias Explorer.Chain.Events.Publisher

  alias Indexer.Fetcher.Arbitrum.DA.Common, as: DataAvailabilityInfo
  alias Indexer.Fetcher.Arbitrum.DA.{Anytrust, Celestia}
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Db.ParentChainTransactions, as: DbParentChainTransactions
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Fetcher.Arbitrum.Workers.Batches.DiscoveryUtils
  alias Indexer.Fetcher.Arbitrum.Workers.Batches.Events, as: EventsUtils
  alias Indexer.Fetcher.Arbitrum.Workers.Batches.RollupEntities, as: RollupEntities
  alias Indexer.Prometheus.Instrumenter

  require Logger

  @doc """
    Performs discovery of new or historical batches within a specified block range.

    Retrieves SequencerBatchDelivered event logs from the specified block range and
    processes these logs to identify new batches and their details. Constructs
    comprehensive data structures for batches, lifecycle transactions, rollup blocks,
    rollup transactions, and Data Availability records. Identifies L2-to-L1 messages
    committed within these batches and updates their status. All discovered data is
    imported into the database. New batches are announced for websocket broadcast.

    ## Parameters
    - `sequencer_inbox_address`: The SequencerInbox contract address for filtering logs
    - `start_block`: Starting block number for discovery range
    - `end_block`: Ending block number for discovery range
    - `new_batches_limit`: Maximum number of new batches to process per iteration
    - `messages_to_blocks_shift`: Value to align message counts with rollup block numbers
    - `l1_rpc_config`: RPC configuration parameters for L1
    - `node_interface_address`: NodeInterface contract address on the rollup
    - `rollup_rpc_config`: RPC configuration parameters for rollup data

    ## Returns
    - N/A
  """
  @spec perform(
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
  def perform(
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
      EventsUtils.get_logs_for_batches(
        min(start_block, end_block),
        max(start_block, end_block),
        sequencer_inbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    new_batches_discovery? = end_block >= start_block

    logs =
      if new_batches_discovery? do
        # called by `Indexer.Fetcher.Arbitrum.Workers.Batches.Tasks.discover_new`
        raw_logs
      else
        # called by `Indexer.Fetcher.Arbitrum.Workers.Batches.Tasks.discover_historical`
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
        extended_batches = extend_batches_with_commitment_transactions(batches, lifecycle_transactions)

        last_batch =
          extended_batches
          |> Enum.max_by(& &1.number, fn -> nil end)

        # credo:disable-for-next-line
        if last_batch do
          Instrumenter.set_latest_batch(last_batch.number, last_batch.commitment_transaction.timestamp)
        end

        Publisher.broadcast(
          [{:new_arbitrum_batches, extended_batches}],
          :realtime
        )
      end
    end)
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
      RollupEntities.associate_rollup_blocks_and_transactions(batches_to_import, rollup_rpc_config)

    lifecycle_transactions =
      lifecycle_transactions_wo_indices
      |> DbParentChainTransactions.get_indices_for_l1_transactions()

    transaction_counts_per_batch = RollupEntities.batches_to_rollup_transactions_amounts(rollup_transactions_to_import)

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
          DiscoveryUtils.determine_batch_block_range(
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

  # Retrieves the unique identifier of an L1 transaction by its hash from the given
  # map. `nil` if there is no such transaction in the map.
  @spec get_l1_transaction_id_by_hash(%{binary() => Arbitrum.LifecycleTransaction.to_import()}, binary()) ::
          non_neg_integer() | nil
  defp get_l1_transaction_id_by_hash(l1_transactions, hash) do
    l1_transactions
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
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
