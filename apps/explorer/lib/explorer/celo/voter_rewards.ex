defmodule Explorer.Celo.VoterRewards do
  @moduledoc """
    Module responsible for calculating a voter's rewards for all groups the voter has voted for.
  """

  import Ecto.Query,
    only: [
      distinct: 3,
      from: 2,
      join: 5,
      order_by: 3,
      select: 3,
      where: 3
    ]

  alias Explorer.Celo.{ContractEvents, Events, Util}
  alias Explorer.Chain.{Block, CeloContractEvent, CeloValidatorGroupVotes, Wei}
  alias Explorer.Repo

  alias ContractEvents.{Election, EventMap}

  alias Election.{
    EpochRewardsDistributedToVotersEvent,
    ValidatorGroupActiveVoteRevokedEvent,
    ValidatorGroupVoteActivatedEvent
  }

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
    validator_group_vote_activated = ValidatorGroupVoteActivatedEvent.name()

    query =
      ValidatorGroupVoteActivatedEvent.query()
      |> join(:inner, [event], block in Block, on: event.block_hash == block.hash)
      |> distinct([event], [json_extract_path(event.params, ["voter"]), json_extract_path(event.params, ["group"])])
      |> order_by([_, block], block.number)
      |> where([event], event.name == ^validator_group_vote_activated)

    validator_group_vote_activated_events =
      query
      |> CeloContractEvent.query_by_voter_param(voter_address_hash)
      |> Repo.all()
      |> EventMap.celo_contract_event_to_concrete_event()

    case validator_group_vote_activated_events do
      [] ->
        {:error, :not_found}

      group ->
        rewards_for_each_group =
          group
          |> Enum.map(fn %ValidatorGroupVoteActivatedEvent{group: group} ->
            voter_rewards_for_group.calculate(voter_address_hash, group, to_date)
          end)

        structured_rewards_for_given_period =
          rewards_for_each_group
          |> Enum.map(fn {:ok, %{group: group, rewards: rewards}} ->
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

        {:ok, structured_rewards_for_given_period}
    end
  end
end
