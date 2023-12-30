defmodule Indexer.Fetcher.ZkSync.Utils.Db do
  @moduledoc """
    Common functions to simplify DB routines
  """

  alias Explorer.Chain
  alias Explorer.Chain.ZkSync.Reader
  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_warning: 1, log_info: 1]

  @json_batch_fields_absent_in_db_batch [
    :commit_tx_hash,
    :commit_timestamp,
    :prove_tx_hash,
    :prove_timestamp,
    :executed_tx_hash,
    :executed_timestamp
  ]

  def prune_json_batch(batch_with_json_fields) do
    Map.drop(batch_with_json_fields, @json_batch_fields_absent_in_db_batch)
  end

  def get_earliest_batch_number do
    case Reader.oldest_available_batch_number() do
      nil ->
        log_warning("No batches found in DB")
        nil

      value ->
        value
    end
  end

  def get_earliest_sealed_batch_number do
    case Reader.earliest_sealed_batch_number() do
      nil ->
        log_info("No committed batches found in DB")
        get_earliest_batch_number()

      value ->
        value
    end
  end

  def get_earliest_unproven_batch_number do
    case Reader.earliest_unproven_batch_number() do
      nil ->
        log_info("No proven batches found in DB")
        get_earliest_batch_number()

      value ->
        value
    end
  end

  def get_earliest_unexecuted_batch_number do
    case Reader.earliest_unexecuted_batch_number() do
      nil ->
        log_info("No executed batches found in DB")
        get_earliest_batch_number()

      value ->
        value
    end
  end

  def get_indices_for_l1_transactions(new_l1_txs) do
    # Get indices for l1 transactions previously handled
    l1_txs =
      Map.keys(new_l1_txs)
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
    {l1_txs, _} =
      Map.keys(l1_txs)
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

    l1_txs
  end

  def import_to_db(batches, l1_txs \\ [], l2_txs \\ [], l2_blocks \\ []) do
    {:ok, _} =
      Chain.import(%{
        zksync_lifecycle_transactions: %{params: l1_txs},
        zksync_transaction_batches: %{params: batches},
        zksync_batch_transactions: %{params: l2_txs},
        zksync_batch_blocks: %{params: l2_blocks},
        timeout: :infinity
      })
  end
end
