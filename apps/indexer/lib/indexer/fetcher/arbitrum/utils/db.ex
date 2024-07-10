defmodule Indexer.Fetcher.Arbitrum.Utils.Db do
  @moduledoc """
    Common functions to simplify DB routines for Indexer.Fetcher.Arbitrum fetchers
  """

  import Ecto.Query, only: [from: 2]

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_warning: 1]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Arbitrum
  alias Explorer.Chain.Arbitrum.Reader
  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.{Data, Hash, Log}

  alias Explorer.Utility.MissingBlockRange

  require Logger

  # 32-byte signature of the event L2ToL1Tx(address caller, address indexed destination, uint256 indexed hash, uint256 indexed position, uint256 arbBlockNum, uint256 ethBlockNum, uint256 timestamp, uint256 callvalue, bytes data)
  @l2_to_l1_event "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc"

  @doc """
    Indexes L1 transactions provided in the input map. For transactions that
    are already in the database, existing indices are taken. For new transactions,
    the next available indices are assigned.

    ## Parameters
    - `new_l1_txs`: A map of L1 transaction descriptions. The keys of the map are
      transaction hashes.

    ## Returns
    - `l1_txs`: A map of L1 transaction descriptions. Each element is extended with
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
  def get_indices_for_l1_transactions(new_l1_txs)
      when is_map(new_l1_txs) do
    # Get indices for l1 transactions previously handled
    l1_txs =
      new_l1_txs
      |> Map.keys()
      |> Reader.lifecycle_transaction_ids()
      |> Enum.reduce(new_l1_txs, fn {hash, id}, txs ->
        {_, txs} =
          Map.get_and_update!(txs, hash.bytes, fn l1_tx ->
            {l1_tx, Map.put(l1_tx, :id, id)}
          end)

        txs
      end)

    # Get the next index for the first new transaction based
    # on the indices existing in DB
    l1_tx_next_id = Reader.next_lifecycle_transaction_id()

    # Assign new indices for the transactions which are not in
    # the l1 transactions table yet
    {updated_l1_txs, _} =
      l1_txs
      |> Map.keys()
      |> Enum.reduce(
        {l1_txs, l1_tx_next_id},
        fn hash, {txs, next_id} ->
          tx = txs[hash]
          id = Map.get(tx, :id)

          if is_nil(id) do
            {Map.put(txs, hash, Map.put(tx, :id, next_id)), next_id + 1}
          else
            {txs, next_id}
          end
        end
      )

    updated_l1_txs
  end

  @doc """
    Reads a list of L1 transactions by their hashes from the
    `arbitrum_lifecycle_l1_transactions` table and converts them to maps.

    ## Parameters
    - `l1_tx_hashes`: A list of hashes to retrieve L1 transactions for.

    ## Returns
    - A list of maps representing the `Explorer.Chain.Arbitrum.LifecycleTransaction`
      corresponding to the hashes from the input list. The output list is
      compatible with the database import operation.
  """
  @spec lifecycle_transactions([binary()]) :: [Arbitrum.LifecycleTransaction.to_import()]
  def lifecycle_transactions(l1_tx_hashes) do
    l1_tx_hashes
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
    Calculates the L1 block number to start the search for committed batches that precede
    the earliest batch already discovered.

    ## Parameters
    - `value_if_nil`: The default value to return if no committed batch is found.

    ## Returns
    - The L1 block number immediately preceding the earliest committed batch,
      or `value_if_nil` if no committed batches are found.
  """
  @spec l1_block_to_discover_earliest_committed_batch(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def l1_block_to_discover_earliest_committed_batch(value_if_nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.l1_block_of_earliest_committed_batch() do
      nil ->
        log_warning("No committed batches found in DB")
        value_if_nil

      value ->
        value - 1
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
    Determines the rollup block number to start searching for missed messages originating from L2.

    ## Parameters
    - `value_if_nil`: The default value to return if no messages originating from L2 have been found.

    ## Returns
    - The rollup block number just before the earliest discovered message from L2,
      or `value_if_nil` if no messages from L2 are found.
  """
  @spec rollup_block_to_discover_missed_messages_from_l2(nil | FullBlock.block_number()) ::
          nil | FullBlock.block_number()
  def rollup_block_to_discover_missed_messages_from_l2(value_if_nil \\ nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.rollup_block_of_earliest_discovered_message_from_l2() do
      nil ->
        log_warning("No messages from L2 found in DB")
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
    Determines the rollup block number to start searching for missed messages originating to L2.

    ## Parameters
    - `value_if_nil`: The default value to return if no messages originating to L2 have been found.

    ## Returns
    - The rollup block number just before the earliest discovered message to L2,
      or `value_if_nil` if no messages to L2 are found.
  """
  @spec rollup_block_to_discover_missed_messages_to_l2(nil | FullBlock.block_number()) :: nil | FullBlock.block_number()
  def rollup_block_to_discover_missed_messages_to_l2(value_if_nil \\ nil)
      when (is_integer(value_if_nil) and value_if_nil >= 0) or is_nil(value_if_nil) do
    case Reader.rollup_block_of_earliest_discovered_message_to_l2() do
      nil ->
        # In theory it could be a situation when when the earliest message points
        # to a completion transaction which is not indexed yet. In this case, this
        # warning will occur.
        log_warning("No completed messages to L2 found in DB")
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
    Retrieves full details of rollup blocks, including associated transactions, for each
    block number specified in the input list.

    ## Parameters
    - `list_of_block_numbers`: A list of block numbers for which full block details are to be retrieved.

    ## Returns
    - A list of `Explorer.Chain.Block` instances containing detailed information for each
      block number in the input list. Returns an empty list if no blocks are found for the given numbers.
  """
  @spec rollup_blocks(maybe_improper_list(FullBlock.block_number(), [])) :: [FullBlock.t()]
  def rollup_blocks(list_of_block_numbers)
      when is_list(list_of_block_numbers) do
    query =
      from(
        block in FullBlock,
        where: block.number in ^list_of_block_numbers
      )

    query
    # :optional is used since a block may not have any transactions
    |> Chain.join_associations(%{:transactions => :optional})
    |> Repo.all(timeout: :infinity)
  end

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
    Retrieves all rollup logs in the range of blocks from `start_block` to `end_block`
    corresponding to the `L2ToL1Tx` event emitted by the ArbSys contract.

    ## Parameters
    - `start_block`: The starting block number of the range from which to
                     retrieve the transaction logs containing L2-to-L1 messages.
    - `end_block`: The ending block number of the range.

    ## Returns
    - A list of log maps for the `L2ToL1Tx` event where binary values for hashes
      and data are decoded into hex strings, containing detailed information about
      each event within the specified block range. Returns an empty list if no
      relevant logs are found.
  """
  @spec l2_to_l1_logs(FullBlock.block_number(), FullBlock.block_number()) :: [
          %{
            data: String,
            index: non_neg_integer(),
            first_topic: String,
            second_topic: String,
            third_topic: String,
            fourth_topic: String,
            address_hash: String,
            transaction_hash: String,
            block_hash: String,
            block_number: FullBlock.block_number()
          }
        ]
  def l2_to_l1_logs(start_block, end_block)
      when is_integer(start_block) and start_block >= 0 and
             is_integer(end_block) and start_block <= end_block do
    arbsys_contract = Application.get_env(:indexer, Indexer.Fetcher.Arbitrum.Messaging)[:arbsys_contract]

    query =
      from(log in Log,
        where:
          log.block_number >= ^start_block and
            log.block_number <= ^end_block and
            log.address_hash == ^arbsys_contract and
            log.first_topic == ^@l2_to_l1_event
      )

    query
    |> Repo.all(timeout: :infinity)
    |> Enum.map(&logs_to_map/1)
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

  @spec get_da_info_by_batch_number(non_neg_integer()) :: map() | nil
  def get_da_info_by_batch_number(batch_number) do
    Reader.get_da_info_by_batch_number(batch_number)
  end

  @spec lifecycle_transaction_to_map(Arbitrum.LifecycleTransaction.t()) :: Arbitrum.LifecycleTransaction.to_import()
  defp lifecycle_transaction_to_map(tx) do
    [:id, :hash, :block_number, :timestamp, :status]
    |> db_record_to_map(tx)
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
