defmodule Explorer.Chain.Celo.PendingEpochBlockOperation do
  @moduledoc """
  Tracks an epoch block that has pending operation.
  """

  use Explorer.Schema

  import Explorer.Chain, only: [add_fetcher_limit: 2]
  alias Explorer.Chain.{Block, Hash}
  alias Explorer.Repo

  @required_attrs ~w(block_hash)a

  @typedoc """
   * `block_hash` - the hash of the block that has pending epoch operations.
  """
  @primary_key false
  typed_schema "celo_pending_epoch_block_operations" do
    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash, name: :pending_epoch_block_operations_pkey)
  end

  @doc """
  Returns a stream of all blocks prior to Celo L2 migration with unfetched
  epochs, using the `celo_pending_epoch_block_operations` table.

      iex> unfetched = insert(:block, number: 1 * blocks_per_epoch())
      iex> insert(:celo_pending_epoch_block_operation, block: unfetched)
      iex> {:ok, blocks} = PendingEpochBlockOperation.stream_premigration_epoch_blocks_with_unfetched_rewards(
      ...>   [],
      ...>   fn block, acc ->
      ...>     [block | acc]
      ...>   end
      ...> )
      iex> [{unfetched.number, unfetched.hash}] == blocks
      true
  """
  @spec stream_premigration_epoch_blocks_with_unfetched_rewards(
          initial :: accumulator,
          reducer :: (entry :: term(), accumulator -> accumulator),
          limited? :: boolean()
        ) :: {:ok, accumulator}
        when accumulator: term()
  def stream_premigration_epoch_blocks_with_unfetched_rewards(initial, reducer, limited? \\ false)
      when is_function(reducer, 2) do
    query =
      from(
        op in __MODULE__,
        join: block in assoc(op, :block),
        select: %{block_number: block.number, block_hash: block.hash},
        where: block.consensus == true,
        order_by: [desc: block.number]
      )

    query
    |> maybe_filter_premigration_epoch_blocks()
    |> add_fetcher_limit(limited?)
    |> Repo.stream_reduce(initial, reducer)
  end

  @spec maybe_filter_premigration_epoch_blocks(Ecto.Query.t()) :: Ecto.Query.t()
  defp maybe_filter_premigration_epoch_blocks(query) do
    l2_migration_block_number = Application.get_env(:explorer, :celo)[:l2_migration_block]

    if l2_migration_block_number do
      query
      |> where([op, block], block.number <= ^l2_migration_block_number)
    else
      query
    end
  end
end
