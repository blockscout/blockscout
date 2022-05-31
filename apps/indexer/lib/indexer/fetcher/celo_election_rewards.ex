defmodule Indexer.Fetcher.CeloElectionRewards do
  @moduledoc """
  Fetches and imports celo voter votes, calculates and imports voter along with validator and validator group rewards.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Celo.{AccountReader, VoterRewards}
  alias Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent
  alias Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent
  alias Explorer.Chain
  alias Explorer.Chain.Block
  alias Explorer.Chain.CeloElectionRewards, as: CeloElectionRewardsChain

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  @behaviour BufferedTask

  @spec async_fetch([%{block_number: Block.block_number()}]) :: :ok
  def async_fetch(blocks) when is_list(blocks) do
    filtered_blocks =
      blocks
      |> Enum.filter(&(rem(&1.block_number, 17_280) == 0))

    BufferedTask.buffer(__MODULE__, filtered_blocks)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    init_options_with_polling =
      init_options
      |> Keyword.put(:poll, true)
      |> Keyword.put(:poll_interval, :timer.minutes(60))
      |> Keyword.put(:max_batch_size, 10)

    Util.default_child_spec(init_options_with_polling, gen_server_options, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      Chain.stream_blocks_with_unfetched_election_rewards(initial, fn block, acc ->
        block
        |> reducer.(acc)
      end)

    final
  end

  @impl BufferedTask
  def run(entries, _json_rpc_named_arguments) do
    response =
      entries
      |> Enum.map(fn entry ->
        entry
        |> get_voter_rewards()
        |> get_validator_and_group_rewards()
        |> import_items()
      end)

    if Enum.all?(response, &(&1 == :ok)) do
      :ok
    else
      {:retry, response}
    end
  end

  def get_voter_rewards(%{voter_rewards: _voter_rewards} = block_with_rewards), do: block_with_rewards

  def get_voter_rewards(%{block_number: block_number, block_timestamp: block_timestamp}) do
    account_group_pairs = ValidatorGroupVoteActivatedEvent.get_account_group_pairs_with_activated_votes(block_number)

    voter_rewards =
      Enum.map(account_group_pairs, fn account_group_pair ->
        # The rewards are distributed on the last block of an epoch. Here we get the votes one block before they are
        # distributed and at the exact block where they are distributed to subtract one from the other. We could have
        # chosen to get the votes at the end of each epoch, but in that case we would need to consider all additional
        # activations and revocations during the epoch (See VoterRewards.subtract_activated_add_revoked for more
        # details).
        before_rewards_votes = fetch_from_blockchain(Map.put(account_group_pair, :block_number, block_number - 1))
        after_rewards_votes = fetch_from_blockchain(Map.put(account_group_pair, :block_number, block_number))

        plus_revoked_minus_activated_votes =
          VoterRewards.subtract_activated_add_revoked(%{
            account_hash: account_group_pair.account_hash,
            block_number: block_number - 1,
            group_hash: account_group_pair.group_hash
          })

        reward_value =
          calculate_voter_rewards(after_rewards_votes, before_rewards_votes, plus_revoked_minus_activated_votes)

        %{
          account_hash: account_group_pair.account_hash,
          amount: reward_value,
          associated_account_hash: account_group_pair.group_hash,
          block_number: block_number,
          block_timestamp: block_timestamp,
          reward_type: "voter"
        }
      end)

    %{block_number: block_number, block_timestamp: block_timestamp, voter_rewards: voter_rewards}
  end

  def calculate_voter_rewards(after_rewards_votes, before_rewards_votes, nil = _votes_plus_revoked_minus_activated),
    do: after_rewards_votes - before_rewards_votes

  def calculate_voter_rewards(after_rewards_votes, before_rewards_votes, plus_revoked_minus_activated_votes),
    do: after_rewards_votes - before_rewards_votes + plus_revoked_minus_activated_votes

  def fetch_from_blockchain(entry) do
    case AccountReader.active_votes(entry) do
      {:ok, data} ->
        data

      error ->
        Logger.debug(inspect(error))
        Map.put(entry, :error, error)
    end
  end

  def get_validator_and_group_rewards(
        %{group_rewards: _group_rewards, validator_rewards: _validator_rewards} = block_with_rewards
      ),
      do: block_with_rewards

  def get_validator_and_group_rewards(
        %{block_number: block_number, block_timestamp: block_timestamp} = block_with_rewards
      ) do
    validator_and_group_rewards =
      ValidatorEpochPaymentDistributedEvent.get_validator_and_group_rewards_for_block(block_number)

    validator_rewards =
      Enum.map(validator_and_group_rewards, fn reward ->
        %{
          account_hash: reward.validator,
          amount: reward.validator_payment,
          associated_account_hash: reward.group,
          block_number: block_number,
          block_timestamp: block_timestamp,
          reward_type: "validator"
        }
      end)

    group_rewards =
      Enum.map(validator_and_group_rewards, fn reward ->
        %{
          account_hash: reward.group,
          amount: reward.group_payment,
          associated_account_hash: reward.validator,
          block_number: block_number,
          block_timestamp: block_timestamp,
          reward_type: "group"
        }
      end)

    Map.merge(block_with_rewards, %{validator_rewards: validator_rewards, group_rewards: group_rewards})
  end

  def import_items(block_with_rewards) do
    reward_types_present_for_block =
      MapSet.intersection(
        MapSet.new(Map.keys(block_with_rewards)),
        MapSet.new([:voter_rewards, :validator_rewards, :group_rewards])
      )

    block_with_changes =
      reward_types_present_for_block
      |> Enum.reduce(block_with_rewards, fn type, block_with_rewards ->
        case changeset(Map.get(block_with_rewards, type)) do
          {:ok, changes} -> Map.put(block_with_rewards, type, changes)
          {:error} -> Map.drop(block_with_rewards, [type])
        end
      end)

    case chain_import(block_with_changes) do
      :ok -> :ok
      {:error, :changeset} -> block_with_changes
      {:error, :import} -> block_with_rewards
    end
  end

  def changeset(election_rewards) do
    {changesets, all_valid} =
      Enum.map_reduce(election_rewards, true, fn reward, all_valid ->
        changeset = CeloElectionRewardsChain.changeset(%CeloElectionRewardsChain{}, reward)
        {changeset, all_valid and changeset.valid?}
      end)

    if all_valid do
      {:ok, Enum.map(changesets, & &1.changes)}
    else
      Enum.each(changesets, fn cs ->
        Logger.error(
          fn -> "Election rewards changeset errors. Block #{inspect(cs.changes.block_number)} requeued." end,
          errors: cs.errors
        )
      end)

      {:error}
    end
  end

  def chain_import(block_with_changes) when not is_map_key(block_with_changes, :voter_rewards), do: {:error, :changeset}

  def chain_import(block_with_changes) when not is_map_key(block_with_changes, :validator_rewards),
    do: {:error, :changeset}

  def chain_import(block_with_changes) when not is_map_key(block_with_changes, :group_rewards), do: {:error, :changeset}

  def chain_import(block_with_changes) do
    import_params = %{
      celo_election_rewards: %{
        params:
          List.flatten([
            block_with_changes.voter_rewards,
            block_with_changes.validator_rewards,
            block_with_changes.group_rewards
          ])
      },
      timeout: :infinity
    }

    case Chain.import(import_params) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error(fn -> ["failed to import Celo election reward data: ", inspect(reason)] end)
        {:error, :import}
    end
  end
end
