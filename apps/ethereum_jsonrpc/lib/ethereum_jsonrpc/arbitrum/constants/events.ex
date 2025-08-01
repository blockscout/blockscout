defmodule EthereumJSONRPC.Arbitrum.Constants.Events do
  @moduledoc """
    Provides constant values for Arbitrum-specific event signatures and their parameter types.

    This module contains keccak256 hashes of event signatures and their corresponding unindexed
    parameter types for various Arbitrum protocol events, including:
    - L2ToL1Tx
    - NodeCreated
    - SetValidKeyset
    - SequencerBatchDelivered
    - SendRootUpdated
    - OutBoxTransactionExecuted
    - MessageDelivered

    Each event signature is stored as a 32-byte string and is accompanied by helper functions
    to access both the signature and, where applicable, the unindexed parameter types used
    in event decoding.
  """

  # keccak256("L2ToL1Tx(address,address,uint256,uint256,uint256,uint256,uint256,uint256,bytes)")
  @l2_to_l1 "0x3e7aafa77dbf186b7fd488006beff893744caa3c4f6f299e8a709fa2087374fc"
  @l2_to_l1_unindexed_params [
    :address,
    {:uint, 256},
    {:uint, 256},
    {:uint, 256},
    {:uint, 256},
    :bytes
  ]

  @doc """
    Returns 32-byte signature of the event `L2ToL1Tx`
  """
  @spec l2_to_l1() :: <<_::528>>
  def l2_to_l1, do: @l2_to_l1

  @spec l2_to_l1_unindexed_params() :: [atom() | {atom(), non_neg_integer()}]
  def l2_to_l1_unindexed_params, do: @l2_to_l1_unindexed_params

  # keccak256("NodeCreated(uint64,bytes32,bytes32,bytes32,(((bytes32[2],uint64[2]),uint8),((bytes32[2],uint64[2]),uint8),uint64),bytes32,bytes32,uint256)")
  @node_created "0x4f4caa9e67fb994e349dd35d1ad0ce23053d4323f83ce11dc817b5435031d096"
  @node_created_unindexed_params [
    {:bytes, 32},
    # Assertion assertion
    {:tuple,
     [
       # ExecutionState beforeState
       {:tuple,
        [
          # GlobalState globalState
          {:tuple,
           [
             # bytes32[2] bytes32Values
             {:array, {:bytes, 32}, 2},
             # uint64[2] u64Values
             {:array, {:uint, 64}, 2}
           ]},
          # MachineStatus machineStatus: enum MachineStatus {RUNNING, FINISHED, ERRORED, TOO_FAR}
          {:uint, 256}
        ]},
       # ExecutionState afterState
       {:tuple,
        [
          # GlobalState globalState
          {:tuple,
           [
             # bytes32[2] bytes32Values
             {:array, {:bytes, 32}, 2},
             # uint64[2] u64Values
             {:array, {:uint, 64}, 2}
           ]},
          # MachineStatus machineStatus: enum MachineStatus {RUNNING, FINISHED, ERRORED, TOO_FAR}
          {:uint, 256}
        ]},
       # uint64 numBlocks
       {:uint, 64}
     ]},
    {:bytes, 32},
    {:bytes, 32},
    {:uint, 256}
  ]

  @doc """
    Returns 32-byte signature of the event `NodeCreated`
  """
  @spec node_created() :: <<_::528>>
  def node_created, do: @node_created

  @spec node_created_unindexed_params() :: [atom() | {atom(), non_neg_integer()}]
  def node_created_unindexed_params, do: @node_created_unindexed_params

  # keccak256("SetValidKeyset(bytes32,bytes)")
  @set_valid_keyset "0xabca9b7986bc22ad0160eb0cb88ae75411eacfba4052af0b457a9335ef655722"
  @set_valid_keyset_unindexed_params [:bytes]

  @doc """
    Returns 32-byte signature of the event `SetValidKeyset`
  """
  @spec set_valid_keyset() :: <<_::528>>
  def set_valid_keyset, do: @set_valid_keyset

  @spec set_valid_keyset_unindexed_params() :: [atom() | {atom(), non_neg_integer()}]
  def set_valid_keyset_unindexed_params, do: @set_valid_keyset_unindexed_params

  # keccak256("SequencerBatchDelivered(uint256,bytes32,bytes32,bytes32,uint256,(uint64,uint64,uint64,uint64),uint8)")
  @sequencer_batch_delivered "0x7394f4a19a13c7b92b5bb71033245305946ef78452f7b4986ac1390b5df4ebd7"

  @doc """
    Returns 32-byte signature of the event `SequencerBatchDelivered`
  """
  @spec sequencer_batch_delivered() :: <<_::528>>
  def sequencer_batch_delivered, do: @sequencer_batch_delivered

  # keccak256("SendRootUpdated(bytes32,bytes32)")
  @send_root_updated "0xb4df3847300f076a369cd76d2314b470a1194d9e8a6bb97f1860aee88a5f6748"

  @doc """
    Returns 32-byte signature of the event `SendRootUpdated`
  """
  @spec send_root_updated() :: <<_::528>>
  def send_root_updated, do: @send_root_updated

  # keccak256("OutBoxTransactionExecuted(address,address,uint256,uint256)")
  @outbox_transaction_executed "0x20af7f3bbfe38132b8900ae295cd9c8d1914be7052d061a511f3f728dab18964"
  @outbox_transaction_executed_unindexed_params [{:uint, 256}]

  @doc """
    Returns 32-byte signature of the event `OutBoxTransactionExecuted`
  """
  @spec outbox_transaction_executed() :: <<_::528>>
  def outbox_transaction_executed, do: @outbox_transaction_executed

  @spec outbox_transaction_executed_unindexed_params() :: [atom() | {atom(), non_neg_integer()}]
  def outbox_transaction_executed_unindexed_params, do: @outbox_transaction_executed_unindexed_params

  # keccak256("MessageDelivered(uint256,bytes32,address,uint8,address,bytes32,uint256,uint64)")
  @message_delivered "0x5e3c1311ea442664e8b1611bfabef659120ea7a0a2cfc0667700bebc69cbffe1"
  @message_delivered_unindexed_params [
    :address,
    {:uint, 8},
    :address,
    {:bytes, 32},
    {:uint, 256},
    {:uint, 64}
  ]

  @doc """
    Returns 32-byte signature of the event `MessageDelivered`
  """
  @spec message_delivered() :: <<_::528>>
  def message_delivered, do: @message_delivered

  @spec message_delivered_unindexed_params() :: [atom() | {atom(), non_neg_integer()}]
  def message_delivered_unindexed_params, do: @message_delivered_unindexed_params
end
