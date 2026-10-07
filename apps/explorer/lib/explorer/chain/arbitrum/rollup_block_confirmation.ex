# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Arbitrum.RollupBlockConfirmation do
  @moduledoc """
    Models one confirmation of rollup blocks for Arbitrum.

    A confirmation is one `SendRootUpdated` event of the Arbitrum `Outbox` contract
    on the parent chain. The event names the rollup block `top`. It confirms this
    block and all rollup blocks below it.

    The table stores only `top` of each confirmation. The order of `top` gives the
    rollup blocks of each row: a row owns the rollup blocks above the `top` of the
    row below it, up to its own `top`. The lowest row owns the blocks from 0.
    Thus a rollup block `rb` is confirmed if a row with `top >= rb` exists, and the
    row with the lowest such `top` holds the confirmation transaction of `rb`.

    Changes in the schema should be reflected in the bulk import module:
    - Explorer.Chain.Import.Runner.Arbitrum.RollupBlockConfirmations

    Migrations:
    - Explorer.Repo.Arbitrum.Migrations.CreateArbitrumRollupBlockConfirmations
  """

  use Explorer.Schema

  alias Explorer.Chain.Arbitrum.LifecycleTransaction

  @required_attrs ~w(top confirmation_id)a

  @typedoc """
  Descriptor of a confirmation of rollup blocks:
    * `top` - The number of the highest rollup block that the confirmation confirms.
    * `confirmation_id` - The ID of the confirmation L1 transaction from
                          `Explorer.Chain.Arbitrum.LifecycleTransaction`.
  """
  @type to_import :: %{
          :top => non_neg_integer(),
          :confirmation_id => non_neg_integer()
        }

  @typedoc """
    * `top` - The number of the highest rollup block that the confirmation confirms.
    * `confirmation_id` - The ID of the confirmation L1 transaction from
                          `Explorer.Chain.Arbitrum.LifecycleTransaction`.
    * `confirmation_transaction` - An instance of `Explorer.Chain.Arbitrum.LifecycleTransaction`
                                   referenced by `confirmation_id`.
  """
  @primary_key {:top, :integer, autogenerate: false}
  typed_schema "arbitrum_rollup_block_confirmations" do
    belongs_to(:confirmation_transaction, LifecycleTransaction,
      foreign_key: :confirmation_id,
      references: :id,
      type: :integer
    )

    timestamps()
  end

  @doc """
    Validates that the `attrs` are valid.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Schema.t()
  def changeset(%__MODULE__{} = confirmation, attrs \\ %{}) do
    confirmation
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:confirmation_id)
    |> unique_constraint(:top)
  end
end
