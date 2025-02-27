defmodule Explorer.Chain.PendingBlockOperation do
  @moduledoc """
  Tracks a block that has pending operations.
  """

  use Explorer.Schema

  import Explorer.Chain, only: [add_fetcher_limit: 2]

  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Repo

  @required_attrs ~w(block_hash block_number)a

  @typedoc """
   * `block_hash` - the hash of the block that has pending operations.
  """
  @primary_key false
  typed_schema "pending_block_operations" do
    timestamps()

    field(:block_number, :integer, null: false)

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )
  end

  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash, name: :pending_block_operations_pkey)
  end

  def block_hashes do
    from(
      pending_ops in __MODULE__,
      select: pending_ops.block_hash
    )
  end

  @doc """
    Returns the count of pending block operations in provided blocks range
    (between `from_block_number` and `to_block_number`).
  """
  @spec blocks_count_in_range(integer(), integer()) :: integer()
  def blocks_count_in_range(from_block_number, to_block_number) when from_block_number <= to_block_number do
    __MODULE__
    |> where([pbo], pbo.block_number >= ^from_block_number)
    |> where([pbo], pbo.block_number <= ^to_block_number)
    |> select([pbo], count(pbo.block_number))
    |> Repo.one()
  end

  @doc """
  Returns a stream of all blocks with unfetched internal transactions, using
  the `pending_block_operation` table.

      iex> unfetched = insert(:block)
      iex> insert(:pending_block_operation, block: unfetched, block_number: unfetched.number)
      iex> {:ok, number_set} = Explorer.Chain.stream_blocks_with_unfetched_internal_transactions(
      ...>   MapSet.new(),
      ...>   fn number, acc ->
      ...>     MapSet.put(acc, number)
      ...>   end
      ...> )
      iex> unfetched.number in number_set
      true

  """
  @spec stream_blocks_with_unfetched_internal_transactions(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_blocks_with_unfetched_internal_transactions(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    direction = Application.get_env(:indexer, :internal_transactions_fetch_order)

    query =
      from(
        po in __MODULE__,
        where: not is_nil(po.block_number),
        select: po.block_number,
        order_by: [{^direction, po.block_number}]
      )

    query
    |> add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end
end
