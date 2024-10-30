defmodule Explorer.Chain.Optimism.TransactionBatch do
  @moduledoc """
    Models a batch of transactions for Optimism.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Optimism.TransactionBatches

    Migrations:
    - Explorer.Repo.Migrations.AddOpTransactionBatchesTable
    - Explorer.Repo.Migrations.RenameFields
    - Explorer.Repo.Migrations.AddOpFrameSequencesTable
    - Explorer.Repo.Migrations.RemoveOpEpochNumberField
    - Explorer.Repo.Optimism.Migrations.AddCelestiaBlobMetadata
    - Explorer.Repo.Optimism.Migrations.AddFrameSequenceIdPrevField
  """

  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, join_association: 3, join_associations: 2, select_repo: 1]

  alias Explorer.Chain.Block
  alias Explorer.Chain.Optimism.FrameSequence
  alias Explorer.{PagingOptions, Repo}

  @required_attrs ~w(l2_block_number frame_sequence_id)a

  @blob_size 4096 * 32
  @encoding_version 0
  @max_blob_data_size (4 * 31 + 3) * 1024 - 4
  @rounds 1024

  @typedoc """
    * `l2_block_number` - An L2 block number related to the specified frame sequence.
    * `frame_sequence_id` - ID of the frame sequence the L2 block relates to.
    * `frame_sequence_id_prev` - Previous ID of the frame sequence (should be 0 until the table row is updated).
    * `frame_sequence` - An instance of `Explorer.Chain.Optimism.FrameSequence` referenced by `frame_sequence_id`.
  """
  @primary_key false
  typed_schema "op_transaction_batches" do
    field(:l2_block_number, :integer, primary_key: true)
    belongs_to(:frame_sequence, FrameSequence, foreign_key: :frame_sequence_id, references: :id, type: :integer)
    field(:frame_sequence_id_prev, :integer)

    timestamps()
  end

  @doc """
    Validates that the attributes are valid.
  """
  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:frame_sequence_id)
  end

  @doc """
    Returns an edge L2 block number (min or max) of an L2 block range
    for the specified frame sequence.

    ## Parameters
    - `id`: The ID of the frame sequence for which the edge block number must be returned.
    - `type`: Can be :min or :max depending on which block number needs to be returned.

    ## Returns
    - The min/max block number or `nil` if the block range is not found.
  """
  @spec edge_l2_block_number(non_neg_integer(), :min | :max) :: non_neg_integer() | nil
  def edge_l2_block_number(id, type) when type == :min and is_integer(id) and id >= 0 do
    query =
      id
      |> edge_l2_block_number_query()
      |> order_by([tb], asc: tb.l2_block_number)

    Repo.replica().one(query)
  end

  def edge_l2_block_number(id, type) when type == :max and is_integer(id) and id >= 0 do
    query =
      id
      |> edge_l2_block_number_query()
      |> order_by([tb], desc: tb.l2_block_number)

    Repo.replica().one(query)
  end

  def edge_l2_block_number(_id, _type), do: nil

  defp edge_l2_block_number_query(id) do
    from(
      tb in __MODULE__,
      select: tb.l2_block_number,
      where: tb.frame_sequence_id == ^id,
      limit: 1
    )
  end

  @doc """
    Lists `t:Explorer.Chain.Optimism.TransactionBatch.t/0`'s' in descending order based on l2_block_number.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database,
      paging options, and optional L2 block range for which to make the list of items.

    ## Returns
    - A list of found entities sorted by `l2_block_number` in descending order.
  """
  @spec list(list()) :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        l2_block_range_start = Keyword.get(options, :l2_block_range_start)
        l2_block_range_end = Keyword.get(options, :l2_block_range_end)

        base_query =
          if is_nil(l2_block_range_start) or is_nil(l2_block_range_end) do
            from(tb in __MODULE__,
              order_by: [desc: tb.l2_block_number]
            )
          else
            from(tb in __MODULE__,
              order_by: [desc: tb.l2_block_number],
              where: tb.l2_block_number >= ^l2_block_range_start and tb.l2_block_number <= ^l2_block_range_end
            )
          end

        base_query
        |> join_association(:frame_sequence, :required)
        |> page_transaction_batches(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all(timeout: :infinity)
    end
  end

  @doc """
    Retrieves a list of rollup blocks included into a specified batch.

    This function constructs and executes a database query to retrieve a list of rollup blocks,
    considering pagination options specified in the `options` parameter. These options dictate
    the number of items to retrieve and how many items to skip from the top.

    ## Parameters
    - `batch_number`: The batch number whose transactions are included on L1.
    - `options`: A keyword list of options specifying pagination, association necessity, and
      whether to use a replica database.

    ## Returns
    - A list of `Explorer.Chain.Block` entries belonging to the specified batch.
  """
  @spec batch_blocks(non_neg_integer() | binary(),
          necessity_by_association: %{atom() => :optional | :required},
          api?: boolean(),
          paging_options: PagingOptions.t()
        ) :: [Block.t()]
  def batch_blocks(batch_number, options) do
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    query =
      from(
        b in Block,
        inner_join: tb in __MODULE__,
        on: tb.l2_block_number == b.number and tb.frame_sequence_id == ^batch_number,
        where: b.consensus == true
      )

    query
    |> page_blocks(paging_options)
    |> limit(^paging_options.page_size)
    |> order_by(desc: :number)
    |> join_associations(necessity_by_association)
    |> select_repo(options).all(timeout: :infinity)
  end

  defp page_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_blocks(query, %PagingOptions{key: {0}}), do: query

  defp page_blocks(query, %PagingOptions{key: {block_number}}) do
    where(query, [block], block.number < ^block_number)
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

  defp page_transaction_batches(query, %PagingOptions{key: nil}), do: query

  defp page_transaction_batches(query, %PagingOptions{key: {block_number}}) do
    from(tb in query, where: tb.l2_block_number < ^block_number)
  end
end
