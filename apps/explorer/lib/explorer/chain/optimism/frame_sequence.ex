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
  alias Explorer.Chain.Optimism.{FrameSequenceBlob, TransactionBatch}
  alias Explorer.PagingOptions

  @required_attrs ~w(id l1_transaction_hashes l1_timestamp)a

  @typedoc """
    * `l1_transaction_hashes` - The list of L1 transaction hashes where the frame sequence is stored.
    * `l1_timestamp` - UTC timestamp of the last L1 transaction of `l1_transaction_hashes` list.
    * `view_ready` - Boolean flag indicating if the frame sequence is ready for displaying on UI.
    * `transaction_batches` - Instances of `Explorer.Chain.Optimism.TransactionBatch` bound with this frame sequence.
    * `blobs` - Instances of `Explorer.Chain.Optimism.FrameSequenceBlob` bound with this frame sequence.
  """
  @primary_key {:id, :integer, autogenerate: false}
  typed_schema "op_frame_sequences" do
    field(:l1_transaction_hashes, {:array, Hash.Full})
    field(:l1_timestamp, :utc_datetime_usec)
    field(:view_ready, :boolean)

    has_many(:transaction_batches, TransactionBatch, foreign_key: :frame_sequence_id)
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
    - `options`: A keyword list of options that may include whether to use a replica database
                 and/or whether to include blobs (true by default).

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
      l2_block_number_from = TransactionBatch.edge_l2_block_number(internal_id, :min)
      l2_block_number_to = TransactionBatch.edge_l2_block_number(internal_id, :max)
      transaction_count = Transaction.transaction_count_for_block_range(l2_block_number_from..l2_block_number_to)

      {batch_data_container, blobs} =
        if Keyword.get(options, :include_blobs?, true) do
          FrameSequenceBlob.list(internal_id, options)
        else
          {nil, []}
        end

      result =
        prepare_base_info_for_batch(
          internal_id,
          l2_block_number_from,
          l2_block_number_to,
          transaction_count,
          batch_data_container,
          batch
        )

      if Enum.empty?(blobs) do
        result
      else
        Map.put(result, :blobs, blobs)
      end
    end
  end

  @doc """
    Transforms an L1 batch into a map format for HTTP response.

    This function processes an Optimism L1 batch and converts it into a map that
    includes basic batch information.

    ## Parameters
    - `internal_id`: The internal ID of the batch.
    - `l2_block_number_from`: Start L2 block number of the batch block range.
    - `l2_block_number_to`: End L2 block number of the batch block range.
    - `transaction_count`: The L2 transaction count included into the blocks of the range.
    - `batch_data_container`: Designates where the batch info is stored: :in_blob4844, :in_celestia, or :in_calldata.
                              Can be `nil` if the container is unknown.
    - `batch`: Either an `Explorer.Chain.Optimism.FrameSequence` entry or a map with
               the corresponding fields.

    ## Returns
    - A map with detailed information about the batch formatted for use in JSON HTTP responses.
  """
  @spec prepare_base_info_for_batch(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          :in_blob4844 | :in_celestia | :in_calldata | nil,
          __MODULE__.t()
          | %{:l1_timestamp => DateTime.t(), :l1_transaction_hashes => list(), optional(any()) => any()}
        ) :: %{
          :number => non_neg_integer(),
          :internal_id => non_neg_integer(),
          :l1_timestamp => DateTime.t(),
          :l2_start_block_number => non_neg_integer(),
          :l2_block_start => non_neg_integer(),
          :l2_end_block_number => non_neg_integer(),
          :l2_block_end => non_neg_integer(),
          :transactions_count => non_neg_integer(),
          :transaction_count => non_neg_integer(),
          :l1_transaction_hashes => list(),
          :batch_data_container => :in_blob4844 | :in_celestia | :in_calldata | nil
        }
  def prepare_base_info_for_batch(
        internal_id,
        l2_block_number_from,
        l2_block_number_to,
        transaction_count,
        batch_data_container,
        batch
      ) do
    %{
      :number => internal_id,
      # todo: "internal_id" should be removed in favour `number` property with the next release after 8.0.0
      :internal_id => internal_id,
      :l1_timestamp => batch.l1_timestamp,
      :l2_start_block_number => l2_block_number_from,
      # todo: It should be removed in favour `l2_start_block_number` property with the next release after 8.0.0
      :l2_block_start => l2_block_number_from,
      :l2_end_block_number => l2_block_number_to,
      # todo: It should be removed in favour `l2_end_block_number` property with the next release after 8.0.0
      :l2_block_end => l2_block_number_to,
      :transactions_count => transaction_count,
      # todo: It should be removed in favour `transactions_count` property with the next release after 8.0.0
      :transaction_count => transaction_count,
      :l1_transaction_hashes => batch.l1_transaction_hashes,
      :batch_data_container => batch_data_container
    }
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
        |> select_repo(options).all(timeout: :infinity)
    end
  end

  defp page_frame_sequences(query, %PagingOptions{key: nil}), do: query

  defp page_frame_sequences(query, %PagingOptions{key: {id}}) do
    from(fs in query, where: fs.id < ^id)
  end
end
