defmodule Explorer.Chain.Arbitrum.Reader do
  @moduledoc """
  Contains read functions for Arbitrum modules.
  """

  import Ecto.Query, only: [dynamic: 2, from: 2, limit: 2, order_by: 2, select: 3, subquery: 1, where: 2, where: 3]
  import Explorer.Chain, only: [log_with_transactions_query: 0, select_repo: 1]

  alias Explorer.Chain.Arbitrum.{
    BatchBlock,
    BatchTransaction,
    DaMultiPurposeRecord,
    L1Batch,
    L1Execution,
    LifecycleTransaction,
    Message
  }

  alias Explorer.{Chain, PagingOptions, Repo}

  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.{Hash, Log, Transaction}

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
    Retrieves the number of the latest L1 block where the commitment transaction with a batch was included.

    As per the Arbitrum rollup nature, from the indexer's point of view, a batch does not exist until
    the commitment transaction is submitted to L1. Therefore, the situation where a batch exists but
    there is no commitment transaction is not possible.

    ## Returns
    - The number of the L1 block, or `nil` if no rollup batches are found, or if the association between the batch
      and the commitment transaction has been broken due to database inconsistency.
  """
  @spec l1_block_of_latest_committed_batch() :: FullBlock.block_number() | nil
  def l1_block_of_latest_committed_batch do
    query =
      from(batch in L1Batch,
        order_by: [desc: batch.number],
        limit: 1
      )

    case query
         # :required is used since the situation when commit transaction is not found is not possible
         |> Chain.join_associations(%{:commitment_transaction => :required})
         |> Repo.one(timeout: :infinity) do
      nil -> nil
      batch -> batch.commitment_transaction.block_number
    end
  end

  @doc """
    Retrieves the number of the earliest L1 block where the commitment transaction with a batch was included.

    As per the Arbitrum rollup nature, from the indexer's point of view, a batch does not exist until
    the commitment transaction is submitted to L1. Therefore, the situation where a batch exists but
    there is no commitment transaction is not possible.

    ## Returns
    - The number of the L1 block, or `nil` if no rollup batches are found, or if the association between the batch
      and the commitment transaction has been broken due to database inconsistency.
  """
  @spec l1_block_of_earliest_committed_batch() :: FullBlock.block_number() | nil
  def l1_block_of_earliest_committed_batch do
    query =
      from(batch in L1Batch,
        order_by: [asc: batch.number],
        limit: 1
      )

    case query
         # :required is used since the situation when commit transaction is not found is not possible
         |> Chain.join_associations(%{:commitment_transaction => :required})
         |> Repo.one(timeout: :infinity) do
      nil -> nil
      batch -> batch.commitment_transaction.block_number
    end
  end

  @doc """
    Retrieves the block number of the highest rollup block that has been included in a batch.

    ## Returns
    - The number of the highest rollup block included in a batch, or `nil` if no rollup batches are found.
  """
  @spec highest_committed_block() :: FullBlock.block_number() | nil
  def highest_committed_block do
    query =
      from(batch in L1Batch,
        select: batch.end_block,
        order_by: [desc: batch.number],
        limit: 1
      )

    query
    |> Repo.one()
  end

  @doc """
    Reads a list of L1 transactions by their hashes from the `arbitrum_lifecycle_l1_transactions` table and returns their IDs.

    ## Parameters
    - `l1_transaction_hashes`: A list of hashes to retrieve L1 transactions for.

    ## Returns
    - A list of tuples containing transaction hashes and IDs for the transaction
      hashes from the input list. The output list may be smaller than the input
      list.
  """
  @spec lifecycle_transaction_ids([binary()]) :: [{Hash.t(), non_neg_integer}]
  def lifecycle_transaction_ids(l1_transaction_hashes) when is_list(l1_transaction_hashes) do
    query =
      from(
        lt in LifecycleTransaction,
        select: {lt.hash, lt.id},
        where: lt.hash in ^l1_transaction_hashes
      )

    Repo.all(query)
  end

  @doc """
    Reads a list of L1 transactions by their hashes from the `arbitrum_lifecycle_l1_transactions` table.

    ## Parameters
    - `l1_transaction_hashes`: A list of hashes to retrieve L1 transactions for.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.LifecycleTransaction` corresponding to the
      hashes from the input list. The output list may be smaller than the input
      list.
  """
  @spec lifecycle_transactions([binary()]) :: [LifecycleTransaction.t()]
  def lifecycle_transactions(l1_transaction_hashes) when is_list(l1_transaction_hashes) do
    query =
      from(
        lt in LifecycleTransaction,
        where: lt.hash in ^l1_transaction_hashes
      )

    Repo.all(query)
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
    Determines the next index for the L1 transaction available in the `arbitrum_lifecycle_l1_transactions` table.

    ## Returns
    - The next available index. If there are no L1 transactions imported yet, it will return `1`.
  """
  @spec next_lifecycle_transaction_id() :: non_neg_integer
  def next_lifecycle_transaction_id do
    query =
      from(lt in LifecycleTransaction,
        select: lt.id,
        order_by: [desc: lt.id],
        limit: 1
      )

    last_id =
      query
      |> Repo.one()
      |> Kernel.||(0)

    last_id + 1
  end

  @doc """
    Retrieves unfinalized L1 transactions from the `LifecycleTransaction` table that are
    involved in changing the statuses of rollup blocks or transactions.

    An L1 transaction is considered unfinalized if it has not yet reached a state where
    it is permanently included in the blockchain, meaning it is still susceptible to
    potential reorganization or change. Transactions are evaluated against the `finalized_block`
    parameter to determine their finalized status.

    ## Parameters
    - `finalized_block`: The L1 block number above which transactions are considered finalized.
      Transactions in blocks higher than this number are not included in the results.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.LifecycleTransaction` representing unfinalized transactions,
      or `[]` if no unfinalized transactions are found.
  """
  @spec lifecycle_unfinalized_transactions(FullBlock.block_number()) :: [LifecycleTransaction.t()]
  def lifecycle_unfinalized_transactions(finalized_block)
      when is_integer(finalized_block) and finalized_block >= 0 do
    query =
      from(
        lt in LifecycleTransaction,
        where: lt.block_number <= ^finalized_block and lt.status == :unfinalized
      )

    Repo.all(query)
  end

  @doc """
    Gets the rollup block number by the hash of the block. Lookup is performed only
    for blocks explicitly included in a batch, i.e., the batch has been identified by
    the corresponding fetcher. The function may return `nil` as a successful response
    if the batch containing the rollup block has not been indexed yet.

    ## Parameters
    - `block_hash`: The hash of a block included in the batch.

    ## Returns
    - the number of the rollup block corresponding to the given hash or `nil` if the
      block or batch were not indexed yet.
  """
  @spec rollup_block_hash_to_num(binary()) :: FullBlock.block_number() | nil
  def rollup_block_hash_to_num(block_hash) when is_binary(block_hash) do
    query =
      from(
        fb in FullBlock,
        inner_join: rb in BatchBlock,
        on: rb.block_number == fb.number,
        select: fb.number,
        where: fb.hash == ^block_hash
      )

    query
    |> Repo.one()
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
  @spec batches_exist(maybe_improper_list(non_neg_integer(), [])) :: [non_neg_integer]
  def batches_exist(batches_numbers) when is_list(batches_numbers) do
    query =
      from(
        batch in L1Batch,
        select: batch.number,
        where: batch.number in ^batches_numbers
      )

    query
    |> Repo.all()
  end

  @doc """
    Retrieves the batch in which the rollup block, identified by the given block number, was included.

    ## Parameters
    - `number`: The number of a rollup block.

    ## Returns
    - An instance of `Explorer.Chain.Arbitrum.L1Batch` representing the batch containing
      the specified rollup block number, or `nil` if no corresponding batch is found.
  """
  @spec get_batch_by_rollup_block_number(FullBlock.block_number()) :: L1Batch.t() | nil
  def get_batch_by_rollup_block_number(number)
      when is_integer(number) and number >= 0 do
    query =
      from(batch in L1Batch,
        # end_block has higher number than start_block
        where: batch.end_block >= ^number and batch.start_block <= ^number
      )

    query
    # :required is used since the situation when commit transaction is not found is not possible
    |> Chain.join_associations(%{:commitment_transaction => :required})
    |> Repo.one()
  end

  @doc """
    Retrieves the batch by its number.

    ## Parameters
    - `number`: The number of a rollup batch.

    ## Returns
    - An instance of `Explorer.Chain.Arbitrum.L1Batch`, or `nil` if no batch with
      such a number is found.
  """
  @spec get_batch_by_number(non_neg_integer()) :: L1Batch.t() | nil
  def get_batch_by_number(number) do
    query =
      from(batch in L1Batch,
        where: batch.number == ^number
      )

    query
    |> Repo.one()
  end

  @doc """
    Retrieves the L1 block number where the confirmation transaction of the highest confirmed rollup block was included.

    ## Returns
    - The L1 block number if a confirmed rollup block is found and the confirmation transaction is indexed;
      `nil` if no confirmed rollup blocks are found or if there is a database inconsistency.
  """
  @spec l1_block_of_latest_confirmed_block() :: FullBlock.block_number() | nil
  def l1_block_of_latest_confirmed_block do
    query =
      from(
        rb in BatchBlock,
        where: not is_nil(rb.confirmation_id),
        order_by: [desc: rb.block_number],
        limit: 1
      )

    case query
         # :required is used since existence of the confirmation id is checked above
         |> Chain.join_associations(%{:confirmation_transaction => :required})
         |> Repo.one(timeout: :infinity) do
      nil ->
        nil

      block ->
        case block.confirmation_transaction do
          # `nil` and `%Ecto.Association.NotLoaded{}` indicate DB inconsistency
          nil -> nil
          %Ecto.Association.NotLoaded{} -> nil
          confirmation_transaction -> confirmation_transaction.block_number
        end
    end
  end

  @doc """
    Retrieves the number of the highest confirmed rollup block.

    ## Returns
    - The number of the highest confirmed rollup block, or `nil` if no confirmed rollup blocks are found.
  """
  @spec highest_confirmed_block() :: FullBlock.block_number() | nil
  def highest_confirmed_block do
    query =
      from(
        rb in BatchBlock,
        where: not is_nil(rb.confirmation_id),
        select: rb.block_number,
        order_by: [desc: rb.block_number],
        limit: 1
      )

    query
    |> Repo.one()
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
    Retrieves all unconfirmed rollup blocks within the specified range from `first_block` to `last_block`,
    inclusive, where `first_block` is less than or equal to `last_block`.

    Since the function relies on the block data generated by the block fetcher, the returned list
    may contain fewer blocks than actually exist if some of the blocks have not been indexed by the fetcher yet.

    ## Parameters
    - `first_block`: The rollup block number starting the lookup range.
    - `last_block`:The rollup block number ending the lookup range.

    ## Returns
    - A list of maps containing the batch number, rollup block number and hash for each
      unconfirmed block within the range. Returns `[]` if no unconfirmed blocks are found
      within the range, or if the block fetcher has not indexed them.
  """
  @spec unconfirmed_rollup_blocks(FullBlock.block_number(), FullBlock.block_number()) :: [BatchBlock.t()]
  def unconfirmed_rollup_blocks(first_block, last_block)
      when is_integer(first_block) and first_block >= 0 and
             is_integer(last_block) and first_block <= last_block do
    query =
      from(
        rb in BatchBlock,
        where: rb.block_number >= ^first_block and rb.block_number <= ^last_block and is_nil(rb.confirmation_id),
        order_by: [asc: rb.block_number]
      )

    Repo.all(query)
  end

  @doc """
    Calculates the number of confirmed rollup blocks in the specified batch.

    ## Parameters
    - `batch_number`: The number of the batch for which the count of confirmed blocks is to be calculated.

    ## Returns
    - The number of confirmed blocks in the batch with the given number.
  """
  @spec count_confirmed_rollup_blocks_in_batch(non_neg_integer()) :: non_neg_integer
  def count_confirmed_rollup_blocks_in_batch(batch_number)
      when is_integer(batch_number) and batch_number >= 0 do
    query =
      from(
        rb in BatchBlock,
        where: rb.batch_number == ^batch_number and not is_nil(rb.confirmation_id)
      )

    Repo.aggregate(query, :count)
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
    Retrieves L2-to-L1 messages initiated by specified transaction.

    The messages are filtered by the originating transaction hash (with any status).
    In the common case a transaction can initiate several messages.

    ## Parameters
    - `transaction_hash`: The transaction hash which initiated the messages.

    ## Returns
    - Instances of `Explorer.Chain.Arbitrum.Message` initiated by the transaction
      with the given hash, or `[]` if no messages with the given status are found.
  """
  @spec l2_to_l1_messages_by_transaction_hash(Hash.Full.t(), api?: boolean()) :: [
          Message.t()
        ]
  def l2_to_l1_messages_by_transaction_hash(transaction_hash, options \\ []) when is_list(options) do
    query =
      from(msg in Message,
        where: msg.direction == :from_l2 and msg.originating_transaction_hash == ^transaction_hash,
        order_by: [desc: msg.message_id]
      )

    query
    |> select_repo(options).all()
  end

  @doc """
    Retrieves logs from a transaction that match a specific topic.

    Fetches all logs emitted by the specified transaction that have the given topic
    as their first topic, ordered by log index.

    ## Parameters
    - `transaction_hash`: The hash of the transaction to fetch logs from
    - `topic0`: The first topic to filter logs by
    - `options`: Optional keyword list with `:api?` flag to use replica database

    ## Returns
    - A list of matching logs ordered by index, or empty list if none found
  """
  @spec transaction_to_logs_by_topic0(Hash.Full.t(), binary(), api?: boolean()) :: [Log.t()]
  def transaction_to_logs_by_topic0(transaction_hash, topic0, options \\ []) when is_list(options) do
    log_with_transactions_query()
    |> where([log, transaction], transaction.hash == ^transaction_hash and log.first_topic == ^topic0)
    |> order_by(asc: :index)
    |> select_repo(options).all()
  end

  @doc """
    Retrieves L2-to-L1 message by message id.

    ## Parameters
    - `message_id`: message ID
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - Instance of `Explorer.Chain.Arbitrum.Message` with the provided message id,
      or nil if message with the given id doesn't exist.
  """
  @spec l2_to_l1_message_by_id(non_neg_integer(), api?: boolean()) :: Message.t() | nil
  def l2_to_l1_message_by_id(message_id, options) do
    query =
      from(message in Message,
        where: message.message_id == ^message_id
      )

    select_repo(options).one(query)
  end

  @doc """
    Retrieves the numbers of the L1 blocks containing the confirmation transactions
    bounding the first interval where missed confirmation transactions could be found.

    The absence of a confirmation transaction is assumed based on the analysis of a
    series of confirmed rollup blocks. For example, if blocks 0-3 are confirmed by transaction X,
    blocks 7-9 by transaction Y, and blocks 12-15 by transaction Z, there are two gaps:
    blocks 4-6 and 10-11. According to Arbitrum's nature, this indicates that the confirmation
    transactions for blocks 6 and 11 have not yet been indexed.

    In the example above, the function will return the tuple with the numbers of the L1 blocks
    where transactions Y and Z were included.

    ## Returns
    - A tuple of the L1 block numbers between which missing confirmation transactions are suspected,
      or `nil` if no gaps in confirmed blocks are found or if there are no missed confirmation transactions.
  """
  @spec l1_blocks_of_confirmations_bounding_first_unconfirmed_rollup_blocks_gap() ::
          {FullBlock.block_number() | nil, FullBlock.block_number()} | nil
  def l1_blocks_of_confirmations_bounding_first_unconfirmed_rollup_blocks_gap do
    # The first subquery retrieves the numbers of confirmed rollup blocks.
    rollup_blocks_query =
      from(
        rb in BatchBlock,
        select: %{
          block_number: rb.block_number,
          confirmation_id: rb.confirmation_id
        },
        where: not is_nil(rb.confirmation_id)
      )

    # The second subquery builds on the first one, grouping block numbers by their
    # confirmation transactions. As a result, it identifies the starting and ending
    # rollup blocks for every transaction.
    confirmed_ranges_query =
      from(
        subquery in subquery(rollup_blocks_query),
        select: %{
          confirmation_id: subquery.confirmation_id,
          min_block_num: min(subquery.block_number),
          max_block_num: max(subquery.block_number)
        },
        group_by: subquery.confirmation_id
      )

    # The third subquery utilizes the window function LAG to associate each confirmation
    # transaction with the starting rollup block of the preceding transaction.
    confirmed_combined_ranges_query =
      from(
        subquery in subquery(confirmed_ranges_query),
        select: %{
          confirmation_id: subquery.confirmation_id,
          min_block_num: subquery.min_block_num,
          max_block_num: subquery.max_block_num,
          prev_max_number: fragment("LAG(?, 1) OVER (ORDER BY ?)", subquery.max_block_num, subquery.min_block_num),
          prev_confirmation_id:
            fragment("LAG(?, 1) OVER (ORDER BY ?)", subquery.confirmation_id, subquery.min_block_num)
        }
      )

    # The final query identifies confirmation transactions for which the ending block does
    # not precede the starting block of the subsequent confirmation transaction.
    main_query =
      from(
        subquery in subquery(confirmed_combined_ranges_query),
        inner_join: current_transaction in LifecycleTransaction,
        on: subquery.confirmation_id == current_transaction.id,
        left_join: previous_transaction in LifecycleTransaction,
        on: subquery.prev_confirmation_id == previous_transaction.id,
        select: {previous_transaction.block_number, current_transaction.block_number},
        where: subquery.min_block_num - 1 != subquery.prev_max_number or is_nil(subquery.prev_max_number),
        order_by: [desc: subquery.min_block_num],
        limit: 1
      )

    main_query
    |> Repo.one()
  end

  @doc """
    Retrieves the count of cross-chain messages either sent to or from the rollup.

    ## Parameters
    - `direction`: A string that specifies the message direction; can be "from-rollup" or "to-rollup".
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - The total count of cross-chain messages.
  """
  @spec messages_count(binary(), api?: boolean()) :: non_neg_integer()
  def messages_count(direction, options) when direction == "from-rollup" and is_list(options) do
    do_messages_count(:from_l2, options)
  end

  def messages_count(direction, options) when direction == "to-rollup" and is_list(options) do
    do_messages_count(:to_l2, options)
  end

  # Counts the number of cross-chain messages based on the specified direction.
  @spec do_messages_count(:from_l2 | :to_l2, api?: boolean()) :: non_neg_integer()
  defp do_messages_count(direction, options) do
    Message
    |> where([msg], msg.direction == ^direction)
    |> select_repo(options).aggregate(:count)
  end

  @doc """
    Retrieves cross-chain messages based on the specified direction.

    This function constructs and executes a query to retrieve messages either sent
    to or from the rollup layer, applying pagination options. These options dictate
    not only the number of items to retrieve but also how many items to skip from
    the top.

    ## Parameters
    - `direction`: A string that can be "from-rollup" or "to-rollup", translated internally to `:from_l2` or `:to_l2`.
    - `options`: A keyword list specifying pagination details and database preferences.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.Message` entries.
  """
  @spec messages(binary(),
          paging_options: PagingOptions.t(),
          api?: boolean()
        ) :: [Message.t()]
  def messages(direction, options) when direction == "from-rollup" do
    do_messages(:from_l2, options)
  end

  def messages(direction, options) when direction == "to-rollup" do
    do_messages(:to_l2, options)
  end

  # Executes the query to fetch cross-chain messages based on the specified direction.
  #
  # This function constructs and executes a query to retrieve messages either sent
  # to or from the rollup layer, applying pagination options. These options dictate
  # not only the number of items to retrieve but also how many items to skip from
  # the top.
  #
  # ## Parameters
  # - `direction`: Can be either `:from_l2` or `:to_l2`, indicating the direction of the messages.
  # - `options`: A keyword list of options specifying pagination details and whether to use a replica database.
  #
  # ## Returns
  # - A list of `Explorer.Chain.Arbitrum.Message` entries matching the specified direction.
  @spec do_messages(:from_l2 | :to_l2,
          paging_options: PagingOptions.t(),
          api?: boolean()
        ) :: [Message.t()]
  defp do_messages(direction, options) do
    base_query =
      from(msg in Message,
        where: msg.direction == ^direction,
        order_by: [desc: msg.message_id]
      )

    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    query =
      base_query
      |> page_messages(paging_options)
      |> limit(^paging_options.page_size)

    select_repo(options).all(query)
  end

  defp page_messages(query, %PagingOptions{key: nil}), do: query

  defp page_messages(query, %PagingOptions{key: {id}}) do
    from(msg in query, where: msg.message_id < ^id)
  end

  @doc """
    Retrieves a list of relayed L1 to L2 messages that have been completed.

    ## Parameters
    - `options`: A keyword list of options specifying whether to use a replica database and how pagination should be handled.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.Message` representing relayed messages from L1 to L2 that have been completed.
  """
  @spec relayed_l1_to_l2_messages(
          paging_options: PagingOptions.t(),
          api?: boolean()
        ) :: [Message.t()]
  def relayed_l1_to_l2_messages(options) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    query =
      from(msg in Message,
        where: msg.direction == :to_l2 and not is_nil(msg.completion_transaction_hash),
        order_by: [desc: msg.message_id],
        limit: ^paging_options.page_size
      )

    select_repo(options).all(query)
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
    Retrieves the total count of rollup batches indexed up to the current moment.

    This function uses an estimated count from system catalogs if available.
    If the estimate is unavailable, it performs an exact count using an aggregate query.

    ## Parameters
    - `options`: A keyword list specifying options, including whether to use a replica database.

    ## Returns
    - The count of indexed batches.
  """
  @spec batches_count(api?: boolean()) :: non_neg_integer()
  def batches_count(options) do
    Chain.get_table_rows_total_count(L1Batch, options)
  end

  @doc """
    Retrieves a specific batch by its number or fetches the latest batch if `:latest` is specified.

    ## Parameters
    - `number`: Can be either the specific batch number or `:latest` to retrieve
                the most recent batch in the database.
    - `options`: A keyword list specifying the necessity for joining associations
                 and whether to use a replica database.

    ## Returns
    - `{:ok, Explorer.Chain.Arbitrum.L1Batch}` if the batch is found.
    - `{:error, :not_found}` if no batch with the specified number exists.
  """
  def batch(number, options)

  @spec batch(:latest, api?: boolean()) :: {:error, :not_found} | {:ok, L1Batch.t()}
  def batch(:latest, options) do
    L1Batch
    |> order_by(desc: :number)
    |> limit(1)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  @spec batch(binary() | non_neg_integer(),
          necessity_by_association: %{atom() => :optional | :required},
          api?: boolean()
        ) :: {:error, :not_found} | {:ok, L1Batch.t()}
  def batch(number, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    L1Batch
    |> where(number: ^number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).one()
    |> case do
      nil -> {:error, :not_found}
      batch -> {:ok, batch}
    end
  end

  @doc """
    Retrieves a list of batches from the database.

    This function constructs and executes a query to retrieve batches based on provided
    pagination options. These options dictate not only the number of items to retrieve
    but also how many items to skip from the top. If the `committed?` option is set to true,
    it returns the ten most recent committed batches; otherwise, it fetches batches as
    dictated by other pagination parameters.

    ## Parameters
    - `options`: A keyword list of options specifying pagination, necessity for joining associations,
      and whether to use a replica database.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.L1Batch` entries, filtered and ordered according to the provided options.
  """
  @spec batches(
          necessity_by_association: %{atom() => :optional | :required},
          committed?: boolean(),
          paging_options: PagingOptions.t(),
          api?: boolean()
        ) :: [L1Batch.t()]
  def batches(options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})

    base_query =
      from(batch in L1Batch,
        order_by: [desc: batch.number]
      )

    query =
      if Keyword.get(options, :committed?, false) do
        base_query
        |> Chain.join_associations(necessity_by_association)
        |> where([batch], not is_nil(batch.commitment_id) and batch.commitment_id > 0)
        |> limit(10)
      else
        paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

        base_query
        |> Chain.join_associations(necessity_by_association)
        |> page_batches(paging_options)
        |> limit(^paging_options.page_size)
      end

    select_repo(options).all(query)
  end

  defp page_batches(query, %PagingOptions{key: nil}), do: query

  defp page_batches(query, %PagingOptions{key: {number}}) do
    from(batch in query, where: batch.number < ^number)
  end

  @doc """
    Retrieves a list of rollup transactions included in a specific batch.

    ## Parameters
    - `batch_number`: The batch number whose transactions were included in L1.
    - `options`: A keyword list specifying options, including whether to use a replica database.

    ## Returns
    - A list of `Explorer.Chain.Arbitrum.BatchTransaction` entries belonging to the specified batch.
  """
  @spec batch_transactions(non_neg_integer() | binary(), api?: boolean()) :: [BatchTransaction.t()]
  def batch_transactions(batch_number, options) do
    query = from(transaction in BatchTransaction, where: transaction.batch_number == ^batch_number)

    select_repo(options).all(query)
  end

  @doc """
    Retrieves a list of rollup blocks included in a specific batch.

    This function constructs and executes a database query to retrieve a list of rollup blocks,
    considering pagination options specified in the `options` parameter. These options dictate
    the number of items to retrieve and how many items to skip from the top.

    ## Parameters
    - `batch_number`: The batch number whose transactions are included on L1.
    - `options`: A keyword list of options specifying pagination, association necessity, and
      whether to use a replica database.

    ## Returns
    - A list of `Explorer.Chain.Block` entries belonging to the specified batch.
  """
  @spec batch_blocks(non_neg_integer() | binary(),
          necessity_by_association: %{atom() => :optional | :required},
          api?: boolean(),
          paging_options: PagingOptions.t()
        ) :: [FullBlock.t()]
  def batch_blocks(batch_number, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())

    query =
      from(
        fb in FullBlock,
        inner_join: rb in BatchBlock,
        on: fb.number == rb.block_number,
        select: fb,
        where: fb.consensus == true and rb.batch_number == ^batch_number
      )

    query
    |> FullBlock.block_type_filter("Block")
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> Chain.join_associations(necessity_by_association)
    |> select_repo(options).all()
  end

  defp page_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_blocks(query, %PagingOptions{key: {block_number}}) do
    where(query, [block], block.number < ^block_number)
  end

  @doc """
    Retrieves an AnyTrust keyset from the database using the provided keyset hash.

    ## Parameters
    - `keyset_hash`: A binary representing the hash of the keyset to be retrieved.

    ## Returns
    - A map containing information about the AnyTrust keyset, otherwise an empty map.
  """
  @spec get_anytrust_keyset(binary()) :: map() | nil
  def get_anytrust_keyset("0x" <> <<_::binary-size(64)>> = keyset_hash) do
    get_anytrust_keyset(keyset_hash |> Chain.string_to_block_hash() |> Kernel.elem(1) |> Map.get(:bytes))
  end

  def get_anytrust_keyset(keyset_hash) do
    query =
      from(
        da_records in DaMultiPurposeRecord,
        where: da_records.data_key == ^keyset_hash and da_records.data_type == 1
      )

    case Repo.one(query) do
      nil -> %{}
      keyset -> keyset.data
    end
  end

  @doc """
    Retrieves Data Availability (DA) information from the database using the provided
    batch number.

    ## Parameters
    - `batch_number`: The batch number to be used for retrieval.

    ## Returns
    - A map containing the DA information if found, otherwise an empty map.
  """
  @spec get_da_info_by_batch_number(non_neg_integer()) :: map()
  def get_da_info_by_batch_number(batch_number) do
    query =
      from(
        da_records in DaMultiPurposeRecord,
        where: da_records.batch_number == ^batch_number and da_records.data_type == 0
      )

    case Repo.one(query) do
      nil -> %{}
      keyset -> keyset.data
    end
  end

  @doc """
    Retrieves a Data Availability (DA) record from the database using the provided
    data key.

    ## Parameters
    - `data_key`: The key of the data to be retrieved.

    ## Returns
    - `{:ok, {batch_number, da_info}}`, where
      - `batch_number` is the number of the batch associated with the DA record
      - `da_info` is a map containing the DA record.
    - `{:error, :not_found}` if no record with the specified `data_key` exists.
  """
  @spec get_da_record_by_data_key(binary(), api?: boolean()) :: {:ok, {non_neg_integer(), map()}} | {:error, :not_found}
  def get_da_record_by_data_key("0x" <> _ = data_key, options) do
    data_key_bytes = data_key |> Chain.string_to_block_hash() |> Kernel.elem(1) |> Map.get(:bytes)
    get_da_record_by_data_key(data_key_bytes, options)
  end

  def get_da_record_by_data_key(data_key, options) do
    query =
      from(
        da_records in DaMultiPurposeRecord,
        where: da_records.data_key == ^data_key and da_records.data_type == 0
      )

    case select_repo(options).one(query) do
      nil -> {:error, :not_found}
      keyset -> {:ok, {keyset.batch_number, keyset.data}}
    end
  end

  @doc """
    Retrieves the batch numbers of missing L1 batches within a specified range.

    This function constructs a query to find the batch numbers of L1 batches that
    are missing within the given range of batch numbers. It uses a right join with
    a generated series to identify batch numbers that do not exist in the
    `arbitrum_l1_batches` table.

    ## Parameters
    - `start_batch_number`: The starting batch number of the search range.
    - `end_batch_number`: The ending batch number of the search range.

    ## Returns
    - A list of batch numbers in ascending order that are missing within the specified range.
  """
  @spec find_missing_batches(non_neg_integer(), non_neg_integer()) :: [non_neg_integer()]
  def find_missing_batches(start_batch_number, end_batch_number)
      when is_integer(start_batch_number) and is_integer(end_batch_number) and end_batch_number >= start_batch_number do
    query =
      from(batch in L1Batch,
        right_join:
          missing_range in fragment(
            """
            (
              SELECT distinct b1.number
              FROM generate_series((?)::integer, (?)::integer) AS b1(number)
              WHERE NOT EXISTS
                (SELECT 1 FROM arbitrum_l1_batches b2 WHERE b2.number=b1.number)
              ORDER BY b1.number DESC
            )
            """,
            ^start_batch_number,
            ^end_batch_number
          ),
        on: batch.number == missing_range.number,
        select: missing_range.number,
        order_by: missing_range.number,
        distinct: missing_range.number
      )

    query
    |> Repo.all()
  end

  @doc """
    Retrieves L1 block numbers for the given list of batch numbers.

    This function finds the numbers of L1 blocks that include L1 transactions
    associated with batches within the specified list of batch numbers.

    ## Parameters
    - `batch_numbers`: A list of batch numbers for which to retrieve the L1 block numbers.

    ## Returns
    - A map where the keys are batch numbers and the values are corresponding L1 block numbers.
  """
  @spec get_l1_blocks_of_batches_by_numbers([non_neg_integer()]) :: %{non_neg_integer() => FullBlock.block_number()}
  def get_l1_blocks_of_batches_by_numbers(batch_numbers) when is_list(batch_numbers) do
    query =
      from(batch in L1Batch,
        join: l1tx in assoc(batch, :commitment_transaction),
        where: batch.number in ^batch_numbers,
        select: {batch.number, l1tx.block_number}
      )

    query
    |> Repo.all()
    |> Enum.reduce(%{}, fn {batch_number, l1_block_number}, acc ->
      Map.put(acc, batch_number, l1_block_number)
    end)
  end

  @doc """
    Retrieves the minimum and maximum batch numbers of L1 batches.

    ## Returns
    - A tuple containing the minimum and maximum batch numbers or `{nil, nil}` if no batches are found.
  """
  @spec get_min_max_batch_numbers() :: {non_neg_integer(), non_neg_integer()} | {nil | nil}
  def get_min_max_batch_numbers do
    query =
      from(batch in L1Batch,
        select: {min(batch.number), max(batch.number)}
      )

    Repo.one(query, timeout: :infinity)
  end

  #####################################################################################
  ### Below are the functions that implement functionality not specific to Arbitrum ###
  #####################################################################################

  @doc """
    Checks if a block with the given block number exists.

    This function queries the database to determine if a block with the specified
    block number exists and has been marked as having reached consensus.

    ## Parameters
    - `block_number`: The number of the block to check.

    ## Returns
    - `true` if the block exists and has reached consensus.
    - `false` otherwise.
  """
  @spec rollup_block_exists?(FullBlock.block_number()) :: boolean()
  def rollup_block_exists?(block_number) do
    query =
      from(
        block in FullBlock,
        where: block.number == ^block_number and block.consensus == true
      )

    Repo.exists?(query, timeout: :infinity)
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
  @spec rollup_blocks([FullBlock.block_number()]) :: [FullBlock.t()]
  def rollup_blocks(list_of_block_numbers)

  def rollup_blocks([]), do: []

  def rollup_blocks(list_of_block_numbers) do
    query =
      from(
        block in FullBlock,
        where: block.number in ^list_of_block_numbers
      )

    query
    # :optional is used since a block may not have any transactions
    |> Chain.join_associations(%{:transactions => :optional})
    |> Repo.all()
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
