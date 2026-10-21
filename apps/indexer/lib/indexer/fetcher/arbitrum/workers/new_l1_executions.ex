# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Indexer.Fetcher.Arbitrum.Workers.NewL1Executions do
  @moduledoc """
    Coordinates the discovery and processing of new and historical L2-to-L1 message executions for an Arbitrum rollup.

    This module is responsible for identifying and importing executions of messages
    that were initiated from Arbitrum's Layer 2 (L2) and are to be relayed to
    Layer 1 (L1). It handles both new executions that are currently occurring on L1
    and historical executions that occurred in the past but have not yet been
    processed.

    Discovery of these message executions involves parsing logs for
    `OutBoxTransactionExecuted` events emitted by the Arbitrum outbox contract. As
    the logs do not provide comprehensive data for constructing the related
    lifecycle transactions, the module executes batched RPC calls to
    `eth_getBlockByNumber`, using the responses to obtain transaction timestamps,
    thereby enriching the lifecycle transaction data.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_debug: 1]

  alias EthereumJSONRPC.Block.ByNumber, as: BlockByNumber

  import Explorer.Helper, only: [decode_data: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Db.ParentChainTransactions, as: DbParentChainTransactions
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Settlement, as: DbSettlement
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum

  require Logger

  @type new_executions_data_map :: %{
          :start_block => non_neg_integer()
        }

  @type historical_executions_data_map :: %{
          :end_block => non_neg_integer() | nil,
          optional(:lowest_l1_block) => non_neg_integer()
        }

  @typep executions_related_state :: %{
           :config => %{
             :l1_outbox_address => binary(),
             :l1_rollup_init_block => non_neg_integer(),
             :l1_start_block => non_neg_integer(),
             :l1_rpc => %{
               :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
               :logs_block_range => non_neg_integer(),
               optional(any()) => any()
             },
             :rollup_first_block => non_neg_integer(),
             optional(any()) => any()
           },
           :task_data => %{
             :new_executions => new_executions_data_map(),
             :historical_executions => historical_executions_data_map(),
             optional(any()) => any()
           },
           optional(any()) => any()
         }

  @typep discovered_executions :: %{
           :lifecycle_transactions => [Arbitrum.LifecycleTransaction.to_import()],
           :executions => [Arbitrum.L1Execution.to_import()]
         }

  @doc """
    Discovers and processes new executions of L2-to-L1 messages within the current L1 block range.

    This function fetches logs for `OutBoxTransactionExecuted` events within the
    specified L1 block range to identify new execution transactions for L2-to-L1
    messages, updating their status and linking them with corresponding lifecycle
    transactions in the database. Additionally, the function checks unexecuted
    L2-to-L1 messages to match them with any newly recorded executions and updates
    their status to `:relayed`.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including the Arbitrum outbox contract
                  address, JSON RPC arguments, and the block range for fetching
                  logs.
      - `data`: Contains the starting block number for new execution discovery.

    ## Returns
    - `{:ok, state}`: On successful discovery and processing, where `state` includes
      an updated `start_block` for the next iteration if new blocks were processed,
      or remains unchanged if no new blocks were found on L1.
  """
  @spec discover_new_l1_messages_executions(executions_related_state()) :: {:ok, executions_related_state()}
  def discover_new_l1_messages_executions(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address
          },
          task_data: %{new_executions: %{start_block: start_block}}
        } = state
      ) do
    # Requesting the "latest" block instead of "safe" allows to catch executions
    # without latency.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        l1_rpc_config.json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + l1_rpc_config.logs_block_range - 1, latest_block)

    if start_block <= end_block do
      log_info("Block range for new l2-to-l1 messages executions discovery: #{start_block}..#{end_block}")

      discovered = discover(outbox_address, start_block, end_block, l1_rpc_config)

      if discovered.executions != [] do
        log_import_of_executions(discovered)

        {:ok, _} =
          Chain.import(%{
            arbitrum_lifecycle_transactions: %{params: discovered.lifecycle_transactions},
            arbitrum_l1_executions: %{params: discovered.executions},
            timeout: :infinity
          })
      end

      import_relayed_messages()

      # The next iteration will start from the next block after the last processed block
      {:ok, ArbitrumHelper.update_fetcher_task_data(state, :new_executions, %{start_block: end_block + 1})}
    else
      # No new blocks on L1 produced from the last iteration of the new executions discovery
      {:ok, state}
    end
  end

  @doc """
    Discovers and processes historical executions of L2-to-L1 messages within a calculated L1 block range.

    This function fetches logs for `OutBoxTransactionExecuted` events within the
    calculated L1 block range. It then processes these logs to identify execution
    transactions for L2-to-L1 messages, updating their status and linking them with
    corresponding lifecycle transactions in the database. Additionally, the
    function goes through unexecuted L2-to-L1 messages, matches them with the
    executions recorded in the database up to this moment, and updates the messages'
    status to `:relayed`.

    The discovery moves down the parent chain, one window in each run. Its lower
    bound is the lowest parent chain block that can hold an execution of a
    message from an indexed rollup block. An execution comes after the
    confirmation of the rollup block of the message, and a confirmation comes
    after the commitment of the batch that holds the rollup block. Thus the bound
    is the parent chain block of the commitment of the batch that holds the first
    indexed rollup block, and not below `l1_rollup_init_block`. While this batch
    is not in the database, the bound is `l1_rollup_init_block`. When the batches
    discovery finds the batch, the bound moves up. A window below the final bound
    costs only time, so the discovery does not wait for the batch.

    The discovery keeps its cursor in the database: the first block of the last
    window. At the first run, the function reads the cursor. If no cursor exists,
    the discovery starts below the earliest execution in the database, or below
    `l1_start_block` if no execution exists. The function writes the cursor in
    one database transaction with the executions of the window, also for a
    window without executions. Thus a restart continues from the last window.

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including the Arbitrum outbox contract
        address, the initialization block for the rollup, the first indexed
        rollup block, and JSON RPC arguments.
      - `data`: Contains the ending block number for the historical execution
        discovery, which is `nil` before the first run.

    ## Returns
    - `{:ok, state}`: On successful discovery and processing, where `state` includes
      an updated `end_block` for the next iteration. If the function read a
      window, it sets `end_block` to the block before the first block of the
      window. If `end_block` is below the bound, the function reads nothing and
      keeps `end_block`.
  """
  @spec discover_historical_l1_messages_executions(executions_related_state()) :: {:ok, executions_related_state()}
  def discover_historical_l1_messages_executions(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address
          }
        } = state
      ) do
    {lowest_l1_block, state} =
      state
      |> load_end_block()
      |> lowest_l1_block_for_executions()

    end_block = state.task_data.historical_executions.end_block

    if end_block >= lowest_l1_block do
      start_block = max(lowest_l1_block, end_block - l1_rpc_config.logs_block_range + 1)

      log_info("Block range for historical l2-to-l1 messages executions discovery: #{start_block}..#{end_block}")

      discovered = discover(outbox_address, start_block, end_block, l1_rpc_config)

      if discovered.executions != [] do
        log_import_of_executions(discovered)
      end

      :ok = DbMessages.import_historical_executions(discovered, start_block)

      import_relayed_messages()

      # The next iteration will consider the block range which ends by the block
      # before the last processed block
      {:ok, ArbitrumHelper.update_fetcher_task_data(state, :historical_executions, %{end_block: start_block - 1})}
    else
      # The historical discovery process has reached the lowest L1 block that
      # needs to be checked for executions
      {:ok, state}
    end
  end

  @doc """
    Determines whether the historical executions discovery process has completed.

    The process is complete when its end block is below the lower bound of the
    discovery, see `discover_historical_l1_messages_executions/1`. Before the
    first run of the process, the end block is `nil`, and the process is not
    complete.

    ## Parameters
    - A map containing:
      - `task_data`: Contains historical executions data with an end block
      - `config`: Contains the first indexed rollup block and
        `l1_rollup_init_block`, which give the lower bound

    ## Returns
    - `true` if the end block is below the lower bound of the discovery
    - `false` otherwise
  """
  @spec historical_executions_discovery_completed?(executions_related_state()) :: boolean()
  def historical_executions_discovery_completed?(%{task_data: %{historical_executions: %{end_block: nil}}}) do
    false
  end

  def historical_executions_discovery_completed?(
        %{task_data: %{historical_executions: %{end_block: end_block}}} = state
      ) do
    {lowest_l1_block, _} = lowest_l1_block_for_executions(state)

    end_block < lowest_l1_block
  end

  # Loads the end block of the historical discovery at its first run.
  #
  # The end block comes from the cursor in the database: the block below the
  # cursor. If no cursor exists, the end block is the block below the earliest
  # execution in the database, or the block below `l1_start_block` if no
  # execution exists. This start lets a database from a release without the
  # cursor continue below the executions that it holds.
  @spec load_end_block(executions_related_state()) :: executions_related_state()
  defp load_end_block(%{task_data: %{historical_executions: %{end_block: end_block}}} = state)
       when not is_nil(end_block) do
    state
  end

  defp load_end_block(%{config: %{l1_start_block: l1_start_block}} = state) do
    end_block =
      case DbMessages.historical_executions_cursor() do
        nil -> DbMessages.l1_block_to_discover_earliest_execution(l1_start_block - 1)
        cursor -> cursor - 1
      end

    log_info("Historical l2-to-l1 messages executions discovery starts from the parent chain block #{end_block}")

    ArbitrumHelper.update_fetcher_task_data(state, :historical_executions, %{end_block: end_block})
  end

  # Determines the lowest parent chain block that can hold an execution of a message from an indexed rollup block.
  #
  # The function gives the cached bound, or computes it from the batch that holds
  # the first indexed rollup block. The bound is the parent chain block of the
  # commitment of this batch, and not below `l1_rollup_init_block`. The function
  # caches the bound only after it finds the batch. If the batch is not in the
  # database, the bound is `l1_rollup_init_block`, and the function computes the
  # bound again at the next call. Thus the bound can only move up.
  #
  # If the first indexed rollup block is 0, the bound is `l1_rollup_init_block`.
  # Block 0 is in no batch, and the rollup contract makes the confirmation of
  # block 0 in `l1_rollup_init_block`, so no execution exists below this block.
  #
  # `get_lowest_l1_block_for_commitments/1` of the batches discovery also finds
  # the batch of the first indexed rollup block, but it answers a different
  # question: the block of the commitment itself. The two rules can change for
  # different reasons, so they are not in one function.
  #
  # ## Returns
  # - A tuple with the bound and the state, with the bound cached in the task
  #   data if the batch is found
  @spec lowest_l1_block_for_executions(executions_related_state()) :: {non_neg_integer(), executions_related_state()}
  defp lowest_l1_block_for_executions(
         %{
           config: %{
             l1_rollup_init_block: l1_rollup_init_block,
             rollup_first_block: rollup_first_block
           },
           task_data: %{historical_executions: historical_executions_data}
         } = state
       ) do
    case Map.get(historical_executions_data, :lowest_l1_block) do
      nil when rollup_first_block == 0 ->
        {l1_rollup_init_block, state}

      nil ->
        case DbSettlement.get_batch_by_rollup_block_number(rollup_first_block) do
          nil ->
            {l1_rollup_init_block, state}

          batch ->
            lowest_l1_block = max(l1_rollup_init_block, batch.commitment_transaction.block_number)

            {lowest_l1_block,
             ArbitrumHelper.update_fetcher_task_data(state, :historical_executions, %{
               lowest_l1_block: lowest_l1_block
             })}
        end

      cached_block ->
        {cached_block, state}
    end
  end

  # Discovers execution transactions for L2-to-L1 messages within a specified L1 block range.
  #
  # This function fetches logs for `OutBoxTransactionExecuted` events within the
  # specified L1 block range to discover new execution transactions. It processes
  # these logs to extract execution details and associated lifecycle transactions.
  # For lifecycle timestamps not available in the logs, RPC calls to
  # `eth_getBlockByNumber` are made to fetch the necessary data. The function
  # does not write to the database. The caller imports the result: the historical
  # process together with its cursor, and the process of new executions without
  # a cursor.
  #
  # ## Parameters
  # - `outbox_address`: The address of the Arbitrum outbox contract to filter the
  #                     logs.
  # - `start_block`: The starting block number for log retrieval.
  # - `end_block`: The ending block number for log retrieval.
  # - `l1_rpc_config`: Configuration parameters including JSON RPC arguments and
  #                    settings for processing the logs.
  #
  # ## Returns
  # - A map with the lists `lifecycle_transactions` and `executions` in the
  #   import format. Both lists are empty if the range holds no event.
  @spec discover(binary(), non_neg_integer(), non_neg_integer(), %{
          :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          :chunk_size => non_neg_integer(),
          :track_finalization => boolean(),
          optional(any()) => any()
        }) :: discovered_executions()
  defp discover(outbox_address, start_block, end_block, l1_rpc_config) do
    logs =
      get_logs_for_new_executions(
        start_block,
        end_block,
        outbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    {lifecycle_transactions, executions} = get_executions_from_logs(logs, l1_rpc_config)

    %{lifecycle_transactions: lifecycle_transactions, executions: executions}
  end

  @spec log_import_of_executions(discovered_executions()) :: :ok
  defp log_import_of_executions(%{executions: executions}) do
    log_info("Executions for #{length(executions)} L2 messages will be imported")
  end

  # Inspects all unexecuted messages to potentially mark them as completed,
  # addressing the scenario where found executions may correspond to messages
  # that have not yet been indexed. This ensures that as soon as a new unexecuted
  # message is added to the database, it can be marked as relayed, considering
  # the execution transactions that have already been indexed.
  @spec import_relayed_messages() :: :ok
  defp import_relayed_messages do
    messages = get_relayed_messages()

    if messages != [] do
      log_info("Marking #{length(messages)} l2-to-l1 messages as completed")

      {:ok, _} =
        Chain.import(%{
          arbitrum_messages: %{params: messages},
          timeout: :infinity
        })
    end

    :ok
  end

  # Retrieves logs representing `OutBoxTransactionExecuted` events between the specified blocks.
  defp get_logs_for_new_executions(start_block, end_block, outbox_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        outbox_address,
        [ArbitrumEvents.outbox_transaction_executed()],
        json_rpc_named_arguments
      )

    unless Enum.empty?(logs) do
      log_debug("Found #{length(logs)} OutBoxTransactionExecuted logs")
    end

    logs
  end

  # Extracts and processes execution details from logs for L2-to-L1 message transactions.
  #
  # This function parses logs representing `OutBoxTransactionExecuted` events to
  # extract basic execution details. It then requests block timestamps and
  # associates them with the extracted executions, forming lifecycle transactions
  # enriched with timestamps and finalization statuses. Subsequently, unique
  # identifiers for the lifecycle transactions are determined, and the connection
  # between execution records and lifecycle transactions is established.
  #
  # ## Parameters
  # - `logs`: A collection of log entries to be processed.
  # - `l1_rpc_config`: Configuration parameters including JSON RPC arguments,
  #   chunk size for RPC calls, and a flag indicating whether to track the
  #   finalization of transactions.
  #
  # ## Returns
  # - A tuple containing:
  #   - A list of lifecycle transactions with updated timestamps, finalization
  #     statuses, and unique identifiers.
  #   - A list of detailed execution information for L2-to-L1 messages.
  # Both lists are prepared for database importation.
  @spec get_executions_from_logs(
          [%{String.t() => any()}],
          %{
            :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :chunk_size => non_neg_integer(),
            :track_finalization => boolean(),
            optional(any()) => any()
          }
        ) :: {[Arbitrum.LifecycleTransaction.to_import()], [Arbitrum.L1Execution.to_import()]}
  defp get_executions_from_logs(logs, l1_rpc_config)

  defp get_executions_from_logs([], _), do: {[], []}

  defp get_executions_from_logs(
         logs,
         %{
           json_rpc_named_arguments: json_rpc_named_arguments,
           chunk_size: chunk_size,
           track_finalization: track_finalization?
         } = _l1_rpc_config
       ) do
    {basics_executions, basic_lifecycle_transactions, blocks_requests} = parse_logs_for_new_executions(logs)

    blocks_to_ts = Rpc.execute_blocks_requests_and_get_ts(blocks_requests, json_rpc_named_arguments, chunk_size)

    lifecycle_transactions =
      basic_lifecycle_transactions
      |> ArbitrumHelper.extend_lifecycle_transactions_with_ts_and_status(blocks_to_ts, track_finalization?)
      |> DbParentChainTransactions.get_indices_for_l1_transactions()

    executions =
      basics_executions
      |> Enum.reduce([], fn execution, updated_executions ->
        updated =
          execution
          |> Map.put(:execution_id, lifecycle_transactions[execution.execution_transaction_hash].id)
          |> Map.drop([:execution_transaction_hash])

        [updated | updated_executions]
      end)

    {Map.values(lifecycle_transactions), executions}
  end

  # Parses logs to extract new execution transactions for L2-to-L1 messages.
  #
  # This function processes log entries to identify `OutBoxTransactionExecuted`
  # events, extracting the message ID, transaction hash, and block number for
  # each. It accumulates this data into execution details, lifecycle
  # transaction descriptions, and RPC requests for block information. These
  # are then used in  subsequent steps to finalize the execution status of the
  # messages.
  #
  # ## Parameters
  # - `logs`: A collection of log entries to be processed.
  #
  # ## Returns
  # - A tuple containing:
  #   - `executions`: A list of details for execution transactions related to
  #     L2-to-L1 messages.
  #   - `lifecycle_transactions`: A map of lifecycle transaction details, keyed by L1
  #     transaction hash.
  #   - `blocks_requests`: A list of RPC requests for fetching block data where
  #     the executions occurred.
  defp parse_logs_for_new_executions(logs) do
    {executions, lifecycle_transactions, blocks_requests} =
      logs
      |> Enum.reduce({[], %{}, %{}}, fn event, {executions, lifecycle_transactions, blocks_requests} ->
        msg_id = outbox_transaction_executed_event_parse(event)

        l1_transaction_hash_raw = event["transactionHash"]
        l1_transaction_hash = Rpc.string_hash_to_bytes_hash(l1_transaction_hash_raw)
        l1_blk_num = quantity_to_integer(event["blockNumber"])

        updated_executions = [
          %{
            message_id: msg_id,
            execution_transaction_hash: l1_transaction_hash
          }
          | executions
        ]

        updated_lifecycle_transactions =
          Map.put(
            lifecycle_transactions,
            l1_transaction_hash,
            %{hash: l1_transaction_hash, block_number: l1_blk_num}
          )

        updated_blocks_requests =
          Map.put(
            blocks_requests,
            l1_blk_num,
            BlockByNumber.request(%{id: 0, number: l1_blk_num}, false, true)
          )

        log_debug("Execution for L2 message ##{msg_id} found in #{l1_transaction_hash_raw}")

        {updated_executions, updated_lifecycle_transactions, updated_blocks_requests}
      end)

    {executions, lifecycle_transactions, Map.values(blocks_requests)}
  end

  # Parses `OutBoxTransactionExecuted` event data to extract the transaction index parameter
  defp outbox_transaction_executed_event_parse(event) do
    [transaction_index] = decode_data(event["data"], ArbitrumEvents.outbox_transaction_executed_unindexed_params())

    transaction_index
  end

  # Retrieves unexecuted messages from L2 to L1, marking them as completed if their
  # corresponding execution transactions are identified.
  #
  # This function fetches messages confirmed on L1 and matches these messages with
  # their corresponding execution transactions. For matched pairs, it updates the
  # message status to `:relayed` and links them with the execution transactions.
  #
  # ## Returns
  # - A list of messages marked as completed, ready for database import.
  @spec get_relayed_messages() :: [Arbitrum.Message.to_import()]
  defp get_relayed_messages do
    # Assuming that both catchup block fetcher and historical messages catchup fetcher
    # will check all discovered historical messages to be marked as executed it is not
    # needed to handle :initiated and :sent of historical messages here, only for
    # new messages discovered and changed their status from `:sent` to `:confirmed`
    confirmed_messages = DbMessages.confirmed_l2_to_l1_messages()

    if Enum.empty?(confirmed_messages) do
      []
    else
      log_debug("Identified #{length(confirmed_messages)} l2-to-l1 messages already confirmed but not completed")

      messages_map =
        confirmed_messages
        |> Enum.reduce(%{}, fn msg, acc ->
          Map.put(acc, msg.message_id, msg)
        end)

      messages_map
      |> Map.keys()
      |> DbMessages.l1_executions()
      |> Enum.map(fn execution ->
        messages_map
        |> Map.get(execution.message_id)
        |> Map.put(:completion_transaction_hash, execution.execution_transaction.hash.bytes)
        |> Map.put(:status, :relayed)
      end)
    end
  end
end
