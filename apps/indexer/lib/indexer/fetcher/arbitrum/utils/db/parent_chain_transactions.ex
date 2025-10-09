defmodule Indexer.Fetcher.Arbitrum.Utils.Db.ParentChainTransactions do
  @moduledoc """
    Manages database operations for Arbitrum L1 (parent chain) lifecycle transactions.

    This module handles indexing and retrieval of L1 transactions that affect the Arbitrum
    rollup state, including:
      * Batch commitment transactions from the sequencer
      * State root confirmation transactions post fraud-proof window
      * User-initiated cross-chain message transactions

    Provides functionality to:
      * Index new L1 transactions with sequential IDs
      * Retrieve transaction data by hash
      * Convert database records to import-compatible format
      * Track transaction finalization status
  """

  alias Explorer.Chain.Arbitrum.LifecycleTransaction
  alias Explorer.Chain.Arbitrum.Reader.Indexer.ParentChainTransactions, as: Reader
  alias Explorer.Chain.Block, as: FullBlock
  alias Indexer.Fetcher.Arbitrum.Utils.Db.Tools, as: DbTools

  require Logger

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
        }) :: %{binary() => LifecycleTransaction.to_import()}
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
  @spec lifecycle_transactions([binary()]) :: [LifecycleTransaction.to_import()]
  def lifecycle_transactions(l1_transaction_hashes) do
    l1_transaction_hashes
    |> Reader.lifecycle_transactions()
    |> Enum.map(&lifecycle_transaction_to_map/1)
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
  @spec lifecycle_unfinalized_transactions(FullBlock.block_number()) :: [LifecycleTransaction.to_import()]
  def lifecycle_unfinalized_transactions(finalized_block)
      when is_integer(finalized_block) and finalized_block >= 0 do
    finalized_block
    |> Reader.lifecycle_unfinalized_transactions()
    |> Enum.map(&lifecycle_transaction_to_map/1)
  end

  @spec lifecycle_transaction_to_map(LifecycleTransaction.t()) :: LifecycleTransaction.to_import()
  defp lifecycle_transaction_to_map(transaction) do
    [:id, :hash, :block_number, :timestamp, :status]
    |> DbTools.db_record_to_map(transaction)
  end
end
