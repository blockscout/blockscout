defmodule Explorer.Chain.Optimism.TxnBatch do
  @moduledoc "Models a batch of transactions for Optimism."

  use Explorer.Schema

  import Explorer.Chain, only: [join_association: 3, select_repo: 1]

  alias Explorer.Chain.Optimism.FrameSequence
  alias Explorer.PagingOptions

  @default_paging_options %PagingOptions{page_size: 50}

  @required_attrs ~w(l2_block_number frame_sequence_id)a

  @blob_size 4096 * 32
  @encoding_version 0
  @max_blob_data_size (4 * 31 + 3) * 1024 - 4
  @rounds 1024

  @type t :: %__MODULE__{
          l2_block_number: non_neg_integer(),
          frame_sequence_id: non_neg_integer(),
          frame_sequence: %Ecto.Association.NotLoaded{} | FrameSequence.t()
        }

  @primary_key false
  schema "op_transaction_batches" do
    field(:l2_block_number, :integer, primary_key: true)
    belongs_to(:frame_sequence, FrameSequence, foreign_key: :frame_sequence_id, references: :id, type: :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:frame_sequence_id)
  end

  @doc """
  Lists `t:Explorer.Chain.Optimism.TxnBatch.t/0`'s' in descending order based on l2_block_number.

  """
  @spec list :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    base_query =
      from(tb in __MODULE__,
        order_by: [desc: tb.l2_block_number]
      )

    base_query
    |> join_association(:frame_sequence, :required)
    |> page_txn_batches(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  @doc """
  Decodes EIP-4844 blob to the raw data. Returns `nil` if the blob is invalid.
  """
  @spec decode_eip4844_blob(binary()) :: binary() | nil
  def decode_eip4844_blob(b) do
    <<encoded_byte0::size(8), version::size(8), output_len::size(24), first_output::binary-size(27), _::binary>> = b

    if version != @encoding_version or output_len > @max_blob_data_size do
      raise "Blob version or data size is incorrect"
    end

    output = first_output <> :binary.copy(<<0>>, @max_blob_data_size - 27)

    opos = 28
    ipos = 32
    {encoded_byte1, opos, ipos, output} = decode_eip4844_field_element(b, opos, ipos, output)
    {encoded_byte2, opos, ipos, output} = decode_eip4844_field_element(b, opos, ipos, output)
    {encoded_byte3, opos, ipos, output} = decode_eip4844_field_element(b, opos, ipos, output)
    {opos, output} = reassemble_eip4844_bytes(opos, encoded_byte0, encoded_byte1, encoded_byte2, encoded_byte3, output)

    {_opos, ipos, output} =
      Enum.reduce_while(Range.new(1, @rounds - 1), {opos, ipos, output}, fn _i, {opos_acc, ipos_acc, output_acc} ->
        if opos_acc >= output_len do
          {:halt, {opos_acc, ipos_acc, output_acc}}
        else
          {encoded_byte0, opos_acc, ipos_acc, output_acc} =
            decode_eip4844_field_element(b, opos_acc, ipos_acc, output_acc)

          {encoded_byte1, opos_acc, ipos_acc, output_acc} =
            decode_eip4844_field_element(b, opos_acc, ipos_acc, output_acc)

          {encoded_byte2, opos_acc, ipos_acc, output_acc} =
            decode_eip4844_field_element(b, opos_acc, ipos_acc, output_acc)

          {encoded_byte3, opos_acc, ipos_acc, output_acc} =
            decode_eip4844_field_element(b, opos_acc, ipos_acc, output_acc)

          {opos_acc, output_acc} =
            reassemble_eip4844_bytes(opos_acc, encoded_byte0, encoded_byte1, encoded_byte2, encoded_byte3, output_acc)

          {:cont, {opos_acc, ipos_acc, output_acc}}
        end
      end)

    Enum.each(Range.new(output_len, byte_size(output) - 1, 1), fn i ->
      <<0>> = binary_part(output, i, 1)
    end)

    output = binary_part(output, 0, output_len)

    Enum.each(Range.new(ipos, @blob_size - 1, 1), fn i ->
      <<0>> = binary_part(b, i, 1)
    end)

    output
  rescue
    _ -> nil
  end

  defp decode_eip4844_field_element(b, opos, ipos, output) do
    <<_::binary-size(ipos), ipos_byte::size(8), insert::binary-size(31), _::binary>> = b

    if Bitwise.band(ipos_byte, 0b11000000) == 0 do
      <<output_before_opos::binary-size(opos), _::binary-size(31), rest::binary>> = output

      {ipos_byte, opos + 32, ipos + 32, output_before_opos <> insert <> rest}
    end
  end

  defp reassemble_eip4844_bytes(opos, encoded_byte0, encoded_byte1, encoded_byte2, encoded_byte3, output) do
    opos = opos - 1

    x = Bitwise.bor(Bitwise.band(encoded_byte0, 0b00111111), Bitwise.bsl(Bitwise.band(encoded_byte1, 0b00110000), 2))
    y = Bitwise.bor(Bitwise.band(encoded_byte1, 0b00001111), Bitwise.bsl(Bitwise.band(encoded_byte3, 0b00001111), 4))
    z = Bitwise.bor(Bitwise.band(encoded_byte2, 0b00111111), Bitwise.bsl(Bitwise.band(encoded_byte3, 0b00110000), 2))

    new_output =
      output
      |> replace_byte(z, opos - 32)
      |> replace_byte(y, opos - 32 * 2)
      |> replace_byte(x, opos - 32 * 3)

    {opos, new_output}
  end

  defp replace_byte(bytes, byte, pos) do
    <<bytes_before::binary-size(pos), _::size(8), bytes_after::binary>> = bytes
    bytes_before <> <<byte>> <> bytes_after
  end

  defp page_txn_batches(query, %PagingOptions{key: nil}), do: query

  defp page_txn_batches(query, %PagingOptions{key: {block_number}}) do
    from(tb in query, where: tb.l2_block_number < ^block_number)
  end
end
