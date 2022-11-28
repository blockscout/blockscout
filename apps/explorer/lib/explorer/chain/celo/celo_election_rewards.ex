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

  alias Explorer.Celo.EpochUtil
  alias Explorer.Chain.{Block, CeloAccount, CeloAccountEpoch, Hash, Wei}
  alias Explorer.Repo

  @required_attrs ~w(account_hash amount associated_account_hash block_number block_timestamp block_hash reward_type)a

  @typedoc """
   * `account_hash` - the hash of the celo account that received the rewards.
   * `amount` - the reward amount the account receives for a specific epoch.
   * `associated_account_hash` - the hash of the associated celo account. in the case of voter and validator rewards,
    the associated account is a validator group and in the case of validator group rewards, it is a validator.
   * `block_number` - the number of the block.
   * `block_timestamp` - the timestamp of the block.
   * `block_hash` - the hash of the block.
   * `reward_type` - can be voter, validator or validator group. please note that validators and validator groups can
    themselves vote so it's possible for an account to get both voter and validator rewards for an epoch.
  """
  @type t :: %__MODULE__{
          account_hash: Hash.Address.t(),
          amount: Wei.t(),
          associated_account_hash: Hash.Address.t(),
          block_number: integer,
          block_timestamp: DateTime.t(),
          block_hash: Hash.Full.t(),
          reward_type: String.t()
        }

  @sample_epoch_block_voter_rewards_limit 20

  @primary_key false
  schema "celo_election_rewards" do
    field(:amount, Wei)
    field(:block_number, :integer)
    field(:block_timestamp, :utc_datetime_usec)
    field(:reward_type, :string)

    timestamps()

    belongs_to(:block, Block,
      foreign_key: :block_hash,
      primary_key: true,
      references: :hash,
      type: Hash.Full
    )

    belongs_to(:address, Explorer.Chain.Address,
      foreign_key: :account_hash,
      references: :hash,
      type: Hash.Address
    )

    belongs_to(:associated_address, Explorer.Chain.Address,
      foreign_key: :associated_account_hash,
      references: :hash,
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
    from(rewards in __MODULE__,
      group_by: rewards.reward_type,
      where: rewards.block_number == ^block_number,
      where: rewards.reward_type in ^reward_types
    )
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

  def base_api_address_query do
    from(rewards in __MODULE__,
      left_join: celo_account_epoch in CeloAccountEpoch,
      on:
        rewards.account_hash == celo_account_epoch.account_hash and
          celo_account_epoch.block_hash == rewards.block_hash,
      select: %{
        block_hash: rewards.block_hash,
        block_number: rewards.block_number,
        epoch_number: fragment("? / 17280", rewards.block_number),
        account_hash: rewards.account_hash,
        account_locked_gold: celo_account_epoch.total_locked_gold,
        account_activated_gold:
          fragment(
            "? - ?",
            celo_account_epoch.total_locked_gold,
            celo_account_epoch.nonvoting_locked_gold
          ),
        associated_account_hash: rewards.associated_account_hash,
        date: rewards.block_timestamp,
        amount: rewards.amount
      },
      order_by: [
        desc: rewards.block_number,
        asc: rewards.reward_type,
        asc: rewards.account_hash,
        asc: rewards.associated_account_hash
      ]
    )
  end

  def base_sum_and_count_rewards_api_address_query do
    from(rewards in __MODULE__,
      select: %{
        sum: fragment("COALESCE(SUM(?), 0)", rewards.amount),
        count: fragment("COUNT(*)")
      }
    )
  end

  defp account_hash_query(query, [account_hash]), do: query |> where([rewards], rewards.account_hash == ^account_hash)

  defp account_hash_query(query, account_hash_list),
    do: query |> where([rewards], rewards.account_hash in ^account_hash_list)

  defp reward_type_query(query, reward_type), do: query |> where([rewards], rewards.reward_type == ^reward_type)

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

  def get_epoch_rewards(
        reward_type,
        account_hash_list,
        associated_account_hash_list,
        page_number,
        page_size,
        opts \\ []
      ) do
    query = base_api_address_query()
    total_query = base_sum_and_count_rewards_api_address_query()
    offset = (page_number - 1) * page_size

    block_number_from = Keyword.get(opts, :block_number_from)
    block_number_to = Keyword.get(opts, :block_number_to)
    date_from = Keyword.get(opts, :date_from)
    date_to = Keyword.get(opts, :date_to)
    block_number_from_rounded = block_number_from |> EpochUtil.round_to_closest_epoch_block_number(:up)
    block_number_to_rounded = block_number_to |> EpochUtil.round_to_closest_epoch_block_number(:down)

    rewards =
      query
      |> block_number_query(block_number_from_rounded, block_number_to_rounded)
      |> block_timestamp_query(date_from, date_to)
      |> reward_type_query(reward_type)
      |> account_hash_query(account_hash_list)
      |> group_address_hash_query(associated_account_hash_list)
      |> offset(^offset)
      |> limit(^page_size)
      |> Repo.all()

    total =
      total_query
      |> block_number_query(block_number_from_rounded, block_number_to_rounded)
      |> block_timestamp_query(Keyword.get(opts, :date_from), Keyword.get(opts, :date_to))
      |> reward_type_query(reward_type)
      |> account_hash_query(account_hash_list)
      |> group_address_hash_query(associated_account_hash_list)
      |> Repo.one()

    {:ok, total_amount} = Wei.cast(total.sum)

    %{
      rewards: rewards,
      total_amount: total_amount,
      total_count: total.count,
      blockNumberFrom: block_number_from,
      blockNumberTo: block_number_to,
      dateFrom: date_from,
      dateTo: date_to
    }
  end

  defp block_timestamp_query_from(query, nil = _from), do: query
  defp block_timestamp_query_from(query, from), do: query |> where([rewards], rewards.block_timestamp >= ^from)

  defp block_timestamp_query_to(query, nil = _to), do: query
  defp block_timestamp_query_to(query, to), do: query |> where([rewards], rewards.block_timestamp <= ^to)

  defp block_number_query_from(query, nil = _from), do: query
  defp block_number_query_from(query, from), do: query |> where([rewards], rewards.block_number >= ^from)

  defp block_number_query_to(query, nil = _to), do: query
  defp block_number_query_to(query, to), do: query |> where([rewards], rewards.block_number <= ^to)

  defp block_timestamp_query(query, from, to),
    do: query |> block_timestamp_query_from(from) |> block_timestamp_query_to(to)

  defp block_number_query(query, from, to), do: query |> block_number_query_from(from) |> block_number_query_to(to)

  defp group_address_hash_query(query, []), do: query

  defp group_address_hash_query(query, group_address_list) when is_list(group_address_list) do
    query |> where([rewards], rewards.associated_account_hash in ^group_address_list)
  end

  defp group_address_hash_query(query, _), do: query

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
    voter_rewards = get_sample_rewards_for_block_number(block_number, "voter", @sample_epoch_block_voter_rewards_limit)
    validator_rewards = get_sample_rewards_for_block_number(block_number, "validator")
    group_rewards = get_sample_rewards_for_block_number(block_number, "group")

    %{
      voter: voter_rewards,
      validator: validator_rewards,
      group: group_rewards
    }
  end

  defp base_sample_rewards_for_block_number(block_number, reward_type) do
    from(reward in __MODULE__,
      preload: [:address, :associated_address],
      order_by: [desc: reward.amount],
      where: reward.block_number == ^block_number,
      where: reward.reward_type == ^reward_type
    )
  end

  defp get_sample_rewards_for_block_number(block_number, reward_type) do
    query = base_sample_rewards_for_block_number(block_number, reward_type)

    query
    |> where_non_zero_reward()
    |> Repo.all()
  end

  defp get_sample_rewards_for_block_number(block_number, reward_type, limit) do
    query = base_sample_rewards_for_block_number(block_number, reward_type)

    query
    |> limit(^limit)
    |> where_non_zero_reward()
    |> Repo.all()
  end

  defp where_non_zero_reward(query), do: query |> where([reward], reward.amount > ^%Wei{value: Decimal.new(0)})

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
