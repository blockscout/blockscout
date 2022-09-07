defmodule Explorer.Chain.Import.Runner.CeloAccountEpochs do
  @moduledoc """
  Bulk imports Celo voter rewards to the DB table.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.{CeloAccountEpoch, Import}
  alias Explorer.Chain.Import.Runner.Util

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [CeloAccountEpoch.t()]

  @impl Import.Runner
  def ecto_schema_module, do: CeloAccountEpoch

  @impl Import.Runner
  def option_key, do: :celo_accounts_epochs

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
    Multi.run(multi, :insert_account_epoch_items, fn repo, _ ->
      insert(repo, changes_list, insert_options)
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], Util.insert_options()) ::
          {:ok, [CeloAccountEpoch.t()]} | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce ShareLocks order (see docs: sharelocks.md)
    uniq_changes_list =
      changes_list
      |> Enum.sort_by(&{&1.block_hash})
      |> Enum.dedup_by(&{&1.block_hash, &1.account_hash})

    {:ok, _} =
      Import.insert_changes_list(
        repo,
        uniq_changes_list,
        conflict_target: [:block_hash, :account_hash],
        on_conflict: on_conflict,
        for: CeloAccountEpoch,
        returning: true,
        timeout: timeout,
        timestamps: timestamps
      )
  end

  defp default_on_conflict do
    from(
      account_epoch in CeloAccountEpoch,
      update: [
        set: [
          total_locked_gold: fragment("EXCLUDED.total_locked_gold"),
          nonvoting_locked_gold: fragment("EXCLUDED.nonvoting_locked_gold"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", account_epoch.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", account_epoch.updated_at)
        ]
      ]
    )
  end
end
