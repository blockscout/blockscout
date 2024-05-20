defmodule Explorer.Chain.Arbitrum.LifecycleTransaction do
  @moduledoc """
    Models an L1 lifecycle transaction for Arbitrum.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.LifecycleTransactions

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables
  """

  use Explorer.Schema

  alias Explorer.Chain.{
    Block,
    Hash
  }

  alias Explorer.Chain.Arbitrum.{BatchBlock, L1Batch}

  @required_attrs ~w(id hash block_number timestamp status)a

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          hash: Hash.t(),
          block_number: Block.block_number(),
          timestamp: DateTime.t(),
          status: String.t()
        }

  @primary_key {:id, :integer, autogenerate: false}
  schema "arbitrum_lifecycle_l1_transactions" do
    field(:hash, Hash.Full)
    field(:block_number, :integer)
    field(:timestamp, :utc_datetime_usec)
    field(:status, Ecto.Enum, values: [:unfinalized, :finalized])

    has_many(:committed_batches, L1Batch, foreign_key: :commitment_id)
    has_many(:confirmed_blocks, BatchBlock, foreign_key: :confirmation_id)

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
    |> unique_constraint([:id, :hash])
  end
end
