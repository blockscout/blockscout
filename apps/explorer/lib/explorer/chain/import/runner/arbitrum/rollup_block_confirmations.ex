# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.Import.Runner.Arbitrum.RollupBlockConfirmations do
  @moduledoc """
    Bulk imports of Explorer.Chain.Arbitrum.RollupBlockConfirmation.

    On a conflict on `top`, the import changes the row only if the new row holds
    a different confirmation transaction. Thus a repeated window changes nothing,
    and a transaction that replaced one lost in a re-org takes over the row of its `top`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Arbitrum.RollupBlockConfirmation
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [RollupBlockConfirmation.t()]

  @impl Import.Runner
  def ecto_schema_module, do: RollupBlockConfirmation

  @impl Import.Runner
  def option_key, do: :arbitrum_rollup_block_confirmations

  @impl Import.Runner
  @spec imported_table_row() :: %{:value_description => binary(), :value_type => binary()}
  def imported_table_row do
    %{
      value_type: "[#{ecto_schema_module()}.t()]",
      value_description: "List of `t:#{ecto_schema_module()}.t/0`s"
    }
  end

  @impl Import.Runner
  @spec run(Multi.t(), list(), map()) :: Multi.t()
  def run(multi, changes_list, %{timestamps: timestamps} = options) do
    insert_options =
      options
      |> Map.get(option_key(), %{})
      |> Map.take(~w(on_conflict timeout)a)
      |> Map.put_new(:timeout, @timeout)
      |> Map.put(:timestamps, timestamps)

    Multi.run(multi, :insert_arbitrum_rollup_block_confirmations, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :arbitrum_rollup_block_confirmations,
        :arbitrum_rollup_block_confirmations
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [RollupBlockConfirmation.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Arbitrum.RollupBlockConfirmation ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.top)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: RollupBlockConfirmation,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :top,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      confirmation in RollupBlockConfirmation,
      update: [
        set: [
          # don't update `top` as it is a primary key and used for the conflict target
          confirmation_id: fragment("EXCLUDED.confirmation_id"),
          updated_at: fragment("EXCLUDED.updated_at")
        ]
      ],
      where: fragment("EXCLUDED.confirmation_id IS DISTINCT FROM ?", confirmation.confirmation_id)
    )
  end
end
