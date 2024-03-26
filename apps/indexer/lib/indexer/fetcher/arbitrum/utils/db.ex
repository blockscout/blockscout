defmodule Indexer.Fetcher.Arbitrum.Utils.Db do
  @moduledoc """
    Common functions to simplify DB routines for Indexer.Fetcher.Arbitrum fetchers
  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Arbitrum.Reader
  alias Explorer.Chain.Block, as: FullBlock
  alias Explorer.Chain.{Data, Hash}

  alias Explorer.Utility.MissingBlockRange

  require Logger

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
  @spec get_indices_for_l1_transactions(map()) :: any()
  # TODO: consider a way to remove duplicate with ZkSync.Utils.Db
  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def get_indices_for_l1_transactions(new_l1_txs)
      when is_map(new_l1_txs) do
    # Get indices for l1 transactions previously handled
    l1_txs =
      new_l1_txs
      |> Map.keys()
      |> Reader.lifecycle_transactions()
      |> Enum.reduce(new_l1_txs, fn {hash, id}, txs ->
        {_, txs} =
          Map.get_and_update!(txs, hash.bytes, fn l1_tx ->
            {l1_tx, Map.put(l1_tx, :id, id)}
          end)

        txs
      end)

    # Get the next index for the first new transaction based
    # on the indices existing in DB
    l1_tx_next_id = Reader.next_id()

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
  TBD
  """
  def l1_block_to_discover_latest_committed_batch(value_if_nil) do
    case Reader.l1_block_of_latest_committed_batch() do
      nil ->
        Logger.warning("No committed batches found in DB")
        value_if_nil

      value ->
        value + 1
    end
  end

  @doc """
  TBD
  """
  def l1_block_to_discover_earliest_committed_batch(value_if_nil) do
    case Reader.l1_block_of_earliest_committed_batch() do
      nil ->
        Logger.warning("No committed batches found in DB")
        value_if_nil

      value ->
        value - 1
    end
  end

  def highest_committed_block(value_if_nil) do
    case Reader.highest_committed_block() do
      nil -> value_if_nil
      value -> value
    end
  end

  @doc """
  TBD
  """
  def l1_block_to_discover_latest_message_to_l2(value_if_nil) do
    case Reader.l1_block_of_latest_discovered_message_to_l2() do
      nil ->
        Logger.warning("No messages to L2 found in DB")
        value_if_nil

      value ->
        value + 1
    end
  end

  @doc """
  TBD
  """
  def l1_block_to_discover_earliest_message_to_l2(value_if_nil) do
    case Reader.l1_block_of_earliest_discovered_message_to_l2() do
      nil ->
        Logger.warning("No messages to L2 found in DB")
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
  TBD
  """
  def rollup_block_to_discover_missed_messages_from_l2(value_if_nil \\ nil) do
    case Reader.rollup_block_of_earliest_discovered_message_from_l2() do
      nil ->
        Logger.warning("No messages from L2 found in DB")
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
  TBD
  """
  def rollup_block_to_discover_missed_messages_to_l2(value_if_nil \\ nil) do
    case Reader.rollup_block_of_earliest_discovered_message_to_l2() do
      nil ->
        # In theory it could be a situation when when the earliest message points
        # to a completion transaction which is not indexed yet. In this case, this
        # warning will occur.
        Logger.warning("No completed messages to L2 found in DB")
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
  TBD
  """
  def l1_block_of_latest_confirmed_block(value_if_nil) do
    case Reader.l1_block_of_latest_confirmed_block() do
      nil ->
        Logger.warning("No confirmed blocks found in DB")
        value_if_nil

      value ->
        value + 1
    end
  end

  def highest_confirmed_block(value_if_nil) do
    case Reader.highest_confirmed_block() do
      nil -> value_if_nil
      value -> value
    end
  end

  def l1_block_to_discover_latest_execution(value_if_nil) do
    case Reader.l1_block_of_latest_execution() do
      nil ->
        Logger.warning("No L1 executions found in DB")
        value_if_nil

      value ->
        value + 1
    end
  end

  def l1_block_to_discover_earliest_execution(value_if_nil) do
    case Reader.l1_block_of_earliest_execution() do
      nil ->
        Logger.warning("No L1 executions found in DB")
        value_if_nil

      value ->
        value - 1
    end
  end

  @doc """
  TBD
  """
  #
  def rollup_blocks(list_of_block_numbers) do
    query =
      from(
        block in FullBlock,
        where: block.number in ^list_of_block_numbers
      )

    query
    |> Chain.join_associations(%{
      :transactions => :optional
    })
    |> Repo.all(timeout: :infinity)
  end

  @doc """
  TBD
  """
  def lifecycle_unfinalized_transactions(finalized_block) do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.lifecycle_unfinalized_transactions(finalized_block)
    |> Enum.map(&lifecycle_transaction_to_map/1)
  end

  defp lifecycle_transaction_to_map(tx) do
    [:id, :hash, :block, :timestamp, :status]
    |> db_record_to_map(tx)
  end

  @doc """
  TBD
  """
  def rollup_block_hash_to_num(hash, %{function: func, params: params} = _recover) do
    case Reader.rollup_block_hash_to_num(hash) do
      {:error, _} ->
        Logger.error("DB inconsistency discovered. No Chain.Block associated with the Arbitrum.BatchBlock")
        apply(func, params)

      {:ok, value} ->
        value
    end
  end

  def get_batch_by_rollup_block_num(num) do
    case Reader.get_batch_by_rollup_block_num(num) do
      nil ->
        nil

      batch ->
        case batch.commit_transaction do
          nil -> nil
          %Ecto.Association.NotLoaded{} -> nil
          _ -> batch
        end
    end
  end

  def unconfirmed_rollup_blocks(first_block, last_block) do
    Reader.unconfirmed_rollup_blocks(first_block, last_block)
  end

  def count_confirmed_rollup_blocks_in_batch(batch_number) do
    Reader.count_confirmed_rollup_blocks_in_batch(batch_number)
  end

  defp message_to_map(message) do
    [
      :direction,
      :message_id,
      :originator_address,
      :originating_tx_hash,
      :originating_tx_blocknum,
      :completion_tx_hash,
      :status
    ]
    |> db_record_to_map(message)
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

  def initiated_l2_to_l1_messages(block_number) do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.l2_to_l1_messages(:initiated, block_number)
    |> Enum.map(&message_to_map/1)
  end

  def sent_l2_to_l1_messages(block_number) do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.l2_to_l1_messages(:sent, block_number)
    |> Enum.map(&message_to_map/1)
  end

  def confirmed_l2_to_l1_messages(block_number) do
    # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
    Reader.l2_to_l1_messages(:confirmed, block_number)
    |> Enum.map(&message_to_map/1)
  end

  def batches_exist(batches_numbers) do
    Reader.batches_exist(batches_numbers)
  end

  def l1_executions(message_ids) do
    Reader.l1_executions(message_ids)
  end

  def l1_blocks_to_expect_rollup_blocks_confirmation(right_pos_value_if_nil) do
    case Reader.l1_blocks_of_confirmations_bounding_first_unconfirmed_rollup_blocks_gap() do
      nil ->
        Logger.warning("No L1 confirmations found in DB")
        {nil, right_pos_value_if_nil}

      {nil, newer_confirmation_l1_block} ->
        {nil, newer_confirmation_l1_block - 1}

      {older_confirmation_l1_block, newer_confirmation_l1_block} ->
        {older_confirmation_l1_block + 1, newer_confirmation_l1_block - 1}
    end
  end

  def l2_to_l1_logs(start_block, end_block) do
    arbsys_contract = Application.get_env(:indexer, Indexer.Fetcher.Arbitrum.Messaging)[:arbsys_contract]

    arbsys_contract
    |> Reader.l2_to_l1_logs(start_block, end_block)
    |> Enum.map(&logs_to_map/1)
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

  def indexed_blocks?(start_block, end_block) do
    is_nil(MissingBlockRange.intersects_with_range(start_block, end_block))
  end

  def l2_to_l1_event, do: Reader.l2_to_l1_event()

  def closest_block_after_timestamp(timestamp) do
    Chain.timestamp_to_block_number(timestamp, :after, false)
  end
end
