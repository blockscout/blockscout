defmodule Explorer.Chain.PendingBlockOperation do
  @moduledoc """
  Tracks a block that has pending operations.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}

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
end
