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

  alias Explorer.Chain.Hash

  alias Explorer.Chain.Arbitrum.LifecycleTransaction

  @optional_attrs ~w(batch_container)a

  @required_attrs ~w(number transactions_count start_block end_block before_acc after_acc commitment_id)a

  @allowed_attrs @optional_attrs ++ @required_attrs

  @typedoc """
  Descriptor of the L1 batch for Arbitrum rollups:
    * `number` - The number of the Arbitrum batch.
    * `transactions_count` - The number of transactions in the batch.
    * `start_block` - The number of the first block in the batch.
    * `end_block` - The number of the last block in the batch.
    * `before_acc` - The hash of the state before the batch.
    * `after_acc` - The hash of the state after the batch.
    * `commitment_id` - The ID of the commitment L1 transaction from Explorer.Chain.Arbitrum.LifecycleTransaction.
    * `batch_container` - The tag meaning the container of the batch data: `:in_blob4844`, `:in_calldata`, `:in_celestia`, `:in_anytrust`
  """
  @type to_import :: %{
          number: non_neg_integer(),
          transactions_count: non_neg_integer(),
          start_block: non_neg_integer(),
          end_block: non_neg_integer(),
          before_acc: binary(),
          after_acc: binary(),
          commitment_id: non_neg_integer(),
          batch_container: :in_blob4844 | :in_calldata | :in_celestia | :in_anytrust
        }

  @typedoc """
    * `number` - The number of the Arbitrum batch.
    * `transactions_count` - The number of transactions in the batch.
    * `start_block` - The number of the first block in the batch.
    * `end_block` - The number of the last block in the batch.
    * `before_acc` - The hash of the state before the batch.
    * `after_acc` - The hash of the state after the batch.
    * `commitment_id` - The ID of the commitment L1 transaction from `Explorer.Chain.Arbitrum.LifecycleTransaction`.
    * `commitment_transaction` - An instance of `Explorer.Chain.Arbitrum.LifecycleTransaction` referenced by `commitment_id`.
    * `batch_container` - The tag meaning the container of the batch data: `:in_blob4844`, `:in_calldata`, `:in_celestia`, `:in_anytrust`
  """
  @primary_key {:number, :integer, autogenerate: false}
  typed_schema "arbitrum_l1_batches" do
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
