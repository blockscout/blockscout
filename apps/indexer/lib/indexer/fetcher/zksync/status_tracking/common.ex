defmodule Indexer.Fetcher.ZkSync.StatusTracking.CommonUtils do
  @moduledoc """
    Common functions for status changes trackers
  """

  alias Explorer.Chain.ZkSync.Reader
  alias Indexer.Fetcher.ZkSync.Utils.{Db, Rpc}
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

    status_changed_or_error =
      case Reader.batch(
             batch_number,
             necessity_by_association: %{
               get_association(tx_type) => :optional
             }
           ) do
        {:ok, batch_from_db} -> transactions_of_batch_changed?(batch_from_db, batch_from_rpc, tx_type)
        {:error, :not_found} -> :error
      end

    l1_tx = get_l1_tx_from_batch(batch_from_rpc, tx_type)

    if l1_tx.hash != Rpc.get_binary_zero_hash() and status_changed_or_error in [true, :error] do
      l1_txs = Db.get_indices_for_l1_transactions(%{l1_tx.hash => l1_tx})

      {:look_for_batches, l1_tx.hash, l1_txs}
    else
      {:skip, "", %{}}
    end
  end

  defp get_association(tx_type) do
    case tx_type do
      :commit_tx -> :commit_transaction
      :prove_tx -> :prove_transaction
      :execute_tx -> :execute_transaction
    end
  end

  defp transactions_of_batch_changed?(batch_db, batch_json, tx_type) do
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

    tx_hash_db_bytes =
      if is_nil(tx_hash_db) do
        Rpc.get_binary_zero_hash()
      else
        tx_hash_db.hash.bytes
      end

    tx_hash_json != tx_hash_db_bytes
  end

  defp get_l1_tx_from_batch(batch_from_rpc, tx_type) do
    case tx_type do
      :commit_tx -> %{hash: batch_from_rpc.commit_tx_hash, timestamp: batch_from_rpc.commit_timestamp}
      :prove_tx -> %{hash: batch_from_rpc.prove_tx_hash, timestamp: batch_from_rpc.prove_timestamp}
      :execute_tx -> %{hash: batch_from_rpc.executed_tx_hash, timestamp: batch_from_rpc.executed_timestamp}
    end
  end

  @doc """
    Receives batches from the database, establishes an association between each batch and
    the corresponding L1 transactions, and imports batches and L1 transactions into the database.
    If the number of batches returned from the database does not match the requested batches,
    the initial list of batch numbers is returned, assuming that they can be
    used for the missed batch recovery procedure.

    ## Parameters
    - `batches_numbers`: the list of batch numbers that must be updated.
    - `l1_txs`: a map containing transaction hashes as keys, and values are maps
      with transaction hashes and transaction timestamps of L1 transactions to import to the database.
    - `tx_hash`: the hash of the L1 transaction to build an association with.
    - `association_key`: the field in the batch description to build an association with L1
                         transactions.

    ## Returns
    - `:ok` if batches and the corresponding L1 transactions are imported successfully.
    - `{:recovery_required, batches_to_recover}` if the absence of batches is discovered;
      `batches_to_recover` contains the list of batch numbers.
  """
  @spec associate_and_import_or_prepare_for_recovery([integer()], map(), binary(), :commit_id | :execute_id | :prove_id) ::
          :ok | {:recovery_required, [integer()]}
  def associate_and_import_or_prepare_for_recovery(batches_numbers, l1_txs, tx_hash, association_key)
      when is_list(batches_numbers) and is_map(l1_txs) and is_binary(tx_hash) and
             association_key in [:commit_id, :prove_id, :execute_id] do
    case prepare_batches_to_import(batches_numbers, %{association_key => l1_txs[tx_hash][:id]}) do
      {:error, batches_to_recover} ->
        {:recovery_required, batches_to_recover}

      {:ok, batches_to_import} ->
        Db.import_to_db(batches_to_import, Map.values(l1_txs))
        :ok
    end
  end

  # Receives batches from the database and merges each batch's data with the data provided
  # in `map_to_update`. If the number of batches returned from the database does not match
  # with the requested batches, the initial list of batch numbers is returned, assuming that they
  # can be used for the missed batch recovery procedure.
  #
  # ## Parameters
  # - `batches`: the list of batch numbers that must be updated.
  # - `map_to_update`: a map containing new data that must be applied to all requested batches.
  #
  # ## Returns
  # - `{:ok, batches_to_import}` where `batches_to_import` is the list of batches ready to import
  #    with updated data.
  # - `{:error, batches}` where `batches` contains the input list of batch numbers.
  defp prepare_batches_to_import(batches, map_to_update) do
    batches_from_db = Reader.batches(batches, [])

    if length(batches_from_db) == length(batches) do
      batches_to_import =
        batches_from_db
        |> Enum.reduce([], fn batch, batches ->
          [
            batch
            |> Rpc.transform_transaction_batch_to_map()
            |> Map.merge(map_to_update)
            | batches
          ]
        end)

      {:ok, batches_to_import}
    else
      log_warning("Lack of batches received from DB to update")
      {:error, batches}
    end
  end
end
