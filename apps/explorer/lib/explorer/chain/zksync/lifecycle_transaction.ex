defmodule Explorer.Chain.ZkSync.LifecycleTransaction do
  @moduledoc "Models an L1 lifecycle transaction for ZkSync."

  use Explorer.Schema

  alias Explorer.Chain.Hash
  # alias Explorer.Chain.Zkevm.TransactionBatch

  @required_attrs ~w(id hash timestamp)a

  @type t :: %__MODULE__{
          hash: Hash.t(),
          timestamp: DateTime.t()
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "zksync_lifecycle_l1_transactions" do
    field(:hash, Hash.Full)
    field(:timestamp, :utc_datetime_usec)

    # has_many(:sequenced_batches, TransactionBatch, foreign_key: :sequence_id)
    # has_many(:verified_batches, TransactionBatch, foreign_key: :verify_id)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = txn, attrs \\ %{}) do
    txn
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end
end
