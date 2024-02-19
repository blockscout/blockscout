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
  alias Explorer.Chain.Block, as: RollupBlock

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
  def l1_block_of_latest_committed_batch(value_if_nil) do
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
  def l1_block_of_latest_discovered_message_to_l2(value_if_nil) do
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
  #
  def rollup_blocks(list_of_block_nums) do
    query =
      from(
        block in RollupBlock,
        where: block.number in ^list_of_block_nums
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
  def transform_lifecycle_transaction_to_map(tx) do
    %{
      id: tx.id,
      hash: tx.hash.bytes,
      block: tx.block,
      timestamp: tx.timestamp,
      status: tx.status
    }
  end
end
