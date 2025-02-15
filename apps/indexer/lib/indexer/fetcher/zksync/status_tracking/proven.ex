defmodule Indexer.Fetcher.ZkSync.StatusTracking.Proven do
  @moduledoc """
    Functionality to discover proven batches
  """

  alias ABI.{FunctionSelector, TypeDecoder}
  alias Indexer.Fetcher.ZkSync.Utils.{Db, Rpc}

  import Indexer.Fetcher.ZkSync.StatusTracking.CommonUtils,
    only: [
      check_if_batch_status_changed: 3,
      associate_and_import_or_prepare_for_recovery: 4
    ]

  import Indexer.Fetcher.ZkSync.Utils.Logging, only: [log_error: 1, log_info: 1]

  @doc """
    Checks if the oldest unproven batch in the database has the associated L1 proving transaction
    by requesting new batch details from RPC. If so, analyzes the calldata of the transaction
    to explore all the batches proven by it. For all discovered batches, it updates
    the database with new associations, importing information about L1 transactions.
    If it is found that some of the discovered batches are absent in the database, the function
    interrupts and returns the list of batch numbers that can be attempted to be recovered.

    ## Parameters
    - `config`: Configuration containing `json_l1_rpc_named_arguments` and
                `json_l2_rpc_named_arguments` defining parameters for the RPC connections.

    ## Returns
    - `:ok` if no new proven batches are found, or if all found batches and the corresponding L1
      transactions are imported successfully.
    - `{:recovery_required, batches_to_recover}` if the absence of new proven batches is
      discovered; `batches_to_recover` contains the list of batch numbers.
  """
  @spec look_for_batches_and_update(%{
          :json_l1_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          :json_l2_rpc_named_arguments => EthereumJSONRPC.json_rpc_named_arguments(),
          optional(any()) => any()
        }) :: :ok | {:recovery_required, list()}
  def look_for_batches_and_update(
        %{
          json_l1_rpc_named_arguments: json_l1_rpc_named_arguments,
          json_l2_rpc_named_arguments: json_l2_rpc_named_arguments
        } = _config
      ) do
    case Db.get_earliest_unproven_batch_number() do
      nil ->
        :ok

      expected_batch_number ->
        log_info("Checking if the batch #{expected_batch_number} was proven")

        {next_action, transaction_hash, l1_transactions} =
          check_if_batch_status_changed(expected_batch_number, :prove_transaction, json_l2_rpc_named_arguments)

        case next_action do
          :skip ->
            :ok

          :look_for_batches ->
            log_info("The batch #{expected_batch_number} looks like proven")
            prove_transaction = Rpc.fetch_transaction_by_hash(transaction_hash, json_l1_rpc_named_arguments)
            batches_numbers_from_rpc = get_proven_batches_from_calldata(prove_transaction["input"])

            associate_and_import_or_prepare_for_recovery(
              batches_numbers_from_rpc,
              l1_transactions,
              transaction_hash,
              :prove_id
            )
        end
    end
  end

  defp get_proven_batches_from_calldata(calldata) do
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
    proven_batches =
      case calldata do
        "0x7f61885c" <> encoded_params ->
          # proveBatches(StoredBatchInfo calldata _prevBatch, StoredBatchInfo[] calldata _committedBatches, ProofInput calldata _proof)
          # IO.inspect(FunctionSelector.decode("proveBatches((uint64,bytes32,uint64,uint256,bytes32,bytes32,uint256,bytes32),(uint64,bytes32,uint64,uint256,bytes32,bytes32,uint256,bytes32)[],(uint256[],uint256[]))"))
          [_prev_batch, proven_batches, _proof] =
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

          proven_batches

        "0xc37533bb" <> encoded_params ->
          # proveBatchesSharedBridge(uint256 _chainId, StoredBatchInfo calldata _prevBatch, StoredBatchInfo[] calldata _committedBatches, ProofInput calldata _proof)
          # IO.inspect(FunctionSelector.decode("proveBatchesSharedBridge(uint256,(uint64,bytes32,uint64,uint256,bytes32,bytes32,uint256,bytes32),(uint64,bytes32,uint64,uint256,bytes32,bytes32,uint256,bytes32)[],(uint256[],uint256[]))"))
          [_chainid, _prev_batch, proven_batches, _proof] =
            TypeDecoder.decode(
              Base.decode16!(encoded_params, case: :lower),
              %FunctionSelector{
                function: "proveBatchesSharedBridge",
                types: [
                  {:uint, 256},
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

          proven_batches

        _ ->
          log_error("Unknown calldata format: #{calldata}")

          []
      end

    log_info("Discovered #{length(proven_batches)} proven batches in the prove transaction")

    proven_batches
    |> Enum.map(fn batch_info -> elem(batch_info, 0) end)
  end
end
