defmodule Explorer.Chain.Import.Runner.Stats.HotSmartContracts do
  @moduledoc """
  Bulk imports `t:Explorer.Stats.HotSmartContracts.t/0` rows (hot_smart_contracts_daily).
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter
  alias Explorer.Stats.HotSmartContracts

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [HotSmartContracts.t()]

  @impl Import.Runner
  def ecto_schema_module, do: HotSmartContracts

  @impl Import.Runner
  def option_key, do: :hot_smart_contracts_daily

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

    Multi.run(multi, :hot_smart_contracts_daily, fn repo, _ ->
      Instrumenter.stats_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :hot_smart_contracts_daily
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{
          optional(:on_conflict) => Import.Runner.on_conflict(),
          required(:timeout) => timeout,
          required(:timestamps) => Import.timestamps()
        }) ::
          {:ok, [HotSmartContracts.t()]}
          | {:error, [Changeset.t()]}
  defp insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce HotSmartContracts ShareLocks order (see docs: sharelocks.md)
    ordered_changes_list = Enum.sort_by(changes_list, &{&1.date, &1.contract_address_hash})

    Import.insert_changes_list(
      repo,
      ordered_changes_list,
      conflict_target: [:date, :contract_address_hash],
      on_conflict: on_conflict,
      for: HotSmartContracts,
      returning: true,
      timeout: timeout,
      timestamps: timestamps
    )
  end

  defp default_on_conflict do
    :replace_all
  end
end
