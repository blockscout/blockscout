defmodule Explorer.Chain.Arbitrum.LifecycleTransaction do
  @moduledoc """
    Models an L1 lifecycle transaction for Arbitrum. Lifecycle transactions are transactions that change the state of transactions and blocks on Arbitrum rollups.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.LifecycleTransactions

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables
  """

  use Explorer.Schema

  alias Explorer.Chain.Hash

  alias Explorer.Chain.Arbitrum.{BatchBlock, L1Batch}

  @required_attrs ~w(id hash block_number timestamp status)a

  @typedoc """
  Descriptor of the L1 transaction changing state of transactions and blocks of Arbitrum rollups:
    * `id` - The ID of the transaction used for referencing.
    * `hash` - The hash of the L1 transaction.
    * `block_number` - The number of the L1 block where the transaction is included.
    * `timestamp` - The timestamp of the block in which the transaction is included.
    * `status` - The status of the transaction: `:unfinalized` or `:finalized`
  """
  @type to_import :: %{
          :id => non_neg_integer(),
          :hash => binary(),
          :block_number => non_neg_integer(),
          :timestamp => DateTime.t(),
          :status => :unfinalized | :finalized
        }

  @typedoc """
    * `id` - The ID of the transaction used for referencing.
    * `hash` - The hash of the L1 transaction.
    * `block_number` - The number of the L1 block where the transaction is included.
    * `timestamp` - The timestamp of the block in which the transaction is included.
    * `status` - The status of the transaction: `:unfinalized` or `:finalized`.
    * `committed_batches` - A list of `Explorer.Chain.Arbitrum.L1Batch` instances
                            that are committed by the transaction.
    * `confirmed_blocks` - A list of `Explorer.Chain.Arbitrum.BatchBlock` instances
                           that are confirmed by the transaction.
  """
  @primary_key {:id, :integer, autogenerate: false}
  typed_schema "arbitrum_lifecycle_l1_transactions" do
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
