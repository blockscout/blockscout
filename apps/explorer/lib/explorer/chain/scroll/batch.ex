defmodule Explorer.Chain.Scroll.Batch do
  @moduledoc """
    Models a batch for Scroll.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Scroll.Batches

    Migrations:
    - Explorer.Repo.Scroll.Migrations.AddBatchesTables
  """

  use Explorer.Schema

  require Logger

  alias Explorer.Chain.Block.Range, as: BlockRange
  alias Explorer.Chain.Hash
  alias Explorer.Chain.Scroll.BatchBundle

  @optional_attrs ~w(bundle_id l2_block_range)a

  @required_attrs ~w(number commit_transaction_hash commit_block_number commit_timestamp container)a
  @zstd_magic_number <<0x28, 0xB5, 0x2F, 0xFD>>
  @codec_version 7

  @typedoc """
    Descriptor of the batch:
    * `number` - A unique batch number.
    * `commit_transaction_hash` - A hash of the commit transaction on L1.
    * `commit_block_number` - A block number of the commit transaction on L1.
    * `commit_timestamp` - A timestamp of the commit block.
    * `l2_block_range` - A range of L2 blocks included into the batch.
    * `container` - A container where the batch info is mostly located (can be :in_calldata, :in_blob4844).
  """
  @type to_import :: %{
          number: non_neg_integer(),
          commit_transaction_hash: binary(),
          commit_block_number: non_neg_integer(),
          commit_timestamp: DateTime.t(),
          l2_block_range: BlockRange.t() | nil,
          container: :in_calldata | :in_blob4844
        }

  @typedoc """
    * `number` - A unique batch number.
    * `commit_transaction_hash` - A hash of the commit transaction on L1.
    * `commit_block_number` - A block number of the commit transaction on L1.
    * `commit_timestamp` - A timestamp of the commit block.
    * `bundle_id` - An identifier of the batch bundle from the `scroll_batch_bundles` database table.
    * `l2_block_range` - A range of L2 blocks included into the batch. Can be `nil` if cannot be determined.
    * `container` - A container where the batch info is mostly located (can be :in_calldata, :in_blob4844).
  """
  @primary_key false
  typed_schema "scroll_batches" do
    field(:number, :integer, primary_key: true)
    field(:commit_transaction_hash, Hash.Full)
    field(:commit_block_number, :integer)
    field(:commit_timestamp, :utc_datetime_usec)

    belongs_to(:bundle, BatchBundle,
      foreign_key: :bundle_id,
      references: :id,
      type: :integer,
      null: true
    )

    field(:l2_block_range, BlockRange, null: true)
    field(:container, Ecto.Enum, values: [:in_blob4844, :in_calldata])

    timestamps()
  end

  @doc """
    Checks that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:number)
    |> foreign_key_constraint(:bundle_id)
  end

  @doc """
    Decodes EIP-4844 blob to the raw data. Returns `nil` if the blob is invalid.

    ## Parameters
    - `blob`: The canonical bytes of the blob. Its size must be 128 Kb.

    ## Returns
    - The raw data decoded from the blob.
    - `nil` if the blob is invalid (cannot be decoded).
  """
  @spec decode_eip4844_blob(binary()) :: binary() | nil
  def decode_eip4844_blob(blob) when byte_size(blob) == 131_072 do
    blob_data_raw =
      blob
      |> chunk_eip4844_blob([])
      |> Enum.map(fn <<_first_byte, rest::binary-size(31)>> -> rest end)
      |> :erlang.iolist_to_binary()

    <<version, blob_payload_size::size(24), is_compressed::size(8), rest::binary>> = blob_data_raw

    # ensure we have correct version, blob envelope size doesn't exceed the raw data size, and compression flag is correct
    with {:version_is_supported, true} <- {:version_is_supported, version == @codec_version},
         {:size_is_correct, true} <- {:size_is_correct, blob_payload_size + 5 <= byte_size(blob_data_raw)},
         {:compression_flag_is_correct, true} <-
           {:compression_flag_is_correct, is_compressed in [0, 1]},
         <<payload::binary-size(blob_payload_size), _::binary>> = rest,
         {:is_compressed, 1, _payload} <- {:is_compressed, is_compressed, payload},
         decompressed when is_binary(decompressed) <- :ezstd.decompress(@zstd_magic_number <> payload) do
      decompressed
    else
      {:version_is_supported, false} ->
        Logger.error("Codec version #{version} is not supported. Expected: #{@codec_version}.")
        nil

      {:size_is_correct, false} ->
        Logger.error("Blob envelope size #{blob_payload_size} exceeds the raw data size (#{blob_data_raw}).")
        nil

      {:compression_flag_is_correct, false} ->
        Logger.error("Invalid compressed flag: #{is_compressed}")
        nil

      {:is_compressed, 0, payload} ->
        payload

      {:error, reason} ->
        Logger.error("Failed to decompress blob payload: #{inspect(reason)}")
        nil
    end
  end

  def decode_eip4844_blob(_), do: nil

  # Divides the blob data by 32-byte chunks and returns them as a list.
  #
  # ## Parameters
  # - `_blob`: The blob bytes. The blob size must be divisible by 32.
  #
  # ## Returns
  # - A list of 32-byte chunks.
  @spec chunk_eip4844_blob(binary(), list()) :: list()
  defp chunk_eip4844_blob(<<chunk::binary-size(32), rest::binary>> = blob, acc) when rem(byte_size(blob), 32) == 0 do
    chunk_eip4844_blob(rest, [chunk | acc])
  end

  defp chunk_eip4844_blob(<<>>, acc), do: Enum.reverse(acc)
end
