defmodule Explorer.Chain.PolygonZkevm.LifecycleTransaction do
  @moduledoc "Models an L1 lifecycle transaction for zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Chain.PolygonZkevm.TransactionBatch

  @required_attrs ~w(id hash is_verify)a

  @primary_key false
  typed_schema "polygon_zkevm_lifecycle_l1_transactions" do
    field(:id, :integer, primary_key: true, null: false)
    field(:hash, Hash.Full, null: false)
    field(:is_verify, :boolean, null: false)

    has_many(:sequenced_batches, TransactionBatch, foreign_key: :sequence_id, references: :id)
    has_many(:verified_batches, TransactionBatch, foreign_key: :verify_id, references: :id)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = transaction, attrs \\ %{}) do
    transaction
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:id)
  end
end
