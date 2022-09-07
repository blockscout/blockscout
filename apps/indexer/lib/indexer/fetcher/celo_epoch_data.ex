defmodule Indexer.Fetcher.CeloEpochData do
  @moduledoc """
  Calculates and imports voter along with validator and validator group rewards.
  """
  use Indexer.Fetcher
  use Spandex.Decorators

  require Logger

  alias Explorer.Celo.{AccountReader, EpochUtil, VoterRewards}
  alias Explorer.Celo.ContractEvents.Election.ValidatorGroupVoteActivatedEvent
  alias Explorer.Celo.ContractEvents.Validators.ValidatorEpochPaymentDistributedEvent
  alias Explorer.Chain
  alias Explorer.Chain.{Block, CeloAccountEpoch, CeloElectionRewards, CeloEpochRewards, CeloPendingEpochOperation, Hash}

  alias Explorer.Celo.ContractEvents.EventMap
  alias Explorer.Celo.ContractEvents.Lockedgold.GoldLockedEvent

  alias Indexer.BufferedTask
  alias Indexer.Fetcher.Util

  use BufferedTask

  @spec async_fetch([%{block_number: Block.block_number()}]) :: :ok
  def async_fetch(blocks) when is_list(blocks) do
    filtered_blocks =
      blocks
      |> Enum.filter(fn block -> EpochUtil.is_epoch_block?(block.block_number) end)

    BufferedTask.buffer(__MODULE__, filtered_blocks)
  end

  @doc false
  def child_spec([init_options, gen_server_options]) do
    init_options_with_polling =
      init_options
      |> Keyword.put(:poll, true)
      |> Keyword.put(:poll_interval, :timer.minutes(5))
      # We have just one such block a day and it's quite a heavy operation
      |> Keyword.put(:max_batch_size, 1)

    Util.default_child_spec(init_options_with_polling, gen_server_options, __MODULE__)
  end

  @impl BufferedTask
  def init(initial, reducer, _json_rpc_named_arguments) do
    {:ok, final} =
      Chain.stream_blocks_with_unfetched_rewards(initial, fn block, acc ->
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
        |> get_epoch_rewards()
        |> get_accounts_epochs()
        |> import_items()
      end)

    failed = Enum.filter(response, &(&1 != :ok))

    if Enum.empty?(failed) do
      :ok
    else
      {:retry, failed}
    end
  end

  def get_accounts_epochs(%{accounts_epochs: _accounts_epochs} = block_with_accounts_epochs),
    do: block_with_accounts_epochs

  def get_accounts_epochs(block) do
    GoldLockedEvent.events_distinct_accounts()
    |> EventMap.query_all()
    |> Enum.map(fn event -> event.account end)
    |> fetch_accounts_epochs(block)
  end

  def fetch_accounts_epochs([], block, acc), do: Map.put(block, :accounts_epochs, acc)

  def fetch_accounts_epochs(
        [account_hash | hashes],
        %{block_hash: block_hash, block_number: block_number} = block,
        acc
      ) do
    case get_account_epoch_data(account_hash, block_number, block_hash) do
      {:ok, data} ->
        fetch_accounts_epochs(hashes, block, [data | acc])

      {:error, error} ->
        Logger.error(inspect(error))
        Map.put(block, :error, error)
    end
  end

  def fetch_accounts_epochs(hashes, block), do: fetch_accounts_epochs(hashes, block, [])

  defp get_account_epoch_data(account_hash, block_number, block_hash) do
    case AccountReader.fetch_celo_account_epoch_data(Hash.to_string(account_hash), block_number) do
      {:ok, data} ->
        {:ok, data |> Map.merge(%{account_hash: account_hash, block_hash: block_hash})}

      {:error, error} ->
        {:error, error}
    end
  end

  def get_voter_rewards(%{voter_rewards: _voter_rewards} = block_with_rewards), do: block_with_rewards

  def get_voter_rewards(%{block_number: block_number, block_timestamp: block_timestamp} = block) do
    account_group_pairs = ValidatorGroupVoteActivatedEvent.get_account_group_pairs_with_activated_votes(block_number)

    voter_rewards =
      Enum.map(account_group_pairs, fn account_group_pair ->
        # The rewards are distributed on the last block of an epoch. Here we get the votes one block before they are
        # distributed and at the exact block where they are distributed to subtract one from the other. We could have
        # chosen to get the votes at the end of each epoch, but in that case we would need to consider all additional
        # activations and revocations during the epoch (See VoterRewards.subtract_activated_add_revoked for more
        # details).
        before_rewards_votes = fetch_votes_from_blockchain(Map.put(account_group_pair, :block_number, block_number - 1))
        after_rewards_votes = fetch_votes_from_blockchain(Map.put(account_group_pair, :block_number, block_number))

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

    Map.merge(block, %{voter_rewards: voter_rewards})
  end

  def calculate_voter_rewards(after_rewards_votes, before_rewards_votes, nil = _votes_plus_revoked_minus_activated),
    do: after_rewards_votes - before_rewards_votes

  def calculate_voter_rewards(after_rewards_votes, before_rewards_votes, plus_revoked_minus_activated_votes),
    do: after_rewards_votes - before_rewards_votes + plus_revoked_minus_activated_votes

  def fetch_votes_from_blockchain(entry) do
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

  def get_validator_and_group_rewards(%{block_number: block_number, block_timestamp: block_timestamp} = block) do
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

    Map.merge(block, %{validator_rewards: validator_rewards, group_rewards: group_rewards})
  end

  def get_epoch_rewards(%{epoch_rewards: _epoch_rewards} = block_with_rewards), do: block_with_rewards

  def get_epoch_rewards(block) do
    epoch_rewards = fetch_epoch_rewards_from_blockchain(block)

    epoch_rewards_with_rewards_bolster =
      epoch_rewards
      |> Map.put(:reserve_bolster, CeloEpochRewards.reserve_bolster_value(block.block_number))

    Map.merge(block, %{epoch_rewards: epoch_rewards_with_rewards_bolster})
  end

  def fetch_epoch_rewards_from_blockchain(entry) do
    case AccountReader.epoch_reward_data(entry) do
      {:ok, data} ->
        data

      {:error, error} ->
        Logger.debug(inspect(error))
        Map.put(entry, :error, error)
    end
  end

  def import_items(block_with_rewards) do
    reward_types_present_for_block =
      MapSet.intersection(
        MapSet.new(Map.keys(block_with_rewards)),
        MapSet.new([
          :voter_rewards,
          :validator_rewards,
          :group_rewards,
          :epoch_rewards,
          :accounts_epochs
        ])
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

  def changeset(epoch_rewards) when is_map(epoch_rewards) do
    changeset = CeloEpochRewards.changeset(%CeloEpochRewards{}, epoch_rewards)

    if changeset.valid? do
      {:ok, changeset.changes}
    else
      Logger.error(
        fn -> "Epoch rewards changeset errors. Block #{inspect(changeset.changes.block_number)} requeued." end,
        errors: changeset.errors
      )

      {:error}
    end
  end

  def changeset(changes) do
    {changesets, all_valid} =
      Enum.map_reduce(changes, true, fn change, all_valid ->
        changeset =
          if Map.has_key?(change, :total_locked_gold) do
            CeloAccountEpoch.changeset(%CeloAccountEpoch{}, change)
          else
            CeloElectionRewards.changeset(%CeloElectionRewards{}, change)
          end

        {changeset, all_valid and changeset.valid?}
      end)

    if all_valid do
      {:ok, Enum.map(changesets, & &1.changes)}
    else
      Enum.each(changesets, fn cs ->
        Logger.error(
          fn -> "Epoch data changeset errors. Block #{inspect(cs.changes.block_number)} requeued." end,
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

  def chain_import(block_with_changes) when not is_map_key(block_with_changes, :epoch_rewards), do: {:error, :changeset}

  def chain_import(block_with_changes) when not is_map_key(block_with_changes, :accounts_epochs),
    do: {:error, :changeset}

  def chain_import(block_with_changes) do
    import_params = %{
      celo_accounts_epochs: %{
        params: block_with_changes.accounts_epochs
      },
      celo_epoch_rewards: %{
        params: [block_with_changes.epoch_rewards]
      },
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
        CeloPendingEpochOperation.delete_celo_pending_epoch_operation(block_with_changes.block_number)
        :ok

      {:error, reason} ->
        Logger.error(fn -> ["failed to import Celo election reward data: ", inspect(reason)] end)
        {:error, :import}
    end
  end
end
