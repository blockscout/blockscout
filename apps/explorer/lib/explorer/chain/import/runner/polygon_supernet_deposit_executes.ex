defmodule Explorer.Chain.Import.Runner.PolygonSupernetDepositExecutes do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.PolygonSupernetDepositExecute.t/0`.
  """

  require Ecto.Query

  import Ecto.Query, only: [from: 2]

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{Import, PolygonSupernetDepositExecute}
  alias Explorer.Prometheus.Instrumenter

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [PolygonSupernetDepositExecute.t()]

  @impl Import.Runner
  def ecto_schema_module, do: PolygonSupernetDepositExecute

  @impl Import.Runner
  def option_key, do: :polygon_supernet_deposit_executes

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

    Multi.run(multi, :insert_polygon_supernet_deposit_executes, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :polygon_supernet_deposit_executes,
        :polygon_supernet_deposit_executes
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [PolygonSupernetDepositExecute.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce PolygonSupernetDepositExecute ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.msg_id)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        conflict_target: :msg_id,
        on_conflict: on_conflict,
        for: PolygonSupernetDepositExecute,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      de in PolygonSupernetDepositExecute,
      update: [
        set: [
          # Don't update `msg_id` as it is a primary key and used for the conflict target
          l2_transaction_hash: fragment("EXCLUDED.l2_transaction_hash"),
          l2_block_number: fragment("EXCLUDED.l2_block_number"),
          success: fragment("EXCLUDED.success"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", de.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", de.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.l2_transaction_hash, EXCLUDED.l2_block_number, EXCLUDED.success) IS DISTINCT FROM (?, ?, ?)",
          de.l2_transaction_hash,
          de.l2_block_number,
          de.success
        )
    )
  end
end
