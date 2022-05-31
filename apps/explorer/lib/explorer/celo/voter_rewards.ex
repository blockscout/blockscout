defmodule Explorer.Celo.VoterRewards do
  @moduledoc """
    Module responsible for calculating a voter's rewards for all groups the voter has voted for.
  """
  import Explorer.Celo.Util,
    only: [
      add_input_account_to_individual_rewards_and_calculate_sum: 2
    ]

  import Ecto.Query,
    only: [
      distinct: 3,
      from: 2,
      order_by: 3,
      where: 3
    ]

  alias Explorer.Celo.ContractEvents
  alias Explorer.Chain.CeloContractEvent
  alias Explorer.Chain.Hash.Address
  alias Explorer.Repo

  alias ContractEvents.{Election, EventMap}

  alias Election.ValidatorGroupVoteActivatedEvent

  def calculate(voter_address_hash, from_date, to_date) do
    from_date =
      case from_date do
        nil -> ~U[2020-04-22 16:00:00.000000Z]
        from_date -> from_date
      end

    to_date =
      case to_date do
        nil -> DateTime.utc_now()
        to_date -> to_date
      end

    voter_rewards_for_group = Application.get_env(:explorer, :voter_rewards_for_group)
    validator_group_vote_activated = ValidatorGroupVoteActivatedEvent.topic()

    query =
      ValidatorGroupVoteActivatedEvent.query()
      |> distinct([event], [json_extract_path(event.params, ["voter"]), json_extract_path(event.params, ["group"])])
      |> order_by([event], event.block_number)
      |> where([event], event.topic == ^validator_group_vote_activated)

    validator_group_vote_activated_events =
      query
      |> CeloContractEvent.query_by_voter_param(voter_address_hash)
      |> Repo.all()
      |> EventMap.celo_contract_event_to_concrete_event()

    rewards_for_each_group =
      validator_group_vote_activated_events
      |> Enum.map(fn %ValidatorGroupVoteActivatedEvent{group: group} ->
        voter_rewards_for_group.calculate(voter_address_hash, group, to_date)
      end)

    structured_rewards_for_given_period =
      rewards_for_each_group
      |> Enum.map(fn %{group: group, rewards: rewards} ->
        Enum.map(rewards, &Map.put(&1, :group, group))
      end)
      |> List.flatten()
      |> Enum.filter(fn x -> DateTime.compare(x.date, from_date) != :lt end)
      |> Enum.map_reduce(0, fn x, acc -> {x, acc + x.amount} end)
      |> then(fn {rewards, total} ->
        %{
          from: from_date,
          rewards: rewards,
          to: to_date,
          total_reward_celo: total,
          account: voter_address_hash
        }
      end)

    structured_rewards_for_given_period
  end

  def calculate_multiple_accounts(voter_address_hash_list, from_date, to_date) do
    reward_lists_chunked_by_account =
      voter_address_hash_list
      |> Enum.map(fn hash -> calculate(hash, from_date, to_date) end)

    {rewards, rewards_sum} =
      add_input_account_to_individual_rewards_and_calculate_sum(reward_lists_chunked_by_account, :account)

    %{from: from_date, to: to_date, rewards: rewards, total_reward_celo: rewards_sum}
  end

  # The way we calculate voter rewards is by subtracting the previous epoch's last block's votes count from the current
  # epoch's first block's votes count. If the user activated or revoked votes in the previous epoch's last block, we
  # need to take that into consideration, namely subtract any activated and add any revoked votes.
  def subtract_activated_add_revoked(entry) do
    query =
      from(event in CeloContractEvent,
        select:
          fragment(
            "SUM(CAST(params->>'value' AS numeric) * CASE name WHEN ? THEN -1 ELSE 1 END)",
            ^"ValidatorGroupVoteActivated"
          ),
        where: event.name in ["ValidatorGroupVoteActivated", "ValidatorGroupActiveVoteRevoked"],
        where: event.block_number == ^entry.block_number
      )

    query
    |> CeloContractEvent.query_by_voter_param(entry.account_hash)
    |> CeloContractEvent.query_by_group_param(entry.group_hash)
    |> Repo.one()
    |> to_integer_if_not_nil()
  end

  defp to_integer_if_not_nil(nil), do: 0
  defp to_integer_if_not_nil(activated_or_revoked), do: Decimal.to_integer(activated_or_revoked)
end
