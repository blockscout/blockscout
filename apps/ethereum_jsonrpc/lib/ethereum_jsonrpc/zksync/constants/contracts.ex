defmodule EthereumJSONRPC.ZkSync.Constants.Contracts do
  @moduledoc """
  Provides constants and ABI definitions for zkSync-specific smart contracts.
  """

  # /// @notice Rollup batch stored data
  # /// @param batchNumber Rollup batch number
  # /// @param batchHash Hash of L2 batch
  # /// @param indexRepeatedStorageChanges The serial number of the shortcut index that's used as a unique identifier for storage keys that were used twice or more
  # /// @param numberOfLayer1Txs Number of priority operations to be processed
  # /// @param priorityOperationsHash Hash of all priority operations from this batch
  # /// @param l2LogsTreeRoot Root hash of tree that contains L2 -> L1 messages from this batch
  # /// @param timestamp Rollup batch timestamp, have the same format as Ethereum batch constant
  # /// @param commitment Verified input for the ZKsync circuit
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
  @stored_batch_info_tuple [
    # batchNumber
    uint: 64,
    # batchHash
    bytes: 32,
    # indexRepeatedStorageChanges
    uint: 64,
    # numberOfLayer1Txs
    uint: 256,
    # priorityOperationsHash
    bytes: 32,
    # l2LogsTreeRoot
    bytes: 32,
    # timestamp
    uint: 256,
    # commitment
    bytes: 32
  ]

  # /// @notice Recursive proof input data (individual commitments are constructed onchain)
  # struct ProofInput {
  #     uint256[] recursiveAggregationInput;
  #     uint256[] serializedProof;
  # }
  @proof_input_tuple [
    # recursiveAggregationInput
    array: {:uint, 256},
    # serializedProof
    array: {:uint, 256}
  ]

  @selector_prove_batches "7f61885c"
  @selector_prove_batches_shared_bridge_c37533bb "c37533bb"
  @selector_prove_batches_shared_bridge_e12a6137 "e12a6137"

  @doc """
    Returns selector of the `proveBatches` function
  """
  def prove_batches_selector, do: @selector_prove_batches

  @doc """
    Returns selector of the `proveBatchesSharedBridge` function
  """
  def prove_batches_shared_bridge_c37533bb_selector, do: @selector_prove_batches_shared_bridge_c37533bb

  @doc """
    Returns selector of the `proveBatchesSharedBridge` function with selector e12a6137
  """
  def prove_batches_shared_bridge_e12a6137_selector, do: @selector_prove_batches_shared_bridge_e12a6137

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      proveBatches(
        StoredBatchInfo calldata _prevBatch,
        StoredBatchInfo[] calldata _committedBatches,
        ProofInput calldata _proof
      )
  """
  def prove_batches_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "proveBatches",
      types: [
        {:tuple, @stored_batch_info_tuple},
        {:array, {:tuple, @stored_batch_info_tuple}},
        {:tuple, @proof_input_tuple}
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      proveBatchesSharedBridge(
        uint256 _chainId,
        StoredBatchInfo calldata _prevBatch,
        StoredBatchInfo[] calldata _committedBatches,
        ProofInput calldata _proof
      )
  """
  def prove_batches_shared_bridge_c37533bb_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "proveBatchesSharedBridge",
      types: [
        {:uint, 256},
        {:tuple, @stored_batch_info_tuple},
        {:array, {:tuple, @stored_batch_info_tuple}},
        {:tuple, @proof_input_tuple}
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      proveBatchesSharedBridge(
        uint256 _chainId,
        uint256 _processBatchFrom,
        uint256 _processBatchTo,
        bytes calldata _proofData
      )
  """
  def prove_batches_shared_bridge_e12a6137_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "proveBatchesSharedBridge",
      types: [
        # _chainId
        {:uint, 256},
        # _processBatchFrom
        {:uint, 256},
        # _processBatchTo
        {:uint, 256},
        # _proofData
        :bytes
      ]
    }
end
