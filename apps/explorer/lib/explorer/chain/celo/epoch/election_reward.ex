defmodule Explorer.Chain.Celo.Epoch.ElectionReward do
  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @types_enum [
    :voter,
    :validator,
    :group,
    :delegated_payment
  ]

  @required_attrs ~w(amount type block_hash account_hash associated_account_hash)a

  @primary_key false
  typed_schema "celo_epoch_election_rewards" do
    field(:amount, Wei, null: false)

    field(
      :type,
      Ecto.Enum,
      values: @types_enum,
      null: false,
      primary_key: true
    )

    belongs_to(
      :block,
      Block,
      primary_key: true,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    belongs_to(
      :account,
      Address,
      primary_key: true,
      foreign_key: :account_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(
      :associated_account,
      Address,
      foreign_key: :associated_account_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = rewards, attrs) do
    rewards
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:block_hash)

    # todo: do I need to set this unique constraint here? or it is redundant?
    # |> unique_constraint(
    #   [:block_hash, :account_hash, :type],
    #   name: :celo_epoch_election_rewards_pkey
    # )
  end
end
