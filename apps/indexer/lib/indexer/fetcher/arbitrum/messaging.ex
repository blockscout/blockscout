defmodule Indexer.Fetcher.Arbitrum.Messaging do
  @moduledoc """
  Provides functionality for filtering and handling messaging between Layer 1 (L1) and Layer 2 (L2) in the Arbitrum protocol.

  This module is responsible for identifying and processing messages that are transmitted
  between L1 and L2. It includes functions to filter incoming logs and transactions to
  find those that represent messages moving between the layers, and to handle the data of
  these messages appropriately.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  alias EthereumJSONRPC.Arbitrum, as: ArbitrumRpc
  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_debug: 1]

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum.Message
  require Logger

  @zero_hex_prefix "0x" <> String.duplicate("0", 56)

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
    Filters rollup transactions to identify L1-to-L2 messages and categorizes them.

    This function processes a list of rollup transactions, identifying those with
    non-nil `request_id` fields. It then separates these into two categories:
    messages with plain message IDs and transactions with hashed message IDs.

    ## Parameters
    - `transactions`: A list of rollup transaction entries.
    - `report`: An optional boolean flag (default `true`) that, when `true`, logs
      the number of identified L1-to-L2 messages and transactions requiring
      further processing.

    ## Returns
    A tuple containing:
    - A list of L1-to-L2 messages with detailed information, ready for database
      import. All messages in this context are considered `:relayed` as they
      represent completed actions from L1 to L2.
    - A list of transactions with hashed message IDs that require further
      processing for message ID matching.
  """
  @spec filter_l1_to_l2_messages([min_transaction()]) :: {[Message.to_import()], [min_transaction()]}
  @spec filter_l1_to_l2_messages([min_transaction()], boolean()) :: {[Message.to_import()], [min_transaction()]}
  def filter_l1_to_l2_messages(transactions, report \\ true)
      when is_list(transactions) and is_boolean(report) do
    {transactions_with_proper_message_id, transactions_with_hashed_message_id} =
      transactions
      |> Enum.filter(fn transaction ->
        transaction[:request_id] != nil
      end)
      |> Enum.split_with(fn transaction ->
        plain_message_id?(transaction[:request_id])
      end)

    # Transform transactions with the plain message ID into messages
    messages =
      transactions_with_proper_message_id
      |> handle_filtered_l1_to_l2_messages()

    if report do
      if not (messages == []) do
        log_info("#{length(messages)} completions of L1-to-L2 messages will be imported")
      end

      if not (transactions_with_hashed_message_id == []) do
        log_info(
          "#{length(transactions_with_hashed_message_id)} completions of L1-to-L2 messages require message ID matching discovery"
        )
      end
    end

    {messages, transactions_with_hashed_message_id}
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
  @spec filter_l2_to_l1_messages(maybe_improper_list(min_log, [])) :: [Message.to_import()]
  def filter_l2_to_l1_messages(logs) when is_list(logs) do
    arbsys_contract = Application.get_env(:indexer, __MODULE__)[:arbsys_contract]

    filtered_logs =
      logs
      |> Enum.filter(fn event ->
        event.address_hash == arbsys_contract and event.first_topic == ArbitrumEvents.l2_to_l1()
      end)

    handle_filtered_l2_to_l1_messages(filtered_logs)
  end

  @doc """
    Processes a list of filtered rollup transactions representing L1-to-L2 messages, constructing a detailed message structure for each.

    ## Parameters
    - `filtered_transactions`: A list of rollup transaction entries, each representing an L1-to-L2
      message transaction.

    ## Returns
    - A list of L1-to-L2 messages with detailed information and current status. Every map
      in the list compatible with the database import operation. All messages in this context
      are considered `:relayed` as they represent completed actions from L1 to L2.
  """
  @spec handle_filtered_l1_to_l2_messages(maybe_improper_list(min_transaction, [])) :: [Message.to_import()]
  def handle_filtered_l1_to_l2_messages([]) do
    []
  end

  def handle_filtered_l1_to_l2_messages(filtered_transactions) when is_list(filtered_transactions) do
    filtered_transactions
    |> Enum.map(fn transaction ->
      log_debug("L1 to L2 message #{transaction.hash} found with the type #{transaction.type}")

      %{
        direction: :to_l2,
        message_id: quantity_to_integer(transaction.request_id),
        completion_transaction_hash: transaction.hash,
        status: :relayed
      }
      |> complete_to_params()
    end)
  end

  @doc """
    Processes a list of filtered logs representing L2-to-L1 messages, enriching and categorizing them.

    This function takes filtered log events, typically representing L2-to-L1 messages, and
    processes each to construct a comprehensive message structure. All messages are set
    with the status `:initiated`.

    ## Parameters
    - `filtered_logs`: A list of log entries, each representing an L2-to-L1 message event.

    ## Returns
    - A list of L2-to-L1 messages with detailed information and `:initiated` status, ready for
      database import.
  """
  @spec handle_filtered_l2_to_l1_messages([min_log]) :: [Message.to_import()]
  def handle_filtered_l2_to_l1_messages(filtered_logs)

  def handle_filtered_l2_to_l1_messages([]), do: []

  def handle_filtered_l2_to_l1_messages(filtered_logs) when is_list(filtered_logs) do
    messages =
      filtered_logs
      |> Enum.map(fn event ->
        log_debug("L2 to L1 message #{event.transaction_hash} found")

        fields =
          event
          |> ArbitrumRpc.l2_to_l1_event_parse()

        %{
          direction: :from_l2,
          message_id: fields.message_id,
          originator_address: fields.caller,
          originating_transaction_hash: event.transaction_hash,
          origination_timestamp: Timex.from_unix(fields.timestamp),
          originating_transaction_block_number: fields.arb_block_number,
          status: :initiated
        }
        |> complete_to_params()
      end)

    log_info("Origins of #{length(messages)} L2-to-L1 messages will be imported")

    messages
  end

  @doc """
    Imports a list of messages into the database.

    ## Parameters
    - `messages`: A list of messages to import into the database.

    ## Returns
    N/A
  """
  @spec import_to_db([Message.to_import()]) :: :ok
  def import_to_db(messages) do
    {:ok, _} =
      Chain.import(%{
        arbitrum_messages: %{params: messages},
        timeout: :infinity
      })

    :ok
  end

  # Converts an incomplete message structure into a complete parameters map for database updates.
  @spec complete_to_params(map()) :: Message.to_import()
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

  # Checks if the given request ID is a plain message ID (starts with 56 zero
  # characters that correspond to 28 zero bytes).
  @spec plain_message_id?(non_neg_integer()) :: boolean()
  defp plain_message_id?(request_id) when byte_size(request_id) == 66 do
    String.starts_with?(request_id, @zero_hex_prefix)
  end

  defp plain_message_id?(_) do
    false
  end
end
