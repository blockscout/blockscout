# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Arbitrum.BatchBlock do
  @moduledoc """
    Models a list of blocks related to a batch for Arbitrum.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.BatchBlocks

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumTables

    The column `confirmation_id` of the table is not a field of the schema. The
    background migration `Explorer.Migrator.HeavyDbIndexOperation.RemoveArbitrumBatchL2BlocksConfirmationId`
    removes the column. The confirmations of rollup blocks live in
    `Explorer.Chain.Arbitrum.RollupBlockConfirmation`.
  """

  use Explorer.Schema

  alias Explorer.Chain.Arbitrum.L1Batch

  @required_attrs ~w(batch_number block_number)a

  @typedoc """
  Descriptor of the rollup block included in an Arbitrum batch:
    * `batch_number` - The number of the Arbitrum batch.
    * `block_number` - The number of the rollup block.
  """
  @type to_import :: %{
          :batch_number => non_neg_integer(),
          :block_number => non_neg_integer()
        }

  @typedoc """
    * `block_number` - The number of the rollup block.
    * `batch_number` - The number of the Arbitrum batch.
    * `batch` - An instance of `Explorer.Chain.Arbitrum.L1Batch` referenced by `batch_number`.
  """
  @primary_key {:block_number, :integer, autogenerate: false}
  typed_schema "arbitrum_batch_l2_blocks" do
    belongs_to(:batch, L1Batch, foreign_key: :batch_number, references: :number, type: :integer)

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = items, attrs \\ %{}) do
    items
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:batch_number)
    |> unique_constraint(:block_number)
  end
end
