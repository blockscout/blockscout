defmodule Indexer.Fetcher.Arbitrum.DA.Eigenda do
  @moduledoc """
    Provides functionality for parsing EigenDA data availability information
    associated with Arbitrum rollup batches.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1]

  alias ABI.{TypeDecoder, TypeEncoder}
  alias EthereumJSONRPC.Arbitrum.Constants.Contracts, as: ArbitrumContracts

  @enforce_keys [:batch_number, :blob_verification_proof, :blob_header]
  defstruct @enforce_keys

  @typedoc """
  EigenDA certificate struct:
    * `batch_number` - The batch number in the Arbitrum rollup associated with the
                       EigenDA certificate.
    * `blob_verification_proof` - The encoded binary data of the blob verification proof
                                  containing batchId, blobIndex, BatchMetadata, inclusionProof, and quorumIndices.
    * `blob_header` - The encoded binary data of the blob header containing commitment (BN254.G1Point),
                      dataLength, and quorumBlobParams array.
  """
  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          blob_verification_proof: binary(),
          blob_header: binary()
        }

  @doc """
    Parses the batch accompanying data for EigenDA.

    This function extracts EigenDA certificate information from the binary input
    associated with a given batch number by decoding the full EigenDACert structure,
    then encoding the BlobVerificationProof and BlobHeader components back to binary
    format for storage. The complex nested structures (BatchMetadata, BN254.G1Point,
    QuorumBlobParams, etc.) are preserved in their encoded binary form.

    ## Parameters
    - `batch_number`: The batch number in the Arbitrum rollup associated with the EigenDA data.
    - `binary_data`: The binary data containing the encoded EigenDA certificate.

    ## Returns
    - `{:ok, :in_eigenda, da_info}` if the data is successfully parsed.
    - `{:error, nil, nil}` if the data cannot be parsed.
  """
  @spec parse_batch_accompanying_data(non_neg_integer(), binary()) ::
          {:ok, :in_eigenda, __MODULE__.t()} | {:error, nil, nil}
  def parse_batch_accompanying_data(batch_number, binary_data) do
    # This function implements a decode->encode pattern that may seem redundant but is
    # architecturally necessary for the following reasons:
    #
    # 1. Data Validation: Decoding first ensures the EigenDA certificate is well-formed
    #    and contains valid data before storing it in the database.
    # 2. Interface Compatibility: The DA pipeline requires individual BlobVerificationProof
    #    and BlobHeader components as separate binary fields, not as a single combined structure.
    # 3. Library Reliability: Using TypeDecoder/TypeEncoder leverages battle-tested ABI
    #    handling instead of manual binary parsing, reducing the risk of encoding bugs.
    #
    # Alternative approaches (direct binary extraction) would require reimplementing
    # complex ABI parsing logic and handling dynamic arrays/nested structures manually,
    # introducing significant complexity and maintenance burden for minimal performance gain.

    # Decode the complex EigenDACert structure to get the tuple components
    [{blob_verification_proof_tuple, blob_header_tuple}] =
      TypeDecoder.decode(
        binary_data,
        ArbitrumContracts.eigen_da_cert_abi()
      )

    # Encode each component back to bytes for storage
    blob_verification_proof_bytes =
      TypeEncoder.encode([blob_verification_proof_tuple], ArbitrumContracts.eigen_da_blob_verification_proof_abi())

    blob_header_bytes =
      TypeEncoder.encode([blob_header_tuple], ArbitrumContracts.eigen_da_blob_header_abi())

    {:ok, :in_eigenda,
     %__MODULE__{
       batch_number: batch_number,
       blob_verification_proof: blob_verification_proof_bytes,
       blob_header: blob_header_bytes
     }}
  rescue
    exception ->
      log_error("Can not parse EigenDA certificate: #{inspect(exception)}")
      {:error, nil, nil}
  end
end
