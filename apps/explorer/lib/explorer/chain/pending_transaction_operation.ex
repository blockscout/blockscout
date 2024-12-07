defmodule Explorer.Chain.PendingTransactionOperation do
  @moduledoc """
  Tracks a transaction that has pending operations.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Repo

  @required_attrs ~w(transaction_hash)a

  @typedoc """
   * `transaction_hash` - the hash of the transaction that has pending operations.
  """
  @primary_key false
  typed_schema "pending_transaction_operations" do
    timestamps()

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
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
  end

  @doc """
    Returns the count of pending blocks in provided range
    (between `from_block_number` and `to_block_number`).
  """
  @spec blocks_count_in_range(integer(), integer()) :: integer()
  def blocks_count_in_range(from_block_number, to_block_number) when from_block_number <= to_block_number do
    __MODULE__
    |> join(:inner, [pto], t in assoc(pto, :transaction))
    |> where([_pto, t], t.block_number >= ^from_block_number)
    |> where([_pto, t], t.block_number <= ^to_block_number)
    |> select([_pto, t], count(t.block_number, :distinct))
    |> Repo.one()
  end
end
