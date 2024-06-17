defmodule Explorer.Chain.Celo.ValidatorGroupVote do
  @moduledoc """
  Stores the information about a vote for a validator group made by an account.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Hash, Wei}
  @types_enum ~w(activated revoked)a
  @required_attrs [
    :account_address_hash,
    :group_address_hash,
    :value,
    :units,
    :type,
    :transaction_hash,
    :block_hash,
    :block_number
  ]

  @typedoc """
  * `account_address_hash` - the address of the account that made the vote.
  * `group_address_hash` - the address of the validator group that
     was voted for.
  * `value` - the amount of votes.
  * `units` - the number of units of the vote.
  * `type` - whether this vote is `activated` or `revoked`.
  * `transaction_hash` - the hash of the transaction that made the vote.
  """
  @primary_key false
  typed_schema "celo_validator_group_votes" do
    belongs_to(
      :account_address,
      Address,
      foreign_key: :account_address_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(
      :group_address,
      Address,
      foreign_key: :group_address_hash,
      references: :hash,
      type: Hash.Address
    )

    field(:value, Wei, null: false)
    field(:units, Wei, null: false)

    field(:type, Ecto.Enum,
      values: @types_enum,
      null: false
    )

    field(:block_number, :integer, null: false)
    field(:block_hash, Hash.Full, null: false)

    field(:transaction_hash, Hash.Full, primary_key: true)

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
    |> foreign_key_constraint(:group_address_hash)

    # todo: is it needed?
    # |> unique_constraint(
    #   [:account_address_hash, :group_address_hash, :block_hash],
    #   name: :activated_validator_group_votes_pkey
    # )
  end
end
