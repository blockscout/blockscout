defmodule Explorer.Chain.Celo.ElectionReward do
  @moduledoc """
  Represents the rewards distributed in an epoch election.
  """
  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Wei}

  @types_enum ~w(voter validator group delegated_payment)a

  @required_attrs ~w(amount type block_hash account_address_hash associated_account_address_hash)a

  @primary_key false
  typed_schema "celo_election_rewards" do
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
      :account_address,
      Address,
      primary_key: true,
      foreign_key: :account_address_hash,
      references: :hash,
      type: Hash.Address,
      null: false
    )

    belongs_to(
      :associated_account_address,
      Address,
      primary_key: true,
      foreign_key: :associated_account_address_hash,
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
    |> foreign_key_constraint(:account_address_hash)
    |> foreign_key_constraint(:associated_account_address_hash)

    # todo: do I need to set this unique constraint here? or it is redundant?
    # |> unique_constraint(
    #   [:block_hash, :type, :account_address_hash, :associated_account_address_hash],
    #   name: :celo_election_rewards_pkey
    # )
  end

  @spec block_hash_to_aggregated_rewards_by_type_query(Hash.Full.t()) :: Ecto.Query.t()
  def block_hash_to_aggregated_rewards_by_type_query(block_hash) do
    from(
      r in __MODULE__,
      where: r.block_hash == ^block_hash,
      select: {r.type, sum(r.amount)},
      group_by: r.type
    )
  end
end
