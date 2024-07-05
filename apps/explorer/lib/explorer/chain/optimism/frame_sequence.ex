defmodule Explorer.Chain.Optimism.FrameSequence do
  @moduledoc """
    Models a frame sequence for Optimism.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Optimism.FrameSequences

    Migrations:
    - Explorer.Repo.Migrations.AddOpFrameSequencesTable
    - Explorer.Repo.Optimism.Migrations.AddViewReadyField
    - Explorer.Repo.Optimism.Migrations.AddFrameSequenceIdPrevField
  """

  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Chain.Optimism.{FrameSequenceBlob, TxnBatch}
  alias Explorer.PagingOptions

  @required_attrs ~w(id l1_transaction_hashes l1_timestamp)a

  @typedoc """
    * `l1_transaction_hashes` - The list of L1 transaction hashes where the frame sequence is stored.
    * `l1_timestamp` - UTC timestamp of the last L1 transaction of `l1_transaction_hashes` list.
    * `view_ready` - Boolean flag indicating if the frame sequence is ready for displaying on UI.
    * `transaction_batches` - Instances of `Explorer.Chain.Optimism.TxnBatch` bound with this frame sequence.
    * `blobs` - Instances of `Explorer.Chain.Optimism.FrameSequenceBlob` bound with this frame sequence.
  """
  @primary_key {:id, :integer, autogenerate: false}
  typed_schema "op_frame_sequences" do
    field(:l1_transaction_hashes, {:array, Hash.Full})
    field(:l1_timestamp, :utc_datetime_usec)
    field(:view_ready, :boolean)

    has_many(:transaction_batches, TxnBatch, foreign_key: :frame_sequence_id)
    has_many(:blobs, FrameSequenceBlob, foreign_key: :frame_sequence_id)

    timestamps()
  end

  @doc """
    Validates that the attributes are valid.
  """
  def changeset(%__MODULE__{} = sequences, attrs \\ %{}) do
    sequences
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end

  @doc """
    Finds and returns L1 batch data from the op_frame_sequences and
    op_frame_sequence_blobs DB tables by Celestia blob's commitment and height.

    ## Parameters
    - `commitment`: Blob's commitment in the form of hex string beginning with 0x prefix.
    - `height`: Blob's height.
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - A map with info about L1 batch bound to the specified Celestia blob.
    - nil if the blob is not found.
  """
  @spec batch_by_celestia_blob(binary(), non_neg_integer(), list()) :: map() | nil
  def batch_by_celestia_blob(commitment, height, options \\ []) do
    commitment = Base.decode16!(String.trim_leading(commitment, "0x"), case: :mixed)
    height = :binary.encode_unsigned(height)
    key = :crypto.hash(:sha256, height <> commitment)

    query =
      from(fsb in FrameSequenceBlob,
        select: fsb.frame_sequence_id,
        where: fsb.key == ^key and fsb.type == :celestia
      )

    frame_sequence_id = select_repo(options).one(query)

    if not is_nil(frame_sequence_id) do
      batch_by_internal_id(frame_sequence_id, options)
    end
  end

  @doc """
    Finds and returns L1 batch data from the op_frame_sequences and
    op_frame_sequence_blobs DB tables by the internal id of the batch.

    ## Parameters
    - `internal_id`: Batch'es internal id.
    - `options`: A keyword list of options that may include whether to use a replica database.

    ## Returns
    - A map with info about L1 batch having the specified id.
    - nil if the batch is not found.
  """
  @spec batch_by_internal_id(non_neg_integer(), list()) :: map() | nil
  def batch_by_internal_id(internal_id, options \\ []) do
    query =
      from(fs in __MODULE__,
        where: fs.id == ^internal_id and fs.view_ready == true
      )

    batch = select_repo(options).one(query)

    if not is_nil(batch) do
      l2_block_number_from = TxnBatch.edge_l2_block_number(internal_id, :min)
      l2_block_number_to = TxnBatch.edge_l2_block_number(internal_id, :max)
      tx_count = Transaction.tx_count_for_block_range(l2_block_number_from..l2_block_number_to)

      {batch_data_container, blobs} = FrameSequenceBlob.list(internal_id, options)

      result = %{
        "internal_id" => internal_id,
        "l1_timestamp" => batch.l1_timestamp,
        "l2_block_start" => l2_block_number_from,
        "l2_block_end" => l2_block_number_to,
        "tx_count" => tx_count,
        "l1_tx_hashes" => batch.l1_transaction_hashes,
        "batch_data_container" => batch_data_container
      }

      if Enum.empty?(blobs) do
        result
      else
        Map.put(result, "blobs", blobs)
      end
    end
  end

  @doc """
    Lists `t:Explorer.Chain.Optimism.FrameSequence.t/0`'s' in descending order based on id.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database,
      paging options, and `only_view_ready` option.

    ## Returns
    - A list of found entities sorted by `id` in descending order.
  """
  @spec list(list()) :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())
    only_view_ready = Keyword.get(options, :only_view_ready?, false)

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          if only_view_ready do
            from(fs in __MODULE__,
              where: fs.view_ready == true,
              order_by: [desc: fs.id]
            )
          else
            from(fs in __MODULE__,
              order_by: [desc: fs.id]
            )
          end

        base_query
        |> page_frame_sequences(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  defp page_frame_sequences(query, %PagingOptions{key: nil}), do: query

  defp page_frame_sequences(query, %PagingOptions{key: {id}}) do
    from(fs in query, where: fs.id < ^id)
  end
end
