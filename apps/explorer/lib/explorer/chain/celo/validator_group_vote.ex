defmodule Explorer.Chain.Celo.ValidatorGroupVote do
  @moduledoc """
  Represents the information about a vote for a validator group made by an
  account.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Block, Hash, Transaction}

  @types_enum ~w(activated revoked)a
  @required_attrs ~w(account_address_hash group_address_hash type transaction_hash block_hash block_number)a

  @typedoc """
  * `account_address_hash` - the address of the account that made the vote.
  * `group_address_hash` - the address of the validator group that
     was voted for.
  * `type` - whether this vote is `activated` or `revoked`.
  * `block_number` - the block number of the vote.
  * `block_hash` - the hash of the block that contains the vote.
  * `transaction_hash` - the hash of the transaction that made the vote.
  """
  @primary_key false
  typed_schema "celo_validator_group_votes" do
    belongs_to(:account_address, Address,
      foreign_key: :account_address_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:group_address, Address,
      foreign_key: :group_address_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Address
    )

    field(:type, Ecto.Enum,
      values: @types_enum,
      null: false
    )

    field(:block_number, :integer, null: false)

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    belongs_to(:transaction, Transaction,
      foreign_key: :transaction_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full,
      null: false
    )

    timestamps()
  end

  @spec changeset(
          __MODULE__.t(),
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any}
        ) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = vote, attrs \\ %{}) do
    vote
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:account_address_hash)
    |> foreign_key_constraint(:group_address_hash)
    |> foreign_key_constraint(:transaction_hash)
  end
end
