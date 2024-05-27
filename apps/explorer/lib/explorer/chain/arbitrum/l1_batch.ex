defmodule Explorer.Chain.Arbitrum.L1Batch do
  @moduledoc """
    Models an L1 batch for Arbitrum.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.L1Batches

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables
    - Explorer.Repo.Arbitrum.Migrations.AddDaInfo
  """

  use Explorer.Schema

  alias Explorer.Chain.{
    Block,
    Hash
  }

  alias Explorer.Chain.Arbitrum.LifecycleTransaction

  @optional_attrs ~w(batch_container)a

  @required_attrs ~w(number transactions_count start_block end_block before_acc after_acc commitment_id)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @type t :: %__MODULE__{
          number: non_neg_integer(),
          transactions_count: non_neg_integer(),
          start_block: Block.block_number(),
          end_block: Block.block_number(),
          before_acc: Hash.t(),
          after_acc: Hash.t(),
          commitment_id: non_neg_integer(),
          commitment_transaction: %Ecto.Association.NotLoaded{} | LifecycleTransaction.t() | nil,
          batch_container: String.t()
        }

  @primary_key {:number, :integer, autogenerate: false}
  schema "arbitrum_l1_batches" do
    field(:transactions_count, :integer)
    field(:start_block, :integer)
    field(:end_block, :integer)
    field(:before_acc, Hash.Full)
    field(:after_acc, Hash.Full)

    belongs_to(:commitment_transaction, LifecycleTransaction,
      foreign_key: :commitment_id,
      references: :id,
      type: :integer
    )

    field(:batch_container, Ecto.Enum, values: [:in_blob4844, :in_calldata, :in_celestia, :in_anytrust])

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = batches, attrs \\ %{}) do
    batches
    |> cast(attrs, @allowed_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:commitment_id)
    |> unique_constraint(:number)
  end
end
