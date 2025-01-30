defmodule Indexer.Fetcher.Arbitrum.DA.Celestia do
  @moduledoc """
    Provides functionality for parsing and preparing Celestia data availability
    information associated with Arbitrum rollup batches.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1]
  import Explorer.Chain.Arbitrum.DaMultiPurposeRecord.Helper, only: [calculate_celestia_data_key: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  alias Explorer.Chain.Arbitrum

  @enforce_keys [:batch_number, :height, :transaction_commitment, :raw]
  defstruct @enforce_keys

  @typedoc """
  Celestia Blob Pointer struct:
    * `batch_number` - The batch number in Arbitrum rollup associated with the
                       Celestia data.
    * `height` - The height of the block in Celestia.
    * `transaction_commitment` - Data commitment in Celestia.
    * `raw` - Unparsed blob pointer data containing data root, proof, etc.
  """
  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          height: non_neg_integer(),
          transaction_commitment: binary(),
          raw: binary()
        }

  @typedoc """
  Celestia Blob Descriptor struct:
    * `height` - The height of the block in Celestia.
    * `transaction_commitment` - Data commitment in Celestia.
    * `raw` - Unparsed blob pointer data containing data root, proof, etc.
  """
  @type blob_descriptor :: %{
          :height => non_neg_integer(),
          :transaction_commitment => String.t(),
          :raw => String.t()
        }

  @doc """
    Parses the batch accompanying data for Celestia.

    This function extracts Celestia blob descriptor information, representing
    information required to address a data blob and prove data availability,
    from a binary input associated with a given batch number.

    ## Parameters
    - `batch_number`: The batch number in the Arbitrum rollup associated with the Celestia data.
    - `binary`: A binary input containing the Celestia blob descriptor data.

    ## Returns
    - `{:ok, :in_celestia, da_info}` if the data is successfully parsed.
    - `{:error, nil, nil}` if the data cannot be parsed.
  """
  @spec parse_batch_accompanying_data(non_neg_integer(), binary()) ::
          {:ok, :in_celestia, __MODULE__.t()} | {:error, nil, nil}
  def parse_batch_accompanying_data(
        batch_number,
        <<
          height::big-unsigned-integer-size(64),
          _start_index::binary-size(8),
          _shares_length::binary-size(8),
          transaction_commitment::binary-size(32),
          _data_root::binary-size(32),
          _rest::binary
        >> = raw
      ) do
    # https://github.com/celestiaorg/nitro-das-celestia/blob/7baf95c5bf1ece467abbbab911db7ed9c7cc6967/das/types.go#L19-L42
    {:ok, :in_celestia,
     %__MODULE__{batch_number: batch_number, height: height, transaction_commitment: transaction_commitment, raw: raw}}
  end

  def parse_batch_accompanying_data(_, _) do
    log_error("Can not parse Celestia DA message.")
    {:error, nil, nil}
  end

  @doc """
    Prepares Celestia Blob data for import.

    ## Parameters
    - A tuple containing:
      - A list of DA records.
      - A list of Batch-to-DA-record associations.
    - `da_info`: The Celestia blob descriptor struct containing details about the data blob.

    ## Returns
    - A tuple containing:
      - An updated list of `DaMultiPurposeRecord` structures ready for import in the DB.
      - An updated list of `BatchToDaBlob` structures ready for import in the DB.
  """
  @spec prepare_for_import(
          {[Arbitrum.DaMultiPurposeRecord.to_import()], [Arbitrum.BatchToDaBlob.to_import()]},
          __MODULE__.t()
        ) ::
          {[Arbitrum.DaMultiPurposeRecord.to_import()], [Arbitrum.BatchToDaBlob.to_import()]}
  def prepare_for_import({da_records_acc, batch_to_blob_acc}, %__MODULE__{} = da_info) do
    data = %{
      height: da_info.height,
      transaction_commitment: ArbitrumHelper.bytes_to_hex_str(da_info.transaction_commitment),
      raw: ArbitrumHelper.bytes_to_hex_str(da_info.raw)
    }

    data_key = calculate_celestia_data_key(da_info.height, da_info.transaction_commitment)

    # Create record for arbitrum_da_multi_purpose table with batch_number set to nil
    da_record = %{
      data_type: 0,
      data_key: data_key,
      data: data,
      # This field must be removed as soon as migration to a separate table for Batch-to-DA-record associations is completed.
      batch_number: nil
    }

    # Create record for arbitrum_batches_to_da_blobs table
    batch_to_blob_record = %{
      batch_number: da_info.batch_number,
      data_blob_id: data_key
    }

    {[da_record | da_records_acc], [batch_to_blob_record | batch_to_blob_acc]}
  end
end
