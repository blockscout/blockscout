defmodule Indexer.Fetcher.ZkSync.BatchesStatusTracker do
  @moduledoc """
    Updates batches statuses and receives historical batches
  """

  use GenServer
  use Indexer.Fetcher

  require Logger

  alias Explorer.Chain
  alias Explorer.Chain.ZkSync.Reader
  alias Indexer.Fetcher.ZkSync.Helper
  alias Indexer.Fetcher.ZkSync.TransactionBatch
  import Indexer.Fetcher.ZkSync.Helper, only: [log_info: 1]

  alias ABI.{
    FunctionSelector,
    TypeDecoder
  }

  # keccak256("BlockCommit(uint256,bytes32,bytes32)")
  @block_commit_event "0x8f2916b2f2d78cc5890ead36c06c0f6d5d112c7e103589947e8e2f0d6eddb763"

  # keccak256("BlockExecution(uint256,bytes32,bytes32)")
  @block_execution_event "0x2402307311a4d6604e4e7b4c8a15a7e1213edb39c16a31efa70afb06030d3165"

  @json_fields_to_exclude [:commit_tx_hash, :commit_timestamp, :prove_tx_hash, :prove_timestamp, :executed_tx_hash, :executed_timestamp]

  def child_spec(start_link_arguments) do
    spec = %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, start_link_arguments},
      restart: :transient,
      type: :worker
    }

    Supervisor.child_spec(spec, [])
  end

  def start_link(args, gen_server_options \\ []) do
    GenServer.start_link(__MODULE__, args, Keyword.put_new(gen_server_options, :name, __MODULE__))
  end

  @impl GenServer
  def init(args) do
    Logger.metadata(fetcher: :zksync_batches_tracker)

    config_tracker = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.BatchesStatusTracker]
    l1_rpc = config_tracker[:zksync_l1_rpc]
    recheck_interval = config_tracker[:recheck_interval]
    config_fetcher = Application.get_all_env(:indexer)[Indexer.Fetcher.ZkSync.TransactionBatch]
    chunk_size = config_fetcher[:chunk_size]
    batches_max_range = config_fetcher[:batches_max_range]

    Process.send(self(), :continue, [])

    {:ok,
     %{
       json_l2_rpc_named_arguments: args[:json_rpc_named_arguments],
       json_l1_rpc_named_arguments: [
         transport: EthereumJSONRPC.HTTP,
         transport_options: [
           http: EthereumJSONRPC.HTTP.HTTPoison,
           url: l1_rpc,
           http_options: [
             recv_timeout: :timer.minutes(10),
             timeout: :timer.minutes(10),
             hackney: [pool: :ethereum_jsonrpc]
           ]
         ]
       ],
       recheck_interval: recheck_interval,
       chunk_size: chunk_size,
       batches_max_range: batches_max_range
     }}
  end

  @impl GenServer
  def handle_info(
        :continue,
        %{
          json_l2_rpc_named_arguments: json_l2_rpc_named_arguments,
          json_l1_rpc_named_arguments: json_l1_rpc_named_arguments,
          recheck_interval: recheck_interval,
          chunk_size: chunk_size,
          batches_max_range: batches_max_range
        } = state
      ) do
    {handle_duration, _} =
      :timer.tc(fn ->
        update_batches_statuses(%{
          json_l2_rpc_named_arguments: json_l2_rpc_named_arguments,
          json_l1_rpc_named_arguments: json_l1_rpc_named_arguments,
          chunk_size: chunk_size,
          batches_max_range: batches_max_range
        })
      end)

    Process.send_after(self(), :continue, max(:timer.seconds(recheck_interval) - div(handle_duration, 1000), 0))

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({ref, _result}, state) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  defp update_batches_statuses(config) do
    {committed_batches, l1_txs} = look_for_committed_batches_and_update(%{}, config)

    {proven_batches, l1_txs} = look_for_proven_batches_and_update(l1_txs, config)

    batches_to_import =
      committed_batches
      |> Map.merge(proven_batches, fn _key, committed_batch, proven_batch ->
        Map.put(committed_batch, :prove_id, proven_batch.prove_id)
      end)

    {executed_batches, l1_txs} = look_for_executed_batches_and_update(l1_txs, config)

    batches_to_import =
      batches_to_import
      |> Map.merge(executed_batches, fn _key, updated_batch, executed_batch ->
        Map.put(updated_batch, :execute_id, executed_batch.execute_id)
      end)

    # In order to avoid conflicts with indexing L1 transactions the process of discovering
    # historical batches is combined with the process of the batches tracking
    {historical_batches, l1_txs, l2_blocks_to_import, l2_txs_to_import} =
      batches_catchup(l1_txs, config)

    batches_to_import = Map.merge(batches_to_import, historical_batches)

    {:ok, _} =
      Chain.import(%{
        zksync_lifecycle_transactions: %{params: Map.values(l1_txs)},
        zksync_transaction_batches: %{params: Map.values(batches_to_import)},
        zksync_batch_transactions: %{params: l2_txs_to_import},
        zksync_batch_blocks: %{params: l2_blocks_to_import},
        timeout: :infinity
      })
  end

  defp batches_catchup(current_l1_txs, config) do
    oldest_batch_number = get_earliest_batch_number()
    if (not is_nil(oldest_batch_number)) && (oldest_batch_number > 0) do
      log_info("The oldest batch number is not zero. Historical baches will be fetched.")
      start_batch_number = max(0, oldest_batch_number - config.batches_max_range)
      end_batch_number = oldest_batch_number - 1

      start_batch_number..end_batch_number
      |> Enum.to_list()
      |> get_full_info_for_batches_list(current_l1_txs, config)
    else
      {%{}, current_l1_txs, [], []}
    end
  end

  defp look_for_committed_batches_and_update(current_l1_txs, config) do
    expected_committed_batch_number = get_earliest_sealed_batch_number()
    if not is_nil(expected_committed_batch_number) do
      log_info("Checking if the batch #{expected_committed_batch_number} was committed")
      batch_from_rpc = Helper.fetch_batch_details_by_batch_number(expected_committed_batch_number, config.json_l2_rpc_named_arguments)

      committed_batch_found =
        case Reader.batch(
          expected_committed_batch_number,
          necessity_by_association: %{
            :commit_transaction => :optional
          }
        ) do
          {:ok, batch_from_db} -> is_transactions_of_batch_changed(batch_from_db, batch_from_rpc, :commit_tx)
          {:error, :not_found} -> true
        end

      if not is_nil(batch_from_rpc.commit_tx_hash) and committed_batch_found do
        log_info("The batch #{expected_committed_batch_number} looks like committed")
        l1_transaction = batch_from_rpc.commit_tx_hash
        l1_txs =
          %{
            l1_transaction => %{
              hash: l1_transaction,
              timestamp: batch_from_rpc.commit_timestamp
            }
          }
          |> get_indices_for_l1_transactions(current_l1_txs)
        hash = "0x" <> Base.encode16(l1_transaction)
        commit_tx_receipt = Helper.fetch_tx_receipt_by_hash(hash, config.json_l1_rpc_named_arguments)
        committed_batches =
          get_committed_batches_from_logs(commit_tx_receipt["logs"])
          |> Reader.batches([])
          # TODO: handle the case when some batches don't exist in DB
          |> Enum.reduce(%{}, fn batch, committed_batches ->
            Map.put(
              committed_batches,
              batch.number,
              Helper.transform_transaction_batch_to_map(batch)
                |> Map.put(:commit_id, l1_txs[l1_transaction][:id])
            )
          end)
        { committed_batches, l1_txs }
      else
        { %{}, current_l1_txs }
      end
    else
      { %{}, current_l1_txs }
    end
  end

  defp look_for_proven_batches_and_update(current_l1_txs, config) do
    expected_proven_batch_number = get_earliest_unproven_batch_number()
    if not is_nil(expected_proven_batch_number) do
      log_info("Checking if the batch #{expected_proven_batch_number} was proven")
      batch_from_rpc = Helper.fetch_batch_details_by_batch_number(expected_proven_batch_number, config.json_l2_rpc_named_arguments)

      proven_batch_found =
        case Reader.batch(
          expected_proven_batch_number,
          necessity_by_association: %{
            :prove_transaction => :optional
          }
        ) do
          {:ok, batch_from_db} -> is_transactions_of_batch_changed(batch_from_db, batch_from_rpc, :prove_tx)
          {:error, :not_found} -> true
        end

      if not is_nil(batch_from_rpc.prove_tx_hash) and proven_batch_found do
        log_info("The batch #{expected_proven_batch_number} looks like proven")
        l1_transaction = batch_from_rpc.prove_tx_hash
        l1_txs =
          %{
            l1_transaction => %{
              hash: l1_transaction,
              timestamp: batch_from_rpc.prove_timestamp
            }
          }
          |> get_indices_for_l1_transactions(current_l1_txs)
        hash = "0x" <> Base.encode16(l1_transaction)
        prove_tx = Helper.fetch_tx_by_hash(hash, config.json_l1_rpc_named_arguments)
        proven_batches =
          get_proven_batches_from_calldata(prove_tx["input"])
          |> Enum.map(fn batch_info -> elem(batch_info, 0) end)
          |> Reader.batches([])
          # TODO: handle the case when some batches don't exist in DB
          |> Enum.reduce(%{}, fn batch, proven_batches ->
            Map.put(
              proven_batches,
              batch.number,
              Helper.transform_transaction_batch_to_map(batch)
                |> Map.put(:prove_id, l1_txs[l1_transaction][:id])
            )
          end)
        { proven_batches, l1_txs }
      else
        { %{}, current_l1_txs }
      end
    else
      { %{}, current_l1_txs }
    end
  end

  defp look_for_executed_batches_and_update(current_l1_txs, config) do
    expected_executed_batch_number = get_earliest_unexecuted_batch_number()
    if not is_nil(expected_executed_batch_number) do
      log_info("Checking if the batch #{expected_executed_batch_number} was executed")
      batch_from_rpc = Helper.fetch_batch_details_by_batch_number(expected_executed_batch_number, config.json_l2_rpc_named_arguments)

      executed_batch_found =
        case Reader.batch(
          expected_executed_batch_number,
          necessity_by_association: %{
            :execute_transaction => :optional
          }
        ) do
          {:ok, batch_from_db} -> is_transactions_of_batch_changed(batch_from_db, batch_from_rpc, :execute_tx)
          {:error, :not_found} -> true
        end

      if not is_nil(batch_from_rpc.executed_tx_hash) and executed_batch_found do
        log_info("The batch #{expected_executed_batch_number} looks like executed")
        l1_transaction = batch_from_rpc.executed_tx_hash
        l1_txs =
          %{
            l1_transaction => %{
              hash: l1_transaction,
              timestamp: batch_from_rpc.executed_timestamp
            }
          }
          |> get_indices_for_l1_transactions(current_l1_txs)
        hash = "0x" <> Base.encode16(l1_transaction)
        execute_tx_receipt = Helper.fetch_tx_receipt_by_hash(hash, config.json_l1_rpc_named_arguments)
        executed_batches =
          get_executed_batches_from_logs(execute_tx_receipt["logs"])
          |> Reader.batches([])
          # TODO: handle the case when some batches don't exist in DB
          |> Enum.reduce(%{}, fn batch, executed_batches ->
            Map.put(
              executed_batches,
              batch.number,
              Helper.transform_transaction_batch_to_map(batch)
                |> Map.put(:execute_id, l1_txs[l1_transaction][:id])
            )
          end)
        { executed_batches, l1_txs }
      else
        { %{}, current_l1_txs }
      end
    else
      { %{}, current_l1_txs }
    end
  end

  defp get_full_info_for_batches_list(batches_list, current_l1_txs, config) do
    # Collect batches and linked L2 blocks and transaction
    {batches_to_import, l2_blocks_to_import, l2_txs_to_import} =
      TransactionBatch.extract_data_for_batch_range(
        batches_list,
        %{
          json_rpc_named_arguments: config.json_l2_rpc_named_arguments,
          chunk_size: config.chunk_size
        }
      )

    # Collect L1 transactions associated with batches
    new_l1_txs =
      collect_l1_transactions(batches_to_import)
      |> get_indices_for_l1_transactions(current_l1_txs)

    # Update batches with l1 transactions indices and prune unnecessary fields
    batches_list_to_import =
      Map.values(batches_to_import)
      |> Enum.reduce(%{}, fn batch, batches ->
        batch =
          batch
            |> Map.put(:commit_id, get_l1_tx_id_by_hash(new_l1_txs, batch.commit_tx_hash))
            |> Map.put(:prove_id, get_l1_tx_id_by_hash(new_l1_txs, batch.prove_tx_hash))
            |> Map.put(:execute_id, get_l1_tx_id_by_hash(new_l1_txs, batch.executed_tx_hash))
            |> Map.drop(@json_fields_to_exclude)
        Map.put(batches, batch.number, batch)
      end)

    {batches_list_to_import, new_l1_txs, l2_blocks_to_import, l2_txs_to_import}
  end

  defp collect_l1_transactions(batches) do
    l1_txs = Map.values(batches)
    |> Enum.reduce(%{}, fn batch, l1_txs ->
      [%{hash: batch.commit_tx_hash, ts: batch.commit_timestamp},
        %{hash: batch.prove_tx_hash, ts: batch.prove_timestamp},
        %{hash: batch.executed_tx_hash, ts: batch.executed_timestamp}
      ]
      |> Enum.reduce(l1_txs, fn l1_tx, acc ->
        if l1_tx.hash != Helper.get_binary_zero_hash() do
          Map.put(acc, l1_tx.hash, %{hash: l1_tx.hash, timestamp: l1_tx.ts})
        else
          acc
        end
      end)
    end)

    log_info("Collected #{length(Map.keys(l1_txs))} L1 hashes")

    l1_txs
  end

  defp get_indices_for_l1_transactions(new_l1_txs, current_l1_txs) do
    # Get indices for l1 transactions previously handled
    l1_txs =
      Map.keys(new_l1_txs)
      |> Reader.lifecycle_transactions()
      |> Enum.reduce(new_l1_txs, fn {hash, id}, txs ->
        {_, txs} = Map.get_and_update!(txs, hash.bytes, fn l1_tx ->
          {l1_tx, Map.put(l1_tx, :id, id)}
        end)
        txs
      end)

    # Choose the next index for the first new transaction taking
    # into account the indices already used in this iteration of
    # the l1 transactions table update
    l1_tx_next_id =
      Map.values(current_l1_txs)
      |> Enum.reduce(Reader.next_id(), fn tx, next_id ->
        max(next_id, tx.id + 1)
      end)

    # Assign new indices for the transactions which are not in
    # the l1 transactions table yet
    { l1_txs, _ } =
      Map.keys(l1_txs)
      |> Enum.reduce({Map.merge(l1_txs, current_l1_txs), l1_tx_next_id},
                     fn hash, {txs, next_id} = _acc ->
        tx = txs[hash]
        id = Map.get(tx, :id)
        if is_nil(id) do
          {Map.put(txs, hash, Map.put(tx, :id, next_id)), next_id + 1}
        else
          {txs, next_id}
        end
      end)

    l1_txs
  end

  defp get_l1_tx_id_by_hash(l1_txs, hash) do
    l1_txs
    |> Map.get(hash)
    |> Kernel.||(%{id: nil})
    |> Map.get(:id)
  end

  defp get_earliest_batch_number do
    case Reader.oldest_available_batch_number() do
      nil -> log_info("No batches found in DB")
             nil
      value -> value
    end
  end

  defp get_earliest_sealed_batch_number do
    case Reader.earliest_sealed_batch_number() do
      nil -> log_info("No committed batches found in DB")
             get_earliest_batch_number()
      value -> value
    end
  end

  defp get_earliest_unproven_batch_number do
    case Reader.earliest_unproven_batch_number() do
      nil -> log_info("No proven batches found in DB")
             get_earliest_batch_number()
      value -> value
    end
  end

  defp get_earliest_unexecuted_batch_number do
    case Reader.earliest_unexecuted_batch_number() do
      nil -> log_info("No executed batches found in DB")
             get_earliest_batch_number()
      value -> value
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
        Helper.get_binary_zero_hash()
      else
        tx_hash_db.hash.bytes
      end
    tx_hash_json != tx_hash_db
  end

  defp get_proven_batches_from_calldata(calldata) do
    "0x7f61885c" <> encoded_params = calldata

    # /// @param batchNumber Rollup batch number
    # /// @param batchHash Hash of L2 batch
    # /// @param indexRepeatedStorageChanges The serial number of the shortcut index that's used as a unique identifier for storage keys that were used twice or more
    # /// @param numberOfLayer1Txs Number of priority operations to be processed
    # /// @param priorityOperationsHash Hash of all priority operations from this batch
    # /// @param l2LogsTreeRoot Root hash of tree that contains L2 -> L1 messages from this batch
    # /// @param timestamp Rollup batch timestamp, have the same format as Ethereum batch constant
    # /// @param commitment Verified input for the zkSync circuit
    # struct StoredBatchInfo {
    #     uint64 batchNumber;
    #     bytes32 batchHash;
    #     uint64 indexRepeatedStorageChanges;
    #     uint256 numberOfLayer1Txs;
    #     bytes32 priorityOperationsHash;
    #     bytes32 l2LogsTreeRoot;
    #     uint256 timestamp;
    #     bytes32 commitment;
    # }
    # /// @notice Recursive proof input data (individual commitments are constructed onchain)
    # struct ProofInput {
    #     uint256[] recursiveAggregationInput;
    #     uint256[] serializedProof;
    # }
    # proveBatches(StoredBatchInfo calldata _prevBatch, StoredBatchInfo[] calldata _committedBatches, ProofInput calldata _proof)

    # IO.inspect(FunctionSelector.decode("proveBatches((uint64,bytes32,uint64,uint256,bytes32,bytes32,uint256,bytes32),(uint64,bytes32,uint64,uint256,bytes32,bytes32,uint256,bytes32)[],(uint256[],uint256[]))"))
    [_prevBatch, committed_batches, _proof] = TypeDecoder.decode(
      Base.decode16!(encoded_params, case: :lower),
      %FunctionSelector{
        function: "proveBatches",
        types: [
          tuple: [
            uint: 64,
            bytes: 32,
            uint: 64,
            uint: 256,
            bytes: 32,
            bytes: 32,
            uint: 256,
            bytes: 32
          ],
          array: {:tuple,
           [
             uint: 64,
             bytes: 32,
             uint: 64,
             uint: 256,
             bytes: 32,
             bytes: 32,
             uint: 256,
             bytes: 32
           ]},
          tuple: [array: {:uint, 256}, array: {:uint, 256}]
        ]
      }
    )

    log_info("Discovered #{length(committed_batches)} proven batches in the prove tx")

    committed_batches
  end

  defp get_committed_batches_from_logs(logs) do
    committed_batches = Helper.filter_logs_and_extract_topic_at(logs, @block_commit_event, 1)
    log_info("Discovered #{length(committed_batches)} committed batches in the commitment tx")

    committed_batches
  end

  defp get_executed_batches_from_logs(logs) do
    executed_batches = Helper.filter_logs_and_extract_topic_at(logs, @block_execution_event, 1)
    log_info("Discovered #{length(executed_batches)} executed batches in the executing tx")

    executed_batches
  end

end
