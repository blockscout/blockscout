defmodule Explorer.Chain.CeloElectionRewards do
  @moduledoc """
  Holds voter, validator and validator group rewards for each epoch.
  """

  use Explorer.Schema

  import Ecto.Query,
    only: [
      select: 3,
      from: 2,
      limit: 2,
      offset: 2,
      where: 3
    ]

  alias Explorer.Chain.{CeloAccount, Hash, Wei}
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

  @sample_epoch_block_transaction_limit 20

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

    belongs_to(:celo_account, Explorer.Chain.CeloAccount,
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

  def base_aggregated_block_query(block_number, reward_types) do
    query =
      from(rewards in __MODULE__,
        group_by: rewards.block_number,
        group_by: rewards.reward_type,
        where: rewards.block_number == ^block_number,
        where: rewards.reward_type in ^reward_types
      )

    query |> where_non_zero_reward()
  end

  def aggregated_voter_and_validator_query(block_number) do
    query = base_aggregated_block_query(block_number, ["validator", "voter"])

    query
    |> select([rewards], %{
      reward_type: rewards.reward_type,
      amount: sum(rewards.amount),
      count: count()
    })
  end

  def aggregated_validator_group_query(block_number) do
    query = base_aggregated_block_query(block_number, ["group"])

    query
    |> select([rewards], %{
      reward_type: rewards.reward_type,
      amount: sum(rewards.amount),
      validator_count: fragment("COUNT(DISTINCT(associated_account_hash))"),
      group_count: fragment("COUNT(DISTINCT(account_hash))"),
      count: count()
    })
  end

  def get_aggregated_for_block_number(block_number) do
    validator_group_query = aggregated_validator_group_query(block_number)
    voter_and_validator_query = aggregated_voter_and_validator_query(block_number)

    aggregated_validator_group = validator_group_query |> Repo.one()
    default = %{group: aggregated_validator_group, voter: nil, validator: nil}

    voter_and_validator_query
    |> Repo.all()
    |> Enum.into(default, fn rewards -> {String.to_existing_atom(rewards.reward_type), rewards} end)
  end

  def base_address_query(account_hash_list, reward_type_list) do
    query =
      from(rewards in __MODULE__,
        join: acc in CeloAccount,
        on: rewards.associated_account_hash == acc.address,
        select: %{
          account_hash: rewards.account_hash,
          amount: rewards.amount,
          associated_account_name: acc.name,
          associated_account_hash: rewards.associated_account_hash,
          block_number: rewards.block_number,
          date: rewards.block_timestamp,
          epoch_number: fragment("? / 17280", rewards.block_number),
          reward_type: rewards.reward_type
        },
        order_by: [desc: rewards.block_number, asc: rewards.reward_type],
        where: rewards.account_hash in ^account_hash_list,
        where: rewards.reward_type in ^reward_type_list
      )

    query |> where_non_zero_reward()
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
    query = base_address_query(account_hash_list, reward_type_list)

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

  def get_paginated_rewards_for_address(account_hash_list, reward_type_list, pagination_params) do
    {items_count, page_size} = extract_pagination_params(pagination_params)

    query = base_address_query(account_hash_list, reward_type_list)

    query |> limit(^page_size) |> offset(^items_count) |> Repo.all()
  end

  def get_voter_rewards_for_group(voter_hash_list, group_hash_list) do
    base_address_query = base_address_query(voter_hash_list, ["voter"])

    rewards =
      base_address_query
      |> where([rewards], rewards.associated_account_hash in ^group_hash_list)
      |> Repo.all()

    {:ok, zero_wei} = Wei.cast(0)
    %{rewards: rewards, total: Enum.reduce(rewards, zero_wei, fn curr, acc -> Wei.sum(curr.amount, acc) end)}
  end

  def sum_query(account_hash) do
    from(reward in __MODULE__, select: sum(reward.amount), where: reward.account_hash == ^account_hash)
  end

  def get_rewards_sum_for_account(account_hash) do
    query = sum_query(account_hash)

    Repo.one!(query)
  end

  def get_rewards_sums_for_account(account_hash, type) do
    sum_query = sum_query(account_hash)

    voting_sum =
      sum_query
      |> where([reward], reward.reward_type == "voter")
      |> Repo.one!()

    validator_or_group_sum =
      sum_query
      |> where([reward], reward.reward_type == ^type)
      |> Repo.one!()

    {:ok, zero_wei} = Wei.cast(0)
    {validator_or_group_sum, voting_sum || zero_wei}
  end

  def get_sample_rewards_for_block_number(block_number) do
    voter_rewards = get_sample_rewards_for_block_number(block_number, "voter")
    validator_rewards = get_sample_rewards_for_block_number(block_number, "validator")
    group_rewards = get_sample_rewards_for_block_number(block_number, "group")

    %{
      voter: voter_rewards,
      validator: validator_rewards,
      group: group_rewards
    }
  end

  defp get_sample_rewards_for_block_number(block_number, reward_type) do
    query =
      from(reward in __MODULE__,
        select: %{
          account_hash: reward.account_hash,
          amount: reward.amount,
          associated_account_hash: reward.associated_account_hash
        },
        order_by: [desc: reward.amount],
        where: reward.block_number == ^block_number,
        where: reward.reward_type == ^reward_type,
        limit: @sample_epoch_block_transaction_limit
      )

    query
    |> where_non_zero_reward()
    |> Repo.all()
  end

  defp where_non_zero_reward(query), do: query |> where([reward], reward.amount != ^%Wei{value: Decimal.new(0)})

  def get_epoch_transaction_count_for_block(block_number) do
    query = from(reward in __MODULE__, select: count(fragment("*")), where: reward.block_number == ^block_number)

    Repo.one!(query)
  end

  defp extract_pagination_params(pagination_params) do
    items_count_string = Map.get(pagination_params, "items_count", "0")
    {items_count, _} = items_count_string |> Integer.parse()
    page_size = Map.get(pagination_params, "page_size")

    {items_count, page_size}
  end
end
