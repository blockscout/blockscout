defmodule Explorer.Chain.Arbitrum.Reader.Indexer.Messages do
  @moduledoc """
    Provides functions for querying and managing Arbitrum cross-chain messages in the Blockscout indexer.

    This module handles the retrieval and tracking of messages between a parent
    chain and Orbit (built with Arbitrum technology) chains, including:
    - L1-to-L2 message discovery and tracking
    - L2-to-L1 message monitoring and status updates
    - Detection of missed messages in both directions
    - Tracking of L2-to-L1 message executions on L1
  """

  import Ecto.Query, only: [from: 2, order_by: 2, select: 3, where: 3]

  alias Explorer.Chain.Arbitrum.{
    LifecycleTransaction,
    Message
  }

  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.{Hash, Log, Transaction}
  alias Explorer.Repo

  # https://github.com/OffchainLabs/go-ethereum/blob/dff302de66598c36b964b971f72d35a95148e650/core/types/transaction.go#L44C2-L50
  @message_to_l2_eth_deposit 100
  @message_to_l2_submit_retryable_transaction 105
  @to_l2_messages_transaction_types [
    @message_to_l2_eth_deposit,
    @message_to_l2_submit_retryable_transaction
  ]

  @doc """
    Retrieves the number of the latest L1 block where an L1-to-L2 message was discovered.

    ## Returns
    - The number of L1 block, or `nil` if no L1-to-L2 messages are found.
  """
  @spec l1_block_of_latest_discovered_message_to_l2() :: FullBlock.block_number() | nil
  def l1_block_of_latest_discovered_message_to_l2 do
    query =
      from(msg in Message,
        select: msg.originating_transaction_block_number,
        where: msg.direction == :to_l2 and not is_nil(msg.originating_transaction_block_number),
        order_by: [desc: msg.message_id],
        limit: 1
      )

    query
    |> Repo.one(timeout: :infinity)
  end

  @doc """
    Retrieves the number of the earliest L1 block where an L1-to-L2 message was discovered.

    ## Returns
    - The number of L1 block, or `nil` if no L1-to-L2 messages are found.
  """
  @spec l1_block_of_earliest_discovered_message_to_l2() :: FullBlock.block_number() | nil
  def l1_block_of_earliest_discovered_message_to_l2 do
    query =
      from(msg in Message,
        select: msg.originating_transaction_block_number,
        where: msg.direction == :to_l2 and not is_nil(msg.originating_transaction_block_number),
        order_by: [asc: msg.message_id],
        limit: 1
      )

    query
    |> Repo.one(timeout: :infinity)
  end

  @doc """
    Retrieves the number of the latest L1 block where a transaction executing an L2-to-L1 message was discovered.

    ## Returns
    - The number of the latest L1 block with an executing transaction for an L2-to-L1 message, or `nil` if no such transactions are found.
  """
  @spec l1_block_of_latest_execution() :: FullBlock.block_number() | nil
  def l1_block_of_latest_execution do
    query =
      from(txn in LifecycleTransaction,
        join: msg in Message,
        on: txn.hash == msg.completion_transaction_hash,
        where: msg.direction == :from_l2,
        select: max(txn.block_number)
      )

    query
    |> Repo.one(timeout: :infinity)
  end

  @doc """
    Retrieves the number of the earliest L1 block where a transaction executing an L2-to-L1 message was discovered.

    ## Returns
    - The number of the earliest L1 block with an executing transaction for an L2-to-L1 message, or `nil` if no such transactions are found.
  """
  @spec l1_block_of_earliest_execution() :: FullBlock.block_number() | nil
  def l1_block_of_earliest_execution do
    query =
      from(txn in LifecycleTransaction,
        join: msg in Message,
        on: txn.hash == msg.completion_transaction_hash,
        where: msg.direction == :from_l2,
        select: min(txn.block_number)
      )

    query
    |> Repo.one(timeout: :infinity)
  end

  @doc """
    Retrieves the transaction hashes for missed L1-to-L2 messages within a specified
    block range.

    The function identifies missed messages by checking transactions of specific
    types that are supposed to contain L1-to-L2 messages and verifying if there are
    corresponding entries in the messages table. A message is considered missed if
    there is a transaction without a matching message record within the specified
    block range.

    ## Parameters
    - `start_block`: The starting block number of the range.
    - `end_block`: The ending block number of the range.

    ## Returns
    - A list of transaction hashes for missed L1-to-L2 messages.
  """
  @spec transactions_for_missed_messages_to_l2(non_neg_integer(), non_neg_integer()) :: [Hash.t()]
  def transactions_for_missed_messages_to_l2(start_block, end_block) do
    missed_messages_to_l2_query()
    |> where(
      [rollup_transaction],
      rollup_transaction.block_number >= ^start_block and rollup_transaction.block_number <= ^end_block
    )
    |> order_by(desc: :block_timestamp)
    |> select([rollup_transaction], rollup_transaction.hash)
    |> Repo.all()
  end

  # Constructs a query to retrieve missed L1-to-L2 messages.
  #
  # The function constructs a query to identify missing messages by checking
  # transactions of specific types that are supposed to contain L1-to-L2
  # messages and verifying if there are corresponding entries in the messages
  # table. A message is considered missed if there is a transaction without a
  # matching message record.
  #
  # ## Returns
  #   - A query to retrieve missed L1-to-L2 messages.
  @spec missed_messages_to_l2_query() :: Ecto.Query.t()
  defp missed_messages_to_l2_query do
    from(rollup_transaction in Transaction,
      left_join: msg in Message,
      on: rollup_transaction.hash == msg.completion_transaction_hash and msg.direction == :to_l2,
      where: rollup_transaction.type in @to_l2_messages_transaction_types and is_nil(msg.completion_transaction_hash)
    )
  end

  @doc """
    Retrieves the logs for missed L2-to-L1 messages within a specified block range.

    The function identifies missed messages by checking logs for the specified
    L2-to-L1 event and verifying if there are corresponding entries in the messages
    table. A message is considered missed if there is a log entry without a
    matching message record within the specified block range.

    ## Parameters
    - `start_block`: The starting block number of the range.
    - `end_block`: The ending block number of the range.
    - `arbsys_contract`: The address of the Arbitrum system contract.
    - `l2_to_l1_event`: The event identifier for L2-to-L1 messages.

    ## Returns
    - A list of logs for missed L2-to-L1 messages.
  """
  @spec logs_for_missed_messages_from_l2(non_neg_integer(), non_neg_integer(), binary(), binary()) :: [Log.t()]
  def logs_for_missed_messages_from_l2(start_block, end_block, arbsys_contract, l2_to_l1_event) do
    # credo:disable-for-lines:5 Credo.Check.Refactor.PipeChainStart
    missed_messages_from_l2_query(arbsys_contract, l2_to_l1_event, start_block, end_block)
    |> where([log, msg], log.block_number >= ^start_block and log.block_number <= ^end_block)
    |> order_by(desc: :block_number, desc: :index)
    |> select([log], log)
    |> Repo.all()
  end

  # Constructs a query to retrieve missed L2-to-L1 messages.
  #
  # The function constructs a query to identify missing messages by checking logs
  # for the specified L2-to-L1 and verifying if there are corresponding entries
  # in the messages table within a given block range. A message is considered missed
  # if there is a log entry without a matching message record.
  #
  # ## Parameters
  # - `arbsys_contract`: The address hash of the Arbitrum system contract.
  # - `l2_to_l1_event`: The event identifier for L2 to L1 messages.
  # - `start_block`: The starting block number for the search range.
  # - `end_block`: The ending block number for the search range.
  #
  # ## Returns
  # - A query to retrieve missed L2-to-L1 messages.
  @spec missed_messages_from_l2_query(binary(), binary(), non_neg_integer(), non_neg_integer()) ::
          Ecto.Query.t()
  defp missed_messages_from_l2_query(arbsys_contract, l2_to_l1_event, start_block, end_block) do
    # It is assumed that all the messages from the same transaction are handled
    # atomically so there is no need to check the message_id for each log entry.
    # Otherwise, the join condition must be extended with
    # fragment("encode(l0.fourth_topic, 'hex') = LPAD(TO_HEX(a1.message_id::BIGINT), 64, '0')")
    from(log in Log,
      left_join: msg in Message,
      on:
        log.transaction_hash == msg.originating_transaction_hash and
          msg.direction == :from_l2 and
          msg.originating_transaction_block_number >= ^start_block and
          msg.originating_transaction_block_number <= ^end_block,
      where:
        log.address_hash == ^arbsys_contract and log.first_topic == ^l2_to_l1_event and
          is_nil(msg.originating_transaction_hash)
    )
  end

  @doc """
    Retrieves the message IDs of uncompleted L1-to-L2 messages.

    ## Returns
    - A list of the message IDs of uncompleted L1-to-L2 messages.
  """
  @spec get_uncompleted_l1_to_l2_messages_ids() :: [non_neg_integer()]
  def get_uncompleted_l1_to_l2_messages_ids do
    query =
      from(msg in Message,
        where: msg.direction == :to_l2 and is_nil(msg.completion_transaction_hash),
        select: msg.message_id
      )

    Repo.all(query)
  end

  @doc """
    Retrieves L2-to-L1 messages by their IDs.

    ## Parameters
    - `message_ids`: A list of message IDs to retrieve.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.Message` corresponding to the message IDs from
      the input list. The output list may be smaller than the input list if some IDs do not
      correspond to any existing messages.
  """
  @spec l2_to_l1_messages_by_ids([non_neg_integer()]) :: [Message.t()]
  def l2_to_l1_messages_by_ids(message_ids) when is_list(message_ids) do
    query =
      from(msg in Message,
        where: msg.direction == :from_l2 and msg.message_id in ^message_ids,
        order_by: [desc: msg.message_id]
      )

    Repo.all(query)
  end

  @doc """
    Streams messages directed from rollup to parent chain with initiated or sent status up to a specified rollup block number.

    For each message, it returns:
    - `{message_id, block_number}` for messages with `:initiated` status
    - `{message_id, block_number, :sent}` for messages with `:sent` status

    ## Parameters
    - `initial`: The initial accumulator value for the stream.
    - `reducer`: A function that processes each entry in the stream, receiving
      the entry and the current accumulator, and returning a new accumulator.
    - `max_block`: The maximum rollup block number to consider. Messages from blocks
      higher than this will not be included in the stream. Mostly used to efficiently
      re-use the composite index.

    ## Returns
    - `{:ok, accumulator}`: The final accumulator value after streaming through
      the initiated and sent L2-to-L1 messages.
  """
  @spec stream_unconfirmed_messages_from_l2({0, []}, function(), non_neg_integer()) ::
          {:ok,
           {non_neg_integer(), [{non_neg_integer(), non_neg_integer()} | {non_neg_integer(), non_neg_integer(), :sent}]}}
  def stream_unconfirmed_messages_from_l2(initial, reducer, max_block)
      when max_block >= 0 do
    query =
      from(msg in Message,
        where:
          msg.direction == :from_l2 and
            msg.originating_transaction_block_number <= ^max_block and
            msg.status in [:initiated, :sent],
        select: {msg.message_id, msg.originating_transaction_block_number, msg.status},
        order_by: [asc: msg.originating_transaction_block_number]
      )

    # Create a custom reducer that transforms the database results into the format
    # expected by L2ToL1StatusReconciler:
    # - For messages with `:initiated` status: convert {id, block, status} -> {id, block}
    # - For messages with `:sent` status: keep as {id, block, :sent}
    # This matches the pattern matching in L2ToL1StatusReconciler.process_message
    modified_reducer = fn {id, block, status}, acc ->
      entry = if status == :sent, do: {id, block, :sent}, else: {id, block}
      reducer.(entry, acc)
    end

    # This query is safe to run even with hundreds of thousands of records because:
    # 1. Repo.stream_reduce uses database cursors under the hood, fetching records in batches (default 500)
    # 2. Each batch is loaded into memory only when needed and released after processing
    # 3. The query uses a composite index on (direction, originating_transaction_block_number, status)
    #    making the filtering and ordering efficient
    # 4. Results start flowing to the reducer function as soon as the first batch is fetched
    #    rather than waiting for the entire result set
    Repo.stream_reduce(query, initial, modified_reducer)
  end
end
