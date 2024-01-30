defmodule Explorer.Chain.Zkevm.LifecycleTransaction do
  @moduledoc "Models an L1 lifecycle transaction for zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Chain.Zkevm.TransactionBatch

  @required_attrs ~w(id hash is_verify)a

  @type t :: %__MODULE__{
          hash: Hash.t(),
          is_verify: boolean()
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "zkevm_lifecycle_l1_transactions" do
    field(:hash, Hash.Full)
    field(:is_verify, :boolean)

    has_many(:sequenced_batches, TransactionBatch, foreign_key: :sequence_id)
    has_many(:verified_batches, TransactionBatch, foreign_key: :verify_id)

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
