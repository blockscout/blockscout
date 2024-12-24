defmodule Explorer.Chain.Import.Runner.Arbitrum.BatchToDaBlobs do
  @moduledoc """
    Bulk imports of Explorer.Chain.Arbitrum.BatchToDaBlob.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Arbitrum.BatchToDaBlob
  alias Explorer.Chain.Import
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [BatchToDaBlob.t()]

  @impl Import.Runner
  def ecto_schema_module, do: BatchToDaBlob

  @impl Import.Runner
  def option_key, do: :arbitrum_batches_to_da_blobs

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

    Multi.run(multi, :insert_batches_to_da_blobs, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :arbitrum_batches_to_da_blobs,
        :arbitrum_batches_to_da_blobs
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [BatchToDaBlob.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce BatchToDaBlob ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.batch_number)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: BatchToDaBlob,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: :batch_number,
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      rec in BatchToDaBlob,
      update: [
        set: [
          # don't update `batch_number` as it is a primary key and used for the conflict target
          data_blob_id: fragment("EXCLUDED.data_blob_id"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", rec.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", rec.updated_at)
        ]
      ],
      where:
        fragment(
          "EXCLUDED.data_blob_id IS DISTINCT FROM ?",
          rec.data_blob_id
        )
    )
  end
end
