defmodule Explorer.Chain.Scroll.Batch do
  @moduledoc """
    Models a batch for Scroll.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Scroll.Batches

    Migrations:
    - Explorer.Repo.Scroll.Migrations.AddBatchesTables
  """

  use Explorer.Schema

  import Explorer.Chain, only: [default_paging_options: 0, join_association: 3, join_associations: 2, select_repo: 1]

  alias Explorer.Chain.Block.Range, as: BlockRange
  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Chain.Scroll.{BatchBundle, Reader}
  alias Explorer.PagingOptions

  @optional_attrs ~w(bundle_id)a

  @required_attrs ~w(number commit_transaction_hash commit_block_number commit_timestamp l2_block_range)a

  @typedoc """
    Descriptor of the batch:
    * `number` - A unique batch number.
    * `commit_transaction_hash` - A hash of the commit transaction on L1.
    * `commit_block_number` - A block number of the commit transaction on L1.
    * `commit_timestamp` - A timestamp of the commit block.
    * `bundle_id` - An identifier of the batch bundle from the `scroll_batch_bundles` database table.
    * `l2_block_range` - A range of L2 blocks included into the batch.
  """
  @type to_import :: %{
          number: non_neg_integer(),
          commit_transaction_hash: Hash.t(),
          commit_block_number: non_neg_integer(),
          commit_timestamp: DateTime.t(),
          bundle_id: non_neg_integer() | nil,
          l2_block_range: BlockRange.t()
        }

  @typedoc """
    * `number` - A unique batch number.
    * `commit_transaction_hash` - A hash of the commit transaction on L1.
    * `commit_block_number` - A block number of the commit transaction on L1.
    * `commit_timestamp` - A timestamp of the commit block.
    * `bundle_id` - An identifier of the batch bundle from the `scroll_batch_bundles` database table.
    * `l2_block_range` - A range of L2 blocks included into the batch.
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

    field(:l2_block_range, BlockRange, null: false)

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
    Lists `t:Explorer.Chain.Scroll.Batch.t/0`'s' in descending order based on the `number`.

    ## Parameters
    - `options`: A keyword list of options that may include whether to use a replica database and paging options.

    ## Returns
    - A list of found entities sorted by `number` in descending order.
  """
  @spec list(list()) :: [__MODULE__.t()]
  def list(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, default_paging_options())

    case paging_options do
      %PagingOptions{key: {0}} ->
        []

      _ ->
        base_query =
          from(b in __MODULE__,
            order_by: [desc: b.number]
          )

        base_query
        |> join_association(:bundle, :optional)
        |> page_batches(paging_options)
        |> limit(^paging_options.page_size)
        |> select_repo(options).all()
    end
  end

  defp page_batches(query, %PagingOptions{key: nil}), do: query

  defp page_batches(query, %PagingOptions{key: {number}}) do
    from(b in query, where: b.number < ^number)
  end

  @doc """
    Retrieves a list of rollup blocks included into a specified batch.

    This function constructs and executes a database query to retrieve a list of rollup blocks,
    considering pagination options specified in the `options` parameter. These options dictate
    the number of items to retrieve and how many items to skip from the top.

    ## Parameters
    - `batch_number`: The batch number.
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
    api = Keyword.get(options, :api?, false)

    case Reader.batch(batch_number, api?: api) do
      {:ok, batch} ->
        query =
          from(
            b in Block,
            where:
              b.number >= ^batch.l2_block_range.from and b.number <= ^batch.l2_block_range.to and b.consensus == true
          )

        query
        |> page_blocks(paging_options)
        |> limit(^paging_options.page_size)
        |> order_by(desc: :number)
        |> join_associations(necessity_by_association)
        |> select_repo(options).all()

      _ ->
        []
    end
  end

  defp page_blocks(query, %PagingOptions{key: nil}), do: query

  defp page_blocks(query, %PagingOptions{key: {0}}), do: query

  defp page_blocks(query, %PagingOptions{key: {block_number}}) do
    where(query, [block], block.number < ^block_number)
  end
end
