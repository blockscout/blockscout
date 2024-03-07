defmodule Explorer.Chain.Optimism.TxnBatch do
  @moduledoc "Models a batch of transactions for Optimism."

  use Explorer.Schema

  import Explorer.Chain, only: [join_association: 3, select_repo: 1]

  alias Explorer.Chain.Optimism.FrameSequence
  alias Explorer.PagingOptions

  @default_paging_options %PagingOptions{page_size: 50}

  @required_attrs ~w(l2_block_number frame_sequence_id)a

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

  defp page_txn_batches(query, %PagingOptions{key: nil}), do: query

  defp page_txn_batches(query, %PagingOptions{key: {block_number}}) do
    from(tb in query, where: tb.l2_block_number < ^block_number)
  end
end
