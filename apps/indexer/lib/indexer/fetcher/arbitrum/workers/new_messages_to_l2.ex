defmodule Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2 do
  @moduledoc """
  Manages the discovery and processing of new and historical L1-to-L2 messages initiated on L1 for an Arbitrum rollup.

  This module is responsible for identifying and importing messages that are initiated
  from Layer 1 (L1) to Arbitrum's Layer 2 (L2). It handles both new messages that are
  currently being sent to L2 and historical messages that were sent in the past but
  have not yet been processed by the system.

  The initiated messages are identified by analyzing logs associated with
  `MessageDelivered` events emitted by the Arbitrum bridge contract. These logs
  contain almost all the information required to compose the messages, except for the
  originator's address, which is obtained by making an RPC call to get the transaction
  details.
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]
  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents

  import Explorer.Helper, only: [decode_data: 2]

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_info: 1, log_debug: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum
  alias Explorer.Chain.Events.Publisher

  require Logger

  @types_of_l1_messages_forwarded_to_l2 [3, 7, 9, 12]

  @doc """
  Discovers new L1-to-L2 messages initiated on L1 within a configured block range and processes them for database import.

  This function calculates the block range for discovering new messages from L1 to L2
  based on the latest block number available on the network. It then fetches logs
  related to L1-to-L2 events within this range, extracts message details from both
  the log and the corresponding L1 transaction, and imports them into the database. If
  new messages were discovered, their amount is announced to be broadcasted through
  a websocket.

  ## Parameters
  - A map containing:
    - `config`: Configuration settings including JSON RPC arguments for L1, Arbitrum
                bridge address, RPC block range, and chunk size for RPC calls.
    - `data`: Contains the starting block number for new L1-to-L2 message discovery.

  ## Returns
  - `{:ok, end_block}`: On successful discovery and processing, where `end_block`
                        indicates the necessity to consider next block range in the
                        following iteration of new message discovery.
  - `{:ok, start_block - 1}`: when no new blocks on L1 produced from the last
                              iteration of the new message discovery.
  """
  @spec discover_new_messages_to_l2(%{
          :config => %{
            :json_l1_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :l1_bridge_address => binary(),
            :l1_rpc_block_range => non_neg_integer(),
            :l1_rpc_chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          :data => %{
            :new_msg_to_l2_start_block => non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  def discover_new_messages_to_l2(
        %{
          config: %{
            json_l1_rpc_named_arguments: json_rpc_named_arguments,
            l1_rpc_chunk_size: chunk_size,
            l1_rpc_block_range: rpc_block_range,
            l1_bridge_address: bridge_address
          },
          data: %{new_msg_to_l2_start_block: start_block}
        } = _state
      ) do
    # Requesting the "latest" block instead of "safe" allows to get messages originated to L2
    # much earlier than they will be seen by the Arbitrum Sequencer.
    {:ok, latest_block} =
      IndexerHelper.get_block_number_by_tag(
        "latest",
        json_rpc_named_arguments,
        Rpc.get_resend_attempts()
      )

    end_block = min(start_block + rpc_block_range - 1, latest_block)

    if start_block <= end_block do
      log_info("Block range for discovery new messages from L1: #{start_block}..#{end_block}")

      new_messages_amount =
        discover(
          bridge_address,
          start_block,
          end_block,
          json_rpc_named_arguments,
          chunk_size
        )

      if new_messages_amount > 0 do
        Publisher.broadcast(%{new_messages_to_arbitrum_amount: new_messages_amount}, :realtime)
      end

      {:ok, end_block}
    else
      {:ok, start_block - 1}
    end
  end

  @doc """
  Discovers historical L1-to-L2 messages initiated on L1 within the configured block range and processes them for database import.

  This function calculates the block range for message discovery and targets historical
  messages from L1 to L2 by querying the specified block range on L1. The discovery is
  conducted by fetching logs related to L1-to-L2 events, extracting message details
  from both the log and the corresponding L1 transaction, and importing them into
  the database.

  ## Parameters
  - A map containing:
    - `config`: Configuration settings including JSON RPC arguments for L1, Arbitrum
                bridge address, rollup initialization block, block range, and chunk
                size for RPC calls.
    - `data`: Contains the end block for historical L1-to-L2 message discovery.

  ## Returns
  - `{:ok, start_block}`: On successful discovery and processing, where `start_block`
                          indicates the necessity to consider another block range in
                          the next iteration of message discovery.
  - `{:ok, l1_rollup_init_block}`: If the discovery process already reached rollup
                                   initialization block and no discovery action was
                                   necessary.
  """
  @spec discover_historical_messages_to_l2(%{
          :config => %{
            :json_l1_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :l1_bridge_address => binary(),
            :l1_rollup_init_block => non_neg_integer(),
            :l1_rpc_block_range => non_neg_integer(),
            :l1_rpc_chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          :data => %{
            :historical_msg_to_l2_end_block => non_neg_integer(),
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {:ok, non_neg_integer()}
  def discover_historical_messages_to_l2(
        %{
          config: %{
            json_l1_rpc_named_arguments: json_rpc_named_arguments,
            l1_rpc_chunk_size: chunk_size,
            l1_rpc_block_range: rpc_block_range,
            l1_bridge_address: bridge_address,
            l1_rollup_init_block: l1_rollup_init_block
          },
          data: %{historical_msg_to_l2_end_block: end_block}
        } = _state
      ) do
    if end_block >= l1_rollup_init_block do
      start_block = max(l1_rollup_init_block, end_block - rpc_block_range + 1)

      log_info("Block range for discovery historical messages from L1: #{start_block}..#{end_block}")

      discover(
        bridge_address,
        start_block,
        end_block,
        json_rpc_named_arguments,
        chunk_size
      )

      {:ok, start_block}
    else
      {:ok, l1_rollup_init_block}
    end
  end

  # Discovers and imports L1-to-L2 messages initiated on L1 within a specified block range.
  #
  # This function discovers messages initiated on L1 for transferring information from L1 to L2
  # by retrieving relevant logs within the specified block range on L1, focusing on
  # `MessageDelivered` events. It processes these logs to extract and construct message
  # details. For information not present in the events, RPC calls are made to fetch additional
  # transaction details. The discovered messages are then imported into the database.
  #
  # ## Parameters
  # - `bridge_address`: The address of the Arbitrum bridge contract used to filter the logs.
  # - `start_block`: The starting block number for log retrieval.
  # - `end_block`: The ending block number for log retrieval.
  # - `json_rpc_named_argument`: Configuration parameters for the JSON RPC connection.
  # - `chunk_size`: The size of chunks for processing RPC calls in batches.
  #
  # ## Returns
  # - amount of discovered messages
  defp discover(bridge_address, start_block, end_block, json_rpc_named_argument, chunk_size) do
    logs =
      get_logs_for_l1_to_l2_messages(
        start_block,
        end_block,
        bridge_address,
        json_rpc_named_argument
      )

    messages = get_messages_from_logs(logs, json_rpc_named_argument, chunk_size)

    unless messages == [] do
      log_info("Origins of #{length(messages)} L1-to-L2 messages will be imported")
    end

    {:ok, _} =
      Chain.import(%{
        arbitrum_messages: %{params: messages},
        timeout: :infinity
      })

    length(messages)
  end

  # Retrieves logs representing the `MessageDelivered` events.
  defp get_logs_for_l1_to_l2_messages(start_block, end_block, bridge_address, json_rpc_named_arguments)
       when start_block <= end_block do
    {:ok, logs} =
      IndexerHelper.get_logs(
        start_block,
        end_block,
        bridge_address,
        [ArbitrumEvents.message_delivered()],
        json_rpc_named_arguments
      )

    if length(logs) > 0 do
      log_debug("Found #{length(logs)} MessageDelivered logs")
    end

    logs
  end

  # Extracts complete message details from the provided logs and prepares them for
  # database insertion.
  #
  # This function filters and parses the logs to identify L1-to-L2 messages,
  # generating corresponding RPC requests to fetch additional transaction data.
  # It executes these RPC requests to obtain the `from` address of each transaction.
  # It then completes each message description by merging the fetched `from`
  # address and setting the status to `:initiated`, making them ready for database
  # import.
  #
  # ## Parameters
  # - `logs`: A list of log entries to be processed.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  # - `chunk_size`: The size of chunks for batch processing transactions.
  #
  # ## Returns
  # - A list of maps describing discovered messages compatible with the database
  #   import operation.
  @spec get_messages_from_logs(
          [%{String.t() => any()}],
          EthereumJSONRPC.json_rpc_named_arguments(),
          non_neg_integer()
        ) :: [Arbitrum.Message.to_import()]
  defp get_messages_from_logs(logs, json_rpc_named_arguments, chunk_size)

  defp get_messages_from_logs([], _, _), do: []

  defp get_messages_from_logs(logs, json_rpc_named_arguments, chunk_size) do
    {messages, transactions_requests} = parse_logs_for_l1_to_l2_messages(logs)

    transactions_to_from =
      Rpc.execute_transactions_requests_and_get_from(transactions_requests, json_rpc_named_arguments, chunk_size)

    Enum.map(messages, fn msg ->
      Map.merge(msg, %{
        originator_address: transactions_to_from[msg.originating_transaction_hash],
        status: :initiated
      })
    end)
  end

  # Parses logs to extract L1-to-L2 message details and prepares RPC requests for transaction data.
  #
  # This function processes log entries corresponding to `MessageDelivered` events, filtering out
  # L1-to-L2 messages identified by one of the following message types: `3`, `17`, `9`, `12`.
  # Utilizing information from both the transaction and the log, the function constructs maps
  # that partially describe each message and prepares RPC `eth_getTransactionByHash` requests to fetch
  # the remaining data needed to complete these message descriptions.
  #
  # ## Parameters
  # - `logs`: A collection of log entries to be processed.
  #
  # ## Returns
  # - A tuple comprising:
  #   - `messages`: A list of maps, each containing an incomplete representation of a message.
  #   - `transactions_requests`: A list of RPC request `eth_getTransactionByHash` structured to fetch
  #     additional data needed to finalize the message descriptions.
  defp parse_logs_for_l1_to_l2_messages(logs) do
    {messages, transactions_requests} =
      logs
      |> Enum.reduce({[], %{}}, fn event, {messages, transactions_requests} ->
        {msg_id, type, ts} = message_delivered_event_parse(event)

        if type in @types_of_l1_messages_forwarded_to_l2 do
          transaction_hash = event["transactionHash"]
          blk_num = quantity_to_integer(event["blockNumber"])

          updated_messages = [
            %{
              direction: :to_l2,
              message_id: msg_id,
              originating_transaction_hash: transaction_hash,
              origination_timestamp: ts,
              originating_transaction_block_number: blk_num
            }
            | messages
          ]

          updated_transactions_requests =
            Map.put(
              transactions_requests,
              transaction_hash,
              Rpc.transaction_by_hash_request(%{id: 0, hash: transaction_hash})
            )

          log_debug("L1 to L2 message #{transaction_hash} found with the type #{type}")

          {updated_messages, updated_transactions_requests}
        else
          {messages, transactions_requests}
        end
      end)

    {messages, Map.values(transactions_requests)}
  end

  # Parses the `MessageDelivered` event to extract relevant message details.
  defp message_delivered_event_parse(event) do
    [
      _inbox,
      kind,
      _sender,
      _message_data_hash,
      _base_fee_l1,
      timestamp
    ] = decode_data(event["data"], ArbitrumEvents.message_delivered_unindexed_params())

    message_index = quantity_to_integer(Enum.at(event["topics"], 1))

    {message_index, kind, Timex.from_unix(timestamp)}
  end
end
