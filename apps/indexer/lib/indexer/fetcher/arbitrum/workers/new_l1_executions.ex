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
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum

  require Logger

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
    - `{:ok, end_block}`: On successful discovery and processing, where `end_block`
                          indicates the necessity to consider next block range in the
                          following iteration of new executions discovery.
    - `{:ok, start_block - 1}`: when no new blocks on L1 produced from the last
                                iteration of the new executions discovery.
  """
  @spec discover_new_l1_messages_executions(%{
          :config => %{
            :l1_outbox_address => binary(),
            :l1_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          :data => %{:new_executions_start_block => non_neg_integer(), optional(any()) => any()},
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  def discover_new_l1_messages_executions(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address
          },
          data: %{new_executions_start_block: start_block}
        } = _state
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

      discover(outbox_address, start_block, end_block, l1_rpc_config)

      {:ok, end_block}
    else
      {:ok, start_block - 1}
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

    ## Parameters
    - A map containing:
      - `config`: Configuration settings including the Arbitrum outbox contract
                  address, the initialization block for the rollup, and JSON RPC
                  arguments.
      - `data`: Contains the ending block number for the historical execution
                discovery.

    ## Returns
    - `{:ok, start_block}`: On successful discovery and processing, where
      `start_block` indicates the necessity to consider another block range in the
      next iteration of historical executions discovery.
    - `{:ok, l1_rollup_init_block}`: If the historical discovery process has reached
      the rollup initialization block, indicating that no further action is needed.
  """
  @spec discover_historical_l1_messages_executions(%{
          :config => %{
            :l1_outbox_address => binary(),
            :l1_rollup_init_block => non_neg_integer(),
            :l1_rpc => %{
              :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
              :logs_block_range => non_neg_integer(),
              optional(any()) => any()
            },
            optional(any()) => any()
          },
          :data => %{:historical_executions_end_block => non_neg_integer(), optional(any()) => any()},
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  def discover_historical_l1_messages_executions(
        %{
          config: %{
            l1_rpc: l1_rpc_config,
            l1_outbox_address: outbox_address,
            l1_rollup_init_block: l1_rollup_init_block
          },
          data: %{historical_executions_end_block: end_block}
        } = _state
      ) do
    if end_block >= l1_rollup_init_block do
      start_block = max(l1_rollup_init_block, end_block - l1_rpc_config.logs_block_range + 1)

      log_info("Block range for historical l2-to-l1 messages executions discovery: #{start_block}..#{end_block}")

      discover(outbox_address, start_block, end_block, l1_rpc_config)

      {:ok, start_block}
    else
      {:ok, l1_rollup_init_block}
    end
  end

  # Discovers and imports execution transactions for L2-to-L1 messages within a specified L1 block range.
  #
  # This function fetches logs for `OutBoxTransactionExecuted` events within the
  # specified L1 block range to discover new execution transactions. It processes
  # these logs to extract execution details and associated lifecycle transactions,
  # which are then imported into the database. For lifecycle timestamps not
  # available in the logs, RPC calls to `eth_getBlockByNumber` are made to fetch
  # the necessary data. Furthermore, the function checks unexecuted L2-to-L1
  # messages to match them with any recorded executions, updating their status to
  # `:relayed` and establishing links with the corresponding lifecycle
  # transactions. These updated messages are also imported into the database.
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
  # - N/A
  defp discover(outbox_address, start_block, end_block, l1_rpc_config) do
    logs =
      get_logs_for_new_executions(
        start_block,
        end_block,
        outbox_address,
        l1_rpc_config.json_rpc_named_arguments
      )

    {lifecycle_transactions, executions} = get_executions_from_logs(logs, l1_rpc_config)

    unless executions == [] do
      log_info("Executions for #{length(executions)} L2 messages will be imported")

      {:ok, _} =
        Chain.import(%{
          arbitrum_lifecycle_transactions: %{params: lifecycle_transactions},
          arbitrum_l1_executions: %{params: executions},
          timeout: :infinity
        })
    end

    # Inspects all unexecuted messages to potentially mark them as completed,
    # addressing the scenario where found executions may correspond to messages
    # that have not yet been indexed. This ensures that as soon as a new unexecuted
    # message is added to the database, it can be marked as relayed, considering
    # the execution transactions that have already been indexed.
    messages = get_relayed_messages()

    unless messages == [] do
      log_info("Marking #{length(messages)} l2-to-l1 messages as completed")

      {:ok, _} =
        Chain.import(%{
          arbitrum_messages: %{params: messages},
          timeout: :infinity
        })
    end
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

    if length(logs) > 0 do
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
