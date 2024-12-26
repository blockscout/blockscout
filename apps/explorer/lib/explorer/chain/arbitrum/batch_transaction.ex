defmodule Explorer.Chain.Arbitrum.BatchTransaction do
  @moduledoc """
    Models a list of transactions related to a batch for Arbitrum.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.BatchTransactions

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables
  """

  use Explorer.Schema

  alias Explorer.Chain.Arbitrum.L1Batch
  alias Explorer.Chain.{Hash, Transaction}

  @required_attrs ~w(batch_number transaction_hash)a

  @typedoc """
  Descriptor of the rollup transaction included in an Arbitrum batch:
    * `batch_number` - The number of the Arbitrum batch.
    * `transaction_hash` - The hash of the rollup transaction.
  """
  @type to_import :: %{
          :batch_number => non_neg_integer(),
          :transaction_hash => binary()
        }

  @typedoc """
    * `transaction_hash` - The hash of the rollup transaction.
    * `l2_transaction` - An instance of `Explorer.Chain.Transaction` referenced by `transaction_hash`.
    * `batch_number` - The number of the Arbitrum batch.
    * `batch` - An instance of `Explorer.Chain.Arbitrum.L1Batch` referenced by `batch_number`.
  """
  @primary_key false
  typed_schema "arbitrum_batch_l2_transactions" do
    belongs_to(:batch, L1Batch, foreign_key: :batch_number, references: :number, type: :integer)

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
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:transaction_hash)
  end
end
