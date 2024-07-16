defmodule Explorer.Chain.Import.Runner.Optimism.FrameSequenceBlobs do
  @moduledoc """
  Bulk imports `t:Explorer.Chain.Optimism.FrameSequenceBlob.t/0`.
  """

  require Ecto.Query

  alias Ecto.{Changeset, Multi, Repo}
  alias Explorer.Chain.Import
  alias Explorer.Chain.Optimism.FrameSequenceBlob
  alias Explorer.Prometheus.Instrumenter

  import Ecto.Query, only: [from: 2]

  @behaviour Import.Runner

  # milliseconds
  @timeout 60_000

  @type imported :: [FrameSequenceBlob.t()]

  @impl Import.Runner
  def ecto_schema_module, do: FrameSequenceBlob

  @impl Import.Runner
  def option_key, do: :optimism_frame_sequence_blobs

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

    Multi.run(multi, :insert_frame_sequence_blobs, fn repo, _ ->
      Instrumenter.block_import_stage_runner(
        fn -> insert(repo, changes_list, insert_options) end,
        :block_referencing,
        :optimism_frame_sequence_blobs,
        :optimism_frame_sequence_blobs
      )
    end)
  end

  @impl Import.Runner
  def timeout, do: @timeout

  @spec insert(Repo.t(), [map()], %{required(:timeout) => timeout(), required(:timestamps) => Import.timestamps()}) ::
          {:ok, [FrameSequenceBlob.t()]}
          | {:error, [Changeset.t()]}
  def insert(repo, changes_list, %{timeout: timeout, timestamps: timestamps} = options) when is_list(changes_list) do
    on_conflict = Map.get_lazy(options, :on_conflict, &default_on_conflict/0)

    # Enforce FrameSequenceBlob ShareLocks order (see docs: sharelock.md)
    ordered_changes_list = Enum.sort_by(changes_list, & &1.id)

    {:ok, inserted} =
      Import.insert_changes_list(
        repo,
        ordered_changes_list,
        for: FrameSequenceBlob,
        returning: true,
        timeout: timeout,
        timestamps: timestamps,
        conflict_target: [:key, :type],
        on_conflict: on_conflict
      )

    {:ok, inserted}
  end

  defp default_on_conflict do
    from(
      fsb in FrameSequenceBlob,
      update: [
        set: [
          # don't update `key` as it is a part of the composite primary key and used for the conflict target
          # don't update `type` as it is a part of the composite primary key and used for the conflict target
          id: fragment("EXCLUDED.id"),
          metadata: fragment("EXCLUDED.metadata"),
          l1_transaction_hash: fragment("EXCLUDED.l1_transaction_hash"),
          l1_timestamp: fragment("EXCLUDED.l1_timestamp"),
          frame_sequence_id: fragment("EXCLUDED.frame_sequence_id"),
          inserted_at: fragment("LEAST(?, EXCLUDED.inserted_at)", fsb.inserted_at),
          updated_at: fragment("GREATEST(?, EXCLUDED.updated_at)", fsb.updated_at)
        ]
      ],
      where:
        fragment(
          "(EXCLUDED.id, EXCLUDED.metadata, EXCLUDED.l1_transaction_hash, EXCLUDED.l1_timestamp, EXCLUDED.frame_sequence_id) IS DISTINCT FROM (?, ?, ?, ?, ?)",
          fsb.id,
          fsb.metadata,
          fsb.l1_transaction_hash,
          fsb.l1_timestamp,
          fsb.frame_sequence_id
        )
    )
  end
end
