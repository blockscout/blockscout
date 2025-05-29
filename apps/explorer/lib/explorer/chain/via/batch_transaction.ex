defmodule Explorer.Chain.Via.BatchTransaction do
  @moduledoc """
  Models a list of transactions related to a batch for Via.

  Changes in the schema should be reflected in the bulk import module:
  - Explorer.Chain.Import.Runner.Via.BatchTransactions

  Migrations:
  - Explorer.Repo.Via.Migrations.CreateViaTables
  - Explorer.Repo.Via.Migrations.RenameFieldInBatchTransactions
  """

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Transaction}
  alias Explorer.Chain.Via.TransactionBatch

  @required_attrs ~w(batch_number transaction_hash)a

  @typedoc """
    * `transaction_hash` - The hash of the rollup transaction.
    * `l2_transaction` - An instance of `Explorer.Chain.Transaction` referenced by `transaction_hash`.
    * `batch_number` - The number of the Via batch.
    * `batch` - An instance of `Explorer.Chain.Via.TransactionBatch` referenced by `batch_number`.
  """
  @primary_key false
  typed_schema "via_batch_l2_transactions" do
    belongs_to(:batch, TransactionBatch, foreign_key: :batch_number, references: :number, type: :integer)

    belongs_to(:l2_transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

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
    |> unique_constraint(:transaction_hash)
  end
end
