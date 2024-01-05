defmodule Indexer.Fetcher.ZkSync.StatusTracking.CommonUtils do
  @moduledoc """
    Common functions for status changes trackers
  """

  alias Explorer.Chain.ZkSync.Reader
  alias Indexer.Fetcher.ZkSync.Utils.Rpc
  alias Indexer.Fetcher.ZkSync.Utils.Db
  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_warning: 1]

  @doc """
    Fetches the details of the batch with the given number and checks if the representation of
    the same batch in the database refers to the same commitment, proving, or executing transaction
    depending on `tx_type`. If the transaction state changes, the new transaction is prepared for
    import to the database.

    ## Parameters
    - `batch_number`: the number of the batch to check L1 transaction state.
    - `tx_type`: a type of the transaction to check, one of :commit_tx, :execute_tx, or :prove_tx.
    - `json_l2_rpc_named_arguments`: parameters for the RPC connections.

    ## Returns
    - `{:look_for_batches, l1_tx_hash, l1_txs}` where
      - `l1_tx_hash` is the hash of the L1 transaction.
      - `l1_txs` is a map containing the transaction hash as a key, and values are maps
        with transaction hashes and transaction timestamps.
    - `{:skip, "", %{}}` means the batch is not found in the database or the state of the transaction
      in the batch representation is the same as the state of the transaction for the batch
      received from RPC.
  """
  @spec check_if_batch_status_changed(
          binary() | non_neg_integer(),
          :commit_tx | :execute_tx | :prove_tx,
          EthereumJSONRPC.json_rpc_named_arguments()
        ) :: {:look_for_batches, any(), any()} | {:skip, <<>>, %{}}
  def check_if_batch_status_changed(batch_number, tx_type, json_l2_rpc_named_arguments)
      when (is_binary(batch_number) or is_integer(batch_number)) and
             tx_type in [:commit_tx, :prove_tx, :execute_tx] and
             is_list(json_l2_rpc_named_arguments) do
    batch_from_rpc = Rpc.fetch_batch_details_by_batch_number(batch_number, json_l2_rpc_named_arguments)

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

  @doc """
    Receives batches from the database and merges each batch's data with the data provided
    in `map_to_update`. If the number of batches returned from the database does not match
    with the requested batches, the initial list of batch numbers is returned, assuming that they
    can be used for the missed batch recovery procedure.

    ## Parameters
    - `batches`: the list of batch numbers that must be updated.
    - `map_to_update`: a map containing new data that must be applied to all requested batches.

    ## Returns
    - `{:ok, batches_to_import}` where `batches_to_import` is the list of batches ready to import
       with updated data.
    - `{:error, batches}` where `batches` contains the input list of batch numbers.
  """
  @spec prepare_batches_to_import([integer()], map()) :: {:error, [integer()]} | {:ok, list()}
  def prepare_batches_to_import(batches, map_to_update)
      when is_list(batches) and is_map(map_to_update) do
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
