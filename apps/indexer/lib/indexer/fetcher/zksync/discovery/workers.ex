defmodule Indexer.Fetcher.ZkSync.Discovery.Workers do
  @moduledoc """
    Provides functions to download a set of batches from RPC and import them to DB.
  """

  alias Indexer.Fetcher.ZkSync.Utils.Db
  alias Indexer.Prometheus.Instrumenter

  import Indexer.Fetcher.ZkSync.Discovery.BatchesData,
    only: [
      collect_l1_transactions: 1,
      extract_data_from_batches: 2
    ]

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1]

  @doc """
    Downloads minimal batches data (batch, associated rollup blocks and transactions hashes) from RPC
    and imports them to the DB. Data is retrieved from the RPC endpoint in chunks of `chunk_size`.
    Import of associated L1 transactions does not happen, assuming that the batch import happens regularly
    enough and last downloaded batches does not contain L1 associations anyway.
    Later `Indexer.Fetcher.ZkSync.BatchesStatusTracker` will update any batch state changes and
    import required L1 transactions.

    ## Parameters
    - `start_batch_number`: The first batch in the range to download.
    - `end_batch_number`: The last batch in the range to download.
    - `config`: Configuration containing `chunk_size` to limit the amount of data requested from the RPC endpoint,
                and `json_rpc_named_arguments` defining parameters for the RPC connection.

    ## Returns
    - `:ok`
  """
  @spec get_minimal_batches_info_and_import(non_neg_integer(), non_neg_integer(), %{
          :chunk_size => integer(),
          :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          optional(any()) => any()
        }) :: :ok
  def get_minimal_batches_info_and_import(start_batch_number, end_batch_number, config)
      when is_integer(start_batch_number) and
             is_integer(end_batch_number) and
             (is_map(config) and is_map_key(config, :json_rpc_named_arguments) and
                is_map_key(config, :chunk_size)) do
    {batches_to_import, l2_blocks_to_import, l2_transactions_to_import} =
      extract_data_from_batches({start_batch_number, end_batch_number}, config)

    batches_list_to_import =
      batches_to_import
      |> Map.values()
      |> Enum.reduce([], fn batch, batches_list ->
        [Db.prune_json_batch(batch) | batches_list]
      end)

    Db.import_to_db(
      batches_list_to_import,
      [],
      l2_transactions_to_import,
      l2_blocks_to_import
    )

    last_batch =
      batches_list_to_import
      |> Enum.max_by(& &1.number, fn -> nil end)

    # credo:disable-for-next-line
    if last_batch do
      Instrumenter.set_latest_batch(last_batch.number, last_batch.timestamp)
    end

    :ok
  end

  @doc """
    Downloads batches, associates L1 transactions, rollup blocks and transactions with the given list of batch numbers,
    and imports the results into the database. Data is retrieved from the RPC endpoint in chunks of `chunk_size`.

    ## Parameters
    - `batches_numbers_list`: List of batch numbers to be retrieved.
    - `config`: Configuration containing `chunk_size` to limit the amount of data requested from the RPC endpoint,
                and `json_rpc_named_arguments` defining parameters for the RPC connection.

    ## Returns
    - `:ok`
  """
  @spec get_full_batches_info_and_import([integer()], %{
          :chunk_size => integer(),
          :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          optional(any()) => any()
        }) :: :ok
  def get_full_batches_info_and_import(batches_numbers_list, config)
      when is_list(batches_numbers_list) and
             (is_map(config) and is_map_key(config, :json_rpc_named_arguments) and
                is_map_key(config, :chunk_size)) do
    # Collect batches and linked L2 blocks and transaction
    {batches_to_import, l2_blocks_to_import, l2_transactions_to_import} =
      extract_data_from_batches(batches_numbers_list, config)

    # Collect L1 transactions associated with batches
    l1_transactions =
      batches_to_import
      |> Map.values()
      |> collect_l1_transactions()
      |> Db.get_indices_for_l1_transactions()

    # Update batches with l1 transactions indices and prune unnecessary fields
    batches_list_to_import =
      batches_to_import
      |> Map.values()
      |> Enum.reduce([], fn batch, batches ->
        [
          batch
          |> Map.put(:commit_id, get_l1_transaction_id_by_hash(l1_transactions, batch.commit_transaction_hash))
          |> Map.put(:prove_id, get_l1_transaction_id_by_hash(l1_transactions, batch.prove_transaction_hash))
          |> Map.put(:execute_id, get_l1_transaction_id_by_hash(l1_transactions, batch.executed_transaction_hash))
          |> Db.prune_json_batch()
          | batches
        ]
      end)

    Db.import_to_db(
      batches_list_to_import,
      Map.values(l1_transactions),
      l2_transactions_to_import,
      l2_blocks_to_import
    )

    :ok
  end

  @doc """
    Retrieves the minimal batch number from the database. If the minimum batch number is not zero,
    downloads `batches_max_range` batches older than the retrieved batch, along with associated
    L1 transactions, rollup blocks, and transactions, and imports everything to the database.

    ## Parameters
    - `config`: Configuration containing `chunk_size` to limit the amount of data requested from
                the RPC endpoint and `json_rpc_named_arguments` defining parameters for the
                RPC connection, `batches_max_range` defines how many of older batches must be downloaded.

    ## Returns
    - `:ok`
  """
  @spec batches_catchup(%{
          :batches_max_range => integer(),
          :chunk_size => integer(),
          :json_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          optional(any()) => any()
        }) :: :ok
  def batches_catchup(config)
      when is_map(config) and is_map_key(config, :json_rpc_named_arguments) and
             is_map_key(config, :batches_max_range) and
             is_map_key(config, :chunk_size) do
    oldest_batch_number = Db.get_earliest_batch_number()

    if not is_nil(oldest_batch_number) && oldest_batch_number > 0 do
      log_info("The oldest batch number is not zero. Historical baches will be fetched.")
      start_batch_number = max(0, oldest_batch_number - config.batches_max_range)
      end_batch_number = oldest_batch_number - 1

      start_batch_number..end_batch_number
      |> Enum.to_list()
      |> get_full_batches_info_and_import(config)
    end

    :ok
  end

  defp get_l1_transaction_id_by_hash(l1_transactions, hash) do
    l1_transactions
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
  end
end
