defmodule Explorer.Chain.Beacon.Blob do
  @moduledoc "Models a data blob broadcasted using eip4844 blob transactions."

  use Explorer.Schema

  alias Explorer.Chain.{Data, Hash}

  @blob_size 4096 * 32
  @encoding_version 0
  @max_blob_data_size (4*31+3)*1024 - 4
  @rounds 1024
  @required_attrs ~w(hash blob_data kzg_commitment kzg_proof)a

  @type t :: %__MODULE__{
          hash: Hash.t(),
          blob_data: Data.t(),
          kzg_commitment: Data.t(),
          kzg_proof: Data.t()
        }

  @primary_key {:hash, Hash.Full, autogenerate: false}
  schema "beacon_blobs" do
    field(:blob_data, Data)
    field(:kzg_commitment, Data)
    field(:kzg_proof, Data)

    timestamps(updated_at: false)
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = struct, attrs \\ %{}) do
    struct
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:hash)
  end

  @doc """
    Returns the `hash` of the `t:Explorer.Chain.Beacon.Blob.t/0` as per EIP-4844.
  """
  @spec hash(binary()) :: Hash.Full.t()
  def hash(kzg_commitment) do
    raw_hash = :crypto.hash(:sha256, kzg_commitment)
    <<_::size(8), rest::binary>> = raw_hash
    {:ok, hash} = Hash.Full.cast(<<1>> <> rest)
    hash
  end

  @spec decode(binary()) :: binary() | nil
  def decode(b) do
    try do
      <<encoded_byte0::size(8), version::size(8), output_len::size(24), first_output::binary-size(27), _::binary>> = b

      if version != @encoding_version or output_len > @max_blob_data_size do
        raise "Blob version or data size is incorrect"
      end

      output = first_output <> :binary.copy(<<0>>, @max_blob_data_size - 27)

      opos = 28
      ipos = 32
      {encoded_byte1, opos, ipos, output} = decode_field_element(b, opos, ipos, output)
      {encoded_byte2, opos, ipos, output} = decode_field_element(b, opos, ipos, output)
      {encoded_byte3, opos, ipos, output} = decode_field_element(b, opos, ipos, output)
      {opos, output} = reassemble_bytes(opos, encoded_byte0, encoded_byte1, encoded_byte2, encoded_byte3, output)

      {_opos, ipos, output} =
        Enum.reduce_while(Range.new(1, @rounds - 1), {opos, ipos, output}, fn _i, {opos_acc, ipos_acc, output_acc} ->
          if opos_acc >= output_len do
            {:halt, {opos_acc, ipos_acc, output_acc}}
          else
            {encoded_byte0, opos_acc, ipos_acc, output_acc} = decode_field_element(b, opos_acc, ipos_acc, output_acc)
            {encoded_byte1, opos_acc, ipos_acc, output_acc} = decode_field_element(b, opos_acc, ipos_acc, output_acc)
            {encoded_byte2, opos_acc, ipos_acc, output_acc} = decode_field_element(b, opos_acc, ipos_acc, output_acc)
            {encoded_byte3, opos_acc, ipos_acc, output_acc} = decode_field_element(b, opos_acc, ipos_acc, output_acc)
            {opos_acc, output_acc} = reassemble_bytes(opos_acc, encoded_byte0, encoded_byte1, encoded_byte2, encoded_byte3, output_acc)

            {:cont, {opos_acc, ipos_acc, output_acc}}
          end
        end)

      Enum.each(Range.new(output_len, byte_size(output) - 1), fn i ->
        <<0>> = binary_part(output, i, 1)
      end)

      output = binary_part(output, 0, output_len)

      Enum.each(Range.new(ipos, @blob_size - 1), fn i ->
        <<0>> = binary_part(b, i, 1)
      end)

      output
    rescue
      _ -> nil
    end
  end

  defp decode_field_element(b, opos, ipos, output) do
    <<_::binary-size(ipos), ipos_byte::size(8), insert::binary-size(32), _::binary>> = b

    if Bitwise.band(ipos_byte, 0b11000000) == 0 do
      <<output_before_opos::binary-size(opos), _::binary-size(32), rest::binary>> = output

      {ipos_byte, opos + 32, ipos + 32, output_before_opos <> insert <> rest}
    end
  end

  defp reassemble_bytes(opos, encoded_byte0, encoded_byte1, encoded_byte2, encoded_byte3, output) do
    opos = opos - 1

    x = Bitwise.bor(Bitwise.band(encoded_byte0, 0b00111111), Bitwise.bsl(Bitwise.band(encoded_byte1, 0b00110000), 2))
    y = Bitwise.bor(Bitwise.band(encoded_byte1, 0b00001111), Bitwise.bsl(Bitwise.band(encoded_byte3, 0b00001111), 4))
    z = Bitwise.bor(Bitwise.band(encoded_byte2, 0b00111111), Bitwise.bsl(Bitwise.band(encoded_byte3, 0b00110000), 2))

    new_output =
      output
      |> replace_byte(z, opos-32)
      |> replace_byte(y, opos-(32*2))
      |> replace_byte(x, opos-(32*3))

    {opos, new_output}
  end

  defp replace_byte(bytes, byte, pos) do
    <<bytes_before::binary-size(pos), _::size(8), bytes_after::binary>> = bytes
    bytes_before <> <<byte>> <> bytes_after
  end
end
