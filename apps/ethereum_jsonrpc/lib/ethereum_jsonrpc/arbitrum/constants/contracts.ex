defmodule EthereumJSONRPC.Arbitrum.Constants.Contracts do
  @moduledoc """
  Provides constants and ABI definitions for Arbitrum-specific smart contracts.

  This module contains function selectors, contract ABIs, and helper functions for
  interacting with core Arbitrum protocol contracts including:
  """

  # EigenDA type definitions - extracted for reusability
  @eigen_da_bn254_g1_point_type {:tuple,
   [
     # X
     {:uint, 256},
     # Y
     {:uint, 256}
   ]}

  @eigen_da_quorum_blob_param_type {:tuple,
   [
     # quorumNumber
     {:uint, 8},
     # adversaryThresholdPercentage
     {:uint, 8},
     # confirmationThresholdPercentage
     {:uint, 8},
     # chunkLength
     {:uint, 32}
   ]}

  @eigen_da_batch_header_type {:tuple,
   [
     # blobHeadersRoot
     {:bytes, 32},
     # quorumNumbers
     :bytes,
     # signedStakeForQuorums
     :bytes,
     # referenceBlockNumber
     {:uint, 32}
   ]}

  @eigen_da_batch_metadata_type {:tuple,
   [
     # BatchHeader
     @eigen_da_batch_header_type,
     # signatoryRecordHash
     {:bytes, 32},
     # confirmationBlockNumber
     {:uint, 32}
   ]}

  @eigen_da_blob_verification_proof_type {:tuple,
   [
     # batchId
     {:uint, 32},
     # blobIndex
     {:uint, 32},
     # BatchMetadata
     @eigen_da_batch_metadata_type,
     # inclusionProof
     :bytes,
     # quorumIndices
     :bytes
   ]}

  @eigen_da_blob_header_type {:tuple,
   [
     # BN254.G1Point commitment
     @eigen_da_bn254_g1_point_type,
     # dataLength
     {:uint, 32},
     # QuorumBlobParam[] quorumBlobParams
     {:array, @eigen_da_quorum_blob_param_type}
   ]}

  @eigen_da_cert_type {:tuple,
   [
     # BlobVerificationProof
     @eigen_da_blob_verification_proof_type,
     # BlobHeader
     @eigen_da_blob_header_type
   ]}

  @selector_outbox "ce11e6ab"
  @selector_sequencer_inbox "ee35f327"
  @selector_bridge "e78cea92"

  @doc """
    Returns selector of the `outbox()` function
  """
  @spec outbox_selector() :: <<_::64>>
  def outbox_selector, do: @selector_outbox

  @doc """
    Returns selector of the `sequencerInbox()` function
  """
  @spec sequencer_inbox_selector() :: <<_::64>>
  def sequencer_inbox_selector, do: @selector_sequencer_inbox

  @doc """
    Returns selector of the `bridge()` function
  """
  @spec bridge_selector() :: <<_::64>>
  def bridge_selector, do: @selector_bridge

  @doc """
    Returns atomized selector of Rollup contract method

    ## Parameters
    - `selector`: The selector of the Rollup contract method

    ## Returns
    - One of the following atoms: `:outbox`, `:sequencer_inbox`, `:bridge`
  """
  @spec atomized_rollup_contract_selector(<<_::64>>) :: atom()
  def atomized_rollup_contract_selector(@selector_outbox), do: :outbox
  def atomized_rollup_contract_selector(@selector_sequencer_inbox), do: :sequencer_inbox
  def atomized_rollup_contract_selector(@selector_bridge), do: :bridge

  @doc """
    Returns selector of the `latestConfirmed()` function
  """
  @spec latest_confirmed_selector() :: <<_::64>>
  def latest_confirmed_selector, do: "65f7f80d"

  @doc """
    Returns selector of the `getNode(uint64 nodeNum)` function
  """
  @spec get_node_selector() :: <<_::64>>
  def get_node_selector, do: "92c8134c"

  @doc """
    Returns ABI of the rollup contract
  """
  @spec rollup_contract_abi() :: [map()]
  def rollup_contract_abi,
    do: [
      %{
        "inputs" => [],
        "name" => "outbox",
        "outputs" => [
          %{
            "internalType" => "address",
            "name" => "",
            "type" => "address"
          }
        ],
        "stateMutability" => "view",
        "type" => "function"
      },
      %{
        "inputs" => [],
        "name" => "sequencerInbox",
        "outputs" => [
          %{
            "internalType" => "address",
            "name" => "",
            "type" => "address"
          }
        ],
        "stateMutability" => "view",
        "type" => "function"
      },
      %{
        "inputs" => [],
        "name" => "bridge",
        "outputs" => [
          %{
            "internalType" => "address",
            "name" => "",
            "type" => "address"
          }
        ],
        "stateMutability" => "view",
        "type" => "function"
      },
      %{
        "inputs" => [],
        "name" => "latestConfirmed",
        "outputs" => [
          %{
            "internalType" => "uint64",
            "name" => "",
            "type" => "uint64"
          }
        ],
        "stateMutability" => "view",
        "type" => "function"
      },
      %{
        "inputs" => [
          %{
            "internalType" => "uint64",
            "name" => "",
            "type" => "uint64"
          }
        ],
        "name" => "getNode",
        "outputs" => [
          %{
            "type" => "tuple",
            "name" => "",
            "internalType" => "struct Node",
            "components" => [
              %{"type" => "bytes32", "name" => "stateHash", "internalType" => "bytes32"},
              %{"type" => "bytes32", "name" => "challengeHash", "internalType" => "bytes32"},
              %{"type" => "bytes32", "name" => "confirmData", "internalType" => "bytes32"},
              %{"type" => "uint64", "name" => "prevNum", "internalType" => "uint64"},
              %{"type" => "uint64", "name" => "deadlineBlock", "internalType" => "uint64"},
              %{"type" => "uint64", "name" => "noChildConfirmedBeforeBlock", "internalType" => "uint64"},
              %{"type" => "uint64", "name" => "stakerCount", "internalType" => "uint64"},
              %{"type" => "uint64", "name" => "childStakerCount", "internalType" => "uint64"},
              %{"type" => "uint64", "name" => "firstChildBlock", "internalType" => "uint64"},
              %{"type" => "uint64", "name" => "latestChildNumber", "internalType" => "uint64"},
              %{"type" => "uint64", "name" => "createdAtBlock", "internalType" => "uint64"},
              %{"type" => "bytes32", "name" => "nodeHash", "internalType" => "bytes32"}
            ]
          }
        ],
        "stateMutability" => "view",
        "type" => "function"
      }
    ]

  @doc """
    Returns address of precompile NodeInterface precompile on Arbitrum chain
  """
  @spec node_interface_contract_address() :: <<_::336>>
  def node_interface_contract_address, do: "0x00000000000000000000000000000000000000c8"

  @doc """
    Returns selector of the `constructOutboxProof(uint64 size, uint64 leaf)` function
  """
  @spec construct_outbox_proof_selector() :: <<_::64>>
  def construct_outbox_proof_selector, do: "42696350"

  @doc """
    Returns selector of the `findBatchContainingBlock(uint64 blockNum)` function
  """
  @spec find_batch_containing_block_selector() :: <<_::64>>
  def find_batch_containing_block_selector, do: "81f1adaf"

  @doc """
    Returns ABI of the node interface contract
  """
  @spec node_interface_contract_abi() :: [map()]
  def node_interface_contract_abi,
    do: [
      %{
        "inputs" => [
          %{
            "internalType" => "uint64",
            "name" => "size",
            "type" => "uint64"
          },
          %{
            "internalType" => "uint64",
            "name" => "leaf",
            "type" => "uint64"
          }
        ],
        "name" => "constructOutboxProof",
        "outputs" => [
          %{
            "internalType" => "bytes32",
            "name" => "send",
            "type" => "bytes32"
          },
          %{
            "internalType" => "bytes32",
            "name" => "root",
            "type" => "bytes32"
          },
          %{
            "internalType" => "bytes32[]",
            "name" => "proof",
            "type" => "bytes32[]"
          }
        ],
        "stateMutability" => "view",
        "type" => "function"
      },
      %{
        "inputs" => [
          %{
            "internalType" => "uint64",
            "name" => "blockNum",
            "type" => "uint64"
          }
        ],
        "name" => "findBatchContainingBlock",
        "outputs" => [
          %{
            "internalType" => "uint64",
            "name" => "batch",
            "type" => "uint64"
          }
        ],
        "stateMutability" => "view",
        "type" => "function"
      }
    ]

  @doc """
    Returns selector of the `isSpent(uint256 index)` function
  """
  @spec is_spent_selector() :: <<_::64>>
  def is_spent_selector, do: "5a129efe"
  # credo:disable-for-previous-line Credo.Check.Readability.PredicateFunctionNames

  @doc """
    Returns ABI of the outbox contract
  """
  @spec outbox_contract_abi() :: [map()]
  def outbox_contract_abi,
    do: [
      %{
        "inputs" => [
          %{
            "internalType" => "uint256",
            "name" => "index",
            "type" => "uint256"
          }
        ],
        "name" => "isSpent",
        "outputs" => [
          %{
            "internalType" => "bool",
            "name" => "",
            "type" => "bool"
          }
        ],
        "stateMutability" => "view",
        "type" => "function"
      }
    ]

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the `finalizeInboundTransfer(...)` function
  """
  def finalize_inbound_transfer_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "finalizeInboundTransfer",
      returns: [],
      types: [
        # _token
        :address,
        # _from
        :address,
        # _to
        :address,
        # _amount
        {:uint, 256},
        # data
        :bytes
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the `executeTransaction(...)` function
  """
  def execute_transaction_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "executeTransaction",
      returns: [],
      types: [
        # proof
        {:array, {:bytes, 32}},
        # index
        {:uint, 256},
        # l2Sender
        :address,
        # to
        :address,
        # l2Block
        {:uint, 256},
        # l1Block
        {:uint, 256},
        # l2Timestamp
        {:uint, 256},
        # value
        {:uint, 256},
        # data
        :bytes
      ],
      type: :function,
      inputs_indexed: []
    }

  @doc """
    Returns selector of the `getKeysetCreationBlock(bytes32 ksHash)` function
  """
  @spec get_keyset_creation_block_selector() :: <<_::64>>
  def get_keyset_creation_block_selector, do: "258f0495"

  @doc """
    Returns ABI of the sequencer inbox contract
  """
  @spec sequencer_inbox_contract_abi() :: [map()]
  def sequencer_inbox_contract_abi,
    do: [
      %{
        "inputs" => [%{"internalType" => "bytes32", "name" => "ksHash", "type" => "bytes32"}],
        "name" => "getKeysetCreationBlock",
        "outputs" => [%{"internalType" => "uint256", "name" => "", "type" => "uint256"}],
        "stateMutability" => "view",
        "type" => "function"
      }
    ]

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      addSequencerL2BatchFromBlobs(
        uint256 sequenceNumber,
        uint256 afterDelayedMessagesRead,
        address gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount
      )
  """
  def add_sequencer_l2_batch_from_blobs_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "addSequencerL2BatchFromBlobs",
      types: [
        {:uint, 256},
        {:uint, 256},
        :address,
        {:uint, 256},
        {:uint, 256}
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      addSequencerL2BatchFromOrigin(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        address gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount
      )
  """
  def add_sequencer_l2_batch_from_origin_8f111f3c_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "addSequencerL2BatchFromOrigin",
      types: [
        {:uint, 256},
        :bytes,
        {:uint, 256},
        :address,
        {:uint, 256},
        {:uint, 256}
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      addSequencerL2BatchFromOrigin(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        address gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount,
        bytes quote
      )
  """
  def add_sequencer_l2_batch_from_origin_37501551_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "addSequencerL2BatchFromOrigin",
      types: [
        {:uint, 256},
        :bytes,
        {:uint, 256},
        :address,
        {:uint, 256},
        {:uint, 256},
        :bytes
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      addSequencerL2BatchFromOrigin(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        address gasRefunder
      )
  """
  def add_sequencer_l2_batch_from_origin_6f12b0c9_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "addSequencerL2BatchFromOrigin",
      types: [
        {:uint, 256},
        :bytes,
        {:uint, 256},
        :address
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      addSequencerL2BatchFromBlobsDelayProof(
        uint256 sequenceNumber,
        uint256 afterDelayedMessagesRead,
        address gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount,
        DelayProof calldata delayProof
      )
  """
  def add_sequencer_l2_batch_from_blobs_delay_proof_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "addSequencerL2BatchFromBlobsDelayProof",
      types: [
        {:uint, 256},
        {:uint, 256},
        :address,
        {:uint, 256},
        {:uint, 256},
        {:tuple,
         [
           {:bytes, 32},
           {:tuple,
            [
              {:uint, 8},
              :address,
              {:uint, 64},
              {:uint, 64},
              {:uint, 256},
              {:uint, 256},
              {:bytes, 32}
            ]}
         ]}
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      addSequencerL2BatchFromOriginDelayProof(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        address gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount,
        DelayProof calldata delayProof
      )
  """
  def add_sequencer_l2_batch_from_origin_delay_proof_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "addSequencerL2BatchFromOriginDelayProof",
      types: [
        {:uint, 256},
        :bytes,
        {:uint, 256},
        :address,
        {:uint, 256},
        {:uint, 256},
        {:tuple,
         [
           {:bytes, 32},
           {:tuple,
            [
              {:uint, 8},
              :address,
              {:uint, 64},
              {:uint, 64},
              {:uint, 256},
              {:uint, 256},
              {:bytes, 32}
            ]}
         ]}
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      addSequencerL2BatchDelayProof(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        address gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount,
        DelayProof calldata delayProof
      )
  """
  def add_sequencer_l2_batch_delay_proof_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "addSequencerL2BatchDelayProof",
      types: [
        {:uint, 256},
        :bytes,
        {:uint, 256},
        :address,
        {:uint, 256},
        {:uint, 256},
        {:tuple,
         [
           {:bytes, 32},
           {:tuple,
            [
              {:uint, 8},
              :address,
              {:uint, 64},
              {:uint, 64},
              {:uint, 256},
              {:uint, 256},
              {:bytes, 32}
            ]}
         ]}
      ]
    }

  @doc """
    Returns selector with ABI (object of `ABI.FunctionSelector`) of the function:

      addSequencerL2BatchFromEigenDA(
        uint256 sequenceNumber,
        EigenDACert calldata cert,
        IGasRefunder gasRefunder,
        uint256 afterDelayedMessagesRead,
        uint256 prevMessageCount,
        uint256 newMessageCount
      )
  """
  def add_sequencer_l2_batch_from_eigen_da_selector_with_abi,
    do: %ABI.FunctionSelector{
      function: "addSequencerL2BatchFromEigenDA",
      types: [
        {:uint, 256},
        # EigenDACert structure
        @eigen_da_cert_type,
        :address,
        {:uint, 256},
        {:uint, 256},
        {:uint, 256}
      ]
    }

  @doc """
    Returns ABI definition for EigenDACert structure for encoding purposes.

    The EigenDACert contains BlobVerificationProof and BlobHeader with full nested structures.
  """
  def eigen_da_cert_abi,
    do: %ABI.FunctionSelector{
      function: nil,
      types: [
        # EigenDACert structure
        @eigen_da_cert_type
      ]
    }

  @doc """
    Returns ABI definition for BlobVerificationProof structure for encoding purposes.

    The BlobVerificationProof contains batchId, blobIndex, BatchMetadata, inclusionProof, and quorumIndices.
  """
  def eigen_da_blob_verification_proof_abi,
    # https://github.com/Layr-Labs/eigenda/blob/6c1deb51fced68efb1aaa585dd5ddb6a27f88637/contracts/src/core/libraries/v1/EigenDATypesV1.sol#L36-L55
    do: %ABI.FunctionSelector{
      function: nil,
      types: [
        # BlobVerificationProof
        @eigen_da_blob_verification_proof_type
      ]
    }

  @doc """
    Returns ABI definition for BlobHeader structure for encoding purposes.

    The BlobHeader contains BN254.G1Point commitment, dataLength, and quorumBlobParams array.
  """
  def eigen_da_blob_header_abi,
    # https://github.com/Layr-Labs/eigenda/blob/6c1deb51fced68efb1aaa585dd5ddb6a27f88637/contracts/src/core/libraries/v1/EigenDATypesV1.sol#L18-L29
    do: %ABI.FunctionSelector{
      function: nil,
      types: [
        # BlobHeader
        @eigen_da_blob_header_type
      ]
    }
end
