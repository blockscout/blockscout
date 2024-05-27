defmodule Indexer.Fetcher.Arbitrum.DA.Celestia do
  @moduledoc """
    TBD
  """

  import Indexer.Fetcher.Arbitrum.Utils.Logging, only: [log_error: 1]

  alias Indexer.Fetcher.Arbitrum.Utils.Helper, as: ArbitrumHelper

  @enforce_keys [:batch_number, :height, :tx_commitment, :raw]
  defstruct @enforce_keys

  @typedoc """
  Celectia Blob pointer struct:
    * `batch_number` - The batch number in Arbitrum rollup associated with the Celestia data.
    * `height` - The height of the block in Celestia.
    * `tx_commitment` - Data commitment in Celestia.
    * `raw` - unparsed blob pointer data contaning data root, the proof etc.
  """
  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          height: non_neg_integer(),
          tx_commitment: binary(),
          raw: binary()
        }

  # Parses Celestia data from a given binary input, representing information required
  # to address a data blob and prove data availability.
  #
  # ## Parameters
  # - `batch_number`: The batch number in Arbitrum rollup associated with the Celestia data.
  # - A binary input representing the Celestia data blob information.
  #
  # ## Returns
  # - `{:ok, :in_celestia, celestia_da_info}` on successful parsing.
  # - `{:error, nil, nil}` if the input cannot be parsed.
  @spec parse_batch_accompanying_data(non_neg_integer(), binary()) :: {:ok, :in_celestia, t()} | {:error, nil, nil}
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

  @spec prepare_for_import(list(), t()) :: [
          %{
            :data_type => non_neg_integer(),
            :data_key => binary(),
            :data => %{:height => non_neg_integer(), :tx_commitment => String.t(), :raw => String.t()},
            :batch_number => non_neg_integer()
          }
        ]
  def prepare_for_import(source, %__MODULE__{} = da_info) do
    key = :crypto.hash(:sha256, :binary.encode_unsigned(da_info.height) <> da_info.tx_commitment)

    data = %{
      height: da_info.height,
      tx_commitment: ArbitrumHelper.bytes_to_hex_str(da_info.tx_commitment),
      raw: ArbitrumHelper.bytes_to_hex_str(da_info.raw)
    }

    [
      %{
        data_type: 0,
        data_key: key,
        data: data,
        batch_number: da_info.batch_number
      }
      | source
    ]
  end
end
