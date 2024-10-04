defmodule Indexer.Fetcher.Arbitrum.Utils.Db do
  @moduledoc """
    Common functions to simplify DB routines for Indexer.Fetcher.Arbitrum fetchers
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1]

  alias Explorer.Chain
  alias Explorer.Chain.Arbitrum
  alias Explorer.Chain.Arbitrum.Reader
  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.{Data, Hash}

  alias Explorer.Utility.MissingBlockRange

  require Logger

  # 32-byte signature of the event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)
  @l2_to_l1_event "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc"

  @doc """
    Indexes L1 transactions provided in the input map. For transactions that
    are already in the database, existing indices are taken. For new transactions,
    the next available indices are assigned.

    ## Parameters
    - `new_l1_transactions`: A map of L1 transaction descriptions. The keys of the map are
      transaction hashes.

    ## Returns
    - `l1_transactions`: A map of L1 transaction descriptions. Each element is extended with
      the key `:id`, representing the index of the L1 transaction in the
      `arbitrum_lifecycle_l1_transactions` table.
  """
  @spec get_indices_for_l1_transactions(%{
          binary() => %{
            :hash => binary(),
            :block_number => FullBlock.block_number(),
            :timestamp => DateTime.t(),
            :status => :unfinalized | :finalized,
            optional(:id) => non_neg_integer()
          }
        }) :: %{binary() => Arbitrum.LifecycleTransaction.to_import()}
  # TODO: consider a way to remove duplicate with ZkSync.Utils.Db
  def get_indices_for_l1_transactions(new_l1_transactions)
      when is_map(new_l1_transactions) do
    # Get indices for l1 transactions previously handled
    l1_transactions =
      new_l1_transactions
      |> Map.keys()
      |> Reader.lifecycle_transaction_ids()
      |> Enum.reduce(new_l1_transactions, fn {hash, id}, transactions ->
        {_, transactions} =
          Map.get_and_update!(transactions, hash.bytes, fn l1_transaction ->
            {l1_transaction, Map.put(l1_transaction, :id, id)}
          end)

        transactions
      end)

    # Get the next index for the first new transaction based
    # on the indices existing in DB
    l1_transaction_next_id = Reader.next_lifecycle_transaction_id()

    # Assign new indices for the transactions which are not in
    # the l1 transactions table yet
    {updated_l1_transactions, _} =
      l1_transactions
      |> Map.keys()
      |> Enum.reduce(
        {l1_transactions, l1_transaction_next_id},
        fn hash, {transactions, next_id} ->
          transaction = transactions[hash]
          id = Map.get(transaction, :id)

          if is_nil(id) do
            {Map.put(transactions, hash, Map.put(transaction, :id, next_id)), next_id + 1}
          else
            {transactions, next_id}
          end
        end
      )

    updated_l1_transactions
  end

  @doc """
    Reads a list of L1 transactions by their hashes from the
    `arbitrum_lifecycle_l1_transactions` table and converts them to maps.

    ## Parameters
    - `l1_transaction_hashes`: A list of hashes to retrieve L1 transactions for.

    ## Returns
    - A list of maps representing the `Explorer.Chain.Arbitrum.LifecycleTransaction`
      corresponding to the hashes from the input list. The output list is
      compatible with the database import operation.
  """
  @spec lifecycle_transactions([binary()]) :: [Arbitrum.LifecycleTransaction.to_import()]
  def lifecycle_transactions(l1_transaction_hashes) do
    l1_transaction_hashes
    |> Reader.lifecycle_transactions()
    |> Enum.map(&lifecycle_transaction_to_map/1)
  end

  @doc """
    Calculates the next L1 block number to search for the latest committed batch.

    ## Parameters
    - `value_if_nil`: The default value to return if no committed batch is found.

    ## Returns
    - The next L1 block number after the latest committed batch or `value_if_nil` if no committed batches are found.
  """
  @spec l1_block_to_discover_latest_committed_batch(FullBlock.block_number() | nil) :: FullBlock.block_number() | nil
  def l1_block_to_discover_latest_committed_batch(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_latest_committed_batch() do
      nil ->
        log_warning("No committed batches found in DB")
        value_if_nil

      value ->
        value + 1
    end
  end

  @doc """
    Calculates the L1 block number to start the search for committed batches.

    Returns the block number of the earliest L1 block containing a transaction
    that commits a batch, as found in the database. If no committed batches are
    found, it returns a default value. It's safe to use the returned block number
    for subsequent searches, even if it corresponds to a block we've previously
    processed. This is because multiple transactions committing different batches
    can exist within the same block, and revisiting this block ensures no batches
    are missed.

    The batch discovery process is expected to handle potential duplicates
    correctly without creating redundant database entries.

    ## Parameters
    - `value_if_nil`: The default value to return if no committed batch is found.

    ## Returns
    - The L1 block number containing the earliest committed batch or `value_if_nil`.
  """
  @spec l1_block_to_discover_earliest_committed_batch(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_to_discover_earliest_committed_batch(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_earliest_committed_batch() do
      nil ->
        log_warning("No committed batches found in DB")
        value_if_nil

      value ->
        value
    end
  end

  @doc """
    Retrieves the block number of the highest rollup block that has been included in a batch.

    ## Parameters
    - `value_if_nil`: The default value to return if no rollup batches are found.

    ## Returns
    - The number of the highest rollup block included in a batch
      or `value_if_nil` if no rollup batches are found.
  """
  @spec highest_committed_block(nil | integer()) :: nil | FullBlock.block_number()
  def highest_committed_block(value_if_nil)
      when is_integer(value_if_nil) or is_nil(value_if_nil) do
    case Reader.highest_committed_block() do
      nil -> value_if_nil
      value -> value
    end
  end

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
        log_warning("No messages to L2 found in DB")
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
        log_warning("No messages to L2 found in DB")
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
    Retrieves the L1 block number immediately following the block where the confirmation transaction
    for the highest confirmed rollup block was included.

    ## Parameters
    - `value_if_nil`: The default value to return if no confirmed rollup blocks are found.

    ## Returns
    - The L1 block number immediately after the block containing the confirmation transaction of
      the highest confirmed rollup block, or `value_if_nil` if no confirmed rollup blocks are present.
  """
  @spec l1_block_of_latest_confirmed_block(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_of_latest_confirmed_block(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_latest_confirmed_block() do
      nil ->
        log_warning("No confirmed blocks found in DB")
        value_if_nil

      value ->
        value + 1
    end
  end

  @doc """
    Retrieves the block number of the highest rollup block for which a confirmation transaction
    has been sent to L1.

    ## Parameters
    - `value_if_nil`: The default value to return if no confirmed rollup blocks are found.

    ## Returns
    - The block number of the highest confirmed rollup block,
      or `value_if_nil` if no confirmed rollup blocks are found in the database.
  """
  @spec highest_confirmed_block(nil | integer()) :: nil | FullBlock.block_number()
  def highest_confirmed_block(value_if_nil)
      when is_integer(value_if_nil) or is_nil(value_if_nil) do
    case Reader.highest_confirmed_block() do
      nil -> value_if_nil
      value -> value
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
        log_warning("No L1 executions found in DB")
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
        log_warning("No L1 executions found in DB")
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
    Retrieves full details of rollup blocks, including associated transactions, for each block number specified in the input list.

    ## Parameters
    - `list_of_block_numbers`: A list of block numbers for which full block details are to be retrieved.

    ## Returns
    - A list of `Explorer.Chain.Block` instances containing detailed information for each
      block number in the input list. Returns an empty list if no blocks are found for the given numbers.
  """
  @spec rollup_blocks([FullBlock.block_number()]) :: [FullBlock.t()]
  def rollup_blocks(list_of_block_numbers), do: Reader.rollup_blocks(list_of_block_numbers)

  @doc """
    Retrieves unfinalized L1 transactions that are involved in changing the statuses
    of rollup blocks or transactions.

    An L1 transaction is considered unfinalized if it has not yet reached a state
    where it is permanently included in the blockchain, meaning it is still susceptible
    to potential reorganization or change. Transactions are evaluated against
    the finalized_block parameter to determine their finalized status.

    ## Parameters
    - `finalized_block`: The block number up to which unfinalized transactions are to be retrieved.

    ## Returns
    - A list of maps representing unfinalized L1 transactions and compatible with the
      database import operation.
  """
  @spec lifecycle_unfinalized_transactions(FullBlock.block_number()) :: [Arbitrum.LifecycleTransaction.to_import()]
  def lifecycle_unfinalized_transactions(finalized_block)
      when is_integer(finalized_block) and finalized_block >= 0 do
    finalized_block
    |> Reader.lifecycle_unfinalized_transactions()
    |> Enum.map(&lifecycle_transaction_to_map/1)
  end

  @doc """
    Retrieves the block number associated with a specific hash of a rollup block.

    ## Parameters
    - `hash`: The hash of the rollup block whose number is to be retrieved.

    ## Returns
    - The block number associated with the given rollup block hash.
  """
  @spec rollup_block_hash_to_num(binary()) :: FullBlock.block_number() | nil
  def rollup_block_hash_to_num(hash) when is_binary(hash) do
    Reader.rollup_block_hash_to_num(hash)
  end

  @doc """
    Retrieves the L1 batch that includes a specified rollup block number.

    ## Parameters
    - `num`: The block number of the rollup block for which the containing
      L1 batch is to be retrieved.

    ## Returns
    - The `Explorer.Chain.Arbitrum.L1Batch` associated with the given rollup block number
      if it exists and its commit transaction is loaded.
  """
  @spec get_batch_by_rollup_block_number(FullBlock.block_number()) :: Arbitrum.L1Batch.t() | nil
  def get_batch_by_rollup_block_number(num)
      when is_integer(num) and num >= 0 do
    case Reader.get_batch_by_rollup_block_number(num) do
      nil ->
        nil

      batch ->
        case batch.commitment_transaction do
          nil ->
            raise "Incorrect state of the DB: commitment_transaction is not loaded for the batch with number #{num}"

          %Ecto.Association.NotLoaded{} ->
            raise "Incorrect state of the DB: commitment_transaction is not loaded for the batch with number #{num}"

          _ ->
            batch
        end
    end
  end

  @doc """
    Retrieves a batch by its number.

    ## Parameters
    - `number`: The number of a rollup batch.

    ## Returns
    - An instance of `Explorer.Chain.Arbitrum.L1Batch`, or `nil` if no batch with
      such a number is found.
  """
  @spec get_batch_by_number(non_neg_integer()) :: Arbitrum.L1Batch.t() | nil
  def get_batch_by_number(number) do
    Reader.get_batch_by_number(number)
  end

  @doc """
    Retrieves rollup blocks within a specified block range that have not yet been confirmed.

    ## Parameters
    - `first_block`: The starting block number of the range to search for unconfirmed rollup blocks.
    - `last_block`: The ending block number of the range.

    ## Returns
    - A list of maps, each representing an unconfirmed rollup block within the specified range.
      If no unconfirmed blocks are found within the range, an empty list is returned.
  """
  @spec unconfirmed_rollup_blocks(FullBlock.block_number(), FullBlock.block_number()) :: [
          Arbitrum.BatchBlock.to_import()
        ]
  def unconfirmed_rollup_blocks(first_block, last_block)
      when is_integer(first_block) and first_block >= 0 and
             is_integer(last_block) and first_block <= last_block do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.unconfirmed_rollup_blocks(first_block, last_block)
    |> Enum.map(&rollup_block_to_map/1)
  end

  @doc """
    Counts the number of confirmed rollup blocks in a specified batch.

    ## Parameters
    - `batch_number`: The batch number for which the count of confirmed rollup blocks
      is to be determined.

    ## Returns
    - A number of rollup blocks confirmed in the specified batch.
  """
  @spec count_confirmed_rollup_blocks_in_batch(non_neg_integer()) :: non_neg_integer()
  def count_confirmed_rollup_blocks_in_batch(batch_number)
      when is_integer(batch_number) and batch_number >= 0 do
    Reader.count_confirmed_rollup_blocks_in_batch(batch_number)
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
  @spec initiated_l2_to_l1_messages(FullBlock.block_number()) :: [Arbitrum.Message.to_import()]
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
  @spec sent_l2_to_l1_messages(FullBlock.block_number()) :: [Arbitrum.Message.to_import()]
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
  @spec confirmed_l2_to_l1_messages() :: [Arbitrum.Message.to_import()]
  def confirmed_l2_to_l1_messages do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.l2_to_l1_messages(:confirmed, nil)
    |> Enum.map(&message_to_map/1)
  end

  @doc """
    Checks if the numbers from the provided list correspond to the numbers of indexed batches.

    ## Parameters
    - `batches_numbers`: The list of batch numbers.

    ## Returns
    - A list of batch numbers that are indexed and match the provided list, or `[]`
      if none of the batch numbers in the provided list exist in the database. The output list
      may be smaller than the input list.
  """
  @spec batches_exist([non_neg_integer()]) :: [non_neg_integer()]
  def batches_exist(batches_numbers) when is_list(batches_numbers) do
    Reader.batches_exist(batches_numbers)
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
  @spec l1_executions([non_neg_integer()]) :: [Arbitrum.L1Execution.t()]
  def l1_executions(message_ids) when is_list(message_ids) do
    Reader.l1_executions(message_ids)
  end

  @doc """
    Identifies the range of L1 blocks to investigate for missing confirmations of rollup blocks.

    This function determines the L1 block numbers bounding the interval where gaps in rollup block
    confirmations might exist. It uses the earliest and latest L1 block numbers associated with
    unconfirmed rollup blocks to define this range.

    ## Parameters
    - `right_pos_value_if_nil`: The default value to use for the upper bound of the range if no
      confirmed blocks found.

    ## Returns
    - A tuple containing two elements: the lower and upper bounds of L1 block numbers to check
      for missing rollup block confirmations. If the necessary confirmation data is unavailable,
      the first element will be `nil`, and the second will be `right_pos_value_if_nil`.
  """
  @spec l1_blocks_to_expect_rollup_blocks_confirmation(nil | FullBlock.block_number()) ::
          {nil | FullBlock.block_number(), nil | FullBlock.block_number()}
  def l1_blocks_to_expect_rollup_blocks_confirmation(right_pos_value_if_nil)
      when (is_integer(right_pos_value_if_nil) and right_pos_value_if_nil >= 0) or is_nil(right_pos_value_if_nil) do
    case Reader.l1_blocks_of_confirmations_bounding_first_unconfirmed_rollup_blocks_gap() do
      nil ->
        log_warning("No L1 confirmations found in DB")
        {nil, right_pos_value_if_nil}

      {nil, newer_confirmation_l1_block} ->
        {nil, newer_confirmation_l1_block - 1}

      {older_confirmation_l1_block, newer_confirmation_l1_block} ->
        {older_confirmation_l1_block + 1, newer_confirmation_l1_block - 1}
    end
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
    Reader.logs_for_missed_messages_from_l2(start_block, end_block, arbsys_contract, @l2_to_l1_event)
    |> Enum.map(&logs_to_map/1)
  end

  @doc """
    Retrieves L1 block ranges that could be used to re-discover missing batches
    within a specified range of batch numbers.

    This function identifies the L1 block ranges corresponding to missing L1 batches
    within the given range of batch numbers. It first finds the missing batches,
    then determines their neighboring ranges, and finally maps these ranges to the
    corresponding L1 block numbers.

    ## Parameters
    - `start_batch_number`: The starting batch number of the search range.
    - `end_batch_number`: The ending batch number of the search range.
    - `block_for_batch_0`: The L1 block number corresponding to the batch number 0.

    ## Returns
    - A list of tuples, each containing a start and end L1 block number for the
      ranges corresponding to the missing batches.

    ## Examples

    Example #1
    - Within the range from 1 to 10, the missing batch is 2. The L1 block for the
      batch #1 is 10, and the L1 block for the batch #3 is 31.
    - The output will be `[{10, 31}]`.

    Example #2
    - Within the range from 1 to 10, the missing batches are 2 and 6, and
      - The L1 block for the batch #1 is 10.
      - The L1 block for the batch #3 is 31.
      - The L1 block for the batch #5 is 64.
      - The L1 block for the batch #7 is 90.
    - The output will be `[{10, 31}, {64, 90}]`.

    Example #3
    - Within the range from 1 to 10, the missing batches are 2 and 4, and
      - The L1 block for the batch #1 is 10.
      - The L1 block for the batch #3 is 31.
      - The L1 block for the batch #5 is 64.
    - The output will be `[{10, 31}, {32, 64}]`.

    Example #4
    - Within the range from 1 to 10, the missing batches are 2 and 4, and
      - The L1 block for the batch #1 is 10.
      - The L1 block for the batch #3 is 31.
      - The L1 block for the batch #5 is 31.
    - The output will be `[{10, 31}]`.
  """
  @spec get_l1_block_ranges_for_missing_batches(non_neg_integer(), non_neg_integer(), FullBlock.block_number()) :: [
          {FullBlock.block_number(), FullBlock.block_number()}
        ]
  def get_l1_block_ranges_for_missing_batches(start_batch_number, end_batch_number, block_for_batch_0)
      when is_integer(start_batch_number) and is_integer(end_batch_number) and end_batch_number >= start_batch_number do
    # credo:disable-for-lines:4 Credo.Check.Refactor.PipeChainStart
    neighbors_of_missing_batches =
      Reader.find_missing_batches(start_batch_number, end_batch_number)
      |> list_to_chunks()
      |> chunks_to_neighbor_ranges()

    batches_gaps_to_block_ranges(neighbors_of_missing_batches, block_for_batch_0)
  end

  # Splits a list into chunks of consecutive numbers, e.g., [1, 2, 3, 5, 6, 8] becomes [[1, 2, 3], [5, 6], [8]].
  @spec list_to_chunks([non_neg_integer()]) :: [[non_neg_integer()]]
  defp list_to_chunks(list) do
    chunk_fun = fn current, acc ->
      case acc do
        [] ->
          {:cont, [current]}

        [last | _] = acc when current == last + 1 ->
          {:cont, [current | acc]}

        acc ->
          {:cont, Enum.reverse(acc), [current]}
      end
    end

    after_fun = fn acc ->
      case acc do
        # Special case to handle the situation when the initial list is empty
        [] -> {:cont, []}
        _ -> {:cont, Enum.reverse(acc), []}
      end
    end

    list
    |> Enum.chunk_while([], chunk_fun, after_fun)
  end

  # Converts chunks of elements into neighboring ranges, e.g., [[1, 2], [4]] becomes [{0, 3}, {3, 5}].
  @spec chunks_to_neighbor_ranges([[non_neg_integer()]]) :: [{non_neg_integer(), non_neg_integer()}]
  defp chunks_to_neighbor_ranges([]), do: []

  defp chunks_to_neighbor_ranges(list_of_chunks) do
    list_of_chunks
    |> Enum.map(fn current ->
      case current do
        [one_element] -> {one_element - 1, one_element + 1}
        chunk -> {List.first(chunk) - 1, List.last(chunk) + 1}
      end
    end)
  end

  # Converts batch number gaps to L1 block ranges for missing batches discovery.
  #
  # This function takes a list of neighboring batch number ranges representing gaps
  # in the batch sequence and converts them to corresponding L1 block ranges. These
  # L1 block ranges can be used to rediscover missing batches.
  #
  # ## Parameters
  # - `neighbors_of_missing_batches`: A list of tuples, each containing the start
  #   and end batch numbers of a gap in the batch sequence.
  # - `block_for_batch_0`: The L1 block number corresponding to batch number 0.
  #
  # ## Returns
  # - A list of tuples, each containing the start and end L1 block numbers for
  #   ranges where missing batches should be rediscovered.
  @spec batches_gaps_to_block_ranges([{non_neg_integer(), non_neg_integer()}], FullBlock.block_number()) ::
          [{FullBlock.block_number(), FullBlock.block_number()}]
  defp batches_gaps_to_block_ranges(neighbors_of_missing_batches, block_for_batch_0)

  defp batches_gaps_to_block_ranges([], _), do: []

  defp batches_gaps_to_block_ranges(neighbors_of_missing_batches, block_for_batch_0) do
    l1_blocks =
      neighbors_of_missing_batches
      |> Enum.reduce(MapSet.new(), fn {start_batch, end_batch}, acc ->
        acc
        |> MapSet.put(start_batch)
        |> MapSet.put(end_batch)
      end)
      # To avoid error in getting L1 block for the batch 0
      |> MapSet.delete(0)
      |> MapSet.to_list()
      |> Reader.get_l1_blocks_of_batches_by_numbers()
      # It is safe to add the block for the batch 0 even if the batch 1 is missing
      |> Map.put(0, block_for_batch_0)

    neighbors_of_missing_batches
    |> Enum.reduce({[], %{}}, fn {start_batch, end_batch}, {res, blocks_used} ->
      range_start = l1_blocks[start_batch]
      range_end = l1_blocks[end_batch]
      # If the batch's block was already used as a block finishing one of the ranges
      # then we should start another range from the next block to avoid discovering
      # the same batches batches again.
      case {Map.get(blocks_used, range_start, false), range_start == range_end} do
        {true, true} ->
          # Edge case when the range consists of a single block (several batches in
          # the same block) which is going to be inspected up to this moment.
          {res, blocks_used}

        {true, false} ->
          {[{range_start + 1, range_end} | res], Map.put(blocks_used, range_end, true)}

        {false, _} ->
          {[{range_start, range_end} | res], Map.put(blocks_used, range_end, true)}
      end
    end)
    |> elem(0)
  end

  @doc """
    Retrieves the minimum and maximum batch numbers of L1 batches.

    ## Returns
    - A tuple containing the minimum and maximum batch numbers or `{nil, nil}` if no batches are found.
  """
  @spec get_min_max_batch_numbers() :: {non_neg_integer(), non_neg_integer()} | {nil | nil}
  def get_min_max_batch_numbers do
    Reader.get_min_max_batch_numbers()
  end

  @doc """
    Returns 32-byte signature of the event `L2ToL1Tx`
  """
  @spec l2_to_l1_event() :: <<_::528>>
  def l2_to_l1_event, do: @l2_to_l1_event

  @doc """
    Determines whether a given range of block numbers has been fully indexed without any missing blocks.

    ## Parameters
    - `start_block`: The starting block number of the range to check for completeness in indexing.
    - `end_block`: The ending block number of the range.

    ## Returns
    - `true` if the entire range from `start_block` to `end_block` is indexed and contains no missing
      blocks, indicating no intersection with missing block ranges; `false` otherwise.
  """
  @spec indexed_blocks?(FullBlock.block_number(), FullBlock.block_number()) :: boolean()
  def indexed_blocks?(start_block, end_block)
      when is_integer(start_block) and start_block >= 0 and
             is_integer(end_block) and start_block <= end_block do
    is_nil(MissingBlockRange.intersects_with_range(start_block, end_block))
  end

  @doc """
    Retrieves the block number for the closest block immediately after a given timestamp.

    ## Parameters
    - `timestamp`: The `DateTime` timestamp for which the closest subsequent block number is sought.

    ## Returns
    - `{:ok, block_number}` where `block_number` is the number of the closest block that occurred
      after the specified timestamp.
    - `{:error, :not_found}` if no block is found after the specified timestamp.
  """
  @spec closest_block_after_timestamp(DateTime.t()) :: {:error, :not_found} | {:ok, FullBlock.block_number()}
  def closest_block_after_timestamp(timestamp) do
    Chain.timestamp_to_block_number(timestamp, :after, false)
  end

  @doc """
    Checks if an AnyTrust keyset exists in the database using the provided keyset hash.

    ## Parameters
    - `keyset_hash`: The hash of the keyset to be checked.

    ## Returns
    - `true` if the keyset exists, `false` otherwise.
  """
  @spec anytrust_keyset_exists?(binary()) :: boolean()
  def anytrust_keyset_exists?(keyset_hash) do
    not Enum.empty?(Reader.get_anytrust_keyset(keyset_hash))
  end

  @doc """
    Retrieves Data Availability (DA) information for a specific Arbitrum batch number.

    This function queries the database for DA information stored in the
    `DaMultiPurposeRecord`. It specifically looks for records where
    the `data_type` is 0, which corresponds to batch-specific DA information.

    ## Parameters
    - `batch_number`: The Arbitrum batch number.

    ## Returns
    - A map containing the DA information for the specified batch number. This map
      corresponds to the `data` field of the `DaMultiPurposeRecord`.
    - An empty map (`%{}`) if no DA information is found for the given batch number.
  """
  @spec get_da_info_by_batch_number(non_neg_integer()) :: map()
  def get_da_info_by_batch_number(batch_number) do
    Reader.get_da_info_by_batch_number(batch_number)
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

  @spec lifecycle_transaction_to_map(Arbitrum.LifecycleTransaction.t()) :: Arbitrum.LifecycleTransaction.to_import()
  defp lifecycle_transaction_to_map(transaction) do
    [:id, :hash, :block_number, :timestamp, :status]
    |> db_record_to_map(transaction)
  end

  @spec rollup_block_to_map(Arbitrum.BatchBlock.t()) :: Arbitrum.BatchBlock.to_import()
  defp rollup_block_to_map(block) do
    [:batch_number, :block_number, :confirmation_id]
    |> db_record_to_map(block)
  end

  @spec message_to_map(Arbitrum.Message.t()) :: Arbitrum.Message.to_import()
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
    |> db_record_to_map(message)
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
    |> db_record_to_map(log, true)
  end

  # Converts an Arbitrum-related database record to a map with specified keys and optional encoding.
  #
  # This function is used to transform various Arbitrum-specific database records
  # (such as LifecycleTransaction, BatchBlock, or Message) into maps containing
  # only the specified keys. It's particularly useful for preparing data for
  # import or further processing of Arbitrum blockchain data.
  #
  # Parameters:
  #   - `required_keys`: A list of atoms representing the keys to include in the
  #     output map.
  #   - `record`: The database record or struct to be converted.
  #   - `encode`: Boolean flag to determine if Hash and Data types should be
  #     encoded to strings (default: false). When true, Hash and Data are
  #     converted to string representations; otherwise, their raw bytes are used.
  #
  # Returns:
  #   - A map containing only the required keys from the input record. Hash and
  #     Data types are either encoded to strings or left as raw bytes based on
  #     the `encode` parameter.  @spec db_record_to_map([atom()], map(), boolean()) :: map()
  defp db_record_to_map(required_keys, record, encode \\ false) do
    required_keys
    |> Enum.reduce(%{}, fn key, record_as_map ->
      raw_value = Map.get(record, key)

      # credo:disable-for-lines:5 Credo.Check.Refactor.Nesting
      value =
        case raw_value do
          %Hash{} -> if(encode, do: Hash.to_string(raw_value), else: raw_value.bytes)
          %Data{} -> if(encode, do: Data.to_string(raw_value), else: raw_value.bytes)
          _ -> raw_value
        end

      Map.put(record_as_map, key, value)
    end)
  end
end
