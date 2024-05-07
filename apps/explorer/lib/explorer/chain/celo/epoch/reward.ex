defmodule Explorer.Chain.Celo.Epoch.Reward do
  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash, Wei}

  @required_attrs ~w(block_hash reserve_bolster per_validator voters_total community_total carbon_offsetting_total)a

  @primary_key false
  typed_schema "celo_epoch_rewards" do
    field(:reserve_bolster, Wei, null: false)
    field(:per_validator, Wei, null: false)
    field(:voters_total, Wei, null: false)
    field(:community_total, Wei, null: false)
    field(:carbon_offsetting_total, Wei, null: false)

    belongs_to(
      :block,
      Block,
      primary_key: true,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = rewards, attrs) do
    rewards
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)
    |> unique_constraint(:block_hash, name: :celo_epoch_rewards_pkey)
  end
end
