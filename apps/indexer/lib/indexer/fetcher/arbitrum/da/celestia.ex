defmodule Indexer.Fetcher.Arbitrum.DA.Celestia do
  @moduledoc """
    Provides functionality for parsing and preparing Celestia data availability
    information associated with Arbitrum rollup batches.
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1]
  import Explorer.Chain.Arbitrum.DaMultiPurposeRecord.Helper, only: [calculate_celestia_data_key: 2]

  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  alias Explorer.Chain.Arbitrum

  @enforce_keys [:batch_number, :height, :tx_commitment, :raw]
  defstruct @enforce_keys

  @typedoc """
  Celestia Blob Pointer struct:
    * `batch_number` - The batch number in Arbitrum rollup associated with the
                       Celestia data.
    * `height` - The height of the block in Celestia.
    * `tx_commitment` - Data commitment in Celestia.
    * `raw` - Unparsed blob pointer data containing data root, proof, etc.
  """
  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          height: non_neg_integer(),
          tx_commitment: binary(),
          raw: binary()
        }

  @typedoc """
  Celestia Blob Descriptor struct:
    * `height` - The height of the block in Celestia.
    * `tx_commitment` - Data commitment in Celestia.
    * `raw` - Unparsed blob pointer data containing data root, proof, etc.
  """
  @type blob_descriptor :: %{
          :height => non_neg_integer(),
          :tx_commitment => String.t(),
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
          _key::big-unsigned-integer-size(64),
          _num_leaves::big-unsigned-integer-size(64),
          _tuple_root_nonce::big-unsigned-integer-size(64),
          tx_commitment::binary-size(32),
          _data_root::binary-size(32),
          _side_nodes_length::big-unsigned-integer-size(64),
          _rest::binary
        >> = raw
      ) do
    # https://github.com/celestiaorg/nitro-contracts/blob/celestia/blobstream/src/bridge/SequencerInbox.sol#L334-L360
    {:ok, :in_celestia, %__MODULE__{batch_number: batch_number, height: height, tx_commitment: tx_commitment, raw: raw}}
  end

  def parse_batch_accompanying_data(_, _) do
    log_error("Can not parse Celestia DA message.")
    {:error, nil, nil}
  end

  @doc """
    Prepares Celestia Blob data for import.

    ## Parameters
    - `source`: The initial list of data to be imported.
    - `da_info`: The Celestia blob descriptor struct containing details about the data blob.

    ## Returns
    - An updated list of data structures ready for import, including the Celestia blob descriptor.
  """
  @spec prepare_for_import(list(), __MODULE__.t()) :: [Arbitrum.DaMultiPurposeRecord.to_import()]
  def prepare_for_import(source, %__MODULE__{} = da_info) do
    data = %{
      height: da_info.height,
      tx_commitment: ArbitrumHelper.bytes_to_hex_str(da_info.tx_commitment),
      raw: ArbitrumHelper.bytes_to_hex_str(da_info.raw)
    }

    [
      %{
        data_type: 0,
        data_key: calculate_celestia_data_key(da_info.height, da_info.tx_commitment),
        data: data,
        batch_number: da_info.batch_number
      }
      | source
    ]
  end
end
