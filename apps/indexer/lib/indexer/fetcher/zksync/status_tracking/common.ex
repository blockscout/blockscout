defmodule Indexer.Fetcher.ZkSync.StatusTracking.CommonUtils do
  @moduledoc """
    Common functions for status changes trackers
  """

  alias Explorer.Chain.ZkSync.Reader
  alias Indexer.Fetcher.ZkSync.Utils.Rpc
  alias Indexer.Fetcher.ZkSync.Utils.Db
  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_warning: 1]

  def check_if_batch_status_changed(batch_number, tx_type, config) do
    batch_from_rpc = Rpc.fetch_batch_details_by_batch_number(batch_number, config.json_l2_rpc_named_arguments)

    association_tx =
      case tx_type do
        :commit_tx -> :commit_transaction
        :prove_tx -> :prove_transaction
        :execute_tx -> :execute_transaction
      end

    status_changed_or_error =
      case Reader.batch(
             batch_number,
             necessity_by_association: %{
               association_tx => :optional
             }
           ) do
        {:ok, batch_from_db} -> is_transactions_of_batch_changed(batch_from_db, batch_from_rpc, tx_type)
        {:error, :not_found} -> :error
      end

    l1_tx =
      case tx_type do
        :commit_tx -> %{hash: batch_from_rpc.commit_tx_hash, timestamp: batch_from_rpc.commit_timestamp}
        :prove_tx -> %{hash: batch_from_rpc.prove_tx_hash, timestamp: batch_from_rpc.prove_timestamp}
        :execute_tx -> %{hash: batch_from_rpc.executed_tx_hash, timestamp: batch_from_rpc.executed_timestamp}
      end

    if l1_tx.hash != Rpc.get_binary_zero_hash() and status_changed_or_error in [true, :error] do
      l1_txs =
        %{l1_tx.hash => l1_tx}
        |> Db.get_indices_for_l1_transactions()

      {:look_for_batches, l1_tx.hash, l1_txs}
    else
      {:skip, "", %{}}
    end
  end

  defp is_transactions_of_batch_changed(batch_db, batch_json, tx_type) do
    tx_hash_json =
      case tx_type do
        :commit_tx -> batch_json.commit_tx_hash
        :prove_tx -> batch_json.prove_tx_hash
        :execute_tx -> batch_json.executed_tx_hash
      end

    tx_hash_db =
      case tx_type do
        :commit_tx -> batch_db.commit_transaction
        :prove_tx -> batch_db.prove_transaction
        :execute_tx -> batch_db.execute_transaction
      end

    tx_hash_db =
      if is_nil(tx_hash_db) do
        Rpc.get_binary_zero_hash()
      else
        tx_hash_db.hash.bytes
      end

    tx_hash_json != tx_hash_db
  end

  def prepare_batches_to_import(batches, map_to_update) do
    batches_from_db = Reader.batches(batches, [])

    if length(batches_from_db) == length(batches) do
      batches_to_import =
        batches_from_db
        |> Enum.reduce([], fn batch, batches ->
          [
            Rpc.transform_transaction_batch_to_map(batch)
            |> Map.merge(map_to_update)
            | batches
          ]
        end)

      {:ok, batches_to_import}
    else
      log_warning("Lack of batches recived from DB to update")
      {:error, batches}
    end
  end
end
