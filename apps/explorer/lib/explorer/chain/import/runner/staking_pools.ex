defmodule Explorer.Chain.Import.Runner.StakingPools do
  @moduledoc """
  Bulk imports staking pools to StakingPool tabe.
  """

  require Ecto.Query
  require Logger

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, StakingPool}

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [StakingPool.t()]

  @impl Import.Runner
  def ecto_schema_module, do: StakingPool

  @impl Import.Runner
  def option_key, do: :staking_pools

  @impl Import.Runner
  def runner_specific_options, do: [:clear_snapshotted_values]

  @impl Import.Runner
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    Logger.info("### Staking pools run STARTED ###")

    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout clear_snapshotted_values)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    clear_snapshotted_values =
      case Map.fetch(insert_options, :clear_snapshotted_values) do
        {:ok, v} -> v
        :error -> false
      end

    multi =
      if clear_snapshotted_values do
        multi
      else
        # Enforce ShareLocks tables order (see docs: sharelocks.md)
        Multi.run(multi, :acquire_all_staking_pools, fn repo, _ ->
          acquire_all_staking_pools(repo)
        end)
      end

    multi
    |> Multi.run(:mark_as_deleted, fn repo, _ ->
      mark_as_deleted(repo, changes_list, insert_options, clear_snapshotted_values)
    end)
    |> Multi.run(:insert_staking_pools, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp acquire_all_staking_pools(repo) do
    query =
      from(
        pool in StakingPool,
        # Enforce StackingPool ShareLocks order (see docs: sharelocks.md)
        order_by: pool.staking_address_hash,
        lock: "FOR UPDATE"
      )

    pools = repo.all(query)

    {:ok, pools}
  end

  defp mark_as_deleted(repo, changes_list, %{timeout: timeout}, clear_snapshotted_values) when is_list(changes_list) do
    query =
      if clear_snapshotted_values do
        from(
          pool in StakingPool,
          update: [
            set: [
              snapshotted_self_staked_amount: nil,
              snapshotted_total_staked_amount: nil,
              snapshotted_validator_reward_ratio: nil
            ]
          ]
        )
      else
        addresses = Enum.map(changes_list, & &1.staking_address_hash)

        from(
          pool in StakingPool,
          where: pool.staking_address_hash not in ^addresses,
          # ShareLocks order already enforced by `acquire_all_staking_pools` (see docs: sharelocks.md)
          update: [set: [is_deleted: true, is_active: false]]
        )
      end

    try do
      {_, result} = repo.update_all(query, [], timeout: timeout)

      {:ok, result}
    rescue
      postgrex_error in Postgrex.Error ->
        {:error, %{exception: postgrex_error}}
    end
  end

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [StakingPool.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    Logger.info(["### Staking pools insert started ###"])
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce StackingPool ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.staking_address_hash)

    {:ok, staking_pools} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: :staking_address_hash,
        on_conflict: on_conflict,
        for: StakingPool,
        returning: [:staking_address_hash],
        timeout: timeout,
        timestamps: timestamps
      )

    Logger.info(["### Staking pools insert FINISHED ###"])
    {:ok, staking_pools}
  end

  defp default_on_conflict do
    from(
      pool in StakingPool,
      update: [
        set: [
          mining_address_hash: fragment("EXCLUDED.mining_address_hash"),
          delegators_count: fragment("EXCLUDED.delegators_count"),
          is_active: fragment("EXCLUDED.is_active"),
          is_banned: fragment("EXCLUDED.is_banned"),
          is_validator: fragment("EXCLUDED.is_validator"),
          is_unremovable: fragment("EXCLUDED.is_unremovable"),
          are_delegators_banned: fragment("EXCLUDED.are_delegators_banned"),
          likelihood: fragment("EXCLUDED.likelihood"),
          validator_reward_percent: fragment("EXCLUDED.validator_reward_percent"),
          stakes_ratio: fragment("EXCLUDED.stakes_ratio"),
          validator_reward_ratio: fragment("EXCLUDED.validator_reward_ratio"),
          self_staked_amount: fragment("EXCLUDED.self_staked_amount"),
          total_staked_amount: fragment("EXCLUDED.total_staked_amount"),
          ban_reason: fragment("EXCLUDED.ban_reason"),
          was_banned_count: fragment("EXCLUDED.was_banned_count"),
          was_validator_count: fragment("EXCLUDED.was_validator_count"),
          is_deleted: fragment("EXCLUDED.is_deleted"),
          banned_until: fragment("EXCLUDED.banned_until"),
          banned_delegators_until: fragment("EXCLUDED.banned_delegators_until"),
          name: fragment("EXCLUDED.name"),
          description: fragment("EXCLUDED.description"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", pool.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", pool.updated_at)
        ]
      ]
    )
  end
end
