defmodule Indexer.Fetcher.Arbitrum.DA.Eigenda do
  @moduledoc """
    Provides functionality for parsing EigenDA data availability information
    associated with Arbitrum rollup batches.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1, log_info: 1]
  import Explorer.Chain.Arbitrum.DaMultiPurposeRecord.Helper, only: [calculate_eigenda_data_key: 1]

  alias ABI.{TypeDecoder, TypeEncoder}
  alias EthereumJSONRPC.Arbitrum.Constants.Contracts, as: ArbitrumContracts
  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  alias Explorer.Chain.Arbitrum

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

  @doc """
    Prepares EigenDA certificate data for import.

    ## Parameters
    - A tuple containing:
      - A map of already prepared DA records
      - A list of already prepared batch-to-blob associations
    - `da_info`: The EigenDA certificate struct containing blob header and verification proof.

    ## Returns
    - A tuple containing:
      - An updated map of `DaMultiPurposeRecord` structures ready for import in the DB,
        where `data_key` maps to the record
      - An updated list of `BatchToDaBlob` structures ready for import in the DB.
  """
  @spec prepare_for_import(
          {%{binary() => Arbitrum.DaMultiPurposeRecord.to_import()}, [Arbitrum.BatchToDaBlob.to_import()]},
          __MODULE__.t()
        ) ::
          {%{binary() => Arbitrum.DaMultiPurposeRecord.to_import()}, [Arbitrum.BatchToDaBlob.to_import()]}
  def prepare_for_import({da_records_acc, batch_to_blob_acc}, %__MODULE__{} = da_info) do
    blob_header_hex = ArbitrumHelper.bytes_to_hex_str(da_info.blob_header)
    blob_verification_proof_hex = ArbitrumHelper.bytes_to_hex_str(da_info.blob_verification_proof)

    data = %{
      blob_header: blob_header_hex,
      blob_verification_proof: blob_verification_proof_hex
    }

    data_key = calculate_eigenda_data_key(da_info.blob_header)

    # Create record for arbitrum_da_multi_purpose table with batch_number set to nil
    da_record = %{
      data_type: 0,
      data_key: data_key,
      data: data,
      # TODO: This field must be removed as soon as migration to a separate table for Batch-to-DA-record associations is completed.
      batch_number: nil
    }

    # Create record for arbitrum_batches_to_da_blobs table
    batch_to_blob_record = %{
      batch_number: da_info.batch_number,
      data_blob_id: data_key
    }

    # Only add the DA record if it doesn't already exist in the map
    updated_da_records =
      if Map.has_key?(da_records_acc, data_key) do
        log_info("Found duplicate DA record #{ArbitrumHelper.bytes_to_hex_str(data_key)}")
        # Record with this data_key already exists, keep existing record
        da_records_acc
      else
        # No duplicate, add the new record
        Map.put(da_records_acc, data_key, da_record)
      end

    {updated_da_records, [batch_to_blob_record | batch_to_blob_acc]}
  end

  @doc """
    Resolves conflicts between existing database records and candidate DA records.

    This function handles deduplication by comparing EigenDA data keys between database
    records and candidate records. For EigenDA records, if a record with a matching data_key
    already exists in the database, the candidate record is excluded from import.

    ## Parameters
    - `db_records`: A list of `Arbitrum.DaMultiPurposeRecord` retrieved from the database
    - `candidate_records`: A map where `data_key` maps to `Arbitrum.DaMultiPurposeRecord.to_import()`

    ## Returns
    - A list of `Arbitrum.DaMultiPurposeRecord.to_import()` after resolving conflicts
  """
  @spec resolve_conflict(
          [Arbitrum.DaMultiPurposeRecord.t()],
          %{binary() => Arbitrum.DaMultiPurposeRecord.to_import()}
        ) :: [Arbitrum.DaMultiPurposeRecord.to_import()]
  # When no database records to check against, simply return all candidate records
  def resolve_conflict([], candidate_records) do
    Map.values(candidate_records)
  end

  def resolve_conflict(db_records, candidate_records) do
    # Create a set of keys to exclude (those already present in DB)
    keys_to_exclude =
      Enum.reduce(db_records, MapSet.new(), fn db_record, acc ->
        # Any key present in both DB and candidates should be excluded
        if Map.has_key?(candidate_records, db_record.data_key) do
          log_info("DA record #{ArbitrumHelper.bytes_to_hex_str(db_record.data_key)} already exists in DB")

          MapSet.put(acc, db_record.data_key)
        else
          acc
        end
      end)

    # Return only candidate records not in the exclude set
    candidate_records
    |> Enum.reject(fn {data_key, _record} -> MapSet.member?(keys_to_exclude, data_key) end)
    |> Enum.map(fn {_data_key, record} -> record end)
  end
end
