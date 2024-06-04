defmodule Explorer.Chain.Celo.ActivatedValidatorGroupVote do
  @moduledoc """
  Stores the information about a vote for a validator group made by an account.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash}

  @required_attrs ~w(account_address_hash validator_group_address_hash)a

  @typedoc """
  * `account_address_hash` - the address of the account that made the vote.
  * `validator_group_address_hash` - the address of the validator group that
     was voted for.
  * `block_hash` - the hash of the block where the vote was included.
  """
  typed_schema "celo_activated_validator_group_votes" do
    belongs_to(
      :account_address,
      Address,
      foreign_key: :account_address_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :validator_group_address,
      Address,
      foreign_key: :validator_group_address_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :block,
      Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    timestamps()
  end

  @spec changeset(
          Explorer.Chain.Celo.ActivatedValidatorGroupVote.t(),
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = vote, attrs \\ %{}) do
    vote
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:account_address_hash)
    |> foreign_key_constraint(:validator_group_address_hash)
    |> foreign_key_constraint(:block_hash)

    # todo: is it needed?
    # |> unique_constraint(
    #   [:account_address_hash, :validator_group_address_hash, :block_hash],
    #   name: :activated_validator_group_votes_pkey
    # )
  end
end
