defmodule Explorer.Chain.PendingBlockOperation do
  @moduledoc """
  Tracks a block that has pending operations.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}

  @required_attrs ~w(block_hash)a

  @typedoc """
   * `block_hash` - the hash of the block that has pending operations.
  """
  @type t :: %__MODULE__{
          block_hash: Hash.Full.t()
        }

  @primary_key false
  schema "pending_block_operations" do
    timestamps()

    belongs_to(:block, Block, foreign_key: :block_hash, primary_key: true, references: :hash, type: Hash.Full)
  end

  def changeset(%__MODULE__{} = pending_ops, attrs) do
    pending_ops
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash, name: :pending_block_operations_pkey)
  end

  @doc """
  Returns all pending block operations with the `block_hash` in the given list,
  using "FOR UPDATE" to grab ShareLocks in order (see docs: sharelocks.md)
  """
  def fetch_and_lock_by_hashes(hashes) when is_list(hashes) do
    from(
      pending_ops in __MODULE__,
      where: pending_ops.block_hash in ^hashes,
      order_by: [asc: pending_ops.block_hash],
      lock: "FOR UPDATE"
    )
  end

  def block_hashes do
    from(
      pending_ops in __MODULE__,
      select: pending_ops.block_hash
    )
  end
end
