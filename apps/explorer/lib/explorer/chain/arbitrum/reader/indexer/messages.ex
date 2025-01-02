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

  import Ecto.Query, only: [dynamic: 2, from: 2, limit: 2, order_by: 2, select: 3, where: 3]

  alias Explorer.Chain.Arbitrum.{
    L1Execution,
    LifecycleTransaction,
    Message
  }

  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.{Hash, Log, Transaction}
  alias Explorer.{Chain, Repo}

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
    Retrieves the rollup block number of the first missed L2-to-L1 message.

    The function identifies missing messages by checking logs for the specified
    L2-to-L1 event and verifying if there are corresponding entries in the messages
    table. A message is considered missed if there is a log entry without a
    matching message record.

    ## Parameters
    - `arbsys_contract`: The address of the Arbitrum system contract.
    - `l2_to_l1_event`: The event identifier for L2-to-L1 messages.

    ## Returns
    - The block number of the first missed L2-to-L1 message, or `nil` if no missed
      messages are found.
  """
  @spec rollup_block_of_first_missed_message_from_l2(binary(), binary()) :: FullBlock.block_number() | nil
  def rollup_block_of_first_missed_message_from_l2(arbsys_contract, l2_to_l1_event) do
    # credo:disable-for-lines:5 Credo.Check.Refactor.PipeChainStart
    missed_messages_from_l2_query(arbsys_contract, l2_to_l1_event)
    |> order_by(desc: :block_number)
    |> limit(1)
    |> select([log], log.block_number)
    |> Repo.one(timeout: :infinity)
  end

  @doc """
    Retrieves the rollup block number of the first missed L1-to-L2 message.

    The function identifies missing messages by checking transactions of specific
    types that are supposed to contain L1-to-L2 messages and verifying if there are
    corresponding entries in the messages table. A message is considered missed if
    there is a transaction without a matching message record.

    ## Returns
    - The block number of the first missed L1-to-L2 message, or `nil` if no missed
      messages are found.
  """
  @spec rollup_block_of_first_missed_message_to_l2() :: FullBlock.block_number() | nil
  def rollup_block_of_first_missed_message_to_l2 do
    missed_messages_to_l2_query()
    |> order_by(desc: :block_number)
    |> limit(1)
    |> select([rollup_transaction], rollup_transaction.block_number)
    |> Repo.one(timeout: :infinity)
  end

  @doc """
    Reads a list of transactions executing L2-to-L1 messages by their IDs.

    ## Parameters
    - `message_ids`: A list of IDs to retrieve executing transactions for.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.L1Execution` corresponding to the message IDs from
      the input list. The output list may be smaller than the input list if some IDs do not
      correspond to any existing transactions.
  """
  @spec l1_executions(maybe_improper_list(non_neg_integer(), [])) :: [L1Execution.t()]
  def l1_executions(message_ids) when is_list(message_ids) do
    query =
      from(
        ex in L1Execution,
        where: ex.message_id in ^message_ids
      )

    query
    # :required is used since execution records in the table are created only when
    # the corresponding execution transaction is indexed
    |> Chain.join_associations(%{:execution_transaction => :required})
    |> Repo.all()
  end

  @doc """
    Retrieves the number of the latest L1 block where a transaction executing an L2-to-L1 message was discovered.

    ## Returns
    - The number of the latest L1 block with an executing transaction for an L2-to-L1 message, or `nil` if no such transactions are found.
  """
  @spec l1_block_of_latest_execution() :: FullBlock.block_number() | nil
  def l1_block_of_latest_execution do
    query =
      from(
        transaction in LifecycleTransaction,
        inner_join: ex in L1Execution,
        on: transaction.id == ex.execution_id,
        select: transaction.block_number,
        order_by: [desc: transaction.block_number],
        limit: 1
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
      from(
        transaction in LifecycleTransaction,
        inner_join: ex in L1Execution,
        on: transaction.id == ex.execution_id,
        select: transaction.block_number,
        order_by: [asc: transaction.block_number],
        limit: 1
      )

    query
    |> Repo.one(timeout: :infinity)
  end

  @doc """
    Retrieves all L2-to-L1 messages with the specified status.

    If `block_number` is not `nil`, only messages originating in rollup blocks with
    numbers not higher than the specified block are considered. Otherwise, all
    messages are considered.

    ## Parameters
    - `status`: The status of the messages to retrieve, such as `:initiated`,
      `:sent`, `:confirmed`, or `:relayed`.
    - `block_number`: The number of a rollup block that limits the messages lookup,
      or `nil`.

    ## Returns
    - Instances of `Explorer.Chain.Arbitrum.Message` corresponding to the criteria,
      or `[]` if no messages with the given status are found.
  """
  @spec l2_to_l1_messages(:confirmed | :initiated | :relayed | :sent, FullBlock.block_number() | nil) :: [
          Message.t()
        ]
  def l2_to_l1_messages(status, block_number)
      when status in [:initiated, :sent, :confirmed, :relayed] and
             is_integer(block_number) and
             block_number >= 0 do
    query =
      from(msg in Message,
        where:
          msg.direction == :from_l2 and msg.originating_transaction_block_number <= ^block_number and
            msg.status == ^status,
        order_by: [desc: msg.message_id]
      )

    Repo.all(query)
  end

  def l2_to_l1_messages(status, nil) when status in [:initiated, :sent, :confirmed, :relayed] do
    query =
      from(msg in Message,
        where: msg.direction == :from_l2 and msg.status == ^status,
        order_by: [desc: msg.message_id]
      )

    Repo.all(query)
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
  # in the messages table within a given block range, or among all messages if no
  # block range is provided. A message is considered missed if there is a log
  # entry without a matching message record.
  #
  # ## Parameters
  # - `arbsys_contract`: The address hash of the Arbitrum system contract.
  # - `l2_to_l1_event`: The event identifier for L2 to L1 messages.
  # - `start_block`: The starting block number for the search range (optional).
  # - `end_block`: The ending block number for the search range (optional).
  #
  # ## Returns
  # - A query to retrieve missed L2-to-L1 messages.
  @spec missed_messages_from_l2_query(binary(), binary(), non_neg_integer() | nil, non_neg_integer() | nil) ::
          Ecto.Query.t()
  defp missed_messages_from_l2_query(arbsys_contract, l2_to_l1_event, start_block \\ nil, end_block \\ nil) do
    # It is assumed that all the messages from the same transaction are handled
    # atomically so there is no need to check the message_id for each log entry.
    # Otherwise, the join condition must be extended with
    # fragment("encode(l0.fourth_topic, 'hex') = LPAD(TO_HEX(a1.message_id::BIGINT), 64, '0')")
    base_condition =
      dynamic([log, msg], log.transaction_hash == msg.originating_transaction_hash and msg.direction == :from_l2)

    join_condition =
      if is_nil(start_block) or is_nil(end_block) do
        base_condition
      else
        dynamic(
          [_, msg],
          ^base_condition and
            msg.originating_transaction_block_number >= ^start_block and
            msg.originating_transaction_block_number <= ^end_block
        )
      end

    from(log in Log,
      left_join: msg in Message,
      on: ^join_condition,
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
end
