defmodule Explorer.Celo.VoterRewardsForGroup do
  @moduledoc """
    Module responsible for calculating a voter's rewards for a specific group. Extracted for testing purposes.
  """

  import Ecto.Query,
    only: [
      from: 2
    ]

  alias Explorer.Celo.{ContractEvents, Util}
  alias Explorer.Chain.{Block, CeloContractEvent, CeloVoterVotes, Wei}
  alias Explorer.Repo

  alias ContractEvents.Election

  alias Election.{
    ValidatorGroupActiveVoteRevokedEvent,
    ValidatorGroupVoteActivatedEvent
  }

  @validator_group_vote_activated ValidatorGroupVoteActivatedEvent.topic()
  @validator_group_active_vote_revoked ValidatorGroupActiveVoteRevokedEvent.topic()

  def calculate(voter_address_hash, group_address_hash, to_date \\ DateTime.utc_now()) do
    query =
      from(event in CeloContractEvent,
        select: %{
          block_number: event.block_number,
          amount_activated_or_revoked: json_extract_path(event.params, ["value"]),
          event: event.topic
        },
        order_by: [asc: event.block_number],
        where:
          event.topic == ^@validator_group_active_vote_revoked or
            event.topic == ^@validator_group_vote_activated
      )

    voter_activated_or_revoked_votes_for_group_events =
      query
      |> CeloContractEvent.query_by_voter_param(voter_address_hash)
      |> CeloContractEvent.query_by_group_param(group_address_hash)
      |> Repo.all()

    case voter_activated_or_revoked_votes_for_group_events do
      [] ->
        %{rewards: [], total: 0, group: group_address_hash}

      voter_activated_or_revoked ->
        [voter_activated_earliest_block | _] = voter_activated_or_revoked

        query =
          from(votes in CeloVoterVotes,
            inner_join: block in Block,
            on: votes.block_hash == block.hash,
            select: %{
              block_hash: votes.block_hash,
              block_number: votes.block_number,
              date: block.timestamp,
              votes: votes.active_votes
            },
            where: votes.account_hash == ^voter_address_hash,
            where: votes.group_hash == ^group_address_hash,
            where: votes.block_number >= ^voter_activated_earliest_block.block_number,
            where: block.timestamp < ^to_date
          )

        voter_votes_for_group =
          query
          |> Repo.all()

        events_and_votes_chunked_by_epoch =
          merge_events_with_votes_and_chunk_by_epoch(
            voter_activated_or_revoked_votes_for_group_events,
            voter_votes_for_group
          )

        {rewards, {rewards_sum, _}} =
          Enum.map_reduce(events_and_votes_chunked_by_epoch, {0, 0}, fn epoch, {rewards_sum, previous_epoch_votes} ->
            epoch_reward = calculate_single_epoch_reward(epoch, previous_epoch_votes)

            current_epoch_votes = epoch |> Enum.reverse() |> hd()
            %Wei{value: current_votes} = current_epoch_votes.votes
            current_votes_integer = Decimal.to_integer(current_votes)

            {
              %{
                amount: epoch_reward,
                block_hash: current_epoch_votes.block_hash,
                block_number: current_epoch_votes.block_number,
                date: current_epoch_votes.date,
                epoch_number: Util.epoch_by_block_number(current_epoch_votes.block_number)
              },
              {epoch_reward + rewards_sum, current_votes_integer}
            }
          end)

        %{rewards: rewards, total: rewards_sum, group: group_address_hash}
    end
  end

  def calculate_single_epoch_reward(epoch, previous_epoch_votes) do
    Enum.reduce(epoch, -previous_epoch_votes, fn
      %{votes: %Wei{value: votes}}, acc ->
        acc + Decimal.to_integer(votes)

      %{amount_activated_or_revoked: amount, event: @validator_group_vote_activated}, acc ->
        acc - amount

      %{amount_activated_or_revoked: amount, event: @validator_group_active_vote_revoked}, acc ->
        acc + amount
    end)
  end

  def merge_events_with_votes_and_chunk_by_epoch(events, votes) do
    chunk_fun = fn
      %{votes: _} = element, acc ->
        {:cont, Enum.reverse([element | acc]), []}

      element, acc ->
        {:cont, [element | acc]}
    end

    after_fun = fn
      [] -> {:cont, []}
      acc -> {:cont, Enum.reverse(acc), []}
    end

    (events ++ votes)
    |> Enum.sort_by(& &1.block_number)
    |> Enum.chunk_while([], chunk_fun, after_fun)
  end
end
