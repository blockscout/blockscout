defmodule Explorer.Chain.Import.Runner.StakingPoolsDelegators do
  @moduledoc """
  Bulk imports delegators to StakingPoolsDelegator table.
  """

  require Ecto.Query
  require Logger

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, StakingPoolsDelegator}

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [StakingPoolsDelegator.t()]

  @impl Import.Runner
  def ecto_schema_module, do: StakingPoolsDelegator

  @impl Import.Runner
  def option_key, do: :staking_pools_delegators

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
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout clear_snapshotted_values)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    multi
    |> Multi.run(:clear_delegators, fn repo, _ ->
      mark_as_deleted(repo, insert_options)
    end)
    |> Multi.run(:insert_staking_pools_delegators, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  defp mark_as_deleted(repo, %{timeout: timeout} = options) do
    clear_snapshotted_values = case Map.fetch(options, :clear_snapshotted_values) do
      {:ok, v} -> v
      :error -> false
    end

    query = if clear_snapshotted_values do
      from(
        d in StakingPoolsDelegator,
        update: [set: [snapshotted_reward_ratio: nil, snapshotted_stake_amount: nil]]
      )
    else
      from(
        d in StakingPoolsDelegator,
        update: [set: [is_active: false, is_deleted: true]]
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
          {:ok, [StakingPoolsDelegator.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce StackingPoolDelegator ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.address_hash, &1.staking_address_hash})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: [:staking_address_hash, :address_hash],
        on_conflict: on_conflict,
        for: StakingPoolsDelegator,
        returning: [:staking_address_hash, :address_hash],
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      delegator in StakingPoolsDelegator,
      update: [
        set: [
          stake_amount: fragment("EXCLUDED.stake_amount"),
          ordered_withdraw: fragment("EXCLUDED.ordered_withdraw"),
          max_withdraw_allowed: fragment("EXCLUDED.max_withdraw_allowed"),
          max_ordered_withdraw_allowed: fragment("EXCLUDED.max_ordered_withdraw_allowed"),
          ordered_withdraw_epoch: fragment("EXCLUDED.ordered_withdraw_epoch"),
          reward_ratio: fragment("EXCLUDED.reward_ratio"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", delegator.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", delegator.updated_at),
          is_active: fragment("EXCLUDED.is_active"),
          is_deleted: fragment("EXCLUDED.is_deleted")
        ]
      ]
    )
  end
end
