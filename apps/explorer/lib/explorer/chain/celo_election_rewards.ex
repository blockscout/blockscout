defmodule Explorer.Chain.CeloElectionRewards do
  @moduledoc """
  Holds voter, validator and validator group rewards for each epoch.
  """

  use Explorer.Schema

  import Ecto.Query,
    only: [
      from: 2,
      where: 3
    ]

  alias Explorer.Chain.{Hash, Wei}
  alias Explorer.Repo

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

  def base_query(account_hash_list, reward_type_list) do
    from(rewards in __MODULE__,
      select: %{
        account_hash: rewards.account_hash,
        amount: rewards.amount,
        associated_account_hash: rewards.associated_account_hash,
        block_number: rewards.block_number,
        date: rewards.block_timestamp,
        epoch_number: fragment("? / 17280", rewards.block_number),
        reward_type: rewards.reward_type
      },
      where: rewards.account_hash in ^account_hash_list,
      where: rewards.reward_type in ^reward_type_list
    )
  end

  def get_rewards(account_hash_list, reward_type_list, from, to) when from == nil and to == nil,
    do: get_rewards(account_hash_list, reward_type_list, ~U[2020-04-22 16:00:00.000000Z], DateTime.utc_now())

  def get_rewards(account_hash_list, reward_type_list, from, to) when from == nil,
    do: get_rewards(account_hash_list, reward_type_list, ~U[2020-04-22 16:00:00.000000Z], to)

  def get_rewards(account_hash_list, reward_type_list, from, to) when to == nil,
    do: get_rewards(account_hash_list, reward_type_list, from, DateTime.utc_now())

  def get_rewards(
        account_hash_list,
        reward_type_list,
        from,
        to
      ) do
    query = base_query(account_hash_list, reward_type_list)

    query_for_time_frame = query |> where([rewards], fragment("? BETWEEN ? AND ?", rewards.block_timestamp, ^from, ^to))

    rewards = query_for_time_frame |> Repo.all()

    {:ok, zero_wei} = Wei.cast(0)

    %{
      rewards: rewards,
      total_reward_celo: Enum.reduce(rewards, zero_wei, fn curr, acc -> Wei.sum(curr.amount, acc) end),
      from: from,
      to: to
    }
  end

  def get_voter_rewards_for_group(voter_hash_list, group_hash_list) do
    base_query = base_query(voter_hash_list, ["voter"])

    rewards =
      base_query
      |> where([rewards], rewards.associated_account_hash in ^group_hash_list)
      |> Repo.all()

    {:ok, zero_wei} = Wei.cast(0)
    %{rewards: rewards, total: Enum.reduce(rewards, zero_wei, fn curr, acc -> Wei.sum(curr.amount, acc) end)}
  end
end
