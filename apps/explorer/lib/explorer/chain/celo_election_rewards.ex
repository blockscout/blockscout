defmodule Explorer.Chain.CeloElectionRewards do
  @moduledoc """
  Holds voter, validator and validator group rewards for each epoch.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Hash, Wei}

  @required_attrs ~w(account_hash amount associated_account_hash block_number block_timestamp reward_type)a

  @typedoc """
   * `account_hash` - the hash of the celo account that received the rewards.
   * `amount` - the reward amount the account receives for a specific epoch.
   * `associated_account_hash` - the hash of the associated celo account. in the case of voter and validator rewards,
    the associated account is a validator group and in the case of validator group rewards, it is a validator.
   * `block_number` - the number of the block.
   * `block_timestamp` - the timestamp of the block.
   * `reward_type` - can be voter, validator or validator group. please note that validators and validator groups can
    themselves vote so it's possible for an account to get both voter and validator rewards for an epoch.
  """
  @type t :: %__MODULE__{
          account_hash: Hash.Address.t(),
          amount: Wei.t(),
          associated_account_hash: Hash.Address.t(),
          block_number: integer,
          block_timestamp: DateTime.t(),
          reward_type: String.t()
        }

  @primary_key false
  schema "celo_election_rewards" do
    field(:amount, Wei)
    field(:block_number, :integer)
    field(:block_timestamp, :utc_datetime_usec)
    field(:reward_type, :string)

    timestamps()

    belongs_to(:addresses, Explorer.Chain.Address,
      foreign_key: :account_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:celo_account, Explorer.Chain.Address,
      foreign_key: :associated_account_hash,
      references: :address,
      type: Hash.Address
    )
  end

  def changeset(%__MODULE__{} = celo_election_rewards, attrs) do
    celo_election_rewards
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:account_hash)
    |> unique_constraint(
      [:account_hash, :reward_type, :block_number, :associated_account_hash],
      name: :celo_election_rewards_account_hash_block_number_reward_type
    )
  end
end
