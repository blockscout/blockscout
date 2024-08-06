defmodule Indexer.Fetcher.Arbitrum.Messaging do
  @moduledoc """
  Provides functionality for filtering and handling messaging between Layer 1 (L1) and Layer 2 (L2) in the Arbitrum protocol.

  This module is responsible for identifying and processing messages that are transmitted
  between L1 and L2. It includes functions to filter incoming logs and transactions to
  find those that represent messages moving between the layers, and to handle the data of
  these messages appropriately.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  import Explorer.Helper, only: [decode_data: 2]

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_debug: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Db

  require Logger

  @l2_to_l1_event_unindexed_params [
    :address,
    {:uint, 256},
    {:uint, 256},
    {:uint, 256},
    {:uint, 256},
    :bytes
  ]

  @type arbitrum_message :: %{
          direction: :to_l2 | :from_l2,
          message_id: non_neg_integer(),
          originator_address: binary(),
          originating_transaction_hash: binary(),
          origination_timestamp: DateTime.t(),
          originating_transaction_block_number: non_neg_integer(),
          completion_transaction_hash: binary(),
          status: :initiated | :sent | :confirmed | :relayed
        }

  @typep min_transaction :: %{
           :hash => binary(),
           :type => non_neg_integer(),
           optional(:request_id) => non_neg_integer(),
           optional(any()) => any()
         }

  @typep min_log :: %{
           :data => binary(),
           :index => non_neg_integer(),
           :first_topic => binary(),
           :second_topic => binary(),
           :third_topic => binary(),
           :fourth_topic => binary(),
           :address_hash => binary(),
           :transaction_hash => binary(),
           :block_hash => binary(),
           :block_number => non_neg_integer(),
           optional(any()) => any()
         }

  @doc """
    Filters a list of rollup transactions to identify L1-to-L2 messages and composes a map for each with the related message information.

    This function filters a list of rollup transactions, selecting those where
    `request_id` is not nil and is below 2^31, indicating they are L1-to-L2
    message completions. These filtered transactions are then processed to
    construct a detailed message structure for each.

    ## Parameters
    - `transactions`: A list of rollup transaction entries.
    - `report`: An optional boolean flag (default `true`) that, when `true`, logs
      the number of processed L1-to-L2 messages if any are found.

    ## Returns
    - A list of L1-to-L2 messages with detailed information and current status. Every
      map in the list compatible with the database import operation. All messages in
      this context are considered `:relayed` as they represent completed actions from
      L1 to L2.
  """
  @spec filter_l1_to_l2_messages([min_transaction()]) :: [arbitrum_message]
  @spec filter_l1_to_l2_messages([min_transaction()], boolean()) :: [arbitrum_message]
  def filter_l1_to_l2_messages(transactions, report \\ true)
      when is_list(transactions) and is_boolean(report) do
    messages =
      transactions
      |> Enum.filter(fn tx ->
        tx[:request_id] != nil and Bitwise.bsr(tx[:request_id], 31) == 0
      end)
      |> handle_filtered_l1_to_l2_messages()

    if report && not (messages == []) do
      log_info("#{length(messages)} completions of L1-to-L2 messages will be imported")
    end

    messages
  end

  @doc """
    Filters logs for L2-to-L1 messages and composes a map for each with the related message information.

    This function filters a list of logs to identify those representing L2-to-L1 messages.
    It checks each log against the ArbSys contract address and the `L2ToL1Tx` event
    signature to determine if it corresponds to an L2-to-L1 message.

    ## Parameters
    - `logs`: A list of log entries.

    ## Returns
    - A list of L2-to-L1 messages with detailed information and current status. Each map
    in the list is compatible with the database import operation.
  """
  @spec filter_l2_to_l1_messages(maybe_improper_list(min_log, [])) :: [arbitrum_message]
  def filter_l2_to_l1_messages(logs) when is_list(logs) do
    arbsys_contract = Application.get_env(:indexer, __MODULE__)[:arbsys_contract]

    filtered_logs =
      logs
      |> Enum.filter(fn event ->
        event.address_hash == arbsys_contract and event.first_topic == Db.l2_to_l1_event()
      end)

    handle_filtered_l2_to_l1_messages(filtered_logs)
  end

  @doc """
    Processes a list of filtered rollup transactions representing L1-to-L2 messages, constructing a detailed message structure for each.

    ## Parameters
    - `filtered_txs`: A list of rollup transaction entries, each representing an L1-to-L2
      message transaction.

    ## Returns
    - A list of L1-to-L2 messages with detailed information and current status. Every map
      in the list compatible with the database import operation. All messages in this context
      are considered `:relayed` as they represent completed actions from L1 to L2.
  """
  @spec handle_filtered_l1_to_l2_messages(maybe_improper_list(min_transaction, [])) :: [arbitrum_message]
  def handle_filtered_l1_to_l2_messages([]) do
    []
  end

  def handle_filtered_l1_to_l2_messages(filtered_txs) when is_list(filtered_txs) do
    filtered_txs
    |> Enum.map(fn tx ->
      log_debug("L1 to L2 message #{tx.hash} found with the type #{tx.type}")

      %{direction: :to_l2, message_id: tx.request_id, completion_transaction_hash: tx.hash, status: :relayed}
      |> complete_to_params()
    end)
  end

  @doc """
    Processes a list of filtered logs representing L2-to-L1 messages, enriching and categorizing them based on their current state and optionally updating their execution status.

    This function takes filtered log events, typically representing L2-to-L1 messages, and
    processes each to construct a comprehensive message structure. It also determines the
    status of each message by comparing its block number against the highest committed and
    confirmed block numbers. If a `caller` module is provided, it further updates the
    messages' execution status.

    ## Parameters
    - `filtered_logs`: A list of log entries, each representing an L2-to-L1 message event.
    - `caller`: An optional module that uses as a flag to determine if the discovered
      should be checked for execution.

    ## Returns
    - A list of L2-to-L1 messages with detailed information and current status, ready for
      database import.
  """
  @spec handle_filtered_l2_to_l1_messages([min_log]) :: [arbitrum_message]
  @spec handle_filtered_l2_to_l1_messages([min_log], module()) :: [arbitrum_message]
  def handle_filtered_l2_to_l1_messages(filtered_logs, caller \\ nil)

  def handle_filtered_l2_to_l1_messages([], _) do
    []
  end

  def handle_filtered_l2_to_l1_messages(filtered_logs, caller) when is_list(filtered_logs) do
    # Get values before the loop parsing the events to reduce number of DB requests
    highest_committed_block = Db.highest_committed_block(-1)
    highest_confirmed_block = Db.highest_confirmed_block(-1)

    messages_map =
      filtered_logs
      |> Enum.reduce(%{}, fn event, messages_acc ->
        log_debug("L2 to L1 message #{event.transaction_hash} found")

        {message_id, caller, blocknum, timestamp} = l2_to_l1_event_parse(event)

        message =
          %{
            direction: :from_l2,
            message_id: message_id,
            originator_address: caller,
            originating_transaction_hash: event.transaction_hash,
            origination_timestamp: timestamp,
            originating_transaction_block_number: blocknum,
            status: status_l2_to_l1_message(blocknum, highest_committed_block, highest_confirmed_block)
          }
          |> complete_to_params()

        Map.put(
          messages_acc,
          message_id,
          message
        )
      end)

    log_info("Origins of #{length(Map.values(messages_map))} L2-to-L1 messages will be imported")

    # The check if messages are executed is required only for the case when l2-to-l1
    # messages are found by block catchup fetcher
    updated_messages_map =
      case caller do
        nil ->
          messages_map

        _ ->
          messages_map
          |> find_and_update_executed_messages()
      end

    updated_messages_map
    |> Map.values()
  end

  # Converts an incomplete message structure into a complete parameters map for database updates.
  defp complete_to_params(incomplete) do
    [
      :direction,
      :message_id,
      :originator_address,
      :originating_transaction_hash,
      :origination_timestamp,
      :originating_transaction_block_number,
      :completion_transaction_hash,
      :status
    ]
    |> Enum.reduce(%{}, fn key, out ->
      Map.put(out, key, Map.get(incomplete, key))
    end)
  end

  # Parses an L2-to-L1 event, extracting relevant information from the event's data.
  defp l2_to_l1_event_parse(event) do
    [
      caller,
      arb_block_num,
      _eth_block_num,
      timestamp,
      _callvalue,
      _data
    ] = decode_data(event.data, @l2_to_l1_event_unindexed_params)

    position = quantity_to_integer(event.fourth_topic)

    {position, caller, arb_block_num, Timex.from_unix(timestamp)}
  end

  # Determines the status of an L2-to-L1 message based on its block number and the highest
  # committed and confirmed block numbers.
  defp status_l2_to_l1_message(msg_block, highest_committed_block, highest_confirmed_block) do
    cond do
      highest_confirmed_block >= msg_block -> :confirmed
      highest_committed_block >= msg_block -> :sent
      true -> :initiated
    end
  end

  # Finds and updates the status of L2-to-L1 messages that have been executed on L1.
  # This function iterates over the given messages, identifies those with corresponding L1 executions,
  # and updates their `completion_transaction_hash` and `status` accordingly.
  #
  # ## Parameters
  # - `messages`: A map where each key is a message ID, and each value is the message's details.
  #
  # ## Returns
  # - The updated map of messages with the `completion_transaction_hash` and `status` fields updated
  #   for messages that have been executed.
  defp find_and_update_executed_messages(messages) do
    messages
    |> Map.keys()
    |> Db.l1_executions()
    |> Enum.reduce(messages, fn execution, messages_acc ->
      message =
        messages_acc
        |> Map.get(execution.message_id)
        |> Map.put(:completion_transaction_hash, execution.execution_transaction.hash.bytes)
        |> Map.put(:status, :relayed)

      Map.put(messages_acc, execution.message_id, message)
    end)
  end
end
