defmodule Explorer.Chain.Import.Runner.CeloEpochRewards do
  @moduledoc """
  Bulk imports Celo voter rewards to the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{CeloEpochRewards, Import}
  alias Explorer.Chain.Import.Runner.Util

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloEpochRewards.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloEpochRewards

  @impl Import.Runner
  def option_key, do: :celo_epoch_rewards

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, options) do
    insert_options = Util.make_insert_options(option_key(), @timeout, options)

    # Enforce ShareLocks tables order (see docs: sharelocks.md)
    Multi.run(multi, :insert_voter_reward_items, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], Util.insert_options()) ::
          {:ok, [CeloEpochRewards.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ShareLocks order (see docs: sharelocks.md)
    uniq_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.block_number})
      |> Enum.dedup_by(&{&1.block_number})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        uniq_changes_list,
        conflict_target: [:block_hash],
        on_conflict: on_conflict,
        for: CeloEpochRewards,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      account in CeloEpochRewards,
      update: [
        set: [
          block_number: fragment("EXCLUDED.block_number"),
          epoch_number: fragment("EXCLUDED.epoch_number"),
          validator_target_epoch_rewards: fragment("EXCLUDED.validator_target_epoch_rewards"),
          voter_target_epoch_rewards: fragment("EXCLUDED.voter_target_epoch_rewards"),
          community_target_epoch_rewards: fragment("EXCLUDED.community_target_epoch_rewards"),
          carbon_offsetting_target_epoch_rewards: fragment("EXCLUDED.carbon_offsetting_target_epoch_rewards"),
          target_total_supply: fragment("EXCLUDED.target_total_supply"),
          rewards_multiplier: fragment("EXCLUDED.rewards_multiplier"),
          rewards_multiplier_max: fragment("EXCLUDED.rewards_multiplier_max"),
          rewards_multiplier_under: fragment("EXCLUDED.rewards_multiplier_under"),
          rewards_multiplier_over: fragment("EXCLUDED.rewards_multiplier_over"),
          target_voting_yield: fragment("EXCLUDED.target_voting_yield"),
          target_voting_yield_max: fragment("EXCLUDED.target_voting_yield_max"),
          target_voting_yield_adjustment_factor: fragment("EXCLUDED.target_voting_yield_adjustment_factor"),
          target_voting_fraction: fragment("EXCLUDED.target_voting_fraction"),
          voting_fraction: fragment("EXCLUDED.voting_fraction"),
          total_locked_gold: fragment("EXCLUDED.total_locked_gold"),
          total_non_voting: fragment("EXCLUDED.total_non_voting"),
          total_votes: fragment("EXCLUDED.total_votes"),
          electable_validators_max: fragment("EXCLUDED.electable_validators_max"),
          reserve_gold_balance: fragment("EXCLUDED.reserve_gold_balance"),
          gold_total_supply: fragment("EXCLUDED.gold_total_supply"),
          stable_usd_total_supply: fragment("EXCLUDED.stable_usd_total_supply"),
          reserve_bolster: fragment("EXCLUDED.reserve_bolster"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", account.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", account.updated_at)
        ]
      ]
    )
  end
end
