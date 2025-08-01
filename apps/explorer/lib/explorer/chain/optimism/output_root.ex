defmodule Explorer.Chain.Optimism.OutputRoot do
  @moduledoc "Models an output root for Optimism."

  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, select_repo: 1]

  alias Explorer.Chain.Hash
  alias Explorer.PagingOptions

  @required_attrs ~w(l2_output_index l2_block_number l1_transaction_hash l1_timestamp l1_block_number output_root)a

  @typedoc """
    * `l2_output_index` - A unique index of the output root.
    * `l2_block_number` - An L2 block number of the output root.
    * `l1_transaction_hash` - An L1 transaction hash where an event with the output root appeared.
    * `l1_timestamp` - A timestamp of the L1 transaction block.
    * `l1_block_number` - A block number of the L1 transaction.
    * `output_root` - The output root.
  """
  @primary_key false
  typed_schema "op_output_roots" do
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
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(r in __MODULE__,
            order_by: [desc: r.l2_output_index],
            select: r
          )

        base_query
        |> page_output_roots(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all(timeout: :infinity)
    end
  end

  defp page_output_roots(query, %PagingOptions{key: nil}), do: query

  defp page_output_roots(query, %PagingOptions{key: {index}}) do
    from(r in query, where: r.l2_output_index < ^index)
  end

  @doc """
    Forms a query to find the last Output Root's L1 block number and transaction hash.
    Used by the `Indexer.Fetcher.Optimism.OutputRoot` module.

    ## Returns
    - A query which can be used by the `Repo.one` function.
  """
  @spec last_root_l1_block_number_query() :: Ecto.Queryable.t()
  def last_root_l1_block_number_query do
    from(root in __MODULE__,
      select: {root.l1_block_number, root.l1_transaction_hash},
      order_by: [desc: root.l2_output_index],
      limit: 1
    )
  end

  @doc """
    Forms a query to remove all Output Roots related to the specified L1 block number.
    Used by the `Indexer.Fetcher.Optimism.OutputRoot` module.

    ## Parameters
    - `l1_block_number`: The L1 block number for which the Output Roots should be removed
                         from the `op_output_roots` database table.

    ## Returns
    - A query which can be used by the `delete_all` function.
  """
  @spec remove_roots_query(non_neg_integer()) :: Ecto.Queryable.t()
  def remove_roots_query(l1_block_number) do
    from(root in __MODULE__, where: root.l1_block_number == ^l1_block_number)
  end
end
