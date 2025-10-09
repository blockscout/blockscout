defmodule Explorer.Chain.Import.Runner.Optimism.EIP1559ConfigUpdates do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Optimism.EIP1559ConfigUpdate.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Optimism.EIP1559ConfigUpdate
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [EIP1559ConfigUpdate.t()]

  @impl Import.Runner
  def ecto_schema_module, do: EIP1559ConfigUpdate

  @impl Import.Runner
  def option_key, do: :optimism_eip1559_config_updates

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
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :insert_eip1559_config_updates, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :optimism_eip1559_config_updates,
        :optimism_eip1559_config_updates
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [EIP1559ConfigUpdate.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce EIP1559ConfigUpdate ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.l2_block_number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: EIP1559ConfigUpdate,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :l2_block_number,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      update in EIP1559ConfigUpdate,
      update: [
        set: [
          # don't update `l2_block_number` as it is a primary key and used for the conflict target
          l2_block_hash: fragment("EXCLUDED.l2_block_hash"),
          base_fee_max_change_denominator: fragment("EXCLUDED.base_fee_max_change_denominator"),
          elasticity_multiplier: fragment("EXCLUDED.elasticity_multiplier"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", update.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", update.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.l2_block_hash, EXCLUDED.base_fee_max_change_denominator, EXCLUDED.elasticity_multiplier) IS DISTINCT FROM (?, ?, ?)",
          update.l2_block_hash,
          update.base_fee_max_change_denominator,
          update.elasticity_multiplier
        )
    )
  end
end
