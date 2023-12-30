defmodule Indexer.Fetcher.ZkSync.StatusTracking.Proven do
  @moduledoc """
    Functionality to discover proven batches
  """

  alias ABI.{FunctionSelector, TypeDecoder}
  alias Indexer.Fetcher.ZkSync.Utils.Db
  alias Indexer.Fetcher.ZkSync.Utils.Rpc

  import Indexer.Fetcher.ZkSync.StatusTracking.CommonUtils,
    only: [
      check_if_batch_status_changed: 3,
      prepare_batches_to_import: 2
    ]

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_info: 1]

  def look_for_batches_and_update(config) do
    case Db.get_earliest_unproven_batch_number() do
      nil ->
        :ok

      expected_batch_number ->
        log_info("Checking if the batch #{expected_batch_number} was proven")

        {next_action, tx_hash, l1_txs} = check_if_batch_status_changed(expected_batch_number, :prove_tx, config)

        case next_action do
          :skip ->
            :ok

          :look_for_batches ->
            log_info("The batch #{expected_batch_number} looks like proven")
            prove_tx = Rpc.fetch_tx_by_hash(tx_hash, config.json_l1_rpc_named_arguments)
            batches_from_rpc = get_proven_batches_from_calldata(prove_tx["input"])

            case prepare_batches_to_import(batches_from_rpc, %{prove_id: l1_txs[tx_hash][:id]}) do
              {:error, batches_to_recover} ->
                {:recovery_required, batches_to_recover}

              {:ok, proven_batches} ->
                Db.import_to_db(proven_batches, Map.values(l1_txs))
                :ok
            end
        end
    end
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
    [_prevBatch, proven_batches, _proof] =
      TypeDecoder.decode(
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
            array:
              {:tuple,
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

    log_info("Discovered #{length(proven_batches)} proven batches in the prove tx")

    proven_batches
    |> Enum.map(fn batch_info -> elem(batch_info, 0) end)
  end
end
