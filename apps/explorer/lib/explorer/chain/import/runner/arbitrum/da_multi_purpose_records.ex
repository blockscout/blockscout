defmodule Explorer.Chain.Import.Runner.Arbitrum.DaMultiPurposeRecords do
  @moduledoc """
    Bulk imports of Explorer.Chain.Arbitrum.DaMultiPurposeRecord.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Arbitrum.DaMultiPurposeRecord
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [DaMultiPurposeRecord.t()]

  @impl Import.Runner
  def ecto_schema_module, do: DaMultiPurposeRecord

  @impl Import.Runner
  def option_key, do: :arbitrum_da_multi_purpose_records

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

    Multi.run(multi, :insert_da_multi_purpose_records, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :arbitrum_da_multi_purpose_records,
        :arbitrum_da_multi_purpose_records
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [DaMultiPurposeRecord.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce Arbitrum.DaMultiPurposeRecord ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.data_key)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: DaMultiPurposeRecord,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :data_key,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      rec in DaMultiPurposeRecord,
      update: [
        set: [
          # don't update `data_key` as it is a primary key and used for the conflict target
          data_type: fragment("EXCLUDED.data_type"),
          data: fragment("EXCLUDED.data"),
          batch_number: fragment("EXCLUDED.batch_number"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", rec.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", rec.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.data_type, EXCLUDED.data, EXCLUDED.batch_number) IS DISTINCT FROM (?, ?, ?)",
          rec.data_type,
          rec.data,
          rec.batch_number
        )
    )
  end
end
