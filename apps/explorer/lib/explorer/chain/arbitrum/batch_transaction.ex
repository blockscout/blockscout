defmodule Explorer.Chain.Arbitrum.BatchTransaction do
  @moduledoc "Models a list of transactions related to a batch for Arbitrum."

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Chain.Arbitrum.{BatchBlock, L1Batch}

  @required_attrs ~w(batch_number block_hash hash)a

  @type t :: %__MODULE__{
          batch_number: non_neg_integer(),
          batch: %Ecto.Association.NotLoaded{} | L1Batch.t() | nil,
          block_hash: Hash.t(),
          block: %Ecto.Association.NotLoaded{} | BatchBlock.t() | nil,
          hash: Hash.t(),
          l2_transaction: %Ecto.Association.NotLoaded{} | Transaction.t() | nil
        }

  @primary_key false
  schema "arbitrum_batch_l2_transactions" do
    belongs_to(:batch, L1Batch, foreign_key: :batch_number, references: :number, type: :integer)
    belongs_to(:block, BatchBlock, foreign_key: :block_hash, references: :hash, type: Hash.Full)
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
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:hash)
  end
end
