defmodule Indexer.Fetcher.Arbitrum.Workers.NewMessagesToL2 do
  @moduledoc """
  Manages the discovery and processing of new and historical L1-to-L2 messages initiated on L1 for an Arbitrum rollup.

  This module is responsible for identifying and importing messages that are initiated
  from Layer 1 (L1) to Arbitrum's Layer 2 (L2). It handles three discovery scenarios:

    1. **New messages**: Currently being sent to L2 as the chain progresses forward
    2. **Historical messages**: Sent in the past before indexing started, discovered
       by working backward from the earliest known message
    3. **Missing origination**: Messages that have completion information on L2 but
       lack origination transaction details from L1, typically occurring when L2
       indexing runs ahead of L1 event discovery

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

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Messages, as: DbMessages
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper
  alias Indexer.Fetcher.Arbitrum.Utils.Rpc
  alias Indexer.Helper, as: IndexerHelper

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum
  alias Explorer.Chain.Arbitrum.Message, as: ArbitrumMessage
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
    - `data`: Contains the starting block number for new L1-to-L2 message discovery
      and the end block number for historical messages discovery.

  ## Returns
  - `{:ok, updated_state}` with `task_data.check_new.start_block` moved forward
    when work was done, or left unchanged when no new blocks were present.
  """
  @spec check_new(%{
          :config => %{
            :json_l1_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :l1_bridge_address => binary(),
            :l1_rpc_block_range => non_neg_integer(),
            :l1_rpc_chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          :task_data => %{
            :check_new => %{start_block: non_neg_integer()},
            :check_historical => %{end_block: non_neg_integer()},
            optional(any()) => any()
          },
          optional(any()) => any()
        }) :: {:ok, map()}
  def check_new(
        %{
          config: %{
            json_l1_rpc_named_arguments: json_rpc_named_arguments,
            l1_rpc_chunk_size: chunk_size,
            l1_rpc_block_range: rpc_block_range,
            l1_bridge_address: bridge_address
          },
          task_data: %{
            check_new: %{start_block: start_block},
            check_historical: %{end_block: historical_msg_to_l2_end_block}
          }
        } = state
      ) do
    # It is necessary to revisit some of the previous blocks to ensure that
    # no information is missed due to reorgs or RPC node inconsistency behind
    # a load balancer.
    {safe_start_block, end_block} =
      Rpc.safe_start_and_end_blocks(
        start_block,
        historical_msg_to_l2_end_block,
        json_rpc_named_arguments,
        rpc_block_range
      )

    if safe_start_block <= end_block do
      log_info("Block range for discovery new messages from L1: #{safe_start_block}..#{end_block}")

      # Since the block range to discover messages could be wider than `rpc_block_range`
      # it is required to divide it in smaller chunks.
      # credo:disable-for-lines:16 Credo.Check.Refactor.PipeChainStart
      new_messages_amount =
        ArbitrumHelper.execute_for_block_range_in_chunks(
          safe_start_block,
          end_block,
          rpc_block_range,
          fn chunk_start, chunk_end ->
            discover(
              bridge_address,
              chunk_start,
              chunk_end,
              json_rpc_named_arguments,
              chunk_size
            )
          end
        )
        |> Enum.reduce(0, fn {_range, amount}, acc -> acc + amount end)

      if new_messages_amount > 0 do
        Publisher.broadcast(%{new_messages_to_arbitrum_amount: new_messages_amount}, :realtime)
      end

      # Cursor is moved forward for the next iteration of the new messages discovery
      updated_state =
        state
        |> ArbitrumHelper.update_fetcher_task_data(:check_new, %{
          start_block: end_block + 1
        })

      # Advance the new-message cursor for the next live run.
      {:ok, updated_state}
    else
      {:ok, state}
    end
  end

  @doc """
  Discovers historical L1-to-L2 messages initiated on L1 within the configured block range and processes them for database import.

  This function calculates the block range for message discovery and targets historical
  messages from L1 to L2 by querying the specified block range on L1. The discovery is
  conducted by fetching logs related to L1-to-L2 events, extracting message details
  from both the log and the corresponding L1 transaction, and importing them into
  the database.

  It updates the end-block cursor and marks historical work complete when the init
  block is reached.

  ## Parameters
  - A map containing:
    - `config`: Configuration settings including JSON RPC arguments for L1, Arbitrum
      bridge address, rollup initialization block, block range, and chunk size for
      RPC calls.
    - `task_data`: where `check_historical` contains the end block for historical
       L1-to-L2 message discovery.

  ## Returns
  - `{:ok, updated_state}` with the historical cursor moved backward and
    `completed_tasks.check_historical` set when the init block boundary is
    reached.
  """
  @spec check_historical(%{
          :config => %{
            :json_l1_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :l1_bridge_address => binary(),
            :l1_rollup_init_block => non_neg_integer(),
            :l1_rpc_block_range => non_neg_integer(),
            :l1_rpc_chunk_size => non_neg_integer(),
            optional(any()) => any()
          },
          :task_data => %{:check_historical => %{end_block: non_neg_integer()}, optional(any()) => any()},
          :completed_tasks => %{:check_historical => boolean(), optional(any()) => any()},
          optional(any()) => any()
        }) :: {:ok, map()}
  def check_historical(
        %{
          config: %{
            json_l1_rpc_named_arguments: json_rpc_named_arguments,
            l1_rpc_chunk_size: chunk_size,
            l1_rpc_block_range: rpc_block_range,
            l1_bridge_address: bridge_address,
            l1_rollup_init_block: l1_rollup_init_block
          },
          task_data: %{check_historical: %{end_block: end_block}}
        } = state
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

      updated_state =
        state
        |> ArbitrumHelper.update_fetcher_task_data(:check_historical, %{
          end_block: start_block - 1
        })
        |> set_historical_completion(false)

      # Move the historical cursor backward for the next catchup run.
      {:ok, updated_state}
    else
      # The rollup init block is reached, flag that next iteration of
      # historical messages discovery is not needed.
      updated_state =
        state
        |> ArbitrumHelper.update_fetcher_task_data(:check_historical, %{
          end_block: l1_rollup_init_block - 1
        })
        |> set_historical_completion(true)

      # Stop scheduling historical checks because the rollup init block was reached.
      {:ok, updated_state}
    end
  end

  @doc """
  Discovers L1-to-L2 messages that have completion transactions on L2 but are missing origination transaction information from L1.

  This function works backward from the most recent fully indexed message,
  checking ranges of message IDs for those marked as `:relayed` but lacking
  L1 origination data. For each missing message found, it determines the
  appropriate L1 block range to search, discovers the originating transaction,
  and imports it.

  The function processes messages in order from highest to lowest ID within
  each range. When multiple missing messages are found, each is processed
  sequentially, with L1 block bounds recalculated after each import to use
  newly discovered messages as range delimiters.

  The cursor advances by the configured range size with each iteration. The
  task completes and stops when the next iteration's range would extend below
  the earliest discovered message ID captured during initialization.

  **Precondition:** This function assumes it is only called when there are
  fully indexed messages to work from (i.e., `end_message_id` is not nil).
  The task initialization logic ensures this function is never called when
  there's no work to do.

  ## Parameters
  - A map containing:
    - `config`: Configuration settings including:
      - JSON RPC arguments for L1
      - L1 bridge address
      - L1 rollup initialization block
      - L1 RPC chunk size for batch requests
      - Message ID range window size
    - `task_data`: Contains:
      - `check_missing_origination.end_message_id`: Upper bound for the next
        message ID range to check (always a valid non-negative integer when this
        function is called; task is disabled at init if no fully indexed messages exist)
      - `check_missing_origination.earliest_discovered_message_id`: Lower bound
        where discovery should stop (defaults to 0 if no historical messages discovered yet)
      - `check_missing_origination.safe_l1_block`: Safe L1 block number used
        as fallback upper bound when determining L1 block ranges
    - `completed_tasks`: Tracking map for task completion status

  ## Returns
  - `{:ok, updated_state}` where:
    - `task_data.check_missing_origination.end_message_id` is moved backward
      by the range size
    - `completed_tasks.check_missing_origination` is set to `true` when the
      next iteration would go below the earliest discovered message boundary
  """
  @spec check_missing_origination(%{
          :config => %{
            :json_l1_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
            :l1_bridge_address => binary(),
            :l1_rollup_init_block => non_neg_integer(),
            :l1_rpc_chunk_size => non_neg_integer(),
            :missed_message_ids_range => non_neg_integer(),
            optional(any()) => any()
          },
          :task_data => %{
            :check_missing_origination => %{
              end_message_id: non_neg_integer(),
              earliest_discovered_message_id: non_neg_integer(),
              safe_l1_block: non_neg_integer()
            },
            optional(any()) => any()
          },
          :completed_tasks => %{:check_missing_origination => boolean(), optional(any()) => any()},
          optional(any()) => any()
        }) :: {:ok, map()}
  def check_missing_origination(
        %{
          config: %{
            json_l1_rpc_named_arguments: json_rpc_named_arguments,
            l1_rpc_chunk_size: chunk_size,
            l1_bridge_address: bridge_address,
            l1_rollup_init_block: l1_rollup_init_block,
            missed_message_ids_range: missed_message_ids_range
          },
          task_data: %{
            check_missing_origination: %{
              end_message_id: end_message_id,
              earliest_discovered_message_id: earliest_discovered_message_id,
              safe_l1_block: safe_l1_block
            }
          }
        } = state
      ) do
    # Calculate the message ID range to check: [start_message_id, end_message_id]
    start_message_id = max(0, end_message_id - missed_message_ids_range + 1)

    log_info("Checking message ID range #{start_message_id}..#{end_message_id} for missing origination information")

    # Query for messages in range that have completion but missing origination
    missing_origination_message_ids =
      DbMessages.messages_to_l2_completed_but_originating_info_missed(start_message_id, end_message_id)

    unless Enum.empty?(missing_origination_message_ids) do
      log_info(
        "Found #{length(missing_origination_message_ids)} messages with missing origination in range #{start_message_id}..#{end_message_id}"
      )

      # Process each missing message (already in descending order from highest to lowest ID)
      missing_origination_message_ids
      |> Enum.each(fn message_id ->
        discover_and_import_single_missing_message(
          message_id,
          start_message_id,
          end_message_id,
          l1_rollup_init_block,
          safe_l1_block,
          bridge_address,
          json_rpc_named_arguments,
          chunk_size
        )
      end)
    end

    # Move cursor backward for next iteration
    next_end_message_id = start_message_id - 1

    # Check if next iteration would go below the earliest discovered message
    should_complete = next_end_message_id < earliest_discovered_message_id

    if should_complete do
      log_info(
        "Missing origination discovery complete: next range would extend below earliest discovered message ID #{earliest_discovered_message_id}"
      )
    end

    updated_state =
      state
      |> ArbitrumHelper.update_fetcher_task_data(:check_missing_origination, %{
        end_message_id: next_end_message_id
      })
      |> set_missing_origination_completion(should_complete)

    {:ok, updated_state}
  end

  # Discovers and imports origination information for a single L1-to-L2 message
  # that is missing such information.
  #
  # This function determines the appropriate L1 block range to search by finding
  # the closest preceding and following messages with known origination blocks.
  # It then fetches L1 logs within that range and filters to find only the
  # target message, excluding any already-indexed messages.
  #
  # ## Parameters
  # - `message_id`: The ID of the message to discover origination for
  # - `lower_bound_msg_id`: Lower message ID bound for filtering (exclusive)
  # - `upper_bound_msg_id`: Upper message ID bound for filtering (exclusive)
  # - `l1_rollup_init_block`: Fallback minimum L1 block if no preceding message
  # - `safe_l1_block`: Fallback maximum L1 block if no following message
  # - `bridge_address`: L1 bridge contract address for log filtering
  # - `json_rpc_named_arguments`: RPC configuration
  # - `chunk_size`: Batch size for RPC requests
  #
  # ## Returns
  # - `:ok` after attempting to discover and import the message
  defp discover_and_import_single_missing_message(
         message_id,
         lower_bound_msg_id,
         upper_bound_msg_id,
         l1_rollup_init_block,
         safe_l1_block,
         bridge_address,
         json_rpc_named_arguments,
         chunk_size
       ) do
    log_debug("Discovering origination for message ID #{message_id}")

    # Determine L1 block range for this message using database helper
    %{lower: lower_bound, higher: higher_bound} =
      DbMessages.l1_block_range_for_message_to_l2(message_id, l1_rollup_init_block, safe_l1_block)

    l1_start_block = lower_bound.block_number
    l1_end_block = higher_bound.block_number

    log_debug(
      "Searching L1 blocks #{l1_start_block}..#{l1_end_block} for message ID #{message_id} " <>
        "(bounded by message IDs #{inspect(lower_bound.message_id)}..#{inspect(higher_bound.message_id)})"
    )

    # Discover messages in the L1 block range, filtering to only messages
    # within the specified ID bounds (exclusive)
    discover(
      bridge_address,
      l1_start_block,
      l1_end_block,
      json_rpc_named_arguments,
      chunk_size,
      %{higher_than: lower_bound_msg_id, lower_than: upper_bound_msg_id}
    )

    :ok
  end

  # Discovers and imports L1-to-L2 messages initiated on L1 within a specified block range.
  #
  # This function discovers messages initiated on L1 for transferring information from L1 to L2
  # by retrieving relevant logs within the specified block range on L1, focusing on
  # `MessageDelivered` events. It processes these logs to extract and construct message
  # details. For information not present in the events, RPC calls are made to fetch additional
  # transaction details. The discovered messages are then imported into the database.
  #
  # When `only_messages_in_range` is provided, discovered messages are filtered to only
  # include those with message IDs strictly between the specified bounds (exclusive).
  # This is used for targeted discovery of specific missing messages.
  #
  # ## Parameters
  # - `bridge_address`: The address of the Arbitrum bridge contract used to filter the logs.
  # - `start_block`: The starting block number for log retrieval.
  # - `end_block`: The ending block number for log retrieval.
  # - `json_rpc_named_argument`: Configuration parameters for the JSON RPC connection.
  # - `chunk_size`: The size of chunks for processing RPC calls in batches.
  # - `only_messages_in_range`: Optional map with `:higher_than` and `:lower_than` message
  #   ID bounds for filtering. When present, only messages with IDs strictly between these
  #   bounds (exclusive) are imported. Pass `nil` to import all discovered messages.
  #
  # ## Returns
  # - amount of discovered messages that were attempted to be imported
  defp discover(
         bridge_address,
         start_block,
         end_block,
         json_rpc_named_argument,
         chunk_size,
         only_messages_in_range \\ nil
       )

  defp discover(bridge_address, start_block, end_block, json_rpc_named_argument, chunk_size, only_messages_in_range) do
    logs =
      get_logs_for_l1_to_l2_messages(
        start_block,
        end_block,
        bridge_address,
        json_rpc_named_argument
      )

    messages = get_messages_from_logs(logs, json_rpc_named_argument, chunk_size, only_messages_in_range)

    case messages do
      [] ->
        0

      _ ->
        log_info("Origins of #{length(messages)} L1-to-L2 messages will be imported")

        {:ok, import_result} =
          Chain.import(%{
            arbitrum_messages: %{params: messages},
            timeout: :infinity
          })

        # Count the actual imported records returned by the runner; the input `messages`
        # length can overstate inserts when conflicts/updates happen during import.
        import_result
        |> Map.get(ArbitrumMessage.insert_result_key(), [])
        |> length()
    end
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

    unless Enum.empty?(logs) do
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
  # When `only_messages_in_range` is provided, messages are filtered to only include
  # those with message IDs strictly between the specified bounds (exclusive). This
  # filtering happens after message construction but before database import.
  #
  # ## Parameters
  # - `logs`: A list of log entries to be processed.
  # - `json_rpc_named_arguments`: Configuration parameters for the JSON RPC connection.
  # - `chunk_size`: The size of chunks for batch processing transactions.
  # - `only_messages_in_range`: Optional map with `:higher_than` and `:lower_than`
  #   message ID bounds for filtering. Pass `nil` to include all messages.
  #
  # ## Returns
  # - A list of maps describing discovered messages compatible with the database
  #   import operation.
  @spec get_messages_from_logs(
          [%{String.t() => any()}],
          EthereumJSONRPC.json_rpc_named_arguments(),
          non_neg_integer(),
          %{higher_than: non_neg_integer(), lower_than: non_neg_integer()} | nil
        ) :: [Arbitrum.Message.to_import()]
  defp get_messages_from_logs(logs, json_rpc_named_arguments, chunk_size, only_messages_in_range)

  defp get_messages_from_logs([], _, _, _), do: []

  defp get_messages_from_logs(logs, json_rpc_named_arguments, chunk_size, only_messages_in_range) do
    {messages, transactions_requests} = parse_logs_for_l1_to_l2_messages(logs)

    transactions_to_from =
      Rpc.execute_transactions_requests_and_get_from(transactions_requests, json_rpc_named_arguments, chunk_size)

    complete_messages =
      Enum.map(messages, fn msg ->
        Map.merge(msg, %{
          originator_address: transactions_to_from[msg.originating_transaction_hash],
          status: :initiated
        })
      end)

    filter_messages_by_id_range(complete_messages, only_messages_in_range)
  end

  # Filters messages to only include those with message IDs strictly between the
  # specified bounds (exclusive).
  #
  # This filtering is used when discovering specific missing messages to ensure
  # only the target messages are imported, excluding any messages that already
  # have origination information in the database.
  #
  # When `range` is `nil`, returns all messages without filtering.
  #
  # ## Parameters
  # - `messages`: List of message maps to filter
  # - `range`: Map with `:higher_than` and `:lower_than` message ID bounds, or `nil`
  #
  # ## Returns
  # - Filtered list of messages with IDs in the exclusive range, or all messages if range is `nil`
  @spec filter_messages_by_id_range(
          [Arbitrum.Message.to_import()],
          %{higher_than: non_neg_integer(), lower_than: non_neg_integer()} | nil
        ) :: [Arbitrum.Message.to_import()]
  defp filter_messages_by_id_range(messages, range)

  defp filter_messages_by_id_range(messages, nil), do: messages

  defp filter_messages_by_id_range(messages, %{higher_than: lower_bound, lower_than: upper_bound}) do
    filtered =
      Enum.filter(messages, fn msg ->
        msg.message_id > lower_bound and msg.message_id < upper_bound
      end)

    if length(filtered) < length(messages) do
      filtered_out_count = length(messages) - length(filtered)

      log_debug("Filtered out #{filtered_out_count} messages outside ID range #{lower_bound + 1}..#{upper_bound - 1}")
    end

    filtered
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

  # Marks historical completion status in the state.
  @spec set_historical_completion(
          %{:completed_tasks => %{:check_historical => boolean(), optional(any()) => any()}, optional(any()) => any()},
          boolean()
        ) :: %{
          :completed_tasks => %{:check_historical => boolean(), optional(any()) => any()},
          optional(any()) => any()
        }
  defp set_historical_completion(state, completed?) do
    updated_completed_tasks =
      state
      |> Map.get(:completed_tasks, %{})
      |> Map.put(:check_historical, completed?)

    %{state | completed_tasks: updated_completed_tasks}
  end

  # Marks missing origination discovery completion status in the state.
  #
  # ## Parameters
  # - `state`: The current fetcher state
  # - `completed?`: Boolean indicating if the task has completed
  #
  # ## Returns
  # - Updated state map with the completion flag set
  @spec set_missing_origination_completion(
          %{
            :completed_tasks => %{:check_missing_origination => boolean(), optional(any()) => any()},
            optional(any()) => any()
          },
          boolean()
        ) :: %{
          :completed_tasks => %{:check_missing_origination => boolean(), optional(any()) => any()},
          optional(any()) => any()
        }
  defp set_missing_origination_completion(state, completed?) do
    updated_completed_tasks =
      state
      |> Map.get(:completed_tasks, %{})
      |> Map.put(:check_missing_origination, completed?)

    %{state | completed_tasks: updated_completed_tasks}
  end
end
