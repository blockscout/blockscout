defmodule Indexer.Fetcher.ZkSync.Utils.Db do
  @moduledoc """
    Common functions to simplify DB routines for Indexer.Fetcher.ZkSync fetchers
  """

  alias Explorer.Chain
  alias Explorer.Chain.ZkSync.Reader
  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_warning: 1, log_info: 1]

  @json_batch_fields_absent_in_db_batch [
    :commit_transaction_hash,
    :commit_timestamp,
    :prove_transaction_hash,
    :prove_timestamp,
    :executed_transaction_hash,
    :executed_timestamp
  ]

  @doc """
    Deletes elements in the batch description map to prepare the batch for importing to
    the database.

    ## Parameters
    - `batch_with_json_fields`: a map describing a batch with elements that could remain
                                after downloading batch details from RPC.

    ## Returns
    - A map describing the batch compatible with the database import operation.
  """
  @spec prune_json_batch(map()) :: map()
  def prune_json_batch(batch_with_json_fields)
      when is_map(batch_with_json_fields) do
    Map.drop(batch_with_json_fields, @json_batch_fields_absent_in_db_batch)
  end

  @doc """
    Gets the oldest imported batch number.

    ## Parameters
    - none

    ## Returns
    - A batch number or `nil` if there are no batches in the database.
  """
  @spec get_earliest_batch_number() :: nil | non_neg_integer()
  def get_earliest_batch_number do
    case Reader.oldest_available_batch_number() do
      nil ->
        log_warning("No batches found in DB")
        nil

      value ->
        value
    end
  end

  @doc """
    Gets the oldest imported batch number without an associated commitment L1 transaction.

    ## Parameters
    - none

    ## Returns
    - A batch number or `nil` in cases where there are no batches in the database or
      all batches in the database are marked as committed.
  """
  @spec get_earliest_sealed_batch_number() :: nil | non_neg_integer()
  def get_earliest_sealed_batch_number do
    case Reader.earliest_sealed_batch_number() do
      nil ->
        log_info("No uncommitted batches found in DB")
        nil

      value ->
        value
    end
  end

  @doc """
    Gets the oldest imported batch number without an associated proving L1 transaction.

    ## Parameters
    - none

    ## Returns
    - A batch number or `nil` in cases where there are no batches in the database or
      all batches in the database are marked as proven.
  """
  @spec get_earliest_unproven_batch_number() :: nil | non_neg_integer()
  def get_earliest_unproven_batch_number do
    case Reader.earliest_unproven_batch_number() do
      nil ->
        log_info("No unproven batches found in DB")
        nil

      value ->
        value
    end
  end

  @doc """
    Gets the oldest imported batch number without an associated executing L1 transaction.

    ## Parameters
    - none

    ## Returns
    - A batch number or `nil` in cases where there are no batches in the database or
      all batches in the database are marked as executed.
  """
  @spec get_earliest_unexecuted_batch_number() :: nil | non_neg_integer()
  def get_earliest_unexecuted_batch_number do
    case Reader.earliest_unexecuted_batch_number() do
      nil ->
        log_info("No not executed batches found in DB")
        nil

      value ->
        value
    end
  end

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
      `zksync_lifecycle_l1_transactions` table.
  """
  @spec get_indices_for_l1_transactions(map()) :: any()
  # TODO: consider a way to remove duplicate with Arbitrum.Utils.Db
  # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
  def get_indices_for_l1_transactions(new_l1_transactions)
      when is_map(new_l1_transactions) do
    # Get indices for l1 transactions previously handled
    l1_transactions =
      new_l1_transactions
      |> Map.keys()
      |> Reader.lifecycle_transactions()
      |> Enum.reduce(new_l1_transactions, fn {hash, id}, transactions ->
        {_, transactions} =
          Map.get_and_update!(transactions, hash.bytes, fn l1_transaction ->
            {l1_transaction, Map.put(l1_transaction, :id, id)}
          end)

        transactions
      end)

    # Get the next index for the first new transaction based
    # on the indices existing in DB
    l1_transaction_next_id = Reader.next_id()

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
    Imports provided lists of batches and their associations with L1 transactions, rollup blocks,
    and transactions to the database.

    ## Parameters
    - `batches`: A list of maps with batch descriptions.
    - `l1_transactions`: A list of maps with L1 transaction descriptions. Optional.
    - `l2_transactions`: A list of maps with rollup transaction associations. Optional.
    - `l2_blocks`: A list of maps with rollup block associations. Optional.

    ## Returns
    n/a
  """
  def import_to_db(batches, l1_transactions \\ [], l2_transactions \\ [], l2_blocks \\ [])
      when is_list(batches) and is_list(l1_transactions) and is_list(l2_transactions) and is_list(l2_blocks) do
    {:ok, _} =
      Chain.import(%{
        zksync_lifecycle_transactions: %{params: l1_transactions},
        zksync_transaction_batches: %{params: batches},
        zksync_batch_transactions: %{params: l2_transactions},
        zksync_batch_blocks: %{params: l2_blocks},
        timeout: :infinity
      })
  end
end
