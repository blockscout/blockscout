defmodule Explorer.Chain.PolygonZkevm.TransactionBatch do
  @moduledoc "Models a batch of transactions for zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.Hash
  alias Explorer.Chain.PolygonZkevm.{BatchTransaction, LifecycleTransaction}

  @optional_attrs ~w(timestamp sequence_id verify_id)a

  @required_attrs ~w(number l2_transactions_count global_exit_root acc_input_hash state_root)a

  @primary_key false
  typed_schema "polygon_zkevm_transaction_batches" do
    field(:number, :integer, primary_key: true, null: false)
    field(:timestamp, :utc_datetime_usec)
    field(:l2_transactions_count, :integer)
    field(:global_exit_root, Hash.Full)
    field(:acc_input_hash, Hash.Full)
    field(:state_root, Hash.Full)

    belongs_to(:sequence_transaction, LifecycleTransaction,
      foreign_key: :sequence_id,
      references: :id,
      type: :integer
    )

    belongs_to(:verify_transaction, LifecycleTransaction, foreign_key: :verify_id, references: :id, type: :integer)

    has_many(:l2_transactions, BatchTransaction, foreign_key: :batch_number, references: :number)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:sequence_id)
    |> foreign_key_constraint(:verify_id)
    |> unique_constraint(:number)
  end
end
