defmodule Explorer.Chain.Zkevm.BatchTransaction do
  @moduledoc "Models a list of transactions related to a batch for zkEVM."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Chain.Zkevm.TransactionBatch

  @required_attrs ~w(batch_number hash)a

  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          batch: %Ecto.Association.NotLoaded{} | TransactionBatch.t() | nil,
          hash: Hash.t(),
          l2_transaction: %Ecto.Association.NotLoaded{} | Transaction.t() | nil
        }

  @primary_key false
  schema "zkevm_batch_l2_transactions" do
    belongs_to(:batch, TransactionBatch, foreign_key: :batch_number, references: :number, type: :integer)
    belongs_to(:l2_transaction, Transaction, foreign_key: :hash, primary_key: true, references: :hash, type: Hash.Full)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = transactions, attrs \\ %{}) do
    transactions
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:batch_number)
    |> unique_constraint(:hash)
  end
end
