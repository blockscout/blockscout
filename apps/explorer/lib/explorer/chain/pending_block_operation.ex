defmodule Explorer.Chain.PendingBlockOperation do
  @moduledoc """
  Tracks a block that has pending operations.
  """

  use Explorer.Schema

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
end
