defmodule Explorer.Chain.Optimism.OutputRoot do
  @moduledoc "Models an output root for Optimism."

  use Explorer.Schema

  import Explorer.Chain, only: [select_repo: 1]

  alias Explorer.Chain.Hash
  alias Explorer.PagingOptions

  @default_paging_options %PagingOptions{page_size: 50}

  @required_attrs ~w(l2_output_index l2_block_number l1_transaction_hash l1_timestamp l1_block_number output_root)a

  @type t :: %__MODULE__{
          l2_output_index: non_neg_integer(),
          l2_block_number: non_neg_integer(),
          l1_transaction_hash: Hash.t(),
          l1_timestamp: DateTime.t(),
          l1_block_number: non_neg_integer(),
          output_root: Hash.t()
        }

  @primary_key false
  schema "op_output_roots" do
    field(:l2_output_index, :integer, primary_key: true)
    field(:l2_block_number, :integer)
    field(:l1_transaction_hash, Hash.Full)
    field(:l1_timestamp, :utc_datetime_usec)
    field(:l1_block_number, :integer)
    field(:output_root, Hash.Full)

    timestamps()
  end

  def changeset(%__MODULE__{} = output_roots, attrs \\ %{}) do
    output_roots
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  @doc """
  Lists `t:Explorer.Chain.Optimism.OutputRoot.t/0`'s' in descending order based on output root index.

  """
  @spec list :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)

    base_query =
      from(r in __MODULE__,
        order_by: [desc: r.l2_output_index],
        select: r
      )

    base_query
    |> page_output_roots(paging_options)
    |> limit(^paging_options.page_size)
    |> select_repo(options).all()
  end

  defp page_output_roots(query, %PagingOptions{key: nil}), do: query

  defp page_output_roots(query, %PagingOptions{key: {index}}) do
    from(r in query, where: r.l2_output_index < ^index)
  end
end
