defmodule Explorer.Chain.Optimism.FrameSequence do
  @moduledoc """
    Models a frame sequence for Optimism.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Optimism.FrameSequences

    Migrations:
    - Explorer.Repo.Migrations.AddOpFrameSequencesTable
  """

  use Explorer.Schema

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Optimism.{FrameSequenceBlob, TxnBatch}
  alias Explorer.PagingOptions

  @default_paging_options %PagingOptions{page_size: 50}

  @required_attrs ~w(id l1_transaction_hashes l1_timestamp)a

  @type t :: %__MODULE__{
          l1_transaction_hashes: [Hash.t()],
          l1_timestamp: DateTime.t(),
          view_ready: boolean(),
          transaction_batches: %Ecto.Association.NotLoaded{} | [TxnBatch.t()],
          blobs: %Ecto.Association.NotLoaded{} | [FrameSequenceBlob.t()]
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "op_frame_sequences" do
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
    Lists `t:Explorer.Chain.Optimism.FrameSequence.t/0`'s' in descending order based on id.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database,
      paging options, and `only_view_ready` option.

    ## Returns
    - A list of found entities sorted by `id` in descending order.
  """
  @spec list :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
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
