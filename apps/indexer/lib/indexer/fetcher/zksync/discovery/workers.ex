defmodule Indexer.Fetcher.ZkSync.Discovery.Workers do
  alias Indexer.Fetcher.ZkSync.Utils.Db

  import Indexer.Fetcher.ZkSync.Discovery.BatchesData,
    only: [
      collect_l1_transactions: 1,
      extract_data_from_batches: 2
    ]

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1]

  def get_full_batches_info_and_import(batches_numbers_list, config) do
    # Collect batches and linked L2 blocks and transaction
    {batches_to_import, l2_blocks_to_import, l2_txs_to_import} =
      extract_data_from_batches(
        batches_numbers_list,
        %{
          json_rpc_named_arguments: config.json_l2_rpc_named_arguments,
          chunk_size: config.chunk_size
        }
      )

    # Collect L1 transactions associated with batches
    l1_txs =
      collect_l1_transactions(batches_to_import)
      |> Db.get_indices_for_l1_transactions()

    # Update batches with l1 transactions indices and prune unnecessary fields
    batches_list_to_import =
      Map.values(batches_to_import)
      |> Enum.reduce([], fn batch, batches ->
        [
          batch
          |> Map.put(:commit_id, get_l1_tx_id_by_hash(l1_txs, batch.commit_tx_hash))
          |> Map.put(:prove_id, get_l1_tx_id_by_hash(l1_txs, batch.prove_tx_hash))
          |> Map.put(:execute_id, get_l1_tx_id_by_hash(l1_txs, batch.executed_tx_hash))
          |> Db.prune_json_batch()
          | batches
        ]
      end)

    Db.import_to_db(
      batches_list_to_import,
      Map.values(l1_txs),
      l2_txs_to_import,
      l2_blocks_to_import
    )
  end

  def batches_catchup(config) do
    oldest_batch_number = Db.get_earliest_batch_number()

    if not is_nil(oldest_batch_number) && oldest_batch_number > 0 do
      log_info("The oldest batch number is not zero. Historical baches will be fetched.")
      start_batch_number = max(0, oldest_batch_number - config.batches_max_range)
      end_batch_number = oldest_batch_number - 1

      start_batch_number..end_batch_number
      |> Enum.to_list()
      |> get_full_batches_info_and_import(config)
    end
  end

  defp get_l1_tx_id_by_hash(l1_txs, hash) do
    l1_txs
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
  end
end
