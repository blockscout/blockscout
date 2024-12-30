defmodule Indexer.Fetcher.Arbitrum.Utils.Db.Messages do
  @moduledoc """
    Provides utility functions for querying Arbitrum cross-chain message data.

    This module serves as a wrapper around the database reader functions from
    `Explorer.Chain.Arbitrum.Reader.Indexer.Messages`, providing additional data
    transformation and error handling capabilities.
  """

  alias EthereumJSONRPC.Arbitrum.Constants.Events, as: ArbitrumEvents

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1]

  alias Explorer.Chain.Arbitrum.Reader.Indexer.Messages, as: Reader

  alias Explorer.Chain.Arbitrum.{
    L1Execution,
    Message
  }

  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.Hash

  alias Indexer.Fetcher.Arbitrum.Utils.Db.Tools, as: DbTools

  require Logger

  @no_messages_warning "No messages to L2 found in DB"
  @no_executions_warning "No L1 executions found in DB"

  @doc """
    Calculates the next L1 block number to search for the latest message sent to L2.

    ## Parameters
    - `value_if_nil`: The default value to return if no L1-to-L2 messages have been discovered.

    ## Returns
    - The L1 block number immediately following the latest discovered message to L2,
      or `value_if_nil` if no messages to L2 have been found.
  """
  @spec l1_block_to_discover_latest_message_to_l2(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_to_discover_latest_message_to_l2(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_latest_discovered_message_to_l2() do
      nil ->
        log_warning(@no_messages_warning)
        value_if_nil

      value ->
        value + 1
    end
  end

  @doc """
    Calculates the next L1 block number to start the search for messages sent to L2
    that precede the earliest message already discovered.

    ## Parameters
    - `value_if_nil`: The default value to return if no L1-to-L2 messages have been discovered.

    ## Returns
    - The L1 block number immediately preceding the earliest discovered message to L2,
      or `value_if_nil` if no messages to L2 have been found.
  """
  @spec l1_block_to_discover_earliest_message_to_l2(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_to_discover_earliest_message_to_l2(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_earliest_discovered_message_to_l2() do
      nil ->
        log_warning(@no_messages_warning)
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
    Determines the next L1 block number to search for the latest execution of an L2-to-L1 message.

    ## Parameters
    - `value_if_nil`: The default value to return if no execution transactions for L2-to-L1 messages
      have been recorded.

    ## Returns
    - The L1 block number following the block that contains the latest execution transaction
      for an L2-to-L1 message, or `value_if_nil` if no such executions have been found.
  """
  @spec l1_block_to_discover_latest_execution(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_to_discover_latest_execution(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_latest_execution() do
      nil ->
        log_warning(@no_executions_warning)
        value_if_nil

      value ->
        value + 1
    end
  end

  @doc """
    Determines the L1 block number just before the block that contains the earliest known
    execution transaction for an L2-to-L1 message.

    ## Parameters
    - `value_if_nil`: The default value to return if no execution transactions for
       L2-to-L1 messages have been found.

    ## Returns
    - The L1 block number preceding the earliest known execution transaction for
      an L2-to-L1 message, or `value_if_nil` if no such executions are found in the database.
  """
  @spec l1_block_to_discover_earliest_execution(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_to_discover_earliest_execution(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_earliest_execution() do
      nil ->
        log_warning(@no_executions_warning)
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
    Retrieves a list of L2-to-L1 messages that have been initiated up to
    a specified rollup block number.

    ## Parameters
    - `block_number`: The block number up to which initiated L2-to-L1 messages
      should be retrieved.

    ## Returns
    - A list of maps, each representing an initiated L2-to-L1 message compatible with the
      database import operation. If no initiated messages are found up to the specified
      block number, an empty list is returned.
  """
  @spec initiated_l2_to_l1_messages(FullBlock.block_number()) :: [Message.to_import()]
  def initiated_l2_to_l1_messages(block_number)
      when is_integer(block_number) and block_number >= 0 do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.l2_to_l1_messages(:initiated, block_number)
    |> Enum.map(&message_to_map/1)
  end

  @doc """
    Retrieves a list of L2-to-L1 'sent' messages that have been included up to
    a specified rollup block number.

    A message is considered 'sent' when there is a batch including the transaction
    that initiated the message, and this batch has been successfully delivered to L1.

    ## Parameters
    - `block_number`: The block number up to which sent L2-to-L1 messages are to be retrieved.

    ## Returns
    - A list of maps, each representing a sent L2-to-L1 message compatible with the
      database import operation. If no messages with the 'sent' status are found by
      the specified block number, an empty list is returned.
  """
  @spec sent_l2_to_l1_messages(FullBlock.block_number()) :: [Message.to_import()]
  def sent_l2_to_l1_messages(block_number)
      when is_integer(block_number) and block_number >= 0 do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.l2_to_l1_messages(:sent, block_number)
    |> Enum.map(&message_to_map/1)
  end

  @doc """
    Retrieves a list of L2-to-L1 'confirmed' messages that have been included up to
    a specified rollup block number.

    A message is considered 'confirmed' when its transaction was included in a rollup block,
    and the confirmation of this block has been delivered to L1.

    ## Parameters
    - `block_number`: The block number up to which confirmed L2-to-L1 messages are to be retrieved.

    ## Returns
    - A list of maps, each representing a confirmed L2-to-L1 message compatible with the
      database import operation. If no messages with the 'confirmed' status are found by
      the specified block number, an empty list is returned.
  """
  @spec confirmed_l2_to_l1_messages() :: [Message.to_import()]
  def confirmed_l2_to_l1_messages do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.l2_to_l1_messages(:confirmed, nil)
    |> Enum.map(&message_to_map/1)
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
  @spec l1_executions([non_neg_integer()]) :: [L1Execution.t()]
  def l1_executions(message_ids) when is_list(message_ids) do
    Reader.l1_executions(message_ids)
  end

  @doc """
    Retrieves the transaction hashes as strings for missed L1-to-L2 messages within
    a specified block range.

    The function identifies missed messages by checking transactions of specific
    types that are supposed to contain L1-to-L2 messages and verifying if there are
    corresponding entries in the messages table. A message is considered missed if
    there is a transaction without a matching message record within the specified
    block range.

    ## Parameters
    - `start_block`: The starting block number of the range.
    - `end_block`: The ending block number of the range.

    ## Returns
    - A list of transaction hashes as strings for missed L1-to-L2 messages.
  """
  @spec transactions_for_missed_messages_to_l2(non_neg_integer(), non_neg_integer()) :: [String.t()]
  def transactions_for_missed_messages_to_l2(start_block, end_block) do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.transactions_for_missed_messages_to_l2(start_block, end_block)
    |> Enum.map(&Hash.to_string/1)
  end

  @doc """
    Retrieves the logs for missed L2-to-L1 messages within a specified block range
    and converts them to maps.

    The function identifies missed messages by checking logs for the specified
    L2-to-L1 event and verifying if there are corresponding entries in the messages
    table. A message is considered missed if there is a log entry without a
    matching message record within the specified block range.

    ## Parameters
    - `start_block`: The starting block number of the range.
    - `end_block`: The ending block number of the range.

    ## Returns
    - A list of maps representing the logs for missed L2-to-L1 messages.
  """
  @spec logs_for_missed_messages_from_l2(non_neg_integer(), non_neg_integer()) :: [
          %{
            data: String.t(),
            index: non_neg_integer(),
            first_topic: String.t(),
            second_topic: String.t(),
            third_topic: String.t(),
            fourth_topic: String.t(),
            address_hash: String.t(),
            transaction_hash: String.t(),
            block_hash: String.t(),
            block_number: FullBlock.block_number()
          }
        ]
  def logs_for_missed_messages_from_l2(start_block, end_block) do
    arbsys_contract = Application.get_env(:indexer, Indexer.Fetcher.Arbitrum.Messaging)[:arbsys_contract]

    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.logs_for_missed_messages_from_l2(start_block, end_block, arbsys_contract, ArbitrumEvents.l2_to_l1())
    |> Enum.map(&logs_to_map/1)
  end

  @doc """
    Retrieves the list of uncompleted L2-to-L1 messages IDs.

    ## Returns
    - A list of the IDs of uncompleted L2-to-L1 messages.
  """
  @spec get_uncompleted_l1_to_l2_messages_ids() :: [non_neg_integer()]
  def get_uncompleted_l1_to_l2_messages_ids do
    Reader.get_uncompleted_l1_to_l2_messages_ids()
  end

  @spec message_to_map(Message.t()) :: Message.to_import()
  defp message_to_map(message) do
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
    |> DbTools.db_record_to_map(message)
  end

  defp logs_to_map(log) do
    [
      :data,
      :index,
      :first_topic,
      :second_topic,
      :third_topic,
      :fourth_topic,
      :address_hash,
      :transaction_hash,
      :block_hash,
      :block_number
    ]
    |> DbTools.db_record_to_map(log, true)
  end
end
